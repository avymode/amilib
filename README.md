# AMILIB - Asterisk AMI Client Library for Free Pascal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Free Pascal](https://img.shields.io/badge/Free%20Pascal-3.2.2-green.svg)](https://www.freepascal.org/)

English | [Russian](README.ru.md)

## Overview

AMILIB is a powerful, thread-safe Free Pascal library for connecting to Asterisk PBX via the Asterisk Manager Interface (AMI). It provides a clean, object-oriented API for sending actions, receiving events, and managing connections.

## Features

- **Synchronous & Asynchronous Operations**: Send actions and receive responses synchronously or handle them asynchronously with callbacks
- **Thread-Safe Design**: Built for multi-threaded applications with proper locking
- **Event System**: Powerful pub/sub event system with filtering capabilities
- **TLS/SSL Support**: Secure connections to Asterisk
- **IPv6 Support**: Connect via IPv4 or IPv6
- **Auto-Reconnection**: Automatic reconnection with exponential backoff
- **Rate Limiting**: Configurable actions per second limiting
- **Caching**: Built-in caching for frequently requested data
- **Logging**: Comprehensive logging system

## Requirements

- Free Pascal Compiler 3.2.2+
- Lazarus IDE (optional, for GUI development)
- Synapse networking library

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/avymode/amilib.git
   ```

2. Add the `src` directory to your project's search paths

3. Add required units to your uses clause:
   ```pascal
   uses ami_client, ami_types, ami_log;
   ```

## Quick Start

```pascal
program MyFirstApp;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, ami_client, ami_types, ami_log;

var
  Client: TAMIClient;
  Config: TAMIClientConfig;
  Response: TAMIResponse;
begin
  // Configure the client
  Config.Host := 'ASTERISK_HOST';
  Config.Port := 5038;
  Config.Username := 'AMI_USERNAME';
  Config.Password := 'AMI_PASSWORD';
  Config.AuthType := 'plain';

  // Initialize logging
  AmiLogInit('', True, llInfo);

  // Create client
  Client := TAMIClient.Create(Config);
  try
    // Connect
    if Client.Connect then
    begin
      WriteLn('Connected to Asterisk!');

      // Send Ping
      Response := Client.Ping(5000);
      if Assigned(Response) and Response.IsSuccess then
        WriteLn('Ping successful!')
      else
        WriteLn('Ping failed!');

      // Disconnect
      Client.Disconnect;
    end
    else
      WriteLn('Connection failed: ', Client.Transport.LastError);
  finally
    Client.Free;
    AmiLogShutdown;
  end;
end.
```

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| Host | Asterisk server hostname/IP | - |
| Port | AMI port | 5038 |
| Username | AMI username | - |
| Password | AMI password | - |
| AuthType | Authentication type ('plain' or 'md5') | 'plain' |
| UseTLS | Enable TLS/SSL | False |
| UseIPv6 | Use IPv6 | False |
| ConnectionTimeout | Connection timeout (ms) | 10000 |
| ResponseTimeout | Response timeout (ms) | 30000 |
| PingInterval | Keep-alive ping interval (sec) | 30 |
| MaxReconnectAttempts | Max reconnection attempts | 3 |
| MaxActionsPerSecond | Rate limiting | 10 |

## Examples

The `examples` directory contains several demonstration applications:

- **Basic**: Simple connection and Ping example
- **QueueMonitor**: Real-time queue monitoring
- **ChannelMonitor**: Channel state monitoring
- **Dashboard**: Complete dashboard application
- **CompleteApp**: Full-featured application template

## Documentation

- [Quick Start](docs/Quick_Start.md) - Getting started guide
- [API Reference](docs/Complete_API_Reference.md) - Complete API documentation
- [Architecture](docs/Architecture.md) - Library architecture

## Testing

Run the test suite:
```bash
cd tests
lazbuild ami_test_suite.lpi
./ami_test_suite.exe
```

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Open an issue on GitHub
- Check the documentation in the `docs` folder
- Review example applications in the `examples` folder

## Acknowledgments

- Asterisk team for the AMI protocol
- Free Pascal community
- Synapse networking library authors
