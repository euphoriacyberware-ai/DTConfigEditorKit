# DTConfigEditorKit

A schema-aware editor for [Draw Things](https://drawthings.ai) configuration JSON. Ships as an embeddable SwiftUI view with headless validation, plus a standalone macOS/iOS app for inspecting and editing configs.

- macOS 14+ / iOS 17+
- Swift 6.3, Swift Package Manager
- Zero-dependency parser and validator (no Foundation JSON, no Codable)
- Lossless round-trip: numeric literals preserved as written, whitespace and key order untouched

## Requirements and installation

Add DTConfigEditorKit as a Swift Package Manager dependency. Two library products are available:

| Product | What you get | Transitive dependencies |
|---|---|---|
| `DTConfigEditorKit` | Parser, validator, completions, TextKit 2 editor view | None beyond SwiftUI/AppKit/UIKit |
| `DTConfigBridge` | `DrawThingsConfiguration` interop, model-family detection | DrawThingsClient, gRPC, SwiftNIO, SwiftProtobuf, FlatBuffers |

Most host apps need both. If you only need validation without the networking stack, `DTConfigEditorKit` alone is sufficient.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/<org>/DTConfigEditorKit.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "DTConfigEditorKit", package: "DTConfigEditorKit"),
            .product(name: "DTConfigBridge", package: "DTConfigEditorKit"),
        ]
    ),
]
```

## Quick start

```swift
import DTConfigEditorKit
import DTConfigBridge

struct EditorScreen: View {
    @State private var model: ConfigEditorModel

    init(configuration: DrawThingsConfiguration) {
        _model = State(initialValue: ConfigEditorModel(configuration))
    }

    var body: some View {
        VStack {
            ConfigTextView(model: model)
            Button("Generate") {
                guard let config = model.configuration else { return }
                // pass config to DrawThingsService.generateImage(...)
            }
            .disabled(!model.isValid)
        }
    }
}
```

To open pasted or loaded JSON text instead of a struct:

```swift
let model = ConfigEditorModel(text: jsonString)
```

## The document model

`ConfigEditorModel` owns a `String`. The `configuration` property is a **projection** of that text — it is `nil` whenever the document contains parse errors or is missing required fields (like `model`).

```
text: String                              ← durable, always present
configuration: DrawThingsConfiguration?   ← nil while invalid
diagnostics: [Diagnostic]                 ← updated ~150ms after each edit
isValid: Bool                             ← configuration != nil
unknownKeys: [(String, JSONValue)]        ← keys not in the known schema
```

There is no `Binding<DrawThingsConfiguration>`. The document is invalid most of the time while someone types — there is no valid struct to write back on every frame. Hosts check `isValid` before reading `configuration`.

## Editing from the host

When the host needs to mutate a field externally (randomizing seed, setting dimensions from a canvas), use `set(_:to:)`:

```swift
model.set("seed", to: .int("-1"))
model.set("width", to: .int("1024"))
```

This replaces only the target key's byte span in the parse tree. Every other byte — whitespace, key order, cursor position, undo history — stays identical.

Full re-emission mid-edit would destroy the user's formatting and undo stack. The fallback to full re-emission only triggers when the document is unparseable.

## Emission styles

When creating a `ConfigEditorModel` from a `DrawThingsConfiguration`, the emission style controls which keys appear in the generated JSON:

| Style | Behavior | Default for |
|---|---|---|
| `.full` | Every key | — |
| `.nonDefaultOnly` | Omit keys matching schema defaults | `ConfigEditorModel.init(_:)` |
| `.preserveShape(keys:)` | Emit only the given set of keys | Paste/load path |

```swift
// Emit only non-default keys (default)
let text = ConfigurationInterop.text(from: config, style: .nonDefaultOnly)

// Emit all keys
let text = ConfigurationInterop.text(from: config, style: .full)

