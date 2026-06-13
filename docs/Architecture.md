# AMILIB Architecture

## Introduction

This document describes the internal architecture of AMILIB, a Free Pascal library for Asterisk AMI. Understanding the architecture helps developers extend the library and troubleshoot issues.

---

## System Overview

AMILIB is organized into several logical layers, each responsible for specific functionality:

```
┌──────────────────────────────────────────────────────────────┐
│                        Application Layer                      │
│  TAMIClient, TAMIActionFactory, TAMIEventFactory              │
├──────────────────────────────────────────────────────────────┤
│                          Action Layer                         │
│  TAMIAction, TAMIResponse, TAMIPingAction, etc.              │
├──────────────────────────────────────────────────────────────┤
│                        Transport Layer                       │
│  TAMITransport, TAMIReader, TAMIWriter                       │
├──────────────────────────────────────────────────────────────┤
│                         Event Layer                          │
│  IEventBus, TThreadedEventBus, TAMIEvent                     │
├──────────────────────────────────────────────────────────────┤
│                        Network Layer                         │
│  TTCPBlockSocket, TLS (via Synapse)                          │
└──────────────────────────────────────────────────────────────┘
```

---

## Component Diagrams

### Connection Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   TAMI     │────▶│ TAMITransport│────▶│  TTCPBlock  │────▶│   Asterisk  │
│   Client   │     │             │     │   Socket    │     │   Server    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │                   
       │                   │                   │                   
       ▼                   ▼                   ▼                   
┌─────────────┐     ┌─────────────┐     ┌─────────────┐           
│  TAMIAction │     │  TAMIReader│     │  Network    │           
│  TAMIAction│◀────│  TAMIBuffer│◀────│   I/O       │           
└─────────────┘     └─────────────┘     └─────────────┘           
```

### Event Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Asterisk  │────▶│ TAMITransport│────▶│  TAMIReader │────▶│  TAMIEvent │
│   Server    │     │             │     │             │     │  Factory   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                    │
                                                                    ▼
                                                            ┌─────────────┐
                                                            │  IEventBus  │
                                                            │(Event Queue)│
                                                            └─────────────┘
                                                                    │
                                                                    ▼
                                                            ┌─────────────┐
                                                            │  Subscribers│
                                                            │(Handlers)   │
                                                            └─────────────┘
```

---

## Core Components

### 1. TAMIClient (Application Layer)

**Purpose**: Main facade class providing unified API to all library features.

**Responsibilities**:
- Connection lifecycle management
- Action sending (sync/async)
- Event distribution
- Configuration management
- Reconnection logic

**Key Interfaces**:
```pascal
TAMIClient = class
  property Config: TAMIClientConfig;
  property Connected: Boolean;
  property Status: TClientStatus;
  property Transport: TAMITransport;
  
  function Connect: Boolean;
  procedure Disconnect;
  function SendAction(AAction: TAMIAction; ATimeout: Integer): TAMIResponse;
  procedure SendActionAsync(AAction: TAMIAction; AOnResponse: TAMIResponseEvent);
  function Ping(ATimeout: Integer): TAMIResponse;
  function SubscribeToEventAsync(...): Integer;
  procedure UnsubscribeFromEventAsync(A subscriptionID: Integer);
end;
```

### 2. TAMITransport (Transport Layer)

**Purpose**: Low-level TCP/TLS connection management.

**Responsibilities**:
- TCP socket management
- TLS/SSL wrapper
- Data sending/receiving
- Connection monitoring
- Keep-alive handling

**State Machine**:
```
┌──────────┐
│  Closed  │◀───────────────────────────────┐
└────┬─────┘                                 │
     │ Connect()                             │
     ▼                                       ▼
┌──────────┐     ┌──────────┐     ┌──────────┐
│ Connecting│────▶│  Auth    │────▶│ Connected │
└──────────┘     └──────────┘     └────┬──────┘
                                       │ Disconnect/Error
                                       ▼
                                   ┌──────────┐
                                   │ Disconnected │
                                   └──────────┘
```

### 3. TAMIReader (Parser)

**Purpose**: Parse incoming AMI protocol data.

**Responsibilities**:
- Read data from socket
- Buffer management
- Message boundary detection
- Parse Key: Value format
- Create appropriate message objects

**Parsing Flow**:
```
Raw Data → TAMIBuffer → HasCompleteMessage → TAMIReader.ReadMessage
                                                        │
                                                        ▼
                                              TAMIResponse/TAMIEvent
```

### 4. IEventBus (Event Layer)

**Purpose**: Publish-subscribe event system.

**Implementations**:
- `TThreadedEventBus`: Multi-threaded with worker pool

**Architecture**:
```
┌─────────────────────────────────────────────────────────────┐
│                      TThreadedEventBus                     │
├─────────────────────────────────────────────────────────────┤
│  Event Queue (TAMIEventQueue)                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  TAMIEvent → TAMIEvent → TAMIEvent → ...           │  │
│  └─────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Worker Pool (4 threads by default)                       │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                         │
│  │ W1  │ │ W2  │ │ W3  │ │ W4  │                         │
│  └─────┘ └─────┘ └─────┘ └─────┘                         │
├─────────────────────────────────────────────────────────────┤
│  Subscribers (TEventSubscriber list)                      │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ S1(events) → S2(events) → S3(events) → ...        │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 5. Action Classes (Action Layer)

**Hierarchy**:
```
TAMIAction (abstract base)
├── TAMIActionWithCallback
│   ├── TAMIPingAction
│   ├── TAMILoginAction
│   ├── TAMIQueueStatusAction
│   └── ...
└── TAMIActionWithoutCallback
    ├── TAMIOriginateAction
    ├── TAMIHangupAction
    └── ...
