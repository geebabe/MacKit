# MacKit — Product Requirements Document

**Version:** 1.0 — Initial Implementation Baseline  
**Status:** Approved MVP scope; implementation not started  
**Platform:** macOS 26+, Apple Silicon first  
**Product category:** Native Productivity Toolkit  
**Development approach:** Antigravity + Xcode + Git

## 1. Product Vision

MacKit is a lightweight, privacy-first macOS menu bar utility combining three everyday productivity workflows:

1. **Clipboard:** Retrieve text, links, code, images and screenshots copied previously.
2. **Arrange:** Resize and reposition windows quickly.
3. **Switch:** Navigate between individual windows using the keyboard.

The application must be reliable enough for everyday personal use before any public release.

The product is developed independently. HyperMac, Rectangle, AltTab and Maccy are behavioral research references, not implementation sources.

## 2. Product Principles

- Native macOS experience, not a browser-style desktop application.
- Minimal friction: common actions must be keyboard-first.
- Local-only clipboard data, no account or cloud service.
- Privacy and permission minimization by default.
- Each module must operate independently.
- Fail safely rather than pretending an operation succeeded.
- No silent data truncation or silent loss.
- Do not add AI integrations or unrelated features to the MVP.
- Design for future extension without prematurely implementing future modules.

## 3. MVP Scope

### Module A — Clipboard Manager

**Required:**

- Automatically capture eligible clipboard changes after macOS permission is granted.
- Support plain text, code, URLs, images and screenshots.
- Preserve the full original content of accepted entries, including Unicode, whitespace, formatting within supported formats, and long text.
- Display concise previews without modifying stored content.
- Open clipboard history using a customizable shortcut, initially proposed as Option+V.
- Search stored text/URL entries.
- Navigate history entirely with the keyboard.
- Restore and paste a selected item into the previously active application.
- Provide an explicit **Copy to Clipboard** fallback where direct paste is unsupported or fails.
- Pin/unpin entries.
- Delete individual entries and clear unpinned history.
- Pause/resume automatic recording.
- Exclude applications from capture.
- Honor known concealed/transient pasteboard markers.
- Encrypt stored clipboard contents and image previews.
- Persist history across app restarts.
- Provide understandable recording status and errors.

**Default policies:**

- Retain up to 500 unpinned entries.
- Automatically expire unpinned entries after 30 days.
- Pinned entries are exempt from ordinary expiration and count-based eviction.
- Maximum accepted text payload: 10 MiB.
- Maximum accepted image payload: 25 MiB.
- Items exceeding a limit must be skipped with a visible, non-sensitive explanation; never silently truncated.
- Enforce a configurable total storage budget before allowing unlimited pinned growth.

These are initial defaults; implementation must make them configurable without compromising safety.

**Out of scope:**

- File/folder history from Finder.
- Clipboard synchronization between devices.
- OCR and AI transformations.
- Cloud storage.
- Complex rich-text editing. Where multiple clipboard representations exist, preserve supported types and provide a clearly documented fallback.

### Module B — Window Manager

**Required operations:**

- Snap window to left half.
- Snap window to right half.
- Maximize within the usable screen area.
- Center window.
- Restore previously saved frame when available.
- Configurable keyboard shortcuts.
- Detect and handle non-resizable or inaccessible windows.
- Respect menu bar, Dock, screen boundaries and display scale.
- Handle display disconnect/reconnect gracefully.

**Out of scope:**

- Automated workspace restoration.
- Complex custom layouts.
- Private macOS window-control APIs.

### Module C — Window Switcher

**Required:**

- List eligible individual windows, not just applications.
- Order windows approximately by most recent use (MRU).
- Display app icon and window title when available.
- Keyboard navigation and activation.
- Escape cancels without intentionally changing focus.
- Handle multiple windows belonging to the same app.
- Handle minimized and hidden windows where public APIs permit.
- Refresh the list when windows appear, disappear or become unavailable.
- Avoid blocking the UI when an app is unresponsive.
- Clearly handle failure to activate a window.

**MVP privacy rule:**

- No thumbnails.
- No Screen Recording permission.
- No attempt to intercept or replace Command+Tab.
- Use a dedicated configurable hotkey.

**Known limitations:**

Cross-Space, fullscreen and minimized-window activation may not behave identically across applications. Support the reliable public-API subset and document unavoidable exceptions.

### Module D — App Shell

**Required:**

- Persistent menu bar entry.
- Settings interface.
- First-run onboarding.
- Module enable/disable controls.
- Permission explanations and status.
- Launch at Login toggle.
- Global shortcut configuration.
- Conflict feedback for registered shortcuts.
- Storage usage and history controls.
- Quit application.
- Basic diagnostics that do not expose clipboard content.

## 4. UX Requirements

The app must feel native to macOS and fit both light and dark appearance.

Keyboard shortcuts must be discoverable and customizable. Clipboard and window switching interfaces must support search/navigation without requiring the mouse.

Empty states must explain what to do next. Permission-denied states must explain how to recover. Failures must be reported without leaking sensitive content.

Avoid excessive notifications and persistent overlays.

## 5. Privacy Requirements

- Explicit, user-understandable consent for automatic clipboard capture.
- No attempt to bypass macOS pasteboard restrictions.
- Clipboard capture must be disabled if the user pauses the module.
- Maintain per-application exclusions.
- Do not persist known concealed/transient clipboard items.
- Sensitive-content detection is best-effort, not an absolute guarantee.
- No clipboard content in application logs.
- No telemetry, analytics SDK or remote API required by the MVP.
- Encrypted history and previews at rest.
- Provide delete/reset functionality, with accurate explanations about backups and secure-erasure limitations.
- Accessibility must only be requested when window functionality needs it.

## 6. Acceptance Criteria

**Clipboard**

- Copying multiple ordinary text entries produces retrievable history.
- Copying 20,000-word Unicode text preserves exact content after restart.
- Screenshot/image round-trips preserve the supported original representation.
- Excluded-app and concealed/transient items are not persisted.
- Paused recording does not create new history entries.
- Search does not expose plaintext persisted indexes.
- Pinned entries survive ordinary retention cleanup.
- A failed paste provides an explicit safe fallback.
- A rejected clipboard permission does not prevent the app shell from working.

**Window Manager**

- Common snap operations work on resizable windows.
- Restore returns a window to its previous valid frame.
- Non-resizable windows fail gracefully.
- Multi-monitor changes do not intentionally place windows outside accessible screen bounds.

**Window Switcher**

- Multiple windows of the same app are independently selectable.
- MRU changes after actual user focus.
- Selecting a closed window does not crash the app.
- Escape cancels without activating an unintended window.
- UI remains responsive when window metadata is unavailable.

**App Shell**

- Modules can be enabled and disabled independently.
- Launch at Login reflects actual macOS registration status.
- Revoked permissions show clear recovery instructions.
- App remains functional without an internet connection.

## 7. Definition of Done

A module is complete only when it builds, passes its unit/integration tests, satisfies its acceptance criteria, has no known critical privacy or data-loss issues, and has been manually tested on a real Mac.

The full MVP is ready for daily dogfooding only when all four modules pass their essential workflows and the security validation checklist.

## 8. Future Roadmap

**After personal dogfooding:** additional window layouts, optional switcher thumbnails, improved clipboard media support, performance refinements.

**Later modules:** system monitoring, battery insights/control, Finder/file utilities and workspace automation.

No future feature is allowed to expand v0.1 scope without a deliberate product decision.