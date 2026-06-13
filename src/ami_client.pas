unit ami_client;

{$mode objfpc}{$H+}
{$DEFINE CACHE}

interface

uses
  Classes, SysUtils, syncobjs, ami_types, ami_parser, ami_actions, ami_cache,
  ami_events, ami_connection, ami_utils, Math, typinfo, DateUtils,
  StrUtils, ami_enums, ami_action_factory, ami_bus, ami_log, ami_exceptions;

type
  TAMIClient = class;

  TKeepAliveThread = class(TThread)
  private
    FClient: TAMIClient;
    FStopEvent: TSimpleEvent;
    FLastPingTime: TDateTime;
    FPingFailures: integer;
    procedure DoLog(Sender: TObject; Level: TAMILogLevel; const Msg: string);
    function ShouldSendPing: boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AClient: TAMIClient; AStopEvent: TSimpleEvent);
  end;

  TReconnectThread = class(TThread)
  private
    FClient: TAMIClient;
    FStopEvent: TSimpleEvent;
    FAttempts: integer;
    FLastAttemptTime: TDateTime;
    procedure DoLog(Sender: TObject; Level: TAMILogLevel; const Msg: string);
    procedure DoConnect;
    function GetBackoffDelay: integer;
  protected
    procedure Execute; override;
  public
    constructor Create(AClient: TAMIClient; AStopEvent: TSimpleEvent);
  end;

  TAMIClient = class(TObject)
  private
    FConfig: TAMIClientConfig;
    FTransport: TAMITransport;
    FPacketReader: TAMIPacketReader;
    FEventManager: TAMIEventManager;
    FEventProcessor: TAMIEventProcessor;
    FPendingActions: TThreadList;
    FPendingLock: TCriticalSection;
    FSendLock: TCriticalSection;
    FProcessLock: TCriticalSection;
    FDestroyLock: TCriticalSection;
    FStatus: TAMIClientStatus;
    FReconnectTimer: TReconnectThread;
    FKeepAliveTimer: TKeepAliveThread;
    FDestroying: integer;
    FKAStopEvent: TSimpleEvent;
    FRCStopEvent: TSimpleEvent;
    FAuthenticating: boolean;
    FEventCache: TAMIEventCache;
    FResponseCache: TAMIResponseCache;
    FConnectTime: TDateTime;
    FLastEventTime: TDateTime;
    FTotalEvents: int64;
    FTotalActions: int64;
    FFailedActions: int64;
    FLastActionTime: TDateTime;
    FActionRateLimitCount: integer;
    FCurrentRetryCount: integer;
    FOnConnect: TAMIConnectEvent;
    FOnDisconnect: TAMIDisconnectEvent;
    FOnLog: TAMILogEvent;
    FOnEvent: TAMIEventEvent;
    FOnResponse: TAMIResponseEvent;
    FOnActionResponse: TAMIResponseEvent;

    procedure SetStatus(AStatus: TAMIClientStatus);
    procedure DoConnect;
    procedure DoDisconnect;
    procedure HandleTransportDisconnect(Sender: TObject);
    function AddPendingAction(AAction: TAMIAction;
      AOnResponse: TAMIResponseEvent = nil): string;
    procedure RemovePendingAction(const AActionID: string);
    function GetPendingAction(const AActionID: string): TPendingAction;
    procedure CleanupExpiredPendingActions;
    function IsMultiEventAction(AAction: TAMIAction): Boolean;
    function IsFollowUpEventName(const AEventName: string): Boolean;
    function IsCompletionEventName(const AEventName: string): Boolean;
    procedure ProcessMessages;
    procedure ProcessMessage(const AMessage: TAMIMessage);
    procedure ProcessResponse(const AResponse: TAMIResponse);
    procedure ProcessEvent(const AEvent: TAMIEvent);
    procedure StartKeepAlive;
    procedure StopKeepAlive;
    procedure StartReconnect;
    procedure StopReconnect;
    function Authenticate: boolean;
    function PerformMD5Auth: boolean;
    function PerformPlainAuth: boolean;
    function ValidateConfig: boolean;
    function CheckRateLimit: boolean;

  public
    constructor Create(const AConfig: TAMIClientConfig);
    destructor Destroy; override;
    function IsDestroying: boolean;

    { Connects to the AMI server using the configured host and port.
      Performs validation, TLS setup if configured, and authentication.
      Returns True if connected successfully, False otherwise. }
    function Connect: boolean;

    { Disconnects from the AMI server gracefully.
      Stops keep-alive, reconnect threads and closes transport connection. }
    procedure Disconnect;

    { Checks if client is currently connected and authenticated.
      @returns True if connected, False otherwise. }
    function IsConnected: boolean;

    { Returns a string with connection details including host, port,
      connection duration, bytes sent/received. }
    function GetConnectionInfo: string;

    { Sends an action to the AMI server and waits for response.
      @param AAction The action to send.
      @param ATimeout Timeout in milliseconds (default 30000).
      @returns TAMIResponse or nil on failure. }
    function SendAction(const AAction: TAMIAction;
      ATimeout: integer = 30000): TAMIResponse;

    { Sends an action asynchronously without waiting for response.
      @param AAction The action to send.
      @param AOnResponse Callback when response is received.
      @returns ActionID string or empty string on failure. }
    function SendActionAsync(const AAction: TAMIAction;
      AOnResponse: TAMIResponseEvent): string;
    function SendCachedAction(const AAction: TAMIAction; const ACacheKey: string;
      ATimeout: integer = 30000): TAMIResponse;
    function CachedQueueStatus(const AQueueName: string = '';
      ATimeout: integer = 30000): TAMIResponse;
    function Originate(const AParams: TOriginateParams;
      ATimeout: integer = 30000): TAMIResponse;
    function Hangup(const AChannel: string; ACause: integer = 16;
      ATimeout: integer = 30000): TAMIResponse;
    function Command(const ACommand: string; ATimeout: integer = 30000): TAMIResponse;
    function QueueAdd(const AQueueName, AMember: string;
      ATimeout: integer = 30000): TAMIResponse;
    function QueueRemove(const AQueueName, AMember: string;
      ATimeout: integer = 30000): TAMIResponse;
    function QueueStatus(const AQueueName: string = '';
      ATimeout: integer = 30000): TAMIResponse;

    { Sends a Ping action to keep the connection alive.
      @param ATimeout Timeout in milliseconds (default 10000).
      @returns TAMIResponse with Pong on success. }
    function Ping(ATimeout: integer = 10000): TAMIResponse;

    { Redirects a channel to a new context/extension.
      @param AChannel Channel to redirect.
      @param AContext Destination context.
      @param AExtension Destination extension.
      @param APriority Priority to use (default 1).
      @param AExtraChannel Optional extra channel.
      @param ATimeout Timeout in milliseconds.
      @returns TAMIResponse indicating success/failure. }
    function Redirect(const AChannel, AContext, AExtension: string;
      APriority: integer = 1; AExtraChannel: string = '';
      ATimeout: integer = 30000): TAMIResponse;
    function BridgeInfo(const ABridgeUniqueID: string;
      ATimeout: integer = 30000): TAMIResponse;
    function GetVar(const AChannel, AVariable: string;
      ATimeout: integer = 30000): TAMIResponse;
    function SetVar(const AChannel, AVariable, AValue: string;
      ATimeout: integer = 30000): TAMIResponse;
    function BridgeList(ATimeout: integer = 30000): TAMIResponse;
    function ChannelList(ATimeout: integer = 30000): TAMIResponse;
    function PeerStatus(const APeer: string = '';
      ATimeout: integer = 30000): TAMIResponse;
    function PeerStatusEx(const APeer: string; const AProtocol: string = 'SIP';
      ATimeout: integer = 30000): TAMIResponse;
    function DeviceStateList(ATimeout: integer = 30000): TAMIResponse;
    procedure SubscribeToEvent(const AEventName: string; AOnEvent: TAMIEventEvent);
    procedure UnsubscribeFromEvent(const AEventName: string);
    procedure AddEventFilter(const AEventName: string; AInclude: boolean = True);
    procedure ClearEventFilters;
    procedure SetEventMask(const AMask: string);
    procedure ProcessPendingMessages;
    procedure ProcessPendingPriorityMessages;
    function HasPendingMessages: boolean;
    function HasPendingPriorityMessages: boolean;
    function GetStatistics: string;
    function GetUptime: integer;
    function GetUptimeMs: int64;
    function GetUptimeStr: string;
    function GetEventsPerSecond: double;
    function GetActionsPerSecond: double;
    procedure ClearCaches;
    procedure CleanupCaches(AMaxAgeMinutes: integer = 60);
    function GetEventCacheStats: string;
    function GetResponseCacheStats: string;
    procedure DoLog(Sender: TObject; Level: TAMILogLevel; const Msg: string); overload;
    procedure DoLog(const Msg: string; Level: TAMILogLevel = llInfo); overload;
    property Status: TAMIClientStatus read FStatus;
    property Config: TAMIClientConfig read FConfig;
    property TotalEvents: int64 read FTotalEvents;
    property TotalActions: int64 read FTotalActions;
    property FailedActions: int64 read FFailedActions;
    property ConnectTime: TDateTime read FConnectTime;
    property OnConnect: TAMIConnectEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TAMIDisconnectEvent read FOnDisconnect write FOnDisconnect;
    property OnLog: TAMILogEvent read FOnLog write FOnLog;
    property OnEvent: TAMIEventEvent read FOnEvent write FOnEvent;
    property OnResponse: TAMIResponseEvent read FOnResponse write FOnResponse;
    property OnActionResponse: TAMIResponseEvent read FOnActionResponse write FOnActionResponse;
    function SubscribeToEventAsync(const AEventName: String; AHandler: TAMIEventEvent;
      ACallInMainThread: Boolean = False; AOwner: TObject = nil): Integer;
    procedure UnsubscribeFromEventAsync(AID: Integer);
  end;

