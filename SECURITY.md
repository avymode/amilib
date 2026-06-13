# Security Policy

## Supported Versions

| Version | Supported | Notes |
| ------- | ----------|------- |
| 1.0.x   | ✅         | Current stable release |
| < 1.0   | ❌         | Deprecated/unsupported |

## Reporting Security Vulnerabilities

If you discover a security vulnerability within AMILIB, please send an email to the maintainer. All security vulnerabilities will be promptly addressed.

### What to Include

- Type of vulnerability
- Full path of affected file
- Location of vulnerability
- Attack scenario
- Proof of concept or exploit code

## Security Best Practices

### For Users

1. **Credential Storage**
   - Never hardcode credentials in source code
   - Use environment variables or secure config files
   - Restrict file permissions on config files

2. **Network Security**
   - Use TLS/SSL for production connections
   - Restrict AMI port access via firewall
   - Use VLANs to isolate Asterisk infrastructure

3. **Least Privilege**
   - Create dedicated AMI users
   - Grant minimum required permissions
   - Avoid using admin-level accounts

4. **Monitoring**
   - Monitor connection attempts
   - Log and alert on authentication failures
   - Track unusual activity patterns

### For Developers

1. **Input Validation**
   - Validate all inputs from Asterisk
   - Sanitize data before processing
   - Handle malformed messages gracefully

2. **Memory Safety**
   - Avoid buffer overflows
   - Properly free all allocated memory
   - Use bounds checking

3. **Error Handling**
   - Don't expose sensitive information in errors
   - Log security-relevant events
   - Handle timeouts properly

## Known Security Considerations

### AMI Protocol

The AMI protocol transmits credentials in plain text (unless using TLS). Consider:

- Always use TLS in production
- Rotate credentials regularly
- Use IP-based access control

### Event Processing

Events from Asterisk can contain untrusted data:

- Validate all event fields
- Don't execute event data as commands
- Sanitize before displaying in UI

### Connection Management

Implement proper connection handling:

- Set appropriate timeouts
- Implement reconnection limits
- Monitor connection state

## Compliance

When using AMILIB, ensure compliance with:

- Your organization's security policies
- Applicable data protection regulations
- PCI DSS (if handling payment-related data)
- Industry-specific requirements

## Updates

Security updates will be released as patch versions. Users will be notified via:

- GitHub Security Advisories
- Release notes
- Community channels

## Contact

For security-related issues, please:
1. Do NOT open a public GitHub issue
2. Contact maintainer directly
3. Allow time for response before public disclosure

Thank you for helping keep AMILIB and its users secure!
