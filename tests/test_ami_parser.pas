unit test_ami_parser;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  ami_parser, ami_types, ami_enums;

type
  { TTestAMIParser }

  TTestAMIParser = class(TTestCase)
  private
    function CreateValidMessage: RawByteString;
    function CreateEventMessage: RawByteString;
    function CreateResponseMessage: RawByteString;
  published
    procedure TestParseValidMessage;
    procedure TestParseEventMessage;
    procedure TestParseResponseMessage;
    procedure TestParseEmptyMessage;
    procedure TestParseMalformedMessage;
    procedure TestAMIBufferAppend;
    procedure TestAMIBufferHasCompleteMessage;
  end;

implementation

{ TTestAMIParser }

function TTestAMIParser.CreateValidMessage: RawByteString;
begin
  Result := 'Action: Login' + #13#10 +
            'Username: admin' + #13#10 +
            'Secret: secret' + #13#10 +
            #13#10;
end;

function TTestAMIParser.CreateEventMessage: RawByteString;
begin
  Result := 'Event: NewChannel' + #13#10 +
            'Channel: SIP/phone-00000001' + #13#10 +
            'State: Ring' + #13#10 +
            'CallerIDNum: 100' + #13#10 +
            #13#10;
end;

function TTestAMIParser.CreateResponseMessage: RawByteString;
begin
  Result := 'Response: Success' + #13#10 +
            'Message: Authentication accepted' + #13#10 +
            #13#10;
end;

procedure TTestAMIParser.TestParseValidMessage;
var
  Parser: TAMIReader;
  Buffer: TAMIBuffer;
  Msg: TAMIMessage;
begin
  Buffer := TAMIBuffer.Create(4096);
  try
    Buffer.Append(PChar(CreateValidMessage), Length(CreateValidMessage));

    Parser := TAMIReader.Create(Buffer);
    try
      Msg := Parser.ReadMessage;
      AssertNotNull('Message should not be nil', Msg);
      AssertEquals('Action field should be Login', 'Login', Msg.GetField('Action'));
      AssertEquals('Username field should be admin', 'admin', Msg.GetField('Username'));
      AssertEquals('Secret field should be secret', 'secret', Msg.GetField('Secret'));
    finally
      Parser.Free;
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TTestAMIParser.TestParseEventMessage;
var
  Parser: TAMIReader;
  Buffer: TAMIBuffer;
  Msg: TAMIMessage;
begin
  Buffer := TAMIBuffer.Create(4096);
  try
    Buffer.Append(PChar(CreateEventMessage), Length(CreateEventMessage));

    Parser := TAMIReader.Create(Buffer);
    try
      Msg := Parser.ReadMessage;
      AssertNotNull('Event message should not be nil', Msg);
      AssertTrue('Message should be an event', Msg is TAMIEvent);
      if Msg is TAMIEvent then
      begin
        AssertEquals('Event name should be NewChannel', 'NewChannel', TAMIEvent(Msg).GetEventName);
      end;
    finally
      Parser.Free;
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TTestAMIParser.TestParseResponseMessage;
var
  Parser: TAMIReader;
  Buffer: TAMIBuffer;
  Msg: TAMIMessage;
begin
  Buffer := TAMIBuffer.Create(4096);
  try
    Buffer.Append(PChar(CreateResponseMessage), Length(CreateResponseMessage));

    Parser := TAMIReader.Create(Buffer);
    try
      Msg := Parser.ReadMessage;
      AssertNotNull('Response message should not be nil', Msg);
      AssertTrue('Message should be a response', Msg is TAMIResponse);
      if Msg is TAMIResponse then
      begin
        AssertEquals('Response should be Success', 'Success', TAMIResponse(Msg).Response);
      end;
    finally
      Parser.Free;
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TTestAMIParser.TestParseEmptyMessage;
var
  Parser: TAMIReader;
  Buffer: TAMIBuffer;
  Msg: TAMIMessage;
begin
  Buffer := TAMIBuffer.Create(4096);
  try
    Parser := TAMIReader.Create(Buffer);
    try
      Msg := Parser.ReadMessage;
      AssertNull('Empty buffer should return nil message', Msg);
    finally
      Parser.Free;
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TTestAMIParser.TestParseMalformedMessage;
var
  Parser: TAMIReader;
  Buffer: TAMIBuffer;
  Msg: TAMIMessage;
begin
  Buffer := TAMIBuffer.Create(4096);
  try
    Buffer.Append(PChar('Invalid message without terminator'), Length('Invalid message without terminator'));

    Parser := TAMIReader.Create(Buffer);
    try
      Msg := Parser.ReadMessage;
      AssertNull('Malformed message should return nil', Msg);
    finally
      Parser.Free;
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TTestAMIParser.TestAMIBufferAppend;
var
  Buffer: TAMIBuffer;
  Data: RawByteString;
begin
  Buffer := TAMIBuffer.Create(4096);
  try
    Data := 'Test data';
    Buffer.Append(PChar(Data), Length(Data));
    AssertEquals('Buffer should have correct size', Length(Data), Buffer.Size);
  finally
    Buffer.Free;
  end;
end;

procedure TTestAMIParser.TestAMIBufferHasCompleteMessage;
var
  Buffer: TAMIBuffer;
  IncompleteMsg: RawByteString;
  CompleteMsg: RawByteString;
begin
  Buffer := TAMIBuffer.Create(4096);

  IncompleteMsg := 'Action: Ping' + #13#10;
  Buffer.Append(PChar(IncompleteMsg), Length(IncompleteMsg));
  AssertFalse('Incomplete message should not be detected as complete', Buffer.HasCompleteMessage);

  CompleteMsg := #13#10;
  Buffer.Append(PChar(CompleteMsg), Length(CompleteMsg));
  AssertTrue('Complete message should be detected', Buffer.HasCompleteMessage);

  Buffer.Free;
end;

initialization
  RegisterTest(TTestAMIParser);
end.
