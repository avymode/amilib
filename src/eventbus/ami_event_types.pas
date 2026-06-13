unit ami_event_types;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, DateUtils,
  ami_types, ami_enums, ami_parser;

type
{==============================================================================}
{=== TEventSubscriber =====================================================}
{==============================================================================}

  TEventSubscriber = class
  public
    ID: Integer;
    Owner: TObject;
    Handler: TAMIEventEvent;
    EventNameFilters: TStringList;
    EventTypeFilters: specialize TList<TAMIEventType>;
    MinPriority: Integer;
    CallInMainThread: Boolean;
    RefCount: Integer;
    Deleted: Boolean;

    constructor Create(AHandler: TAMIEventEvent; AOwner: TObject;
      const ANameFilter: string; const AEventTypes: TAMIEventTypes;
      ACallInMainThread: Boolean; AMinPriority: Integer);
    destructor Destroy; override;
    function MatchesEvent(const AEvent: TAMIEvent): Boolean;
  end;

{==============================================================================}
{=== TEventTask =============================================================}
{==============================================================================}

  TEventTask = class
  public
    Event: TAMIEvent;
    Subscriber: TEventSubscriber;
    EnqueuedAt: TDateTime;
    EventPriority: Integer;

    constructor Create(AEvent: TAMIEvent; ASubscriber: TEventSubscriber);
    destructor Destroy; override;
  end;

{==============================================================================}
{=== TInvokeItem =============================================================}
{==============================================================================}

  TInvokeItem = class
  public
    Subscriber: TEventSubscriber;
    Event: TAMIEvent;
  end;

implementation

{==============================================================================}
{=== TEventSubscriber =====================================================}
{==============================================================================}

constructor TEventSubscriber.Create(AHandler: TAMIEventEvent; AOwner: TObject;
  const ANameFilter: string; const AEventTypes: TAMIEventTypes;
  ACallInMainThread: Boolean; AMinPriority: Integer);
var
  i: Integer;
  s: string;
begin
  inherited Create;
  Handler := AHandler;
  Owner := AOwner;
  CallInMainThread := ACallInMainThread;
  MinPriority := AMinPriority;

  EventNameFilters := TStringList.Create;
  EventNameFilters.StrictDelimiter := True;
  EventNameFilters.Delimiter := ',';
  EventNameFilters.CaseSensitive := False;

  EventTypeFilters := specialize TList<TAMIEventType>.Create;

  if Trim(ANameFilter) <> '' then
  begin
    s := StringReplace(ANameFilter, ' ', '', [rfReplaceAll]);
    EventNameFilters.DelimitedText := s;
    for i := 0 to EventNameFilters.Count - 1 do
      EventNameFilters[i] := UpperCase(EventNameFilters[i]);
  end;

  if Assigned(AEventTypes) and (Length(AEventTypes) > 0) then
    for i := Low(AEventTypes) to High(AEventTypes) do
      EventTypeFilters.Add(AEventTypes[i]);

  RefCount := 0;
  Deleted := False;
end;

destructor TEventSubscriber.Destroy;
begin
  FreeAndNil(EventNameFilters);
  FreeAndNil(EventTypeFilters);
  inherited Destroy;
end;

function TEventSubscriber.MatchesEvent(const AEvent: TAMIEvent): Boolean;
var
  nm: string;
  et: TAMIEventType;
begin
  if Deleted then Exit(False);

  if EventTypeFilters.Count > 0 then
  begin
    et := AEvent.EventType;
    if EventTypeFilters.IndexOf(et) < 0 then Exit(False);
  end;

  if EventNameFilters.Count > 0 then
  begin
    nm := UpperCase(AEvent.GetEventName);
    if EventNameFilters.IndexOf(nm) < 0 then Exit(False);
  end;

  if AEvent.EventType <> etUnknown then
  begin
    if TAMIEventParser.GetEventPriority(AEvent.EventType) < MinPriority then
      Exit(False);
  end;

  Result := True;
end;

{==============================================================================}
{=== TEventTask =============================================================}
{==============================================================================}

constructor TEventTask.Create(AEvent: TAMIEvent; ASubscriber: TEventSubscriber);
begin
  inherited Create;
  Event := AEvent;
  Subscriber := ASubscriber;
  EnqueuedAt := Now;
  EventPriority := TAMIEventParser.GetEventPriority(AEvent.EventType);
end;

destructor TEventTask.Destroy;
begin
  FreeAndNil(Event);
  inherited Destroy;
end;

end.

