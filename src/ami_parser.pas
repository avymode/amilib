unit ami_parser;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ami_types, fpjson, jsonparser, ami_enums, ami_log, Generics.Collections,
  ami_event_map;

type
  TAMIBuffer = class
  private
    FData: PByte;
    FSize: Integer;
    FCapacity: Integer;
    FPosition: Integer;
    procedure Grow(MinSize: Integer);
  public
    constructor Create(InitialCapacity: Integer = 8192);
    destructor Destroy; override;
    procedure Clear;
    procedure Append(const Data: Pointer; Size: Integer);
    procedure Compact;
    function ReadLine(out Line: RawByteString): Boolean;
    function HasCompleteMessage: Boolean;
    property Position: Integer read FPosition write FPosition;
    property Size: Integer read FSize;
  end;

  TAMIReader = class
  private
    FStream: TStream;
    FBuffer: TAMIBuffer;
    FConfig: TAMIClientConfig;
    FLineBuffer: RawByteString;
    FBytesRead: Int64;
    FMessagesRead: Integer;
    FOwnsBuffer: Boolean;
    FOnLog: TAMILogEvent;

    function ReadFromStream: Boolean;
    function ParseMessageFromBuffer: TAMIMessage;
    function ParseJSONMessage: TAMIMessage;
    function ParseKVMessage: TAMIMessage;
    procedure DoLog(const Msg: String; Level: TAMILogLevel);

  public
    constructor Create(AStream: TStream); overload;
    constructor Create(ABuffer: TAMIBuffer); overload;
    constructor Create(ABuffer: TAMIBuffer; const AConfig: TAMIClientConfig); overload;
    destructor Destroy; override;
    function ReadMessage: TAMIMessage;
    function HasData: Boolean;

    property BytesRead: Int64 read FBytesRead;
    property MessagesRead: Integer read FMessagesRead;
    property OnLog: TAMILogEvent read FOnLog write FOnLog;
  end;

  TAMIWriter = class
  private
    class function EscapeValue(const Value: String): String;
    class function ValidateFieldName(const Name: String): Boolean;
  public
    class function WriteMessage(const AMessage: TAMIMessage): RawByteString;
    class function WriteAction(const AAction: TAMIAction): RawByteString;
    class function WriteResponse(const AResponse: TAMIResponse): RawByteString;
  end;

  TAMIEventParser = class
  public
    class function ParseEventType(const AEventName: String): TAMIEventType;
    class function ParseChannelInfo(const AEvent: TAMIEvent): TChannelInfo;
    class function ParseHangupInfo(const AEvent: TAMIEvent): THangupInfo;
    class function ParseDialInfo(const AEvent: TAMIEvent): TDialInfo;
    class function IsCallRelatedEvent(const AEvent: TAMIEvent): Boolean;
    class function ExtractChannelFromEvent(const AEvent: TAMIEvent): String;
    class function GetEventPriority(const AEventType: TAMIEventType): Integer;
    class function GetEventCategory(const AEventType: TAMIEventType): String;
  end;

  TTempBuffer = array[0..4095] of Byte;

implementation

uses Math, StrUtils;


function IsHeaderKey(const Key: String): Boolean;
const
  HeaderKeys: array[0..8] of String = (
    'RESPONSE', 'ACTIONID', 'MESSAGE', 'EVENT', 'PRIVILEGE',
    'CHANNEL', 'UNIQUEID', 'LINKEDID', 'SERVER');
var
  i: Integer;
begin
  Result := False;
  for i := Low(HeaderKeys) to High(HeaderKeys) do
  begin
    if SameText(Key, HeaderKeys[i]) then
      Exit(True);
  end;
end;

function RawBytesToUTF8String(const Bytes: RawByteString): String;
begin
  Result := String(Bytes);
  SetCodePage(RawByteString(Result), CP_UTF8, False);
end;

{==============================================================================}
{=== TAMIEventParser =========================================================}
{==============================================================================}

class function TAMIEventParser.ParseEventType(const AEventName: String): TAMIEventType;
var
  UpperEventName: String;
begin
  UpperEventName := UpperCase(AEventName);
  if not EventTypeMap.TryGetValue(UpperEventName, Result) then
  begin
    AmiLog(llWarning, Format('Event type not found in map: "%s"', [AEventName]));
    Result := etUnknown;
  end;
