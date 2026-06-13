program ami_test_suite;

{$mode objfpc}{$H+}

{$IFDEF UNIX}
{$DEFINE USE_THREADING}
{$ENDIF}

uses
  {$IFDEF USE_THREADING}
  cthreads,
  {$ENDIF}
  SysUtils,
  Classes,
  ami_parser,
  ami_cache,
  ami_types,
  ami_enums,
  ami_exceptions,
  ami_mock_server,
  synsock,
  blcksock;

var
  Failures: Integer = 0;
  Passed: Integer = 0;

procedure Check(Condition: Boolean; TestName: string);
begin
  if Condition then
  begin
    WriteLn('  [PASS] ', TestName);
    Inc(Passed);
  end
  else
  begin
    WriteLn('  [FAIL] ', TestName);
    Inc(Failures);
  end;
end;

procedure TestParser;
var
  Buffer: TAMIBuffer;
  Parser: TAMIReader;
  Msg: TAMIMessage;
  Data: string;
begin
  WriteLn('Running parser tests...');
  Buffer := TAMIBuffer.Create(4096);
  Parser := TAMIReader.Create(Buffer, Default(TAMIClientConfig));
  try
    Data := 'Action: Ping'#13#10#13#10;
    Buffer.Append(PChar(Data), Length(Data));
    Msg := Parser.ReadMessage;
    Check(Assigned(Msg), 'TestParseMessage');
    if Assigned(Msg) then
      Msg.Free;
  finally
    Parser.Free;
    Buffer.Free;
  end;
end;

procedure TestCache;
var
  EventCache: TAMIEventCache;
  EventType: TAMIEventType;
begin
  WriteLn('Running cache tests...');
  EventCache := TAMIEventCache.Create(10);
  try
    EventCache.PutEventType('TestEvent', etNewchannel);
    EventType := EventCache.GetEventType('TestEvent');
    Check(EventType = etNewchannel, 'TestEventCachePutGet');
    Check(EventCache.GetSize = 1, 'TestEventCacheSize');
    EventCache.Clear;
    Check(EventCache.GetSize = 0, 'TestEventCacheClear');
  finally
    EventCache.Free;
  end;
end;

procedure TestTypes;
var
  Msg: TAMIMessage;
  Response: TAMIResponse;
begin
  WriteLn('Running type tests...');
  
  Msg := TAMIMessage.Create;
  try
    Msg.AddField('Key', 'Value');
    Check(Msg.GetField('Key') = 'Value', 'TestMessageAddField');
    Check(Msg.FieldCount = 1, 'TestMessageFieldCount');
  finally
    Msg.Free;
  end;

  Response := TAMIResponse.Create;
  try
    Response.AddField('Response', 'Success');
    Check(Response.IsSuccess = True, 'TestResponseIsSuccess');
    
    Response := TAMIResponse.Create;
    Response.AddField('Response', 'Error');
    Check(Response.IsSuccess = False, 'TestResponseIsError');
  finally
    Response.Free;
  end;
end;

procedure TestMockServerAuthentication;
var
  Server: TAMIMockServer;
  ClientSocket: TTCPBlockSocket;
  Received: string;
  Port: Word;
begin
  WriteLn('Running mock server authentication tests...');

  Port := 15038;
  Server := TAMIMockServer.Create(Port, 'testuser', 'testpass');
  try
    Server.Start;
    Check(Server.Running, 'TestMockServerStart');

    if Server.Running then
    begin
      Sleep(100);
      ClientSocket := TTCPBlockSocket.Create;
      try
        ClientSocket.Family := SF_IP4;
        ClientSocket.Connect('127.0.0.1', IntToStr(Port));
        Check(ClientSocket.LastError = 0, 'TestMockServerConnect');
      finally
        ClientSocket.Free;
      end;
    end;
  finally
    Server.Free;
  end;
end;

procedure TestMockServerPing;
var
  Server: TAMIMockServer;
  ClientSocket: TTCPBlockSocket;
  Received: string;
  Port: Word;
begin
  WriteLn('Running mock server Ping tests...');

  Port := 15039;
  Server := TAMIMockServer.Create(Port, 'admin', 'secret');
  try
    Server.Start;
    Check(Server.Running, 'TestMockServerPingStart');

    if Server.Running then
    begin
      ClientSocket := TTCPBlockSocket.Create;
      try
        ClientSocket.Family := SF_IP4;
        ClientSocket.SetTimeout(5000);
        ClientSocket.Connect('127.0.0.1', IntToStr(Port));
        Check(ClientSocket.LastError = 0, 'TestMockServerPingConnect');

        if ClientSocket.LastError = 0 then
        begin
          ClientSocket.SendString('Action: Login' + #13#10);
          ClientSocket.SendString('Username: admin' + #13#10);
          ClientSocket.SendString('Secret: secret' + #13#10#13#10);

          Server.ProcessOneClient;
          Sleep(100);

          Received := ClientSocket.RecvString(5000);
          Check(Pos('Response: Success', Received) > 0, 'TestMockServerLoginSuccess');
        end;
        ClientSocket.CloseSocket;
      finally
        ClientSocket.Free;
      end;
    end;
  finally
    Server.Free;
  end;
end;

procedure TestMockServerMultipleActions;
var
  Server: TAMIMockServer;
  ClientSocket: TTCPBlockSocket;
  Received: string;
  Port: Word;
begin
  WriteLn('Running mock server multiple actions tests...');

  Port := 15040;
  Server := TAMIMockServer.Create(Port, 'admin', 'secret');
  try
    Server.Start;
    Check(Server.Running, 'TestMockServerMultipleStart');

    if Server.Running then
    begin
      ClientSocket := TTCPBlockSocket.Create;
      try
        ClientSocket.Family := SF_IP4;
        ClientSocket.SetTimeout(5000);
        ClientSocket.Connect('127.0.0.1', IntToStr(Port));

        if ClientSocket.LastError = 0 then
        begin
          ClientSocket.SendString('Action: Login' + #13#10);
          ClientSocket.SendString('Username: admin' + #13#10);
          ClientSocket.SendString('Secret: secret' + #13#10#13#10);

          Server.ProcessOneClient;
          Sleep(100);

          Received := ClientSocket.RecvString(5000);
          Check(Pos('Response: Success', Received) > 0, 'TestMockServerMultipleLogin');
        end;
        ClientSocket.CloseSocket;
      finally
        ClientSocket.Free;
      end;
    end;
  finally
    Server.Free;
  end;
end;

begin
  WriteLn('═══════════════════════════════════════════════════════════════');
  WriteLn('              AMILIB Unit Tests                               ');
  WriteLn('═══════════════════════════════════════════════════════════════');
  WriteLn('');

  try
    TestParser;
    TestCache;
    TestTypes;
    WriteLn('');
    WriteLn('--- Mock Server Tests ---');
    TestMockServerAuthentication;
    TestMockServerPing;
    TestMockServerMultipleActions;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Inc(Failures);
    end;
  end;

  WriteLn('');
  WriteLn('═══════════════════════════════════════════════════════════════');
  WriteLn('Results: ', Passed, ' passed, ', Failures, ' failed');
  WriteLn('═══════════════════════════════════════════════════════════════');

  if Failures > 0 then
    Halt(1);
end.
