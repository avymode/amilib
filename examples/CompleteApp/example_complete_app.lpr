
Program example_complete_app;

{$mode objfpc}{$H+}

Uses 
  {$IFDEF UNIX}
cthreads,
  {$ENDIF}
Classes, SysUtils, syncobjs, DateUtils, TypInfo,
ami_client, ami_types, ami_actions, ami_events, ami_parser,ami_enums, ami_log;

Type 
  { Main application class }
  TAMIApp = Class
    Private 
      FClient: TAMIClient;
      FConfig: TAMIClientConfig;
      FRunning: Boolean;
      FStopEvent: TSimpleEvent;
      FMessageThread: TThread;
      FStatsThread: TThread;

      // Statistics
      FCallsToday: Integer;
      FActiveChannels: Integer;
      FStatLock: TCriticalSection;

      // Event handlers
      Procedure OnConnect(Sender: TObject);
      Procedure OnDisconnect(Sender: TObject);
      Procedure OnLog(Sender: TObject; Level: TAMILogLevel; Const Msg: String);

      Procedure OnNewChannel(Sender: TObject; Const Event: TAMIEvent);
      Procedure OnHangup(Sender: TObject; Const Event: TAMIEvent);
      Procedure OnDialBegin(Sender: TObject; Const Event: TAMIEvent);
      Procedure OnDialEnd(Sender: TObject; Const Event: TAMIEvent);
      Procedure OnQueueCallerJoin(Sender: TObject; Const Event: TAMIEvent);
      Procedure OnQueueCallerLeave(Sender: TObject; Const Event: TAMIEvent);

      // Threads
      Procedure MessageProcessorThread;
      Procedure StatsReporterThread;

      // Helpers
      Procedure LoadConfig;
      Procedure InitializeClient;
      Procedure SetupEventHandlers;
      Function FormatUptime(ASeconds: Integer): String;

    Public 
      constructor Create;
      destructor Destroy;
      override;

      Procedure Run;
      Procedure Stop;

      // Commands
      Procedure ShowStatus;
      Procedure ShowChannels;
      Procedure ShowQueues;
      Procedure OriginateTestCall;
  End;

  { Thread wrapper for methods }
  TMethodThread = Class(TThread)
    Private 
      FMethod: TThreadMethod;
    Protected 
      Procedure Execute;
      override;
    Public 
      constructor Create(AMethod: TThreadMethod);
  End;


{ TAMIApp }

  constructor TAMIApp.Create;
Begin
  inherited Create;
  FRunning := False;
  FStopEvent := TSimpleEvent.Create;
  FStatLock := TCriticalSection.Create;
  FCallsToday := 0;
  FActiveChannels := 0;

  LoadConfig;
  InitializeClient;
  SetupEventHandlers;
End;

destructor TAMIApp.Destroy;
Begin
  Stop;

  If Assigned(FClient) Then
    Begin
      FClient.Disconnect;
      FreeAndNil(FClient);
    End;

  FreeAndNil(FStopEvent);
  FreeAndNil(FStatLock);
  inherited Destroy;
End;

Procedure TAMIApp.LoadConfig;
Begin
  // Load from file or use defaults
  FConfig := Default(TAMIClientConfig);

  FConfig.Host := 'ASTERISK_HOST';
  FConfig.Port := 5038;
  FConfig.Username := 'AMI_USERNAME';
  FConfig.Password := 'AMI_PASSWORD';
  FConfig.AuthType := 'plain';
  FConfig.UTF8Enabled := True;

  FConfig.ConnectionTimeout := 10000;
  FConfig.ResponseTimeout := 30000;
  FConfig.ReadTimeout := 100;
  FConfig.WriteTimeout := 10000;

  FConfig.PingInterval := 30;
  FConfig.PingTimeout := 10;

  FConfig.MaxReconnectAttempts := 10;
  FConfig.ReconnectInterval := 5000;
  FConfig.ReconnectBackoff := True;

  FConfig.EventMask := 'call,user';
  FConfig.BufferSize := 16384;
End;

