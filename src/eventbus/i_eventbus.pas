unit i_eventbus;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ami_types, ami_enums, Generics.Collections;

type
  IEventBus = interface
    ['{2C9A1D3F-8E6C-4F8A-BB6A-1F3E9C1B2A4F}']
    function Subscribe(AHandler: TAMIEventEvent; AOwner: TObject = nil;
      ACallInMainThread: Boolean = False; const AEventNameFilter: string = '';
      const AEventTypes: TAMIEventTypes = nil; AMinPriority: Integer = 0): Integer;
    procedure Unsubscribe(AID: Integer);
    procedure ClearSubscribersForOwner(AOwner: TObject);
    procedure Dispatch(const AEvent: TAMIEvent);
    function GetStats: string;
  end;

implementation

end.
