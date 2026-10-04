# DTConfigEditor

A standalone editor for Draw Things configuration JSON files. Paste or open a config, see validation results instantly, and fix problems with one click.

## What it does

DTConfigEditor validates your Draw Things configuration against the known schema and highlights issues directly in the text. It understands Draw Things semantics — dimension constraints, sampler values, cross-field dependencies, and model-family-specific fields.

## Reading the editor

**Error indicators:**
- **Red underline** — error: malformed JSON, wrong type, or confirmed constraint violation (e.g. width not a multiple of 64)
- **Orange underline** — warning: semantically suspect but accepted (e.g. a LoRA set to the refiner with no refiner model)
- **Dimmed text** — inert: the field is valid but has no effect, e.g. video fields like `numFrames` on an image model, or hires-fix sizes while hires fix is off

**Gutter icons** show the highest severity on each line. Click a gutter icon to jump to that line.

**Hover** over underlined text to see the diagnostic details and fix-it buttons. Click a fix-it to apply the suggested repair automatically.

## Problems panel

The problems panel groups all diagnostics by severity. Each entry shows the diagnostic code, message, and line number. Click an entry to jump to it in the editor. Fix-it buttons appear inline where available.

Use the filter toggles at the top to show or hide errors, warnings, and inert diagnostics. The "Unused" toggle is the same setting as "Show inert diagnostics" in Settings.

## Commands

**Format** — Pretty-prints the document with 2-space indentation. Preserves numeric literals exactly as written (e.g. `0.80000000000000004` stays `0.80000000000000004`).

**Sort Keys** — Reorders object keys alphabetically. Nested objects (like LoRA and control entries) are sorted recursively.

Neither command runs automatically. Your document is never rewritten unless you ask. Both can be undone, as can fix-its, Revert to Saved, and switching emission style.

## Emission styles

The toolbar re-writes the document in one of three styles, using DrawThings-Swift to produce the JSON:

- **Full** — every key Draw Things reads.
- **Non-Default Only** — only keys that differ from the defaults (Draw Things' Z Image Turbo preset).
- **Preserve Shape** — the keys the document was opened with, plus any you've added since.

Switching style marks the document as edited.

## Unsaved changes

New, Open, Paste from Clipboard, dropping a file, and loading a fixture all ask before replacing a document with unsaved changes. You can save first, discard, or cancel.

<!-- Screenshots: TODO -->
