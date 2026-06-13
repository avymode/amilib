unit ami_types;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TypInfo, Generics.Collections, ami_enums, ami_log, ami_exceptions,
  ami_event_map;

type
  TAMIMessage = class;
  TAMIAction = class;
  TAMIResponse = class;
  TAMIEvent = class;

  TAMILogEvent = procedure(Sender: TObject; Level: TAMILogLevel; const Msg: string) of object;
  TAMIResponseEvent = procedure(Sender: TObject; const Response: TAMIResponse) of object;
  TAMIEventEvent = procedure(Sender: TObject; const Event: TAMIEvent) of object;
  TAMIConnectEvent = procedure(Sender: TObject) of object;
  TAMIDisconnectEvent = procedure(Sender: TObject) of object;

  {==============================================================================}
  {=== TAMIMessage ===========================================================}
  {==============================================================================}

  TAMIMessage = class(TObject)
  private
    FFields: TStringList;
    FMessageType: TAMIMessageType;
    FActionID: string;
    FTimestamp: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddField(const AKey, AValue: string);
    function GetField(const AKey: string): string;
    function HasField(const AKey: string): boolean;
    function FieldCount: integer;
    function GetFieldName(Index: integer): string;
    function GetFieldValue(Index: integer): string;

    procedure UpdateFromFields; virtual;
    procedure Assign(Source: TAMIMessage);
    function ToString: string; override;
    function Clone: TAMIMessage; virtual;

    property MessageType: TAMIMessageType read FMessageType write FMessageType;
    property ActionID: string read FActionID write FActionID;
    property Fields: TStringList read FFields;
    property Timestamp: TDateTime read FTimestamp;
  end;

{==============================================================================}
{=== TAMIAction =============================================================}
{==============================================================================}

  TAMIAction = class(TAMIMessage)
  private
    FActionName: string;
  public
    constructor Create; overload;
    constructor Create(const AActionName: string); overload;
    property ActionName: string read FActionName write FActionName;
  end;

{==============================================================================}
{=== TAMIResponse ===========================================================}
{==============================================================================}

  TAMIResponse = class(TAMIMessage)
  private
    FResponse: string;
    FMessage: string;
    FSuccess: boolean;
    FFollowUpEvents: specialize TObjectList<TAMIEvent>;

  public
    constructor Create;
    destructor Destroy; override;

    procedure UpdateFromFields; override;
    function IsSuccess: boolean;
    procedure Assign(Source: TAMIMessage);

    procedure AddFollowUpEvent(const AEvent: TAMIEvent);
    function HasFollowUpEvents: Boolean;
    function GetFollowUpEventCount: Integer;
    function GetFollowUpEvent(Index: Integer): TAMIEvent;

    property Response: string read FResponse write FResponse;
    property Message: string read FMessage write FMessage;
    property Success: boolean read FSuccess;
  end;

{==============================================================================}
{=== TAMICommandResponse =====================================================}
{==============================================================================}

  TAMICommandResponse = class(TAMIResponse)
  private
    FOutputLines: TStringList;
    FCommandOutput: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure UpdateFromFields; override;
    function GetFullOutput: string;
    function GetOutputLineCount: integer;

    property OutputLines: TStringList read FOutputLines;
    property CommandOutput: string read FCommandOutput;
  end;

{==============================================================================}
{=== TAMIEvent ==============================================================}
{==============================================================================}

  TAMIEvent = class(TAMIMessage)
  private
    FEventName: string;
    FEventType: TAMIEventType;
  public
    constructor Create;
    function GetEventName: string;
    procedure UpdateFromFields; override;
    function Clone: TAMIEvent;

    property EventName: string read FEventName write FEventName;
    property EventType: TAMIEventType read FEventType;
  end;

  TAMIEventTypes = array of TAMIEventType;

{==============================================================================}
{=== TAMIDBGetResponse =====================================================}
{==============================================================================}

  TAMIDBGetResponse = class(TAMIResponse)
  private
    FFamily: string;
    FKey: string;
    FValue: string;
    FHasData: Boolean;
  public
    constructor Create;
    procedure UpdateFromFields; override;

    property Family: string read FFamily;
    property Key: string read FKey;
    property Value: string read FValue;
    property HasData: Boolean read FHasData;
  end;

