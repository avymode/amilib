program example_dashboard;

{$mode objfpc}{$H+}
{$codepage UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  Classes, SysUtils, syncobjs, DateUtils, TypInfo,
  ami_client, ami_types, ami_events, ami_parser, ami_enums;

type
  { Thread wrapper for object methods }
  TMethodThread = class(TThread)
  private
    FMethod: TThreadMethod;
  protected
    procedure Execute; override;
  public
    constructor Create(AMethod: TThreadMethod);
  end;

  { Real-time dashboard }
  TAMIDashboard = class
  private
    FClient: TAMIClient;
    FUpdateThread: TThread;
    FRunning: Boolean;

    // Metrics
    FMetrics: record
      ActiveCalls: Integer;
      TotalCallsToday: Integer;
      CompletedCalls: Integer;
      FailedCalls: Integer;
      AverageCallDuration: Double;

      QueueCalls: Integer;
      AverageWaitTime: Double;
      LongestWaitTime: Double;

      ActiveAgents: Integer;
      TotalAgents: Integer;

      SystemLoad: Double;
      MemoryUsage: Int64;
    end;

    FMetricsLock: TCriticalSection;
    FCallStartTimes: TStringList;

    procedure UpdateDisplay;

    procedure DrawHeader;
    procedure DrawMetrics;
    procedure DrawGraph(const ATitle: String; const AValues: array of Double);
    procedure ClearScreen;

    // Event handlers
    procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueCallerJoin(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueCallerLeave(Sender: TObject; const Event: TAMIEvent);

  public
    constructor Create(AClient: TAMIClient);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
    procedure DoUpdateThread;
  end;

  { Main application wrapper }
  TDashboardApp = class
  private
    FClient: TAMIClient;
    FDashboard: TAMIDashboard;
    FMessageThread: TThread;
    FRunning: Boolean;

    procedure ProcessMessages;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Run;
    procedure Stop;
  end;

{ TMethodThread }

constructor TMethodThread.Create(AMethod: TThreadMethod);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FMethod := AMethod;
end;

procedure TMethodThread.Execute;
begin
  if Assigned(FMethod) then
    FMethod();
end;

{ TAMIDashboard }

constructor TAMIDashboard.Create(AClient: TAMIClient);
begin
  inherited Create;
  FClient := AClient;
  FMetricsLock := TCriticalSection.Create;
  FCallStartTimes := TStringList.Create;
  FCallStartTimes.Sorted := True;
  FRunning := False;

  FillChar(FMetrics, SizeOf(FMetrics), 0);

  // Subscribe to events
  FClient.SubscribeToEvent('Newchannel', @OnNewChannel);
  FClient.SubscribeToEvent('Hangup', @OnHangup);
  FClient.SubscribeToEvent('QueueCallerJoin', @OnQueueCallerJoin);
  FClient.SubscribeToEvent('QueueCallerLeave', @OnQueueCallerLeave);
end;

destructor TAMIDashboard.Destroy;
begin
  Stop;
  FreeAndNil(FMetricsLock);
  FreeAndNil(FCallStartTimes);
  inherited Destroy;
end;

procedure TAMIDashboard.DoUpdateThread;
begin
  while FRunning do
  begin
    UpdateDisplay;
    Sleep(1000);  // Update every second
  end;
end;

procedure TAMIDashboard.Start;
begin
  FRunning := True;
  FUpdateThread := TMethodThread.Create(@DoUpdateThread);
  FUpdateThread.Start;
end;

procedure TAMIDashboard.Stop;
begin
  FRunning := False;

  if Assigned(FUpdateThread) then
  begin
    FUpdateThread.WaitFor;
    FreeAndNil(FUpdateThread);
  end;
end;

procedure TAMIDashboard.ClearScreen;
begin
  {$IFDEF UNIX}
  Write(#27'[2J');
  Write(#27'[H');
  {$ELSE}
  System.Write(#27'[2J');
  System.Write(#27'[H');
  {$ENDIF}
end;

procedure TAMIDashboard.DrawHeader;
begin
  WriteLn('╔════════════════════════════════════════════════════════════════════════╗');
  WriteLn('║          ASTERISK REAL-TIME MONITORING DASHBOARD                      ║');
  WriteLn('║          ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), '                                      ║');
  WriteLn('╚════════════════════════════════════════════════════════════════════════╝');
  WriteLn;
end;

procedure TAMIDashboard.DrawMetrics;
var
  SuccessRate: Double;
  Uptime: Integer;
begin
  FMetricsLock.Enter;
  try
    // Calculate success rate
    if FMetrics.TotalCallsToday > 0 then
      SuccessRate := (FMetrics.CompletedCalls / FMetrics.TotalCallsToday) * 100
    else
      SuccessRate := 0;

    WriteLn('┌─ CALLS ────────────────────────────────────────────────────────────┐');
    WriteLn('│ Active Calls:      ', FMetrics.ActiveCalls:6, '                                        │');
    WriteLn('│ Total Today:       ', FMetrics.TotalCallsToday:6, '                                        │');
    WriteLn('│ Completed:         ', FMetrics.CompletedCalls:6, '                                        │');
    WriteLn('│ Failed:            ', FMetrics.FailedCalls:6, '                                        │');
    WriteLn('│ Success Rate:      ', SuccessRate:6:2, '%                                      │');
    WriteLn('│ Avg Duration:      ', FMetrics.AverageCallDuration:6:1, 's                                     │');
    WriteLn('└────────────────────────────────────────────────────────────────────┘');
    WriteLn;

    WriteLn('┌─ QUEUES ───────────────────────────────────────────────────────────┐');
    WriteLn('│ Queued Calls:      ', FMetrics.QueueCalls:6, '                                        │');
    WriteLn('│ Avg Wait Time:     ', FMetrics.AverageWaitTime:6:1, 's                                     │');
    WriteLn('│ Longest Wait:      ', FMetrics.LongestWaitTime:6:1, 's                                     │');
    WriteLn('└────────────────────────────────────────────────────────────────────┘');
    WriteLn;

    WriteLn('┌─ AGENTS ───────────────────────────────────────────────────────────┐');
    WriteLn('│ Active:            ', FMetrics.ActiveAgents:6, ' / ', FMetrics.TotalAgents:6, '                              │');
    WriteLn('└────────────────────────────────────────────────────────────────────┘');
    WriteLn;

    Uptime := FClient.GetUptime;
    WriteLn('┌─ SYSTEM ───────────────────────────────────────────────────────────┐');
    WriteLn('│ AMI Uptime:        ', Uptime div 3600:2, ':', (Uptime mod 3600) div 60:02, ':', Uptime mod 60:02, '                                 │');
    WriteLn('│ Events/sec:        ', FClient.GetEventsPerSecond:6:2, '                                      │');
    WriteLn('│ Actions/sec:       ', FClient.GetActionsPerSecond:6:2, '                                      │');
    WriteLn('└────────────────────────────────────────────────────────────────────┘');
  finally
    FMetricsLock.Leave;
  end;
end;

procedure TAMIDashboard.DrawGraph(const ATitle: String; const AValues: array of Double);
const
  GRAPH_HEIGHT = 10;
  GRAPH_WIDTH = 60;
var
  i, j: Integer;
  MaxValue, Scale: Double;
  BarHeight: Integer;
begin
  MaxValue := 0;
  for i := 0 to High(AValues) do
    if AValues[i] > MaxValue then
      MaxValue := AValues[i];

  if MaxValue = 0 then
    MaxValue := 1;

  Scale := GRAPH_HEIGHT / MaxValue;

  WriteLn('┌─ ', ATitle, ' ', StringOfChar('─', GRAPH_WIDTH - Length(ATitle) - 4), '┐');

  for j := GRAPH_HEIGHT downto 1 do
  begin
    Write('│ ');
    for i := 0 to High(AValues) do
    begin
      BarHeight := Round(AValues[i] * Scale);
      if BarHeight >= j then
        Write('█')
      else
        Write(' ');
    end;
    WriteLn(' │');
  end;

  WriteLn('└', StringOfChar('─', GRAPH_WIDTH + 2), '┘');
end;

procedure TAMIDashboard.UpdateDisplay;
begin
  ClearScreen;
  DrawHeader;
  DrawMetrics;
  WriteLn;
  WriteLn('Press Ctrl+C to exit');
end;

procedure TAMIDashboard.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  UniqueID: String;
begin
  UniqueID := Event.GetField('Uniqueid');

  FMetricsLock.Enter;
  try
    Inc(FMetrics.ActiveCalls);
    Inc(FMetrics.TotalCallsToday);
    FCallStartTimes.AddObject(UniqueID, TObject(PtrUInt(DateTimeToUnix(Now))));
  finally
    FMetricsLock.Leave;
  end;
end;

procedure TAMIDashboard.OnHangup(Sender: TObject; const Event: TAMIEvent);
var
  UniqueID: String;
  Index: Integer;
  StartTime, Duration: Int64;
  Cause: Integer;
begin
  UniqueID := Event.GetField('Uniqueid');
  Cause := StrToIntDef(Event.GetField('Cause'), 0);

  FMetricsLock.Enter;
  try
    Dec(FMetrics.ActiveCalls);

    Index := FCallStartTimes.IndexOf(UniqueID);
    if Index >= 0 then
    begin
      StartTime := PtrUInt(FCallStartTimes.Objects[Index]);
      Duration := DateTimeToUnix(Now) - StartTime;

      if FMetrics.CompletedCalls > 0 then
        FMetrics.AverageCallDuration :=
          (FMetrics.AverageCallDuration * FMetrics.CompletedCalls + Duration) /
          (FMetrics.CompletedCalls + 1)
      else
        FMetrics.AverageCallDuration := Duration;

      FCallStartTimes.Delete(Index);
    end;

    if Cause = 16 then
      Inc(FMetrics.CompletedCalls)
    else
      Inc(FMetrics.FailedCalls);
  finally
    FMetricsLock.Leave;
  end;
end;

procedure TAMIDashboard.OnQueueCallerJoin(Sender: TObject; const Event: TAMIEvent);
begin
  FMetricsLock.Enter;
  try
    Inc(FMetrics.QueueCalls);
  finally
    FMetricsLock.Leave;
  end;
end;

procedure TAMIDashboard.OnQueueCallerLeave(Sender: TObject; const Event: TAMIEvent);
begin
  FMetricsLock.Enter;
  try
    Dec(FMetrics.QueueCalls);
  finally
    FMetricsLock.Leave;
  end;
end;

{ TDashboardApp }

constructor TDashboardApp.Create;
var
  Config: TAMIClientConfig;
begin
  inherited Create;
  FRunning := False;

  // Configure client
  Config := Default(TAMIClientConfig);
  Config.Host := 'ASTERISK_HOST';
  Config.Port := 5038;
  Config.Username := 'AMI_USERNAME';
  Config.Password := 'AMI_PASSWORD';
  Config.AuthType := 'plain';
  Config.ConnectionTimeout := 10000;
  Config.ResponseTimeout := 30000;
  Config.PingInterval := 30;
  Config.MaxReconnectAttempts := 10;
  Config.EventMask := 'call,agent';
  Config.UTF8Enabled := True;

  FClient := TAMIClient.Create(Config);
end;

destructor TDashboardApp.Destroy;
begin
  Stop;
  FreeAndNil(FDashboard);
  if Assigned(FClient) then
  begin
    FClient.Disconnect;
    FreeAndNil(FClient);
  end;
  inherited Destroy;
end;

procedure TDashboardApp.ProcessMessages;
begin
  while FRunning do
  begin
    if FClient.HasPendingPriorityMessages then
      FClient.ProcessPendingPriorityMessages
    else if FClient.HasPendingMessages then
      FClient.ProcessPendingMessages
    else
      Sleep(10);
  end;
end;

procedure TDashboardApp.Run;
begin
  {$IFDEF WINDOWS}
  SetConsoleOutputCP(CP_UTF8);
  {$ENDIF}

  if not FClient.Connect then
  begin
    WriteLn('ERROR: Failed to connect to AMI');
    Exit;
  end;

  FRunning := True;

  // Start message processing thread
  FMessageThread := TMethodThread.Create(@ProcessMessages);
  FMessageThread.Start;

  // Create and start dashboard
  FDashboard := TAMIDashboard.Create(FClient);
  FDashboard.Start;

  // Wait for user interrupt
  WriteLn('Dashboard running... Press Enter to exit');
  ReadLn;

  Stop;
end;

procedure TDashboardApp.Stop;
begin
  if not FRunning then
    Exit;

  FRunning := False;

  if Assigned(FDashboard) then
    FDashboard.Stop;

  if Assigned(FMessageThread) then
  begin
    FMessageThread.WaitFor;
    FreeAndNil(FMessageThread);
  end;

  if Assigned(FClient) then
    FClient.Disconnect;
end;

{ Main Program }

var
  App: TDashboardApp;

begin
  App := TDashboardApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;

  WriteLn('Dashboard terminated');
end.
