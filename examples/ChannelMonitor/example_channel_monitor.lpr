program example_channel_monitor;

{$mode objfpc}{$H+}

uses
  Crt, SysUtils, Classes, ami_client, ami_types, ami_events, ami_parser, ami_enums,
  Generics.Collections, TypInfo, ami_log;

type
  TChannelMonitor = class
  private
    FChannels: specialize TDictionary<string, TChannelInfo>;
    FClient: TAMIClient;

    procedure OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
    procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
    procedure OnNewState(Sender: TObject; const Event: TAMIEvent);
    procedure OnNewCallerID(Sender: TObject; const Event: TAMIEvent);
    procedure OnDialBegin(Sender: TObject; const Event: TAMIEvent);
    procedure OnDialEnd(Sender: TObject; const Event: TAMIEvent);
    procedure OnBridgeEnter(Sender: TObject; const Event: TAMIEvent);
    procedure OnBridgeLeave(Sender: TObject; const Event: TAMIEvent);

    procedure UpdateChannelInfo(const Event: TAMIEvent);
    procedure DisplayChannelInfo(const ChannelName: String);
    procedure DisplayAllChannels;
  public
    constructor Create(AClient: TAMIClient);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
    procedure RefreshChannels;
    procedure ProcessCommands;
  end;

{ TChannelMonitor }

constructor TChannelMonitor.Create(AClient: TAMIClient);
begin
  inherited Create;
  FClient := AClient;
  FClient.OnLog := @OnLog;
  FChannels := specialize TDictionary<string, TChannelInfo>.Create;
end;

destructor TChannelMonitor.Destroy;
begin
  FreeAndNil(FChannels);
  inherited Destroy;
end;

procedure TChannelMonitor.OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
begin
  if Level >= llInfo then
    WriteLn(Format('[%s] %s', [GetEnumName(TypeInfo(TAMILogLevel), Ord(Level)), Msg]));
end;

procedure TChannelMonitor.Start;
begin
  // Subscribe to channel events
  FClient.SubscribeToEvent('Newchannel', @OnNewChannel);
  FClient.SubscribeToEvent('Hangup', @OnHangup);
  FClient.SubscribeToEvent('Newstate', @OnNewState);
  FClient.SubscribeToEvent('NewCallerid', @OnNewCallerID);
  FClient.SubscribeToEvent('DialBegin', @OnDialBegin);
  FClient.SubscribeToEvent('DialEnd', @OnDialEnd);
  FClient.SubscribeToEvent('BridgeEnter', @OnBridgeEnter);
  FClient.SubscribeToEvent('BridgeLeave', @OnBridgeLeave);

  WriteLn('Channel monitor started');
  RefreshChannels;
end;

procedure TChannelMonitor.Stop;
begin
  FClient.UnsubscribeFromEvent('Newchannel');
  FClient.UnsubscribeFromEvent('Hangup');
  FClient.UnsubscribeFromEvent('Newstate');
  FClient.UnsubscribeFromEvent('NewCallerid');
  FClient.UnsubscribeFromEvent('DialBegin');
  FClient.UnsubscribeFromEvent('DialEnd');
  FClient.UnsubscribeFromEvent('BridgeEnter');
  FClient.UnsubscribeFromEvent('BridgeLeave');

  WriteLn('Channel monitor stopped');
end;

procedure TChannelMonitor.RefreshChannels;
var
  Response: TAMIResponse;
begin
  FChannels.Clear;
  Response := FClient.ChannelList;
  if Assigned(Response) then
  begin
    try
      WriteLn('Channel list refreshed');
    finally
      Response.Free;
    end;
  end;
end;

procedure TChannelMonitor.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  Info: TChannelInfo;
begin
  Info := TAMIEventParser.ParseChannelInfo(Event);
  FChannels.AddOrSetValue(Info.Channel, Info);

  WriteLn('=== NEW CHANNEL ===');
  DisplayChannelInfo(Info.Channel);
end;

procedure TChannelMonitor.OnHangup(Sender: TObject; const Event: TAMIEvent);
var
  Channel: String;
  HangupInfo: THangupInfo;
begin
  Channel := Event.GetField('Channel');
  HangupInfo := TAMIEventParser.ParseHangupInfo(Event);

  WriteLn('=== HANGUP ===');
  WriteLn('Channel: ', Channel);
  WriteLn('Cause: ', HangupInfo.Cause, ' (', HangupInfo.CauseTxt, ')');
  WriteLn('Duration: ', HangupInfo.Duration, ' seconds');

  FChannels.Remove(Channel);
  WriteLn('Active channels: ', FChannels.Count);
end;

procedure TChannelMonitor.OnNewState(Sender: TObject; const Event: TAMIEvent);
var
  Channel: String;
begin
  Channel := Event.GetField('Channel');
  UpdateChannelInfo(Event);

  WriteLn('=== STATE CHANGE ===');
  WriteLn('Channel: ', Channel);
  WriteLn('New State: ', Event.GetField('ChannelStateDesc'));
end;

procedure TChannelMonitor.OnNewCallerID(Sender: TObject; const Event: TAMIEvent);
var
  Channel: String;
