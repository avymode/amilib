program example_basic;

{$mode objfpc}{$H+}

uses
  SysUtils, TypInfo, ami_client, ami_types, ami_actions, ami_enums,ami_log;

type
  TBasicExample = class
  private
    FClient: TAMIClient;
    procedure OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
  public
    constructor Create(const AConfig: TAMIClientConfig);
    destructor Destroy; override;
    procedure Run;
  end;

{ TBasicExample }

constructor TBasicExample.Create(const AConfig: TAMIClientConfig);
begin
  inherited Create;
  FClient := TAMIClient.Create(AConfig);
  FClient.OnLog := @OnLog;
end;

destructor TBasicExample.Destroy;
begin
  FreeAndNil(FClient);
  inherited Destroy;
end;

procedure TBasicExample.OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
begin
  WriteLn(Format('[%s] %s', [GetEnumName(TypeInfo(TAMILogLevel), Ord(Level)), Msg]));
end;
{
procedure TBasicExample.Run;
var
  Response: TAMIResponse;
  CmdResponse: TAMICommandResponse;
begin
  if FClient.Connect then
  begin
    WriteLn('Connected successfully!');

    // Send a ping
    Response := FClient.Ping;
    if Assigned(Response) then
    begin
      try
        WriteLn('Ping response: ', Response.Response);
      finally
        Response.Free;
      end;
    end;

    // Get core status
    Response := FClient.Command('core show version');
    if Assigned(Response) and (Response is TAMICommandResponse) then
    begin
      try
        CmdResponse := TAMICommandResponse(Response);
        WriteLn(CmdResponse.GetFullOutput);
      finally
        Response.Free;
      end;
    end;

    WriteLn('Press Enter to disconnect...');
    ReadLn;
    FClient.Disconnect;
  end
  else
    WriteLn('Failed to connect!');
end;
 }

procedure TBasicExample.Run;
var
  Response: TAMIResponse;
  CmdResponse: TAMICommandResponse;
begin
  if FClient.Connect then
  begin
    // FIXED: Use logging instead of WriteLn
    OnLog(Self, llInfo, 'Connected successfully!');

    // Send a ping
    OnLog(Self, llInfo, 'Sending Ping...');
    Response := FClient.Ping;
    if Assigned(Response) then
    begin
      try
        OnLog(Self, llInfo, 'Ping response: ' + Response.Response);
      finally
        Response.Free;
      end;
    end;

    // Get core status
    OnLog(Self, llInfo, 'Executing: core show version');
    Response := FClient.Command('core show version');
    if Assigned(Response) and (Response is TAMICommandResponse) then
    begin
      try
        CmdResponse := TAMICommandResponse(Response);
        OnLog(Self, llInfo, 'Command output:');
        OnLog(Self, llInfo, CmdResponse.GetFullOutput);
      finally
        Response.Free;
      end;
    end;

    OnLog(Self, llInfo, 'Press Enter to disconnect...');
    ReadLn;
    FClient.Disconnect;
  end
  else
    OnLog(Self, llError, 'Failed to connect!');
end;


var
  Config: TAMIClientConfig;
  Example: TBasicExample;

begin
  // Configure client
  Config := Default(TAMIClientConfig);
  Config.Host := 'ASTERISK_HOST';
  Config.Port := 5038;
  Config.Username := 'AMI_USERNAME';
  Config.Password := 'AMI_PASSWORD';
  Config.AuthType := 'plain';
  //Config.AuthType := 'md5';
  Config.ConnectionTimeout := 10000;
  Config.ResponseTimeout := 30000;
  Config.PingInterval := 30;
  Config.MaxReconnectAttempts := 5;

  // Create and run
  Example := TBasicExample.Create(Config);
  try
    Example.Run;
  finally
    Example.Free;
  end;
end.
