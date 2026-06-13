unit ami_eventbus_threaded;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, Generics.Collections, DateUtils,
  ami_event_types, ami_bus_queue, ami_event_factory, ami_log,
  ami_types, ami_enums, i_eventbus;

type
  TThreadedEventBus = class;

{==============================================================================}
{=== TBusNotifier ==========================================================}
{==============================================================================}

  TBusNotifier = class(TComponent)
  private
    FBus: TThreadedEventBus;
  public
    constructor Create(ABus: TThreadedEventBus);
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  end;

{==============================================================================}
{=== TThreadedEventBus ====================================================}
{==============================================================================}

  TThreadedEventBus = class(TInterfacedObject, IEventBus)
  private
    FSubscribers: specialize TList<TEventSubscriber>;
    FSubscribersLock: TCriticalSection;
    FPendingFree: specialize TList<TEventSubscriber>;

    FQueue: TPriorityEventQueue;
    FQueueEvent: TSimpleEvent;
    FWorkerCount: Integer;
    FWorkers: specialize TList<TThread>;
    FWorkerTerminating: Boolean;

    FInvokeQueue: specialize TList<TInvokeItem>;
    FInvokeLock: TCriticalSection;

    FNextID: Integer;
    FOverflowPolicy: TOverflowPolicy;
    FBlockTimeoutMs: Cardinal;

    FNotifier: TBusNotifier;

    FTotalDispatched: Int64;
    FTotalEnqueued: Int64;
    FTotalProcessed: Int64;
    FTotalDropped: Int64;
    FTotalQueueLatencyMs: Int64;
    FProcessedCount: Int64;
    FMaxQueueObserved: Integer;

    procedure WorkerLoop;
    procedure ProcessPendingInvokesMethod;

    function AllocateSubscriberID: Integer;
    procedure ReleaseSubscriberReference(ASub: TEventSubscriber);

  public
    constructor Create(AWorkerCount: Integer = 4; AMaxQueueSize: Integer = 10000;
      AOverflow: TOverflowPolicy = opDropOldest; ABlockTimeoutMs: Cardinal = 5000);
    destructor Destroy; override;

    function Subscribe(AHandler: TAMIEventEvent; AOwner: TObject = nil;
      ACallInMainThread: Boolean = False; const AEventNameFilter: string = '';
      const AEventTypes: TAMIEventTypes = nil; AMinPriority: Integer = 0): Integer;
    procedure Unsubscribe(AID: Integer);
    procedure ClearSubscribersForOwner(AOwner: TObject);
    procedure Dispatch(const AEvent: TAMIEvent);
    function GetStats: string;
  end;

implementation

uses
  Math, SysUtils, StrUtils;

type
{==============================================================================}
{=== TWorkerThread ==========================================================}
{==============================================================================}

  TWorkerThread = class(TThread)
  private
    FOwnerBus: TThreadedEventBus;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwnerBus: TThreadedEventBus);
  end;

{==============================================================================}
{=== TWorkerThread ==========================================================}
{==============================================================================}

constructor TWorkerThread.Create(AOwnerBus: TThreadedEventBus);
begin
  inherited Create(False);
  FOwnerBus := AOwnerBus;
  FreeOnTerminate := False;
end;

procedure TWorkerThread.Execute;
begin
  if Assigned(FOwnerBus) then
    FOwnerBus.WorkerLoop;
end;

{==============================================================================}
{=== TBusNotifier ==========================================================}
{==============================================================================}

constructor TBusNotifier.Create(ABus: TThreadedEventBus);
begin
  inherited Create(nil);
  FBus := ABus;
end;

procedure TBusNotifier.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and Assigned(FBus) and Assigned(AComponent) then
  begin
    try
      FBus.ClearSubscribersForOwner(AComponent);
    except
      on E: Exception do
        AmiLog(llError, 'TBusNotifier.Notification exception: ' + E.ClassName + ': ' + E.Message);
    end;
  end;
end;

{==============================================================================}
{=== TThreadedEventBus ====================================================}
{==============================================================================}

constructor TThreadedEventBus.Create(AWorkerCount: Integer; AMaxQueueSize: Integer;
  AOverflow: TOverflowPolicy; ABlockTimeoutMs: Cardinal);
var
  i: Integer;
