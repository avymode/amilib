unit ami_log;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Generics.Collections;

type
  TAMILogLevel = (llDebug, llInfo, llWarning, llError, llCritical);

procedure AmiLogInit(const ALogFile: string = ''; AUseConsole: boolean = False;
  ALogLevel: TAMILogLevel = llInfo);
procedure AmiLog(const Level: TAMILogLevel; const Msg: string); overload;
procedure AmiLog(const Msg: string); overload;
procedure AmiLogFlush;
procedure AmiLogShutdown;

implementation

uses DateUtils, StrUtils;

type
  TLogItem = record
    Level: TAMILogLevel;
    Msg: string;
    Timestamp: TDateTime;
    ThreadID: nativeuint;
  end;

{==============================================================================}
{=== TLogWriter =============================================================}
{==============================================================================}

  TLogWriter = class(TThread)
  private
    FQueue: specialize TList<TLogItem>;
    FLock: TCriticalSection;
    FEvent: TSimpleEvent;
    FLogFile: string;
    FUseConsole: boolean;
    FLogLevel: TAMILogLevel;
    FTerminating: boolean;
    procedure WriteOne(const Item: TLogItem);
  protected
    procedure Execute; override;
  public
    constructor Create(const ALogFile: string; AUseConsole: boolean;
      ALogLevel: TAMILogLevel);
    destructor Destroy; override;
    procedure Enqueue(const Item: TLogItem);
    procedure Flush;
    procedure Shutdown;
    property LogLevel: TAMILogLevel read FLogLevel write FLogLevel;
    property LogFile: string read FLogFile write FLogFile;
    property UseConsole: boolean read FUseConsole write FUseConsole;
  end;

var
  GLogWriter: TLogWriter = nil;
  GLogLock: TCriticalSection = nil;

{==============================================================================}
{=== Public Interface ========================================================}
{==============================================================================}

procedure AmiLogInit(const ALogFile: string = ''; AUseConsole: boolean = False;
  ALogLevel: TAMILogLevel = llInfo);
begin
  if GLogLock = nil then
    GLogLock := TCriticalSection.Create;

  GLogLock.Enter;
  try
    if Assigned(GLogWriter) then
    begin
      GLogWriter.LogFile := ALogFile;
      GLogWriter.UseConsole := AUseConsole;
      GLogWriter.LogLevel := ALogLevel;
      Exit;
    end;
    GLogWriter := TLogWriter.Create(ALogFile, AUseConsole, ALogLevel);
  finally
    GLogLock.Leave;
  end;
end;

procedure AmiLog(const Level: TAMILogLevel; const Msg: string);
var
  Item: TLogItem;
  TmpWriter: TLogWriter;
begin
  if GLogLock = nil then
    GLogLock := TCriticalSection.Create;

  GLogLock.Enter;
  try
    if not Assigned(GLogWriter) then
      GLogWriter := TLogWriter.Create('', False, llInfo);
    TmpWriter := GLogWriter;
  finally
    GLogLock.Leave;
  end;

  if not Assigned(TmpWriter) then Exit;
  if Level < TmpWriter.LogLevel then Exit;

  Item.Level := Level;
  Item.Msg := Msg;
  Item.Timestamp := Now;
  Item.ThreadID := TThread.CurrentThread.ThreadID;
  try
    TmpWriter.Enqueue(Item);
  except
  end;
end;

procedure AmiLog(const Msg: string);
begin
  AmiLog(llInfo, Msg);
end;

procedure AmiLogFlush;
var
  TmpWriter: TLogWriter;
begin
  if GLogLock = nil then
    GLogLock := TCriticalSection.Create;

  GLogLock.Enter;
  try
    TmpWriter := GLogWriter;
  finally
    GLogLock.Leave;
  end;

  if Assigned(TmpWriter) then
    TmpWriter.Flush;
end;

procedure AmiLogShutdown;
var
  Tmp: TLogWriter;
begin
  if GLogLock = nil then
    GLogLock := TCriticalSection.Create;

  GLogLock.Enter;
  try
    Tmp := GLogWriter;
    GLogWriter := nil;
  finally
    GLogLock.Leave;
  end;

  if Assigned(Tmp) then
  begin
    Tmp.Shutdown;
    Tmp.Free;
  end;
