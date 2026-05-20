# SoloDrop Share Extension Setup

This repository now includes `SoloDrop.xcodeproj`. Open it from the repository root:

```bash
open SoloDrop.xcodeproj
```

The project already contains the `SoloDrop` app target and the `SolodropShareExtension` target. Use this document as a checklist if Xcode target membership ever needs to be repaired.

## App Group

Use the same App Group for the app target and the extension target:

```text
group.com.solodrop.app
```

If your Apple Developer team requires another identifier, update it in:

- `SoloDrop/SavedMessages/SharedImport.swift`
- `SoloDrop/SavedMessages/SavedMessages.entitlements`
- `SolodropShareExtension/SolodropShareExtension.entitlements`

## Main App Target

The main app target should include the Swift files in:

```text
SoloDrop/SavedMessages/
```

The app target uses:

```text
INFOPLIST_FILE = SoloDrop/SavedMessages/Info.plist
CODE_SIGN_ENTITLEMENTS = SoloDrop/SavedMessages/SavedMessages.entitlements
```

## Share Extension Target

The Share Extension target is named `SolodropShareExtension`.

It should include:

- `SolodropShareExtension/ShareViewController.swift`
- `SoloDrop/SavedMessages/SharedImport.swift`
- `SolodropShareExtension/Info.plist`
- `SolodropShareExtension/SolodropShareExtension.entitlements`

It should not compile `SolodropShareExtension/SharedImport.swift`; that file is an older duplicate controller copy and is excluded in `SoloDrop.xcodeproj` to avoid duplicate Swift outputs.

The extension target uses:

```text
INFOPLIST_FILE = SolodropShareExtension/Info.plist
CODE_SIGN_ENTITLEMENTS = SolodropShareExtension/SolodropShareExtension.entitlements
```

## Behavior

The extension accepts web URLs, web pages, images, movies, and files. It saves a batch into the App Group container and immediately calls `completeRequest(returningItems:)`. The main app reads the queue on launch and when it returns to foreground, then sends URLs as text messages and files through the existing multipart upload endpoint.
