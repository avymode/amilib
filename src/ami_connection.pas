unit ami_connection;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, syncobjs, blcksock, synsock, ssl_openssl3, TypInfo,
  ami_types, ami_parser, Math, DateUtils, ami_enums, ami_log;

type
  TAMITransport = class
  private
    FSock: TTCPBlockSocket;
    FConfig: TAMIClientConfig;
    FConnected: Boolean;
    FLastError: String;
    FConnectionLock: TCriticalSection;
    FBytesReceived: Int64;
    FBytesSent: Int64;
    FLastActivity: TDateTime;
    FConnectionTime: TDateTime;
    FOnLog: TAMILogEvent;

    procedure SetConnected(AValue: Boolean);
    procedure UpdateActivity;
    function ConfigureSocket: Boolean;
    procedure DoLog(const Msg: String; Level: TAMILogLevel);

  public
    constructor Create(const AConfig: TAMIClientConfig);
    destructor Destroy; override;

    function Connect: Boolean;
    procedure Disconnect;
    function IsAlive: Boolean;

    function SendData(const AData: RawByteString): Boolean;
    function ReceiveData(ATimeout: Integer = 100): RawByteString;
    function ReceiveMessage(ATimeout: Integer = 100): TAMIMessage;

    function GetConnectionDuration: Integer;
    function GetBytesPerSecond: Double;

    property Connected: Boolean read FConnected;
    property LastError: String read FLastError;
    property BytesReceived: Int64 read FBytesReceived;
    property BytesSent: Int64 read FBytesSent;
    property LastActivity: TDateTime read FLastActivity;
    property Sock: TTCPBlockSocket read FSock;
    property Config: TAMIClientConfig read FConfig;
    property OnLog: TAMILogEvent read FOnLog write FOnLog;
  end;

  TAMIPacketReader = class
  private
    FTransport: TAMITransport;
    FReaderThread: TThread;
    FStopEvent: TSimpleEvent;
    FMessageQueue: TThreadList;
    FPriorityQueue: TThreadList;
    FActive: Boolean;
    FMessagesProcessed: Int64;
    FLastMessageTime: TDateTime;

    FOnMessageReceived: TNotifyEvent;
    FOnDisconnected: TNotifyEvent;
    FOnLog: TAMILogEvent;
    FOnHighPriorityMessage: TNotifyEvent;

    procedure ProcessMessage(AMessage: TAMIMessage);
  public
    constructor Create(ATransport: TAMITransport);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
    function GetNextMessage: TAMIMessage;
    function GetNextPriorityMessage: TAMIMessage;
    function HasMessages: Boolean;
    function HasPriorityMessages: Boolean;

    property MessagesProcessed: Int64 read FMessagesProcessed;
    property LastMessageTime: TDateTime read FLastMessageTime;

    property OnMessageReceived: TNotifyEvent read FOnMessageReceived write FOnMessageReceived;
    property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;
    property OnLog: TAMILogEvent read FOnLog write FOnLog;
    property OnHighPriorityMessage: TNotifyEvent read FOnHighPriorityMessage write FOnHighPriorityMessage;
    property MessageQueue: TThreadList read FMessageQueue;
  end;

  TReaderThread = class(TThread)
  private
    FOwner: TAMIPacketReader;
    FTransport: TAMITransport;
    FReader: TAMIReader;
    FLastError: String;
    FMessagesRead: Int64;

    procedure DoLog(const AMsg: String; ALevel: TAMILogLevel = llInfo);
    procedure DoDisconnected;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TAMIPacketReader; ATransport: TAMITransport);
    destructor Destroy; override;

    property MessagesRead: Int64 read FMessagesRead;
  end;

  TBytes = array of Byte;

implementation

{==============================================================================}
{=== TAMITransport ===========================================================}
{==============================================================================}