implementation

{ TKeepAliveThread }

constructor TKeepAliveThread.Create(AClient: TAMIClient; AStopEvent: TSimpleEvent);
begin
  FClient := AClient;
  FStopEvent := AStopEvent;
  FLastPingTime := 0;
  FPingFailures := 0;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TKeepAliveThread.DoLog(Sender: TObject; Level: TAMILogLevel;
  const Msg: string);
begin
  if Assigned(FClient) then
    FClient.DoLog(Self, Level, Msg);
end;

function TKeepAliveThread.ShouldSendPing: boolean;
var
  TimeSinceLastPing: double;
  PingInterval: integer;
begin
  TimeSinceLastPing := (Now - FLastPingTime) * 24 * 60 * 60;
  PingInterval := FClient.FConfig.PingInterval;
  if FPingFailures > 0 then
    PingInterval := Max(PingInterval div 2, 10);
  Result := (FLastPingTime = 0) or (TimeSinceLastPing >= PingInterval);
end;

procedure TKeepAliveThread.Execute;
var
  PingAction: TAMIPingAction;
  Response: TAMIResponse;
  InitialDelay: integer;
  pingTimeoutMs: integer;
begin
  DoLog(Self, llDebug, 'Keep-alive thread started');

  if not Assigned(FClient) then Exit;

  InitialDelay := Max(1, FClient.FConfig.PingInterval) * 1000;
  if Assigned(FStopEvent) and (FStopEvent.WaitFor(InitialDelay) = wrSignaled) then
    Exit;

  while not Terminated do
  begin
    if Assigned(FStopEvent) and (FStopEvent.WaitFor(500) = wrSignaled) then
      Break;

    if not Assigned(FClient) or FClient.IsDestroying then
      Break;

    if FClient.IsConnected and ShouldSendPing then
    begin
      PingAction := TAMIPingAction.Create;
      Response := nil;
      try
        pingTimeoutMs := FClient.FConfig.PingTimeout;
        if pingTimeoutMs <= 0 then
          pingTimeoutMs := FClient.FConfig.ResponseTimeout;
        if pingTimeoutMs <= 0 then
          pingTimeoutMs := 10000;

        Response := FClient.SendAction(PingAction, pingTimeoutMs);

        if Assigned(Response) then
        begin
          try
            if Response.IsSuccess then
            begin
              FPingFailures := 0;
            end
            else
            begin
              Inc(FPingFailures);
              DoLog(Self, llWarning, Format('Keep-alive ping failed: %s (failures: %d)',
                [Response.Message, FPingFailures]));
            end;
          finally
            FreeAndNil(Response);
          end;
        end
        else
        begin
          Inc(FPingFailures);
          DoLog(Self, llError, Format('Keep-alive ping timeout (failures: %d)', [FPingFailures]));
          if FPingFailures >= 3 then
          begin
            DoLog(Self, llError, 'Too many ping failures, disconnecting');
            try FClient.Disconnect; except end;
            Break;
          end;
        end;
      finally
        FreeAndNil(PingAction);
      end;

      FLastPingTime := Now;
    end;
  end;

  DoLog(Self, llDebug, 'Keep-alive thread finished');
end;

{ TReconnectThread }

constructor TReconnectThread.Create(AClient: TAMIClient; AStopEvent: TSimpleEvent);
begin
  FClient := AClient;
  FStopEvent := AStopEvent;
  FAttempts := 0;
  FLastAttemptTime := 0;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TReconnectThread.DoLog(Sender: TObject; Level: TAMILogLevel;
  const Msg: string);
begin
  if Assigned(FClient) then
    FClient.DoLog(Self, Level, Msg);
end;

procedure TReconnectThread.DoConnect;
begin
  if Assigned(FClient) and not FClient.IsDestroying then
  begin
    if FClient.Connect then
      FClient.FConnectTime := Now;
  end;
end;

function TReconnectThread.GetBackoffDelay: integer;
begin
  if FClient.FConfig.ReconnectBackoff then
  begin
    Result := Min(FClient.FConfig.ReconnectInterval * (1 shl Min(FAttempts, 6)), 60000);
  end
  else
  begin
    Result := FClient.FConfig.ReconnectInterval;
  end;
end;

procedure TReconnectThread.Execute;
var
  Delay: integer;
  TimeSinceLastAttempt: double;
