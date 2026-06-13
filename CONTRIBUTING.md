# Contributing to AMILIB

Thank you for considering contributing to AMILIB! This document provides guidelines for contributing to the project.

## Code of Conduct

Please be respectful and professional in all interactions. We aim to foster an inclusive and welcoming community.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported
2. Create a detailed issue with:
   - Clear title
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Environment details (OS, FPC version, Asterisk version)
   - Sample code if applicable

### Suggesting Features

1. Check existing issues and pull requests
2. Create an issue with:
   - Clear description of the feature
   - Use case and rationale
   - Proposed implementation approach
   - Alternative solutions considered

### Pull Requests

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Make** your changes
4. **Test** your changes
5. **Commit** with clear commit messages
6. **Push** to your fork
7. **Submit** a pull request

## Development Setup

### Prerequisites

- Free Pascal Compiler 3.2.2+
- Lazarus IDE (optional)
- Git

### Building

```bash
# Clone the repository
git clone https://github.com/avymode/amilib.git
cd amilib

# Open amilib.lpk in Lazarus to build
# Or use lazbuild:
lazbuild amilib.lpk
```

### Testing

```bash
cd tests
lazbuild ami_test_suite.lpi
./ami_test_suite.exe
```

## Coding Standards

### Style Guide

- Use PascalCase for types, methods, classes
- Use camelCase for variables
- Use descriptive names (minimum 3 characters)
- Comment complex logic in English
- 2-space indentation
- Maximum line length: 120 characters

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Class | PascalCase | TAMIClient |
| Method | PascalCase | Connect |
| Variable | camelCase | FConfig |
| Constant | UPPER_SNAKE_CASE | MAX_RETRIES |
| Type | PascalCase | TAMIEventType |
| Interface | IPascalCase | IEventBus |

### Required Documentation

Each public class should have:
- Purpose description
- Key properties documented
- Key methods documented with parameters

Each public method should have:
- Description of functionality
- Parameter descriptions
- Return value description
- Exception information

### Comments

- Use English only
- Comment "why", not "what"
- Keep comments up to date with code
- Remove commented-out code before submitting

## Testing Guidelines

### Unit Tests

- Test all new functionality
- Test edge cases
- Test error conditions

### Integration Tests

- Test with mock AMI server
- Test with real Asterisk (if available)

### Test Structure

```pascal
procedure TestMyFeature;
var
  // Setup
begin
  // Arrange - prepare test data
  
  // Act - execute functionality
  
  // Assert - verify results
  Check(SomeCondition, 'Description of what should be true');
end;
```

## Submitting Changes

### Before Submitting

1. Code compiles without warnings
2. All tests pass
3. Code follows style guidelines
4. Documentation is updated
5. No debug code or temporary changes

### Pull Request Description

Include:
- Summary of changes
- Related issue numbers
- Testing performed
- Any known limitations

### Review Process

1. All submissions require review
2. Address feedback promptly
3. Be respectful of reviewer suggestions

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- Git history

## Questions?

- Open an issue for questions
- Use GitHub Discussions for general questions

Thank you for your contribution!