// Preserve unknown keys through a round-trip
let text = ConfigurationInterop.text(
    from: config,
    style: .nonDefaultOnly,
    unknownKeys: model.unknownKeys
)
```

## Diagnostics

All validation feedback flows through a single `Diagnostic` type:

```swift
public struct Diagnostic: Sendable, Equatable, Codable {
    public let range: Range<Int>       // byte offsets
    public let severity: Severity      // .error | .warning | .inert
    public let code: String            // stable, e.g. "dimension.not-multiple-of-64"
    public let message: String
    public let fixIts: [FixIt]
}
```

**Three severities:**

- `.error` — malformed JSON, wrong type, confirmed constraint violation (e.g. `width` not a multiple of 64)
- `.warning` — semantically suspect but accepted (e.g. `loras[].mode == "refiner"` with no `refinerModel`)
- `.inert` — valid but unused by the current model family (e.g. video fields on an image model); rendered dimmed, never as a problem

Diagnostic `code` strings are stable identifiers suitable for snapshot testing. `Diagnostic` conforms to `Codable` — each test fixture has a sibling `.expected.json` file.

### Problems list

`ProblemsListView` provides a sidebar panel grouped by severity with filter toggles:

```swift
ProblemsListView(
    diagnostics: model.diagnostics,
    text: model.text,
    onSelect: { diagnostic in coordinator.selectRange(diagnostic.range) },
    onApplyFixIt: { fixIt in coordinator.applyFixIt(fixIt) }
)
```

### Fix-its

`FixIt` describes a byte-range replacement. Apply programmatically:

```swift
let fixed = FixItApplicator.apply(fixIt, to: model.text)
model.text = fixed
```

## ValueDomainProvider

Fields like `model`, `loras[].file`, `upscaler`, and `controls[].file` are not static enums — the available values depend on the connected Draw Things server.

```swift
public protocol ValueDomainProvider: Sendable {
    func values(for field: FieldPath) async -> [DomainValue]?   // nil = free-form
}
```

- `StaticValueDomainProvider` (DTConfigCore) — returns `nil` for all fields (free-form).
- `ServerValueDomainProvider` (DTConfigBridge) — currently returns `nil` for all fields because DrawThingsClient does not yet expose a model-browsing API. `checkFilesExist(_:)` is available for validating specific filenames against a running server. When model browsing lands in the client, completions and validation will automatically pick up real lists.

## Module structure

```
DTConfigEditorKit (re-exports Core + UI)
├── DTConfigCore          zero imports — lexer, parser, CST, schema, validator,
│                         completions, formatter, fix-it applicator
└── DTConfigEditorUI      SwiftUI + AppKit/UIKit — TextKit 2 editor, gutter,
                          diagnostic popovers, problems list, completion popup

DTConfigBridge            DrawThingsClient interop — ConfigEditorModel,
                          ConfigurationInterop, model-family detection,
                          ServerValueDomainProvider
```

`DTConfigCore` imports nothing — not even Foundation. This keeps `swift test --filter DTConfigCoreTests` fast and lets lightweight embedders avoid the gRPC dependency tree entirely. A test asserts no imports exist in the module.

`DTConfigBridge` is the only target allowed to import `DrawThingsClient`.

## Unknown-key handling

Draw Things ships fields ahead of the client library. Unknown keys produce a **warning**, never an error, and are **never auto-removed**. The warning message notes the key may come from a newer Draw Things version.

`ConfigEditorModel.unknownKeys` is a sidecar that survives re-emission:

```swift
let text = ConfigurationInterop.text(
    from: config,
    style: .nonDefaultOnly,
    unknownKeys: model.unknownKeys
)
```

Caveat: constructing a `DrawThingsConfiguration` from JSON and serializing it back drops unknown keys — the struct has no place for them. The `unknownKeys` sidecar is what preserves them through round-trips.

## configlint

Command-line validator for CI and scripting:

```bash
swift run configlint path/to/config.json

# Multiple files
swift run configlint Tests/Fixtures/*.json

# JSON output
swift run configlint --format json config.json

# Fail on warnings too
swift run configlint --strict config.json

# Pretty-print in place
swift run configlint --format-in-place config.json

# Update expected diagnostic snapshots
swift run configlint --update-expected Tests/Fixtures/DT_krea2_robo.json
```

**Exit codes:** 0 = no errors, 1 = errors found (or warnings under `--strict`), 2 = tool failure.

**Text output format:** `file:line:col: severity [code] message`

## Headless validation

Use the validator directly without the editor UI:

```swift
import DTConfigCore

let result = Parser.parse(jsonText)
let diagnostics = Validator.validate(result)

for d in diagnostics {
    print("\(d.severity): [\(d.code)] \(d.message)")
}
```

## Known limitations

- **Numeric ranges** (guidanceScale, strength, weight, etc.) are not validated — no confirmed constraints from the upstream parser.
- **64-alignment** is only checked for `width` and `height`. Other candidates (`hiresFixWidth`, `hiresFixHeight`, `targetImageWidth`, etc.) are unverified.
- **Video-model constraints** (e.g. `numFrames` mod 4 for Wan models) are unverified.
- **`ServerValueDomainProvider`** returns `nil` for all fields — DrawThingsClient does not yet expose a model-browsing API.
- **`controls` array** schema is modelled but fixture coverage is thin (one fixture).
- **`set(_:to:)` fallback path** (used only when the document is unparseable) handles a subset of fields: `width`, `height`, `steps`, `model`, `guidanceScale`, `seed`, `shift`, `strength`, `sampler`.
- **App target** is a development/test harness, not yet production-ready.

## License

No license file has been added yet.
