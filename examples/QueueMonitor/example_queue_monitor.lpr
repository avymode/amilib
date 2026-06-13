program example_queue_monitor;

{$mode objfpc}{$H+}
{$codepage UTF8}

uses
  Crt, SysUtils, Classes, TypInfo, ami_client, ami_types, ami_events,
  ami_enums, ami_log;

type
  TQueueMonitor = class
  private
    FClient: TAMIClient;
    FQueueStats: TStringList;

    procedure OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
    procedure OnQueueParams(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueMember(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueEntry(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueCallerJoin(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueCallerLeave(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueMemberStatus(Sender: TObject; const Event: TAMIEvent);

    procedure DisplayQueueStats;
  public
    constructor Create(const AConfig: TAMIClientConfig);
    destructor Destroy; override;
    procedure Run;
  end;

{ TQueueMonitor }

constructor TQueueMonitor.Create(const AConfig: TAMIClientConfig);
begin
  inherited Create;
  FClient := TAMIClient.Create(AConfig);
  FClient.OnLog := @OnLog;
  FQueueStats := TStringList.Create;
end;

destructor TQueueMonitor.Destroy;
begin
  FreeAndNil(FQueueStats);
  FreeAndNil(FClient);
  inherited Destroy;
end;

procedure TQueueMonitor.OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
begin
  if Level >= llInfo then
    WriteLn(Format('[%s] %s', [GetEnumName(TypeInfo(TAMILogLevel), Ord(Level)), Msg]));
end;

procedure TQueueMonitor.OnQueueParams(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('=== Queue Parameters ===');
  WriteLn('Queue: ', Event.GetField('Queue'));
  WriteLn('Max: ', Event.GetField('Max'));
  WriteLn('Strategy: ', Event.GetField('Strategy'));
  WriteLn('Calls: ', Event.GetField('Calls'));
  WriteLn('Holdtime: ', Event.GetField('Holdtime'));
  WriteLn('TalkTime: ', Event.GetField('TalkTime'));
  WriteLn('Completed: ', Event.GetField('Completed'));
  WriteLn('Abandoned: ', Event.GetField('Abandoned'));
  WriteLn('ServiceLevel: ', Event.GetField('ServiceLevel'));
  WriteLn('ServicelevelPerf: ', Event.GetField('ServicelevelPerf'));
  WriteLn('Weight: ', Event.GetField('Weight'));
  WriteLn;
end;

procedure TQueueMonitor.OnQueueMember(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('=== Queue Member ===');
  WriteLn('Queue: ', Event.GetField('Queue'));
  WriteLn('Name: ', Event.GetField('Name'));
  WriteLn('Location: ', Event.GetField('Location'));
  WriteLn('StateInterface: ', Event.GetField('StateInterface'));
  WriteLn('Membership: ', Event.GetField('Membership'));
  WriteLn('Penalty: ', Event.GetField('Penalty'));
  WriteLn('CallsTaken: ', Event.GetField('CallsTaken'));
  WriteLn('LastCall: ', Event.GetField('LastCall'));
  WriteLn('LastPause: ', Event.GetField('LastPause'));
  WriteLn('InCall: ', Event.GetField('InCall'));
  WriteLn('Status: ', Event.GetField('Status'));
  WriteLn('Paused: ', Event.GetField('Paused'));
  WriteLn('PausedReason: ', Event.GetField('PausedReason'));
  WriteLn('Wrapuptime: ', Event.GetField('Wrapuptime'));
  WriteLn;
end;

procedure TQueueMonitor.OnQueueEntry(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('=== Queue Entry (Waiting Call) ===');
  WriteLn('Queue: ', Event.GetField('Queue'));
  WriteLn('Position: ', Event.GetField('Position'));
  WriteLn('Channel: ', Event.GetField('Channel'));
  WriteLn('Uniqueid: ', Event.GetField('Uniqueid'));
  WriteLn('CallerIDNum: ', Event.GetField('CallerIDNum'));
  WriteLn('CallerIDName: ', Event.GetField('CallerIDName'));
  WriteLn('ConnectedLineNum: ', Event.GetField('ConnectedLineNum'));
  WriteLn('ConnectedLineName: ', Event.GetField('ConnectedLineName'));
  WriteLn('Wait: ', Event.GetField('Wait'), ' seconds');
  WriteLn;
end;

procedure TQueueMonitor.OnQueueCallerJoin(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('>>> Caller Joined Queue <<<');
  WriteLn('Queue: ', Event.GetField('Queue'));
  WriteLn('CallerID: ', Event.GetField('CallerIDNum'));
  WriteLn('Position: ', Event.GetField('Position'));
  WriteLn('Channel: ', Event.GetField('Channel'));
  WriteLn;
end;

procedure TQueueMonitor.OnQueueCallerLeave(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('<<< Caller Left Queue <<<');
  WriteLn('Queue: ', Event.GetField('Queue'));
  WriteLn('CallerID: ', Event.GetField('CallerIDNum'));
  WriteLn('Position: ', Event.GetField('Position'));
  WriteLn('Channel: ', Event.GetField('Channel'));
  WriteLn('Count: ', Event.GetField('Count'));
  WriteLn;
end;

procedure TQueueMonitor.OnQueueMemberStatus(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('*** Queue Member Status Change ***');
  WriteLn('Queue: ', Event.GetField('Queue'));
  WriteLn('Member: ', Event.GetField('MemberName'));
  WriteLn('Location: ', Event.GetField('Location'));
  WriteLn('Status: ', Event.GetField('Status'));
  WriteLn('Paused: ', Event.GetField('Paused'));
  WriteLn;
end;

procedure TQueueMonitor.DisplayQueueStats;
var
  Response: TAMIResponse;
begin
  WriteLn('======================================');
  WriteLn('Requesting queue status...');
  WriteLn('======================================');
  WriteLn;

  Response := FClient.QueueStatus;
  if Assigned(Response) then
  begin
    try
      if Response.IsSuccess then
        WriteLn('Queue status request sent successfully')
      else
        WriteLn('Failed to get queue status: ', Response.Message);
    finally
      Response.Free;
    end;
  end;
end;

procedure TQueueMonitor.Run;
var
  Command: String;
begin
  if not FClient.Connect then
  begin
    WriteLn('Failed to connect to Asterisk');
    Exit;
  end;

  WriteLn('Connected to Asterisk AMI');
  WriteLn;

  // Subscribe to queue events
  FClient.SubscribeToEvent('QueueParams', @OnQueueParams);
  FClient.SubscribeToEvent('QueueMember', @OnQueueMember);
  FClient.SubscribeToEvent('QueueEntry', @OnQueueEntry);
  FClient.SubscribeToEvent('QueueCallerJoin', @OnQueueCallerJoin);
  FClient.SubscribeToEvent('QueueCallerLeave', @OnQueueCallerLeave);
  FClient.SubscribeToEvent('QueueMemberStatus', @OnQueueMemberStatus);

  WriteLn('Queue monitor started');
  WriteLn;

  // Get initial queue status
  DisplayQueueStats;

  WriteLn;
  WriteLn('Commands:');
  WriteLn('  status  - Show queue status');
  WriteLn('  stats   - Show client statistics');
  WriteLn('  quit    - Exit');
  WriteLn;

  repeat
    // Process AMI messages
    FClient.ProcessPendingMessages;

    // Check for user input (non-blocking)
    if KeyPressed then
    begin
      Write('> ');
      ReadLn(Command);
      Command := LowerCase(Trim(Command));

      if Command = 'status' then
        DisplayQueueStats
      else if Command = 'stats' then
        WriteLn(FClient.GetStatistics)
      else if Command <> 'quit' then
        WriteLn('Unknown command');
    end
    else
      Sleep(100);

  until Command = 'quit';

  WriteLn;
  WriteLn('Disconnecting...');
  FClient.Disconnect;
end;

var
  Config: TAMIClientConfig;
  Monitor: TQueueMonitor;

begin
  // Configure client
  Config := Default(TAMIClientConfig);
  Config.Host := 'ASTERISK_HOST';
  Config.Port := 5038;
  Config.Username := 'AMI_USERNAME';
  Config.Password := 'AMI_PASSWORD';
  Config.UTF8Enabled := True;
  Config.AuthType := 'plain';
  Config.ConnectionTimeout := 10000;
  Config.ResponseTimeout := 30000;
  Config.PingInterval := 30;
  Config.EventMask := 'call,user';

  // Create and run monitor
  Monitor := TQueueMonitor.Create(Config);
  try
    Monitor.Run;
  finally
    Monitor.Free;
  end;
end.
