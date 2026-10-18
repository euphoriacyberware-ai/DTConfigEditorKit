# Changelog

## Unreleased

Migrated to DrawThings-Swift 2.2 and Swift 6.

### Breaking

- Depends on DrawThings-Swift `from: "2.2.0"` (was the pre-release `v2` branch). Requires macOS 15 / iOS 18 / visionOS 2.
- Absent keys now take DrawThings-Swift 2.2's defaults (Draw Things' Z Image Turbo preset: `z_image_turbo_1.0_q8p.ckpt`, 8 steps, UniPC Trailing, guidance 1, shift 3, TEA cache threshold 0.06, hires-fix size 0). `.nonDefaultOnly` output omits keys equal to these, so it differs from earlier output.
- `ConfigurationInterop` decodes and encodes with `DrawThingsConfiguration`'s `Codable` conformance instead of its own codec. The output is complete Draw Things JSON: a random seed is written as `-1`, and `id`, `shiftForAudio`, `usesSolAttention`, `solAttentionStart`, `solAttentionTau` and `expandPromptToJson` are included.
- `causalInferenceEnabled` is no longer written; `causalInference > 0` enables causal inference. It is still accepted when reading.
- A document whose values have the wrong type no longer loses them all: each such key is skipped (and reported by the validator) while the rest decode.
- `ConfigurationInterop.knownKeys` is derived from DrawThingsClient, so `id` and the 2.2 keys are no longer unknown keys.
- The hires-fix, TEA cache, refiner-start and separate-text-encoder rules now report `.inert` instead of `.warning`.
- `GutterRulerView` was removed (it was unused; `GutterSideView` replaced it).

### Added

- `ConfigEditorActions`: pass to `ConfigTextView(model:actions:)` to format, sort keys, apply fix-its, replace the document and select ranges as undoable edits from menus or a problems list.
- `ProblemsListView(showInert:)` binds the "Unused" filter to outside state.
- `JSONString.decode(_:)` / `quote(_:)` in DTConfigCore: one JSON string-literal decoder (with surrogate pairs) in place of five copies.
- `ConfigurationInterop.defaultValues`.
- `DTConfigBridge` re-exports `DrawThingsClient`.
- Draw Things example configs (H3 Turbo, Krea 2 + LoRA) as test fixtures, with round-trip and schema-sync tests.

### Fixed

- Control fields `noPrompt`, `globalAveragePooling`, `downSamplingRate`, `inputOverride` and `targetBlocks` were dropped on re-emission.
- Older documents with integer `compressionArtifacts`, `colorCalibration` or `controlImportance` are read correctly.
- `ConfigEditorModel.set(_:to:)` inserted keys without escaping them and could trap on an out-of-range sampler value; its fallback handles every key.
- The macOS editor no longer drops to TextKit 1 when showing completions, hover popovers or the gutter. The gutter numbers source lines rather than wrapped lines.
- Replacing the text from outside the view clears its undo history instead of leaving undo steps that no longer apply.
- Force unwraps in `ConfigTextView`, `Validator` and `configlint`.
- Escaped characters in keys are decoded by the validator, completion engine and formatter.

### App

- Swift 6 language mode.
- New, Open, Paste, drop and fixture loading ask to save or discard unsaved changes, including from menus.
- Format, Sort Keys, fix-its, Revert and emission-style switches are undoable. Switching style keeps the document edited, and Preserve Shape keeps keys added since loading.
- Clicking a problem selects it in the editor.
- The connection uses `ConnectionOptions`, including the shared secret, and shuts the service down on disconnect.
- Save and open errors are shown in an alert.
- The default emission style preference is applied at launch.
