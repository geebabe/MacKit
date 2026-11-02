# AGENTS.md — MacKit Development Context

## Mission

Build MacKit, a production-minded native macOS Productivity Toolkit for personal daily use.

The source of truth is:
1. `docs/PRD.md`
2. `docs/TECHNICAL_SPEC.md`
3. This file (`AGENTS.md`)

When requirements conflict, identify the conflict explicitly and preserve security, correctness and approved product scope.

## Developer Profile

The product owner understands software engineering concepts and uses AI-assisted coding, but does not know Swift in depth.

Explain important architectural decisions, error messages and manual testing steps in plain language.

Do not require the product owner to write Swift or debug implementation details manually when the agent can do so.

## Core Scope

Implement:
- Clipboard Manager: text, URL, code, images/screenshots, full-length content, history, search, pin/delete/pause, exclusions, encrypted persistence.
- Window Manager: left/right snapping, maximize, center, restore, shortcuts.
- Window Switcher: per-window MRU, icon/title, keyboard navigation and focus.
- App Shell: menu bar, settings, modules, permission onboarding and login toggle.

Do not implement system monitoring, battery control, Finder/file utilities, workspace automation, OCR, AI services, cloud sync, auto-updates or thumbnail screen capture.

## Technical Requirements

- Swift native macOS application.
- SwiftUI and AppKit.
- macOS 26 minimum, Apple Silicon first.
- SQLite with encrypted sensitive payloads.
- CryptoKit AES-256-GCM.
- Keychain-managed encryption keys.
- Native system APIs, public interfaces only.
- Swift concurrency and clear state isolation.
- Unit/integration tests for critical paths.

## Security Rules

Security-sensitive operations require additional scrutiny.

- Never log clipboard text, images, URLs or secrets.
- Never send clipboard history to external services.
- Never keep plaintext clipboard history files or disk-based search indexes.
- Never invent or implement cryptographic primitives manually.
- Do not bypass macOS privacy controls.
- Do not add privileged helpers.
- Do not use sudo or destructive commands without explicit user approval.
- Never silently truncate copied data.
- Never silently reset encryption keys or erase unreadable history.
- Stop and report any security requirement that cannot be satisfied.

## Source Independence

HyperMac and other utility repositories were used only for behavioral research.

Do not copy or translate their implementation code.

Write original code using official Apple documentation, general software engineering principles and independently derived requirements.

Any dependency must have its license and security implications reviewed.

## Coding Rules

1. Keep each feature in a clearly separated module.
2. Use descriptive names and small, testable components.
3. Avoid unnecessary patterns and abstractions.
4. Make invalid states explicit.
5. Use structured, redacted error reporting.
6. Keep AppKit and Accessibility work off critical UI paths when possible.
7. Do not hide compiler warnings or failed tests.
8. Do not use placeholder success responses to simulate functioning capabilities.
9. Avoid mock data in production interfaces except clearly labeled demos.
10. Use Git commits at coherent implementation milestones.

## Required Working Method

For each implementation milestone:

1. Read relevant specifications.
2. Inspect the existing code.
3. Explain the intended changes briefly.
4. Implement the smallest coherent vertical slice.
5. Build the application.
6. Run relevant tests.
7. Fix errors.
8. Report what works, what is untested and known limitations.
9. Give the product owner a short manual testing scenario.
10. Continue only after respecting any approval or security gate.

Never claim a feature is complete if it has not been built and tested.

## Approval Gates

Ask the product owner before:

- Installing privileged tools or helpers.
- Executing destructive commands.
- Changing privacy/security assumptions.
- Adding network access or analytics.
- Adding dependencies with major security or license implications.
- Changing the supported macOS version.
- Removing a required feature from MVP.
- Making the repository public.
- Packaging a public release.

## Definition of Done

A milestone is complete when:
- It compiles.
- Relevant automated tests pass.
- The UI is usable.
- Required behaviors are implemented, not mocked.
- Failure states are handled.
- Known limitations are documented.
- Security constraints remain satisfied.

## Project Status Reporting

After each milestone, report:

**Implemented:** What actually works.  
**Verified:** Build/tests/manual checks with results.  
**Unverified:** What still needs physical-device testing.  
**Risks:** Remaining correctness/security concerns.  
**Next:** The next smallest implementation milestone.

Keep reports concise, evidence-based and understandable to a non-Swift developer.