unit ami_bus;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections,
  i_eventbus, ami_types, ami_enums;

type
{==============================================================================}
{=== TLegacyEventBus =======================================================}
{==============================================================================}

  TLegacyEventBus = class
  private
    FBus: IEventBus;
  public
    constructor Create;
    destructor Destroy; override;
    function Subscribe(AHandler: TAMIEventEvent; AOwner: TObject = nil;
      ACallInMainThread: Boolean = False; const AEventNameFilter: string = '';
      const AEventTypes: TAMIEventTypes = nil; AMinPriority: Integer = 0): Integer;
    procedure Unsubscribe(AID: Integer);
    procedure Dispatch(const AEvent: TAMIEvent);
    function GetStats: string;
  end;

function AMIEventBus: TLegacyEventBus;

implementation

uses
  ami_eventbus_threaded, ami_bus_queue;

var
  GLegacyEventBus: TLegacyEventBus = nil;

{==============================================================================}
{=== TLegacyEventBus =======================================================}
{==============================================================================}

constructor TLegacyEventBus.Create;
begin
  inherited Create;
  FBus := TThreadedEventBus.Create(4, 10000, opDropOldest, 5000);
end;

destructor TLegacyEventBus.Destroy;
begin
  FBus := nil;
  inherited Destroy;
end;

function TLegacyEventBus.Subscribe(AHandler: TAMIEventEvent; AOwner: TObject;
  ACallInMainThread: Boolean; const AEventNameFilter: string;
  const AEventTypes: TAMIEventTypes; AMinPriority: Integer): Integer;
begin
  Result := FBus.Subscribe(AHandler, AOwner, ACallInMainThread, AEventNameFilter, AEventTypes, AMinPriority);
end;

procedure TLegacyEventBus.Unsubscribe(AID: Integer);
begin
  FBus.Unsubscribe(AID);
end;

procedure TLegacyEventBus.Dispatch(const AEvent: TAMIEvent);
begin
  FBus.Dispatch(AEvent);
end;

function TLegacyEventBus.GetStats: string;
begin
  Result := FBus.GetStats;
end;

function AMIEventBus: TLegacyEventBus;
begin
  if not Assigned(GLegacyEventBus) then
    GLegacyEventBus := TLegacyEventBus.Create;
  Result := GLegacyEventBus;
end;

finalization
  FreeAndNil(GLegacyEventBus);

end.