begin
  inherited Create;
  FSubscribers := specialize TList<TEventSubscriber>.Create;
  FSubscribersLock := TCriticalSection.Create;
  FPendingFree := specialize TList<TEventSubscriber>.Create;

  FQueue := TPriorityEventQueue.Create(AMaxQueueSize);
  FQueueEvent := TSimpleEvent.Create;

  FWorkers := specialize TList<TThread>.Create;
  FWorkerCount := Max(1, AWorkerCount);
  FWorkerTerminating := False;

  FInvokeQueue := specialize TList<TInvokeItem>.Create;
  FInvokeLock := TCriticalSection.Create;

  FNextID := 1;
  FOverflowPolicy := AOverflow;
  FBlockTimeoutMs := ABlockTimeoutMs;

  FTotalDispatched := 0;
  FTotalEnqueued := 0;
  FTotalProcessed := 0;
  FTotalDropped := 0;
  FTotalQueueLatencyMs := 0;
  FProcessedCount := 0;
  FMaxQueueObserved := 0;

  FNotifier := TBusNotifier.Create(self);

  for i := 1 to FWorkerCount do
    FWorkers.Add(TWorkerThread.Create(self));
end;

destructor TThreadedEventBus.Destroy;
var
  i: Integer;
  thr: TThread;
  tsk: TEventTask;
  inv: TInvokeItem;
  sub: TEventSubscriber;
begin
  FWorkerTerminating := True;
  if Assigned(FQueueEvent) then
    FQueueEvent.SetEvent;

  for i := FWorkers.Count - 1 downto 0 do
  begin
    thr := FWorkers[i];
    if Assigned(thr) then
    begin
      try thr.Terminate; except end;
      try thr.WaitFor; except end;
      try thr.Free; except end;
    end;
    FWorkers.Delete(i);
  end;
  FreeAndNil(FWorkers);

  if Assigned(FQueue) then
  begin
    tsk := FQueue.Dequeue;
    while Assigned(tsk) do
    begin
      try ReleaseSubscriberReference(tsk.Subscriber) except end;
      try tsk.Free; except end;
      tsk := FQueue.Dequeue;
    end;
    FreeAndNil(FQueue);
  end;
  FreeAndNil(FQueueEvent);

  if Assigned(FInvokeLock) then
  begin
    FInvokeLock.Acquire;
    try
      while FInvokeQueue.Count > 0 do
      begin
        inv := FInvokeQueue[0];
        if Assigned(inv) then
        begin
          if Assigned(inv.Event) then inv.Event.Free;
          try ReleaseSubscriberReference(inv.Subscriber) except end;
          inv.Free;
        end;
        FInvokeQueue.Delete(0);
      end;
    finally
      FInvokeLock.Release;
    end;
  end;
  FreeAndNil(FInvokeQueue);
  FreeAndNil(FInvokeLock);

  if Assigned(FSubscribersLock) then
  begin
    FSubscribersLock.Acquire;
    try
      for i := FPendingFree.Count - 1 downto 0 do
      begin
        sub := FPendingFree[i];
        try sub.Free; except end;
      end;
      FPendingFree.Clear;
    finally
      FSubscribersLock.Release;
    end;
  end;
  FreeAndNil(FPendingFree);

  if Assigned(FSubscribersLock) then
  begin
    FSubscribersLock.Acquire;
    try
      for i := FSubscribers.Count - 1 downto 0 do
      begin
        sub := FSubscribers[i];
        try sub.Free; except end;
      end;
      FSubscribers.Clear;
    finally
      FSubscribersLock.Release;
    end;
  end;
  FreeAndNil(FSubscribers);
  FreeAndNil(FSubscribersLock);

  FreeAndNil(FNotifier);

  inherited Destroy;
end;

function TThreadedEventBus.AllocateSubscriberID: Integer;
begin
  FSubscribersLock.Acquire;
  try
    Result := FNextID;
    Inc(FNextID);
  finally
    FSubscribersLock.Release;
  end;
end;

procedure TThreadedEventBus.ReleaseSubscriberReference(ASub: TEventSubscriber);
var
  idx: Integer;
begin
  if not Assigned(ASub) then Exit;
  FSubscribersLock.Acquire;
  try
    Dec(ASub.RefCount);
    if ASub.RefCount < 0 then ASub.RefCount := 0;
    if ASub.Deleted and (ASub.RefCount = 0) then
    begin
      idx := FPendingFree.IndexOf(ASub);
      if idx >= 0 then FPendingFree.Delete(idx);
      try ASub.Free; except end;
    end;
  finally
    FSubscribersLock.Release;
  end;
end;

function TThreadedEventBus.Subscribe(AHandler: TAMIEventEvent; AOwner: TObject;
  ACallInMainThread: Boolean; const AEventNameFilter: string;
  const AEventTypes: TAMIEventTypes; AMinPriority: Integer): Integer;
var
  sub: TEventSubscriber;
