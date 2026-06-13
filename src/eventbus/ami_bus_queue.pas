unit ami_bus_queue;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Generics.Collections, DateUtils,
  ami_event_types, ami_enums;

type
  TOverflowPolicy = (opDropOldest, opDropNewest, opBlock);

{==============================================================================}
{=== TPriorityEventQueue ==================================================}
{==============================================================================}

  TPriorityEventQueue = class
  private
    FList: specialize TList<TEventTask>;
    FLock: TCriticalSection;
    FMaxSize: Integer;
  public
    constructor Create(AMaxSize: Integer = 10000);
    destructor Destroy; override;

    function Enqueue(ATask: TEventTask; APolicy: TOverflowPolicy; ABlockTimeoutMs: Cardinal = 5000): Boolean;
    function Dequeue: TEventTask;
    function Count: Integer;
    procedure Clear;
    property MaxSize: Integer read FMaxSize write FMaxSize;
  end;

implementation

uses
  Math;

{==============================================================================}
{=== TPriorityEventQueue ==================================================}
{==============================================================================}

constructor TPriorityEventQueue.Create(AMaxSize: Integer);
begin
  inherited Create;
  FList := specialize TList<TEventTask>.Create;
  FLock := TCriticalSection.Create;
  FMaxSize := Max(1, AMaxSize);
end;

destructor TPriorityEventQueue.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  FreeAndNil(FLock);
  inherited Destroy;
end;

function TPriorityEventQueue.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FList.Count;
  finally
    FLock.Release;
  end;
end;

procedure TPriorityEventQueue.Clear;
var
  i: Integer;
begin
  FLock.Acquire;
  try
    for i := 0 to FList.Count - 1 do
      TEventTask(FList[i]).Free;
    FList.Clear;
  finally
    FLock.Release;
  end;
end;

function TPriorityEventQueue.Dequeue: TEventTask;
begin
  Result := nil;
  FLock.Acquire;
  try
    if FList.Count > 0 then
    begin
      Result := TEventTask(FList[0]);
      FList.Delete(0);
    end;
  finally
    FLock.Release;
  end;
end;

function TPriorityEventQueue.Enqueue(ATask: TEventTask; APolicy: TOverflowPolicy; ABlockTimeoutMs: Cardinal): Boolean;
var
  startTick: TDateTime;
  oldestIdx, idx: Integer;
  oldestTime: TDateTime;
  droppedTask: TEventTask;
  inserted: Boolean;
begin
  Result := False;
  if not Assigned(ATask) then Exit;

  startTick := Now;
  inserted := False;
  droppedTask := nil;

  while not inserted do
  begin
    FLock.Acquire;
    try
      if FList.Count < FMaxSize then
      begin
        idx := 0;
        while (idx < FList.Count) and (TEventTask(FList[idx]).EventPriority >= ATask.EventPriority) do
          Inc(idx);
        FList.Insert(idx, ATask);
        Result := True;
        inserted := True;
      end
      else
      begin
        case APolicy of
          opDropNewest:
            begin
              Result := False;
              inserted := True;
            end;

          opDropOldest:
            begin
              oldestIdx := -1;
              oldestTime := MaxDateTime;
              for idx := 0 to FList.Count - 1 do
                if TEventTask(FList[idx]).EnqueuedAt < oldestTime then
                begin
                  oldestTime := TEventTask(FList[idx]).EnqueuedAt;
                  oldestIdx := idx;
                end;
              if oldestIdx >= 0 then
              begin
                droppedTask := TEventTask(FList[oldestIdx]);
                FList.Delete(oldestIdx);
                idx := 0;
                while (idx < FList.Count) and (TEventTask(FList[idx]).EventPriority >= ATask.EventPriority) do
                  Inc(idx);
                FList.Insert(idx, ATask);
                Result := True;
                inserted := True;
              end
              else
              begin
                Result := False;
                inserted := True;
              end;
            end;

          opBlock:
            begin
            end;
        end;
      end;
    finally
      FLock.Release;
    end;

    if Assigned(droppedTask) then
    begin
      try
        droppedTask.Free;
      except
      end;
      droppedTask := nil;
    end;

    if inserted then Break;

    if APolicy = opBlock then
    begin
      if MilliSecondsBetween(Now, startTick) >= Integer(ABlockTimeoutMs) then
      begin
        Result := False;
        Break;
      end;
      Sleep(5);
      Continue;
    end
    else
      Break;
  end;
end;

end.