constructor TAMITransport.Create(const AConfig: TAMIClientConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FSock := TTCPBlockSocket.Create;
  FConnected := False;
  FLastError := '';
  FConnectionLock := TCriticalSection.Create;
  FBytesReceived := 0;
  FBytesSent := 0;
  FLastActivity := Now;
  FConnectionTime := 0;

  ConfigureSocket;
end;

destructor TAMITransport.Destroy;
begin
  Disconnect;
  FreeAndNil(FSock);
  FreeAndNil(FConnectionLock);
  inherited Destroy;
end;

function TAMITransport.ConfigureSocket: Boolean;
begin
  Result := True;
  try
    if FConfig.UseIPv6 then
      FSock.Family := SF_IP6
    else
      FSock.Family := SF_IP4;
    FSock.ConvertLineEnd := True;
    FSock.HeartbeatRate := 0;
    FSock.SetTimeout(FConfig.ConnectionTimeout);

    FSock.SetLinger(True, 0);
    FSock.TTL := 64;

    if FConfig.BufferSize > 0 then
    begin
      FSock.SizeRecvBuffer := FConfig.BufferSize;
      FSock.SizeSendBuffer := FConfig.BufferSize;
    end;

    if FConfig.UseTLS then
    begin
      FSock.SSL.VerifyCert := FConfig.VerifyCertificate;
      if FConfig.TLSVersion <> '' then
      begin
        if SameText(FConfig.TLSVersion, '1.3') then
          FSock.SSL.SSLType := LT_TLSv1_3
        else if SameText(FConfig.TLSVersion, '1.2') then
          FSock.SSL.SSLType := LT_TLSv1_2
        else if SameText(FConfig.TLSVersion, '1.1') then
          FSock.SSL.SSLType := LT_TLSv1_1
        else if SameText(FConfig.TLSVersion, '1.0') then
          FSock.SSL.SSLType := LT_TLSv1
        else if SameText(FConfig.TLSVersion, '3') then
          FSock.SSL.SSLType := LT_SSLv3
        else if SameText(FConfig.TLSVersion, '2') then
          FSock.SSL.SSLType := LT_SSLv2
        else if SameText(FConfig.TLSVersion, 'ssh2') then
          FSock.SSL.SSLType := LT_SSHv2
        else
          FSock.SSL.SSLType := LT_all;
      end
      else
      begin
        FSock.SSL.SSLType := LT_all;
      end;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Socket configuration failed: ' + E.Message;
      Result := False;
    end;
  end;
end;

procedure TAMITransport.SetConnected(AValue: Boolean);
begin
  FConnectionLock.Enter;
  try
    if FConnected <> AValue then
    begin
      FConnected := AValue;
      if AValue then
        FConnectionTime := Now
      else
        FConnectionTime := 0;
    end;
  finally
    FConnectionLock.Leave;
  end;
end;

procedure TAMITransport.UpdateActivity;
begin
  FLastActivity := Now;
end;

function TAMITransport.Connect: Boolean;
begin
  Result := False;
  FConnectionLock.Enter;
  try
    if FConnected then
      Exit(True);

    FLastError := '';

    try
      if FSock.Socket <> INVALID_SOCKET then
        FSock.CloseSocket;

      FSock.Connect(FConfig.Host, IntToStr(FConfig.Port));

      if FSock.LastError = 0 then
      begin
        if FConfig.UseTLS then
        begin
          FSock.SSLDoConnect;
          if FSock.LastError <> 0 then
          begin
            FLastError := 'SSL connection failed: ' + FSock.LastErrorDesc;
            FSock.CloseSocket;
            Exit;
          end;
        end;

        SetConnected(True);
        UpdateActivity;
        Result := True;
        FLastError := '';
      end
      else
      begin
        FLastError := 'Connection failed: ' + FSock.LastErrorDesc;
        SetConnected(False);
      end;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        SetConnected(False);
      end;
    end;
  finally
    FConnectionLock.Leave;
  end;
end;

procedure TAMITransport.Disconnect;
begin
  FConnectionLock.Enter;
  try
    SetConnected(False);
    if FSock.Socket <> INVALID_SOCKET then
      FSock.CloseSocket;
  finally
    FConnectionLock.Leave;
  end;
end;

function TAMITransport.IsAlive: Boolean;
var
  TimeSinceActivity: Double;
begin
  FConnectionLock.Enter;
  try
    Result := FConnected;
    if Result and (FConfig.PingInterval > 0) then
    begin
      TimeSinceActivity := (Now - FLastActivity) * 24 * 60 * 60;
      Result := TimeSinceActivity < (FConfig.PingInterval * 2);
    end;
  finally
    FConnectionLock.Leave;
  end;
end;

function TAMITransport.SendData(const AData: RawByteString): Boolean;
var
  IsConnected: Boolean;
begin
  Result := False;

  FConnectionLock.Enter;
  try
    IsConnected := FConnected;
  finally
    FConnectionLock.Leave;
  end;

  if not IsConnected then
  begin
    FLastError := 'Not connected';
    Exit;
  end;

  if not Assigned(FSock) then
  begin
    FLastError := 'Socket not assigned';
    SetConnected(False);
    Exit;
  end;

  if FSock.Socket = INVALID_SOCKET then
  begin
    FLastError := 'Socket is invalid';
    SetConnected(False);
    Exit;
  end;

  try
    FSock.SendString(String(AData));

    if FSock.LastError = 0 then
    begin
      FConnectionLock.Enter;
      try
        Inc(FBytesSent, Length(AData));
        UpdateActivity;
        Result := True;
        FLastError := '';
      finally
        FConnectionLock.Leave;
      end;
    end
    else
    begin
      FLastError := Format('Send failed (Error %d): %s',
                          [FSock.LastError, FSock.LastErrorDesc]);
      DoLog(FLastError, llError);
      SetConnected(False);
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Send exception: ' + E.Message;
      DoLog(FLastError, llError);
      SetConnected(False);
    end;
  end;
end;

function TAMITransport.ReceiveData(ATimeout: Integer): RawByteString;
var
  Buf: array[0..4095] of Byte;
  BytesRead: Integer;
  IsConnected: Boolean;
begin
  Result := '';

  FConnectionLock.Enter;
  try
    IsConnected := FConnected;
  finally
    FConnectionLock.Leave;
  end;

  if not IsConnected then
  begin
    FLastError := 'Not connected';
    Exit;
  end;

  try
    FSock.SetTimeout(ATimeout);
    if FSock.CanRead(ATimeout) then
    begin
      BytesRead := FSock.RecvBuffer(@Buf[0], SizeOf(Buf));
      if BytesRead > 0 then
      begin
        SetLength(Result, BytesRead);
        Move(Buf[0], Result[1], BytesRead);

        FConnectionLock.Enter;
        try
          Inc(FBytesReceived, BytesRead);
          UpdateActivity;
          FLastError := '';
        finally
          FConnectionLock.Leave;
        end;
      end
      else if FSock.LastError <> 0 then
      begin
        FLastError := 'Receive failed: ' + FSock.LastErrorDesc;
        SetConnected(False);
      end;
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      SetConnected(False);
    end;
  end;
end;

function TAMITransport.ReceiveMessage(ATimeout: Integer): TAMIMessage;
var
  Buffer: TAMIBuffer;
  Reader: TAMIReader;
  Data: RawByteString;
  StartTime: TDateTime;
  HasCompleteMessage: Boolean;
begin
  Result := nil;
  StartTime := Now;
  HasCompleteMessage := False;

  if not FConnected then
  begin
    FLastError := 'Not connected';
    Exit;
  end;

  try
    Buffer := TAMIBuffer.Create(8192);
    try
      while (MilliSecondsBetween(Now, StartTime) < ATimeout) and not HasCompleteMessage do
      begin
        Data := ReceiveData(Min(ATimeout div 10, 50));

        if Length(Data) > 0 then
        begin
          Buffer.Append(@Data[1], Length(Data));
          HasCompleteMessage := Buffer.HasCompleteMessage;
        end
        else if FSock.LastError <> WSAETIMEDOUT then
          Break;
      end;

      if HasCompleteMessage and (Buffer.Size > 0) then
      begin
        Reader := TAMIReader.Create(Buffer);

        try
          Result := Reader.ReadMessage;
        finally
          Reader.Free;
        end;
      end;
    finally
      Buffer.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      SetConnected(False);
    end;
  end;
end;

function TAMITransport.GetConnectionDuration: Integer;
begin
  FConnectionLock.Enter;
  try
    if FConnected and (FConnectionTime > 0) then
      Result := SecondsBetween(Now, FConnectionTime)
    else
      Result := 0;
  finally
    FConnectionLock.Leave;
  end;
end;

function TAMITransport.GetBytesPerSecond: Double;
var
  Duration: Integer;
begin
  Duration := GetConnectionDuration;
  if Duration > 0 then
    Result := (FBytesReceived + FBytesSent) / Duration
  else
    Result := 0;
end;

procedure TAMITransport.DoLog(const Msg: String; Level: TAMILogLevel);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, Level, Msg);
end;