begin
  Result := -1;
  if not Assigned(AHandler) then Exit;

  sub := TEventSubscriber.Create(AHandler, AOwner, AEventNameFilter, AEventTypes, ACallInMainThread, AMinPriority);
  sub.ID := AllocateSubscriberID;

  FSubscribersLock.Acquire;
  try
    FSubscribers.Add(sub);
    Result := sub.ID;
  finally
    FSubscribersLock.Release;
  end;

  if Assigned(AOwner) and (AOwner is TComponent) and Assigned(FNotifier) then
  begin
    try
      TComponent(AOwner).FreeNotification(FNotifier);
    except
      on E: Exception do AmiLog(llWarning, 'Subscribe: FreeNotification failed: ' + E.Message);
    end;
  end;
end;

procedure TThreadedEventBus.Unsubscribe(AID: Integer);
var
  i: Integer;
  s: TEventSubscriber;
begin
  FSubscribersLock.Acquire;
  try
    for i := FSubscribers.Count - 1 downto 0 do
    begin
      s := FSubscribers[i];
      if s.ID = AID then
      begin
        FSubscribers.Delete(i);
        if s.RefCount = 0 then
        begin
          try s.Free; except end;
        end
        else
        begin
          s.Deleted := True;
          FPendingFree.Add(s);
        end;
        Break;
      end;
    end;
  finally
    FSubscribersLock.Release;
  end;
  AmiLog(llDebug, Format('TThreadedEventBus.Unsubscribe: id=%d', [AID]));
end;

procedure TThreadedEventBus.ClearSubscribersForOwner(AOwner: TObject);
var
  i: Integer;
  s: TEventSubscriber;
begin
  if AOwner = nil then Exit;
  FSubscribersLock.Acquire;
  try
    for i := FSubscribers.Count - 1 downto 0 do
    begin
      s := FSubscribers[i];
      if s.Owner = AOwner then
      begin
        FSubscribers.Delete(i);
        if s.RefCount = 0 then
        begin
          try s.Free; except end;
        end
        else
        begin
          s.Deleted := True;
          FPendingFree.Add(s);
        end;
      end;
    end;
  finally
    FSubscribersLock.Release;
  end;
end;

procedure TThreadedEventBus.Dispatch(const AEvent: TAMIEvent);
var
  snapshot: specialize TList<TEventSubscriber>;
  s: TEventSubscriber;
  cloned: TAMIEvent = nil;
  task: TEventTask = nil;
  idx: Integer;
  enqueueOK: Boolean;
begin
  if (AEvent = nil) then Exit;
  Inc(FTotalDispatched);

  snapshot := specialize TList<TEventSubscriber>.Create;
  try
    FSubscribersLock.Acquire;
    try
      for idx := 0 to FSubscribers.Count - 1 do
      begin
        s := FSubscribers[idx];
        if not Assigned(s) then Continue;
        if s.Deleted then Continue;
        try
          if s.MatchesEvent(AEvent) then
          begin
            Inc(s.RefCount);
            snapshot.Add(s);
          end;
        except
          on E: Exception do
          begin
            AmiLog(llError, Format('Dispatch: subscriber.MatchesEvent exception id=%d: %s', [s.ID, E.Message]));
            s.Deleted := True;
            FPendingFree.Add(s);
          end;
        end;
      end;
    finally
      FSubscribersLock.Release;
    end;

    for s in snapshot do
    begin
      cloned := nil;
      task := nil;
      try
        cloned := TAMIEventFactory.CreateEvent(AEvent.EventType);
        if not Assigned(cloned) then cloned := TAMIEvent.Create;
        cloned.Assign(AEvent);
        cloned.UpdateFromFields;

        task := TEventTask.Create(cloned, s);
        cloned := nil;

        enqueueOK := FQueue.Enqueue(task, FOverflowPolicy, FBlockTimeoutMs);
        if enqueueOK then
        begin
          Inc(FTotalEnqueued);
          FMaxQueueObserved := Max(FMaxQueueObserved, FQueue.Count);
          if Assigned(FQueueEvent) then FQueueEvent.SetEvent;
        end
        else
        begin
          Inc(FTotalDropped);
          ReleaseSubscriberReference(s);
          task.Free;
          task := nil;
        end;
      except
        on E: Exception do
        begin
          AmiLog(llError, Format('Dispatch: exception while enqueueing for sub id=%d: %s', [s.ID, E.Message]));
          if Assigned(task) then task.Free;
          if Assigned(cloned) then cloned.Free;
          ReleaseSubscriberReference(s);
        end;
      end;
    end;
  finally
    snapshot.Free;
  end;
end;

procedure TThreadedEventBus.WorkerLoop;
var
  task: TEventTask;
  latency: Int64;
  inv: TInvokeItem;
  s: TEventSubscriber;