{==============================================================================}
{=== Configuration and Info Records =========================================}
{==============================================================================}

  TAMIClientConfig = record
    Host: string;
    Port: word;
    Username: string;
    Password: string;
    AuthType: string;
    UseTLS: boolean;
    TLSVersion: string;
    VerifyCertificate: boolean;
    ConnectionTimeout: integer;
    ResponseTimeout: integer;
    ReadTimeout: integer;
    WriteTimeout: integer;
    ReconnectInterval: integer;
    MaxReconnectAttempts: integer;
    ReconnectBackoff: boolean;
    PingInterval: integer;
    PingTimeout: integer;
    UTF8Enabled: boolean;
    EventMask: string;
    BufferSize: integer;
    EnableCompression: boolean;
    MaxConcurrentActions: integer;
    MaxActionsPerSecond: integer;
    MaxRetries: integer;
    UseIPv6: boolean;
    UseJSON: boolean;
    OnLog: TAMILogEvent;
  end;

  TOriginateParams = record
    Channel: string;
    Context: string;
    Extension: string;
    Priority: string;
    Application: string;
    Data: string;
    Timeout: integer;
    CallerID: string;
    Account: string;
    Async: boolean;
    ActionID: string;
    EarlyMedia: boolean;
    Codecs: string;
    Variables: TStringList;
    ChannelId: string;
  end;

  TChannelInfo = record
    Channel: string;
    UniqueID: string;
    LinkedID: string;
    CallerIDNum: string;
    CallerIDName: string;
    ConnectedLineNum: string;
    ConnectedLineName: string;
    State: string;
    StateDesc: string;
    Context: string;
    Extension: string;
    Priority: string;
    AccountCode: string;
    Duration: integer;
    BillableSeconds: integer;
  end;

  THangupInfo = record
    Channel: string;
    UniqueID: string;
    LinkedID: string;
    Cause: integer;
    CauseTxt: string;
    Duration: integer;
    BillableSeconds: integer;
  end;

  TDialInfo = record
    Channel: string;
    Destination: string;
    DestUniqueID: string;
    CallerIDNum: string;
    CallerIDName: string;
    ConnectedLineNum: string;
    ConnectedLineName: string;
    DialStatus: string;
    Forward: string;
    Forwarded: boolean;
  end;

const
  LIBRARY_VERSION = '1.0.0';

implementation

uses StrUtils;

{==============================================================================}
{=== TAMIMessage ===========================================================}
{==============================================================================}

constructor TAMIMessage.Create;
begin
  inherited Create;
  FFields := TStringList.Create;
  FFields.CaseSensitive := False;
  FFields.Duplicates := dupAccept;
  FFields.Sorted := False;
  FMessageType := mtAction;
  FActionID := '';
  FTimestamp := Now;
end;

destructor TAMIMessage.Destroy;
begin
  FreeAndNil(FFields);
  inherited Destroy;
end;

procedure TAMIMessage.AddField(const AKey, AValue: string);
begin
  FFields.Add(AKey + ': ' + AValue);
  if SameText(AKey, 'ActionID') then
    FActionID := AValue;
end;

function TAMIMessage.GetField(const AKey: string): string;
var
  i, SepPos: integer;
  Key, Line: string;
begin
  Result := '';
  for i := 0 to FFields.Count - 1 do
  begin
    Line := FFields[i];
    SepPos := Pos(':', Line);
    if SepPos > 0 then
    begin
      Key := Trim(Copy(Line, 1, SepPos - 1));
      if SameText(Key, AKey) then
      begin
        Result := Trim(Copy(Line, SepPos + 1, MaxInt));
        Exit;
      end;
    end;
  end;
end;

function TAMIMessage.HasField(const AKey: string): boolean;
begin
  Result := GetField(AKey) <> '';
end;

function TAMIMessage.FieldCount: integer;
begin
  Result := FFields.Count;
end;

function TAMIMessage.GetFieldName(Index: integer): string;
var
  SepPos: integer;