{==============================================================================}
{=== TAMIPacketReader ========================================================}
{==============================================================================}

constructor TAMIPacketReader.Create(ATransport: TAMITransport);
begin
  inherited Create;
  FTransport := ATransport;
  FStopEvent := TSimpleEvent.Create;
  FMessageQueue := TThreadList.Create;
  FPriorityQueue := TThreadList.Create;
  FActive := False;
  FMessagesProcessed := 0;
  FLastMessageTime := 0;
end;

destructor TAMIPacketReader.Destroy;
var
  List: TList;
  i: Integer;
begin
  Stop;

  List := FMessageQueue.LockList;
  try
    for i := 0 to List.Count - 1 do
      TAMIMessage(List[i]).Free;
    List.Clear;
  finally
    FMessageQueue.UnlockList;
  end;
  FreeAndNil(FMessageQueue);

  List := FPriorityQueue.LockList;
  try
    for i := 0 to List.Count - 1 do
      TAMIMessage(List[i]).Free;
    List.Clear;
  finally
    FPriorityQueue.UnlockList;
  end;
  FreeAndNil(FPriorityQueue);

  FreeAndNil(FStopEvent);
  inherited Destroy;
end;

procedure TAMIPacketReader.Start;
begin
  if not FActive then
  begin
    FActive := True;
    FStopEvent.ResetEvent;
    FReaderThread := TReaderThread.Create(Self, FTransport);
  end;
