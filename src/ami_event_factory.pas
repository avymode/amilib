unit ami_event_factory;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, ami_types, ami_enums;

type
  TEventCreator = function: TAMIEvent;

{==============================================================================}
{=== TAMIEventFactory ======================================================}
{==============================================================================}

  TAMIEventFactory = class
  private
    class var FEventMap: specialize TDictionary<TAMIEventType, TEventCreator>;
    class procedure InitializeMap;
  public
    class function CreateEvent(AEventType: TAMIEventType): TAMIEvent;
    class procedure RegisterEvent(AEventType: TAMIEventType; ACreator: TEventCreator);
  end;

implementation

{==============================================================================}
{=== TAMIEventFactory ======================================================}
{==============================================================================}

class procedure TAMIEventFactory.InitializeMap;
begin
  FEventMap := specialize TDictionary<TAMIEventType, TEventCreator>.Create;
end;

class function TAMIEventFactory.CreateEvent(AEventType: TAMIEventType): TAMIEvent;
var
  Creator: TEventCreator;
begin
  if FEventMap.TryGetValue(AEventType, Creator) then
    Result := Creator()
  else
    Result := TAMIEvent.Create;
end;

class procedure TAMIEventFactory.RegisterEvent(AEventType: TAMIEventType; ACreator: TEventCreator);
begin
  FEventMap.AddOrSetValue(AEventType, ACreator);
end;

initialization
  TAMIEventFactory.InitializeMap;

finalization
  TAMIEventFactory.FEventMap.Free;

end.
