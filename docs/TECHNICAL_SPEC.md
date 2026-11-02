# MacKit — Technical & Security Specification

**Version:** 1.0  
**Implementation:** Swift native macOS application  
**Minimum deployment:** macOS 26  
**Primary test:** Apple Silicon M3 / macOS 27

## 1. Technology Decisions

- **Swift:** primary implementation language.
- **SwiftUI:** settings, onboarding and standard views.
- **AppKit:** floating panels, window integration and macOS-specific UI behavior.
- **ApplicationServices / Accessibility:** external window access and control.
- **NSPasteboard:** clipboard data access and change detection.
- **SQLite:** persisted record metadata and encrypted payload references.
- **CryptoKit:** AES-256-GCM authenticated encryption.
- **Security.framework / Keychain:** encryption-key protection.
- **ServiceManagement:** Launch at Login.
- **Swift concurrency:** asynchronous work and isolated state.
- **Swift Testing / XCTest:** automated tests.
- **Xcode Instruments:** memory, responsiveness, CPU and energy profiling.
- **Swift Package Manager:** package and dependency management.

Use Apple frameworks by default. Introducing third-party libraries requires a documented reason, license review and explicit user approval when security-sensitive.

## 2. Architecture

Use a modular monolith, not microservices.

Logical components:

**AppCore**
- Application lifecycle
- Dependency wiring
- Feature configuration
- Settings management
- Permission coordination
- Shortcut coordination

**ClipboardFeature**
- Clipboard observer
- Privacy and exclusion filters
- Clipboard data representation
- Deduplication
- History repository
- Search
- Paste/restore coordinator
- Clipboard UI

**WindowFeature**
- Window discovery
- Accessibility wrappers
- Screen geometry conversion
- Snap operations
- Restore-frame state

**SwitcherFeature**
- Window identity and lifecycle
- Focus tracking
- MRU ordering
- Window activation
- Keyboard UI

**SecureStorage**
- Database adapter
- Encrypted payload manager
- Keychain key manager
- Image/thumbnail store
- Retention and recovery

**Diagnostics**
- Redacted local logging
- Error classification
- Performance measurement

A feature must not access another feature's private implementation directly. Communication should use narrow interfaces/protocols.

Avoid creating unnecessary abstraction layers before they have real consumers.

## 3. Storage Model

Suggested `clipboard_items` fields:

- `id`: randomly generated identifier
- `kind`: text / URL / image / screenshot
- `created_at`
- `last_used_at`
- `pinned`
- `encrypted_payload_ref`
- `encrypted_metadata`
- `payload_size_bytes`
- `payload_format_version`
- `encryption_version`

Optional content-derived fingerprints must not be stored as ordinary unsalted plaintext hashes when they could reveal sensitive content. Prefer deduplication within memory or keyed fingerprints with an explicit threat-model justification.

Content, source details, full text, source URLs and image previews should be encrypted when persisted. Minimize unencrypted metadata.

Use a versioned serialization format. Validate decoded data before use.

## 4. Image Storage

Recommended design:

- SQLite stores metadata and encrypted file references.
- Image originals are stored in application-private encrypted files.
- Image previews are encrypted separately or included in a sealed payload.
- Use opaque randomly generated filenames.
- Never save unencrypted thumbnails in cache folders.
- Avoid unbounded image decoding in the main UI thread.
- Keep original supported clipboard representations when practical; do not silently replace an original PNG with lossy JPEG.
- Show a smaller decoded preview in the UI to limit memory consumption.

**Write sequence:**

1. Validate size and type.
2. Encrypt the image into a uniquely named temporary encrypted file.
3. Flush the encrypted file appropriately.
4. Atomically move it to its final location.
5. Commit the referencing database record.
6. On failure, clean up temporary files safely.

A recovery routine must detect orphaned encrypted files and missing references. Avoid deleting files referenced by surviving database records.

## 5. Encryption

Use CryptoKit AES-256-GCM.

Requirements:

