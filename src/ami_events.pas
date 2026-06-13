unit ami_events;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, ami_types, syncobjs, ami_enums, ami_log;

type
  TAMIEventHandler = class(TObject)
  private
    FEventName: String;
    FOnEvent: TAMIEventEvent;
    FEnabled: Boolean;
  public
    constructor Create(const AEventName: String; AOnEvent: TAMIEventEvent);
    property EventName: String read FEventName;
    property OnEvent: TAMIEventEvent read FOnEvent write FOnEvent;
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

  TAMIEventManager = class(TObject)
  private
    FHandlers: TFPObjectList;
    FEventFilters: TStringList;
    FDefaultHandler: TAMIEventEvent;
    FLock: TCriticalSection;
    procedure SetEventFilter(const AEventName: String; AInclude: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddHandler(const AEventName: String; AOnEvent: TAMIEventEvent);
    procedure RemoveHandler(const AEventName: String);
    procedure ClearHandlers;
    function ProcessEvent(const AEvent: TAMIEvent): Boolean;
    procedure AddIncludeFilter(const AEventName: String);
    procedure AddExcludeFilter(const AEventName: String);
    procedure ClearFilters;
    function IsEventAllowed(const AEventName: String): Boolean;
    property DefaultHandler: TAMIEventEvent read FDefaultHandler write FDefaultHandler;
  end;

  TAMIEventProcessor = class(TObject)
  private
    FEventManager: TAMIEventManager;
    FOnLog: TAMILogEvent;
    procedure DoLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
  public
    constructor Create(AEventManager: TAMIEventManager);
    procedure ProcessMessage(const AMessage: TAMIMessage);
    procedure ProcessEvent(const AEvent: TAMIEvent);
    property OnLog: TAMILogEvent read FOnLog write FOnLog;
  end;

implementation

{==============================================================================}
{=== TAMIEventHandler ========================================================}
{==============================================================================}

constructor TAMIEventHandler.Create(const AEventName: String; AOnEvent: TAMIEventEvent);
begin
  inherited Create;
  FEventName := AEventName;
  FOnEvent := AOnEvent;
  FEnabled := True;
end;

{==============================================================================}
{=== TAMIEventManager =========================================================}
{==============================================================================}

constructor TAMIEventManager.Create;
begin
  inherited Create;
  FHandlers := TFPObjectList.Create(True);
  FEventFilters := TStringList.Create;
  FEventFilters.CaseSensitive := False;
  FLock := TCriticalSection.Create;
end;

destructor TAMIEventManager.Destroy;
begin
  FLock.Enter;
  try
    FreeAndNil(FHandlers);
    FreeAndNil(FEventFilters);
  finally
    FLock.Leave;
  end;
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure TAMIEventManager.AddHandler(const AEventName: String; AOnEvent: TAMIEventEvent);
var
  Handler: TAMIEventHandler;
begin
  FLock.Enter;
  try
    Handler := TAMIEventHandler.Create(AEventName, AOnEvent);
    FHandlers.Add(Handler);
  finally
    FLock.Leave;
  end;
end;

procedure TAMIEventManager.RemoveHandler(const AEventName: String);
var
  i: Integer;
  Handler: TAMIEventHandler;
begin
  FLock.Enter;
  try
    for i := FHandlers.Count - 1 downto 0 do
    begin
      Handler := TAMIEventHandler(FHandlers[i]);
      if SameText(Handler.EventName, AEventName) then
      begin
        FHandlers.Delete(i);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TAMIEventManager.ClearHandlers;
begin
  FLock.Enter;
  try
    FHandlers.Clear;
  finally
    FLock.Leave;
  end;
end;

function TAMIEventManager.ProcessEvent(const AEvent: TAMIEvent): Boolean;
var
  i: Integer;
  Handler: TAMIEventHandler;
  EventName: String;
  HandlersCopy: TList;
begin
  Result := False;
  EventName := AEvent.GetField('Event');

  if not IsEventAllowed(EventName) then
    Exit;

  HandlersCopy := TList.Create;
  try
    FLock.Enter;
    try
      for i := 0 to FHandlers.Count - 1 do
      begin
        Handler := TAMIEventHandler(FHandlers[i]);
        if SameText(Handler.EventName, EventName) and Handler.Enabled then
          HandlersCopy.Add(Handler);
      end;
    finally
      FLock.Leave;
    end;

    for i := 0 to HandlersCopy.Count - 1 do
    begin
      Handler := TAMIEventHandler(HandlersCopy[i]);
      if Assigned(Handler.OnEvent) then
      begin
        try
          Handler.OnEvent(nil, AEvent);
          Result := True;
        except
          on E: Exception do
          begin
          end;
        end;
      end;
    end;

    if not Result and Assigned(FDefaultHandler) then
    begin
      try
        FDefaultHandler(nil, AEvent);
        Result := True;
      except
        on E: Exception do
        begin
        end;
      end;
    end;
  finally
    FreeAndNil(HandlersCopy);
  end;
end;

procedure TAMIEventManager.SetEventFilter(const AEventName: String; AInclude: Boolean);
var
  FilterValue: String;
begin
  FilterValue := AEventName;
  if not AInclude then
    FilterValue := '!' + FilterValue;

  FLock.Enter;
  try
    FEventFilters.Add(FilterValue);
  finally
    FLock.Leave;
  end;
end;

procedure TAMIEventManager.AddIncludeFilter(const AEventName: String);
begin
  SetEventFilter(AEventName, True);
end;

procedure TAMIEventManager.AddExcludeFilter(const AEventName: String);
begin
  SetEventFilter(AEventName, False);
end;

procedure TAMIEventManager.ClearFilters;
begin
  FLock.Enter;
  try
    FEventFilters.Clear;
  finally
    FLock.Leave;
  end;
end;

function TAMIEventManager.IsEventAllowed(const AEventName: String): Boolean;
var
  i: Integer;
  Filter: String;
  Exclude: Boolean;
  FilterName: String;
begin
  FLock.Enter;
  try
    Result := True;
    if FEventFilters.Count = 0 then
      Exit;

    Result := False;

    for i := 0 to FEventFilters.Count - 1 do
    begin
      Filter := FEventFilters[i];
      if Length(Filter) > 0 then
      begin
        if Filter[1] = '!' then
        begin
          Exclude := True;
          FilterName := Copy(Filter, 2, MaxInt);
        end
        else
        begin
          Exclude := False;
          FilterName := Filter;
        end;

        if SameText(FilterName, AEventName) then
        begin
          if Exclude then
          begin
            Result := False;
            Exit;
          end
          else
          begin
            Result := True;
          end;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

{==============================================================================}
{=== TAMIEventProcessor =======================================================}
{==============================================================================}

constructor TAMIEventProcessor.Create(AEventManager: TAMIEventManager);
begin
  inherited Create;
  FEventManager := AEventManager;
end;

procedure TAMIEventProcessor.DoLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Level, Msg);
end;

procedure TAMIEventProcessor.ProcessMessage(const AMessage: TAMIMessage);
begin
  if AMessage.MessageType = mtEvent then
  begin
    ProcessEvent(TAMIEvent(AMessage));
  end;
end;

procedure TAMIEventProcessor.ProcessEvent(const AEvent: TAMIEvent);
begin
  //DoLog(Self, llDebug, 'Processing event: ' + AEvent.GetField('Event'));
  if Assigned(FEventManager) then
    FEventManager.ProcessEvent(AEvent);
end;

end.