end;

class function TAMIEventParser.ParseChannelInfo(const AEvent: TAMIEvent): TChannelInfo;
begin
  Result := Default(TChannelInfo);
  Result.Channel := AEvent.GetField('Channel');
  Result.UniqueID := AEvent.GetField('UniqueID');
  Result.LinkedID := AEvent.GetField('LinkedID');
  Result.CallerIDNum := AEvent.GetField('CallerIDNum');
  Result.CallerIDName := AEvent.GetField('CallerIDName');
  Result.ConnectedLineNum := AEvent.GetField('ConnectedLineNum');
  Result.ConnectedLineName := AEvent.GetField('ConnectedLineName');
  Result.State := AEvent.GetField('State');
  Result.StateDesc := AEvent.GetField('StateDesc');
  Result.Context := AEvent.GetField('Context');
  Result.Extension := AEvent.GetField('Extension');
  Result.Priority := AEvent.GetField('Priority');
  Result.AccountCode := AEvent.GetField('AccountCode');
  Result.Duration := StrToIntDef(AEvent.GetField('Duration'), 0);
  Result.BillableSeconds := StrToIntDef(AEvent.GetField('BillableSeconds'), 0);
end;

class function TAMIEventParser.ParseHangupInfo(const AEvent: TAMIEvent): THangupInfo;
begin
  Result := Default(THangupInfo);
  Result.Channel := AEvent.GetField('Channel');
  Result.UniqueID := AEvent.GetField('UniqueID');
  Result.LinkedID := AEvent.GetField('LinkedID');
  Result.Cause := StrToIntDef(AEvent.GetField('Cause'), 0);
  Result.CauseTxt := AEvent.GetField('CauseTxt');
  Result.Duration := StrToIntDef(AEvent.GetField('Duration'), 0);
  Result.BillableSeconds := StrToIntDef(AEvent.GetField('BillableSeconds'), 0);
end;

class function TAMIEventParser.ParseDialInfo(const AEvent: TAMIEvent): TDialInfo;
begin
  Result := Default(TDialInfo);
  Result.Channel := AEvent.GetField('Channel');
  Result.Destination := AEvent.GetField('Destination');
  Result.DestUniqueID := AEvent.GetField('DestUniqueID');
  Result.CallerIDNum := AEvent.GetField('CallerIDNum');
  Result.CallerIDName := AEvent.GetField('CallerIDName');
  Result.ConnectedLineNum := AEvent.GetField('ConnectedLineNum');
  Result.ConnectedLineName := AEvent.GetField('ConnectedLineName');
  Result.DialStatus := AEvent.GetField('DialStatus');
  Result.Forward := AEvent.GetField('Forward');
  Result.Forwarded := (Result.Forward <> '');
end;

class function TAMIEventParser.IsCallRelatedEvent(const AEvent: TAMIEvent): Boolean;
var
  EventType: TAMIEventType;
begin
  EventType := ParseEventType(AEvent.GetEventName);
  Result := EventType in [etNewchannel, etHangup, etDialBegin, etDialEnd, etBridgeEnter, etBridgeLeave, etNewstate, etNewCallerid, etNewConnectedLine, etHold, etUnhold, etAttendedTransfer, etBlindTransfer, etChannelHungup];
end;

class function TAMIEventParser.ExtractChannelFromEvent(const AEvent: TAMIEvent): String;
begin
  Result := AEvent.GetField('Channel');
  if Result = '' then
    Result := AEvent.GetField('DestChannel');
  if Result = '' then
    Result := AEvent.GetField('BridgeChannel');
end;

class function TAMIEventParser.GetEventPriority(const AEventType: TAMIEventType): Integer;
begin
  if not EventPriorityMap.TryGetValue(AEventType, Result) then
    Result := 25;
end;

class function TAMIEventParser.GetEventCategory(const AEventType: TAMIEventType): String;
begin
  if not EventCategoryMap.TryGetValue(AEventType, Result) then
    Result := 'Unknown';
end;

{==============================================================================}
{=== TAMIBuffer (остается без изменений) =======================================}
{==============================================================================}

constructor TAMIBuffer.Create(InitialCapacity: Integer);
begin
  FCapacity := Max(InitialCapacity, 1024);
  FSize := 0;
  FPosition := 0;
  GetMem(FData, FCapacity);
end;