- Generate a cryptographically random 256-bit key.
- Store the key in macOS Keychain.
- Use a fresh unique nonce for every encryption operation.
- Store the nonce, ciphertext and authentication tag in a versioned format.
- Authenticate relevant record identity/version metadata as associated data when appropriate.
- Reject corrupted or unauthenticated ciphertext.
- Never implement custom AES, nonce generation or key derivation algorithms.
- Never store encryption keys in UserDefaults, source code, logs or SQLite.
- Restrict Keychain access to the application identity.
- Document the behavior of key backup, migration, loss and rotation.

Start with a device-bound key accessibility policy compatible with the supported macOS data-protection Keychain configuration. Validate that background recording and lock/unlock behave as expected.

If the key becomes inaccessible, retain existing encrypted data, stop writes that could overwrite it and present a recovery/reset path. Never silently replace the key.

## 6. Search

MVP strategy: in-memory search over authorized decrypted text.

- Build an index only from eligible loaded records.
- Keep plaintext index data out of SQLite, disk caches and logs.
- Support case-insensitive text search and sensible Unicode behavior.
- Rank exact and prefix matches ahead of weak substring matches.
- Apply a bounded memory budget.
- Support incremental indexing and invalidation.
- Clear sensitive cached representations on lock/logout/quit when feasible.
- Benchmark 500 records and long-content searches.

Do not use ordinary unencrypted SQLite FTS5 to index secret text. Evaluate a more sophisticated encrypted search approach only if real performance measurements justify it.

## 7. Clipboard Capture Algorithm

Use a stateful observer:

1. Detect a change in `NSPasteboard` state.
2. Check module enabled/paused status.
3. Check platform permission and session state.
4. Check the originating app when reliably identifiable.
5. Apply exclusion and concealed/transient rules.
6. Identify supported content representations.
7. Reject unsupported or oversized items clearly.
8. Avoid duplicate recording of identical active content.
9. Encrypt and persist asynchronously.
10. Update history UI when persistence succeeds.

Critical requirements:

- Never assume `changeCount` proves every intermediate clipboard version has been observed.
- Avoid running expensive encoding or encryption on the UI thread.
- Handle denied clipboard access without repeated intrusive prompts.
- Prevent app-generated clipboard writes from producing duplicate history loops.
- Do not falsely attribute an unknown source application to the foreground app.

## 8. Clipboard Paste Algorithm

Restore selected content to the system clipboard, then attempt paste into the previously active application only through a permitted, tested mechanism.

Protect against:

- Wrong target window
- Lost focus
- Target app no longer running
- Secure input mode
- Hotkey collision
- Unsupported image representation
- Event-injection permission failure
- Clipboard changes from another app during the operation

Do not claim a successful paste solely because the clipboard write succeeded.

Where automatic paste cannot be reliably confirmed, expose **Copy to Clipboard** and instruct the user to paste normally.

## 9. Window Geometry

Use current screen visible frames and the target window's coordinate system.

For each operation:

1. Resolve the window and its display.
2. Validate window capabilities.
3. Calculate target frame.
4. Convert coordinate systems correctly.
5. Clamp to usable screen boundaries.
6. Apply bounds with Accessibility.
7. Verify the resulting frame when possible.
8. Report failures without repeated uncontrolled retries.

Store restore frames per relevant window identity while valid; discard stale state.

Handle differing display scales, Dock/menu bar geometry and disconnected screens.

## 10. Window Switcher

Maintain a stateful model of eligible windows.

The system must:

- Track the owning application and window lifecycle.
- Avoid relying solely on mutable window titles as identities.
- Maintain a best-effort MRU order from actual focus observations.
- Avoid duplicating stale windows.
- Resolve metadata in the background.
- Never block rendering while waiting for an unresponsive app.

Activation should use a bounded state machine:

`Selected → Validate → Restore if needed → Activate app → Raise/focus → Verify → Success/Failure`

Only use public APIs for MVP. Do not import private SkyLight interfaces or use undocumented window-server methods to force activation.