Procedure TAMIApp.InitializeClient;
Begin
  FClient := TAMIClient.Create(FConfig);

  // Set event handlers
  FClient.OnConnect := @OnConnect;
  FClient.OnDisconnect := @OnDisconnect;
  FClient.OnLog := @OnLog;
End;

Procedure TAMIApp.SetupEventHandlers;
Begin
  // Subscribe to important events
  FClient.SubscribeToEvent('Newchannel', @OnNewChannel);
  FClient.SubscribeToEvent('Hangup', @OnHangup);
  FClient.SubscribeToEvent('DialBegin', @OnDialBegin);
  FClient.SubscribeToEvent('DialEnd', @OnDialEnd);
  FClient.SubscribeToEvent('QueueCallerJoin', @OnQueueCallerJoin);
  FClient.SubscribeToEvent('QueueCallerLeave', @OnQueueCallerLeave);

  // Filter out noisy events
  FClient.AddEventFilter('VarSet', False);
  FClient.AddEventFilter('RTCPSent', False);
  FClient.AddEventFilter('RTCPReceived', False);
End;

Procedure TAMIApp.OnConnect(Sender: TObject);
Begin
  WriteLn('=================================');
  WriteLn('Connected to Asterisk AMI');
  WriteLn('Server: ', FConfig.Host, ':', FConfig.Port);
  WriteLn('=================================');
  WriteLn;
End;

Procedure TAMIApp.OnDisconnect(Sender: TObject);
Begin
  WriteLn('*** Disconnected from AMI server ***');
  WriteLn('Attempting reconnection...');
End;

Procedure TAMIApp.OnLog(Sender: TObject; Level: TAMILogLevel; Const Msg: String)
;

Const 
  LevelStr: array[TAMILogLevel] Of String = (
                                             'DEBUG', 'INFO ', 'WARN ', 'ERROR',
                                             'CRIT '
                                            );
Begin
  If Level >= llInfo Then
    WriteLn(Format('[%s] [%s] %s', [
            FormatDateTime('hh:nn:ss', Now),
    LevelStr[Level],
    Msg
    ]));
End;

Procedure TAMIApp.OnNewChannel(Sender: TObject; Const Event: TAMIEvent);

Var 
  Info: TChannelInfo;
Begin
  Info := TAMIEventParser.ParseChannelInfo(Event);

  FStatLock.Enter;
  Try
    Inc(FActiveChannels);
    Inc(FCallsToday);
  Finally
    FStatLock.Leave;
End;

WriteLn(Format('[CALL] New channel: %s from %s', [
        Info.Channel,
        Info.CallerIDNum
        ]));
End;

Procedure TAMIApp.OnHangup(Sender: TObject; Const Event: TAMIEvent);

Var 
  Info: THangupInfo;
Begin
  Info := TAMIEventParser.ParseHangupInfo(Event);

  FStatLock.Enter;
  Try
    Dec(FActiveChannels);
  Finally
    FStatLock.Leave;
End;

WriteLn(Format('[CALL] Hangup: %s - Cause: %d (%s)', [
        Info.Channel,
        Info.Cause,
        Info.CauseTxt
        ]));
End;

Procedure TAMIApp.OnDialBegin(Sender: TObject; Const Event: TAMIEvent);

Var 
  Info: TDialInfo;
Begin
  Info := TAMIEventParser.ParseDialInfo(Event);
  WriteLn(Format('[DIAL] Begin: %s -> %s', [
          Info.Channel,
          Info.Destination
          ]));
End;

Procedure TAMIApp.OnDialEnd(Sender: TObject; Const Event: TAMIEvent);

Var 
  Info: TDialInfo;
Begin
  Info := TAMIEventParser.ParseDialInfo(Event);
  WriteLn(Format('[DIAL] End: %s - Status: %s', [
          Info.Channel,
          Info.DialStatus
          ]));
End;

Procedure TAMIApp.OnQueueCallerJoin(Sender: TObject; Const Event: TAMIEvent);
Begin
  WriteLn(Format('[QUEUE] Caller joined: %s - Position: %s', [
          Event.GetField('Queue'),
  Event.GetField('Position')
  ]));