destructor TAMIBuffer.Destroy;
begin
  if Assigned(FData) then
    FreeMem(FData);
  inherited Destroy;
end;

procedure TAMIBuffer.Clear;
begin
  FSize := 0;
  FPosition := 0;
end;

procedure TAMIBuffer.Append(const Data: Pointer; Size: Integer);
begin
  if FSize + Size > FCapacity then
    Grow(FSize + Size);
  Move(Data^, (FData + FSize)^, Size);
  Inc(FSize, Size);
end;

procedure TAMIBuffer.Compact;
var
  Remaining: Integer;
begin
  if FPosition > 0 then
  begin
    Remaining := FSize - FPosition;
    if Remaining > 0 then
      Move((FData + FPosition)^, FData^, Remaining);
    FSize := Remaining;
    FPosition := 0;
  end;
end;

procedure TAMIBuffer.Grow(MinSize: Integer);
var
  NewCapacity: Integer;
  NewData: PByte;
begin
  NewCapacity := FCapacity;
  while NewCapacity < MinSize do
    NewCapacity := NewCapacity * 2;
  GetMem(NewData, NewCapacity);
  if FSize > 0 then
    Move(FData^, NewData^, FSize);
  FreeMem(FData);
  FData := NewData;
  FCapacity := NewCapacity;
end;

function TAMIBuffer.ReadLine(out Line: RawByteString): Boolean;
var
  StartPos, EndPos: Integer;
  LineLen: Integer;
begin
  Result := False;
  Line := '';
  if FPosition >= FSize then
    Exit;

  StartPos := FPosition;
  EndPos := StartPos;

  while (EndPos < FSize) and
        (PByte(FData + EndPos)^ <> 13) and
        (PByte(FData + EndPos)^ <> 10) do
    Inc(EndPos);

  if EndPos >= FSize then
    Exit;

  LineLen := EndPos - StartPos;
  if LineLen > 0 then
  begin
    SetLength(Line, LineLen);
    Move((FData + StartPos)^, Line[1], LineLen);
  end;

  FPosition := EndPos + 1;

  if (FPosition < FSize) and
     (PByte(FData + EndPos)^ = 13) and
     (PByte(FData + FPosition)^ = 10) then
    Inc(FPosition);

  Result := True;
end;

function TAMIBuffer.HasCompleteMessage: Boolean;
var
  Slice: RawByteString;
  s: String;
  i, Len: Integer;
