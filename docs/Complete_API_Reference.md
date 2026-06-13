# 📖 AMI Library - Complete API Reference

## Table of Contents

1. [Core Module: ami_types.pas](#1-ami_typespas)
2. [Client Module: ami_client.pas](#2-ami_clientpas)
3. [Actions Module: ami_actions.pas](#3-ami_actionspas)
4. [Events Module: ami_events.pas](#4-ami_eventspas)
5. [Parser Module: ami_parser.pas](#5-ami_parserpas)

---

# 1. ami_types.pas

## Overview
Foundation module providing base types, exceptions, and data structures for AMI protocol.

## Core Types

### TAMIMessage
**Base class for all AMI protocol messages**

```pascal
type
  TAMIMessage = class(TObject)
  private
    FFields: TStringList;
    FMessageType: TAMIMessageType;
    FActionID: String;
    FTimestamp: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;

    // Field management
    procedure AddField(const AKey, AValue: String);
    function GetField(const AKey: String): String;
    function HasField(const AKey: String): Boolean;
    function FieldCount: Integer;
    function GetFieldName(Index: Integer): String;
    function GetFieldValue(Index: Integer): String;

    // Serialization
    procedure UpdateFromFields; virtual;
    procedure Assign(Source: TAMIMessage);
    function ToString: String; override;

    property MessageType: TAMIMessageType read FMessageType write FMessageType;
    property ActionID: String read FActionID write FActionID;
    property Fields: TStringList read FFields;
    property Timestamp: TDateTime read FTimestamp;
  end;
```

#### Methods

##### AddField
```pascal
procedure AddField(const AKey, AValue: String);
```
**Description**: Adds a key-value pair to the message.

**Parameters**:
- `AKey`: Field name (case-insensitive)
- `AValue`: Field value

**Example**:
```pascal
Message.AddField('Channel', 'SIP/1001-00000001');
Message.AddField('CallerIDNum', '1001');
```

**Notes**:
- Duplicate keys are allowed (for multi-value fields)
- Keys are stored with original case but retrieved case-insensitively
- Special handling for 'ActionID' field (updates `FActionID` property)

---

##### GetField
```pascal
function GetField(const AKey: String): String;
```
**Description**: Retrieves the first value for a given field name.

**Parameters**:
- `AKey`: Field name (case-insensitive)

**Returns**: Field value, or empty string if not found

**Example**:
```pascal
Channel := Message.GetField('Channel');
CallerID := Message.GetField('CallerIDNum');

if Message.GetField('Response') = 'Success' then
  WriteLn('Action succeeded');
```

**Notes**:
- For multi-value fields (e.g., 'Output' in Command response), returns only first value
- Use iteration for multi-value fields:
```pascal
for i := 0 to Message.FieldCount - 1 do
begin
  if SameText(Message.GetFieldName(i), 'Output') then
    WriteLn(Message.GetFieldValue(i));
end;
```

---

##### HasField
```pascal
function HasField(const AKey: String): Boolean;
```
**Description**: Checks if a field exists in the message.

**Parameters**:
- `AKey`: Field name (case-insensitive)

**Returns**: True if field exists, False otherwise

**Example**:
```pascal
if Message.HasField('UniqueID') then
  UniqueID := Message.GetField('UniqueID')
else
  UniqueID := '';
```

---

##### UpdateFromFields
```pascal
procedure UpdateFromFields; virtual;
```
**Description**: Parses fields and updates object properties (called automatically by parser).

**Override in descendants**:
```pascal
type
  TAMIResponse = class(TAMIMessage)
  public
    procedure UpdateFromFields; override;
  end;

procedure TAMIResponse.UpdateFromFields;
begin
  inherited;
  FResponse := GetField('Response');
  FMessage := GetField('Message');
  FSuccess := SameText(Trim(FResponse), 'Success');
end;
```

---

### TAMIAction
**Base class for AMI actions (requests sent to Asterisk)**

```pascal
type
  TAMIAction = class(TAMIMessage)
  private
    FActionName: String;
  public
    constructor Create; overload;
    constructor Create(const AActionName: String); overload;
    
    property ActionName: String read FActionName write FActionName;
  end;
```

#### Constructors

##### Create (parameterless)
```pascal
constructor Create;
```
**Description**: Creates empty action (must set ActionName manually).

**Example**:
```pascal
Action := TAMIAction.Create;
try
  Action.ActionName := 'Ping';
  Action.AddField('Action', 'Ping');
  Response := Client.SendAction(Action);
finally
  Action.Free;
end;
```

**Use case**: Dynamic action creation

---

##### Create (with name)
```pascal
constructor Create(const AActionName: String);
```
**Description**: Creates action with specified name (automatically adds 'Action' field).

**Parameters**:
- `AActionName`: Action name (e.g., 'Ping', 'Originate', 'QueueStatus')

**Example**:
```pascal
Action := TAMIAction.Create('Ping');
try
  // 'Action: Ping' field already added
  Response := Client.SendAction(Action);
finally
  Action.Free;
end;
```

**Recommended**: Use predefined action classes (TAMIPingAction, etc.) instead of manual creation

---

### TAMIResponse
**Response from Asterisk to an action**

```pascal
type
  TAMIResponse = class(TAMIMessage)
  private
    FResponse: String;       // 'Success' | 'Error' | 'Follows'
    FMessage: String;        // Human-readable message
    FSuccess: Boolean;       // Computed from FResponse
  public
    constructor Create;
    procedure UpdateFromFields; override;
    function IsSuccess: Boolean;
    procedure Assign(Source: TAMIMessage);

    property Response: String read FResponse write FResponse;
    property Message: String read FMessage write FMessage;
    property Success: Boolean read FSuccess;
  end;
```

#### Methods

##### IsSuccess
```pascal
function IsSuccess: Boolean;
```
**Description**: Checks if the action was successful.

**Returns**: True if Response = 'Success' or 'Follows'

**Example**:
```pascal
Response := Client.Ping(5000);
if Assigned(Response) then
try
  if Response.IsSuccess then
    WriteLn('Ping successful: ', Response.Message)
  else
    WriteLn('Ping failed: ', Response.Message);
finally
  Response.Free;
end;
```

**Response Values**:
- `'Success'` - Action completed successfully
- `'Follows'` - Multi-line response follows (Command action)
- `'Error'` - Action failed

---

### TAMICommandResponse
**Special response for CLI Command action with multi-line output**

```pascal
type
  TAMICommandResponse = class(TAMIResponse)
  private
    FOutputLines: TStringList;
    FCommandOutput: String;
  public
    constructor Create;
    destructor Destroy; override;
    procedure UpdateFromFields; override;
    function GetFullOutput: String;
    function GetOutputLineCount: Integer;

    property OutputLines: TStringList read FOutputLines;
    property CommandOutput: String read FCommandOutput;
  end;
```

#### Methods

##### GetFullOutput
```pascal
function GetFullOutput: String;
```
**Description**: Returns complete command output as single string.

**Returns**: All output lines joined with CRLF

**Example**:
```pascal
Response := Client.Command('core show channels');
if Assigned(Response) and (Response is TAMICommandResponse) then
try
  CmdResp := TAMICommandResponse(Response);
  WriteLn(CmdResp.GetFullOutput);
  WriteLn('Total lines: ', CmdResp.GetOutputLineCount);
finally
  Response.Free;
end;
```

**Output format**:
```
Channel              Location             State   Application(Data)
SIP/1001-00000001    100@default:1        Up      Dial(SIP/1002,30)
SIP/1002-00000002    s@macro-dial:5       Ringing AppDial((Outgoing Line))
2 active channels
```

---

##### GetOutputLineCount
```pascal
function GetOutputLineCount: Integer;
```
**Description**: Returns number of output lines.

**Returns**: Line count

**Example**:
```pascal
if CmdResp.GetOutputLineCount > 0 then
begin
  for i := 0 to CmdResp.OutputLines.Count - 1 do
    Memo.Lines.Add(CmdResp.OutputLines[i]);
end;
```

---

### TAMIEvent
**Asynchronous event from Asterisk**

```pascal
type
  TAMIEvent = class(TAMIMessage)
  private
    FEventName: String;
    FEventType: TAMIEventType;
  public
    constructor Create;
    function GetEventName: String;
    procedure UpdateFromFields; override;

    property EventName: String read FEventName write FEventName;
    property EventType: TAMIEventType read FEventType;
  end;
```

#### Methods

##### GetEventName
```pascal
function GetEventName: String;
```
**Description**: Returns event name (from 'Event' field).

**Returns**: Event name (e.g., 'Newchannel', 'Hangup', 'QueueMemberAdded')

**Example**:
```pascal
procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
begin
  case Event.EventType of
    etNewchannel:
      WriteLn('New channel: ', Event.GetField('Channel'));
    etHangup:
      WriteLn('Hangup: ', Event.GetField('Channel'), 
              ' Cause: ', Event.GetField('Cause'));
  end;
end;
```

---

## Configuration Types

### TAMIClientConfig
**Complete client configuration**

```pascal
type
  TAMIClientConfig = record
    // Connection settings
    Host: String;
    Port: Word;
    Username: String;
    Password: String;
    AuthType: String;              // 'plain' | 'md5'

    // TLS settings
    UseTLS: Boolean;
    TLSVersion: String;            // '1.0' | '1.1' | '1.2' | '1.3'
    VerifyCertificate: Boolean;

    // Timeout settings (milliseconds)
    ConnectionTimeout: Integer;    // Default: 10000
    ResponseTimeout: Integer;      // Default: 30000
    ReadTimeout: Integer;
    WriteTimeout: Integer;

    // Reconnection settings
    ReconnectInterval: Integer;    // Default: 5000
    MaxReconnectAttempts: Integer; // Default: 0 (infinite)
    ReconnectBackoff: Boolean;     // Default: True

    // Keep-alive settings
    PingInterval: Integer;         // Default: 30 (seconds)
    PingTimeout: Integer;          // Default: 10 (seconds)

    // Protocol settings
    UTF8Enabled: Boolean;
    EventMask: String;             // 'on' | 'off' | 'system,call,log'
    BufferSize: Integer;           // Default: 8192
    EnableCompression: Boolean;
    MaxConcurrentActions: Integer;
    UseJSON: Boolean;              // Asterisk 18+ only

    // Logging
    OnLog: TAMILogEvent;
  end;
```

#### Configuration Examples

##### Basic Configuration
```pascal
var
  Config: TAMIClientConfig;
begin
  Config := Default(TAMIClientConfig);
  Config.Host := 'localhost';
  Config.Port := 5038;
  Config.Username := 'admin';
  Config.Password := 'secret';
  Config.AuthType := 'plain';
  
  // Use defaults for other settings
end;
```

##### Production Configuration with TLS
```pascal
Config := Default(TAMIClientConfig);
Config.Host := 'pbx.example.com';
Config.Port := 5039;
Config.Username := 'api_user';
Config.Password := 'StrongP@ssw0rd';
Config.AuthType := 'md5';

// TLS settings
Config.UseTLS := True;
Config.TLSVersion := '1.2';
Config.VerifyCertificate := True;

// Timeouts
Config.ConnectionTimeout := 15000;
Config.ResponseTimeout := 60000;

// Reconnection
Config.MaxReconnectAttempts := 10;
Config.ReconnectInterval := 5000;
Config.ReconnectBackoff := True;

// Keep-alive
Config.PingInterval := 60;
Config.PingTimeout := 15;

// Events
Config.EventMask := 'system,call,user';
```

##### High-Performance Configuration
```pascal
Config := Default(TAMIClientConfig);
// ... basic settings ...

// Optimize for throughput
Config.BufferSize := 65536;          // 64KB buffer
Config.ResponseTimeout := 5000;      // Fast timeout
Config.MaxConcurrentActions := 100;  // Allow many pending actions

// Disable reconnect for critical systems
Config.MaxReconnectAttempts := 0;    // Manual reconnect only

// Minimal keep-alive
Config.PingInterval := 120;          // 2 minutes
```

---

## Data Structures

### TOriginateParams
**Parameters for Originate action**

```pascal
type
  TOriginateParams = record
    // Required (choose one of two modes)
    Channel: String;          // Destination channel (e.g., 'SIP/1001')
    
    // Mode 1: Dialplan execution
    Context: String;          // Dialplan context
    Extension: String;        // Extension to execute
    Priority: String;         // Priority ('1' or label)
    
    // Mode 2: Application execution
    Application: String;      // Application name (e.g., 'Playback')
    Data: String;            // Application parameters
    
    // Optional parameters
    Timeout: Integer;         // Max wait time (ms), default: 30000
    CallerID: String;        // Caller ID presentation
    Account: String;         // CDR account code
    Async: Boolean;          // Return immediately (don't wait for answer)
    ActionID: String;        // Custom action ID
    EarlyMedia: Boolean;     // Enable early media
    Codecs: String;          // Preferred codecs (e.g., 'ulaw,alaw')
    Variables: TStringList;  // Channel variables
    ChannelId: String;       // Custom channel identifier
  end;
```

#### Usage Examples

##### Dialplan Mode
```pascal
var
  Params: TOriginateParams;
  Response: TAMIResponse;
begin
  Params := Default(TOriginateParams);
  Params.Channel := 'SIP/1001';
  Params.Context := 'from-internal';
  Params.Extension := '100';
  Params.Priority := '1';
  Params.CallerID := 'Test Call <5000>';
  Params.Timeout := 30000;
  Params.Async := True;
  
  Response := Client.Originate(Params, 60000);
  if Assigned(Response) then
  try
    if Response.IsSuccess then
      WriteLn('Call originated')
    else
      WriteLn('Failed: ', Response.Message);
  finally
    Response.Free;
  end;
end;
```

##### Application Mode
```pascal
Params := Default(TOriginateParams);
Params.Channel := 'SIP/1002';
Params.Application := 'Playback';
Params.Data := 'tt-monkeys';
Params.CallerID := 'System <9999>';
Params.Async := False;  // Wait for completion

Response := Client.Originate(Params, 60000);
```

##### With Channel Variables
```pascal
Params := Default(TOriginateParams);
Params.Channel := 'SIP/1001';
Params.Context := 'from-internal';
Params.Extension := '100';
Params.Priority := '1';

// Add custom variables
Params.Variables := TStringList.Create;
try
  Params.Variables.Add('CALL_TYPE=automated');
  Params.Variables.Add('CAMPAIGN_ID=12345');
  Params.Variables.Add('CUSTOMER_ID=67890');
  
  Response := Client.Originate(Params, 60000);
  // Handle response...
finally
  Params.Variables.Free;
end;
```

---

### TChannelInfo
**Parsed channel information from events**

```pascal
type
  TChannelInfo = record
    Channel: String;              // Channel name (e.g., 'SIP/1001-00000001')
    UniqueID: String;             // Unique channel identifier
    LinkedID: String;             // Call chain identifier
    CallerIDNum: String;          // Caller ID number
    CallerIDName: String;         // Caller ID name
    ConnectedLineNum: String;     // Connected line number
    ConnectedLineName: String;    // Connected line name
    State: String;                // Numeric state code
    StateDesc: String;            // Human-readable state
    Context: String;              // Current dialplan context
    Extension: String;            // Current extension
    Priority: String;             // Current priority
    AccountCode: String;          // CDR account code
    Duration: Integer;            // Call duration (seconds)
    BillableSeconds: Integer;     // Billable duration (seconds)
  end;
```

#### Usage Example

```pascal
procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  Info: TChannelInfo;
begin
  Info := TAMIEventParser.ParseChannelInfo(Event);
  
  WriteLn('New channel: ', Info.Channel);
  WriteLn('  Caller: ', Info.CallerIDName, ' <', Info.CallerIDNum, '>');
  WriteLn('  UniqueID: ', Info.UniqueID);
  WriteLn('  Context: ', Info.Context);
  WriteLn('  Extension: ', Info.Extension);
  WriteLn('  State: ', Info.StateDesc, ' (', Info.State, ')');
end;
```

---

### THangupInfo
**Parsed hangup information**

```pascal
type
  THangupInfo = record
    Channel: String;
    UniqueID: String;
    LinkedID: String;
    Cause: Integer;               // Q.850 cause code
    CauseTxt: String;            // Human-readable cause
    Duration: Integer;            // Total duration (seconds)
    BillableSeconds: Integer;     // Billable duration
  end;
```

#### Q.850 Cause Codes

| Code | Constant | Description |
|------|----------|-------------|
| 16 | Normal clearing | Normal call termination |
| 17 | User busy | Called party is busy |
| 18 | No user responding | No answer |
| 19 | No answer | Timeout waiting for answer |
| 21 | Call rejected | Called party rejected call |
| 34 | Circuit congestion | Network congestion |
| 127 | Interworking | Protocol error |

#### Usage Example

```pascal
procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
var
  Info: THangupInfo;
begin
  Info := TAMIEventParser.ParseHangupInfo(Event);
  
  WriteLn('Hangup: ', Info.Channel);
  WriteLn('  Cause: ', Info.Cause, ' - ', Info.CauseTxt);
  WriteLn('  Duration: ', Info.Duration, 's');
  WriteLn('  Billable: ', Info.BillableSeconds, 's');
  
  // Log to database
  LogCallToDatabase(Info.UniqueID, Info.Duration, Info.Cause);
end;
```

---

### TDialInfo
**Parsed dial information**

```pascal
type
  TDialInfo = record
    Channel: String;              // Originating channel
    Destination: String;          // Destination channel
    DestUniqueID: String;        // Destination unique ID
    CallerIDNum: String;
    CallerIDName: String;
    ConnectedLineNum: String;
    ConnectedLineName: String;
    DialStatus: String;          // 'ANSWER' | 'BUSY' | 'NOANSWER' | etc.
    Forward: String;             // Forwarding destination (if any)
    Forwarded: Boolean;          // Was call forwarded?
  end;
```

#### DialStatus Values

| Status | Description |
|--------|-------------|
| CHANUNAVAIL | Channel unavailable |
| CONGESTION | Network congestion |
| NOANSWER | No answer within timeout |
| BUSY | Destination busy |
| ANSWER | Call answered |
| CANCEL | Call cancelled |

#### Usage Example

```pascal
procedure OnDialEnd(Sender: TObject; const Event: TAMIEvent);
var
  Info: TDialInfo;
begin
  Info := TAMIEventParser.ParseDialInfo(Event);
  
  WriteLn('Dial completed: ', Info.Channel, ' -> ', Info.Destination);
  WriteLn('  Status: ', Info.DialStatus);
  
  if Info.Forwarded then
    WriteLn('  Forwarded to: ', Info.Forward);
  
  case Info.DialStatus of
    'ANSWER':
      WriteLn('  Call connected successfully');
    'BUSY':
      WriteLn('  Destination was busy');
    'NOANSWER':
      WriteLn('  No answer');
  end;
end;
```

---

## Exception Types

### EAMIException
**Base exception for all AMI errors**

```pascal
type
  EAMIException = class(Exception)
  public
    constructor Create(const AMsg: string; AErrorCode: Integer = 0);
  end;
```

**Descendants**:
- `EAMIConnectionException` - Connection/transport errors
- `EAMIAuthenticationException` - Authentication failures
- `EAMITimeoutException` - Timeout errors
- `EAMIProtocolException` - Protocol parsing errors
- `EAMIInvalidOperation` - Invalid operation errors

#### Usage Example

```pascal
try
  Response := Client.Ping(5000);
  if not Assigned(Response) then
    raise EAMITimeoutException.Create('Ping timeout');
    
  if not Response.IsSuccess then
    raise EAMIException.Create('Ping failed: ' + Response.Message);
finally
  if Assigned(Response) then
    Response.Free;
end;

except
  on E: EAMITimeoutException do
    WriteLn('Timeout error: ', E.Message);
  on E: EAMIConnectionException do
    WriteLn('Connection error: ', E.Message);
  on E: EAMIException do
    WriteLn('AMI error: ', E.Message);
end;
```

---

## Enumerations

### TAMILogLevel
```pascal
type
  TAMILogLevel = (
    llDebug,      // Verbose debugging information
    llInfo,       // Informational messages
    llWarning,    // Warning messages
    llError,      // Error messages
    llCritical    // Critical errors
  );
```

**Usage**:
```pascal
procedure OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
begin
  case Level of
    llDebug:    Exit; // Ignore debug in production
    llInfo:     WriteLn('[INFO] ', Msg);
    llWarning:  WriteLn('[WARN] ', Msg);
    llError:    WriteLn('[ERROR] ', Msg);
    llCritical: WriteLn('[CRITICAL] ', Msg);
  end;
end;
```

---

### TAMIMessageType
```pascal
type
  TAMIMessageType = (
    mtAction,     // Action (request)
    mtResponse,   // Response to action
    mtEvent,      // Asynchronous event
    mtWelcome     // Welcome message on connect
  );
```

---

### TAMIClientStatus
```pascal
type
  TAMIClientStatus = (
    csDisconnected,   // Not connected
    csConnecting,     // Connection in progress
    csConnected,      // Connected and authenticated
    csAuthenticating, // Authenticating
    csAuthFailed,     // Authentication failed
    csReconnecting    // Reconnection in progress
  );
```

**Usage**:
```pascal
case Client.Status of
  csDisconnected:
    StatusLabel.Caption := 'Disconnected';
  csConnecting:
    StatusLabel.Caption := 'Connecting...';
  csAuthenticating:
    StatusLabel.Caption := 'Authenticating...';
  csConnected:
    StatusLabel.Caption := 'Connected';
  csAuthFailed:
    StatusLabel.Caption := 'Authentication failed';
  csReconnecting:
    StatusLabel.Caption := 'Reconnecting...';
end;
```

---

### TAMIEventType
**Complete enumeration of 180+ AMI event types**

```pascal
type
  TAMIEventType = (
    etUnknown,
    
    // AGI Events
    etAGIExecEnd,
    etAGIExecStart,
    etAsyncAGIEnd,
    etAsyncAGIExec,
    etAsyncAGIStart,
    
    // Call Control Events
    etNewchannel,         // New channel created
    etHangup,             // Channel hungup
    etDialBegin,          // Dial started
    etDialEnd,            // Dial completed
    etNewstate,           // Channel state changed
    
    // Queue Events
    etQueueCallerJoin,    // Caller joined queue
    etQueueCallerLeave,   // Caller left queue
    etQueueMemberAdded,   // Member added to queue
    etQueueMemberRemoved, // Member removed from queue
    etQueueMemberPause,   // Member paused/unpaused
    etQueueMemberStatus,  // Member status update
    
    // Bridge Events
    etBridgeCreate,       // Bridge created
    etBridgeDestroy,      // Bridge destroyed
    etBridgeEnter,        // Channel entered bridge
    etBridgeLeave,        // Channel left bridge
    
    // System Events
    etFullyBooted,        // Asterisk fully booted
    etShutdown,           // Asterisk shutting down
    etReload,             // Configuration reloaded
    
    // ... and 160+ more event types
  );
```

**Priority Mapping**:
```pascal
// High priority events (>= 80)
etHangup            : 100
etNewchannel        : 100
etSoftHangupRequest : 100
etHangupRequest     : 100
etDialBegin         : 90
etDialEnd           : 90
etBridgeCreate      : 85
etBridgeEnter       : 85

// Medium priority (50-79)
etQueueCallerJoin   : 60
etQueueMemberAdded  : 55
etPeerStatus        : 50

// Low priority (< 50)
etVarSet            : 20
etUserEvent         : 20
```

---

# 2. ami_client.pas

## Overview
Main client class providing high-level AMI interface with automatic reconnection, keep-alive, and thread-safe operations.

## TAMIClient Class

```pascal
type
  TAMIClient = class(TObject)
  private
    FConfig: TAMIClientConfig;
    FTransport: TAMITransport;
    FPacketReader: TAMIPacketReader;
    FEventManager: TAMIEventManager;
    FStatus: TAMIClientStatus;
    FAuthenticating: Boolean;
    
    // Statistics
    FTotalEvents: Int64;
    FTotalActions: Int64;
    FFailedActions: Int64;
    
  public
    constructor Create(const AConfig: TAMIClientConfig);
    destructor Destroy; override;

    // Connection management
    function Connect: Boolean;
    procedure Disconnect;
    function IsConnected: Boolean;
    function GetConnectionInfo: String;

    // Synchronous actions
    function SendAction(const AAction: TAMIAction; ATimeout: Integer = 30000): TAMIResponse;
    
    // Asynchronous actions
    function SendActionAsync(const AAction: TAMIAction; AOnResponse: TAMIResponseEvent): String;

    // Cached actions
    function SendCachedAction(const AAction: TAMIAction; const ACacheKey: String; ATimeout: Integer = 30000): TAMIResponse;
    
    // Built-in actions
    function Originate(const AParams: TOriginateParams; ATimeout: Integer = 30000): TAMIResponse;
    function Hangup(const AChannel: String; ACause: Integer = 16; ATimeout: Integer = 30000): TAMIResponse;
    function Command(const ACommand: String; ATimeout: Integer = 30000): TAMIResponse;
    function Ping(ATimeout: Integer = 10000): TAMIResponse;
    function QueueStatus(const AQueueName: String = ''; ATimeout: Integer = 30000): TAMIResponse;
    function QueueAdd(const AQueueName, AMember: String; ATimeout: Integer = 30000): TAMIResponse;
    function QueueRemove(const AQueueName, AMember: String; ATimeout: Integer = 30000): TAMIResponse;
    
    // Event subscription
    procedure SubscribeToEvent(const AEventName: String; AOnEvent: TAMIEventEvent);
    procedure UnsubscribeFromEvent(const AEventName: String);
    procedure SetEventMask(const AMask: String);
    
    // Statistics
    function GetStatistics: String;
    function GetUptime: Integer;
    
    // Properties
    property Status: TAMIClientStatus read FStatus;
    property TotalEvents: Int64 read FTotalEvents;
    property TotalActions: Int64 read FTotalActions;
    property FailedActions: Int64 read FFailedActions;
    
    // Events
    property OnConnect: TAMIConnectEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TAMIDisconnectEvent read FOnDisconnect write FOnDisconnect;
    property OnLog: TAMILogEvent read FOnLog write FOnLog;
    property OnEvent: TAMIEventEvent read FOnEvent write FOnEvent;
    property OnResponse: TAMIResponseEvent read FOnResponse write FOnResponse;
  end;
```

---

## Connection Management

### Connect
```pascal
function Connect: Boolean;
```

**Description**: Establishes connection to Asterisk AMI and authenticates.

**Returns**: True if connected and authenticated successfully

**Process**:
1. Connects TCP socket to configured host:port
2. Starts packet reader thread
3. Waits for reader initialization (500ms)
4. Authenticates using configured method (plain/MD5)
5. Starts keep-alive thread (if PingInterval > 0)

**Example**:
```pascal
var
  Client: TAMIClient;
  Config: TAMIClientConfig;
begin
  Config := Default(TAMIClientConfig);
  Config.Host := '192.168.1.100';
  Config.Port := 5038;
  Config.Username := 'admin';
  Config.Password := 'secret';
  
  Client := TAMIClient.Create(Config);
  try
    if Client.Connect then
    begin
      WriteLn('Connected successfully!');
      WriteLn(Client.GetConnectionInfo);
      
      // Use client...
      
      Client.Disconnect;
    end
    else
      WriteLn('Connection failed');
  finally
    Client.Free;
  end;
end;
```

**Thread Safety**: Safe to call from any thread

**Error Handling**:
```pascal
if not Client.Connect then
begin
  case Client.Status of
    csAuthFailed:
      WriteLn('Authentication failed - check credentials');
    csDisconnected:
      WriteLn('Connection failed - check host/port');
  end;
end;
```

**Auto-Reconnect**: If connection fails and `MaxReconnectAttempts > 0`, automatic reconnection starts

---

### Disconnect
```pascal
procedure Disconnect;
```

**Description**: Gracefully disconnects from Asterisk.

**Process**:
1. Stops keep-alive thread
2. Stops reconnection thread (if active)
3. Stops packet reader thread
4. Closes TCP socket
5. Sets status to `csDisconnected`

**Example**:
```pascal
Client.Disconnect;
WriteLn('Disconnected. Uptime was: ', Client.GetUptime, ' seconds');
```

**Thread Safety**: Safe to call from any thread

**Note**: Automatically called in destructor

---

### IsConnected
```pascal
function IsConnected: Boolean;
```

**Description**: Checks if client is connected and ready to send actions.

**Returns**: True if status is `csConnected` OR currently authenticating

**Example**:
```pascal
if Client.IsConnected then
begin
  Response := Client.Ping;
  // Process response...
end
else
begin
  WriteLn('Not connected. Status: ', GetEnumName(TypeInfo(TAMIClientStatus), Ord(Client.Status)));
  Client.Connect;
end;
```

**Note**: Returns True during authentication to allow sending Login action

---

### GetConnectionInfo
```pascal
function GetConnectionInfo: String;
```

**Description**: Returns formatted connection information string.

**Returns**: Human-readable connection status

**Example Output**:
```
Connected to 192.168.1.100:5038 for 3600 seconds, 2456.3 bytes/sec, 1523 events, 42 actions
```

**Usage**:
```pascal
Timer.OnTimer := procedure
begin
  StatusBar.Panels[0].Text := Client.GetConnectionInfo;
end;
```

---

## Synchronous Actions

### SendAction
```pascal
function SendAction(const AAction: TAMIAction; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Sends action synchronously and waits for response.

**Parameters**:
- `AAction`: Action to send (caller owns and must free)
- `ATimeout`: Maximum wait time in milliseconds (default: 30000)

**Returns**: Response object (caller owns and must free), or nil on timeout/error

**Memory Management**:
```pascal
// CORRECT usage:
Action := TAMIPingAction.Create;
try
  Response := Client.SendAction(Action, 5000);
  if Assigned(Response) then
  try
    WriteLn(Response.Response);
  finally
    Response.Free;  // Caller frees response
  end;
finally
  Action.Free;  // Caller frees action
end;
```

**Process**:
1. Validates connection
2. Generates unique ActionID
3. Adds action to pending queue
4. Sends action data to Asterisk
5. Waits for response (processes incoming messages during wait)
6. Returns response or nil on timeout

**Thread Safety**: Fully thread-safe (uses FSendLock)

**Example - Multiple concurrent actions**:
```pascal
TThread.CreateAnonymousThread(
  procedure
  var
    Action: TAMIPingAction;
    Response: TAMIResponse;
  begin
    Action := TAMIPingAction.Create;
    try
      Response := Client.SendAction(Action, 10000);
      if Assigned(Response) then
      try
        TThread.Synchronize(nil, 
          procedure
          begin
            Memo.Lines.Add('Thread ping: ' + Response.Response);
          end);
      finally
        Response.Free;
      end;
    finally
      Action.Free;
    end;
  end).Start;
```

**Timeout Behavior**:
- If no response within `ATimeout`, returns nil
- Failed action count incremented
- Pending action automatically cleaned up

---

### SendActionAsync
```pascal
function SendActionAsync(const AAction: TAMIAction; AOnResponse: TAMIResponseEvent): String;
```

**Description**: Sends action asynchronously with callback.

**Parameters**:
- `AAction`: Action to send (ownership transferred to client)
- `AOnResponse`: Callback invoked when response arrives

**Returns**: ActionID string, or empty string on error

**Example**:
```pascal
procedure TForm1.SendAsyncPing;
var
  Action: TAMIPingAction;
begin
  Action := TAMIPingAction.Create;
  
  Client.SendActionAsync(Action, 
    procedure(Sender: TObject; const Response: TAMIResponse)
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          Memo.Lines.Add('Async ping: ' + Response.Response);
        end);
    end);
  
  // Action ownership transferred - don't free it
  WriteLn('Ping sent, continuing...');
end;
```

**Callback Notes**:
- Called from internal thread context
- Response object is valid only during callback
- Use TThread.Synchronize for UI updates

**Error Handling**:
```pascal
ActionID := Client.SendActionAsync(Action, @OnResponse);
if ActionID = '' then
  WriteLn('Failed to send action');
```

---

### SendCachedAction
```pascal
function SendCachedAction(const AAction: TAMIAction; const ACacheKey: String; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Sends action with response caching (useful for expensive queries).

**Parameters**:
- `AAction`: Action to send
- `ACacheKey`: Unique cache key
- `ATimeout`: Action timeout

**Returns**: Cached response if available, otherwise executes action and caches result

**Cache Behavior**:
- TTL: Configurable (default 300 seconds)
- Size limit: Configurable (default 200 entries)
- LRU eviction when full

**Example**:
```pascal
// Queue status changes infrequently - cache for 60 seconds
function GetQueueStatus(const QueueName: String): TAMIResponse;
var
  Action: TAMIQueueStatusAction;
  CacheKey: String;
begin
  CacheKey := 'queue_status_' + QueueName;
  
  Action := TAMIQueueStatusAction.Create(QueueName);
  try
    Result := Client.SendCachedAction(Action, CacheKey, 30000);
    
    if Assigned(Result) then
      WriteLn('Got queue status (cached: ', IsCached, ')');
  finally
    Action.Free;
  end;
end;

// First call - executes action
Response1 := GetQueueStatus('support');

// Second call within TTL - returns cached
Response2 := GetQueueStatus('support');  // Cache hit!
```

**Cache Invalidation**:
```pascal
// Manual cache clear
Client.ClearCaches;

// Clear old entries
Client.CleanupCaches(60);  // Remove entries older than 60 minutes
```

---

## Built-in Actions

### Ping
```pascal
function Ping(ATimeout: Integer = 10000): TAMIResponse;
```

**Description**: Sends Ping action to test connection.

**Parameters**:
- `ATimeout`: Timeout in milliseconds (default: 10000)

**Returns**: Response with `Response: Pong`

**Example**:
```pascal
Response := Client.Ping(5000);
if Assigned(Response) then
try
  if Response.IsSuccess then
    WriteLn('Server alive, ping time: 0ms')
  else
    WriteLn('Ping failed: ', Response.Message);
finally
  Response.Free;
end;
```

**Use Cases**:
- Connection health check
- Keep-alive (automatic with PingInterval > 0)
- Latency measurement

---

### Originate
```pascal
function Originate(const AParams: TOriginateParams; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Initiates outbound call.

**Parameters**:
- `AParams`: Originate parameters (see TOriginateParams)
- `ATimeout`: Action timeout (default: 30000ms)

**Returns**: Response indicating if call was initiated

**Example - Click-to-call**:
```pascal
procedure TForm1.ButtonCallClick(Sender: TObject);
var
  Params: TOriginateParams;
  Response: TAMIResponse;
begin
  Params := Default(TOriginateParams);
  Params.Channel := 'SIP/' + EditExtension.Text;
  Params.Context := 'from-internal';
  Params.Extension := EditNumber.Text;
  Params.Priority := '1';
  Params.CallerID := 'Click-to-Call <9999>';
  Params.Async := True;
  Params.Timeout := 30000;
  
  Response := Client.Originate(Params, 60000);
  if Assigned(Response) then
  try
    if Response.IsSuccess then
      ShowMessage('Call initiated successfully')
    else
      ShowMessage('Call failed: ' + Response.Message);
  finally
    Response.Free;
  end;
end;
```

**Example - Conference bridge**:
```pascal
// Join caller to conference
Params := Default(TOriginateParams);
Params.Channel := 'SIP/1001';
Params.Application := 'ConfBridge';
Params.Data := 'conference-100,user_profile,bridge_profile';
Params.CallerID := 'Conference Call <5555>';
Params.Async := True;

Response := Client.Originate(Params);
```

**Response Fields**:
- Success: Call initiated
- Error: Failure reason

**Related Events**:
- `OriginateResponse` - Final result
- `Newchannel` - Channel created
- `DialBegin` - Dialing started

---

### Hangup
```pascal
function Hangup(const AChannel: String; ACause: Integer = 16; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Terminates active channel.

**Parameters**:
- `AChannel`: Channel name (e.g., 'SIP/1001-00000001')
- `ACause`: Q.850 cause code (default: 16 = Normal clearing)
- `ATimeout`: Action timeout

**Returns**: Response indicating success/failure

**Example**:
```pascal
// Hangup specific channel
Response := Client.Hangup('SIP/1001-00000001', 16);

// Hangup with custom cause
Response := Client.Hangup(ChannelName, 21);  // Call rejected
```

**Common Cause Codes**:
```pascal
const
  CAUSE_NORMAL_CLEARING = 16;
  CAUSE_USER_BUSY = 17;
  CAUSE_NO_ANSWER = 19;
  CAUSE_CALL_REJECTED = 21;
  CAUSE_CONGESTION = 34;
```

**Related Events**:
- `Hangup` - Channel terminated

---

### Command
```pascal
function Command(const ACommand: String; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Executes Asterisk CLI command.

**Parameters**:
- `ACommand`: CLI command string
- `ATimeout`: Action timeout

**Returns**: TAMICommandResponse with multi-line output

**Example - Show channels**:
```pascal
Response := Client.Command('core show channels');
if Assigned(Response) and (Response is TAMICommandResponse) then
try
  CmdResp := TAMICommandResponse(Response);
  
  Memo.Lines.BeginUpdate;
  try
    Memo.Lines.Clear;
    for i := 0 to CmdResp.OutputLines.Count - 1 do
      Memo.Lines.Add(CmdResp.OutputLines[i]);
  finally
    Memo.Lines.EndUpdate;
  end;
finally
  Response.Free;
end;
```

**Example - Reload dialplan**:
```pascal
Response := Client.Command('dialplan reload');
if Assigned(Response) then
try
  if Pos('Dialplan reloaded', Response.Message) > 0 then
    WriteLn('Dialplan reloaded successfully')
  else
    WriteLn('Reload failed');
finally
  Response.Free;
end;
```

**Security Note**: Requires 'system' permission level in manager.conf

**Useful Commands**:
```pascal
// System info
Client.Command('core show version');
Client.Command('core show uptime');
Client.Command('core show settings');

// Channel info
Client.Command('core show channels');
Client.Command('core show channel SIP/1001-00000001');

// Queue info
Client.Command('queue show');
Client.Command('queue show support');

// SIP/PJSIP info
Client.Command('pjsip show endpoints');
Client.Command('pjsip show endpoint 1001');

// Reload modules
Client.Command('module reload res_pjsip.so');
Client.Command('dialplan reload');
```

---

### QueueStatus
```pascal
function QueueStatus(const AQueueName: String = ''; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Retrieves queue status (members, calls, statistics).

**Parameters**:
- `AQueueName`: Specific queue name, or empty for all queues
- `ATimeout`: Action timeout

**Returns**: Response (triggers multiple events with detailed info)

**Example**:
```pascal
// Get all queues
Response := Client.QueueStatus('', 30000);
if Assigned(Response) then
try
  if Response.IsSuccess then
    WriteLn('Queue status request sent - listen for events')
  else
    WriteLn('Failed: ', Response.Message);
finally
  Response.Free;
end;

// Listen for events
Client.SubscribeToEvent('QueueParams', @OnQueueParams);
Client.SubscribeToEvent('QueueMember', @OnQueueMember);
Client.SubscribeToEvent('QueueEntry', @OnQueueEntry);
```

**Event Handlers**:
```pascal
procedure TForm1.OnQueueParams(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('Queue: ', Event.GetField('Queue'));
  WriteLn('  Max: ', Event.GetField('Max'));
  WriteLn('  Calls: ', Event.GetField('Calls'));
  WriteLn('  Hold time: ', Event.GetField('Holdtime'));
  WriteLn('  Completed: ', Event.GetField('Completed'));
  WriteLn('  Abandoned: ', Event.GetField('Abandoned'));
end;

procedure TForm1.OnQueueMember(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('  Member: ', Event.GetField('Name'));
  WriteLn('    Status: ', Event.GetField('Status'));
  WriteLn('    Paused: ', Event.GetField('Paused'));
  WriteLn('    Calls taken: ', Event.GetField('CallsTaken'));
end;
```

**Cached Version**:
```pascal
// Cache queue status for 30 seconds
Response := Client.SendCachedAction(
  TAMIQueueStatusAction.Create('support'),
  'queue_status_support',
  30000
);
```

---

### QueueAdd
```pascal
function QueueAdd(const AQueueName, AMember: String; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Adds member to queue.

**Parameters**:
- `AQueueName`: Queue name
- `AMember`: Member interface (e.g., 'SIP/1001')
- `ATimeout`: Action timeout

**Returns**: Response indicating success/failure

**Example**:
```pascal
Response := Client.QueueAdd('support', 'SIP/1001', 30000);
if Assigned(Response) then
try
  if Response.IsSuccess then
    WriteLn('Member added to queue successfully')
  else
    WriteLn('Failed to add member: ', Response.Message);
finally
  Response.Free;
end;
```

**Advanced Example - Add with penalty**:
```pascal
var
  Action: TAMIQueueAddAction;
begin
  Action := TAMIQueueAddAction.Create('support', 'SIP/1001', 5, False);
  try
    Response := Client.SendAction(Action, 30000);
    if Assigned(Response) then
    try
      if Response.IsSuccess then
        WriteLn('Member added with penalty 5');
    finally
      Response.Free;
    end;
  finally
    Action.Free;
  end;
end;
```

**Related Events**:
- `QueueMemberAdded` - Member successfully added

---

### QueueRemove
```pascal
function QueueRemove(const AQueueName, AMember: String; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Removes member from queue.

**Parameters**:
- `AQueueName`: Queue name
- `AMember`: Member interface
- `ATimeout`: Action timeout

**Returns**: Response indicating success/failure

**Example**:
```pascal
Response := Client.QueueRemove('support', 'SIP/1001');
if Assigned(Response) then
try
  if Response.IsSuccess then
  begin
    WriteLn('Member removed from queue');
    UpdateQueueDisplay;
  end;
finally
  Response.Free;
end;
```

**Related Events**:
- `QueueMemberRemoved` - Member successfully removed

---

## Additional Built-in Actions

### Redirect
```pascal
function Redirect(const AChannel, AContext, AExtension: String; 
                 APriority: Integer = 1; 
                 AExtraChannel: String = ''; 
                 ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Redirects channel to different extension.

**Example - Transfer call**:
```pascal
// Simple redirect
Response := Client.Redirect('SIP/1001-00000001', 'from-internal', '100', 1);

// Two-channel redirect (merge calls)
Response := Client.Redirect(
  'SIP/1001-00000001',  // First channel
  'from-internal',
  '100',
  1,
  'SIP/1002-00000002'   // Second channel
);
```

---

### GetVar / SetVar
```pascal
function GetVar(const AChannel, AVariable: String; ATimeout: Integer = 30000): TAMIResponse;
function SetVar(const AChannel, AVariable, AValue: String; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Get/set channel or global variables.

**Example - Channel variable**:
```pascal
// Set channel variable
Response := Client.SetVar('SIP/1001-00000001', 'MYVAR', 'value123');
if Assigned(Response) then
try
  if Response.IsSuccess then
    WriteLn('Variable set');
finally
  Response.Free;
end;

// Get channel variable
Response := Client.GetVar('SIP/1001-00000001', 'CALLERID(num)');
if Assigned(Response) then
try
  CallerID := Response.GetField('Value');
  WriteLn('Caller ID: ', CallerID);
finally
  Response.Free;
end;
```

**Example - Global variable**:
```pascal
// Set global variable (empty channel name)
Client.SetVar('', 'GLOBAL_COUNTER', IntToStr(Counter));

// Get global variable
Response := Client.GetVar('', 'GLOBAL_COUNTER');
```

---

### BridgeInfo / BridgeList
```pascal
function BridgeInfo(const ABridgeUniqueID: String; ATimeout: Integer = 30000): TAMIResponse;
function BridgeList(ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Bridge information (Asterisk 12+).

**Example**:
```pascal
// List all bridges
Response := Client.BridgeList;

// Get specific bridge info
Response := Client.BridgeInfo('bridge-uuid-12345');
if Assigned(Response) then
try
  WriteLn('Bridge: ', Response.GetField('BridgeUniqueid'));
  WriteLn('Type: ', Response.GetField('BridgeType'));
  WriteLn('Channels: ', Response.GetField('BridgeNumChannels'));
finally
  Response.Free;
end;
```

---

### PeerStatus / PeerStatusEx
```pascal
function PeerStatus(const APeer: String = ''; ATimeout: Integer = 30000): TAMIResponse;
function PeerStatusEx(const APeer: String; const AProtocol: String = 'SIP'; ATimeout: Integer = 30000): TAMIResponse;
```

**Description**: Peer/endpoint status.

**Example - PJSIP**:
```pascal
Response := Client.PeerStatusEx('1001', 'PJSIP');
if Assigned(Response) then
try
  WriteLn('Endpoint: ', Response.GetField('Endpoint'));
  WriteLn('Status: ', Response.GetField('DeviceState'));
  WriteLn('Contact: ', Response.GetField('ContactStatus'));
finally
  Response.Free;
end;
```

**Example - Legacy SIP**:
```pascal
Response := Client.PeerStatusEx('1001', 'SIP');
```

---

## Event Management

### SubscribeToEvent
```pascal
procedure SubscribeToEvent(const AEventName: String; AOnEvent: TAMIEventEvent);
```

**Description**: Subscribes to specific event type with callback.

**Parameters**:
- `AEventName`: Event name (case-insensitive, e.g., 'Newchannel', 'Hangup')
- `AOnEvent`: Callback procedure

**Example - Multiple event handlers**:
```pascal
type
  TCallMonitor = class
    procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
    procedure OnDialBegin(Sender: TObject; const Event: TAMIEvent);
  end;

var
  Monitor: TCallMonitor;
begin
  Monitor := TCallMonitor.Create;
  
  Client.SubscribeToEvent('Newchannel', @Monitor.OnNewChannel);
  Client.SubscribeToEvent('Hangup', @Monitor.OnHangup);
  Client.SubscribeToEvent('DialBegin', @Monitor.OnDialBegin);
end;

procedure TCallMonitor.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('New call: ', Event.GetField('Channel'));
  WriteLn('  From: ', Event.GetField('CallerIDNum'));
  WriteLn('  To: ', Event.GetField('Exten'));
end;

procedure TCallMonitor.OnHangup(Sender: TObject; const Event: TAMIEvent);
var
  Info: THangupInfo;
begin
  Info := TAMIEventParser.ParseHangupInfo(Event);
  
  LogCallToDatabase(
    Info.UniqueID,
    Info.Duration,
    Info.Cause,
    Info.CauseTxt
  );
end;
```

**Thread Safety**: Event callbacks are called from internal thread - use TThread.Synchronize for UI updates:

```pascal
procedure TForm1.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  Channel: String;
begin
  Channel := Event.GetField('Channel');
  
  TThread.Synchronize(nil,
    procedure
    begin
      ListBox1.Items.Add(Channel);
      StatusBar1.SimpleText := 'Active calls: ' + IntToStr(ListBox1.Items.Count);
    end);
end;
```

---

### UnsubscribeFromEvent
```pascal
procedure UnsubscribeFromEvent(const AEventName: String);
```

**Description**: Removes all handlers for specific event.

**Example**:
```pascal
// Stop monitoring hangup events
Client.UnsubscribeFromEvent('Hangup');

// Cleanup on form close
procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Client.UnsubscribeFromEvent('Newchannel');
  Client.UnsubscribeFromEvent('Hangup');
  Client.UnsubscribeFromEvent('DialBegin');
end;
```

---

### SetEventMask
```pascal
procedure SetEventMask(const AMask: String);
```

**Description**: Sets AMI event filter mask.

**Parameters**:
- `AMask`: Event mask string

**Mask Values**:
- `'on'` - All events
- `'off'` - No events
- `'system,call,log'` - Specific categories

**Example**:
```pascal
// Only receive call-related events
Client.SetEventMask('call');

// System and call events
Client.SetEventMask('system,call');

// All events (default)
Client.SetEventMask('on');

// No events
Client.SetEventMask('off');
```

**Event Categories**:
```
system    - System events (reload, shutdown, etc.)
call      - Call events (newchannel, hangup, dial, etc.)
log       - Log events
verbose   - Verbose messages
command   - Command responses
agent     - Agent events
user      - User events
config    - Configuration events
dtmf      - DTMF events
reporting - CDR and CEL events
cdr       - CDR events
dialplan  - Dialplan events
originate - Originate events
agi       - AGI events
cc        - Call completion events
aoc       - Advice of charge events
```

**Performance Tip**: Limit event mask to reduce network traffic and processing overhead:

```pascal
// Production server - only essential events
Client.SetEventMask('call,system');

// Development - all events for debugging
Client.SetEventMask('on');
```

---

## Statistics and Monitoring

### GetStatistics
```pascal
function GetStatistics: String;
```

**Description**: Returns formatted statistics string.

**Returns**: Multi-line string with client statistics

**Example Output**:
```
AMI Client Statistics:
  Status: csConnected
  Uptime: 3600 seconds
  Total Events: 15234 (4.23/sec)
  Total Actions: 428 (0.12/sec)
  Failed Actions: 3
  Success Rate: 99.3%
  Bytes Received: 2.4 MB
  Bytes Sent: 156.7 KB
  Connection: Connected to 192.168.1.100:5038 for 3600 seconds, 2456.3 bytes/sec
```

**Usage**:
```pascal
// Periodic statistics logging
Timer.OnTimer := procedure
begin
  WriteLn(Client.GetStatistics);
  WriteLn('');
end;

// Write to log file
procedure LogStatistics;
begin
  var LogFile := TStringList.Create;
  try
    LogFile.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    LogFile.Add(Client.GetStatistics);
    LogFile.Add('---');
    LogFile.SaveToFile('ami_stats.log');
  finally
    LogFile.Free;
  end;
end;
```

---

### GetUptime
```pascal
function GetUptime: Integer;
```

**Description**: Returns connection uptime in seconds.

**Returns**: Seconds since connect, or 0 if disconnected

**Example**:
```pascal
Uptime := Client.GetUptime;

Hours := Uptime div 3600;
Minutes := (Uptime mod 3600) div 60;
Seconds := Uptime mod 60;

WriteLn(Format('Connected for %d:%02d:%02d', [Hours, Minutes, Seconds]));
```

---

### GetEventsPerSecond / GetActionsPerSecond
```pascal
function GetEventsPerSecond: Double;
function GetActionsPerSecond: Double;
```

**Description**: Returns average events/actions per second.

**Example - Monitor load**:
```pascal
procedure MonitorLoad;
var
  EventsPS, ActionsPS: Double;
begin
  EventsPS := Client.GetEventsPerSecond;
  ActionsPS := Client.GetActionsPerSecond;
  
  WriteLn(Format('Load: %.2f events/sec, %.2f actions/sec', [EventsPS, ActionsPS]));
  
  if EventsPS > 100 then
    WriteLn('WARNING: High event rate!');
end;
```

---

## Cache Management

### ClearCaches
```pascal
procedure ClearCaches;
```

**Description**: Clears all cache entries (event cache and response cache).

**Example**:
```pascal
// Clear cache after configuration change
Client.Command('dialplan reload');
Client.ClearCaches;  // Invalidate cached data
```

---

### CleanupCaches
```pascal
procedure CleanupCaches(AMaxAgeMinutes: Integer = 60);
```

**Description**: Removes cache entries older than specified age.

**Parameters**:
- `AMaxAgeMinutes`: Maximum age in minutes (default: 60)

**Example - Periodic cleanup**:
```pascal
Timer.Interval := 300000;  // 5 minutes
Timer.OnTimer := procedure
begin
  Client.CleanupCaches(60);  // Remove entries older than 1 hour
end;
```

---

### GetEventCacheStats / GetResponseCacheStats
```pascal
function GetEventCacheStats: String;
function GetResponseCacheStats: String;
```

**Description**: Returns cache statistics.

**Example Output**:
```
Event Cache: 0.95 hit rate, 450 items
Response Cache: 125 items
```

**Usage**:
```pascal
WriteLn('Cache Performance:');
WriteLn('  ', Client.GetEventCacheStats);
WriteLn('  ', Client.GetResponseCacheStats);
```

---

## Event Handlers

### OnConnect
```pascal
property OnConnect: TAMIConnectEvent;

type
  TAMIConnectEvent = procedure(Sender: TObject) of object;
```

**Description**: Fired when successfully connected and authenticated.

**Example**:
```pascal
Client.OnConnect := procedure(Sender: TObject)
begin
  WriteLn('Connected to Asterisk!');
  WriteLn(Client.GetConnectionInfo);
  
  // Subscribe to events
  Client.SubscribeToEvent('Newchannel', @OnNewChannel);
  Client.SubscribeToEvent('Hangup', @OnHangup);
  
  // Set event mask
  Client.SetEventMask('call,system');
  
  // UI update
  TThread.Synchronize(nil,
    procedure
    begin
      ButtonConnect.Caption := 'Disconnect';
      ButtonConnect.Enabled := True;
      StatusIndicator.Color := clGreen;
    end);
end;
```

---

### OnDisconnect
```pascal
property OnDisconnect: TAMIDisconnectEvent;

type
  TAMIDisconnectEvent = procedure(Sender: TObject) of object;
```

**Description**: Fired when disconnected (either intentionally or due to error).

**Example**:
```pascal
Client.OnDisconnect := procedure(Sender: TObject)
begin
  WriteLn('Disconnected from Asterisk');
  
  // UI update
  TThread.Synchronize(nil,
    procedure
    begin
      ButtonConnect.Caption := 'Connect';
      StatusIndicator.Color := clRed;
      ListBoxCalls.Clear;
    end);
  
  // Attempt reconnection if unexpected
  if Client.Status = csDisconnected then
  begin
    WriteLn('Attempting reconnection in 5 seconds...');
    Sleep(5000);
    Client.Connect;
  end;
end;
```

---

### OnLog
```pascal
property OnLog: TAMILogEvent;

type
  TAMILogEvent = procedure(Sender: TObject; Level: TAMILogLevel; const Msg: String) of object;
```

**Description**: Fired for all internal log messages.

**Example - File logging**:
```pascal
type
  TForm1 = class(TForm)
  private
    FLogFile: TFileStream;
    FLogLock: TCriticalSection;
    procedure OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
  end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FLogLock := TCriticalSection.Create;
  FLogFile := TFileStream.Create('ami_client.log', fmCreate or fmShareDenyWrite);
  
  Client.OnLog := @OnLog;
end;

procedure TForm1.OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
var
  LogLine: String;
  Bytes: TBytes;
begin
  // Format log line
  LogLine := Format('[%s] [%s] %s'#13#10, [
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
    GetEnumName(TypeInfo(TAMILogLevel), Ord(Level)),
    Msg
  ]);
  
  // Write to file (thread-safe)
  FLogLock.Enter;
  try
    Bytes := TEncoding.UTF8.GetBytes(LogLine);
    FLogFile.Write(Bytes[0], Length(Bytes));
  finally
    FLogLock.Leave;
  end;
  
  // Also display in UI for errors
  if Level >= llError then
  begin
    TThread.Synchronize(nil,
      procedure
      begin
        MemoLog.Lines.Add(LogLine);
      end);
  end;
end;
```

**Example - Filtered logging**:
```pascal
procedure TForm1.OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
begin
  // Production: Only log warnings and errors
  if Level < llWarning then
    Exit;
  
  case Level of
    llWarning:
      WriteLn('[WARN] ', Msg);
    llError:
      WriteLn('[ERROR] ', Msg);
    llCritical:
      begin
        WriteLn('[CRITICAL] ', Msg);
        // Send alert email
        SendAlertEmail('AMI Critical Error', Msg);
      end;
  end;
end;
```

**Example - Structured logging**:
```pascal
type
  TLogEntry = record
    Timestamp: TDateTime;
    Level: TAMILogLevel;
    Message: String;
    ThreadID: TThreadID;
  end;

var
  LogQueue: TThreadList;

procedure OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
var
  Entry: TLogEntry;
  List: TList;
begin
  Entry.Timestamp := Now;
  Entry.Level := Level;
  Entry.Message := Msg;
  Entry.ThreadID := GetCurrentThreadId;
  
  List := LogQueue.LockList;
  try
    List.Add(@Entry);
  finally
    LogQueue.UnlockList;
  end;
end;
```

---

### OnEvent
```pascal
property OnEvent: TAMIEventEvent;

type
  TAMIEventEvent = procedure(Sender: TObject; const Event: TAMIEvent) of object;
```

**Description**: Fired for ALL events (global event handler).

**Example - Event logging**:
```pascal
Client.OnEvent := procedure(Sender: TObject; const Event: TAMIEvent)
begin
  WriteLn(Format('[EVENT] %s: %s', [
    Event.GetEventName,
    Event.GetField('Channel')
  ]));
end;
```

**Example - Event statistics**:
```pascal
var
  EventCounts: TDictionary<String, Integer>;

Client.OnEvent := procedure(Sender: TObject; const Event: TAMIEvent)
var
  EventName: String;
  Count: Integer;
begin
  EventName := Event.GetEventName;
  
  if EventCounts.TryGetValue(EventName, Count) then
    EventCounts[EventName] := Count + 1
  else
    EventCounts.Add(EventName, 1);
  
  // Log every 100 events
  if (Client.TotalEvents mod 100) = 0 then
  begin
    WriteLn('Top events:');
    for EventName in EventCounts.Keys do
      WriteLn('  ', EventName, ': ', EventCounts[EventName]);
  end;
end;
```

**Note**: Use `SubscribeToEvent()` for specific event types instead of filtering in OnEvent

---

### OnResponse
```pascal
property OnResponse: TAMIResponseEvent;

type
  TAMIResponseEvent = procedure(Sender: TObject; const Response: TAMIResponse) of object;
```

**Description**: Fired for ALL action responses (global response handler).

**Example - Response logging**:
```pascal
Client.OnResponse := procedure(Sender: TObject; const Response: TAMIResponse)
begin
  WriteLn(Format('[RESPONSE] ActionID: %s, Result: %s', [
    Response.ActionID,
    Response.Response
  ]));
  
  if not Response.IsSuccess then
    WriteLn('  Error: ', Response.Message);
end;
```

**Example - Performance monitoring**:
```pascal
var
  ResponseTimes: TDictionary<String, TDateTime>;

Client.OnResponse := procedure(Sender: TObject; const Response: TAMIResponse)
var
  ActionID: String;
  StartTime: TDateTime;
  Elapsed: Int64;
begin
  ActionID := Response.ActionID;
  
  if ResponseTimes.TryGetValue(ActionID, StartTime) then
  begin
    Elapsed := MilliSecondsBetween(Now, StartTime);
    WriteLn(Format('Action %s took %dms', [ActionID, Elapsed]));
    
    if Elapsed > 1000 then
      WriteLn('WARNING: Slow response!');
    
    ResponseTimes.Remove(ActionID);
  end;
end;
```

---

### OnActionResponse
```pascal
property OnActionResponse: TAMIResponseEvent;
```

**Description**: Fired for responses with ActionID (same as OnResponse but only for actions with IDs).

**Usage**: Typically use OnResponse instead, as OnActionResponse is redundant.

---

## Complete Usage Example

### Real-time Call Monitoring Application

```pascal
program CallMonitor;

uses
  SysUtils, Classes, ami_client, ami_types, ami_actions, ami_enums;

type
  TCallMonitorApp = class
  private
    FClient: TAMIClient;
    FActiveCalls: TStringList;
    
    procedure OnConnect(Sender: TObject);
    procedure OnDisconnect(Sender: TObject);
    procedure OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
    procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
    procedure OnDialBegin(Sender: TObject; const Event: TAMIEvent);
    procedure OnDialEnd(Sender: TObject; const Event: TAMIEvent);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

{ TCallMonitorApp }

constructor TCallMonitorApp.Create;
var
  Config: TAMIClientConfig;
begin
  inherited Create;
  
  FActiveCalls := TStringList.Create;
  
  // Configure client
  Config := Default(TAMIClientConfig);
  Config.Host := 'localhost';
  Config.Port := 5038;
  Config.Username := 'monitor';
  Config.Password := 'secret';
  Config.AuthType := 'plain';
  Config.PingInterval := 30;
  Config.MaxReconnectAttempts := 0;  // Infinite
  Config.ReconnectInterval := 5000;
  Config.EventMask := 'call,system';
  
  // Create client
  FClient := TAMIClient.Create(Config);
  
  // Setup event handlers
  FClient.OnConnect := @OnConnect;
  FClient.OnDisconnect := @OnDisconnect;
  FClient.OnLog := @OnLog;
  
  // Subscribe to call events
  FClient.SubscribeToEvent('Newchannel', @OnNewChannel);
  FClient.SubscribeToEvent('Hangup', @OnHangup);
  FClient.SubscribeToEvent('DialBegin', @OnDialBegin);
  FClient.SubscribeToEvent('DialEnd', @OnDialEnd);
end;

destructor TCallMonitorApp.Destroy;
begin
  FClient.Free;
  FActiveCalls.Free;
  inherited Destroy;
end;

procedure TCallMonitorApp.OnConnect(Sender: TObject);
begin
  WriteLn('=== Connected to Asterisk AMI ===');
  WriteLn(FClient.GetConnectionInfo);
  WriteLn('');
  WriteLn('Monitoring calls... Press Ctrl+C to exit');
  WriteLn('');
end;

procedure TCallMonitorApp.OnDisconnect(Sender: TObject);
begin
  WriteLn('=== Disconnected from Asterisk ===');
end;

procedure TCallMonitorApp.OnLog(Sender: TObject; Level: TAMILogLevel; const Msg: String);
begin
  // Only show warnings and errors
  if Level >= llWarning then
    WriteLn(Format('[%s] %s', [GetEnumName(TypeInfo(TAMILogLevel), Ord(Level)), Msg]));
end;

procedure TCallMonitorApp.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  Info: TChannelInfo;
begin
  Info := TAMIEventParser.ParseChannelInfo(Event);
  
  FActiveCalls.Add(Info.Channel);
  
  WriteLn('');
  WriteLn('[NEW CALL]');
  WriteLn('  Channel: ', Info.Channel);
  WriteLn('  From: ', Info.CallerIDName, ' <', Info.CallerIDNum, '>');
  WriteLn('  To: ', Info.Extension, '@', Info.Context);
  WriteLn('  UniqueID: ', Info.UniqueID);
  WriteLn('  Active calls: ', FActiveCalls.Count);
end;

procedure TCallMonitorApp.OnHangup(Sender: TObject; const Event: TAMIEvent);
var
  Info: THangupInfo;
  Index: Integer;
begin
  Info := TAMIEventParser.ParseHangupInfo(Event);
  
  Index := FActiveCalls.IndexOf(Info.Channel);
  if Index >= 0 then
    FActiveCalls.Delete(Index);
  
  WriteLn('');
  WriteLn('[HANGUP]');
  WriteLn('  Channel: ', Info.Channel);
  WriteLn('  Cause: ', Info.Cause, ' - ', Info.CauseTxt);
  WriteLn('  Duration: ', Info.Duration, ' seconds');
  WriteLn('  Active calls: ', FActiveCalls.Count);
end;

procedure TCallMonitorApp.OnDialBegin(Sender: TObject; const Event: TAMIEvent);
var
  Info: TDialInfo;
begin
  Info := TAMIEventParser.ParseDialInfo(Event);
  
  WriteLn('');
  WriteLn('[DIAL START]');
  WriteLn('  From: ', Info.Channel);
  WriteLn('  To: ', Info.Destination);
  WriteLn('  Caller: ', Info.CallerIDName, ' <', Info.CallerIDNum, '>');
end;

procedure TCallMonitorApp.OnDialEnd(Sender: TObject; const Event: TAMIEvent);
var
  Info: TDialInfo;
begin
  Info := TAMIEventParser.ParseDialInfo(Event);
  
  WriteLn('');
  WriteLn('[DIAL END]');
  WriteLn('  Status: ', Info.DialStatus);
  
  if Info.Forwarded then
    WriteLn('  Forwarded to: ', Info.Forward);
end;

procedure TCallMonitorApp.Run;
begin
  // Connect to Asterisk
  if not FClient.Connect then
  begin
    WriteLn('Failed to connect!');
    Exit;
  end;
  
  // Main loop - just keep processing events
  while FClient.IsConnected do
  begin
    Sleep(100);
    // Events are processed automatically in background
  end;
end;

var
  App: TCallMonitorApp;

begin
  App := TCallMonitorApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
```

**Output Example**:
```
=== Connected to Asterisk AMI ===
Connected to 192.168.1.100:5038 for 0 seconds, 0.0 bytes/sec, 0 events, 0 actions

Monitoring calls... Press Ctrl+C to exit

[NEW CALL]
  Channel: SIP/1001-00000001
  From: John Doe <1001>
  To: 100@from-internal
  UniqueID: 1234567890.123
  Active calls: 1

[DIAL START]
  From: SIP/1001-00000001
  To: SIP/1002-00000002
  Caller: John Doe <1001>

[DIAL END]
  Status: ANSWER

[HANGUP]
  Channel: SIP/1001-00000001
  Cause: 16 - Normal Clearing
  Duration: 45 seconds
  Active calls: 0
```

---

# 3. ami_actions.pas

## Overview
Predefined action classes for all standard AMI actions. Each class provides type-safe constructor with required/optional parameters.

## Action Categories

### Core Actions
- `TAMIOriginateAction` - Initiate outbound call
- `TAMIHangupAction` - Terminate channel
- `TAMICommandAction` - Execute CLI command

### Queue Actions
- `TAMIQueueAddAction` - Add member to queue
- `TAMIQueueRemoveAction` - Remove member from queue
- `TAMIQueueStatusAction` - Get queue status
- `TAMIQueuePauseAction` - Pause/unpause member
- `TAMIQueuePenaltyAction` - Change member penalty
- `TAMIQueueReloadAction` - Reload queue configuration
- `TAMIQueueResetAction` - Reset queue statistics
- `TAMIQueueRuleAction` - Get queue rule details
- `TAMIQueueSummaryAction` - Get queue summary

### Channel Actions
- `TAMIRedirectAction` - Redirect channel
- `TAMIAtxferAction` - Attended transfer
- `TAMIBridgeAction` - Bridge two channels
- `TAMIParkAction` - Park call
- `TAMIPlayDTMFAction` - Send DTMF
- `TAMISendTextAction` - Send text message
- `TAMISetVarAction` - Set variable
- `TAMIGetVarAction` - Get variable

### Conferencing Actions
**ConfBridge** (Asterisk 10+):
- `TAMIConfbridgeKickAction`
- `TAMIConfbridgeListAction`
- `TAMIConfbridgeListRoomsAction`
- `TAMIConfbridgeLockAction`
- `TAMIConfbridgeUnlockAction`
- `TAMIConfbridgeMuteAction`
- `TAMIConfbridgeUnmuteAction`
- `TAMIConfbridgeStartRecordAction`
- `TAMIConfbridgeStopRecordAction`
- `TAMIConfbridgeSetSingleVideoSrcAction`

**MeetMe** (Legacy):
- `TAMIMeetmeListAction`
- `TAMIMeetmeListRoomsAction`
- `TAMIMeetmeMuteAction`
- `TAMIMeetmeUnmuteAction`

### PJSIP Actions (Asterisk 12+)
- `TAMIPJSIPNotifyAction` - Send SIP NOTIFY
- `TAMIPJSIPQualifyAction` - Qualify endpoint
- `TAMIPJSIPShowEndpointsAction` - List all endpoints
- `TAMIPJSIPShowEndpointAction` - Show endpoint details
- `TAMIPJSIPShowRegistrationInboundContactStatusesAction`
- `TAMIPJSIPShowRegistrationsInboundAction`
- `TAMIPJSIPShowRegistrationsOutboundAction`
- `TAMIPJSIPShowResourceListsAction`
- `TAMIPJSIPShowSubscriptionsInboundAction`
- `TAMIPJSIPShowSubscriptionsOutboundAction`

### Legacy SIP Actions (chan_sip)
- `TAMISIPnotifyAction`
- `TAMISIPpeersAction`
- `TAMISIPshowpeerAction`
- `TAMISIPshowregistryAction`
- `TAMISIPqualifypeerAction`

### Voicemail Actions
- `TAMIVoicemailUsersListAction` - List voicemail users
- `TAMIMailboxStatusAction` - Get mailbox status
- `TAMIMailboxCountAction` - Get message count

### System Actions
- `TAMIPingAction` - Test connection
- `TAMIEventsAction` - Set event mask
- `TAMILogoffAction` - Disconnect session
- `TAMIChallengeAction` - Get MD5 challenge
- `TAMILoginAction` - Authenticate
- `TAMICoreShowChannelsAction` - List all channels
- `TAMICoreStatusAction` - Core status
- `TAMICoreSettingsAction` - Core settings
- `TAMIReloadAction` - Reload module/config
- `TAMIModuleLoadAction` - Load/unload/reload module
- `TAMIModuleCheckAction` - Check module status

### Monitoring Actions
- `TAMIMonitorAction` - Start call recording
- `TAMIStopMonitorAction` - Stop recording
- `TAMIPauseMonitorAction` - Pause recording
- `TAMIUnpauseMonitorAction` - Resume recording
- `TAMIChangeMonitorAction` - Change recording file
- `TAMIMixMonitorAction` - Start MixMonitor recording
- `TAMIMixMonitorMuteAction` - Mute MixMonitor
- `TAMIStopMixMonitorAction` - Stop MixMonitor

### Configuration Actions
- `TAMIGetConfigAction` - Get configuration file
- `TAMIGetConfigJSONAction` - Get config as JSON
- `TAMIUpdateConfigAction` - Update configuration
- `TAMICreateConfigAction` - Create configuration file
- `TAMIListCategoriesAction` - List config categories

### Bridge Actions (Asterisk 12+)
- `TAMIBridgeInfoAction` - Get bridge info
- `TAMIBridgeListAction` - List all bridges
- `TAMIBridgeDestroyAction` - Destroy bridge
- `TAMIBridgeKickAction` - Kick channel from bridge

### Agent Actions
- `TAMIAgentLogoffAction` - Logoff agent
- `TAMIAgentsAction` - List agents

### Miscellaneous Actions
- `TAMIUserEventAction` - Send custom user event
- `TAMIWaitEventAction` - Wait for event
- `TAMIShowDialPlanAction` - Show dialplan
- `TAMIDataGetAction` - Get data provider info
- `TAMIFilterAction` - Add/clear event filter
- `TAMIBlindTransferAction` - Blind transfer
- `TAMICancelAtxferAction` - Cancel attended transfer

---

## Action Usage Examples

### TAMIOriginateAction
```pascal
var
  Action: TAMIOriginateAction;
  Params: TOriginateParams;
  Response: TAMIResponse;
begin
  Action := TAMIOriginateAction.Create;
  try
    Params := Default(TOriginateParams);
    Params.Channel := 'SIP/1001';
    Params.Context := 'from-internal';
    Params.Extension := '100';
    Params.Priority := '1';
    Params.CallerID := 'Callback <5000>';
    Params.Timeout := 30000;
    Params.Async := True;
    
    // Optional: Add variables
    Params.Variables := TStringList.Create;
    try
      Params.Variables.Add('CUSTOMER_ID=12345');
      Params.Variables.Add('CAMPAIGN=summer_sale');
      
      Action.SetParams(Params);
      
      Response := Client.SendAction(Action, 60000);
      if Assigned(Response) then
      try
        if Response.IsSuccess then
          WriteLn('Call initiated')
        else
          WriteLn('Failed: ', Response.Message);
      finally
        Response.Free;
      end;
    finally
      Params.Variables.Free;
    end;
  finally
    Action.Free;
  end;
end;
```

---

### TAMIQueuePauseAction
```pascal
// Pause agent in specific queue
var
  Action: TAMIQueuePauseAction;
begin
  Action := TAMIQueuePauseAction.Create('support', 'SIP/1001', True);
  try
    Response := Client.SendAction(Action);
    // Handle response...
  finally
    Action.Free;
  end;
end;

// Unpause agent in all queues
Action := TAMIQueuePauseAction.Create('', 'SIP/1001', False);
```

---

### TAMIConfbridgeStartRecordAction
```pascal
var
  Action: TAMIConfbridgeStartRecordAction;
  RecordFile: String;
begin
  RecordFile := Format('/var/spool/asterisk/monitor/conf-%s-%s', [
    'meeting-room-1',
    FormatDateTime('yyyymmdd-hhnnss', Now)
  ]);
  
  Action := TAMIConfbridgeStartRecordAction.Create('meeting-room-1', RecordFile);
  try
    Response := Client.SendAction(Action);
    if Assigned(Response) then
    try
      if Response.IsSuccess then
        WriteLn('Recording started: ', RecordFile)
      else
        WriteLn('Failed to start recording: ', Response.Message);
    finally
      Response.Free;
    end;
  finally
    Action.Free;
  end;
end;
```

---

### TAMIMixMonitorAction
```pascal
// Start MixMonitor with options
var
  Action: TAMIMixMonitorAction;
  Options: String;
begin
  // Options: b=both, r=receive-only, t=transmit-only
  // i=inherit, m=mute, a=append
  Options := 'b(in)a';  // Both directions, inherit, append
  
  Action := TAMIMixMonitorAction.Create(
    'SIP/1001-00000001',
    '/var/spool/asterisk/monitor/call-${UNIQUEID}.wav',
    Options
  );
  try
    Response := Client.SendAction(Action);
    // Handle response...
  finally
    Action.Free;
  end;
end;
```

---

### TAMIGetConfigAction
```pascal
// Get entire config file
var
  Action: TAMIGetConfigAction;
begin
  Action := TAMIGetConfigAction.Create('extensions.conf');
  try
    Response := Client.SendAction(Action);
    if Assigned(Response) then
    try
      if Response.IsSuccess then
      begin
        // Parse config from response fields
        for i := 0 to Response.FieldCount - 1 do
        begin
          if StartsText('Line-', Response.GetFieldName(i)) then
            WriteLn(Response.GetFieldValue(i));
        end;
      end;
    finally
      Response.Free;
    end;
  finally
    Action.Free;
  end;
end;

// Get specific category
Action := TAMIGetConfigAction.Create('extensions.conf', 'from-internal');
```

---

### TAMIUserEventAction
```pascal
// Send custom event
var
  Action: TAMIUserEventAction;
begin
  Action := TAMIUserEventAction.Create('MyCustomEvent');
  try
    Action.AddHeader('CustomField1', 'Value1');
    Action.AddHeader('CustomField2', 'Value2');
    Action.AddHeader('Timestamp', IntToStr(DateTimeToUnix(Now)));
    
    Response := Client.SendAction(Action);
    // Handle response...
  finally
    Action.Free;
  end;
end;

// Subscribe to receive the event
Client.SubscribeToEvent('UserEvent', 
  procedure(Sender: TObject; const Event: TAMIEvent)
  begin
    if Event.GetField('UserEvent') = 'MyCustomEvent' then
    begin
      WriteLn('Custom event received:');
      WriteLn('  Field1: ', Event.GetField('CustomField1'));
      WriteLn('  Field2: ', Event.GetField('CustomField2'));
    end;
  end);
```

---

### TAMIDataGetAction
```pascal
// Get Asterisk data provider information
var
  Action: TAMIDataGetAction;
begin
  // Get all PJSIP endpoints
  Action := TAMIDataGetAction.Create('asterisk/res_pjsip/endpoints');
  try
    Response := Client.SendAction(Action);
    // Handle response...
  finally
    Action.Free;
  end;
end;

// Get specific endpoint with search filter
Action := TAMIDataGetAction.Create(
  'asterisk/res_pjsip/endpoints',
  'endpoint=1001',  // Search
  ''                // Filter
);
```

---

### TAMIFilterAction
```pascal
// Add event filter
var
  Action: TAMIFilterAction;
begin
  // Filter format: Header: Value
  Action := TAMIFilterAction.Create('Add', 'Event: Newchannel');
  try
    Response := Client.SendAction(Action);
  finally
    Action.Free;
  end;
end;

// Clear all filters
Action := TAMIFilterAction.Create('Clear', '');
```

---

## TPendingAction (Internal)

```pascal
type
  TPendingAction = class(TObject)
  private
    FAction: TAMIAction;
    FResponse: TAMIResponse;
    FActionID: String;
    FCreateTime: TDateTime;
    FOnResponse: TAMIResponseEvent;
    FWaitEvent: TSimpleEvent;
  public
    constructor Create(AAction: TAMIAction);
    destructor Destroy; override;
    
    procedure SignalDone;
    function Wait(ATimeout: Cardinal): TWaitResult;
    
    property ActionID: String read FActionID;
    property Action: TAMIAction read FAction;
    property Response: TAMIResponse read FResponse write FResponse;
    property CreateTime: TDateTime read FCreateTime;
    property OnResponse: TAMIResponseEvent read FOnResponse write FOnResponse;
  end;
```

**Description**: Internal class for tracking pending actions (not for direct use).

**Process**:
1. Created when action is sent
2. Added to pending queue with unique ActionID
3. Waits for matching response
4. Signals completion when response arrives
5. Cleaned up after timeout or response received

---

# 4. ami_events.pas

## Overview
Event handling and management system with filtering, routing, and subscription capabilities.

## TAMIEventHandler

```pascal
type
  TAMIEventHandler = class(TObject)
  private
    FEventName: String;
    FOnEvent: TAMIEventEvent;
    FEnabled: Boolean;
  public
    constructor Create(const AEventName: String; AOnEvent: TAMIEventEvent);
    
    property EventName: String read FEventName;
    property OnEvent: TAMIEventEvent read FOnEvent write FOnEvent;
    property Enabled: Boolean read FEnabled write FEnabled;
  end;
```

**Description**: Wrapper for event callback with enable/disable capability.

**Usage**:
```pascal
Handler := TAMIEventHandler.Create('Newchannel', @OnNewChannel);
Handler.Enabled := False;  // Temporarily disable
```

---

## TAMIEventManager

```pascal
type
  TAMIEventManager = class(TObject)
  private
    FHandlers: TFPObjectList;
    FEventFilters: TStringList;
    FDefaultHandler: TAMIEventEvent;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddHandler(const AEventName: String; AOnEvent: TAMIEventEvent);
    procedure RemoveHandler(const AEventName: String);
    procedure ClearHandlers;
    function ProcessEvent(const AEvent: TAMIEvent): Boolean;
    
    procedure AddIncludeFilter(const AEventName: String);
    procedure AddExcludeFilter(const AEventName: String);
    procedure ClearFilters;
    function IsEventAllowed(const AEventName: String): Boolean;
    
    property DefaultHandler: TAMIEventEvent read FDefaultHandler write FDefaultHandler;
  end;
```

### Methods

#### AddHandler
```pascal
procedure AddHandler(const AEventName: String; AOnEvent: TAMIEventEvent);
```

**Description**: Adds event handler for specific event type.

**Example**:
```pascal
EventManager.AddHandler('Newchannel', @OnNewChannel);
EventManager.AddHandler('Hangup', @OnHangup);
EventManager.AddHandler('QueueMemberAdded', @OnQueueMemberAdded);
```

**Thread Safety**: Fully thread-safe

---

#### RemoveHandler
```pascal
procedure RemoveHandler(const AEventName: String);
```

**Description**: Removes ALL handlers for specific event type.

**Example**:
```pascal
EventManager.RemoveHandler('Newchannel');
```

---

#### ProcessEvent
```pascal
function ProcessEvent(const AEvent: TAMIEvent): Boolean;
```

**Description**: Processes event through registered handlers.

**Returns**: True if at least one handler was called

**Process**:
1. Checks if event is allowed (filters)
2. Finds all handlers for event type
3. Calls each enabled handler
4. Calls default handler if no specific handler found

**Example**:
```pascal
if EventManager.ProcessEvent(Event) then
  WriteLn('Event handled')
else
  WriteLn('No handler for event: ', Event.GetEventName);
```

---

#### AddIncludeFilter / AddExcludeFilter
```pascal
procedure AddIncludeFilter(const AEventName: String);
procedure AddExcludeFilter(const AEventName: String);
```

**Description**: Adds event to include/exclude filter list.

**Filter Logic**:
- If filters exist: Only included events pass (whitelist mode)
- Excluded events are always blocked
- No filters: All events pass

**Example**:
```pascal
// Only allow call-related events
EventManager.ClearFilters;
EventManager.AddIncludeFilter('Newchannel');
EventManager.AddIncludeFilter('Hangup');
EventManager.AddIncludeFilter('DialBegin');
EventManager.AddIncludeFilter('DialEnd');

// Block specific events
EventManager.AddExcludeFilter('VarSet');  // Too noisy
EventManager.AddExcludeFilter('RTCPSent');
```

---

#### IsEventAllowed
```pascal
function IsEventAllowed(const AEventName: String): Boolean;
```

**Description**: Checks if event passes filters.

**Example**:
```pascal
if EventManager.IsEventAllowed('Newchannel') then
  WriteLn('Newchannel events are allowed')
else
  WriteLn('Newchannel events are filtered out');
```

---

## TAMIEventProcessor

```pascal
type
  TAMIEventProcessor = class(TObject)
  private
    FEventManager: TAMIEventManager;
    FOnLog: TAMILogEvent;
  public
    constructor Create(AEventManager: TAMIEventManager);
    
    procedure ProcessMessage(const AMessage: TAMIMessage);
    procedure ProcessEvent(const AEvent: TAMIEvent);
    
    property OnLog: TAMILogEvent read FOnLog write FOnLog;
  end;
```

**Description**: High-level event processor that routes events to manager.

### Methods

#### ProcessMessage
```pascal
procedure ProcessMessage(const AMessage: TAMIMessage);
```

**Description**: Processes any message type, routing events to ProcessEvent.

**Example**:
```pascal
Processor.ProcessMessage(Message);  // Handles events, ignores other message types
```

---

#### ProcessEvent
```pascal
procedure ProcessEvent(const AEvent: TAMIEvent);
```

**Description**: Processes event through event manager.

**Example**:
```pascal
Processor.ProcessEvent(Event);
```

---

## Complete Event Handling Example

### Multi-Queue Call Center Monitor

```pascal
program QueueMonitor;

type
  TQueueMonitor = class
  private
    FClient: TAMIClient;
    FQueueStats: TDictionary<String, TQueueStats>;
    FLock: TCriticalSection;
    
    procedure OnQueueCallerJoin(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueCallerLeave(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueMemberPause(Sender: TObject; const Event: TAMIEvent);
    procedure OnQueueMemberStatus(Sender: TObject; const Event: TAMIEvent);
    procedure UpdateDisplay;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

type
  TQueueStats = record
    QueueName: String;
    WaitingCalls: Integer;
    ActiveMembers: Integer;
    PausedMembers: Integer;
    LongestWait: Integer;
    AbandonedCalls: Integer;
  end;

constructor TQueueMonitor.Create;
var
  Config: TAMIClientConfig;
begin
  FQueueStats := TDictionary<String, TQueueStats>.Create;
  FLock := TCriticalSection.Create;
  
  Config := Default(TAMIClientConfig);
  Config.Host := 'localhost';
  Config.Port := 5038;
  Config.Username := 'monitor';
  Config.Password := 'secret';
  Config.EventMask := 'call,agent';
  
  FClient := TAMIClient.Create(Config);
  
  // Subscribe to queue events
  FClient.SubscribeToEvent('QueueCallerJoin', @OnQueueCallerJoin);
  FClient.SubscribeToEvent('QueueCallerLeave', @OnQueueCallerLeave);
  FClient.SubscribeToEvent('QueueMemberPause', @OnQueueMemberPause);
  FClient.SubscribeToEvent('QueueMemberStatus', @OnQueueMemberStatus);
end;

destructor TQueueMonitor.Destroy;
begin
  FClient.Free;
  FQueueStats.Free;
  FLock.Free;
  inherited;
end;

procedure TQueueMonitor.OnQueueCallerJoin(Sender: TObject; const Event: TAMIEvent);
var
  Queue: String;
  Stats: TQueueStats;
  Position, Wait: Integer;
begin
  Queue := Event.GetField('Queue');
  Position := StrToIntDef(Event.GetField('Position'), 0);
  Wait := StrToIntDef(Event.GetField('Wait'), 0);
  
  FLock.Enter;
  try
    if FQueueStats.TryGetValue(Queue, Stats) then
    begin
      Inc(Stats.WaitingCalls);
      if Wait > Stats.LongestWait then
        Stats.LongestWait := Wait;
      FQueueStats[Queue] := Stats;
    end
    else
    begin
      Stats := Default(TQueueStats);
      Stats.QueueName := Queue;
      Stats.WaitingCalls := 1;
      Stats.LongestWait := Wait;
      FQueueStats.Add(Queue, Stats);
    end;
  finally
    FLock.Leave;
  end;
  
  UpdateDisplay;
end;

procedure TQueueMonitor.OnQueueCallerLeave(Sender: TObject; const Event: TAMIEvent);
var
  Queue: String;
  Stats: TQueueStats;
begin
  Queue := Event.GetField('Queue');
  
  FLock.Enter;
  try
    if FQueueStats.TryGetValue(Queue, Stats) then
    begin
      Dec(Stats.WaitingCalls);
      if Stats.WaitingCalls < 0 then
        Stats.WaitingCalls := 0;
      FQueueStats[Queue] := Stats;
    end;
  finally
    FLock.Leave;
  end;
  
  UpdateDisplay;
end;

procedure TQueueMonitor.OnQueueMemberPause(Sender: TObject; const Event: TAMIEvent);
var
  Queue, Paused: String;
  Stats: TQueueStats;
begin
  Queue := Event.GetField('Queue');
  Paused := Event.GetField('Paused');
  
  FLock.Enter;
  try
    if FQueueStats.TryGetValue(Queue, Stats) then
    begin
      if Paused = '1' then
        Inc(Stats.PausedMembers)
      else
        Dec(Stats.PausedMembers);
        
      FQueueStats[Queue] := Stats;
    end;
  finally
    FLock.Leave;
  end;
  
  UpdateDisplay;
end;

procedure TQueueMonitor.OnQueueMemberStatus(Sender: TObject; const Event: TAMIEvent);
var
  Queue, Status: String;
  Stats: TQueueStats;
begin
  Queue := Event.GetField('Queue');
  Status := Event.GetField('Status');
  
  FLock.Enter;
  try
    if FQueueStats.TryGetValue(Queue, Stats) then
    begin
      // Status: 1=Available, 2=InUse, 5=Unavailable
      if Status = '1' then
        Inc(Stats.ActiveMembers);
        
      FQueueStats[Queue] := Stats;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TQueueMonitor.UpdateDisplay;
var
  Queue: String;
  Stats: TQueueStats;
begin
  // Clear screen
  WriteLn(#27'[2J'#27'[H');  // ANSI clear screen
  
  WriteLn('=== Queue Statistics ===');
  WriteLn('');
  WriteLn(Format('%-20s %8s %8s %8s %12s', [
    'Queue', 'Waiting', 'Active', 'Paused', 'Longest Wait'
  ]));
  WriteLn(StringOfChar('-', 70));
  
  FLock.Enter;
  try
    for Queue in FQueueStats.Keys do
    begin
      Stats := FQueueStats[Queue];
      WriteLn(Format('%-20s %8d %8d %8d %12d', [
        Stats.QueueName,
        Stats.WaitingCalls,
        Stats.ActiveMembers,
        Stats.PausedMembers,
        Stats.LongestWait
      ]));
    end;
  finally
    FLock.Leave;
  end;
  
  WriteLn('');
  WriteLn('Press Ctrl+C to exit');
end;

procedure TQueueMonitor.Run;
var
  Response: TAMIResponse;
begin
  if not FClient.Connect then
  begin
    WriteLn('Failed to connect!');
    Exit;
  end;
  
  // Initial queue status request
  Response := FClient.QueueStatus('', 30000);
  if Assigned(Response) then
    Response.Free;
  
  // Main loop
  while FClient.IsConnected do
  begin
    Sleep(1000);
    UpdateDisplay;
  end;
end;

var
  Monitor: TQueueMonitor;
begin
  Monitor := TQueueMonitor.Create;
  try
    Monitor.Run;
  finally
    Monitor.Free;
  end;
end.
```

---

# 5. ami_parser.pas

## Overview
Low-level AMI protocol parsing with support for both Key-Value and JSON formats.

## TAMIBuffer

```pascal
type
  TAMIBuffer = class
  private
    FData: PByte;
    FSize: Integer;
    FCapacity: Integer;
    FPosition: Integer;
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
```

### Methods

#### Append
```pascal
procedure Append(const Data: Pointer; Size: Integer);
```

**Description**: Appends raw bytes to buffer (grows automatically).

**Example**:
```pascal
Buffer.Append(@Bytes[0], BytesRead);
```

---

#### ReadLine
```pascal
function ReadLine(out Line: RawByteString): Boolean;
```

**Description**: Reads next line from buffer (consumes data).

**Returns**: True if line was read, False if no complete line available

**Example**:
```pascal
while Buffer.ReadLine(Line) do
begin
  WriteLn('Line: ', String(Line));
end;
```

---

#### HasCompleteMessage
```pascal
function HasCompleteMessage: Boolean;
```

**Description**: Checks if buffer contains complete AMI message.

**Detection Logic**:
- Standard messages: CRLF CRLF (`\r\n\r\n`)
- Command responses: `--END COMMAND--`
- Welcome messages: Single CRLF after "Asterisk Call Manager"

**Example**:
```pascal
if Buffer.HasCompleteMessage then
begin
  Message := Reader.ReadMessage;
  // Process message...
end;
```

---

#### Compact
```pascal
procedure Compact;
```

**Description**: Removes consumed data from buffer (moves unprocessed data to beginning).

**Example**:
```pascal
// After processing messages
Buffer.Compact;  // Free up memory
```

---

## TAMIReader

```pascal
type
  TAMIReader = class
  private
    FStream: TStream;
    FBuffer: TAMIBuffer;
    FConfig: TAMIClientConfig;
    FBytesRead: Int64;
    FMessagesRead: Integer;
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
```

### Methods

#### ReadMessage
```pascal
function ReadMessage: TAMIMessage;
```

**Description**: Reads and parses next complete message from buffer.

**Returns**: Parsed message object (caller owns), or nil if no complete message

**Example**:
```pascal
Message := Reader.ReadMessage;
if Assigned(Message) then
try
  case Message.MessageType of
    mtResponse: ProcessResponse(TAMIResponse(Message));
    mtEvent: ProcessEvent(TAMIEvent(Message));
  end;
finally
  Message.Free;
end;
```

**Parsing Process**:
1. Checks `HasCompleteMessage()`
2. Determines format (KV or JSON)
3. Parses message fields
4. Creates appropriate message object
5. Returns object or nil

---

## TAMIWriter

```pascal
type
  TAMIWriter = class
  public
    class function WriteMessage(const AMessage: TAMIMessage): RawByteString;
    class function WriteAction(const AAction: TAMIAction): RawByteString;
    class function WriteResponse(const AResponse: TAMIResponse): RawByteString;
  end;
```

### Methods

#### WriteAction
```pascal
class function WriteAction(const AAction: TAMIAction): RawByteString;
```

**Description**: Serializes action to AMI protocol format.

**Returns**: Raw bytes ready to send over socket

**Format**:
```
Action: <ActionName>
Field1: Value1
Field2: Value2
...
<CRLF>
```

**Example**:
```pascal
Action := TAMIPingAction.Create;
try
  Data := TAMIWriter.WriteAction(Action);
  Socket.SendData(Data);
finally
  Action.Free;
end;
```

**Generated Output**:
```
Action: Ping
ActionID: ami_1234567890_123_456_000001

```

---

## TAMIEventParser

```pascal
type
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
```

### Methods

#### ParseEventType
```pascal
class function ParseEventType(const AEventName: String): TAMIEventType;
```

**Description**: Converts event name string to enumeration.

**Example**:
```pascal
EventType := TAMIEventParser.ParseEventType('Newchannel');
// Returns: etNewchannel
```

**Performance**: Uses internal dictionary for O(1) lookup

---

#### ParseChannelInfo
```pascal
class function ParseChannelInfo(const AEvent: TAMIEvent): TChannelInfo;
```

**Description**: Extracts channel information from event.

**Example**:
```pascal
procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  Info: TChannelInfo;
begin
  Info := TAMIEventParser.ParseChannelInfo(Event);
  
  LogCall(Info.UniqueID, Info.CallerIDNum, Info.Extension);
end;
```

---

#### GetEventPriority
```pascal
class function GetEventPriority(const AEventType: TAMIEventType): Integer;
```

**Description**: Returns event priority (0-100, higher = more important).

**Priority Levels**:
- **100**: Critical (Hangup, HangupRequest, Newchannel)
- **90**: High (DialBegin, DialEnd)
- **85**: Important (Bridge events)
- **60-80**: Medium (Queue events, Auth events)
- **25-50**: Normal (Status events, System events)
- **20**: Low (VarSet, UserEvent)

**Example - Priority queue processing**:
```pascal
function ShouldProcessImmediately(const Event: TAMIEvent): Boolean;
var
  Priority: Integer;
begin
  Priority := TAMIEventParser.GetEventPriority(Event.EventType);
  Result := Priority >= 80;  // Process high-priority events immediately
end;
```

---

#### GetEventCategory
```pascal
class function GetEventCategory(const AEventType: TAMIEventType): String;
```

**Description**: Returns event category string.

**Categories**:
- `'CallControl'` - Channel lifecycle events
- `'Queue'` - Queue management events
- `'Bridge'` - Bridge events
- `'System'` - System events
- `'Security'` - Authentication events
- `'Conference'` - Conference events
- `'PJSIP'` - PJSIP endpoint events
- etc.

**Example - Category-based routing**:
```pascal
procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
var
  Category: String;
begin
  Category := TAMIEventParser.GetEventCategory(Event.EventType);
  
  case Category of
    'CallControl':
      CallControlHandler(Event);
    'Queue':
      QueueHandler(Event);
    'System':
      SystemHandler(Event);
  end;
end;
```

---

#### IsCallRelatedEvent
```pascal
class function IsCallRelatedEvent(const AEvent: TAMIEvent): Boolean;
```

**Description**: Checks if event is related to call processing.

**Call-Related Events**:
- Newchannel, Hangup
- DialBegin, DialEnd
- BridgeEnter, BridgeLeave
- Newstate, NewCallerid
- Hold, Unhold
- Transfers

**Example**:
```pascal
procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
begin
  if TAMIEventParser.IsCallRelatedEvent(Event) then
    UpdateCallDisplay(Event);
end;
```

---

#### ExtractChannelFromEvent
```pascal
class function ExtractChannelFromEvent(const AEvent: TAMIEvent): String;
```

**Description**: Extracts primary channel name from event.

**Field Priority**:
1. `Channel`
2. `DestChannel`
3. `BridgeChannel`

**Example**:
```pascal
Channel := TAMIEventParser.ExtractChannelFromEvent(Event);
if Channel <> '' then
  WriteLn('Channel: ', Channel);
```

---

## Advanced Parser Usage

### Custom Message Parser

```pascal
type
  TCustomAMIParser = class
  private
    FReader: TAMIReader;
    FBuffer: TAMIBuffer;
    FOnMessage: TNotifyEvent;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure FeedData(const Data: RawByteString);
    procedure ProcessMessages;
  end;

constructor TCustomAMIParser.Create;
begin
  FBuffer := TAMIBuffer.Create(16384);
  FReader := TAMIReader.Create(FBuffer);
end;

destructor TCustomAMIParser.Destroy;
begin
  FReader.Free;
  FBuffer.Free;
  inherited;
end;

procedure TCustomAMIParser.FeedData(const Data: RawByteString);
begin
  if Length(Data) > 0 then
    FBuffer.Append(@Data[1], Length(Data));
end;

procedure TCustomAMIParser.ProcessMessages;
var
  Message: TAMIMessage;
begin
  while FBuffer.HasCompleteMessage do
  begin
    Message := FReader.ReadMessage;
    if Assigned(Message) then
    try
      if Assigned(FOnMessage) then
        FOnMessage(Message);
    finally
      Message.Free;
    end;
  end;
  
  // Cleanup processed data
  FBuffer.Compact;
end;

// Usage
var
  Parser: TCustomAMIParser;
  Data: RawByteString;
begin
  Parser := TCustomAMIParser.Create;
  try
    Parser.OnMessage := procedure(Sender: TObject)
    var
      Msg: TAMIMessage;
    begin
      Msg := TAMIMessage(Sender);
      WriteLn('Received: ', Msg.ToString);
    end;
    
    // Feed data from socket
    Data := Socket.ReceiveData;
    Parser.FeedData(Data);
    
    // Process all complete messages
    Parser.ProcessMessages;
  finally
    Parser.Free;
  end;
end;
```

---

### Streaming Parser for Large Files

```pascal
procedure ParseAMILog(const FileName: String);
var
  FileStream: TFileStream;
  Reader: TAMIReader;
  Message: TAMIMessage;
  Count: Integer;
begin
  FileStream := TFileStream.Create(FileName, fmOpenRead);
  try
    Reader := TAMIReader.Create(FileStream);
    try
      Count := 0;
      
      while Reader.HasData do
      begin
        Message := Reader.ReadMessage;
        if Assigned(Message) then
        try
          Inc(Count);
          
          // Process message
          case Message.MessageType of
            mtEvent:
              ProcessLoggedEvent(TAMIEvent(Message));
            mtResponse:
              ProcessLoggedResponse(TAMIResponse(Message));
          end;
          
          if (Count mod 1000) = 0 then
            WriteLn('Processed ', Count, ' messages...');
        finally
          Message.Free;
        end;
      end;
      
      WriteLn('Total messages: ', Count);
      WriteLn('Bytes read: ', Reader.BytesRead);
    finally
      Reader.Free;
    end;
  finally
    FileStream.Free;
  end;
end;
```

---

## Error Handling Best Practices

### Parser Error Recovery

```pascal
function SafeParseMessage(Reader: TAMIReader): TAMIMessage;
begin
  Result := nil;
  
  try
    Result := Reader.ReadMessage;
  except
    on E: EAMIProtocolException do
    begin
      WriteLn('Protocol error: ', E.Message);
      // Skip corrupted message
      Result := nil;
    end;
    on E: Exception do
    begin
      WriteLn('Unexpected error: ', E.Message);
      raise;
    end;
  end;
end;
```

---

### Malformed Data Handling

```pascal
type
  TRobustAMIParser = class
  private
    FBuffer: TAMIBuffer;
    FReader: TAMIReader;
    FDiscardedBytes: Int64;
    
    procedure RecoverFromError;
  public
    function ParseNext: TAMIMessage;
  end;

procedure TRobustAMIParser.RecoverFromError;
var
  Line: RawByteString;
begin
  // Skip lines until we find a valid message start
  while FBuffer.ReadLine(Line) do
  begin
    Inc(FDiscardedBytes, Length(Line) + 2);
    
    if (Pos('Response:', String(Line)) > 0) or
       (Pos('Event:', String(Line)) > 0) or
       (Pos('Action:', String(Line)) > 0) then
    begin
      // Found potential message start
      // Reset position to before this line
      Dec(FBuffer.FPosition, Length(Line) + 2);
      Break;
    end;
  end;
end;

function TRobustAMIParser.ParseNext: TAMIMessage;
begin
  Result := nil;
  
  try
    if FBuffer.HasCompleteMessage then
      Result := FReader.ReadMessage;
  except
    on E: EAMIProtocolException do
    begin
      WriteLn('Parse error, attempting recovery: ', E.Message);
      RecoverFromError;
    end;
  end;
end;
```

---

## Performance Optimization

### Buffer Size Tuning

```pascal
const
  // Default buffer size (8KB) - good for most cases
  BUFFER_SIZE_DEFAULT = 8192;
  
  // Small buffer (2KB) - low-traffic connections
  BUFFER_SIZE_SMALL = 2048;
  
  // Large buffer (64KB) - high-traffic servers
  BUFFER_SIZE_LARGE = 65536;
  
  // Huge buffer (256KB) - batch processing
  BUFFER_SIZE_HUGE = 262144;

var
  Buffer: TAMIBuffer;
begin
  // Choose buffer size based on load
  if IsHighTrafficServer then
    Buffer := TAMIBuffer.Create(BUFFER_SIZE_LARGE)
  else
    Buffer := TAMIBuffer.Create(BUFFER_SIZE_DEFAULT);
end;
```

---

### Zero-Copy Parsing (Advanced)

```pascal
type
  TZeroCopyParser = class
  private
    FBuffer: PByte;
    FSize: Integer;
    FPosition: Integer;
    
    function FindLineEnd(StartPos: Integer): Integer;
    function ExtractField(StartPos, EndPos: Integer; out Key, Value: String): Boolean;
  public
    procedure SetData(AData: PByte; ASize: Integer);
    function ParseMessageInPlace: Boolean;
  end;

function TZeroCopyParser.FindLineEnd(StartPos: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := StartPos to FSize - 2 do
  begin
    if (FBuffer[i] = 13) and (FBuffer[i + 1] = 10) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

function TZeroCopyParser.ExtractField(StartPos, EndPos: Integer; 
                                      out Key, Value: String): Boolean;
var
  SepPos: Integer;
  Line: String;
begin
  Result := False;
  
  SetString(Line, PAnsiChar(FBuffer + StartPos), EndPos - StartPos);
  
  SepPos := Pos(':', Line);
  if SepPos > 0 then
  begin
    Key := Trim(Copy(Line, 1, SepPos - 1));
    Value := Trim(Copy(Line, SepPos + 1, MaxInt));
    Result := True;
  end;
end;
```

---

## Testing and Validation

### Unit Tests for Parser

```pascal
procedure TestParseSimpleResponse;
var
  Buffer: TAMIBuffer;
  Reader: TAMIReader;
  Message: TAMIMessage;
  Input: RawByteString;
begin
  Input := 'Response: Success'#13#10 +
           'ActionID: test-123'#13#10 +
           'Message: Authentication accepted'#13#10#13#10;
  
  Buffer := TAMIBuffer.Create;
  try
    Buffer.Append(@Input[1], Length(Input));
    
    Reader := TAMIReader.Create(Buffer);
    try
      AssertTrue('HasCompleteMessage', Buffer.HasCompleteMessage);
      
      Message := Reader.ReadMessage;
      try
        AssertNotNull('Message parsed', Message);
        AssertTrue('Is Response', Message is TAMIResponse);
        AssertEquals('Response', 'Success', TAMIResponse(Message).Response);
        AssertEquals('ActionID', 'test-123', Message.ActionID);
        AssertTrue('IsSuccess', TAMIResponse(Message).IsSuccess);
      finally
        Message.Free;
      end;
    finally
      Reader.Free;
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TestParseCommandResponse;
var
  Input: RawByteString;
  Message: TAMICommandResponse;
begin
  Input := 'Response: Follows'#13#10 +
           'Privilege: Command'#13#10 +
           'ActionID: cmd-456'#13#10 +
           'Line 1 of output'#13#10 +
           'Line 2 of output'#13#10 +
           'Line 3 of output'#13#10 +
           '--END COMMAND--'#13#10#13#10;
  
  Buffer := TAMIBuffer.Create;
  try
    Buffer.Append(@Input[1], Length(Input));
    Reader := TAMIReader.Create(Buffer);
    try
      Message := Reader.ReadMessage as TAMICommandResponse;
      try
        AssertNotNull('Command response', Message);
        AssertEquals('Line count', 3, Message.GetOutputLineCount);
        AssertTrue('Contains line 1', Pos('Line 1', Message.GetFullOutput) > 0);
      finally
        Message.Free;
      end;
    finally
      Reader.Free;
    end;
  finally
    Buffer.Free;
  end;
end;

procedure TestParseEvent;
var
  Input: RawByteString;
  Event: TAMIEvent;
begin
  Input := 'Event: Newchannel'#13#10 +
           'Privilege: call,all'#13#10 +
           'Channel: SIP/1001-00000001'#13#10 +
           'ChannelState: 0'#13#10 +
           'ChannelStateDesc: Down'#13#10 +
           'CallerIDNum: 1001'#13#10 +
           'CallerIDName: John Doe'#13#10 +
           'ConnectedLineNum: <unknown>'#13#10 +
           'Uniqueid: 1234567890.123'#13#10#13#10;
  
  Buffer := TAMIBuffer.Create;
  try
    Buffer.Append(@Input[1], Length(Input));
    Reader := TAMIReader.Create(Buffer);
    try
      Event := Reader.ReadMessage as TAMIEvent;
      try
        AssertNotNull('Event parsed', Event);
        AssertEquals('Event name', 'Newchannel', Event.GetEventName);
        AssertEquals('Event type', etNewchannel, Event.EventType);
        AssertEquals('Channel', 'SIP/1001-00000001', Event.GetField('Channel'));
        AssertEquals('CallerID', '1001', Event.GetField('CallerIDNum'));
      finally
        Event.Free;
      end;
    finally
      Reader.Free;
    end;
  finally
    Buffer.Free;
  end;
end;
```

---

## Summary and Best Practices

### Memory Management
1. **Always free messages** after processing
2. **Use try-finally blocks** for cleanup
3. **Compact buffers** periodically to avoid memory growth
4. **Monitor buffer sizes** in high-load scenarios

### Performance
1. **Choose appropriate buffer size** based on traffic
2. **Use event filters** to reduce processing overhead
3. **Cache event type lookups** (built-in with TAMIEventCache)
4. **Process high-priority events first**

### Error Handling
1. **Catch protocol exceptions** and log them
2. **Implement recovery mechanisms** for malformed data
3. **Monitor discarded bytes** to detect issues
4. **Validate message completeness** before parsing

### Thread Safety
1. **Use locks** when sharing parsers between threads
2. **Create separate parser instances** per thread when possible
3. **Synchronize UI updates** from event handlers
4. **Avoid blocking operations** in event callbacks

---

## Complete Documentation Index

✅ **Completed Sections**:
1. ami_types.pas - Core types, exceptions, data structures
2. ami_client.pas - Client class with all methods and examples
3. ami_actions.pas - All 100+ predefined actions
4. ami_events.pas - Event management system
5. ami_parser.pas - Protocol parsing and utilities

## Quick Reference Card

### Essential Operations
```pascal
// Connect
Client := TAMIClient.Create(Config);
if Client.Connect then
  WriteLn('Connected');

// Send action
Response := Client.Ping(5000);
if Assigned(Response) then
try
  if Response.IsSuccess then
    WriteLn('Success');
finally
  Response.Free;
end;

// Subscribe to events
Client.SubscribeToEvent('Newchannel', @OnNewChannel);
Client.SubscribeToEvent('Hangup', @OnHangup);

// Disconnect
Client.Disconnect;
Client.Free;
```

---

## Appendix A: Complete Event Type Reference

### Event Type Mapping Table

| Event Name | Event Type | Priority | Category | Description |
|------------|------------|----------|----------|-------------|
| **Call Control** |
| Newchannel | etNewchannel | 100 | CallControl | New channel created |
| Hangup | etHangup | 100 | CallControl | Channel terminated |
| HangupRequest | etHangupRequest | 100 | CallControl | Hangup requested |
| SoftHangupRequest | etSoftHangupRequest | 100 | CallControl | Soft hangup requested |
| Newstate | etNewstate | 75 | CallControl | Channel state changed |
| NewCallerid | etNewCallerid | 70 | CallControl | Caller ID changed |
| NewConnectedLine | etNewConnectedLine | 70 | CallControl | Connected line changed |
| NewExten | etNewExten | 25 | CallControl | Extension changed |
| DialBegin | etDialBegin | 90 | Dial | Dial started |
| DialEnd | etDialEnd | 90 | Dial | Dial completed |
| DialState | etDialState | 90 | Dial | Dial state changed |
| Hold | etHold | 70 | CallControl | Call placed on hold |
| Unhold | etUnhold | 70 | CallControl | Call taken off hold |
| **Queue Events** |
| QueueCallerJoin | etQueueCallerJoin | 60 | Queue | Caller joined queue |
| QueueCallerLeave | etQueueCallerLeave | 60 | Queue | Caller left queue |
| QueueCallerAbandon | etQueueCallerAbandon | 60 | Queue | Caller abandoned queue |
| QueueMemberAdded | etQueueMemberAdded | 55 | Queue | Member added to queue |
| QueueMemberRemoved | etQueueMemberRemoved | 55 | Queue | Member removed from queue |
| QueueMemberPause | etQueueMemberPause | 55 | Queue | Member paused/unpaused |
| QueueMemberStatus | etQueueMemberStatus | 55 | Queue | Member status update |
| QueueMemberPenalty | etQueueMemberPenalty | 55 | Queue | Member penalty changed |
| QueueParams | etQueueParams | 55 | Queue | Queue parameters |
| QueueMember | etQueueMember | 55 | Queue | Queue member info |
| QueueEntry | etQueueEntry | 60 | Queue | Queue entry info |
| **Bridge Events** |
| BridgeCreate | etBridgeCreate | 85 | Bridge | Bridge created |
| BridgeDestroy | etBridgeDestroy | 85 | Bridge | Bridge destroyed |
| BridgeEnter | etBridgeEnter | 85 | Bridge | Channel entered bridge |
| BridgeLeave | etBridgeLeave | 85 | Bridge | Channel left bridge |
| BridgeMerge | etBridgeMerge | 85 | Bridge | Bridges merged |
| LocalBridge | etLocalBridge | 85 | Bridge | Local channel bridge |
| **System Events** |
| FullyBooted | etFullyBooted | 80 | System | Asterisk fully booted |
| Shutdown | etShutdown | 80 | System | Asterisk shutting down |
| Reload | etReload | 30 | System | Module reloaded |
| Load | etLoad | 30 | System | Module loaded |
| Unload | etUnload | 30 | System | Module unloaded |
| CoreShowChannel | etCoreShowChannel | 25 | System | Channel details |
| **Conference Events** |
| ConfbridgeStart | etConfbridgeStart | 50 | Conference | Conference started |
| ConfbridgeEnd | etConfbridgeEnd | 50 | Conference | Conference ended |
| ConfbridgeJoin | etConfbridgeJoin | 50 | Conference | Participant joined |
| ConfbridgeLeave | etConfbridgeLeave | 50 | Conference | Participant left |
| ConfbridgeTalking | etConfbridgeTalking | 50 | Conference | Participant talking |
| **DTMF Events** |
| DTMFBegin | etDTMFBegin | 35 | DTMF | DTMF digit started |
| DTMFEnd | etDTMFEnd | 35 | DTMF | DTMF digit ended |
| **Variable Events** |
| VarSet | etVarSet | 20 | Variables | Variable set |
| **User Events** |
| UserEvent | etUserEvent | 20 | UserEvent | Custom user event |

---

## Appendix B: AMI Protocol Specification

### Message Format

#### Standard Message
```
Field1: Value1
Field2: Value2
Field3: Value3

```

**Rules**:
- Each field on separate line
- Format: `Key: Value`
- Terminated by double CRLF (`\r\n\r\n`)
- Keys are case-insensitive
- Values may contain spaces

#### Command Response
```
Response: Follows
Privilege: Command
ActionID: cmd-123
Line 1 of output
Line 2 of output
Line 3 of output
--END COMMAND--

```

**Rules**:
- Starts with `Response: Follows`
- Output lines have no key prefix
- Terminated by `--END COMMAND--` + CRLF CRLF

#### Welcome Message
```
Asterisk Call Manager/2.10.0

```

**Rules**:
- First message after connection
- Single line terminated by CRLF
- No fields

---

### Field Types

#### Common Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| ActionID | String | Unique action identifier | ami_1234567890_123_456_000001 |
| Response | Enum | Response status | Success, Error, Follows |
| Message | String | Human-readable message | Authentication accepted |
| Event | String | Event name | Newchannel |
| Privilege | CSV | Event privilege level | call,all |
| Channel | String | Channel name | SIP/1001-00000001 |
| Uniqueid | String | Unique channel ID | 1234567890.123 |
| CallerIDNum | String | Caller ID number | 1001 |
| CallerIDName | String | Caller ID name | John Doe |
| Context | String | Dialplan context | from-internal |
| Exten/Extension | String | Extension | 100 |
| Priority | Integer/String | Dialplan priority | 1 |
| State | Integer | Channel state code | 6 |
| StateDesc | String | Channel state description | Up |

---

### Response Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| Success | Action completed successfully | Continue |
| Error | Action failed | Check Message field for reason |
| Follows | Multi-line response follows | Read until --END COMMAND-- |

---

### Channel State Codes

| Code | State | Description |
|------|-------|-------------|
| 0 | Down | Channel is down and available |
| 1 | Rsrvd | Channel is reserved |
| 2 | OffHook | Channel is off hook |
| 3 | Dialing | Digits have been dialed |
| 4 | Ring | Channel is ringing |
| 5 | Ringing | Remote end is ringing |
| 6 | Up | Line is up |
| 7 | Busy | Line is busy |
| 8 | Dialing Offhook | Digits dialed while offhook |
| 9 | Pre-ring | Channel reserved, waiting to ring |

---

## Appendix C: Common Patterns and Recipes

### Pattern 1: Click-to-Call

```pascal
function InitiateClickToCall(const Extension, Number: String): Boolean;
var
  Params: TOriginateParams;
  Response: TAMIResponse;
begin
  Result := False;
  
  Params := Default(TOriginateParams);
  Params.Channel := 'Local/' + Extension + '@from-internal';
  Params.Context := 'from-internal';
  Params.Extension := Number;
  Params.Priority := '1';
  Params.CallerID := 'Click-to-Call <9999>';
  Params.Timeout := 30000;
  Params.Async := True;
  
  Response := Client.Originate(Params, 60000);
  if Assigned(Response) then
  try
    Result := Response.IsSuccess;
    if not Result then
      ShowMessage('Call failed: ' + Response.Message);
  finally
    Response.Free;
  end;
end;

// Usage
if InitiateClickToCall('1001', '555-1234') then
  WriteLn('Call initiated');
```

---

### Pattern 2: Queue Member Management

```pascal
type
  TQueueMemberManager = class
  private
    FClient: TAMIClient;
  public
    constructor Create(AClient: TAMIClient);
    
    function AddMember(const Queue, Member: String; Penalty: Integer = 0): Boolean;
    function RemoveMember(const Queue, Member: String): Boolean;
    function PauseMember(const Queue, Member: String): Boolean;
    function UnpauseMember(const Queue, Member: String): Boolean;
    function SetPenalty(const Queue, Member: String; Penalty: Integer): Boolean;
  end;

constructor TQueueMemberManager.Create(AClient: TAMIClient);
begin
  FClient := AClient;
end;

function TQueueMemberManager.AddMember(const Queue, Member: String; Penalty: Integer): Boolean;
var
  Action: TAMIQueueAddAction;
  Response: TAMIResponse;
begin
  Result := False;
  
  Action := TAMIQueueAddAction.Create(Queue, Member, Penalty, False);
  try
    Response := FClient.SendAction(Action, 30000);
    if Assigned(Response) then
    try
      Result := Response.IsSuccess;
    finally
      Response.Free;
    end;
  finally
    Action.Free;
  end;
end;

function TQueueMemberManager.PauseMember(const Queue, Member: String): Boolean;
var
  Action: TAMIQueuePauseAction;
  Response: TAMIResponse;
begin
  Result := False;
  
  Action := TAMIQueuePauseAction.Create(Queue, Member, True);
  try
    Response := FClient.SendAction(Action, 30000);
    if Assigned(Response) then
    try
      Result := Response.IsSuccess;
    finally
      Response.Free;
    end;
  finally
    Action.Free;
  end;
end;

// Usage
var
  Manager: TQueueMemberManager;
begin
  Manager := TQueueMemberManager.Create(Client);
  
  if Manager.AddMember('support', 'SIP/1001', 0) then
    WriteLn('Member added');
    
  if Manager.PauseMember('support', 'SIP/1001') then
    WriteLn('Member paused');
end;
```

---

### Pattern 3: Real-time Call Recording

```pascal
type
  TCallRecorder = class
  private
    FClient: TAMIClient;
    FRecordings: TDictionary<String, String>;  // Channel -> Filename
    FRecordPath: String;
    
    procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
  public
    constructor Create(AClient: TAMIClient; const ARecordPath: String);
    destructor Destroy; override;
    
    procedure StartRecording(const Channel: String);
    procedure StopRecording(const Channel: String);
  end;

constructor TCallRecorder.Create(AClient: TAMIClient; const ARecordPath: String);
begin
  FClient := AClient;
  FRecordPath := ARecordPath;
  FRecordings := TDictionary<String, String>.Create;
  
  // Subscribe to events
  FClient.SubscribeToEvent('Newchannel', @OnNewChannel);
  FClient.SubscribeToEvent('Hangup', @OnHangup);
end;

destructor TCallRecorder.Destroy;
begin
  FRecordings.Free;
  inherited;
end;

procedure TCallRecorder.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  Channel: String;
begin
  Channel := Event.GetField('Channel');
  
  // Auto-start recording for certain channels
  if StartsText('SIP/support-', Channel) then
    StartRecording(Channel);
end;

procedure TCallRecorder.StartRecording(const Channel: String);
var
  Action: TAMIMixMonitorAction;
  Filename: String;
  Response: TAMIResponse;
begin
  Filename := Format('%s/recording-%s-%s.wav', [
    FRecordPath,
    FormatDateTime('yyyymmdd-hhnnss', Now),
    StringReplace(Channel, '/', '-', [rfReplaceAll])
  ]);
  
  Action := TAMIMixMonitorAction.Create(Channel, Filename, 'b');
  try
    Response := FClient.SendAction(Action, 30000);
    if Assigned(Response) then
    try
      if Response.IsSuccess then
      begin
        FRecordings.Add(Channel, Filename);
        WriteLn('Recording started: ', Filename);
      end;
    finally
      Response.Free;
    end;
  finally
    Action.Free;
  end;
end;

procedure TCallRecorder.OnHangup(Sender: TObject; const Event: TAMIEvent);
var
  Channel, Filename: String;
begin
  Channel := Event.GetField('Channel');
  
  if FRecordings.TryGetValue(Channel, Filename) then
  begin
    WriteLn('Recording saved: ', Filename);
    FRecordings.Remove(Channel);
  end;
end;
```

---

### Pattern 4: Channel State Tracker

```pascal
type
  TChannelState = record
    Channel: String;
    UniqueID: String;
    State: String;
    CallerID: String;
    Extension: String;
    CreateTime: TDateTime;
    LastUpdate: TDateTime;
  end;

  TChannelTracker = class
  private
    FChannels: TDictionary<String, TChannelState>;
    FLock: TCriticalSection;
    
    procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
    procedure OnNewstate(Sender: TObject; const Event: TAMIEvent);
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
  public
    constructor Create(AClient: TAMIClient);
    destructor Destroy; override;
    
    function GetChannelState(const Channel: String): TChannelState;
    function GetActiveChannels: TArray<TChannelState>;
    function GetChannelCount: Integer;
  end;

constructor TChannelTracker.Create(AClient: TAMIClient);
begin
  FChannels := TDictionary<String, TChannelState>.Create;
  FLock := TCriticalSection.Create;
  
  AClient.SubscribeToEvent('Newchannel', @OnNewChannel);
  AClient.SubscribeToEvent('Newstate', @OnNewstate);
  AClient.SubscribeToEvent('Hangup', @OnHangup);
end;

destructor TChannelTracker.Destroy;
begin
  FLock.Free;
  FChannels.Free;
  inherited;
end;

procedure TChannelTracker.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  State: TChannelState;
begin
  State := Default(TChannelState);
  State.Channel := Event.GetField('Channel');
  State.UniqueID := Event.GetField('Uniqueid');
  State.State := Event.GetField('ChannelStateDesc');
  State.CallerID := Event.GetField('CallerIDNum');
  State.Extension := Event.GetField('Exten');
  State.CreateTime := Now;
  State.LastUpdate := Now;
  
  FLock.Enter;
  try
    FChannels.AddOrSetValue(State.Channel, State);
  finally
    FLock.Leave;
  end;
  
  WriteLn('Channel created: ', State.Channel, ' (', State.CallerID, ')');
end;

procedure TChannelTracker.OnNewstate(Sender: TObject; const Event: TAMIEvent);
var
  Channel: String;
  State: TChannelState;
begin
  Channel := Event.GetField('Channel');
  
  FLock.Enter;
  try
    if FChannels.TryGetValue(Channel, State) then
    begin
      State.State := Event.GetField('ChannelStateDesc');
      State.LastUpdate := Now;
      FChannels[Channel] := State;
      
      WriteLn('Channel state: ', Channel, ' -> ', State.State);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TChannelTracker.OnHangup(Sender: TObject; const Event: TAMIEvent);
var
  Channel: String;
  State: TChannelState;
  Duration: Integer;
begin
  Channel := Event.GetField('Channel');
  
  FLock.Enter;
  try
    if FChannels.TryGetValue(Channel, State) then
    begin
      Duration := SecondsBetween(Now, State.CreateTime);
      WriteLn('Channel hangup: ', Channel, ' (duration: ', Duration, 's)');
      FChannels.Remove(Channel);
    end;
  finally
    FLock.Leave;
  end;
end;

function TChannelTracker.GetActiveChannels: TArray<TChannelState>;
var
  List: TList<TChannelState>;
  Channel: String;
begin
  List := TList<TChannelState>.Create;
  try
    FLock.Enter;
    try
      for Channel in FChannels.Keys do
        List.Add(FChannels[Channel]);
    finally
      FLock.Leave;
    end;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TChannelTracker.GetChannelCount: Integer;
begin
  FLock.Enter;
  try
    Result := FChannels.Count;
  finally
    FLock.Leave;
  end;
end;

// Usage
var
  Tracker: TChannelTracker;
  Channels: TArray<TChannelState>;
  Channel: TChannelState;
begin
  Tracker := TChannelTracker.Create(Client);
  try
    // Wait for events...
    Sleep(60000);
    
    // Get snapshot
    Channels := Tracker.GetActiveChannels;
    WriteLn('Active channels: ', Length(Channels));
    
    for Channel in Channels do
    begin
      WriteLn('  ', Channel.Channel);
      WriteLn('    State: ', Channel.State);
      WriteLn('    CallerID: ', Channel.CallerID);
      WriteLn('    Duration: ', SecondsBetween(Now, Channel.CreateTime), 's');
    end;
  finally
    Tracker.Free;
  end;
end;
```

---

### Pattern 5: Automatic Failover Connection

```pascal
type
  TFailoverAMIClient = class
  private
    FPrimaryClient: TAMIClient;
    FSecondaryClient: TAMIClient;
    FActiveClient: TAMIClient;
    FPrimaryConfig: TAMIClientConfig;
    FSecondaryConfig: TAMIClientConfig;
    
    procedure OnPrimaryDisconnect(Sender: TObject);
    procedure OnSecondaryDisconnect(Sender: TObject);
    procedure SwitchToSecondary;
    procedure SwitchToPrimary;
  public
    constructor Create(const APrimaryConfig, ASecondaryConfig: TAMIClientConfig);
    destructor Destroy; override;
    
    function Connect: Boolean;
    function GetActiveClient: TAMIClient;
    property ActiveClient: TAMIClient read GetActiveClient;
  end;

constructor TFailoverAMIClient.Create(const APrimaryConfig, ASecondaryConfig: TAMIClientConfig);
begin
  FPrimaryConfig := APrimaryConfig;
  FSecondaryConfig := ASecondaryConfig;
  
  FPrimaryClient := TAMIClient.Create(FPrimaryConfig);
  FPrimaryClient.OnDisconnect := @OnPrimaryDisconnect;
  
  FSecondaryClient := TAMIClient.Create(FSecondaryConfig);
  FSecondaryClient.OnDisconnect := @OnSecondaryDisconnect;
  
  FActiveClient := FPrimaryClient;
end;

destructor TFailoverAMIClient.Destroy;
begin
  FPrimaryClient.Free;
  FSecondaryClient.Free;
  inherited;
end;

function TFailoverAMIClient.Connect: Boolean;
begin
  WriteLn('Attempting primary connection...');
  Result := FPrimaryClient.Connect;
  
  if Result then
  begin
    FActiveClient := FPrimaryClient;
    WriteLn('Connected to primary server');
  end
  else
  begin
    WriteLn('Primary failed, trying secondary...');
    Result := FSecondaryClient.Connect;
    
    if Result then
    begin
      FActiveClient := FSecondaryClient;
      WriteLn('Connected to secondary server');
    end
    else
      WriteLn('Both servers unavailable');
  end;
end;

procedure TFailoverAMIClient.OnPrimaryDisconnect(Sender: TObject);
begin
  WriteLn('Primary server disconnected');
  
  if FActiveClient = FPrimaryClient then
  begin
    WriteLn('Failing over to secondary...');
    SwitchToSecondary;
  end;
end;

procedure TFailoverAMIClient.OnSecondaryDisconnect(Sender: TObject);
begin
  WriteLn('Secondary server disconnected');
  
  if FActiveClient = FSecondaryClient then
  begin
    WriteLn('Attempting reconnect to primary...');
    SwitchToPrimary;
  end;
end;

procedure TFailoverAMIClient.SwitchToSecondary;
begin
  if FSecondaryClient.Connect then
  begin
    FActiveClient := FSecondaryClient;
    WriteLn('Failover successful');
  end
  else
  begin
    WriteLn('Failover failed - retrying primary...');
    Sleep(5000);
    if FPrimaryClient.Connect then
      FActiveClient := FPrimaryClient;
  end;
end;

procedure TFailoverAMIClient.SwitchToPrimary;
begin
  if FPrimaryClient.Connect then
  begin
    FActiveClient := FPrimaryClient;
    WriteLn('Switched back to primary');
  end;
end;

function TFailoverAMIClient.GetActiveClient: TAMIClient;
begin
  Result := FActiveClient;
end;

// Usage
var
  PrimaryConfig, SecondaryConfig: TAMIClientConfig;
  FailoverClient: TFailoverAMIClient;
  Response: TAMIResponse;
begin
  PrimaryConfig := Default(TAMIClientConfig);
  PrimaryConfig.Host := '192.168.1.100';
  PrimaryConfig.Port := 5038;
  // ... other settings
  
  SecondaryConfig := Default(TAMIClientConfig);
  SecondaryConfig.Host := '192.168.1.101';
  SecondaryConfig.Port := 5038;
  // ... other settings
  
  FailoverClient := TFailoverAMIClient.Create(PrimaryConfig, SecondaryConfig);
  try
    if FailoverClient.Connect then
    begin
      // Use active client
      Response := FailoverClient.ActiveClient.Ping(5000);
      if Assigned(Response) then
      try
        WriteLn('Ping: ', Response.Response);
      finally
        Response.Free;
      end;
    end;
  finally
    FailoverClient.Free;
  end;
end;
```

---

### Pattern 6: Event Statistics Collector

```pascal
type
  TEventStatistics = record
    EventName: String;
    Count: Int64;
    FirstSeen: TDateTime;
    LastSeen: TDateTime;
    AvgPerSecond: Double;
  end;

  TEventStatsCollector = class
  private
    FStats: TDictionary<String, TEventStatistics>;
    FLock: TCriticalSection;
    FStartTime: TDateTime;
    
    procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
  public
    constructor Create(AClient: TAMIClient);
    destructor Destroy; override;
    
    function GetStatistics(const EventName: String): TEventStatistics;
    function GetAllStatistics: TArray<TEventStatistics>;
    function GetTopEvents(Count: Integer): TArray<TEventStatistics>;
    procedure Reset;
    procedure PrintReport;
  end;

constructor TEventStatsCollector.Create(AClient: TAMIClient);
begin
  FStats := TDictionary<String, TEventStatistics>.Create;
  FLock := TCriticalSection.Create;
  FStartTime := Now;
  
  AClient.OnEvent := @OnEvent;
end;

destructor TEventStatsCollector.Destroy;
begin
  FLock.Free;
  FStats.Free;
  inherited;
end;

procedure TEventStatsCollector.OnEvent(Sender: TObject; const Event: TAMIEvent);
var
  EventName: String;
  Stats: TEventStatistics;
  ElapsedSec: Double;
begin
  EventName := Event.GetEventName;
  
  FLock.Enter;
  try
    if FStats.TryGetValue(EventName, Stats) then
    begin
      Inc(Stats.Count);
      Stats.LastSeen := Now;
    end
    else
    begin
      Stats := Default(TEventStatistics);
      Stats.EventName := EventName;
      Stats.Count := 1;
      Stats.FirstSeen := Now;
      Stats.LastSeen := Now;
    end;
    
    // Calculate average
    ElapsedSec := (Now - FStartTime) * 24 * 60 * 60;
    if ElapsedSec > 0 then
      Stats.AvgPerSecond := Stats.Count / ElapsedSec;
    
    FStats.AddOrSetValue(EventName, Stats);
  finally
    FLock.Leave;
  end;
end;

function TEventStatsCollector.GetTopEvents(Count: Integer): TArray<TEventStatistics>;
var
  List: TList<TEventStatistics>;
  EventName: String;
begin
  List := TList<TEventStatistics>.Create;
  try
    FLock.Enter;
    try
      for EventName in FStats.Keys do
        List.Add(FStats[EventName]);
    finally
      FLock.Leave;
    end;
    
    // Sort by count descending
    List.Sort(TComparer<TEventStatistics>.Construct(
      function(const A, B: TEventStatistics): Integer
      begin
        Result := CompareValue(B.Count, A.Count);
      end));
    
    // Take top N
    if List.Count > Count then
      List.Count := Count;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TEventStatsCollector.PrintReport;
var
  TopEvents: TArray<TEventStatistics>;
  Event: TEventStatistics;
  Uptime: Double;
begin
  Uptime := (Now - FStartTime) * 24 * 60 * 60;
  
  WriteLn('=== Event Statistics Report ===');
  WriteLn('Uptime: ', FormatFloat('0.0', Uptime), ' seconds');
  WriteLn('');
  WriteLn(Format('%-30s %10s %15s', ['Event Name', 'Count', 'Avg/sec']));
  WriteLn(StringOfChar('-', 60));
  
  TopEvents := GetTopEvents(20);
  for Event in TopEvents do
  begin
    WriteLn(Format('%-30s %10d %15.2f', [
      Event.EventName,
      Event.Count,
      Event.AvgPerSecond
    ]));
  end;
end;

// Usage
var
  Collector: TEventStatsCollector;
begin
  Collector := TEventStatsCollector.Create(Client);
  try
    // Let it collect for a while
    Sleep(60000);
    
    // Print report
    Collector.PrintReport;
  finally
    Collector.Free;
  end;
end;
```

---

## Appendix D: Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Connection Timeout
**Symptoms**: Connection attempt times out, no welcome message received

**Possible Causes**:
1. Firewall blocking port 5038
2. Asterisk AMI not enabled
3. Wrong host/port configuration
4. Network connectivity issues

**Solutions**:
```pascal
// Enable detailed logging
Config.OnLog := procedure(Sender: TObject; Level: TAMILogLevel; const Msg: String)
begin
  WriteLn(Format('[%s] %s', [GetEnumName(TypeInfo(TAMILogLevel), Ord(Level)), Msg]));
end;

// Test with telnet first
// telnet <host> 5038

// Verify manager.conf on Asterisk
// [general]
// enabled = yes
// port = 5038
// bindaddr = 0.0.0.0
```

---

#### Issue 2: Authentication Failed
**Symptoms**: Connection succeeds but authentication fails

**Possible Causes**:
1. Wrong username/password
2. User permissions insufficient
3. MD5 challenge mismatch

**Solutions**:
```pascal
// Try plain authentication first
Config.AuthType := 'plain';

// Check manager.conf on Asterisk
// [myuser]
// secret = mypassword
// read = all
// write = all

// Enable auth logging
Client.OnLog := procedure(Sender: TObject; Level: TAMILogLevel; const Msg: String)
begin
  if (Level >= llWarning) or (Pos('auth', LowerCase(Msg)) > 0) then
    WriteLn(Msg);
end;
```

---

#### Issue 3: No Events Received
**Symptoms**: Connected but no events arrive

**Possible Causes**:
1. Event mask too restrictive
2. No activity on Asterisk
3. Event subscription not working

**Solutions**:
```pascal
// Set event mask to receive all events
Client.SetEventMask('on');

// Subscribe to common events
Client.SubscribeToEvent('Newchannel', @OnNewChannel);
Client.SubscribeToEvent('Hangup', @OnHangup);

// Enable event logging
Client.OnEvent := procedure(Sender: TObject; const Event: TAMIEvent)
begin
  WriteLn('EVENT: ', Event.GetEventName);
end;

// Generate test event
Response := Client.Command('channel originate Local/100@from-internal extension 100@from-internal');
```

---

#### Issue 4: Memory Leaks
**Symptoms**: Memory usage grows over time

**Possible Causes**:
1. Not freeing responses after SendAction
2. Event handlers holding references
3. Pending actions not cleaned up
4. Cache growing unbounded

**Solutions**:
```pascal
// ALWAYS free responses
Response := Client.Ping(5000);
if Assigned(Response) then
try
  // Use response
  WriteLn(Response.Response);
finally
  Response.Free;  // <-- CRITICAL
end;

// Don't store event references
procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
begin
  // BAD: Storing reference
  // FStoredEvent := Event;  // <-- Event will be freed!
  
  // GOOD: Copy needed data
  FChannelName := Event.GetField('Channel');
  FUniqueID := Event.GetField('Uniqueid');
end;

// Periodic cache cleanup
Timer.OnTimer := procedure
begin
  Client.CleanupCaches(60);  // Remove entries older than 1 hour
end;

// Monitor memory with heaptrc
{$IFDEF DEBUG}
{$APPTYPE CONSOLE}
{$ENDIF}

// Add to project .lpr
uses
  {$IFDEF DEBUG}
  heaptrc,
  {$ENDIF}
  ...

// Check for leaks on exit
```

**Memory Leak Detection**:
```pascal
program TestMemoryLeaks;

{$mode objfpc}{$H+}
{$APPTYPE CONSOLE}

uses
  {$IFDEF DEBUG}
  heaptrc,
  {$ENDIF}
  SysUtils, ami_client, ami_types, ami_actions;

var
  Client: TAMIClient;
  Response: TAMIResponse;
  Config: TAMIClientConfig;
  i: Integer;
begin
  {$IFDEF DEBUG}
  SetHeapTraceOutput('heap.log');
  {$ENDIF}
  
  Config := Default(TAMIClientConfig);
  Config.Host := 'localhost';
  Config.Port := 5038;
  Config.Username := 'admin';
  Config.Password := 'secret';
  
  Client := TAMIClient.Create(Config);
  try
    if Client.Connect then
    begin
      // Test 1000 ping operations
      for i := 1 to 1000 do
      begin
        Response := Client.Ping(5000);
        if Assigned(Response) then
          Response.Free;  // <-- Must free
          
        if (i mod 100) = 0 then
          WriteLn('Iteration ', i);
      end;
      
      Client.Disconnect;
    end;
  finally
    Client.Free;
  end;
  
  WriteLn('Check heap.log for memory leaks');
end.
```

---

#### Issue 5: Action Timeouts
**Symptoms**: Actions frequently timeout without response

**Possible Causes**:
1. Asterisk overloaded
2. Network latency high
3. Timeout value too low
4. Response not being processed

**Solutions**:
```pascal
// Increase timeout
Response := Client.Ping(30000);  // 30 seconds instead of 5

// Check network latency
StartTime := Now;
Response := Client.Ping(10000);
if Assigned(Response) then
try
  Latency := MilliSecondsBetween(Now, StartTime);
  WriteLn('Latency: ', Latency, 'ms');
  
  if Latency > 1000 then
    WriteLn('WARNING: High latency detected');
finally
  Response.Free;
end;

// Monitor pending actions
Client.OnLog := procedure(Sender: TObject; Level: TAMILogLevel; const Msg: String)
begin
  if Pos('timeout', LowerCase(Msg)) > 0 then
    WriteLn('TIMEOUT: ', Msg);
end;

// Check Asterisk load
Response := Client.Command('core show sysinfo');
if Assigned(Response) and (Response is TAMICommandResponse) then
try
  WriteLn(TAMICommandResponse(Response).GetFullOutput);
finally
  Response.Free;
end;
```

---

#### Issue 6: Reconnection Loops
**Symptoms**: Client constantly reconnecting and disconnecting

**Possible Causes**:
1. Authentication continuously failing
2. Asterisk rejecting connections
3. Network instability
4. Reconnection settings too aggressive

**Solutions**:
```pascal
// Adjust reconnection settings
Config.MaxReconnectAttempts := 5;  // Limit attempts
Config.ReconnectInterval := 10000;  // 10 seconds between attempts
Config.ReconnectBackoff := True;   // Use exponential backoff

// Monitor reconnection
Client.OnConnect := procedure(Sender: TObject)
begin
  WriteLn('Connected at ', FormatDateTime('hh:nn:ss', Now));
end;

Client.OnDisconnect := procedure(Sender: TObject)
begin
  WriteLn('Disconnected at ', FormatDateTime('hh:nn:ss', Now));
  WriteLn('Status: ', GetEnumName(TypeInfo(TAMIClientStatus), Ord(Client.Status)));
end;

// Disable auto-reconnect for debugging
Config.MaxReconnectAttempts := 0;
```

---

#### Issue 7: Thread Deadlocks
**Symptoms**: Application freezes or hangs

**Possible Causes**:
1. UI update in event handler without TThread.Synchronize
2. Long-blocking operations in callbacks
3. Lock contention

**Solutions**:
```pascal
// WRONG: Direct UI update from event
procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
begin
  Memo1.Lines.Add(Event.GetEventName);  // <-- CRASH!
end;

// CORRECT: Use TThread.Synchronize
procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
var
  EventName: String;
begin
  EventName := Event.GetEventName;
  
  TThread.Synchronize(nil,
    procedure
    begin
      Memo1.Lines.Add(EventName);
    end);
end;

// Avoid long operations in callbacks
procedure OnEvent(Sender: TObject; const Event: TAMIEvent);
begin
  // BAD: Long database operation
  // SaveEventToDatabase(Event);  // <-- Blocks event processing
  
  // GOOD: Queue for background processing
  EventQueue.Add(Event.GetEventName, Event.GetField('Channel'));
end;

// Use background thread for processing
TThread.CreateAnonymousThread(
  procedure
  var
    EventData: TEventData;
  begin
    while not Terminated do
    begin
      if EventQueue.TryDequeue(EventData) then
        SaveEventToDatabase(EventData);
      Sleep(10);
    end;
  end).Start;
```

---

#### Issue 8: Events Arriving Out of Order
**Symptoms**: Events processed in unexpected sequence

**Cause**: Network packet reordering or multiple threads

**Solution**:
```pascal
// Use UniqueID to correlate events
type
  TCallTracker = class
  private
    FCalls: TDictionary<String, TCallInfo>;  // UniqueID -> CallInfo
  public
    procedure OnNewChannel(Sender: TObject; const Event: TAMIEvent);
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
  end;

procedure TCallTracker.OnNewChannel(Sender: TObject; const Event: TAMIEvent);
var
  UniqueID: String;
  Info: TCallInfo;
begin
  UniqueID := Event.GetField('Uniqueid');
  
  Info := Default(TCallInfo);
  Info.Channel := Event.GetField('Channel');
  Info.StartTime := Now;
  
  FCalls.Add(UniqueID, Info);
end;

procedure TCallTracker.OnHangup(Sender: TObject; const Event: TAMIEvent);
var
  UniqueID: String;
  Info: TCallInfo;
begin
  UniqueID := Event.GetField('Uniqueid');
  
  if FCalls.TryGetValue(UniqueID, Info) then
  begin
    Info.EndTime := Now;
    Info.Duration := SecondsBetween(Info.EndTime, Info.StartTime);
    
    // Process completed call
    ProcessCompletedCall(Info);
    
    FCalls.Remove(UniqueID);
  end;
end;
```

---

## Appendix E: Performance Tuning

### Optimization Checklist

#### 1. Connection Settings
```pascal
// Production configuration
Config := Default(TAMIClientConfig);

// Network optimization
Config.BufferSize := 65536;           // 64KB buffer for high throughput
Config.ConnectionTimeout := 15000;     // Generous timeout for stability
Config.ResponseTimeout := 30000;       // Sufficient for slow responses

// Keep-alive optimization
Config.PingInterval := 60;             // Reduce ping frequency
Config.PingTimeout := 10;              // Quick ping timeout

// Reconnection optimization
Config.MaxReconnectAttempts := 10;     // Persistent reconnection
Config.ReconnectInterval := 5000;      // 5 second base interval
Config.ReconnectBackoff := True;       // Exponential backoff
```

---

#### 2. Event Filtering
```pascal
// Reduce event processing overhead
Client.SetEventMask('call,system');    // Only essential events

// Use event filters
Client.AddEventFilter('Newchannel', True);
Client.AddEventFilter('Hangup', True);
Client.AddEventFilter('DialBegin', True);
Client.AddEventFilter('DialEnd', True);

// Block noisy events
Client.AddEventFilter('VarSet', False);
Client.AddEventFilter('RTCPSent', False);
Client.AddEventFilter('RTCPReceived', False);
```

---

#### 3. Caching Strategy
```pascal
// Configure cache sizes based on load
const
  EVENT_CACHE_SIZE = 1000;      // Cache for 1000 unique event types
  RESPONSE_CACHE_SIZE = 500;     // Cache for 500 responses
  RESPONSE_CACHE_TTL = 300;      // 5 minutes TTL

// Use cached queries for expensive operations
function GetCachedQueueStatus(const Queue: String): TAMIResponse;
var
  CacheKey: String;
  Action: TAMIQueueStatusAction;
begin
  CacheKey := 'queue_' + Queue;
  
  Action := TAMIQueueStatusAction.Create(Queue);
  try
    Result := Client.SendCachedAction(Action, CacheKey, 30000);
  finally
    Action.Free;
  end;
end;

// Periodic cache cleanup
SetTimer(300000,  // 5 minutes
  procedure
  begin
    Client.CleanupCaches(60);  // Remove entries older than 1 hour
  end);
```

---

#### 4. Batch Operations
```pascal
// Bad: Send actions one by one synchronously
for i := 1 to 100 do
begin
  Response := Client.Ping(5000);
  if Assigned(Response) then
    Response.Free;
end;

// Good: Use async for batch operations
for i := 1 to 100 do
begin
  Client.SendActionAsync(TAMIPingAction.Create,
    procedure(Sender: TObject; const Response: TAMIResponse)
    begin
      // Handle response
      InterlockedIncrement(CompletedCount);
    end);
end;

// Wait for completion
while CompletedCount < 100 do
  Sleep(10);
```

---

#### 5. Memory Management
```pascal
// Reuse objects where possible
type
  TActionPool = class
  private
    FAvailable: TThreadList;
  public
    function Acquire: TAMIPingAction;
    procedure Release(Action: TAMIPingAction);
  end;

// Limit queue sizes
const
  MAX_PENDING_ACTIONS = 1000;

if PendingActionCount > MAX_PENDING_ACTIONS then
begin
  WriteLn('WARNING: Too many pending actions, throttling');
  Sleep(100);
end;

// Use string interning for repeated values
var
  InternedStrings: TDictionary<String, String>;

function Intern(const S: String): String;
begin
  if not InternedStrings.TryGetValue(S, Result) then
  begin
    Result := S;
    InternedStrings.Add(S, Result);
  end;
end;
```

---

#### 6. Thread Pool for Event Processing
```pascal
type
  TEventWorkerPool = class
  private
    FWorkers: array[0..7] of TThread;
    FEventQueue: TThreadedQueue<TAMIEvent>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure QueueEvent(const Event: TAMIEvent);
  end;

constructor TEventWorkerPool.Create;
var
  i: Integer;
begin
  FEventQueue := TThreadedQueue<TAMIEvent>.Create(1000, INFINITE, 100);
  
  for i := Low(FWorkers) to High(FWorkers) do
  begin
    FWorkers[i] := TThread.CreateAnonymousThread(
      procedure
      var
        Event: TAMIEvent;
      begin
        while not TThread.CurrentThread.CheckTerminated do
        begin
          if FEventQueue.PopItem(Event) = wrSignaled then
          begin
            try
              ProcessEvent(Event);
            finally
              Event.Free;
            end;
          end;
        end;
      end);
    FWorkers[i].Start;
  end;
end;

procedure TEventWorkerPool.QueueEvent(const Event: TAMIEvent);
begin
  FEventQueue.PushItem(Event);
end;
```

---

## Appendix F: Security Best Practices

### Secure Configuration

```pascal
// Use MD5 authentication
Config.AuthType := 'md5';

// Use TLS for encryption
Config.UseTLS := True;
Config.TLSVersion := '1.2';  // Minimum TLS 1.2
Config.VerifyCertificate := True;

// Store credentials securely (not in source code)
Config.Username := LoadFromSecureStore('ami_username');
Config.Password := LoadFromSecureStore('ami_password');

// Use restrictive event mask
Config.EventMask := 'call';  // Only call events, not system events

// Limit connection attempts
Config.MaxReconnectAttempts := 5;
```

---

### Asterisk manager.conf Security

```ini
[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1  ; Bind to localhost only

; Use separate users for different applications
[readonly_user]
secret = strong_password_here
read = all
write =   ; No write permissions

[limited_user]
secret = another_strong_password
read = call,system
write = call

; Enable encryption
tlsenable = yes
tlsbindaddr = 0.0.0.0:5039
tlscertfile = /etc/asterisk/keys/asterisk.pem
tlscafile = /etc/asterisk/keys/ca.pem
```

---

### Input Validation

```pascal
function SanitizeChannelName(const Channel: String): String;
begin
  // Remove potentially dangerous characters
  Result := Channel;
  Result := StringReplace(Result, ';', '', [rfReplaceAll]);
  Result := StringReplace(Result, '|', '', [rfReplaceAll]);
  Result := StringReplace(Result, '&', '', [rfReplaceAll]);
  Result := StringReplace(Result, '$', '', [rfReplaceAll]);
  Result := StringReplace(Result, '`', '', [rfReplaceAll]);
end;

function ValidateExtension(const Extension: String): Boolean;
begin
  // Only allow alphanumeric and basic symbols
  Result := TRegEx.IsMatch(Extension, '^[a-zA-Z0-9\-_]+$');
end;

// Use validation before originate
if not ValidateExtension(UserInput) then
  raise Exception.Create('Invalid extension format');
```

---

## Final Notes

### Library Version and Compatibility

**Current Version**: 1.0.0

**Asterisk Compatibility**:
- ✅ Asterisk 1.8+ (Basic AMI)
- ✅ Asterisk 11+ (ConfBridge)
- ✅ Asterisk 12+ (ARI Bridge, PJSIP)
- ✅ Asterisk 13+ (Enhanced PJSIP)
- ✅ Asterisk 16+ (All features)
- ✅ Asterisk 18+ (JSON protocol support)

**Free Pascal Compatibility**:
- Free Pascal 3.2.0+
- Lazarus 2.0.0+

---

### Migration Guide

#### From Older AMI Libraries

**Common Migration Patterns**:

```pascal
// OLD: Direct socket manipulation
Socket := TSocket.Create;
Socket.Connect(Host, Port);
Socket.SendText('Action: Ping\r\n\r\n');
Response := Socket.ReceiveText;

// NEW: High-level client
Client := TAMIClient.Create(Config);
if Client.Connect then
begin
  Response := Client.Ping(5000);
  if Assigned(Response) then
  try
    // Use response
  finally
    Response.Free;
  end;
end;

// OLD: Manual event parsing
if Pos('Event: Newchannel', Data) > 0 then
begin
  Channel := ExtractField(Data, 'Channel');
  // ...
end;

// NEW: Typed event handlers
Client.SubscribeToEvent('Newchannel',
  procedure(Sender: TObject; const Event: TAMIEvent)
  var
    Info: TChannelInfo;
  begin
    Info := TAMIEventParser.ParseChannelInfo(Event);
    // Use strongly-typed Info structure
  end);

// OLD: Manual action construction
Data := 'Action: Originate' + CRLF +
        'Channel: SIP/1001' + CRLF +
        'Context: default' + CRLF +
        'Exten: 100' + CRLF +
        'Priority: 1' + CRLF + CRLF;
Socket.Send(Data);

// NEW: Type-safe action builders
var
  Params: TOriginateParams;
begin
  Params := Default(TOriginateParams);
  Params.Channel := 'SIP/1001';
  Params.Context := 'default';
  Params.Extension := '100';
  Params.Priority := '1';
  
  Response := Client.Originate(Params, 30000);
end;
```

---

### Testing Framework Integration

#### FPCUnit Integration

```pascal
unit AMIClientTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  ami_client, ami_types, ami_actions;

type
  TTestAMIClient = class(TTestCase)
  private
    FClient: TAMIClient;
    FConfig: TAMIClientConfig;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestConnect;
    procedure TestPing;
    procedure TestOriginate;
    procedure TestQueueStatus;
    procedure TestEventHandling;
  end;

implementation

procedure TTestAMIClient.SetUp;
begin
  FConfig := Default(TAMIClientConfig);
  FConfig.Host := 'localhost';
  FConfig.Port := 5038;
  FConfig.Username := 'test';
  FConfig.Password := 'test';
  
  FClient := TAMIClient.Create(FConfig);
end;

procedure TTestAMIClient.TearDown;
begin
  FClient.Free;
end;

procedure TTestAMIClient.TestConnect;
begin
  AssertTrue('Should connect', FClient.Connect);
  AssertEquals('Status should be connected', csConnected, FClient.Status);
  
  FClient.Disconnect;
  AssertEquals('Status should be disconnected', csDisconnected, FClient.Status);
end;

procedure TTestAMIClient.TestPing;
var
  Response: TAMIResponse;
begin
  AssertTrue('Should connect', FClient.Connect);
  
  Response := FClient.Ping(5000);
  try
    AssertNotNull('Response should not be nil', Response);
    AssertTrue('Ping should succeed', Response.IsSuccess);
    AssertEquals('Response should be Pong', 'Pong', Response.Response);
  finally
    Response.Free;
  end;
end;

procedure TTestAMIClient.TestOriginate;
var
  Params: TOriginateParams;
  Response: TAMIResponse;
begin
  AssertTrue('Should connect', FClient.Connect);
  
  Params := Default(TOriginateParams);
  Params.Channel := 'Local/100@from-internal';
  Params.Application := 'Echo';
  Params.Async := True;
  
  Response := FClient.Originate(Params, 30000);
  try
    AssertNotNull('Response should not be nil', Response);
    // Note: May fail if channel doesn't exist, adjust test accordingly
  finally
    if Assigned(Response) then
      Response.Free;
  end;
end;

procedure TTestAMIClient.TestEventHandling;
var
  EventReceived: Boolean;
begin
  EventReceived := False;
  
  FClient.SubscribeToEvent('FullyBooted',
    procedure(Sender: TObject; const Event: TAMIEvent)
    begin
      EventReceived := True;
      AssertEquals('Event name should be FullyBooted', 
                   'FullyBooted', Event.GetEventName);
    end);
  
  AssertTrue('Should connect', FClient.Connect);
  
  // Wait for FullyBooted event
  Sleep(2000);
  
  AssertTrue('Should receive FullyBooted event', EventReceived);
end;

initialization
  RegisterTest(TTestAMIClient);

end.
```

---

### Continuous Integration Example

**GitHub Actions Workflow** (`.github/workflows/test.yml`):

```yaml
name: AMI Library Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      asterisk:
        image: andrius/asterisk:latest
        ports:
          - 5038:5038
        env:
          AMI_USER: test
          AMI_PASSWORD: test
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Install Free Pascal
      run: |
        sudo apt-get update
        sudo apt-get install -y fpc lcl
    
    - name: Build Library
      run: |
        cd src
        fpc -Mobjfpc -Sh ami_client.pas
    
    - name: Run Tests
      run: |
        cd tests
        fpc -Mobjfpc -Sh -Fu../src -Fu/usr/lib/fpc/3.2.0/units RunTests.pas
        ./RunTests
    
    - name: Generate Coverage Report
      run: |
        # Add coverage tool here
```

---

### Deployment Checklist

#### Production Deployment

```
☐ Security
  ☐ Use TLS/SSL encryption
  ☐ Use MD5 authentication
  ☐ Store credentials in secure vault
  ☐ Restrict Asterisk manager.conf permissions
  ☐ Use firewall rules to limit AMI access
  ☐ Enable audit logging

☐ Reliability
  ☐ Configure automatic reconnection
  ☐ Set appropriate timeouts
  ☐ Implement failover if needed
  ☐ Monitor connection health
  ☐ Set up alerts for disconnections

☐ Performance
  ☐ Tune buffer sizes for expected load
  ☐ Configure event filters
  ☐ Enable response caching where appropriate
  ☐ Set up periodic cache cleanup
  ☐ Monitor memory usage

☐ Monitoring
  ☐ Enable logging to file
  ☐ Set up log rotation
  ☐ Monitor failed actions
  ☐ Track event processing rate
  ☐ Alert on high error rates

☐ Documentation
  ☐ Document configuration settings
  ☐ Create runbook for common issues
  ☐ Document event handlers
  ☐ Maintain changelog
```

---

### Example Production Configuration

```pascal
function CreateProductionConfig: TAMIClientConfig;
begin
  Result := Default(TAMIClientConfig);
  
  // Connection
  Result.Host := GetEnvVar('AMI_HOST', 'localhost');
  Result.Port := StrToIntDef(GetEnvVar('AMI_PORT'), 5038);
  Result.Username := GetEnvVar('AMI_USERNAME');
  Result.Password := GetEnvVar('AMI_PASSWORD');
  
  // Security
  Result.AuthType := 'md5';
  Result.UseTLS := True;
  Result.TLSVersion := '1.2';
  Result.VerifyCertificate := True;
  
  // Timeouts (generous for production)
  Result.ConnectionTimeout := 30000;
  Result.ResponseTimeout := 60000;
  Result.ReadTimeout := 10000;
  Result.WriteTimeout := 10000;
  
  // Reconnection (persistent)
  Result.MaxReconnectAttempts := 0;  // Infinite
  Result.ReconnectInterval := 10000;
  Result.ReconnectBackoff := True;
  
  // Keep-alive
  Result.PingInterval := 60;
  Result.PingTimeout := 15;
  
  // Performance
  Result.BufferSize := 65536;
  Result.EventMask := 'call,system';
  
  // Logging
  Result.OnLog := @ProductionLogHandler;
end;

procedure ProductionLogHandler(Sender: TObject; Level: TAMILogLevel; const Msg: String);
var
  LogFile: TextFile;
  LogFileName: String;
begin
  // Only log warnings and errors in production
  if Level < llWarning then
    Exit;
  
  LogFileName := FormatDateTime('yyyymmdd', Now) + '_ami.log';
  
  AssignFile(LogFile, LogFileName);
  try
    if FileExists(LogFileName) then
      Append(LogFile)
    else
      Rewrite(LogFile);
    
    WriteLn(LogFile, Format('[%s] [%s] %s', [
      FormatDateTime('yyyy-mm-dd hh:nn:ss', Now),
      GetEnumName(TypeInfo(TAMILogLevel), Ord(Level)),
      Msg
    ]));
  finally
    CloseFile(LogFile);
  end;
  
  // Send critical errors to monitoring system
  if Level = llCritical then
    SendToMonitoring('AMI Critical Error: ' + Msg);
end;
```

---

### Monitoring Dashboard Example

```pascal
type
  TAMIMonitor = class
  private
    FClient: TAMIClient;
    FStartTime: TDateTime;
    FMetrics: record
      TotalConnections: Integer;
      FailedConnections: Integer;
      TotalActions: Int64;
      FailedActions: Int64;
      TotalEvents: Int64;
      LastEventTime: TDateTime;
      AvgResponseTime: Double;
    end;
  public
    constructor Create(AClient: TAMIClient);
    procedure UpdateMetrics;
    function GetHealthStatus: String;
    function GetMetricsJSON: String;
  end;

function TAMIMonitor.GetHealthStatus: String;
var
  Uptime: Integer;
  EventRate: Double;
begin
  Uptime := SecondsBetween(Now, FStartTime);
  EventRate := FClient.GetEventsPerSecond;
  
  Result := Format(
    'Status: %s, ' +
    'Uptime: %ds, ' +
    'Events: %d (%.2f/s), ' +
    'Actions: %d (%.1f%% success), ' +
    'Last Event: %ds ago',
    [
      GetEnumName(TypeInfo(TAMIClientStatus), Ord(FClient.Status)),
      Uptime,
      FClient.TotalEvents,
      EventRate,
      FClient.TotalActions,
      IfThen(FClient.TotalActions > 0,
             ((FClient.TotalActions - FClient.FailedActions) / FClient.TotalActions) * 100,
             100.0),
      SecondsBetween(Now, FMetrics.LastEventTime)
    ]);
end;

function TAMIMonitor.GetMetricsJSON: String;
begin
  Result := Format(
    '{'#13#10 +
    '  "status": "%s",'#13#10 +
    '  "uptime": %d,'#13#10 +
    '  "events": {'#13#10 +
    '    "total": %d,'#13#10 +
    '    "rate": %.2f'#13#10 +
    '  },'#13#10 +
    '  "actions": {'#13#10 +
    '    "total": %d,'#13#10 +
    '    "failed": %d,'#13#10 +
    '    "success_rate": %.2f'#13#10 +
    '  },'#13#10 +
    '  "cache": {'#13#10 +
    '    "event_cache": "%s",'#13#10 +
    '    "response_cache": "%s"'#13#10 +
    '  }'#13#10 +
    '}',
    [
      GetEnumName(TypeInfo(TAMIClientStatus), Ord(FClient.Status)),
      SecondsBetween(Now, FStartTime),
      FClient.TotalEvents,
      FClient.GetEventsPerSecond,
      FClient.TotalActions,
      FClient.FailedActions,
      IfThen(FClient.TotalActions > 0,
             ((FClient.TotalActions - FClient.FailedActions) / FClient.TotalActions) * 100,
             100.0),
      FClient.GetEventCacheStats,
      FClient.GetResponseCacheStats
    ]);
end;
```

---

## Conclusion

### What's Included

✅ **Complete AMI Protocol Support**
- 100+ predefined actions
- 180+ event types
- Both Key-Value and JSON formats
- Full Asterisk 1.8-18+ compatibility

✅ **Production-Ready Features**
- Thread-safe operations
- Automatic reconnection with exponential backoff
- Keep-alive mechanism
- LRU caching with TTL
- Graceful error handling
- Memory leak prevention

✅ **Developer-Friendly API**
- Type-safe action builders
- Strongly-typed event parsing
- Comprehensive error messages
- Extensive logging support
- Full documentation

✅ **Performance Optimized**
- Zero-copy parsing where possible
- Efficient buffer management
- Event priority queuing
- Response caching
- Configurable buffer sizes

---

### Getting Help

**Documentation**:
- API Reference (this document)
- Example programs in `/examples/`
- Unit tests in `/tests/`

**Community**:
- GitHub Issues: Report bugs and feature requests
- Discussions: Ask questions and share solutions

**Commercial Support**:
- Contact for enterprise support options
- Custom development available
- Training and consulting services

---

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

**Code Standards**:
- Follow Object Pascal style guide
- Document all public interfaces
- Add unit tests for new features
- Use meaningful variable names
- Comment complex algorithms

---

### License

**MIT License**

```
Copyright (c) 2026 AMI Library Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files