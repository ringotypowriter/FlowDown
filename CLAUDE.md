# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

- @import AGENTS.md

## Project Overview

FlowDown is a Swift-based AI/LLM client app for iOS and macOS (Catalyst) with privacy-first design. The project uses Xcode workspace with multiple Swift Package Manager frameworks.

## Build Commands

### Archive Build (Release)
```bash
# Build for both iOS and macOS Catalyst
make

# Clean build artifacts
make clean
```

### Development Build

```bash
# Build iOS scheme
xcodebuild -workspace FlowDown.xcworkspace -scheme FlowDown -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'

# Build macOS Catalyst scheme
xcodebuild -workspace FlowDown.xcworkspace -scheme FlowDown-Catalyst -configuration Debug -destination 'platform=macOS'
```

When testing build, use `xcbeautify -qq` (only print tasks that have errors) for better output and save us some token.

## Architecture

### Project Structure
- **FlowDown.xcworkspace**: Main workspace containing app and frameworks
- **FlowDown/**: Main app source code
  - **Application/**: App delegates, scene delegates, configuration
  - **Backend/**: Core business logic (Model, Conversation, Storage, etc.)
  - **PlatformSupport/**: Platform-specific code (Catalyst)
- **Frameworks/**: Reusable Swift packages
  - **Storage**: Database layer using WCDB
  - **ChatClientKit**: LLM client functionality with MLX support
  - **RichEditor**: Text editing components
  - **RunestoneEditor**: Code editor with syntax highlighting

### Key Managers (Singleton Pattern)
- `ModelManager`: AI model management
- `ModelToolsManager`: Model tools and capabilities
- `ConversationManager`: Chat conversation handling
- `MCPService`: Model Context Protocol service
- `UpdateManager`: App updates (macOS/Catalyst only)

### Security Features
- App signature validation in release builds
- Sandbox enforcement on macOS/Catalyst
- Debug assertions for development-time checks
- Anti-debugging measures in production

## Development Guidelines

### Swift Style (from AGENTS.md)
- **Indentation**: 4 spaces
- **Braces**: Opening brace on same line
- **Naming**: PascalCase for types, camelCase for properties/methods
- **Modern Swift**: Use @Observable macro, async/await, Result builders
- **Architecture**: Protocol-oriented design, dependency injection, composition over inheritance

### Platform Requirements
- iOS 15.0+ / macOS 11.0+ / macCatalyst 15.0+
- Swift 5.9+
- Uses MLX for local AI model support (GPU acceleration on supported devices)

### Dependencies
Key external dependencies managed via Swift Package Manager:
- MLX/MLX-examples: Local AI model support
- WCDB: Database storage
- MarkdownView: Markdown rendering
- Various UI and utility libraries

## Testing
No automated test suite found. Manual testing required for changes.