begin
  DoLog(Self, llInfo, 'Reconnection thread started');

  while not Terminated and ((FClient.FConfig.MaxReconnectAttempts = 0) or
      (FAttempts < FClient.FConfig.MaxReconnectAttempts)) do
  begin
    if FStopEvent.WaitFor(1000) = wrSignaled then
      Break;

    if not Assigned(FClient) or FClient.IsDestroying then
      Break;

    TimeSinceLastAttempt := (Now - FLastAttemptTime) * 24 * 60 * 60 * 1000;
    Delay := GetBackoffDelay;

    if (FLastAttemptTime = 0) or (TimeSinceLastAttempt >= Delay) then
    begin
      Inc(FAttempts);
      FLastAttemptTime := Now;

      DoLog(Self, llInfo, Format('Reconnection attempt %d/%d (delay: %dms)',
        [FAttempts, FClient.FConfig.MaxReconnectAttempts, Delay]));

      DoConnect;

      if FClient.IsConnected then
      begin
        DoLog(Self, llInfo, 'Reconnection successful');
        Break;
      end;
    end;
  end;

  if (FClient.FConfig.MaxReconnectAttempts > 0) and
    (FAttempts >= FClient.FConfig.MaxReconnectAttempts) then
    DoLog(Self, llError, 'Maximum reconnection attempts reached');

  DoLog(Self, llDebug, 'Reconnection thread finished');
end;

{ TAMIClient }

{==============================================================================}
{=== Construction / Destruction ===============================================}
{==============================================================================}