begin
  if (Index >= 0) and (Index < FFields.Count) then
  begin
    SepPos := Pos(':', FFields[Index]);
    if SepPos > 0 then
      Result := Trim(Copy(FFields[Index], 1, SepPos - 1))
    else
      Result := FFields[Index];
  end
  else
    Result := '';
end;

function TAMIMessage.GetFieldValue(Index: integer): string;
var
  SepPos: integer;
begin
  if (Index >= 0) and (Index < FFields.Count) then
  begin
    SepPos := Pos(':', FFields[Index]);
    if SepPos > 0 then
      Result := Trim(Copy(FFields[Index], SepPos + 1, MaxInt))
    else
      Result := '';
  end
  else
    Result := '';
end;

procedure TAMIMessage.Assign(Source: TAMIMessage);
begin
  if Assigned(Source) then
  begin
    FFields.Assign(Source.FFields);
    FMessageType := Source.FMessageType;
    FActionID := Source.FActionID;
    FTimestamp := Source.FTimestamp;
  end;
end;

function TAMIMessage.ToString: string;
begin
  Result := Format('[%s] %s (Fields: %d)',
    [FormatDateTime('hh:nn:ss.zzz', FTimestamp),
    GetEnumName(TypeInfo(TAMIMessageType), Ord(FMessageType)), FieldCount]);
end;

procedure TAMIMessage.UpdateFromFields;
begin
end;

function TAMIMessage.Clone: TAMIMessage;
var
  Cls: TAMIMessage;
begin
  Cls := TAMIMessage(Self.ClassType);
  Result := Cls.Create;
  Result.Assign(Self);
  Result.UpdateFromFields;
end;

{==============================================================================}
{=== TAMIAction =============================================================}
{==============================================================================}

constructor TAMIAction.Create;
begin
  inherited Create;
  FActionName := '';
  FMessageType := mtAction;
  AddField('Action', '');
end;

constructor TAMIAction.Create(const AActionName: string);
begin
  inherited Create;
  FActionName := AActionName;
  FMessageType := mtAction;
  AddField('Action', AActionName);
end;

{==============================================================================}
{=== TAMIResponse ===========================================================}
{==============================================================================}

constructor TAMIResponse.Create;
begin
  inherited Create;
  FMessageType := mtResponse;
  FResponse := '';
  FMessage := '';
  FSuccess := False;
  FFollowUpEvents := specialize TObjectList<TAMIEvent>.Create(True);
end;

destructor TAMIResponse.Destroy;
begin
  FreeAndNil(FFollowUpEvents);
  inherited Destroy;
end;

procedure TAMIResponse.AddFollowUpEvent(const AEvent: TAMIEvent);
var
  FClone: TAMIEvent;
begin
  FClone := TAMIEvent.Create;
  FClone.Assign(AEvent);
  FClone.UpdateFromFields;
  FFollowUpEvents.Add(FClone);
end;

function TAMIResponse.HasFollowUpEvents: Boolean;
begin
  Result := FFollowUpEvents.Count > 0;
end;

function TAMIResponse.GetFollowUpEventCount: Integer;
begin
  Result := FFollowUpEvents.Count;
end;

function TAMIResponse.GetFollowUpEvent(Index: Integer): TAMIEvent;
begin
  if (Index >= 0) and (Index < FFollowUpEvents.Count) then
    Result := FFollowUpEvents[Index]
  else
    Result := nil;
end;

procedure TAMIResponse.UpdateFromFields;
begin
  FResponse := GetField('Response');
  FMessage := GetField('Message');
  FSuccess := SameText(FResponse, 'Success') or
              SameText(FResponse, 'Follows') or
              SameText(FResponse, 'Pong');
  if FMessage = '' then
  begin
    if not SameText(Trim(FResponse), 'Follows') then
    begin
      FMessage := GetField('ActionID');
      if FMessage = '' then
        FMessage := GetField('Event');
    end;
  end;
end;

function TAMIResponse.IsSuccess: boolean;
begin
  Result := FSuccess or SameText(Trim(GetField('Response')), 'Success') or
    SameText(Trim(GetField('Response')), 'Follows');
end;

procedure TAMIResponse.Assign(Source: TAMIMessage);
var
  i: Integer;
  EvtClone: TAMIEvent;