End;

Procedure TAMIApp.OnQueueCallerLeave(Sender: TObject; Const Event: TAMIEvent);
Begin
  WriteLn(Format('[QUEUE] Caller left: %s - Count: %s', [
          Event.GetField('Queue'),
  Event.GetField('Count')
  ]));
End;

Procedure TAMIApp.MessageProcessorThread;
Begin
  WriteLn('[Thread] Message processor started');

  While FRunning Do
    Begin
      Try
        // Process priority messages first
        If FClient.HasPendingPriorityMessages Then
          FClient.ProcessPendingPriorityMessages
        Else If FClient.HasPendingMessages Then
               FClient.ProcessPendingMessages
        Else
          Sleep(10);
      Except
        on E: Exception Do
              WriteLn('[ERROR] Message processor: ', E.Message);
    End;
End;

WriteLn('[Thread] Message processor stopped');
End;

Procedure TAMIApp.StatsReporterThread;

Var 
  LastReport: TDateTime;
Begin
  WriteLn('[Thread] Stats reporter started');
  LastReport := Now;

  While FRunning Do
    Begin
      Sleep(1000);

      // Report stats every 60 seconds
      If SecondsBetween(Now, LastReport) >= 60 Then
        Begin
          WriteLn;
          WriteLn('=== Statistics ===');
          ShowStatus;
          WriteLn('==================');
          WriteLn;
          LastReport := Now;
        End;
    End;

  WriteLn('[Thread] Stats reporter stopped');
End;

Function TAMIApp.FormatUptime(ASeconds: Integer): String;

Var 
  Days, Hours, Minutes, Seconds: Integer;
Begin
  Days := ASeconds Div 86400;
  ASeconds := ASeconds Mod 86400;
  Hours := ASeconds Div 3600;
  ASeconds := ASeconds Mod 3600;
  Minutes := ASeconds Div 60;
  Seconds := ASeconds Mod 60;

  If Days > 0 Then
    Result := Format('%dd %dh %dm %ds', [Days, Hours, Minutes, Seconds])
  Else If Hours > 0 Then
         Result := Format('%dh %dm %ds', [Hours, Minutes, Seconds])
  Else
    Result := Format('%dm %ds', [Minutes, Seconds]);
End;

Procedure TAMIApp.Run;

Var 
  Command: String;
Begin
  WriteLn('AMI Client Application Starting...');
  WriteLn;

  // Connect to Asterisk
  If Not FClient.Connect Then
    Begin
      WriteLn('ERROR: Failed to connect to AMI server');
      WriteLn('Last error: ', FClient.Config.Host);
      Exit;
    End;

  FRunning := True;

  // Start worker threads - ИСПРАВЛЕНО
  FMessageThread := TMethodThread.Create(@MessageProcessorThread);
  FMessageThread.Start;

  FStatsThread := TMethodThread.Create(@StatsReporterThread);
  FStatsThread.Start;

  WriteLn;
  WriteLn('Application running. Commands:');
  WriteLn('  status   - Show status');
  WriteLn('  channels - List active channels');
  WriteLn('  queues   - Show queue status');
  WriteLn('  call     - Originate test call');
  WriteLn('  quit     - Exit application');
  WriteLn;

  // Command loop
  While FRunning Do
    Begin
      Write('> ');
      ReadLn(Command);
      Command := LowerCase(Trim(Command));

      Case Command Of 
        'status': ShowStatus;
        'channels': ShowChannels;
        'queues': ShowQueues;
        'call': OriginateTestCall;
        'quit', 'exit', 'q': Break;
        '': ;
        // Ignore empty input
        Else
          WriteLn('Unknown command: ', Command);
      End;
    End;

  Stop;
End;

Procedure TAMIApp.Stop;
Begin
  If Not FRunning Then
    Exit;

  WriteLn;
  WriteLn('Shutting down...');

  FRunning := False;
  FStopEvent.SetEvent;

  // Wait for threads
  If Assigned(FMessageThread) Then
    Begin
      FMessageThread.WaitFor;
      FreeAndNil(FMessageThread);
    End;

  If Assigned(FStatsThread) Then
    Begin
      FStatsThread.WaitFor;
      FreeAndNil(FStatsThread);
    End;

  WriteLn('Shutdown complete');
