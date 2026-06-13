unit test_ami_eventbus;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  ami_eventbus_threaded, ami_types, ami_enums, ami_events;

type
  { TTestAMIEventBus }

  TTestAMIEventBus = class(TTestCase)
  private
    FEventBus: TThreadedEventBus;
    FEventsReceived: Integer;
    FTestEvent: TAMIEvent;
    procedure OnTestEvent(Sender: TObject; const Event: TAMIEvent);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEventBusCreate;
    procedure TestEventBusSubscribe;
    procedure TestEventBusUnsubscribe;
    procedure TestEventBusDispatch;
    procedure TestEventBusMultipleSubscribers;
    procedure TestEventBusClearSubscribersForOwner;
    procedure TestEventBusStats;
  end;

implementation

{ TTestAMIEventBus }

procedure TTestAMIEventBus.OnTestEvent(Sender: TObject; const Event: TAMIEvent);
begin
  Inc(FEventsReceived);
end;

procedure TTestAMIEventBus.SetUp;
begin
  inherited SetUp;
  FEventBus := TThreadedEventBus.Create(2, 100);
  FEventsReceived := 0;
  FTestEvent := TAMIEvent.Create;
  FTestEvent.AddField('Event', 'TestEvent');
end;

procedure TTestAMIEventBus.TearDown;
begin
  FreeAndNil(FTestEvent);
  FreeAndNil(FEventBus);
  inherited TearDown;
end;

procedure TTestAMIEventBus.TestEventBusCreate;
begin
  AssertNotNull('EventBus should be created', FEventBus);
end;

procedure TTestAMIEventBus.TestEventBusSubscribe;
var
  SubID: Integer;
begin
  SubID := FEventBus.Subscribe(@OnTestEvent, nil, False, 'TestEvent', nil, 0);
  AssertTrue('Subscription ID should be positive', SubID > 0);
end;

procedure TTestAMIEventBus.TestEventBusUnsubscribe;
var
  SubID: Integer;
begin
  SubID := FEventBus.Subscribe(@OnTestEvent, nil, False, 'TestEvent', nil, 0);
  AssertTrue('Subscription ID should be positive', SubID > 0);

  FEventBus.Unsubscribe(SubID);
  FEventBus.Unsubscribe(SubID);
end;

procedure TTestAMIEventBus.TestEventBusDispatch;
var
  SubID: Integer;
begin
  SubID := FEventBus.Subscribe(@OnTestEvent, nil, False, 'TestEvent', nil, 0);
  AssertTrue('Subscription ID should be positive', SubID > 0);

  FEventsReceived := 0;
  FTestEvent.AddField('Event', 'TestEvent');
  FEventBus.Dispatch(FTestEvent);

  Sleep(100);

  AssertEquals('One event should be received', 1, FEventsReceived);
end;

procedure TTestAMIEventBus.TestEventBusMultipleSubscribers;
var
  SubID1, SubID2: Integer;
begin
  SubID1 := FEventBus.Subscribe(@OnTestEvent, nil, False, 'TestEvent', nil, 0);
  SubID2 := FEventBus.Subscribe(@OnTestEvent, nil, False, 'TestEvent', nil, 0);

  FEventsReceived := 0;
  FTestEvent.AddField('Event', 'TestEvent');
  FEventBus.Dispatch(FTestEvent);

  Sleep(100);

  AssertEquals('Two events should be received', 2, FEventsReceived);
end;

procedure TTestAMIEventBus.TestEventBusClearSubscribersForOwner;
var
  OwnerObj: TObject;
  SubID: Integer;
begin
  OwnerObj := TObject.Create;
  try
    SubID := FEventBus.Subscribe(@OnTestEvent, OwnerObj, False, 'TestEvent', nil, 0);
    AssertTrue('Subscription ID should be positive', SubID > 0);

    FEventBus.ClearSubscribersForOwner(OwnerObj);
  finally
    OwnerObj.Free;
  end;
end;

procedure TTestAMIEventBus.TestEventBusStats;
var
  Stats: string;
begin
  Stats := FEventBus.GetStats;
  AssertTrue('Stats should not be empty', Length(Stats) > 0);
end;

initialization
  RegisterTest(TTestAMIEventBus);
end.