begin
  Result := False;

  Len := FSize - FPosition;
  if Len <= 0 then Exit;

  SetLength(Slice, Len);
  Move((FData + FPosition)^, Slice[1], Len);
  s := String(Slice);

  if Pos('Asterisk Call Manager', s) > 0 then
  begin
    for i := 1 to Length(s) - 1 do
      if (s[i] = #13) and (s[i+1] = #10) then
        Exit(True);
  end;

  if Pos('Response: Follows', s) > 0 then
    Exit(Pos('--END COMMAND--', s) > 0);

  if Length(s) >= 4 then
  begin
    for i := 1 to Length(s) - 3 do
      if (s[i] = #13) and (s[i+1] = #10) and
         (s[i+2] = #13) and (s[i+3] = #10) then
        Exit(True);
  end;
end;

{==============================================================================}
{=== TAMIReader (остается без изменений) =======================================}
{==============================================================================}

constructor TAMIReader.Create(AStream: TStream);
begin
  FStream := AStream;
  FBuffer := TAMIBuffer.Create(8192);
  FOwnsBuffer := True;
  FLineBuffer := '';
  FBytesRead := 0;
  FMessagesRead := 0;
  FConfig := Default(TAMIClientConfig);
end;

constructor TAMIReader.Create(ABuffer: TAMIBuffer);
begin
  FStream := nil;
  FBuffer := ABuffer;
  FOwnsBuffer := False;
  FLineBuffer := '';
  FBytesRead := 0;
  FMessagesRead := 0;
  FConfig := Default(TAMIClientConfig);
end;

constructor TAMIReader.Create(ABuffer: TAMIBuffer; const AConfig: TAMIClientConfig);
begin
  FStream := nil;
  FBuffer := ABuffer;
  FOwnsBuffer := False;
  FConfig := AConfig;
  FLineBuffer := '';
  FBytesRead := 0;
  FMessagesRead := 0;
end;

destructor TAMIReader.Destroy;
begin
  if FOwnsBuffer and Assigned(FBuffer) then
    FBuffer.Free;
  inherited Destroy;
end;

procedure TAMIReader.DoLog(const Msg: String; Level: TAMILogLevel);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Level, Msg);
end;

function TAMIReader.ReadFromStream: Boolean;
var
  TempBuffer: TTempBuffer;
  ABytesRead: Integer;
begin
  Result := False;
  if not Assigned(FStream) then
    Exit;

  try
    TempBuffer := Default(TTempBuffer);
    ABytesRead := FStream.Read(TempBuffer[0], SizeOf(TempBuffer));
    if ABytesRead > 0 then
    begin
      FBuffer.Append(@TempBuffer[0], ABytesRead);
      Inc(FBytesRead, ABytesRead);
      Result := True;
    end;
  except
    Result := False;
  end;
end;

function TAMIReader.HasData: Boolean;
begin
  Result := FBuffer.HasCompleteMessage or ReadFromStream;
end;

function TAMIReader.ReadMessage: TAMIMessage;
begin
  Result := ParseMessageFromBuffer;
  if Assigned(Result) then
    Inc(FMessagesRead);
end;

function TAMIReader.ParseJSONMessage: TAMIMessage;
var
  Slice: RawByteString;
  JSONData: TJSONData;
  JSONObject: TJSONObject;
  i: Integer;
  Key, Value: String;
  MessageType: TAMIMessageType;
begin
  Result := nil;

  Slice := Default(RawByteString);
  SetLength(Slice, FBuffer.Size - FBuffer.Position);
  if Length(Slice) > 0 then
    Move((FBuffer.FData + FBuffer.Position)^, Slice[1], Length(Slice));

  try
    JSONData := GetJSON(Slice);
    try
      if JSONData is TJSONObject then
      begin
        JSONObject := TJSONObject(JSONData);

        if Assigned(JSONObject.Find('Response')) then
          MessageType := mtResponse
        else if Assigned(JSONObject.Find('Event')) then
          MessageType := mtEvent
        else
          MessageType := mtWelcome;

        case MessageType of
          mtResponse: Result := TAMIResponse.Create;
          mtEvent:    Result := TAMIEvent.Create;
        else
          Result := TAMIMessage.Create;
        end;

        Result.MessageType := MessageType;

        for i := 0 to JSONObject.Count - 1 do
        begin
          Key := JSONObject.Names[i];
          Value := JSONObject.Items[i].AsString;
          Result.AddField(Key, Value);
        end;

        Result.UpdateFromFields;

        FBuffer.Position := FBuffer.Size;
        FBuffer.Compact;
      end;
    finally
      JSONData.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function TAMIReader.ParseKVMessage: TAMIMessage;
var
  AllLines: TStringList;
  Line: RawByteString;
  LineStr: String;
  Key, Value: String;
  SepPos: Integer;
  IsCommandResponse: Boolean;
  IsDBGetResponse: Boolean;
  MessageType: TAMIMessageType;
  OriginalPosition: Integer;
  MessageTerminatorFound: Boolean;
  InBodySection: Boolean;
  i: Integer;
  IsWelcomeMessage: Boolean;
begin
  Result := nil;
  OriginalPosition := FBuffer.Position;
  AllLines := TStringList.Create;
  try
    MessageTerminatorFound := False;
    IsWelcomeMessage := False;
    while FBuffer.ReadLine(Line) do
    begin
      LineStr := RawBytesToUTF8String(Line);
      if (AllLines.Count = 0) and (Pos('Asterisk Call Manager', LineStr) > 0) then
      begin
        IsWelcomeMessage := True;
        AllLines.Add(LineStr);
        MessageTerminatorFound := True;
        Break;
      end;

      if Trim(LineStr) = '' then
      begin
        MessageTerminatorFound := True;
        Break;
      end;
      AllLines.Add(LineStr);
    end;

    if not MessageTerminatorFound then
    begin
      FBuffer.Position := OriginalPosition;
      Exit;
    end;

    if AllLines.Count = 0 then
    begin
      FBuffer.Compact;
      Exit;
    end;
    IsCommandResponse := False;
    IsDBGetResponse := False;

    if IsWelcomeMessage then
      MessageType := mtWelcome
    else
    begin
      MessageType := mtWelcome;

      for i := 0 to AllLines.Count - 1 do
      begin
        if StartsText('Response: Follows', AllLines[i]) then
        begin
          IsCommandResponse := True;
          MessageType := mtResponse;
          Break;
        end
        else if StartsText('Message: Result will follow', AllLines[i]) then
        begin
          IsDBGetResponse := True;
          MessageType := mtResponse;
        end
        else if StartsText('Response:', AllLines[i]) then
        begin
          MessageType := mtResponse;
          Break;
        end
        else if StartsText('Event:', AllLines[i]) then
        begin
          MessageType := mtEvent;
          Break;
        end;
      end;
    end;

    case MessageType of
      mtResponse:
        if IsCommandResponse then
          Result := TAMICommandResponse.Create
        else
          Result := TAMIResponse.Create;
      mtEvent:
        Result := TAMIEvent.Create;
    else
      Result := TAMIMessage.Create;
    end;

    if IsWelcomeMessage then
    begin
      Result.AddField('Welcome', AllLines[0]);
      Result.MessageType := mtWelcome;
    end
    else
    begin
      InBodySection := False;
      for i := 0 to AllLines.Count - 1 do
      begin
        LineStr := AllLines[i];

        if IsCommandResponse then
        begin
          if SameText(Trim(LineStr), '--END COMMAND--') then
            Continue;

          if not InBodySection then
          begin
            SepPos := Pos(':', LineStr);
            if (SepPos > 0) and IsHeaderKey(Trim(Copy(LineStr, 1, SepPos - 1))) then
            begin
              Key := Trim(Copy(LineStr, 1, SepPos - 1));
              Value := Trim(Copy(LineStr, SepPos + 1, MaxInt));
              Result.AddField(Key, Value);
            end
            else
            begin
              InBodySection := True;
              Result.AddField('Output', LineStr);
            end;
          end
          else
          begin
            Result.AddField('Output', LineStr);
          end;
        end
        else
        begin
          SepPos := Pos(':', LineStr);
          if SepPos > 0 then
          begin
            Key := Trim(Copy(LineStr, 1, SepPos - 1));
            Value := Trim(Copy(LineStr, SepPos + 1, MaxInt));
            Result.AddField(Key, Value);
          end
          else
          begin
            Result.AddField(LineStr, '');
          end;
        end;
      end;
    end;

    Result.UpdateFromFields;
    FBuffer.Compact;
  finally
    AllLines.Free;
  end;
end;


function TAMIReader.ParseMessageFromBuffer: TAMIMessage;
var
  FirstChar: Byte;
begin
  Result := nil;

  if (FBuffer.Size - FBuffer.Position) <= 0 then
    Exit;

  FirstChar := PByte(FBuffer.FData + FBuffer.Position)^;

  if (FirstChar = Ord('{')) and FConfig.UseJSON then
  begin
    Result := ParseJSONMessage;
    if Assigned(Result) then
      Exit;
  end;

  Result := ParseKVMessage;
end;

{==============================================================================}
{=== TAMIWriter (остается без изменений) =======================================}
{==============================================================================}

class function TAMIWriter.EscapeValue(const Value: String): String;
begin
  Result := StringReplace(Value, #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

class function TAMIWriter.ValidateFieldName(const Name: String): Boolean;
var
  i: Integer;
begin
  Result := (Length(Name) > 0);
  if not Result then
    Exit;

  for i := 1 to Length(Name) do
    if not (Name[i] in ['A'..'Z','a'..'z','0'..'9','_','-']) then
      Exit(False);
end;

class function TAMIWriter.WriteMessage(const AMessage: TAMIMessage): RawByteString;
var
  i: Integer;
  Line, Output: String;
begin
  Result := '';
  if not Assigned(AMessage) then
    Exit;

  Output := '';
  for i := 0 to AMessage.FieldCount - 1 do
  begin
    Line := AMessage.Fields[i];
    if Line <> '' then
      Output := Output + Line + #13#10;
  end;
  Output := Output + #13#10;
  Result := RawByteString(Output);
end;

class function TAMIWriter.WriteAction(const AAction: TAMIAction): RawByteString;
begin
  Result := WriteMessage(AAction);
end;

class function TAMIWriter.WriteResponse(const AResponse: TAMIResponse): RawByteString;
begin
  Result := WriteMessage(AResponse);
end;

end.
