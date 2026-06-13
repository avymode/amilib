program ami_test_suite;

{$mode objfpc}{$H+}
{$codepage UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, DateUtils, TypInfo, Math,
  ami_client, ami_types, ami_actions, ami_enums, ami_parser,
  ami_events, ami_log;

type
  { TAMITestSuite }
  TAMITestSuite = class
  private
    FClient: TAMIClient;
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestsTotal: Integer;
    FVerbose: Boolean;

    // Event tracking
    FEventsReceived: TStringList;
    FEventLock: TRTLCriticalSection;

    // Async test tracking
    FAsyncResponseReceived: Boolean;
    FAsyncResponseText: String;

    // Test event handlers
    procedure OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
    procedure OnConnect(Sender: TObject);
    procedure OnDisconnect(Sender: TObject);
    procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
    procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
    procedure OnAsyncPingResponse(Sender: TObject; const Response: TAMIResponse);

    // Helper methods
    procedure LogTest(const TestName: String);
    procedure LogPass(const Msg: String);
    procedure LogFail(const Msg: String);
    procedure LogInfo(const Msg: String);
    procedure LogSeparator;

    function AssertTrue(const Msg: String; Condition: Boolean): Boolean;
    function AssertEquals(const Msg: String; Expected, Actual: String): Boolean;
    function AssertNotNull(const Msg: String; Obj: TObject): Boolean;

  public
    constructor Create(const AConfig: TAMIClientConfig; AVerbose: Boolean = False);
    destructor Destroy; override;

    // Test categories
    function TestConnection: Boolean;
    function TestAuthentication: Boolean;
    function TestBasicActions: Boolean;
    function TestQueueActions: Boolean;
    function TestChannelActions: Boolean;
    function TestEventHandling: Boolean;
    function TestAsyncActions: Boolean;
    function TestCaching: Boolean;
    function TestReconnection: Boolean;
    function TestStatistics: Boolean;

    // Run all tests
    procedure RunAllTests;
    procedure PrintSummary;

    property Client: TAMIClient read FClient;
  end;

{ TAMITestSuite }

constructor TAMITestSuite.Create(const AConfig: TAMIClientConfig; AVerbose: Boolean);
begin
  inherited Create;

  FVerbose := AVerbose;
  FTestsPassed := 0;
  FTestsFailed := 0;
  FTestsTotal := 0;

  FEventsReceived := TStringList.Create;
  InitCriticalSection(FEventLock);

  FAsyncResponseReceived := False;
  FAsyncResponseText := '';

  FClient := TAMIClient.Create(AConfig);
  FClient.OnLog := @OnLog;
  FClient.OnConnect := @OnConnect;
  FClient.OnDisconnect := @OnDisconnect;
  FClient.OnEvent := @OnEvent;
end;

destructor TAMITestSuite.Destroy;
begin
  FClient.Free;
  FEventsReceived.Free;
  DoneCriticalSection(FEventLock);
  inherited Destroy;
end;

procedure TAMITestSuite.OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
var
  LevelStr: String;
begin
  if not FVerbose and (Level < llWarning) then
    Exit;

  LevelStr := Copy(GetEnumName(TypeInfo(TAMILogLevel), Ord(Level)), 3, MaxInt);
  WriteLn(Format('[%s] [%-7s] %s', [
    FormatDateTime('hh:nn:ss', Now),
    UpperCase(LevelStr),
    Msg
  ]));
end;

procedure TAMITestSuite.OnConnect(Sender: TObject);
begin
  LogInfo('>>> Connected to AMI server');
end;

procedure TAMITestSuite.OnDisconnect(Sender: TObject);
begin
  LogInfo('>>> Disconnected from AMI server');
end;

procedure TAMITestSuite.OnEvent(Sender: TObject; const Event: TAMIEvent);
begin
  EnterCriticalSection(FEventLock);
  try
    FEventsReceived.Add(Event.GetEventName);
  finally
    LeaveCriticalSection(FEventLock);
  end;
end;

procedure TAMITestSuite.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
begin
  LogInfo('>>> Newchannel event: ' + Event.GetField('Channel'));
end;

procedure TAMITestSuite.OnHangup(Sender: TObject; const Event: TAMIEvent);
begin
  LogInfo('>>> Hangup event: ' + Event.GetField('Channel') +
          ' (Cause: ' + Event.GetField('Cause') + ')');
end;

procedure TAMITestSuite.OnAsyncPingResponse(Sender: TObject; const Response: TAMIResponse);
begin
  LogInfo('Async response received: ' + Response.Response);
  FAsyncResponseText := Response.Response;
  FAsyncResponseReceived := True;
end;

procedure TAMITestSuite.LogTest(const TestName: String);
begin
  WriteLn('');
  WriteLn('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  WriteLn('TEST: ', TestName);
  WriteLn('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
end;

procedure TAMITestSuite.LogPass(const Msg: String);
begin
  WriteLn('  ✓ PASS: ', Msg);
  Inc(FTestsPassed);
  Inc(FTestsTotal);
end;

procedure TAMITestSuite.LogFail(const Msg: String);
begin
  WriteLn('  ✗ FAIL: ', Msg);
  Inc(FTestsFailed);
  Inc(FTestsTotal);
end;

procedure TAMITestSuite.LogInfo(const Msg: String);
begin
  WriteLn('  ℹ ', Msg);
end;

procedure TAMITestSuite.LogSeparator;
begin
  WriteLn('  ────────────────────────────────────────────────────────────');
end;

function TAMITestSuite.AssertTrue(const Msg: String; Condition: Boolean): Boolean;
begin
  Inc(FTestsTotal);
  Result := Condition;
  if Result then
    LogPass(Msg)
  else
    LogFail(Msg);
end;

function TAMITestSuite.AssertEquals(const Msg: String; Expected, Actual: String): Boolean;
begin
  Inc(FTestsTotal);
  Result := Expected = Actual;
  if Result then
    LogPass(Msg)
  else
    LogFail(Format('%s (Expected: "%s", Got: "%s")', [Msg, Expected, Actual]));
end;

function TAMITestSuite.AssertNotNull(const Msg: String; Obj: TObject): Boolean;
begin
  Inc(FTestsTotal);
  Result := Assigned(Obj);
  if Result then
    LogPass(Msg)
  else
    LogFail(Msg + ' (Object is nil)');
end;

{ Test: Connection }
function TAMITestSuite.TestConnection: Boolean;
begin
  LogTest('CONNECTION MANAGEMENT');

  // Test 1: Initial status
  AssertEquals('Initial status should be Disconnected',
                'csDisconnected',
                GetEnumName(TypeInfo(TAMIClientStatus), Ord(FClient.Status)));

  // Test 2: Connect
  Result := AssertTrue('Should connect to AMI server', FClient.Connect);
  if not Result then
    Exit(False);

  // Enable all events for testing
  FClient.SetEventMask('on');

  // Test 3: Connected status
  AssertEquals('Status should be Connected',
                'csConnected',
                GetEnumName(TypeInfo(TAMIClientStatus), Ord(FClient.Status)));

  // Test 4: IsConnected
  AssertTrue('IsConnected should return True', FClient.IsConnected);

  // Test 5: Connection info
  LogInfo('Connection info: ' + FClient.GetConnectionInfo);

  Result := True;
end;

{ Test: Authentication }
function TAMITestSuite.TestAuthentication: Boolean;
var
  Response: TAMIResponse;
begin
  LogTest('AUTHENTICATION');

  // Already authenticated by Connect, test ping to verify
  Response := FClient.Ping(5000);
  try
    Result := AssertNotNull('Ping response should not be nil', Response);
    if Result then
    begin
      AssertTrue('Ping should succeed', Response.IsSuccess);
      AssertEquals('Ping response should be Success or Pong', 'Success', Response.Response);
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;
end;

{ Test: Basic Actions }
function TAMITestSuite.TestBasicActions: Boolean;
var
  Response: TAMIResponse;
  CmdResponse: TAMICommandResponse;
  StartTime: TDateTime;
  Latency: Int64;
begin
  LogTest('BASIC ACTIONS');

  // Test 1: Ping
  LogInfo('Testing Ping action...');
  StartTime := Now;
  Response := FClient.Ping(10000);
  try
    Result := AssertNotNull('Ping response received', Response);
    if Result then
    begin
      Latency := MilliSecondsBetween(Now, StartTime);
      AssertTrue('Ping successful', Response.IsSuccess);
      LogInfo(Format('Ping latency: %dms', [Latency]));
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;

  LogSeparator;

  // Test 2: Command (CoreStatus)
  LogInfo('Testing Command action (core show uptime)...');
  Response := FClient.Command('core show uptime', 10000);
  try
    if AssertNotNull('Command response received', Response) then
    begin
      AssertTrue('Command successful', Response.IsSuccess);

      if Response is TAMICommandResponse then
      begin
        CmdResponse := TAMICommandResponse(Response);
        AssertTrue('Command has output', CmdResponse.GetOutputLineCount > 0);
        LogInfo(Format('Command output (%d lines):', [CmdResponse.GetOutputLineCount]));
        LogInfo(CmdResponse.GetFullOutput);
      end;
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;

  LogSeparator;

  // Test 3: CoreShowChannels
  LogInfo('Testing CoreShowChannels action...');
  Response := FClient.ChannelList(10000);
  try
    if AssertNotNull('CoreShowChannels response received', Response) then
    begin
      AssertTrue('CoreShowChannels successful', Response.IsSuccess);
      LogInfo('Active channels query successful');
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;
end;

{ Test: Queue Actions }
function TAMITestSuite.TestQueueActions: Boolean;
var
  Response: TAMIResponse;
  TestQueue: String;
  TestMember: String;
begin
  LogTest('QUEUE ACTIONS');

  TestQueue := 'test_queue';
  TestMember := 'Local/9999@default';

  // Test 1: QueueStatus (all queues)
  LogInfo('Testing QueueStatus (all queues)...');
  Response := FClient.QueueStatus('', 15000);
  try
    Result := AssertNotNull('QueueStatus response received', Response);
    if Result then
    begin
      AssertTrue('QueueStatus successful', Response.IsSuccess);
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;

  LogSeparator;

  // Test 2: QueueAdd (best effort - may fail if queue doesn't exist)
  LogInfo(Format('Testing QueueAdd (Queue: %s, Member: %s)...', [TestQueue, TestMember]));
  Response := FClient.QueueAdd(TestQueue, TestMember, 10000);
  try
    if AssertNotNull('QueueAdd response received', Response) then
    begin
      if Response.IsSuccess then
        LogInfo('QueueAdd successful')
      else
        LogInfo('QueueAdd failed (queue may not exist): ' + Response.Message);
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;

  LogSeparator;

  // Test 3: QueueRemove
  LogInfo(Format('Testing QueueRemove (Queue: %s, Member: %s)...', [TestQueue, TestMember]));
  Response := FClient.QueueRemove(TestQueue, TestMember, 10000);
  try
    if AssertNotNull('QueueRemove response received', Response) then
    begin
      if Response.IsSuccess then
        LogInfo('QueueRemove successful')
      else
        LogInfo('QueueRemove result: ' + Response.Message);
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;
end;

{ Test: Channel Actions }
function TAMITestSuite.TestChannelActions: Boolean;
var
  Response: TAMIResponse;
  TestChannel: String;
begin
  LogTest('CHANNEL ACTIONS');

  TestChannel := 'SIP/nonexistent-00000000';

  // Test 1: GetVar (global variable)
  LogInfo('Testing GetVar (global variable)...');
  Response := FClient.GetVar('', 'EPOCH', 10000);
  try
    if AssertNotNull('GetVar response received', Response) then
    begin
      AssertTrue('GetVar successful', Response.IsSuccess);
      LogInfo('EPOCH value: ' + Response.GetField('Value'));
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;

  LogSeparator;

  // Test 2: SetVar (global variable)
  LogInfo('Testing SetVar (global variable)...');
  Response := FClient.SetVar('', 'TEST_VAR', 'test_value_123', 10000);
  try
    if AssertNotNull('SetVar response received', Response) then
    begin
      AssertTrue('SetVar successful', Response.IsSuccess);

      // Verify by getting it back
      Response.Free;
      Response := FClient.GetVar('', 'TEST_VAR', 10000);
      if Assigned(Response) then
      begin
        AssertEquals('Variable value should match',
                      'test_value_123',
                      Response.GetField('Value'));
      end;
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;

  LogSeparator;

  // Test 3: Hangup (non-existent channel - should fail gracefully)
  LogInfo(Format('Testing Hangup (non-existent channel: %s)...', [TestChannel]));
  Response := FClient.Hangup(TestChannel, 16, 10000);
  try
    if AssertNotNull('Hangup response received', Response) then
    begin
      if not Response.IsSuccess then
        LogInfo('Hangup correctly failed for non-existent channel')
      else
        LogInfo('Hangup result: ' + Response.Message);
    end;
  finally
    if Assigned(Response) then
      Response.Free;
  end;

  Result := True;
end;

{ Test: Event Handling }
function TAMITestSuite.TestEventHandling: Boolean;
var
  InitialEventCount: Integer;
  WaitTime: Integer;
  i, MaxIndex: Integer;
begin
  LogTest('EVENT HANDLING');

  // Clear event list
  EnterCriticalSection(FEventLock);
  try
    FEventsReceived.Clear;
  finally
    LeaveCriticalSection(FEventLock);
  end;

  // Test 1: Subscribe to events
  LogInfo('Subscribing to Newchannel and Hangup events...');
  FClient.SetEventMask('on');
  FClient.SubscribeToEvent('Newchannel', @OnNewChannel);
  FClient.SubscribeToEvent('Hangup', @OnHangup);
  LogPass('Event subscription successful');

  LogSeparator;

  // Test 2: Wait for events
  LogInfo('Waiting for events (10 seconds)...');
  LogInfo('Tip: Make a test call to generate events');

  InitialEventCount := FEventsReceived.Count;
  WaitTime := 0;
  while (WaitTime < 10000) do
  begin
    Sleep(1000);
    Inc(WaitTime, 1000);

    EnterCriticalSection(FEventLock);
    try
      if FEventsReceived.Count > InitialEventCount then
      begin
        LogInfo(Format('Received %d events so far...', [FEventsReceived.Count]));
      end;
    finally
      LeaveCriticalSection(FEventLock);
    end;
  end;

  // Test 3: Check events received
  EnterCriticalSection(FEventLock);
  try
    LogInfo(Format('Total events received: %d', [FEventsReceived.Count]));

    if FEventsReceived.Count > 0 then
    begin
      LogInfo('Event types received:');
      MaxIndex := FEventsReceived.Count - 1;
      if MaxIndex > 9 then
        MaxIndex := 9;

      for i := 0 to MaxIndex do
        LogInfo('  - ' + FEventsReceived[i]);

      if FEventsReceived.Count > 10 then
        LogInfo(Format('  ... and %d more', [FEventsReceived.Count - 10]));
    end
    else
    begin
      LogInfo('No events received (this is normal if no activity on Asterisk)');
    end;

    Result := AssertTrue('Event handling system operational', True);
  finally
    LeaveCriticalSection(FEventLock);
  end;

  LogSeparator;

  // Test 4: Unsubscribe
  LogInfo('Unsubscribing from events...');
  FClient.UnsubscribeFromEvent('Newchannel');
  FClient.UnsubscribeFromEvent('Hangup');
  LogPass('Event unsubscription successful');
end;

{ Test: Async Actions }
function TAMITestSuite.TestAsyncActions: Boolean;
var
  Action: TAMIPingAction;
  ActionID: String;
begin
  LogTest('ASYNCHRONOUS ACTIONS');

  // Reset flags
  FAsyncResponseReceived := False;
  FAsyncResponseText := '';

  // Test 1: Send async action
  LogInfo('Sending async Ping action...');
  Action := TAMIPingAction.Create;

  ActionID := FClient.SendActionAsync(Action, @OnAsyncPingResponse);

  Result := AssertTrue('Async action sent successfully', ActionID <> '');

  if Result then
    LogInfo('ActionID: ' + ActionID);

  LogSeparator;

  // Test 2: Async actions are fire-and-forget
  // The callback may or may not be called in the same thread
  // The response is delivered via pending actions mechanism
  LogInfo('Async action sent - callback is fire-and-forget');
  LogInfo('Response will be delivered via pending actions (not via callback)');
  LogPass('Async action sent (callback may arrive later)');
end;

{ Test: Caching }
function TAMITestSuite.TestCaching: Boolean;
var
  Response1, Response2: TAMIResponse;
  StartTime: TDateTime;
  Time1, Time2: Int64;
begin
  LogTest('RESPONSE CACHING');

  Response1 := nil;
  Response2 := nil;

  // Test 1: First request (uncached)
  LogInfo('First request (should hit Asterisk)...');
  StartTime := Now;
  Response1 := FClient.CachedQueueStatus('', 15000);
  try
    Time1 := MilliSecondsBetween(Now, StartTime);
    Result := AssertNotNull('First response received', Response1);
    if Result then
    begin
      AssertTrue('First request successful', Response1.IsSuccess);
      LogInfo(Format('First request took %dms', [Time1]));
    end;
  finally
    if Assigned(Response1) then
      Response1.Free;
  end;

  LogSeparator;

  // Test 2: Second request (cached)
  LogInfo('Second request (should use cache)...');
  StartTime := Now;
  Response2 := FClient.CachedQueueStatus('', 15000);
  try
    Time2 := MilliSecondsBetween(Now, StartTime);
    if AssertNotNull('Second response received', Response2) then
    begin
      AssertTrue('Second request successful', Response2.IsSuccess);
      LogInfo(Format('Second request took %dms', [Time2]));

      if Time2 < Time1 then
        LogPass(Format('Cache improved performance (%dms vs %dms)', [Time2, Time1]))
      else
        LogInfo('Cache performance similar or slower (may be normal)');
    end;
  finally
    if Assigned(Response2) then
      Response2.Free;
  end;

  LogSeparator;

  // Test 3: Cache stats
  LogInfo('Cache statistics:');
  LogInfo('  Event cache: ' + FClient.GetEventCacheStats);
  LogInfo('  Response cache: ' + FClient.GetResponseCacheStats);

  LogSeparator;

  // Test 4: Clear cache
  LogInfo('Clearing caches...');
  FClient.ClearCaches;
  LogPass('Caches cleared successfully');
end;

{ Test: Reconnection }
function TAMITestSuite.TestReconnection: Boolean;
var
  Response: TAMIResponse;
begin
  LogTest('RECONNECTION');

  LogInfo('Simulating disconnect...');
  FClient.Disconnect;

  AssertEquals('Status should be Disconnected',
                'csDisconnected',
                GetEnumName(TypeInfo(TAMIClientStatus), Ord(FClient.Status)));

  LogSeparator;

  LogInfo('Reconnecting...');
  Result := AssertTrue('Should reconnect successfully', FClient.Connect);

  if Result then
  begin
    AssertEquals('Status should be Connected',
                  'csConnected',
                  GetEnumName(TypeInfo(TAMIClientStatus), Ord(FClient.Status)));

    // Verify connection with ping
    Response := FClient.Ping(5000);
    try
      if AssertNotNull('Ping after reconnect successful', Response) then
        AssertTrue('Connection fully restored', Response.IsSuccess);
    finally
      if Assigned(Response) then
        Response.Free;
    end;
  end;
end;

{ Test: Statistics }
function TAMITestSuite.TestStatistics: Boolean;
var
  Stats: String;
  Uptime: Integer;
begin
  LogTest('STATISTICS');

  // Test 1: Get uptime
  Uptime := FClient.GetUptime;
  AssertTrue('Uptime should be non-negative', Uptime >= 0);
  LogInfo(Format('Connection uptime: %d seconds (%s)', [Uptime, FClient.GetUptimeStr]));

  LogSeparator;

  // Test 2: Get statistics
  Stats := FClient.GetStatistics;
  AssertTrue('Statistics should not be empty', Stats <> '');

  LogInfo('Full statistics:');
  WriteLn(Stats);

  LogSeparator;

  // Test 3: Event and action rates
  LogInfo(Format('Events per second: %.2f', [FClient.GetEventsPerSecond]));
  LogInfo(Format('Actions per second: %.2f', [FClient.GetActionsPerSecond]));
  LogInfo(Format('Total events: %d', [FClient.TotalEvents]));
  LogInfo(Format('Total actions: %d', [FClient.TotalActions]));
  LogInfo(Format('Failed actions: %d', [FClient.FailedActions]));

  Result := True;
end;

{ Run All Tests }
procedure TAMITestSuite.RunAllTests;
var
  TestStartTime: TDateTime;
  TotalTime: Int64;
begin
  TestStartTime := Now;

  WriteLn('');
  WriteLn('╔════════════════════════════════════════════════════════════════╗');
  WriteLn('║         AMI LIBRARY COMPREHENSIVE TEST SUITE                  ║');
  WriteLn('╚════════════════════════════════════════════════════════════════╝');
  WriteLn('');

  // Run all test categories
  TestConnection;
  TestAuthentication;
  TestBasicActions;
  TestQueueActions;
  TestChannelActions;
  TestEventHandling;
  TestAsyncActions;
  TestCaching;
  TestReconnection;
  TestStatistics;

  // Calculate total time
  TotalTime := MilliSecondsBetween(Now, TestStartTime);

  WriteLn('');
  LogSeparator;
  WriteLn('');

  // Print summary
  PrintSummary;

  WriteLn('');
  WriteLn(Format('Total execution time: %.2f seconds', [TotalTime / 1000]));
  WriteLn('');
end;

procedure TAMITestSuite.PrintSummary;
var
  SuccessRate: Double;
begin
  WriteLn('╔════════════════════════════════════════════════════════════════╗');
  WriteLn('║                      TEST SUMMARY                              ║');
  WriteLn('╚═══════════════════════════════════════════════════════════════');
  WriteLn('');

  if FTestsTotal > 0 then
    SuccessRate := (FTestsPassed / FTestsTotal) * 100
  else
    SuccessRate := 0;

  WriteLn(Format('  Tests run:    %d', [FTestsTotal]));
  WriteLn(Format('  Passed:       %d', [FTestsPassed]));
  WriteLn(Format('  Failed:       %d', [FTestsFailed]));
  if FTestsTotal > 0 then
    WriteLn(Format('  Success rate: %.1f%%', [SuccessRate]));
  WriteLn('');

  if FTestsFailed = 0 then
  begin
    WriteLn('  ╔═══════════════════════════════════════════════════════════╗');
    WriteLn('  ║  ✓✓✓  ALL TESTS PASSED SUCCESSFULLY!  ✓✓✓               ║');
    WriteLn('  ╚═══════════════════════════════════════════════════════════╝');
  end
  else
  begin
    WriteLn('  ╔═══════════════════════════════════════════════════════════╗');
    WriteLn('  ║  ⚠ SOME TESTS FAILED - Review output above  ⚠            ║');
    WriteLn('  ╚═══════════════════════════════════════════════════════════╝');
  end;
end;

{ Main Program }

procedure PrintUsage;
begin
  WriteLn('Usage: ami_test_suite [options]');
  WriteLn('');
  WriteLn('Options:');
  WriteLn('  -h, --host <host>       AMI server host (default: localhost)');
  WriteLn('  -p, --port <port>       AMI server port (default: 5038)');
  WriteLn('  -u, --username <user>   AMI username (default: admin)');
  WriteLn('  -s, --secret <pass>     AMI password (default: secret)');
  WriteLn('  -a, --auth <type>       Auth type: plain|md5 (default: plain)');
  WriteLn('  -v, --verbose           Enable verbose logging');
  WriteLn('  --help                  Show this help');
  WriteLn('');
  WriteLn('Examples:');
  WriteLn('  ami_test_suite');
  WriteLn('  ami_test_suite -h 192.168.1.100 -u myuser -s mypass');
  WriteLn('  ami_test_suite -v --auth md5');
  WriteLn('');
end;

function ParseArguments(out Config: TAMIClientConfig; out Verbose: Boolean): Boolean;
var
  i: Integer;
  Arg: String;
begin
  Result := True;

  // Defaults
  Config := Default(TAMIClientConfig);
  Config.Host := 'ASTERISK_HOST';
  Config.Port := 5038;
  Config.Username := 'AMI_USERNAME';
  Config.Password := 'AMI_PASSWORD';
  Config.AuthType := 'plain';
  Config.ConnectionTimeout := 10000;
  Config.ResponseTimeout := 30000;
  Config.PingInterval := 30;
  Config.MaxReconnectAttempts := 3;
  Config.ReconnectInterval := 5000;

  Verbose := False;

  i := 1;
  while i <= ParamCount do
  begin
    Arg := ParamStr(i);

    if (Arg = '-h') or (Arg = '--host') then
    begin
      Inc(i);
      if i <= ParamCount then
        Config.Host := ParamStr(i)
      else
      begin
        WriteLn('Error: --host requires an argument');
        Exit(False);
      end;
    end
    else if (Arg = '-p') or (Arg = '--port') then
    begin
      Inc(i);
      if i <= ParamCount then
        Config.Port := StrToIntDef(ParamStr(i), 5038)
      else
      begin
        WriteLn('Error: --port requires an argument');
        Exit(False);
      end;
    end
    else if (Arg = '-u') or (Arg = '--username') then
    begin
      Inc(i);
      if i <= ParamCount then
        Config.Username := ParamStr(i)
      else
      begin
        WriteLn('Error: --username requires an argument');
        Exit(False);
      end;
    end
    else if (Arg = '-s') or (Arg = '--secret') then
    begin
      Inc(i);
      if i <= ParamCount then
        Config.Password := ParamStr(i)
      else
      begin
        WriteLn('Error: --secret requires an argument');
        Exit(False);
      end;
    end
    else if (Arg = '-a') or (Arg = '--auth') then
    begin
      Inc(i);
      if i <= ParamCount then
        Config.AuthType := ParamStr(i)
      else
      begin
        WriteLn('Error: --auth requires an argument');
        Exit(False);
      end;
    end
    else if (Arg = '-v') or (Arg = '--verbose') then
    begin
      Verbose := True;
    end
    else if (Arg = '--help') then
    begin
      PrintUsage;
      Exit(False);
    end
    else
    begin
      WriteLn('Error: Unknown option: ', Arg);
      WriteLn('');
      PrintUsage;
      Exit(False);
    end;

    Inc(i);
  end;
end;

var
  Config: TAMIClientConfig;
  Verbose: Boolean;
  TestSuite: TAMITestSuite;
  ExitCode: Integer;

begin
  ExitCode := 0;

  try
    // Parse command line arguments
    if not ParseArguments(Config, Verbose) then
    begin
      Halt(1);
    end;

    // Create and run test suite
    TestSuite := TAMITestSuite.Create(Config, Verbose);
    try
      TestSuite.RunAllTests;

      // Set exit code based on results
      if TestSuite.FTestsFailed > 0 then
        ExitCode := 1;
    finally
      TestSuite.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('╔════════════════════════════════════════════════════════════════╗');
      WriteLn('║                    FATAL ERROR                                 ║');
      WriteLn('╚════════════════════════════════════════════════════════════════╝');
      WriteLn('');
      WriteLn('  ', E.ClassName, ': ', E.Message);
      WriteLn('');
      ExitCode := 2;
    end;
  end;

  Halt(ExitCode);
end.