```

### 6. Response Classes

**Hierarchy**:
```
TAMIMessage (abstract)
├── TAMIResponse
│   ├── TAMICommandResponse
│   └── TAMIDBGetResponse
└── TAMIEvent
```

---

## Data Flow

### Synchronous Action Flow

```
1. User creates TAMIAction
2. User calls Client.SendAction(Action, Timeout)
3. SendAction locks Transport
4. Transport sends action via TAMIWriter
5. Transport waits for response (with Timeout)
6. TAMIReader reads and parses response
7. Transport returns TAMIResponse
8. User processes response
9. User frees Action and Response
```

### Asynchronous Action Flow

```
1. User creates TAMIAction
2. User calls Client.SendActionAsync(Action, Callback)
3. Action is added to pending actions queue
4. SendActionAsync returns immediately with ActionID
5. Client processes response in background
6. When response arrives, callback is invoked
7. Client frees Action automatically
8. User frees Response in callback
```

### Event Flow

```
1. Asterisk sends event data
2. Transport receives data via TAMIBuffer
3. TAMIReader parses complete messages
4. TAMIEventFactory creates TAMIEvent objects
5. Events are published to IEventBus
6. EventBus enqueues events
7. Worker threads process events
8. Subscribers receive events via their handlers
```

---

## Threading Model

### Main Thread
- Creates and manages TAMIClient
- Handles UI updates (if Lazarus)
- Processes synchronous actions

### Network Thread (Transport)
- Dedicated socket I/O
- Receives data from Asterisk
- Triggers event parsing

### Worker Threads (EventBus)
- Process queued events
- Execute subscriber handlers
- Configurable pool size (default: 4)

### Thread Synchronization
- Critical sections protect shared data
- Reader-writer locks for queues
- Atomic operations for counters

---

## Memory Management

### Object Lifecycle

```
TAMIAction
├── Created by: User (for sync) or Factory (for async)
├── Used by: Transport
├── Freed by: User (sync) or Client (async)

TAMIResponse
├── Created by: Transport
├── Used by: User
├── Freed by: User

TAMIEvent
├── Created by: TAMIEventFactory
├── Used by: IEventBus, Subscribers
├── Freed by: Each subscriber (cloned) or EventBus (original)

TSubscriber
├── Created by: User via Subscribe()
├── Managed by: IEventBus (reference counted)
└── Freed by: Unsubscribe() or owner destruction
```

### Memory Pools

- TAMIBuffer: Pre-allocated buffers for network data
- TAMIEventCache: LRU cache for event objects
- TAMIResponseCache: Cache for command responses
- String interning: Common field names

---

## Extension Points

### Custom Actions

```pascal
TMyCustomAction = class(TAMIAction)
public
  constructor Create;
  function GetActionName: string; override;
  procedure AddFieldsToMessage(AMessage: TAMIMessage); override;
end;
```

### Custom Event Handlers

```pascal
type
  TMyEventHandler = class
    procedure HandleEvent(Sender: TObject; const AEvent: TAMIEvent);
  end;
```

### Custom Event Bus

```pascal
TMyEventBus = class(TInterfacedObject, IEventBus)
  // Implement IEventBus interface
end;
```

---

## Error Handling Architecture

### Exception Hierarchy

```
EAMIException (abstract)
├── EAMIConnectionException
│   ├── EAMITransportException
│   ├── EAMITLSException
│   └── EAMIIPException
├── EAMIAuthException
├── EAMITimeoutException
├── EAMIProtocolException
└── EAMIActionException
```

### Recovery Strategies

1. **Auto-reconnect**: Exponential backoff retry
2. **Action timeout**: Return nil response
3. **Event queue overflow**: Log and drop old events
4. **Memory pressure**: Reduce cache sizes

---

## Performance Considerations

### Optimization Techniques

1. **Connection pooling**: Reuse connections
2. **Response caching**: Cache frequently requested data
3. **Event filtering**: Subscribe to specific events only
4. **Async operations**: Don't block on actions
5. **Worker tuning**: Match pool size to workload
6. **Buffer sizing**: Match to expected message sizes

### Benchmarks (Typical)

- Action round-trip: 5-15ms (local Asterisk)
- Event dispatch: <1ms per subscriber
- Memory footprint: ~2MB base + caches

---

## Security Considerations

1. **TLS/SSL**: Enable for production
2. **Credential storage**: Never hardcode
3. **Firewall**: Restrict AMI port access
4. **Least privilege**: Minimal AMI permissions
5. **Input validation**: Sanitize all inputs
6. **Logging**: Don't log sensitive data

---

## Conclusion

AMILIB architecture provides:

- **Separation of concerns**: Clear layer boundaries
- **Extensibility**: Easy to add custom actions/events
- **Testability**: Mockable interfaces
- **Performance**: Optimized for high throughput
- **Reliability**: Comprehensive error handling

For implementation details, see the source code in `src/` and API reference in `docs/`.