end;

{==============================================================================}
{=== TLogWriter =============================================================}
{==============================================================================}

constructor TLogWriter.Create(const ALogFile: string; AUseConsole: boolean;
  ALogLevel: TAMILogLevel);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FQueue := specialize TList<TLogItem>.Create;
  FLock := TCriticalSection.Create;
  FEvent := TSimpleEvent.Create;
  FLogFile := ALogFile;
  FUseConsole := AUseConsole;
  FLogLevel := ALogLevel;
  FTerminating := False;
end;

destructor TLogWriter.Destroy;
begin
  FTerminating := True;
  if Assigned(FEvent) then
    FEvent.SetEvent;
  WaitFor;
  FreeAndNil(FEvent);
  FreeAndNil(FLock);
  FreeAndNil(FQueue);
  inherited Destroy;
end;

procedure TLogWriter.Enqueue(const Item: TLogItem);
begin
  FLock.Enter;
  try
    FQueue.Add(Item);
    FEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;

procedure TLogWriter.Flush;
var
  locallist: specialize TList<TLogItem>;
  i: integer;
begin
  locallist := specialize TList<TLogItem>.Create;
  try
    FLock.Enter;
    try
      for i := 0 to FQueue.Count - 1 do
        locallist.Add(FQueue[i]);
      FQueue.Clear;
    finally
      FLock.Leave;
    end;

    for i := 0 to locallist.Count - 1 do
      WriteOne(locallist[i]);
  finally
    locallist.Free;
  end;
end;

procedure TLogWriter.Shutdown;
begin
  FTerminating := True;
  if Assigned(FEvent) then
    FEvent.SetEvent;
  WaitFor;
end;

procedure TLogWriter.WriteOne(const Item: TLogItem);
var
  Line: string;
  slevel: string;
  fs: TFileStream;
  Data: rawbytestring;
begin
  case Item.Level of
    llDebug: slevel := 'DEBUG';
    llInfo: slevel := 'INFO';
    llWarning: slevel := 'WARN';
    llError: slevel := 'ERROR';
    llCritical: slevel := 'CRIT';
  else
    slevel := 'INFO';
  end;

  Line := Format('[%s] [%s] [%d] %s%s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Item.Timestamp),
    PadLeft(slevel,5), Item.ThreadID, Item.Msg, LineEnding]);

  if FUseConsole and not FTerminating then
  begin
    try
      Write(Line);
    except
    end;
  end;

  if (FLogFile <> '') and (not FTerminating) then
  begin
    try
      if not FileExists(FLogFile) then
        fs := TFileStream.Create(FLogFile, fmCreate or fmShareDenyWrite)
      else
        fs := TFileStream.Create(FLogFile, fmOpenReadWrite or fmShareDenyWrite);
    except
      fs := nil;
    end;

    if Assigned(fs) then
    begin
      try
        fs.Seek(0, soFromEnd);
        Data := rawbytestring(Line);
        fs.WriteBuffer(Data[1], Length(Data));
      finally
        fs.Free;
      end;
    end;
  end;
end;

procedure TLogWriter.Execute;
var
  waitres: TWaitResult;
  locallist: specialize TList<TLogItem>;
  i: integer;
begin
  while not Terminated and not FTerminating do
  begin
    waitres := FEvent.WaitFor(1000);
    if (waitres = wrSignaled) then
    begin
      locallist := specialize TList<TLogItem>.Create;
      try
        FLock.Enter;
        try
          for i := 0 to FQueue.Count - 1 do
            locallist.Add(FQueue[i]);
          FQueue.Clear;
        finally
          FLock.Leave;
        end;

        for i := 0 to locallist.Count - 1 do
          WriteOne(locallist[i]);
      finally
        locallist.Free;
      end;
    end;
  end;
  Flush;
end;

initialization
  GLogLock := TCriticalSection.Create;

finalization
  AmiLogShutdown;
  FreeAndNil(GLogLock);

end.
