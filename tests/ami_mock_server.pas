unit ami_mock_server;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, syncobjs, blcksock, synsock, ami_types, ami_parser,
  ami_enums, ami_log, sockets;

type
  TAMIMockClient = class
  private
    FSocket: TTCPBlockSocket;
    FConnected: Boolean;
    FUsername: string;
    FPassword: string;
    FServerUsername: string;
    FServerPassword: string;
    FAuthenticated: Boolean;
    FEventMask: string;
    FLastActionID: string;
    procedure SendResponse(const AResponse: string);
    function ProcessAction(const AAction: TAMIAction): string;
    function AuthenticateUser(const AUsername, APassword: string): Boolean;
  public
    constructor Create(ASocket: TTCPBlockSocket; const AServerUsername, AServerPassword: string);
    destructor Destroy; override;
    function HandleClient: Boolean;
    property Authenticated: Boolean read FAuthenticated;
  end;

  TAMIMockServer = class
  private
    FSocket: TTCPBlockSocket;
    FPort: Word;
    FRunning: Boolean;
    FUsername: string;
    FPassword: string;
    FThread: TThread;
    procedure DoAccept;
  public
    constructor Create(APort: Word; const AUsername, APassword: string);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure ProcessOneClient;
    property Port: Word read FPort;
    property Running: Boolean read FRunning;
  end;

implementation

{ TAMIMockClient }

constructor TAMIMockClient.Create(ASocket: TTCPBlockSocket; const AServerUsername, AServerPassword: string);
begin
  inherited Create;
  FSocket := ASocket;
  FConnected := True;
  FAuthenticated := False;
  FEventMask := 'on';
  FServerUsername := AServerUsername;
  FServerPassword := AServerPassword;
  FUsername := '';
  FPassword := '';
end;

destructor TAMIMockClient.Destroy;
begin
  inherited Destroy;
end;

procedure TAMIMockClient.SendResponse(const AResponse: string);
var
  ResponseStr: string;
begin
  if FConnected and Assigned(FSocket) then
  begin
    ResponseStr := AResponse + #13#10#13#10;
    FSocket.SetTimeout(3000);
    FSocket.SendString(ResponseStr);
  end;
end;

function TAMIMockClient.AuthenticateUser(const AUsername, APassword: string): Boolean;
begin
  Result := (AUsername = FServerUsername) and (APassword = FServerPassword);
end;

function TAMIMockClient.ProcessAction(const AAction: TAMIAction): string;
var
  ActionName: string;
begin
  Result := '';
  ActionName := UpperCase(AAction.GetField('Action'));

  if ActionName = 'LOGIN' then
  begin
    FUsername := AAction.GetField('Username');
    FPassword := AAction.GetField('Secret');
    FLastActionID := AAction.GetField('ActionID');

    if AuthenticateUser(FUsername, FPassword) then
    begin
      FAuthenticated := True;
      Result := 'Response: Success' + #13#10 +
                'Message: Authentication accepted' + #13#10 +
                'ActionID: ' + FLastActionID + #13#10;
    end
    else
    begin
      Result := 'Response: Error' + #13#10 +
                'Message: Authentication failed' + #13#10 +
                'ActionID: ' + FLastActionID + #13#10;
    end;
  end
  else if ActionName = 'PING' then
  begin
    FLastActionID := AAction.GetField('ActionID');
    Result := 'Response: Pong' + #13#10 +
              'ActionID: ' + FLastActionID + #13#10;
  end
  else if ActionName = 'COMMAND' then
  begin
    FLastActionID := AAction.GetField('ActionID');
    Result := 'Response: Follows' + #13#10 +
              'ActionID: ' + FLastActionID + #13#10 +
              #13#10 +
              'Output: Mock command output' + #13#10 +
              '--END COMMAND--' + #13#10;
  end
  else if ActionName = 'LOGOFF' then
  begin
    FAuthenticated := False;
    FLastActionID := AAction.GetField('ActionID');
    Result := 'Response: Goodbye' + #13#10 +
              'Message: Logged off' + #13#10 +
              'ActionID: ' + FLastActionID + #13#10;
    FConnected := False;
  end
  else if ActionName = 'EVENTS' then
  begin
    FEventMask := AAction.GetField('EventMask');
    FLastActionID := AAction.GetField('ActionID');
    Result := 'Response: Success' + #13#10 +
              'Message: Events enabled' + #13#10 +
              'ActionID: ' + FLastActionID + #13#10;
  end
  else if not FAuthenticated then
  begin
    Result := 'Response: Error' + #13#10 +
              'Message: Authentication required' + #13#10;
  end
  else
  begin
    FLastActionID := AAction.GetField('ActionID');
    Result := 'Response: Success' + #13#10 +
              'Message: Action completed' + #13#10 +
              'ActionID: ' + FLastActionID + #13#10;
  end;
