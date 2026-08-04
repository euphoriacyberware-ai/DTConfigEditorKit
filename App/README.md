# DTConfigEditor

A standalone editor for Draw Things configuration JSON files. Paste or open a config, see validation results instantly, and fix problems with one click.

## What it does

DTConfigEditor validates your Draw Things configuration against the known schema and highlights issues directly in the text. It understands Draw Things semantics — dimension constraints, sampler values, cross-field dependencies, and model-family-specific fields.

## Reading the editor

**Error indicators:**
- **Red underline** — error: malformed JSON, wrong type, or confirmed constraint violation (e.g. width not a multiple of 64)
- **Orange underline** — warning: semantically suspect but accepted (e.g. refiner settings with no refiner model)
- **Dimmed text** — inert: the field is valid but unused by your current model family (e.g. video fields like `numFrames` on an image model)

**Gutter icons** show the highest severity on each line. Click a gutter icon to jump to that line.

**Hover** over underlined text to see the diagnostic details and fix-it buttons. Click a fix-it to apply the suggested repair automatically.

## Problems panel

The problems panel groups all diagnostics by severity. Each entry shows the diagnostic code, message, and line number. Click an entry to jump to it in the editor. Fix-it buttons appear inline where available.

Use the filter toggles at the top to show or hide errors, warnings, and inert diagnostics.

## Commands

**Format** — Pretty-prints the document with 2-space indentation. Preserves numeric literals exactly as written (e.g. `0.80000000000000004` stays `0.80000000000000004`).

**Sort Keys** — Reorders object keys alphabetically. Nested objects (like LoRA and control entries) are sorted recursively.

Neither command runs automatically. Your document is never rewritten unless you ask.

<!-- Screenshots: TODO -->
