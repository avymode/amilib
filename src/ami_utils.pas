unit ami_utils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, MD5, ami_enums, ami_log;

type
  TAMIUtils = class
  public
    class function GenerateActionID: String;
    class function GenerateMD5Challenge(const AChallenge, APassword: String): String;
    class function GetCurrentTimestamp: String;
    class function FormatBytes(ABytes: Int64): String;
    class function GetElapsedTimeString(const AStart: TDateTime): String;
    class function ToUnixTime(ADateTime: TDateTime): Int64;
    class function FromUnixTime(AUnixTime: Int64): TDateTime;
    class function IfThen(AValue: Boolean; const ATrue: String; const AFalse: String = ''): String; overload;
    class function IfThen(AValue: Boolean; const ATrue: Double; const AFalse: Double = 0): Double; overload;
    class function IfThen(AValue: Boolean; const ATrue: Integer; const AFalse: Integer = 0): Integer; overload;
    class function AmiToBool(const AmiString: String): Boolean;
    class function ClientStatusToString(AStatus: TAMIClientStatus): string;
    class function ParseClientStatus(const AState: string): TAMIClientStatus;
    class function BuildHangupRegexForExtension(const OpExt: string;
      IncludeSIP: Boolean = True; IncludePJSIP: Boolean = True): string;
  end;

implementation

{$IFDEF UNIX}
uses
  BaseUnix;
{$ENDIF}

var
  GlobalActionCounter: Int64 = 0;

function GetCurrentProcessID: Cardinal;
begin
  Result := 0;
  {$IFDEF UNIX}
  Result := FpGetPid;
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := GetCurrentProcessId;
  {$ENDIF}
end;

{==============================================================================}
{=== TAMIUtils ==============================================================}
{==============================================================================}

class function TAMIUtils.GenerateActionID: String;
var
  Counter: Int64;
  UnixTime: Int64;
  Milliseconds: Int64;
  ProcessID: Cardinal;
begin
  Counter := InterlockedIncrement64(GlobalActionCounter);
  UnixTime := DateTimeToUnix(Now, False);
  Milliseconds := MilliSecondOf(Now);
  ProcessID := GetCurrentProcessID;
  Result := Format('ami_%d_%d_%.6u_%.6d', [UnixTime, Milliseconds, ProcessID, Counter mod 1000000]);
end;

class function TAMIUtils.AmiToBool(const AmiString: String): Boolean;
var
  s: String;
begin
  s := Trim(UpperCase(AmiString));
  Result := (s = '1') or (s = 'YES') or (s = 'ON') or (s = 'TRUE');
end;

class function TAMIUtils.GenerateMD5Challenge(const AChallenge, APassword: String): String;
var
  Hash1, Hash2: String;
begin
  Hash1 := LowerCase(MD5Print(MD5String(APassword)));
  Hash2 := LowerCase(MD5Print(MD5String(AChallenge + Hash1)));
  Result := Hash2;
end;

class function TAMIUtils.GetCurrentTimestamp: String;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
end;

class function TAMIUtils.FormatBytes(ABytes: Int64): String;
const
  UNITS: array[0..4] of String = ('B', 'KB', 'MB', 'GB', 'TB');
var
  UnitIndex: Integer;
  Size: Double;
begin
  UnitIndex := 0;
  Size := ABytes;
  while (Size >= 1024) and (UnitIndex < High(UNITS)) do
  begin
    Size := Size / 1024;
    Inc(UnitIndex);
  end;
  if UnitIndex = 0 then
    Result := Format('%d %s', [ABytes, UNITS[UnitIndex]])
  else
    Result := Format('%.2f %s', [Size, UNITS[UnitIndex]]);
end;

class function TAMIUtils.GetElapsedTimeString(const AStart: TDateTime): String;
var
  Elapsed: TDateTime;
  Hours, Minutes, Seconds, Milliseconds: Word;
begin
  Elapsed := Now - AStart;
  DecodeTime(Elapsed, Hours, Minutes, Seconds, Milliseconds);
  Result := Format('%d:%.2d:%.2d.%.3d', [Hours, Minutes, Seconds, Milliseconds]);
end;

class function TAMIUtils.ToUnixTime(ADateTime: TDateTime): Int64;
begin
  Result := DateTimeToUnix(ADateTime, False);
end;

class function TAMIUtils.FromUnixTime(AUnixTime: Int64): TDateTime;
begin
  Result := UnixToDateTime(AUnixTime, False);
end;

class function TAMIUtils.IfThen(AValue: Boolean; const ATrue: String; const AFalse: String): String;
begin
  if AValue then Result := ATrue else Result := AFalse;
end;

class function TAMIUtils.IfThen(AValue: Boolean; const ATrue: Double; const AFalse: Double): Double;
begin
  if AValue then Result := ATrue else Result := AFalse;
end;

class function TAMIUtils.IfThen(AValue: Boolean; const ATrue: Integer; const AFalse: Integer): Integer;
begin
  if AValue then Result := ATrue else Result := AFalse;
end;

class function TAMIUtils.ClientStatusToString(AStatus: TAMIClientStatus): string;
begin
  case AStatus of
    csDisconnected: Result := 'Disconnected';
    csConnecting: Result := 'Connecting';
    csConnected: Result := 'Connected';
    csAuthenticating: Result := 'Authenticating';
    csAuthFailed: Result := 'AuthFailed';
    csReconnecting: Result := 'Reconnecting';
  else
    Result := 'Unknown';
  end;
end;

class function TAMIUtils.ParseClientStatus(const AState: string): TAMIClientStatus;
begin
  AmiLog(llDebug, Format('ParseClientStatus: input="%s"', [AState]));
  if SameText(AState, 'Connected') then
    Result := csConnected
  else if SameText(AState, 'Connecting') then
    Result := csConnecting
  else if SameText(AState, 'Authenticating') then
    Result := csAuthenticating
  else if SameText(AState, 'AuthFailed') then
    Result := csAuthFailed
  else if SameText(AState, 'Reconnecting') then
    Result := csReconnecting
  else if SameText(AState, 'Disconnected') then
    Result := csDisconnected
  else
    Result := csDisconnected;
end;

class function TAMIUtils.BuildHangupRegexForExtension(const OpExt: string;
  IncludeSIP: Boolean; IncludePJSIP: Boolean): string;

  function IsDigitsOnly(const S: string): Boolean;
  var
    i: Integer;
  begin
    Result := (S <> '');
    if not Result then Exit;
    for i := 1 to Length(S) do
      if not (S[i] in ['0'..'9']) then
        Exit(False);
  end;

var
  Proto: string;
begin
  if not IsDigitsOnly(OpExt) then
    raise Exception.CreateFmt('Invalid extension for regex hangup: %s', [OpExt]);

  if IncludeSIP and IncludePJSIP then
    Proto := '^(SIP|PJSIP)/'
  else if IncludeSIP then
    Proto := '^SIP/'
  else if IncludePJSIP then
    Proto := '^PJSIP/'
  else
    raise Exception.Create('At least one protocol must be included for regex hangup');

  // Result example: '/^(SIP|PJSIP)\/10255-.*$/'
  Result := Format('/%s%s-.*$/', [Proto, OpExt]);
end;

initialization
  Randomize;

end.
