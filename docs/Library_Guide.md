# AMILIB Library Guide

## Overview

AMILIB is a comprehensive Free Pascal library for interfacing with Asterisk PBX systems via the Asterisk Manager Interface (AMI). This guide provides in-depth understanding of the library's architecture, approaches, and working principles.

---

## Table of Contents

1. [What is Asterisk AMI?](#what-is-asterisk-ami)
2. [Library Architecture](#library-architecture)
3. [Core Concepts](#core-concepts)
4. [Main Classes](#main-classes)
5. [Approaches and Best Practices](#approaches-and-best-practices)
6. [Protocol Details](#protocol-details)
7. [Memory Management](#memory-management)
8. [Thread Safety](#thread-safety)
9. [Error Handling](#error-handling)

---

## What is Asterisk AMI?

Asterisk Manager Interface (AMI) is a TCP-based protocol that allows external applications to control and monitor Asterisk PBX. It provides:

- **Event monitoring**: Real-time notifications about call events, channel states, queue changes
- **Action execution**: Remote control of Asterisk (originate calls, queue management, etc.)
- **System status**: Querying Asterisk for various statistics and configurations

### AMI Protocol Structure

AMI uses a simple text-based protocol with `Key: Value` format:

```
Action: Login
Username: admin
Secret: secret

Action: Ping

Response: Success
Message: Authentication accepted
ActionID: 12345

Event: NewChannel
Channel: SIP/100-0001
CallerIDNum: 1001
```

### Message Types

1. **Action**: Commands sent from client to Asterisk
2. **Response**: Answers to actions from Asterisk
3. **Event**: Asynchronous notifications from Asterisk

---

## Library Architecture

AMILIB follows a layered architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│                      (TAMIClient)                           │
├─────────────────────────────────────────────────────────────┤
│                    Action Layer                            │
│              (TAMIAction, TAMIResponse)                     │
├─────────────────────────────────────────────────────────────┤
│                   Transport Layer                          │
│            (TAMITransport, TAMIReader)                     │
├─────────────────────────────────────────────────────────────┤
│                    Event Layer                             │
│              (IEventBus, TAMIEvent)                        │
├─────────────────────────────────────────────────────────────┤
│                   Network Layer                            │
│              (TTCPBlockSocket, TLS)                        │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Patterns

1. **Facade Pattern**: TAMIClient provides a unified interface to all library features
2. **Observer Pattern**: IEventBus implements publish-subscribe for events
3. **Factory Pattern**: TAMIActionFactory, TAMIEventFactory for creating actions/events
4. **Builder Pattern**: TOriginateParams for constructing complex originate commands
5. **Promise Pattern**: Async operations return ActionID immediately, result comes via callback

---

## Core Concepts

### 1. Client Connection

```pascal
var
  Client: TAMIClient;
  Config: TAMIClientConfig;
begin
  Config.Host := '127.0.0.1';
  Config.Port := 5038;
  Config.Username := 'admin';
  Config.Password := 'secret';
  
  Client := TAMIClient.Create(Config);
  try
    if Client.Connect then
    begin
      // Connected successfully
      Client.Disconnect;
    end;
  finally
    Client.Free;
  end;
end;
```

### 2. Sending Actions

**Synchronous:**
```pascal
Response := Client.SendAction(PingAction, 5000);
try
  if Response.IsSuccess then
    WriteLn('Success!');
finally
  Response.Free;
end;
```

**Asynchronous:**
```pascal
Client.SendActionAsync(PingAction, @OnPingResponse);
// PingAction is automatically freed by the client
```

### 3. Event Subscription

```pascal
// Subscribe to specific event
Client.OnEvent := @MyEventHandler;

// Or use EventBus directly
Client.SubscribeToEventAsync('NewChannel', @OnNewChannel, True, Self);
```

---

## Main Classes

### TAMIClient

The main class representing an AMI client connection.

**Key Properties:**
- `Connected`: Connection status (read-only)
- `Status`: Current client status (TClientStatus)
- `Config`: Current configuration
- `Transport`: Access to transport layer
- `OnEvent`: Event handler
- `OnResponse`: Response handler
- `OnLog`: Logging handler

**Key Methods:**
- `Connect`: Establish connection
- `Disconnect`: Close connection
- `SendAction`: Send action synchronously
- `SendActionAsync`: Send action asynchronously
- `Ping`: Send keep-alive ping
- `SubscribeToEventAsync`: Subscribe to events
- `UnsubscribeFromEventAsync`: Unsubscribe from events

### TAMITransport

Low-level TCP/TLS connection manager.

**Key Properties:**
- `Connected`: Socket connection status
- `LastError`: Last error description
- `BytesSent`: Total bytes sent
- `BytesReceived`: Total bytes received

**Key Methods:**
- `Connect`: Connect to server
- `Disconnect`: Close connection
- `Send`: Send raw data
- `Receive`: Receive data

### IEventBus

Event pub/sub system interface.

**Key Methods:**
- `Publish`: Publish event to all subscribers
- `Subscribe`: Subscribe to events
- `Unsubscribe`: Unsubscribe
- `GetStats`: Get queue statistics

### TAMIAction

Base class for all AMI actions.

### TAMIResponse

Represents AMI response from Asterisk.

**Key Properties:**
- `IsSuccess`: Check if response is successful
- `Message`: Response message
- `ActionID`: Action ID for correlation

### TAMIEvent

Represents AMI event from Asterisk.

**Key Properties:**
- `EventName`: Event name
- `EventType`: Event type (TAMIEventType)
- `GetField(FieldName)`: Get field value

---

## Approaches and Best Practices

### Synchronous vs Asynchronous

**Use Synchronous When:**
- Script execution
- Simple tools
- When result is needed immediately

**Use Asynchronous When:**
- GUI applications
- High-throughput scenarios
- Long-running operations

### Connection Management

1. **Always check connection status before sending actions**
2. **Implement reconnection logic for production**
3. **Use TLS in production environments**

### Event Handling

1. **Use event filtering to reduce processing**
2. **Process events in separate threads**
3. **Marshal UI updates to main thread**

### Error Handling

```pascal
try
  Response := Client.SendAction(Action, 5000);
  if Assigned(Response) then
  begin
    if Response.IsSuccess then
      HandleSuccess
    else
      HandleError(Response.Message);
  end;
except
  on E: EAMIConnectionException do
    HandleConnectionError;
  on E: EAMITimeoutException do
    HandleTimeout;
end;
```

---

## Protocol Details

### Authentication

**Plain Authentication:**
```
Action: Login
Username: admin
Secret: secret
```

**MD5 Authentication:**
```
Action: Login
Username: admin
AuthKey: challenge
Secret: md5(challenge + secret)
```

### Action Response Correlation

Each action has an ActionID that can be used to correlate requests and responses:

```pascal
Action.ActionID := 'unique-id-' + IntToStr(Random(10000));
Response := Client.SendAction(Action, 5000);
// Response.ActionID will match
```

### Multi-Part Responses

Some actions return multiple responses (e.g., QueueStatus). Use follow-up events:

```pascal
for i := 0 to Response.GetFollowUpEventCount - 1 do
  Event := Response.GetFollowUpEvent(i);
```

---

## Memory Management

### Ownership Rules

1. **TAMIAction**: Caller creates, caller frees (unless async)
2. **TAMIResponse**: Caller receives, caller frees
3. **TAMIEvent**: EventBus creates, clones for subscribers
4. **Subscriptions**: Auto-cleanup when owner is destroyed

### Best Practices

```pascal
// Correct: Always free actions
Action := TAMIPingAction.Create;
try
  Response := Client.SendAction(Action, 5000);
  try
    // Use response
  finally
    Response.Free;
  end;
finally
  Action.Free;
end;

// Correct: Async - client owns the action
Client.SendActionAsync(PingAction, @OnResponse);
// Don't free PingAction - client manages it
```

---

## Thread Safety

AMILIB is designed to be fully thread-safe:

- All shared resources are protected by critical sections
- Event bus uses worker thread pool
- Transport layer is thread-safe

### Guidelines

1. **Event handlers may be called from worker threads**
2. **Use ACallInMainThread=True for UI updates**
3. **Don't block in event handlers**
4. **Use thread-safe logging**

---

## Error Handling

### Exception Types

- `EAMIException`: Base exception
- `EAMIConnectionException`: Connection errors
- `EAMIAuthException`: Authentication failures
- `EAMITimeoutException`: Timeout errors
- `EAMIProtocolException`: Protocol errors

### Best Practices

1. Always check IsSuccess on responses
2. Inspect Response.Message for error details
3. Use try/except for network operations
4. Enable logging for debugging
5. Implement reconnection strategies

---

## Configuration Reference

| Property | Type | Description |
|----------|------|-------------|
| Host | string | Asterisk hostname or IP |
| Port | word | AMI port (default 5038) |
| Username | string | AMI username |
| Password | string | AMI password |
| AuthType | string | 'plain' or 'md5' |
| UseTLS | boolean | Enable TLS/SSL |
| UseIPv6 | boolean | Use IPv6 |
| ConnectionTimeout | integer | ms |
| ResponseTimeout | integer | ms |
| PingInterval | integer | seconds |
| MaxReconnectAttempts | integer | 0 = infinite |
| ReconnectInterval | integer | ms |
| MaxActionsPerSecond | integer | Rate limit |
| BufferSize | integer | Socket buffer size |
| EventMask | string | Event filter |

---

## Conclusion

AMILIB provides a comprehensive solution for Asterisk AMI integration in Free Pascal. Its design emphasizes:

- **Simplicity**: Easy to learn and use
- **Flexibility**: Multiple patterns for different scenarios
- **Reliability**: Thread-safety and error handling
- **Performance**: Caching, rate limiting, async operations

For more information, see:
- [API Reference](docs/Complete_API_Reference.md)
- [Quick Start](docs/Quick_Start.md)
- Example applications in `examples/` directory
