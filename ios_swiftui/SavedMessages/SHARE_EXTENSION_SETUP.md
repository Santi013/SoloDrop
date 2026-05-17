# SoloDrop Share Extension Setup

This repository contains Swift source files, but no `.xcodeproj` file. Add the target in Xcode and wire these files as described below.

## App Group

Use the same App Group for the app target and the extension target:

```text
group.com.solodrop.app
```

If your Apple Developer team requires another identifier, update it in:

- `SavedMessages/SharedImport.swift`
- `SavedMessages/SavedMessages.entitlements`
- `SolodropShareExtension/SolodropShareExtension.entitlements`

## Main App Target

Include these files in the main app target:

- `SavedMessages/SharedImport.swift`
- `SavedMessages/SharedImportProcessor.swift`
- `SavedMessages/SavedMessages.entitlements`

Set `CODE_SIGN_ENTITLEMENTS` for the app target to:

```text
SavedMessages/SavedMessages.entitlements
```

## Share Extension Target

Create an iOS Share Extension target named `SolodropShareExtension`.

Include these files in the extension target:

- `SolodropShareExtension/ShareViewController.swift`
- `SolodropShareExtension/Info.plist`
- `SolodropShareExtension/SolodropShareExtension.entitlements`
- `SavedMessages/SharedImport.swift`

Set `INFOPLIST_FILE` for the extension target to:

```text
SolodropShareExtension/Info.plist
```

Set `CODE_SIGN_ENTITLEMENTS` for the extension target to:

```text
SolodropShareExtension/SolodropShareExtension.entitlements
```

## Behavior

The extension accepts web URLs, web pages, images, movies, and files. It saves a batch into the App Group container and immediately calls `completeRequest(returningItems:)`. The main app reads the queue on launch and when it returns to foreground, then sends URLs as text messages and files through the existing multipart upload endpoint.