end;

procedure TAMIPacketReader.Stop;
var
  StartTime: TDateTime;
  TimeoutMs: Integer;
begin
  if FActive then
  begin
    FActive := False;
    FStopEvent.SetEvent;

    if Assigned(FReaderThread) then
    begin
      FReaderThread.Terminate;

      TimeoutMs := 5000;
      StartTime := Now;

      while not FReaderThread.Finished and (MilliSecondsBetween(Now, StartTime) < TimeoutMs) do
        Sleep(10);

      try
        if not FReaderThread.Finished then
          FReaderThread.WaitFor;
      except
      end;

      FreeAndNil(FReaderThread);
    end;
  end;
end;

procedure TAMIPacketReader.ProcessMessage(AMessage: TAMIMessage);
var
  EventType: TAMIEventType;
  Priority: Integer;
  List: TList;
  MessageHandled: Boolean;
begin
  MessageHandled := False;

  if not Assigned(AMessage) then
    Exit;

  if not FActive then
  begin
    AMessage.Free;
    Exit;
  end;

  try
    Inc(FMessagesProcessed);
    FLastMessageTime := Now;

    if AMessage is TAMIEvent then
    begin
      EventType := TAMIEvent(AMessage).EventType;
      Priority := TAMIEventParser.GetEventPriority(EventType);

      if Priority >= 80 then
      begin
        List := FPriorityQueue.LockList;
        try
          List.Add(AMessage);
          MessageHandled := True;
        finally
          FPriorityQueue.UnlockList;
        end;

        if MessageHandled and Assigned(FOnHighPriorityMessage) then
          FOnHighPriorityMessage(Self);

        Exit;
      end;
    end;

    if not MessageHandled then
    begin
      List := FMessageQueue.LockList;
      try
        List.Add(AMessage);
        MessageHandled := True;
      finally
        FMessageQueue.UnlockList;
      end;

      if MessageHandled and Assigned(FOnMessageReceived) then
        FOnMessageReceived(Self);
    end;
  finally
    if not MessageHandled then
      AMessage.Free;
  end;
end;

function TAMIPacketReader.GetNextMessage: TAMIMessage;
var
  List: TList;
begin
  Result := nil;
  List := FMessageQueue.LockList;
  try
    if List.Count > 0 then
    begin
      Result := TAMIMessage(List[0]);
      List.Delete(0);
    end;
  finally
    FMessageQueue.UnlockList;
  end;
