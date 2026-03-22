# Prelude (native iOS)

PRD-grounded SwiftUI app under `Prelude/`. Open **`Prelude.xcodeproj`** in Xcode, select an iPhone simulator or device, and run.

**Requirements:** **iOS 26+** deployment target; **Xcode 26+** with the **FoundationModels** framework for on-device Apple Intelligence. On the **Simulator**, voice sessions use the **scripted** agent path (`shouldAttemptFoundationModels` is false); exercise **LanguageModelSession** + tools on a **physical device** with Apple Intelligence available.

## Regenerate the Xcode project

If you add or remove Swift files, run:

```bash
python3 scripts/generate_xcode_project.py
```

## Command-line build

```bash
xcodebuild -project Prelude.xcodeproj -target Prelude -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Set your **Development Team** in Xcode for device builds and App Store distribution.

## Structure

Matches **PRELUDE_PRD.md §11**: `App/`, `Design/`, `Agent/`, `Tools/`, `Voice/`, `Memory/`, `Models/`, `UI/`.