End;

Procedure TAMIApp.ShowStatus;

Var 
  Uptime: Integer;
  Stats: String;
Begin
  WriteLn('Connection Status:');
  WriteLn('  Server: ', FConfig.Host, ':', FConfig.Port);
  WriteLn('  Status: ', GetEnumName(TypeInfo(TAMIClientStatus), Ord(FClient.Status)));

  Uptime := FClient.GetUptime;
  WriteLn('  Uptime: ', FormatUptime(Uptime));

  FStatLock.Enter;
  Try
    WriteLn('  Active Channels: ', FActiveChannels);
    WriteLn('  Calls Today: ', FCallsToday);
  Finally
    FStatLock.Leave;
End;

WriteLn;
WriteLn('Performance:');
WriteLn('  Events/sec: ', FClient.GetEventsPerSecond:0:2);
WriteLn('  Actions/sec: ', FClient.GetActionsPerSecond:0:2);
WriteLn('  Total Events: ', FClient.TotalEvents);
WriteLn('  Total Actions: ', FClient.TotalActions);
WriteLn('  Failed Actions: ', FClient.FailedActions);
End;

Procedure TAMIApp.ShowChannels;

Var 
  Response: TAMIResponse;
Begin
  WriteLn('Requesting channel list...');

  Response := FClient.ChannelList(10000);
  Try
    If Assigned(Response) And Response.IsSuccess Then
      WriteLn('Channel list requested (check events)')
    Else
      WriteLn('Failed to get channel list');
  Finally
    If Assigned(Response) Then
      Response.Free;
End;
End;

Procedure TAMIApp.ShowQueues;

Var 
  Response: TAMIResponse;
Begin
  WriteLn('Requesting queue status...');

  Response := FClient.QueueStatus('', 10000);
  Try
    If Assigned(Response) And Response.IsSuccess Then
      WriteLn('Queue status requested (check events)')
    Else
      WriteLn('Failed to get queue status');
  Finally
    If Assigned(Response) Then
      Response.Free;
End;
End;

Procedure TAMIApp.OriginateTestCall;

Var 
  Params: TOriginateParams;
  Response: TAMIResponse;
Begin
  WriteLn('Originating test call...');

  Params := Default(TOriginateParams);
  Params.Channel := 'Local/100@default';
  Params.Context := 'default';
  Params.Extension := '200';
  Params.Priority := '1';
  Params.CallerID := 'Test Call <9999>';
  Params.Timeout := 30000;
  Params.Async := True;

  Response := FClient.Originate(Params, 10000);
  Try
    If Assigned(Response) And Response.IsSuccess Then
      WriteLn('Call originated successfully')
    Else If Assigned(Response) Then
           WriteLn('Failed to originate call: ', Response.Message)
    Else
      WriteLn('Failed to originate call: Timeout');
  Finally
    If Assigned(Response) Then
      Response.Free;
End;
End;

constructor TMethodThread.Create(AMethod: TThreadMethod);
Begin
  inherited Create(False);
  FreeOnTerminate := False;
  FMethod := AMethod;
End;

Procedure TMethodThread.Execute;
Begin
  If Assigned(FMethod) Then
    FMethod();
End;


{ Main Program }

Var 
  App: TAMIApp;

{$IFDEF UNIX}
Procedure SignalHandler(Signal: LongInt);
cdecl;
Begin
  WriteLn;
  WriteLn('Received signal ', Signal);
  If Assigned(App) Then
    App.Stop;
End;
{$ENDIF}

Begin
  {$IFDEF UNIX}
  // Setup signal handlers for graceful shutdown
  FpSignal(SIGTERM, @SignalHandler);
  FpSignal(SIGINT, @SignalHandler);
  {$ENDIF}

  App := TAMIApp.Create;
  Try
    App.Run;
  Finally
    App.Free;
End;

WriteLn('Application terminated');
End.