constructor TAMIClient.Create(const AConfig: TAMIClientConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FStatus := csDisconnected;
  FDestroying := 0;
  FAuthenticating := False;
  FConnectTime := 0;
  FLastEventTime := 0;
  FTotalEvents := 0;
  FTotalActions := 0;
  FFailedActions := 0;
  FTransport := TAMITransport.Create(FConfig);
  FEventManager := TAMIEventManager.Create;
  FEventProcessor := TAMIEventProcessor.Create(FEventManager);
  FPendingActions := TThreadList.Create;
  FPendingLock := TCriticalSection.Create;
  FSendLock := TCriticalSection.Create;
  FProcessLock := TCriticalSection.Create;
  FDestroyLock := TCriticalSection.Create;
  FKAStopEvent := TSimpleEvent.Create;
  FRCStopEvent := TSimpleEvent.Create;
  FEventCache := TAMIEventCache.Create(500);
  FResponseCache := TAMIResponseCache.Create(300, 200);
  FEventProcessor.OnLog := @DoLog;
  FTransport.OnLog := @DoLog;
  FPacketReader := TAMIPacketReader.Create(FTransport);
  FPacketReader.OnDisconnected := @HandleTransportDisconnect;
  FPacketReader.OnLog := @DoLog;
  FLastActionTime := 0;
  FActionRateLimitCount := 0;
  FCurrentRetryCount := 0;
  DoLog(Self, llInfo, 'AMI Client created with enhanced real-time capabilities');
end;

destructor TAMIClient.Destroy;
var
  List: TList;
  i: integer;
begin
  InterlockedExchange(FDestroying, 1);
  Sleep(10);
  DoLog(Self, llInfo, 'AMI Client shutting down...');
  StopKeepAlive;
  StopReconnect;
  Disconnect;
  FPendingLock.Enter;
  try
    List := FPendingActions.LockList;
    try
      for i := 0 to List.Count - 1 do
        TPendingAction(List[i]).Free;
      List.Clear;
    finally
      FPendingActions.UnlockList;
    end;
  finally
    FPendingLock.Leave;
  end;
  FreeAndNil(FPendingActions);
  FreeAndNil(FEventProcessor);
  FreeAndNil(FEventManager);
  FreeAndNil(FEventCache);
  FreeAndNil(FResponseCache);
  FreeAndNil(FPacketReader);
  FreeAndNil(FTransport);
  FreeAndNil(FKAStopEvent);
  FreeAndNil(FRCStopEvent);
  FreeAndNil(FPendingLock);
  FreeAndNil(FSendLock);
  FreeAndNil(FProcessLock);
  FreeAndNil(FDestroyLock);
  DoLog(Self, llInfo, 'AMI Client destroyed');
  inherited Destroy;
end;

function TAMIClient.IsDestroying: boolean;
begin
  Result := InterlockedCompareExchange(FDestroying, 0, 0) = 1;
end;

{==============================================================================}
{=== Connection Management ====================================================}
{==============================================================================}

procedure TAMIClient.SetStatus(AStatus: TAMIClientStatus);
var
  OldStatus: TAMIClientStatus;
  ConnEvent: TAMIEvent;
  StateStr: string;
begin
  FProcessLock.Enter;
  try
    OldStatus := FStatus;
    if FStatus <> AStatus then
      FStatus := AStatus
    else
      Exit;
  finally
    FProcessLock.Leave;
  end;

  case AStatus of
    csConnected: StateStr := 'Connected';
    csDisconnected: StateStr := 'Disconnected';
    csConnecting: StateStr := 'Connecting';
    csAuthenticating: StateStr := 'Authenticating';
    csAuthFailed: StateStr := 'AuthFailed';
  else
    StateStr := GetEnumName(TypeInfo(TAMIClientStatus), Ord(AStatus));
  end;

  DoLog(Self, llInfo, Format('Status changed: %s -> %s',
    [GetEnumName(TypeInfo(TAMIClientStatus), Ord(OldStatus)),
     GetEnumName(TypeInfo(TAMIClientStatus), Ord(AStatus))]));

  if Assigned(AMIEventBus) then
  begin
    ConnEvent := TAMIEvent.Create;
    try
      ConnEvent.AddField('Event', 'AmiConnection');
      ConnEvent.AddField('State', StateStr);
      ConnEvent.AddField('Host', FConfig.Host);
      ConnEvent.AddField('Port', IntToStr(FConfig.Port));
      ConnEvent.AddField('Timestamp', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      try
        AMIEventBus.Dispatch(ConnEvent);
      except
        on E: Exception do
          DoLog(Self, llWarning, 'AMIEventBus.Dispatch failed for AmiConnection: ' + E.Message);
      end;
    finally
      ConnEvent.Free;
    end;
  end;

  case AStatus of
    csConnected:
    begin
      FConnectTime := Now;
      if Assigned(FOnConnect) then
        FOnConnect(Self);
    end;
    csDisconnected:
    begin
      FConnectTime := 0;
      if Assigned(FOnDisconnect) then
        FOnDisconnect(Self);
    end;
  end;
end;

procedure TAMIClient.DoLog(const Msg: string; Level: TAMILogLevel);
begin
  DoLog(Self, Level, Msg);
end;

procedure TAMIClient.DoLog(Sender: TObject; Level: TAMILogLevel; const Msg: string);
begin
  if Assigned(FOnLog) and not IsDestroying then
    FOnLog(Self, Level, Msg);
end;

procedure TAMIClient.DoConnect;
begin
  if Assigned(FOnConnect) and not IsDestroying then
    FOnConnect(Self);
end;

procedure TAMIClient.DoDisconnect;
begin
  if Assigned(FOnDisconnect) and not IsDestroying then
    FOnDisconnect(Self);
end;

function TAMIClient.Connect: boolean;
begin
  Result := False;

  if IsDestroying then
    Exit;

  if FStatus in [csConnecting, csConnected] then
  begin
    DoLog(Self, llWarning, 'Already connected or connecting');
    Exit(FStatus = csConnected);
  end;

  if not ValidateConfig then
    Exit;

  SetStatus(csConnecting);
  DoLog(Self, llInfo, Format('Connecting to %s:%d', [FConfig.Host, FConfig.Port]));

  if FTransport.Connect then
  begin
    DoLog(Self, llInfo, 'Connected to AMI server');
    FPacketReader.Start;
    DoLog(Self, llInfo, 'Waiting for reader thread to initialize...');
    Sleep(500);

    FAuthenticating := True;
    try
      SetStatus(csAuthenticating);
      DoLog(Self, llInfo, 'Starting authentication...');

      if Authenticate then
      begin
        SetStatus(csConnected);
        FConnectTime := Now;
        DoLog(Self, llInfo, 'Successfully authenticated');
        StartKeepAlive;
        Result := True;
      end
      else
      begin
        SetStatus(csAuthFailed);
        DoLog(Self, llError, 'Authentication failed: ' + FTransport.LastError);
        FTransport.Disconnect;
      end;
    finally
      FAuthenticating := False;
    end;
  end
  else
  begin
    SetStatus(csDisconnected);
    DoLog(Self, llError, 'Connection failed: ' + FTransport.LastError);
  end;
end;

function TAMIClient.ValidateConfig: boolean;
var
  Errors: string;
begin
  Result := True;
  Errors := '';
  
  if FConfig.Host = '' then
    Errors := Errors + 'Host cannot be empty' + LineEnding;
  if FConfig.Port = 0 then
    Errors := Errors + 'Port cannot be 0' + LineEnding;
  if FConfig.Username = '' then
    Errors := Errors + 'Username cannot be empty' + LineEnding;
  if FConfig.Password = '' then
    Errors := Errors + 'Password cannot be empty' + LineEnding;
  if FConfig.ConnectionTimeout <= 0 then
    FConfig.ConnectionTimeout := 10000;
  if FConfig.ResponseTimeout <= 0 then
    FConfig.ResponseTimeout := 30000;
  if FConfig.MaxActionsPerSecond <= 0 then
    FConfig.MaxActionsPerSecond := 10;
  if FConfig.MaxRetries <= 0 then
    FConfig.MaxRetries := 3;
  if FConfig.UseIPv6 then
    FConfig.UseIPv6 := False;

  if Errors <> '' then
  begin
    Result := False;
    raise EAMIValidationException.Create(Errors);
  end;
end;

function TAMIClient.CheckRateLimit: boolean;
var
  CurrentTime: TDateTime;
  TimeSinceLastAction: Double;
begin
  Result := True;

  if FConfig.MaxActionsPerSecond <= 0 then
    Exit;

  CurrentTime := Now;
  TimeSinceLastAction := (CurrentTime - FLastActionTime) * 24 * 60 * 60;

  if TimeSinceLastAction >= 1.0 then
  begin
    FActionRateLimitCount := 0;
    FLastActionTime := CurrentTime;
  end
  else
  begin
    if FActionRateLimitCount >= FConfig.MaxActionsPerSecond then
    begin
      DoLog(Self, llWarning, Format('Rate limit exceeded: %d actions/sec',
        [FConfig.MaxActionsPerSecond]));
      Result := False;
    end
    else
    begin
      Inc(FActionRateLimitCount);
    end;
  end;
end;

procedure TAMIClient.Disconnect;
var
  List: TList;
  i: Integer;
  Pending: TPendingAction;
begin
  if IsDestroying then
    Exit;

  DoLog(Self, llInfo, 'Disconnecting from AMI server');

  StopKeepAlive;
  StopReconnect;

  FPendingLock.Enter;
  try
    List := FPendingActions.LockList;
    try
      for i := 0 to List.Count - 1 do
      begin
        Pending := TPendingAction(List[i]);
        if Assigned(Pending) then
        begin
          DoLog(Self, llDebug, Format('Cancelling pending action: %s (disconnect)',
            [Pending.ActionID]));
          Pending.SignalDone;
        end;
      end;
    finally
      FPendingActions.UnlockList;
    end;
  finally
    FPendingLock.Leave;
  end;

  if Assigned(FPacketReader) then
    FPacketReader.Stop;

  if Assigned(FTransport) then
    FTransport.Disconnect;

  SetStatus(csDisconnected);
end;

function TAMIClient.IsConnected: boolean;
begin
  Result := ((FStatus = csConnected) or FAuthenticating) and
    Assigned(FTransport) and FTransport.Connected;
end;

function TAMIClient.GetConnectionInfo: string;
var
  Uptime: integer;
  BytesPerSec: double;
begin
  if IsConnected then
  begin
    Uptime := GetUptime;
    BytesPerSec := FTransport.GetBytesPerSecond;

    Result := Format(
      'Connected to %s:%d for %d seconds, %.1f bytes/sec, %d events, %d actions',
      [FConfig.Host, FConfig.Port, Uptime, BytesPerSec, FTotalEvents,
      FTotalActions]);
  end
  else
  begin
    Result := Format('Disconnected (Status: %s)',
      [GetEnumName(TypeInfo(TAMIClientStatus), Ord(FStatus))]);
  end;
end;

procedure TAMIClient.HandleTransportDisconnect(Sender: TObject);
begin
  if IsDestroying or (FStatus = csDisconnected) then
    Exit;

  DoLog(Self, llWarning, 'Transport disconnected unexpectedly');
  SetStatus(csDisconnected);

  if (FConfig.MaxReconnectAttempts > 0) and not IsDestroying then
    StartReconnect;
end;

{==============================================================================}
{=== Action Management ========================================================}
{==============================================================================}

function TAMIClient.IsMultiEventAction(AAction: TAMIAction): Boolean;
var
  ActionName: string;
begin
  ActionName := UpperCase(AAction.ActionName);
  Result := (ActionName = 'DBGET') or
            (ActionName = 'DBGETTREE') or
            (ActionName = 'EXTENSIONSTATELIST');
end;

function TAMIClient.IsFollowUpEventName(const AEventName: string): Boolean;
begin
  Result := (AEventName = 'DBGETRESPONSE') or
            (AEventName = 'DBGETCOMPLETE') or
            (AEventName = 'EXTENSIONSTATUS') or
            (AEventName = 'EXTENSIONSTATELISTCOMPLETE');
end;

function TAMIClient.IsCompletionEventName(const AEventName: string): Boolean;
begin
  Result := (AEventName = 'DBGETCOMPLETE') or
            (AEventName = 'EXTENSIONSTATELISTCOMPLETE');
end;

function TAMIClient.AddPendingAction(AAction: TAMIAction;
  AOnResponse: TAMIResponseEvent): string;
var
  Pending: TPendingAction;
begin
  Result := AAction.GetField('ActionID');
  if Result = '' then
  begin
    Result := TAMIUtils.GenerateActionID;
    AAction.AddField('ActionID', Result);
  end;

  Pending := TPendingAction.Create(AAction);
  Pending.OnResponse := AOnResponse;

  FPendingLock.Enter;
  try
    FPendingActions.Add(Pending);
    Inc(FTotalActions);
    DoLog(Self, llDebug, Format('AddPendingAction: %s', [Pending.ActionID]));
  finally
    FPendingLock.Leave;
  end;
end;

procedure TAMIClient.RemovePendingAction(const AActionID: string);
var
  Pending: TPendingAction;
  i: integer;
  List: TList;
begin
  FPendingLock.Enter;
  try
    List := FPendingActions.LockList;
    try
      for i := List.Count - 1 downto 0 do
      begin
        Pending := TPendingAction(List[i]);
        if SameText(Pending.ActionID, AActionID) then
        begin
          List.Delete(i);
          FreeAndNil(Pending);
          Break;
        end;
      end;
    finally
      FPendingActions.UnlockList;
    end;
  finally
    FPendingLock.Leave;
  end;
end;

function TAMIClient.GetPendingAction(const AActionID: string): TPendingAction;
var
  i: integer;
  Pending: TPendingAction;
  List: TList;
begin
  Result := nil;
  FPendingLock.Enter;
  try
    List := FPendingActions.LockList;
    try
      for i := 0 to List.Count - 1 do
      begin
        Pending := TPendingAction(List[i]);
        if SameText(Pending.ActionID, AActionID) then
        begin
          Result := Pending;
          Break;
        end;
      end;
    finally
      FPendingActions.UnlockList;
    end;
  finally
    FPendingLock.Leave;
  end;
end;

procedure TAMIClient.CleanupExpiredPendingActions;
var
  i: integer;
  Pending: TPendingAction;
  ExpiredTime: TDateTime;
  List: TList;
  ExpiredCount: integer;
begin
  ExpiredTime := Now - (FConfig.ResponseTimeout / 86400);
  ExpiredCount := 0;

  FPendingLock.Enter;
  try
    List := FPendingActions.LockList;
    try
      for i := List.Count - 1 downto 0 do
      begin
        Pending := TPendingAction(List[i]);
        if Pending.CreateTime < ExpiredTime then
        begin
          DoLog(Self, llDebug, 'Cleaning up expired pending action: ' +
            Pending.ActionID);
          List.Delete(i);
          FreeAndNil(Pending);
          Inc(ExpiredCount);
          Inc(FFailedActions);
        end;
      end;
    finally
      FPendingActions.UnlockList;
    end;
  finally
    FPendingLock.Leave;
  end;

  if ExpiredCount > 0 then
    DoLog(Self, llDebug, Format('Cleaned up %d expired pending actions',
      [ExpiredCount]));
end;

function TAMIClient.SendAction(const AAction: TAMIAction; ATimeout: integer): TAMIResponse;
var
  ActionID: string;
  Pending: TPendingAction;
  ActionData: rawbytestring;
  WaitResult: TWaitResult;
  StartTime: TDateTime;
  ElapsedMs: int64;
  RetryDelay: integer;
  ShouldRetry: boolean;
begin
  FSendLock.Enter;
  try
    Result := nil;
    FCurrentRetryCount := 0;

    if IsDestroying or not IsConnected then
    begin
      DoLog(Self, llError, 'Cannot send action: not connected or shutting down');
      if not IsConnected then
        Inc(FFailedActions);
      Exit;
    end;

    CleanupExpiredPendingActions;

    if not CheckRateLimit then
    begin
      DoLog(Self, llWarning, 'Action blocked by rate limit');
      Inc(FFailedActions);
      Exit;
    end;

    if ATimeout <= 0 then
    begin
      if FConfig.ResponseTimeout > 0 then
        ATimeout := FConfig.ResponseTimeout
      else
        ATimeout := 30000;
    end;

    ActionID := AddPendingAction(AAction, nil);
    Pending := GetPendingAction(ActionID);

    if not Assigned(Pending) then
    begin
      DoLog(Self, llCritical, 'Failed to add pending action: ' + ActionID);
      Inc(FFailedActions);
      Exit;
    end;

    ActionData := TAMIWriter.WriteAction(AAction);
    if not FTransport.SendData(ActionData) then
    begin
      DoLog(Self, llError, 'Failed to send action data: ' + FTransport.LastError);
      RemovePendingAction(ActionID);
      Inc(FFailedActions);
      Exit;
    end;

    StartTime := Now;
    ShouldRetry := True;

    while ShouldRetry and (FCurrentRetryCount <= FConfig.MaxRetries) do
    begin
      repeat
        ProcessMessages;
        WaitResult := Pending.Wait(100);
        ElapsedMs := MilliSecondsBetween(Now, StartTime);

        if WaitResult = wrSignaled then
          Break;

        if IsDestroying or not IsConnected then
          Break;

        if ElapsedMs >= ATimeout then
          Break;

      until False;

      if WaitResult = wrSignaled then
      begin
        Result := Pending.Response;
        Pending.Response := nil;

        if Assigned(Result) then
        begin
          Result.UpdateFromFields;
        end;
        ShouldRetry := False;
      end
      else
      begin
        if (FCurrentRetryCount < FConfig.MaxRetries) and IsConnected then
        begin
          Inc(FCurrentRetryCount);
          RetryDelay := Min(1000 * (1 shl FCurrentRetryCount), 5000);
          DoLog(Self, llInfo, Format('Action timeout, retry %d/%d after %dms',
            [FCurrentRetryCount, FConfig.MaxRetries, RetryDelay]));
          Sleep(RetryDelay);

          if FTransport.SendData(ActionData) then
          begin
            StartTime := Now;
            Continue;
          end;
        end;

        DoLog(Self, llWarning, Format('Action timeout: %s after %dms (retries: %d)',
          [ActionID, ElapsedMs, FCurrentRetryCount]));
        ShouldRetry := False;
      end;
    end;

    if not Assigned(Result) then
      Inc(FFailedActions);

    RemovePendingAction(ActionID);
  finally
    FSendLock.Leave;
  end;
end;

function TAMIClient.SendActionAsync(const AAction: TAMIAction;
  AOnResponse: TAMIResponseEvent): string;
var
  ActionData: rawbytestring;
begin
  Result := '';

  if IsDestroying then
  begin
    DoLog(Self, llError, 'Cannot send async action: client is shutting down');
    Exit;
  end;

  if not IsConnected then
  begin
    DoLog(Self, llError, 'Cannot send async action: not connected');
    Exit;
  end;

  FSendLock.Enter;
  try
    if not CheckRateLimit then
    begin
      DoLog(Self, llWarning, 'Async action blocked by rate limit');
      Inc(FFailedActions);
      Exit;
    end;
  finally
    FSendLock.Leave;
  end;

  Result := AddPendingAction(AAction, AOnResponse);

  ActionData := TAMIWriter.WriteAction(AAction);
  if not FTransport.SendData(ActionData) then
  begin
    DoLog(Self, llError, 'Failed to send async action: ' + FTransport.LastError);
    RemovePendingAction(Result);
    Inc(FFailedActions);
    Result := '';
  end
  else
  begin
    //DoLog(Self, llDebug, Format('Async action sent: %s', [Result]));
  end;
end;

function TAMIClient.SendCachedAction(const AAction: TAMIAction;
  const ACacheKey: string; ATimeout: integer): TAMIResponse;
begin
  Result := FResponseCache.GetResponse(ACacheKey);
  if Assigned(Result) then
  begin
    DoLog(Self, llDebug, Format('Cache hit for key: %s', [ACacheKey]));
    Exit;
  end;

  Result := SendAction(AAction, ATimeout);
  if Assigned(Result) and Result.IsSuccess then
  begin
    FResponseCache.PutResponse(ACacheKey, Result);
    DoLog(Self, llDebug, Format('Cached response for key: %s', [ACacheKey]));
  end;
end;

function TAMIClient.CachedQueueStatus(const AQueueName: string;
  ATimeout: integer): TAMIResponse;
var
  CacheKey: string;
  Action: TAMIQueueStatusAction;
begin
  if AQueueName = '' then
    CacheKey := 'queuestatus_all'
  else
    CacheKey := 'queuestatus_' + AQueueName;

  Action := TAMIQueueStatusAction.Create(AQueueName);
  try
    Result := SendCachedAction(Action, CacheKey, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

{==============================================================================}
{=== Message Processing =======================================================}
{==============================================================================}

procedure TAMIClient.ProcessMessages;
var
  Message: TAMIMessage;
begin
  while FPacketReader.HasPriorityMessages and not IsDestroying do
  begin
    Message := FPacketReader.GetNextPriorityMessage;
    if Assigned(Message) then
    begin
      try
        ProcessMessage(Message);
      finally
        FreeAndNil(Message);
      end;
    end;
  end;

  while FPacketReader.HasMessages and not IsDestroying do
  begin
    Message := FPacketReader.GetNextMessage;
    if Assigned(Message) then
    begin
      try
        ProcessMessage(Message);
      finally
        FreeAndNil(Message);
      end;
    end;
  end;
end;

procedure TAMIClient.ProcessMessage(const AMessage: TAMIMessage);
var
  ActionID: string;
  EventName: string;
  Pending: TPendingAction;
begin
  if IsDestroying or not Assigned(AMessage) then
    Exit;

  //DoLog(Self, llDebug, Format('Processing message: %s', [AMessage.ToString]));

  case AMessage.MessageType of
    mtResponse:
      ProcessResponse(TAMIResponse(AMessage));

    mtEvent:
    begin
      if AMessage is TAMIEvent then
      begin
        ActionID := AMessage.GetField('ActionID');
        EventName := UpperCase(TAMIEvent(AMessage).GetEventName);

        if (ActionID <> '') and IsFollowUpEventName(EventName) then
        begin
          Pending := GetPendingAction(ActionID);
          if Assigned(Pending) and Assigned(Pending.Response) then
          begin
            Pending.Response.AddFollowUpEvent(TAMIEvent(AMessage));

            //DoLog(Self, llDebug, Format('Attached follow-up event %s to action %s',
            //  [EventName, ActionID]));

            if IsCompletionEventName(EventName) then
            begin
              //DoLog(Self, llDebug, Format('Multi-event action %s completed', [ActionID]));
              Pending.Response.UpdateFromFields;
              //DoLog(Self, llDebug, Format('Response type: %s, FieldCount: %d, FollowUpCount: %d',
              //  [Pending.Response.ClassName,
              //   Pending.Response.FieldCount,
              //   Pending.Response.GetFollowUpEventCount]));
              Pending.SignalDone;
            end;

            Exit;
          end;
        end;
      end;

      ProcessEvent(TAMIEvent(AMessage));
    end;
  end;
end;

procedure TAMIClient.ProcessResponse(const AResponse: TAMIResponse);
var
  ActionID: string;
  Pending: TPendingAction;
  List: TList;
  i: integer;
  ActionName: string;
  IsError: Boolean;
begin
  if IsDestroying or not Assigned(AResponse) then
  begin
    DoLog(Self, llWarning, 'ProcessResponse: Invalid response or shutting down');
    Exit;
  end;

  ActionID := AResponse.GetField('ActionID');

  if Assigned(FOnResponse) then
  begin
    try
      FOnResponse(Self, AResponse);
    except
      on E: Exception do
        DoLog(Self, llError, 'Error in OnResponse handler: ' + E.Message);
    end;
  end;

  if ActionID = '' then Exit;

  //DoLog(Self, llDebug, Format('Processing response for ActionID: %s, Result: %s',
  //  [ActionID, AResponse.Response]));

  Pending := nil;
  FPendingLock.Enter;
  try
    List := FPendingActions.LockList;
    try
      for i := 0 to List.Count - 1 do
      begin
        if SameText(TPendingAction(List[i]).ActionID, ActionID) then
        begin
          Pending := TPendingAction(List[i]);
          Break;
        end;
      end;
    finally
      FPendingActions.UnlockList;
    end;
  finally
    FPendingLock.Leave;
  end;

  if (ActionID <> '') and Assigned(FOnActionResponse) then
  begin
    try
      FOnActionResponse(Self, AResponse);
    except
      on E: Exception do
        DoLog(Self, llError, 'Error in OnActionResponse handler: ' + E.Message);
    end;
  end;

  if Assigned(Pending) then
  begin
    DoLog(Self, llDebug, Format('Found pending action for ActionID: %s', [ActionID]));
    IsError := not AResponse.IsSuccess;

    if not Assigned(Pending.Response) then
    begin
      ActionName := UpperCase(Pending.Action.ActionName);

      if (ActionName = 'DBGET') or (ActionName = 'DBGETTREE') then
      begin
        Pending.Response := TAMIDBGetResponse.Create;
        //DoLog(Self, llDebug, 'Created TAMIDBGetResponse for action ' + ActionName);
      end
      else if SameText(AResponse.GetField('Response'), 'Follows') then
      begin
        Pending.Response := TAMICommandResponse.Create;
      end
      else
      begin
        Pending.Response := TAMIResponse.Create;
      end;
    end;

    try
      if Assigned(AResponse) and Assigned(Pending.Response) then
      begin
        Pending.Response.Assign(AResponse);
      end
      else
      begin
        DoLog(Self, llWarning, Format('Cannot assign response for action %s', [ActionID]));
      end;
    except
      on E: Exception do
      begin
        DoLog(Self, llError, Format('Exception in Response.Assign for action %s: %s',
          [ActionID, E.Message]));
      end;
    end;

    if Assigned(Pending.OnResponse) then
    begin
      try
        Pending.OnResponse(Self, Pending.Response);
      except
        on E: Exception do
          DoLog(Self, llError, 'Error in async response callback: ' + E.Message);
      end;
    end;

    if IsError or not IsMultiEventAction(Pending.Action) then
    begin
      //DoLog(Self, llDebug, Format('Signaling done for action %s (Error=%s, MultiEvent=%s)',
      //  [ActionID, BoolToStr(IsError, True), BoolToStr(IsMultiEventAction(Pending.Action), True)]));
      Pending.SignalDone;
    end
    else
    begin
      //DoLog(Self, llDebug, Format('Waiting for completion event for multi-event action %s', [ActionID]));
    end;
  end
  else
  begin
    DoLog(Self, llWarning, Format(
      'No pending action found for ActionID: %s (might have timed out)', [ActionID]));
  end;
end;

procedure TAMIClient.ProcessEvent(const AEvent: TAMIEvent);
var
  EventName: string;
  EventType: TAMIEventType;
begin
  if IsDestroying or not Assigned(AEvent) then
    Exit;

  Inc(FTotalEvents);
  FLastEventTime := Now;

  EventName := AEvent.GetEventName;

  {$IFDEF CACHE}
  EventType := FEventCache.GetEventType(EventName);
  if EventType = etUnknown then
  begin
    EventType := TAMIEventParser.ParseEventType(EventName);
    FEventCache.PutEventType(EventName, EventType);
  end;
  {$ELSE}
  EventType := TAMIEventParser.ParseEventType(EventName);
  {$ENDIF}

  //DoLog(Self, llDebug, Format('Processing event: %s (Type: %s, Category: %s)',
  //  [EventName, GetEnumName(TypeInfo(TAMIEventType), Ord(EventType)),
  //  TAMIEventParser.GetEventCategory(EventType)]));

  FEventProcessor.ProcessEvent(AEvent);

  if Assigned(FOnEvent) then
  begin
    try
      FOnEvent(Self, AEvent);
    except
      on E: Exception do
        DoLog(Self, llError, 'Error in global event handler: ' + E.Message);
    end;
  end;
    try
    if Assigned(AMIEventBus) then
      AMIEventBus.Dispatch(AEvent);
  except
    on E: Exception do
      DoLog(Self, llError, 'Event bus dispatch failed: ' + E.Message);
  end;
end;

procedure TAMIClient.ProcessPendingMessages;
begin
  ProcessMessages;
end;

procedure TAMIClient.ProcessPendingPriorityMessages;
begin
  ProcessMessages;
end;

function TAMIClient.HasPendingMessages: boolean;
begin
  Result := Assigned(FPacketReader) and FPacketReader.HasMessages;
end;

function TAMIClient.HasPendingPriorityMessages: boolean;
begin
  Result := Assigned(FPacketReader) and FPacketReader.HasPriorityMessages;
end;

{==============================================================================}
{=== Authentication ===========================================================}
{==============================================================================}

function TAMIClient.Authenticate: boolean;
begin
  DoLog(Self, llInfo, Format('Authenticating with method: %s', [FConfig.AuthType]));

  if SameText(FConfig.AuthType, 'md5') then
    Result := PerformMD5Auth
  else
    Result := PerformPlainAuth;

  if Result then
  begin
    DoLog(Self, llInfo, 'Authentication successful');
    if FConfig.EventMask <> '' then
      SetEventMask(FConfig.EventMask);
  end
  else
    DoLog(Self, llError, 'Authentication failed');
end;

function TAMIClient.PerformPlainAuth: boolean;
var
  LoginAction: TAMILoginAction;
  LoginResponse: TAMIResponse;
begin
  Result := False;

  DoLog(Self, llInfo, 'Performing plain authentication...');

  LoginAction := TAMILoginAction.Create(FConfig.Username, FConfig.Password, 'plain');
  try
    DoLog(Self, llDebug, 'Sending login action...');

    LoginResponse := SendAction(LoginAction, 15000);
    if Assigned(LoginResponse) then
    begin
      DoLog(Self, llInfo, 'Login response received: ' + LoginResponse.Response);
      DoLog(Self, llDebug, 'Login message: ' + LoginResponse.Message);

      if SameText(Trim(LoginResponse.Response), 'Success') then
        Result := True
      else
        DoLog(Self, llError, 'Login failed: ' + LoginResponse.Message);
      FreeAndNil(LoginResponse);
    end
    else
    begin
      DoLog(Self, llError, 'No login response received (timeout)');
    end;
  finally
    FreeAndNil(LoginAction);
  end;
end;

function TAMIClient.PerformMD5Auth: boolean;
var
  ChallengeAction: TAMIChallengeAction;
  ChallengeResponse: TAMIResponse;
  LoginAction: TAMILoginAction;
  LoginResponse: TAMIResponse;
  Challenge: string;
  HashedPassword: string;
begin
  Result := False;

  DoLog(Self, llDebug, 'Performing MD5 authentication...');

  ChallengeAction := TAMIChallengeAction.Create('MD5');
  try
    ChallengeResponse := SendAction(ChallengeAction, 10000);
    if Assigned(ChallengeResponse) and ChallengeResponse.IsSuccess then
    begin
      Challenge := ChallengeResponse.GetField('Challenge');
      DoLog(Self, llDebug, 'Challenge received: ' + Challenge);

      HashedPassword := TAMIUtils.GenerateMD5Challenge(Challenge, FConfig.Password);

      LoginAction := TAMILoginAction.Create(FConfig.Username, HashedPassword, 'MD5');
      try
        LoginResponse := SendAction(LoginAction, 10000);
        if Assigned(LoginResponse) then
        begin
          Result := LoginResponse.IsSuccess;
          FreeAndNil(LoginResponse);
        end;
      finally
        FreeAndNil(LoginAction);
      end;

      FreeAndNil(ChallengeResponse);
    end
    else
    begin
      DoLog(Self, llError, 'Challenge request failed');
      if Assigned(ChallengeResponse) then
        FreeAndNil(ChallengeResponse);
    end;
  finally
    FreeAndNil(ChallengeAction);
  end;
end;

{==============================================================================}
{=== Keep-Alive / Reconnect Threads ===========================================}
{==============================================================================}

procedure TAMIClient.StartKeepAlive;
begin
  StopKeepAlive;
  if FConfig.PingInterval > 0 then
  begin
    FKAStopEvent.ResetEvent;
    DoLog(Self, llDebug, Format('Starting keep-alive with %d second interval',
      [FConfig.PingInterval]));
    FKeepAliveTimer := TKeepAliveThread.Create(Self, FKAStopEvent);
  end;
end;

procedure TAMIClient.StopKeepAlive;
begin
  if Assigned(FKeepAliveTimer) then
  begin
    DoLog(Self, llDebug, 'Stopping keep-alive thread');
    FKAStopEvent.SetEvent;
    FKeepAliveTimer.Terminate;
    FKeepAliveTimer.WaitFor;
    FreeAndNil(FKeepAliveTimer);
  end;
end;

procedure TAMIClient.StartReconnect;
begin
  StopReconnect;
  if FConfig.MaxReconnectAttempts > 0 then
  begin
    FRCStopEvent.ResetEvent;
    DoLog(Self, llInfo, 'Starting automatic reconnection');
    FReconnectTimer := TReconnectThread.Create(Self, FRCStopEvent);
  end;
end;

procedure TAMIClient.StopReconnect;
begin
  if Assigned(FReconnectTimer) then
  begin
    DoLog(Self, llDebug, 'Stopping reconnection thread');
    FRCStopEvent.SetEvent;
    FReconnectTimer.Terminate;
    FReconnectTimer.WaitFor;
    FreeAndNil(FReconnectTimer);
  end;
end;

{==============================================================================}
{=== High-Level Action Wrappers ===============================================}
{==============================================================================}

function TAMIClient.Originate(const AParams: TOriginateParams;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMIOriginateAction;
begin
  Action := TAMIOriginateAction.Create;
  try
    Action.SetParams(AParams);
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.Hangup(const AChannel: string; ACause: integer;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMIHangupAction;
begin
  Action := TAMIHangupAction.Create(AChannel, ACause);
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.Command(const ACommand: string; ATimeout: integer): TAMIResponse;
var
  Action: TAMICommandAction;
begin
  Action := TAMICommandAction.Create(ACommand);
  try
    Result := SendAction(Action, ATimeout);

    if Assigned(Result) and (Result is TAMICommandResponse) then
    begin
      DoLog(Self, llInfo, Format('Command "%s" executed, %d lines of output',
        [ACommand, TAMICommandResponse(Result).GetOutputLineCount]));
    end;
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.QueueAdd(const AQueueName, AMember: string;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMIQueueAddAction;
begin
  Action := TAMIQueueAddAction.Create(AQueueName, AMember);
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.QueueRemove(const AQueueName, AMember: string;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMIQueueRemoveAction;
begin
  Action := TAMIQueueRemoveAction.Create(AQueueName, AMember);
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.QueueStatus(const AQueueName: string;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMIQueueStatusAction;
begin
  Action := TAMIQueueStatusAction.Create(AQueueName);
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.Ping(ATimeout: integer): TAMIResponse;
var
  Action: TAMIPingAction;
begin
  Action := TAMIPingAction.Create;
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.Redirect(const AChannel, AContext, AExtension: string;
  APriority: integer; AExtraChannel: string; ATimeout: integer): TAMIResponse;
var
  Action: TAMIRedirectAction;
begin
  Action := TAMIRedirectAction.Create(AChannel, AContext, AExtension,
    APriority, AExtraChannel);
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.BridgeInfo(const ABridgeUniqueID: string;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMIBridgeInfoAction;
begin
  Action := TAMIBridgeInfoAction.Create(ABridgeUniqueID);
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.GetVar(const AChannel, AVariable: string;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMIGetVarAction;
begin
  Action := TAMIGetVarAction.Create(AChannel, AVariable);
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.SetVar(const AChannel, AVariable, AValue: string;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMISetVarAction;
begin
  Action := TAMISetVarAction.Create(AChannel, AVariable, AValue);
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.BridgeList(ATimeout: integer): TAMIResponse;
var
  Action: TAMIBridgeListAction;
begin
  Action := TAMIBridgeListAction.Create;
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.ChannelList(ATimeout: integer): TAMIResponse;
var
  Action: TAMICoreShowChannelsAction;
begin
  Action := TAMICoreShowChannelsAction.Create;
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.PeerStatus(const APeer: string; ATimeout: integer): TAMIResponse;
begin
  Result := PeerStatusEx(APeer, 'SIP', ATimeout);
end;

function TAMIClient.PeerStatusEx(const APeer: string; const AProtocol: string;
  ATimeout: integer): TAMIResponse;
var
  Action: TAMIAction;
begin
  if SameText(AProtocol, 'PJSIP') then
  begin
    Action := TAMIAction.Create('PJSIPShowEndpoint');
    if APeer <> '' then
      Action.AddField('Endpoint', APeer);
  end
  else
  begin
    Action := TAMIAction.Create('SIPshowpeer');
    if APeer <> '' then
      Action.AddField('Peer', APeer);
  end;

  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

function TAMIClient.DeviceStateList(ATimeout: integer): TAMIResponse;
var
  Action: TAMIAction;
begin
  Action := TAMIAction.Create('DeviceStateList');
  try
    Result := SendAction(Action, ATimeout);
  finally
    FreeAndNil(Action);
  end;
end;

{==============================================================================}
{=== Event Management =========================================================}
{==============================================================================}

procedure TAMIClient.SubscribeToEvent(const AEventName: string;
  AOnEvent: TAMIEventEvent);
begin
  FEventManager.AddHandler(AEventName, AOnEvent);
end;

procedure TAMIClient.UnsubscribeFromEvent(const AEventName: string);
begin
  FEventManager.RemoveHandler(AEventName);
end;

procedure TAMIClient.AddEventFilter(const AEventName: string; AInclude: boolean);
begin
  if AInclude then
    FEventManager.AddIncludeFilter(AEventName)
  else
    FEventManager.AddExcludeFilter(AEventName);
end;

procedure TAMIClient.ClearEventFilters;
begin
  FEventManager.ClearFilters;
end;

procedure TAMIClient.SetEventMask(const AMask: string);
var
  Action: TAMIEventsAction;
  Response: TAMIResponse;
begin
  Action := TAMIEventsAction.Create(AMask);
  try
    Response := SendAction(Action, 10000);
    if Assigned(Response) then
    begin
      if Response.IsSuccess then
        DoLog(Self, llInfo, 'Event mask set to: ' + AMask)
      else
        DoLog(Self, llError, 'Failed to set event mask: ' + Response.Message);
      FreeAndNil(Response);
    end;
  finally
    FreeAndNil(Action);
  end;
end;

{==============================================================================}
{=== Statistics and Monitoring ================================================}
{==============================================================================}

function TAMIClient.GetStatistics: string;
var
  EventsPerSec, ActionsPerSec: double;
begin
  EventsPerSec := GetEventsPerSecond;
  ActionsPerSec := GetActionsPerSecond;

  Result := Format('AMI Client Statistics:'#13#10 + '  Status: %s'#13#10 +
    '  Uptime: %s'#13#10 + '  Total Events: %d (%.2f/sec)'#13#10 +
    '  Total Actions: %d (%.2f/sec)'#13#10 + '  Failed Actions: %d'#13#10 +
    '  Success Rate: %.1f%%'#13#10 + '  Bytes Received: %s'#13#10 +
    '  Bytes Sent: %s'#13#10 + '  Connection: %s',
    [GetEnumName(TypeInfo(TAMIClientStatus), Ord(FStatus)), GetUptimeStr,
    FTotalEvents, EventsPerSec, FTotalActions, ActionsPerSec,
    FFailedActions, IfThen(FTotalActions > 0,
    ((FTotalActions - FFailedActions) / FTotalActions) * 100, 100.0),
    TAMIUtils.FormatBytes(FTransport.BytesReceived),
    TAMIUtils.FormatBytes(FTransport.BytesSent), GetConnectionInfo]);
end;

function TAMIClient.GetUptime: integer;
begin
  if (FStatus = csConnected) and (FConnectTime > 0) then
    Result := SecondsBetween(Now, FConnectTime)
  else
    Result := 0;
end;

function TAMIClient.GetUptimeMs: int64;
begin
  if (FStatus = csConnected) and (FConnectTime > 0) then
    Result := MilliSecondsBetween(Now, FConnectTime)
  else
    Result := 0;
end;

function TAMIClient.GetUptimeStr: string;
var
  TotalSeconds: Integer;
  Hours, Minutes, Seconds: Integer;
begin
  Result := '0s';
  if (FStatus = csConnected) and (FConnectTime > 0) then
  begin
    TotalSeconds := SecondsBetween(Now, FConnectTime);
    if TotalSeconds < 60 then
      Result := Format('%ds', [TotalSeconds])
    else if TotalSeconds < 3600 then
    begin
      Minutes := TotalSeconds div 60;
      Seconds := TotalSeconds mod 60;
      Result := Format('%dm %ds', [Minutes, Seconds]);
    end
    else
    begin
      Hours := TotalSeconds div 3600;
      Minutes := (TotalSeconds mod 3600) div 60;
      Seconds := TotalSeconds mod 60;
      Result := Format('%dh %dm %ds', [Hours, Minutes, Seconds]);
    end;
  end;
end;

function TAMIClient.GetEventsPerSecond: double;
var
  Uptime: integer;
begin
  Uptime := GetUptime;
  if Uptime > 0 then
    Result := FTotalEvents / Uptime
  else
    Result := 0;
end;

function TAMIClient.GetActionsPerSecond: double;
var
  Uptime: integer;
begin
  Uptime := GetUptime;
  if Uptime > 0 then
    Result := FTotalActions / Uptime
  else
    Result := 0;
end;

{==============================================================================}
{=== Caching ==================================================================}
{==============================================================================}

procedure TAMIClient.ClearCaches;
begin
  FEventCache.Clear;
  FResponseCache.Clear;
end;

procedure TAMIClient.CleanupCaches(AMaxAgeMinutes: integer);
begin
  FEventCache.CleanupOldEntries(AMaxAgeMinutes);
  FResponseCache.CleanupExpired;
end;

function TAMIClient.GetEventCacheStats: string;
begin
  Result := FEventCache.GetHitRate.ToString + ' hit rate, ' +
    FEventCache.GetSize.ToString + ' items';
end;

function TAMIClient.GetResponseCacheStats: string;
begin
  Result := FResponseCache.GetSize.ToString + ' items';
end;

{==============================================================================}
{=== Asynchronous Event Bus ===================================================}
{==============================================================================}

function TAMIClient.SubscribeToEventAsync(const AEventName: String; AHandler: TAMIEventEvent;
  ACallInMainThread: Boolean; AOwner: TObject): Integer;
begin
  Result := -1;
  if not Assigned(AMIEventBus) then Exit;
  Result := AMIEventBus.Subscribe(AHandler, AOwner, ACallInMainThread, AEventName, []);
end;

procedure TAMIClient.UnsubscribeFromEventAsync(AID: Integer);
begin
  if Assigned(AMIEventBus) then
    AMIEventBus.Unsubscribe(AID);
end;

end.
