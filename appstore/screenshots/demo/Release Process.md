# Release Process

Every release goes through the same four stages. Nothing ships without a signed, notarized build.

```mermaid
flowchart LR
  A[Merge to main] --> B[Build & sign]
  B --> C{Notarized?}
  C -- yes --> D[Publish update]
  C -- no --> E[Fix & rebuild]
  E --> B
  D --> F[Users updated]
```

## Build

```swift
let release = try await Builder(target: .universal)
    .sign(identity: "Developer ID Application")
    .notarize()
print("Ready: \(release.version)")
```

## Rollback

If a release has a serious bug, publish a fixed build with a **higher build number**[^1].

[^1]: Sparkle compares build numbers, not version strings.