end;

function TAMIMockClient.HandleClient: Boolean;
var
  Buffer: TAMIBuffer;
  Reader: TAMIReader;
  Msg: TAMIMessage;
  BytesRead: Integer;
  Buf: array[0..4095] of Byte;
begin
  Result := True;
  FSocket.SetTimeout(5000);
  Buffer := TAMIBuffer.Create(8192);
  Reader := TAMIReader.Create(Buffer, Default(TAMIClientConfig));
  try
    if FSocket.CanRead(5000) then
    begin
      BytesRead := FSocket.RecvBuffer(@Buf[0], SizeOf(Buf));
      if BytesRead > 0 then
      begin
        Buffer.Append(@Buf[0], BytesRead);

        Msg := Reader.ReadMessage;
        if Assigned(Msg) then
        begin
          if Msg.HasField('Action') then
          begin
            if Msg is TAMIAction then
            begin
              TAMIAction(Msg).UpdateFromFields;
              SendResponse(ProcessAction(TAMIAction(Msg)));
            end
            else
            begin
              Msg.MessageType := mtAction;
              TAMIAction(Msg).UpdateFromFields;
              SendResponse(ProcessAction(TAMIAction(Msg)));
            end;
          end;
          Msg.Free;
        end;
      end;
    end;
  finally
    Reader.Free;
    Buffer.Free;
  end;
  FConnected := False;
end;

{ TAMIMockServer }

constructor TAMIMockServer.Create(APort: Word; const AUsername, APassword: string);
begin
  inherited Create;
  FPort := APort;
  FUsername := AUsername;
  FPassword := APassword;
  FRunning := False;
  FSocket := TTCPBlockSocket.Create;
  FThread := nil;
end;

destructor TAMIMockServer.Destroy;
begin
  Stop;
  FreeAndNil(FSocket);
  inherited Destroy;
end;

procedure TAMIMockServer.DoAccept;
var
  ClientSocket: TTCPBlockSocket;
  Client: TAMIMockClient;
  SocketHandle: TSocket;
begin
  SocketHandle := FSocket.Accept;
  if TSocket(SocketHandle) <> TSocket(INVALID_SOCKET) then
  begin
    ClientSocket := TTCPBlockSocket.Create;
    ClientSocket.Socket := SocketHandle;
    try
      Client := TAMIMockClient.Create(ClientSocket, FUsername, FPassword);
      try
        Client.HandleClient;
      finally
        Client.Free;
      end;
    finally
      ClientSocket.Free;
    end;
  end;
end;

procedure TAMIMockServer.Start;
begin
  if FRunning then
    Exit;

  FSocket.Family := SF_IP4;
  FSocket.SetLinger(True, 0);
  FSocket.Bind('0.0.0.0',IntToStr(FPort));
  FSocket.Listen;
  FRunning := FSocket.LastError = 0;
end;

procedure TAMIMockServer.Stop;
begin
  if not FRunning then
    Exit;

  FRunning := False;
  FSocket.CloseSocket;
end;

procedure TAMIMockServer.ProcessOneClient;
begin
  DoAccept;
end;

end.