begin
  while not FWorkerTerminating do
  begin
    if Assigned(FQueueEvent) then
      FQueueEvent.WaitFor(500);

    while not FWorkerTerminating do
    begin
      task := FQueue.Dequeue;
      if not Assigned(task) then Break;

      try
        s := task.Subscriber;
        latency := MilliSecondsBetween(Now, task.EnqueuedAt);
        Inc(FTotalQueueLatencyMs, latency);
        Inc(FProcessedCount);

        if (not Assigned(s)) or s.Deleted or not Assigned(s.Handler) then
        begin
          try ReleaseSubscriberReference(s) except end;
          task.Free;
          Continue;
        end;

        if s.CallInMainThread then
        begin
          inv := TInvokeItem.Create;
          inv.Subscriber := s;
          inv.Event := task.Event;
          task.Event := nil;
          task.Free;

          FInvokeLock.Acquire;
          try
            FInvokeQueue.Add(inv);
          finally
            FInvokeLock.Release;
          end;

          try
            TThread.Queue(nil, @Self.ProcessPendingInvokesMethod);
          except
            FInvokeLock.Enter;
            try
              if FInvokeQueue.IndexOf(inv) >= 0 then
                FInvokeQueue.Delete(FInvokeQueue.IndexOf(inv));
            finally
              FInvokeLock.Leave;
            end;
            try ReleaseSubscriberReference(s) except end;
            try inv.Free; except end;
            AmiLog(llError, 'WorkerLoop: TThread.Queue for ProcessPendingInvokesMethod failed');
          end;
        end
        else
        begin
          try
            try
              s.Handler(Self, task.Event);
            except
              on E: Exception do
              begin
                AmiLog(llError, 'Event handler exception (worker): ' + E.ClassName + ': ' + E.Message);
                try Unsubscribe(s.ID) except end;
              end;
            end;
          finally
            try ReleaseSubscriberReference(s) except end;
          end;
          task.Free;
        end;

        Inc(FTotalProcessed);
      except
        on E: Exception do
        begin
          AmiLog(llError, 'WorkerLoop processing exception: ' + E.ClassName + ': ' + E.Message);
          if Assigned(task) then
          begin
            try ReleaseSubscriberReference(task.Subscriber) except end;
            FreeAndNil(task);
          end;
        end;
      end;
    end;
  end;
end;

procedure TThreadedEventBus.ProcessPendingInvokesMethod;
var
  inv: TInvokeItem;
  s: TEventSubscriber;
  ownerObj: TObject;
begin
  while True do
  begin
    FInvokeLock.Acquire;
    try
      if FInvokeQueue.Count = 0 then Exit;
      inv := FInvokeQueue[0];
      FInvokeQueue.Delete(0);
    finally
      FInvokeLock.Release;
    end;

    if not Assigned(inv) then Continue;
    s := inv.Subscriber;
    if not Assigned(s) then
    begin
      if Assigned(inv.Event) then inv.Event.Free;
      inv.Free;
      Continue;
    end;

    if s.Deleted then
    begin
      try ReleaseSubscriberReference(s) except end;
      if Assigned(inv.Event) then inv.Event.Free;
      inv.Free;
      Continue;
    end;

    ownerObj := s.Owner;
    if Assigned(ownerObj) and (ownerObj is TComponent) then
    begin
      if (csDestroying in TComponent(ownerObj).ComponentState) then
      begin
        try ReleaseSubscriberReference(s) except end;
        if Assigned(inv.Event) then inv.Event.Free;
        inv.Free;
        Continue;
      end;
    end;

    try
      try
        if Assigned(ownerObj) then
          s.Handler(ownerObj, inv.Event)
        else
          s.Handler(Self, inv.Event);
      except
        on E: Exception do
        begin
          AmiLog(llError, 'Event handler exception (main): ' + E.ClassName + ': ' + E.Message);
          try Unsubscribe(s.ID) except end;
        end;
      end;
    finally
      try ReleaseSubscriberReference(s) except end;
      if Assigned(inv.Event) then inv.Event.Free;
      inv.Free;
    end;
  end;
end;

function TThreadedEventBus.GetStats: string;
var
  avgLatency: Double;
  qsize: Integer;
begin
  if FProcessedCount > 0 then
    avgLatency := FTotalQueueLatencyMs / FProcessedCount
  else
    avgLatency := 0;

  qsize := 0;
  if Assigned(FQueue) then qsize := FQueue.Count;

  Result := Format('EventBus stats: dispatched=%d enqueued=%d processed=%d dropped=%d current_queue=%d max_observed=%d avg_latency_ms=%.1f',
    [FTotalDispatched, FTotalEnqueued, FTotalProcessed, FTotalDropped, qsize, FMaxQueueObserved, avgLatency]);
end;

end.