begin
  if Assigned(Source) then
  begin
    inherited Assign(Source);

    if Source is TAMIResponse then
    begin
      FResponse := TAMIResponse(Source).FResponse;
      FMessage := TAMIResponse(Source).FMessage;
      FSuccess := TAMIResponse(Source).FSuccess;

      if Assigned(TAMIResponse(Source).FFollowUpEvents) and
         (TAMIResponse(Source).FFollowUpEvents.Count > 0) then
      begin
        FFollowUpEvents.Clear;
        for i := 0 to TAMIResponse(Source).FFollowUpEvents.Count - 1 do
        begin
          EvtClone := TAMIEvent.Create;
          try
            EvtClone.Assign(TAMIResponse(Source).FFollowUpEvents[i]);
            EvtClone.UpdateFromFields;
            FFollowUpEvents.Add(EvtClone);
          except
            EvtClone.Free;
            raise;
          end;
        end;
      end;
    end;
  end;
end;

{==============================================================================}
{=== TAMICommandResponse =====================================================}
{==============================================================================}

constructor TAMICommandResponse.Create;
begin
  inherited Create;
  FOutputLines := TStringList.Create;
  FCommandOutput := '';
end;

destructor TAMICommandResponse.Destroy;
begin
  FreeAndNil(FOutputLines);
  inherited Destroy;
end;

procedure TAMICommandResponse.UpdateFromFields;
var
  i: integer;
  FieldName, FieldValue: string;
begin
  inherited UpdateFromFields;

  FOutputLines.Clear;
  FCommandOutput := '';

  for i := 0 to FieldCount - 1 do
  begin
    FieldName := GetFieldName(i);
    if SameText(FieldName, 'Output') then
    begin
      FieldValue := GetFieldValue(i);
      FOutputLines.Add(FieldValue);
    end;
  end;

  if FOutputLines.Count > 0 then
    FCommandOutput := FOutputLines.Text
  else
    FCommandOutput := '';
end;

function TAMICommandResponse.GetFullOutput: string;
begin
  Result := FCommandOutput;
end;

function TAMICommandResponse.GetOutputLineCount: integer;
begin
  Result := FOutputLines.Count;
end;

{==============================================================================}
{=== TAMIDBGetResponse =====================================================}
{==============================================================================}

constructor TAMIDBGetResponse.Create;
begin
  inherited Create;
  FFamily := '';
  FKey := '';
  FValue := '';
  FHasData := False;
end;

procedure TAMIDBGetResponse.UpdateFromFields;
var
  i, j: Integer;
  FieldName, FieldValue, EventName: string;
  Evt: TAMIEvent;
begin
  inherited UpdateFromFields;

  FFamily := '';
  FKey := '';
  FValue := '';
  FHasData := False;

  for j := 0 to GetFollowUpEventCount - 1 do
  begin
    Evt := GetFollowUpEvent(j);
    if not Assigned(Evt) then Continue;

    EventName := UpperCase(Evt.GetEventName);

    if EventName = 'DBGETRESPONSE' then
    begin
      FFamily := Evt.GetField('Family');
      FKey := Evt.GetField('Key');
      FValue := Evt.GetField('Val');
      FHasData := (FFamily <> '') or (FKey <> '');
    end
    else if EventName = 'DBGETCOMPLETE' then
      Break;
  end;
end;

{==============================================================================}
{=== TAMIEvent ==============================================================}
{==============================================================================}

constructor TAMIEvent.Create;
begin
  inherited Create;
  FMessageType := mtEvent;
  FEventName := '';
  FEventType := etUnknown;
end;

function TAMIEvent.GetEventName: string;
begin
  Result := GetField('Event');
  if Result = '' then
    Result := FEventName;
end;

function TAMIEvent.Clone: TAMIEvent;
begin
  Result := TAMIEvent.Create;
  Result.Assign(Self);
end;


procedure TAMIEvent.UpdateFromFields;
var
  E: string;
begin
  inherited UpdateFromFields;
  FEventName := GetField('Event');
  E := UpperCase(FEventName);
  if not EventTypeMap.TryGetValue(E, FEventType) then
    FEventType := etUnknown;
end;

end.