end;

function TAMIPacketReader.GetNextPriorityMessage: TAMIMessage;
var
  List: TList;
begin
  Result := nil;
  List := FPriorityQueue.LockList;
  try
    if List.Count > 0 then
    begin
      Result := TAMIMessage(List[0]);
      List.Delete(0);
    end;
  finally
    FPriorityQueue.UnlockList;
  end;
end;

function TAMIPacketReader.HasMessages: Boolean;
var
  List: TList;
begin
  List := FMessageQueue.LockList;
  try
    Result := List.Count > 0;
  finally
    FMessageQueue.UnlockList;
  end;
end;

function TAMIPacketReader.HasPriorityMessages: Boolean;
var
  List: TList;
begin
  List := FPriorityQueue.LockList;
  try
    Result := List.Count > 0;
  finally
    FPriorityQueue.UnlockList;
  end;
end;

{==============================================================================}
{=== TReaderThread ===========================================================}
{==============================================================================}

constructor TReaderThread.Create(AOwner: TAMIPacketReader; ATransport: TAMITransport);
begin
  inherited Create(False);
  FOwner := AOwner;
  FTransport := ATransport;
  FReader := nil;
  FLastError := '';
  FMessagesRead := 0;
  FreeOnTerminate := False;
end;

destructor TReaderThread.Destroy;
begin
  FreeAndNil(FReader);
  inherited Destroy;
end;

procedure TReaderThread.DoLog(const AMsg: String; ALevel: TAMILogLevel);
begin
  if Assigned(FOwner) and Assigned(FOwner.FOnLog) then
    FOwner.FOnLog(FOwner, ALevel, AMsg);
end;

procedure TReaderThread.DoDisconnected;
begin
  if Assigned(FOwner) and Assigned(FOwner.FOnDisconnected) then
    FOwner.FOnDisconnected(FOwner);
end;

procedure TReaderThread.Execute;
var
  Buffer: TAMIBuffer;
  Reader: TAMIReader;
  Sock: TTCPBlockSocket;
  Bytes: TBytes;
  BytesRead: Integer;
  Message: TAMIMessage;
  LocalTransport: TAMITransport;
begin
  DoLog('Reader thread started', llDebug);

  Buffer := TAMIBuffer.Create(65536);
  Reader := TAMIReader.Create(Buffer, FTransport.Config);
  try
    while not Terminated do
    begin
      LocalTransport := FTransport;
      if not Assigned(LocalTransport) then
        Break;

      if not LocalTransport.Connected then
      begin
        Sleep(100);
        Continue;
      end;

      Sock := LocalTransport.Sock;
      if not Assigned(Sock) or Terminated then
        Break;

      if Sock.CanRead(500) then
      begin
        Bytes := Default(TBytes);
        SetLength(Bytes, 4096);
        BytesRead := Sock.RecvBuffer(@Bytes[0], Length(Bytes));

        if BytesRead > 0 then
        begin
          Buffer.Append(@Bytes[0], BytesRead);

          if Assigned(FOwner) then
          begin
            FOwner.FTransport.FConnectionLock.Enter;
            try
              Inc(FOwner.FTransport.FBytesReceived, BytesRead);
            finally
              FOwner.FTransport.FConnectionLock.Leave;
            end;
          end;

          while not Terminated and Buffer.HasCompleteMessage do
          begin
            Message := Reader.ReadMessage;
            if Assigned(Message) then
            begin
              Inc(FMessagesRead);

              if Assigned(FOwner) and not Terminated then
                FOwner.ProcessMessage(Message)
              else
                Message.Free;
            end;
          end;
        end
        else
        begin
          if (Sock.LastError <> 0) and (Sock.LastError <> WSAETIMEDOUT) then
          begin
            DoLog(Format('Socket error %d: %s', [Sock.LastError, Sock.LastErrorDesc]), llError);
            Break;
          end;
        end;
      end;
    end;
  finally
    FreeAndNil(Reader);
    FreeAndNil(Buffer);
  end;

  if Assigned(FOwner) and not Terminated then
    DoDisconnected;

  DoLog('Reader thread finished', llDebug);
end;

end.
