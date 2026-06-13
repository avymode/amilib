unit test_ami_types;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  ami_types, ami_enums, ami_exceptions;

type
  { TTestAMITypes }

  TTestAMITypes = class(TTestCase)
  published
    procedure TestTAMIMessageCreate;
    procedure TestTAMIMessageAddField;
    procedure TestTAMIMessageGetField;
    procedure TestTAMIMessageHasField;
    procedure TestTAMIMessageFieldCount;
    procedure TestTAMIMessageToString;
    procedure TestTAMIActionCreate;
    procedure TestTAMIResponseCreate;
    procedure TestTAMIResponseIsSuccess;
    procedure TestTAMIEventCreate;
    procedure TestTAMIEventGetEventName;
    procedure TestEAMIExceptionCreate;
    procedure TestEAMIValidationException;
    procedure TestTOriginateParamsDefault;
  end;

implementation

{ TTestAMITypes }

procedure TTestAMITypes.TestTAMIMessageCreate;
var
  Msg: TAMIMessage;
begin
  Msg := TAMIMessage.Create;
  try
    AssertNotNull('Message should be created', Msg);
    AssertEquals('Field count should be 0', 0, Msg.FieldCount);
    AssertEquals('Message type should be Action', Ord(mtAction), Ord(Msg.MessageType));
  finally
    Msg.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIMessageAddField;
var
  Msg: TAMIMessage;
begin
  Msg := TAMIMessage.Create;
  try
    Msg.AddField('TestKey', 'TestValue');
    AssertEquals('Field count should be 1', 1, Msg.FieldCount);
    AssertEquals('Field value should match', 'TestValue', Msg.GetField('TestKey'));
  finally
    Msg.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIMessageGetField;
var
  Msg: TAMIMessage;
begin
  Msg := TAMIMessage.Create;
  try
    Msg.AddField('Key1', 'Value1');
    Msg.AddField('Key2', 'Value2');

    AssertEquals('Key1 should return Value1', 'Value1', Msg.GetField('Key1'));
    AssertEquals('Key2 should return Value2', 'Value2', Msg.GetField('Key2'));
    AssertEquals('Non-existent key should return empty', '', Msg.GetField('NonExistent'));
  finally
    Msg.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIMessageHasField;
var
  Msg: TAMIMessage;
begin
  Msg := TAMIMessage.Create;
  try
    Msg.AddField('ExistingKey', 'Value');
    AssertTrue('HasField should return True for existing key', Msg.HasField('ExistingKey'));
    AssertFalse('HasField should return False for non-existing key', Msg.HasField('NonExisting'));
  finally
    Msg.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIMessageFieldCount;
var
  Msg: TAMIMessage;
begin
  Msg := TAMIMessage.Create;
  try
    AssertEquals('Initial field count should be 0', 0, Msg.FieldCount);

    Msg.AddField('Key1', 'Value1');
    AssertEquals('Field count should be 1', 1, Msg.FieldCount);

    Msg.AddField('Key2', 'Value2');
    AssertEquals('Field count should be 2', 2, Msg.FieldCount);
  finally
    Msg.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIMessageToString;
var
  Msg: TAMIMessage;
  Str: string;
begin
  Msg := TAMIMessage.Create;
  try
    Msg.AddField('Key', 'Value');
    Str := Msg.ToString;
    AssertTrue('ToString should contain FieldCount', Pos('Fields:', Str) > 0);
  finally
    Msg.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIActionCreate;
var
  Action: TAMIAction;
begin
  Action := TAMIAction.Create('Ping');
  try
    AssertNotNull('Action should be created', Action);
    AssertEquals('Action name should be Ping', 'Ping', Action.ActionName);
    AssertEquals('Action field should be Ping', 'Ping', Action.GetField('Action'));
  finally
    Action.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIResponseCreate;
var
  Response: TAMIResponse;
begin
  Response := TAMIResponse.Create;
  try
    AssertNotNull('Response should be created', Response);
    AssertFalse('Default success should be False', Response.Success);
    AssertEquals('Default message should be empty', '', Response.Message);
  finally
    Response.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIResponseIsSuccess;
var
  Response: TAMIResponse;
begin
  Response := TAMIResponse.Create;
  try
    AssertFalse('Empty response should not be success', Response.IsSuccess);

    Response.AddField('Response', 'Success');
    AssertTrue('Response: Success should be success', Response.IsSuccess);

    Response.AddField('Response', 'Follows');
    AssertTrue('Response: Follows should be success', Response.IsSuccess);

    Response.AddField('Response', 'Pong');
    AssertTrue('Response: Pong should be success', Response.IsSuccess);

    Response.AddField('Response', 'Error');
    AssertFalse('Response: Error should not be success', Response.IsSuccess);
  finally
    Response.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIEventCreate;
var
  Event: TAMIEvent;
begin
  Event := TAMIEvent.Create;
  try
    AssertNotNull('Event should be created', Event);
    AssertEquals('Default event type should be Unknown', Ord(etUnknown), Ord(Event.EventType));
    AssertEquals('Default event name should be empty', '', Event.EventName);
  finally
    Event.Free;
  end;
end;

procedure TTestAMITypes.TestTAMIEventGetEventName;
var
  Event: TAMIEvent;
begin
  Event := TAMIEvent.Create;
  try
    Event.AddField('Event', 'NewChannel');
    AssertEquals('Event name should be NewChannel', 'NewChannel', Event.GetEventName);
  finally
    Event.Free;
  end;
end;

procedure TTestAMITypes.TestEAMIExceptionCreate;
var
  Ex: EAMIException;
begin
  Ex := EAMIException.Create('Test message');
  AssertEquals('Message should match', 'Test message', Ex.Message);
  AssertEquals('Error code should be 0', 0, Ex.ErrorCode);
  FreeAndNil(Ex);

  Ex := EAMIException.Create('Test message with error', 500);
  AssertEquals('Message should include error code', 'Test message with error (Error: 500)', Ex.Message);
  AssertEquals('Error code should be 500', 500, Ex.ErrorCode);
  FreeAndNil(Ex);
end;

procedure TTestAMITypes.TestEAMIValidationException;
var
  Ex: EAMIValidationException;
  Config: TAMIClientConfig;
  Errors: string;
begin
  Config := Default(TAMIClientConfig);
  Config.Host := '';
  Config.Port := 0;
  Config.Username := '';

  Ex := EAMIValidationException.Create('Validation failed');
  AssertEquals('Message should match', 'Validation failed', Ex.Message);
  FreeAndNil(Ex);
end;

procedure TTestAMITypes.TestTOriginateParamsDefault;
var
  Params: TOriginateParams;
begin
  Params := Default(TOriginateParams);
  AssertEquals('Default channel should be empty', '', Params.Channel);
  AssertEquals('Default context should be empty', '', Params.Context);
  AssertEquals('Default extension should be empty', '', Params.Extension);
  AssertEquals('Default timeout should be 0', 0, Params.Timeout);
  AssertEquals('Default async should be False', False, Params.Async);
  AssertEquals('Default early media should be False', False, Params.EarlyMedia);
end;

initialization
  RegisterTest(TTestAMITypes);
end.