Minimized/hidden and cross-Space behavior must be tested empirically. Clearly document unsupported cases.

## 11. Global Shortcuts

Provide a centralized shortcut registry.

- Detect duplicate shortcuts within MacKit.
- Check registration success and report conflicts.
- Do not assume every system-level shortcut conflict can be detected.
- Do not take over Command+Tab.
- Respect Secure Input and relevant OS restrictions.
- Allow resetting shortcut mappings.
- Unregister shortcuts when a module is disabled.

## 12. Privacy & Permission Handling

Permissions must be requested contextually:

- Clipboard automatic history: respect macOS pasteboard access policy.
- Window Manager and Switcher: Accessibility as needed.
- Screen Recording: not requested in MVP.
- Launch at Login: controlled by user.
- No full disk access required.
- No privileged helper or root access.

Never disable SIP, alter TCC databases or bypass macOS permissions.

Provide recovery instructions for revoked/denied permissions.

## 13. Data Lifecycle

Initial defaults:

- 500 unpinned items.
- 30-day unpinned retention.
- Pinned items retained until deleted by user.
- 10 MiB maximum serialized text payload per item.
- 25 MiB maximum captured image payload per item.
- Limits configurable where safe.
- A total disk budget must be enforced, with explicit handling for pinned entries.

No silent truncation.

Retention cleanup must not accidentally delete pinned data or currently referenced encrypted files.

Deleting history must remove app-managed active records and payload files, while accurately communicating that snapshots/backups may retain historical copies.

## 14. Crash & Recovery

Required tests:

- App terminated during a text write.
- App terminated during an image write.
- SQLite transaction rolled back.
- Referenced image file missing.
- Encrypted image file orphaned.
- Authentication tag invalid.
- Keychain key inaccessible.
- Storage schema migration interrupted.
- Disk full.
- Permission revoked during use.

Never delete a damaged data store automatically. Offer recovery or a user-confirmed reset.

## 15. Performance Goals

Targets, not previously measured results:

- Clipboard overlay should become interactive within approximately 200 ms under ordinary conditions.
- Window Switcher should show cached entries promptly without synchronous app enumeration.
- Heavy image processing must remain off the main thread.
- Idle CPU and energy use should be low enough for an always-running utility.
- No runaway memory growth during long sessions.
- No persistent polling loop should run when its module is disabled.

Measure performance with Instruments before claiming a target is achieved.

## 16. Testing Requirements

Unit tests:
- Deduplication
- Retention and pin rules
- Search ranking
- Encryption/decryption
- Authentication failure
- Image size validation
- Window geometry and coordinate conversion
- MRU ordering
- Shortcut conflicts
- State-machine transitions

Integration tests:
- SQLite transactions
- Keychain access
- Clipboard serialization/round-trip
- Encrypted image persistence
- Crash-safe recovery
- Permission-state transitions

Manual system tests:
- Text and screenshot copy/paste
- 20,000-word Unicode content
- VS Code/browser/Preview switching
- Minimized/hidden windows
- Sleep/wake
- Restart
- Multiple displays
- App crash/relaunch
- Permission denial and revocation
- Long-running idle session

## 17. Release & Distribution

During development, use local development builds with stable bundle identity and signing where practical.

Before public distribution:

- Apple Developer signing/notarization review
- Privacy and permission audit
- Third-party license/SBOM review
- Dependency vulnerability audit
- Independent security-oriented code review
- Reproducible documented build procedure
- Clean installation and uninstall testing
- Public privacy policy
- Verified artifact provenance

Do not build an automatic update system into MVP v0.1.

## 18. Security Prohibitions

The coding agent must never:

- Disable Gatekeeper or SIP.
- Modify TCC permissions directly.
- Execute remote scripts blindly.
- Request sudo without explicit approval.
- Log clipboard contents.
- Upload clipboard data.
- Save plaintext snapshots, indexes or previews to disk.
- Introduce private APIs merely to bypass restrictions.
- Delete or replace user data during automatic recovery.
- Claim that encryption or security tests passed without evidence.