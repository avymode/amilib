# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-03

### Added
- Initial release of AMILIB - a Free Pascal library for Asterisk AMI
- TAMIClient class with full connection management
- Support for plain and MD5 authentication
- Synchronous and asynchronous action execution
- Event handling system with IEventBus interface
- Thread-safe event processing with TThreadedEventBus
- Response and event caching
- Built-in logging system
- TLS/SSL support
- IPv6 support
- Reconnection with exponential backoff
- Rate limiting for actions per second

### Features
- Complete AMI protocol parser
- 40+ built-in AMI actions (Ping, QueueStatus, Command, Originate, etc.)
- Event filtering by type and name
- Custom action support via TAMIAction
- Response follow-up events handling for multi-part responses

### Examples
- Basic connection example
- Queue monitoring example
- Channel monitoring example
- Dashboard example
- Complete application example

### Testing
- Unit tests for types, parser, cache, eventbus
- Integration tests with mock AMI server

### Documentation
- Quick Start guide
- Complete API Reference
- Library documentation with tutorials

## [0.0.0] - Development

### Development Phase
- Internal development and testing
- Alpha/beta testing with real Asterisk installations
