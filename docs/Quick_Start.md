### Quick Start Guide

# AMI Library - Quick Start

## Installation

1. Add library path to project:
   - Project → Project Inspector → Add → amilib/src

2. Add units to uses:
   ```pascal
   uses
     ami_client, ami_types, ami_actions, ami_enums;
   ```

## Basic Usage

### Connect and Authenticate

```pascal
var
  Config: TAMIClientConfig;
  Client: TAMIClient;
begin
  Config := Default(TAMIClientConfig);
  Config.Host := 'localhost';
  Config.Port := 5038;
  Config.Username := 'admin';
  Config.Password := 'secret';
  Config.AuthType := 'plain';
  
  Client := TAMIClient.Create(Config);
  try
    if Client.Connect then
    begin
      WriteLn('Connected!');
      // Use client...
      Client.Disconnect;
    end;
  finally
    Client.Free;
  end;
end;
```

### Send Actions

```pascal
var
  Response: TAMIResponse;
begin
  // Ping
  Response := Client.Ping(5000);
  if Assigned(Response) then
  try
    WriteLn('Pong: ', Response.Response);
  finally
    Response.Free;
  end;
  
  // Execute CLI command
  Response := Client.Command('core show version');
  if Assigned(Response) and (Response is TAMICommandResponse) then
  try
    WriteLn(TAMICommandResponse(Response).GetFullOutput);
  finally
    Response.Free;
  end;
  
  // Originate call
  var Params: TOriginateParams;
  Params.Channel := 'SIP/1001';
  Params.Context := 'default';
  Params.Extension := '100';
  Params.Priority := '1';
  
  Response := Client.Originate(Params, 30000);
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

### Handle Events

```pascal
type
  TMyApp = class
    procedure OnHangup(Sender: TObject; const Event: TAMIEvent);
  end;

procedure TMyApp.OnHangup(Sender: TObject; const Event: TAMIEvent);
begin
  WriteLn('Call ended: ', Event.GetField('Channel'));
end;

var
  App: TMyApp;
begin
  App := TMyApp.Create;
  try
    Client.SubscribeToEvent('Hangup', @App.OnHangup);
    
    // Events will be processed automatically
    while Client.IsConnected do
    begin
      Sleep(100);
      // Process UI events or other tasks
    end;
  finally
    App.Free;
  end;
end;
```

## Configuration Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ConnectionTimeout` | 10000ms | Socket connection timeout |
| `ResponseTimeout` | 30000ms | Action response timeout |
| `PingInterval` | 30s | Keep-alive ping interval |
| `MaxReconnectAttempts` | 5 | Auto-reconnect attempts (0=infinite) |
| `ReconnectInterval` | 5000ms | Delay between reconnect attempts |
| `ReconnectBackoff` | True | Use exponential backoff |
| `BufferSize` | 8192 | Socket buffer size |
| `UseJSON` | False | Enable JSON protocol (Asterisk 18+) |

## Error Handling

```pascal
try
  if Client.Connect then
  begin
    Response := Client.Ping(5000);
    if Assigned(Response) then
    try
      if not Response.IsSuccess then
        raise Exception.Create('Ping failed: ' + Response.Message);
    finally
      Response.Free;
    end
    else
      raise Exception.Create('No response received');
  end
  else
    raise Exception.Create('Connection failed');
except
  on E: Exception do
    WriteLn('Error: ', E.Message);
end;
```

## Thread Safety

All public methods are thread-safe. You can:
- Send actions from multiple threads
- Subscribe to events from different threads
- Connect/disconnect from any thread

Example:
```pascal
TThread.CreateAnonymousThread(
  procedure
  var
    Response: TAMIResponse;
  begin
    Response := Client.Ping(5000);
    if Assigned(Response) then
    try
      TThread.Synchronize(nil, 
        procedure
        begin
          Memo1.Lines.Add('Ping: ' + Response.Response);
        end);
    finally
      Response.Free;
    end;
  end).Start;
```
---