begin
  Channel := Event.GetField('Channel');
  UpdateChannelInfo(Event);

  WriteLn('=== CALLER ID CHANGE ===');
  WriteLn('Channel: ', Channel);
  WriteLn('CallerID: ', Event.GetField('CallerIDNum'), ' <', Event.GetField('CallerIDName'), '>');
end;

procedure TChannelMonitor.OnDialBegin(Sender: TObject; const Event: TAMIEvent);
var
  DialInfo: TDialInfo;
begin
  DialInfo := TAMIEventParser.ParseDialInfo(Event);

  WriteLn('=== DIAL BEGIN ===');
  WriteLn('From: ', DialInfo.Channel);
  WriteLn('To: ', DialInfo.Destination);
  WriteLn('CallerID: ', DialInfo.CallerIDNum);
end;

procedure TChannelMonitor.OnDialEnd(Sender: TObject; const Event: TAMIEvent);
var
  DialInfo: TDialInfo;
begin
  DialInfo := TAMIEventParser.ParseDialInfo(Event);

  WriteLn('=== DIAL END ===');
  WriteLn('Channel: ', DialInfo.Channel);
  WriteLn('Destination: ', DialInfo.Destination);
  WriteLn('Status: ', DialInfo.DialStatus);
end;

procedure TChannelMonitor.OnBridgeEnter(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('=== BRIDGE ENTER ===');
  WriteLn('Channel: ', Event.GetField('Channel'));
  WriteLn('Bridge: ', Event.GetField('BridgeUniqueid'));
end;

procedure TChannelMonitor.OnBridgeLeave(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('=== BRIDGE LEAVE ===');
  WriteLn('Channel: ', Event.GetField('Channel'));
  WriteLn('Bridge: ', Event.GetField('BridgeUniqueid'));
end;

procedure TChannelMonitor.UpdateChannelInfo(const Event: TAMIEvent);
var
  Info: TChannelInfo;
  Channel: String;
begin
  Channel := Event.GetField('Channel');
  if FChannels.TryGetValue(Channel, Info) then
  begin
    Info := TAMIEventParser.ParseChannelInfo(Event);
    FChannels.AddOrSetValue(Channel, Info);
  end;
end;

procedure TChannelMonitor.DisplayChannelInfo(const ChannelName: String);
var
  Info: TChannelInfo;
begin
  if FChannels.TryGetValue(ChannelName, Info) then
  begin
    WriteLn('Channel: ', Info.Channel);
    WriteLn('  UniqueID: ', Info.UniqueID);
    WriteLn('  CallerID: ', Info.CallerIDNum, ' <', Info.CallerIDName, '>');
    WriteLn('  State: ', Info.StateDesc);
    WriteLn('  Context: ', Info.Context);
    WriteLn('  Extension: ', Info.Extension);
    WriteLn('  Priority: ', Info.Priority);
  end;
end;

procedure TChannelMonitor.DisplayAllChannels;
var
  Info: TChannelInfo;
begin
  WriteLn('=== ACTIVE CHANNELS (', FChannels.Count, ') ===');
  for Info in FChannels.Values do
  begin
    WriteLn('Channel: ', Info.Channel);
    WriteLn('  CallerID: ', Info.CallerIDNum);
    WriteLn('  State: ', Info.StateDesc);
    WriteLn;
  end;
end;

procedure TChannelMonitor.ProcessCommands;
var
  Command: String;
begin
  WriteLn('Commands:');
  WriteLn('  list   - Show all active channels');
  WriteLn('  stats  - Show statistics');
  WriteLn('  refresh - Refresh channel list');
  WriteLn('  quit   - Exit');
  WriteLn;

  repeat
    // Process pending AMI messages
    FClient.ProcessPendingMessages;

    // Check for user input (non-blocking)
    if KeyPressed then
    begin
      Write('> ');
      ReadLn(Command);
      Command := LowerCase(Trim(Command));

      if Command = 'list' then
        DisplayAllChannels
      else if Command = 'stats' then
        WriteLn(FClient.GetStatistics)
      else if Command = 'refresh' then
        RefreshChannels
      else if Command <> 'quit' then
        WriteLn('Unknown command');
    end
    else
      Sleep(100); // Small delay to reduce CPU usage

  until Command = 'quit';
end;

var
  Client: TAMIClient;
  Config: TAMIClientConfig;
  Monitor: TChannelMonitor;

begin
  Config := Default(TAMIClientConfig);
  Config.Host := 'ASTERISK_HOST';
  Config.Port := 5038;
  Config.Username := 'AMI_USERNAME';
  Config.Password := 'AMI_PASSWORD';
  Config.AuthType := 'plain';
  Config.ConnectionTimeout := 10000;
  Config.ResponseTimeout := 30000;
  Config.PingInterval := 30;

  Client := TAMIClient.Create(Config);
  try
    if Client.Connect then
    begin
      WriteLn('Connected to Asterisk!');
      WriteLn;

      Monitor := TChannelMonitor.Create(Client);
      try
        Monitor.Start;
        Monitor.ProcessCommands;
        Monitor.Stop;
      finally
        Monitor.Free;
      end;

      Client.Disconnect;
    end
    else
      WriteLn('Failed to connect to Asterisk!');
  finally
    Client.Free;
  end;
end.
