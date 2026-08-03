# Draw Things Configuration JSON Schema Reference

Derived from four upstream sources. When sources conflict, priority order is:

1. `ConfigfromJSON.swift` — the behavioural contract (JSON parser)
2. `Configuration.swift` — struct definition, init defaults, `didSet` constraints
3. `config_generated.swift` — FlatBuffers enums (canonical enum definitions)
4. Fixture files — real Draw Things exports

---

## 1. Top-Level Field Inventory

Legend:
- **JSON default**: value used by `ConfigfromJSON.swift` when key is absent (`??` value)
- **Struct default**: value in `DrawThingsConfiguration.init` parameter default
- **Diff**: marked when JSON parser default differs from struct init default
- **Fixture presence**: K=krea-full, M=krea-min, W=wan22

### Core Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `model` | `String` | No | *(required)* | `"sd_xl_base_1.0.safetensors"` | -- | Y | Y | Y | CONFIRMED: must be non-empty; JSON parser returns nil if missing/empty |
| `width` | `Int32` | No | `1024` | `512` | YES | Y | Y | Y | CONFIRMED: `didSet` enforces multiple of 64 |
| `height` | `Int32` | No | `1024` | `512` | YES | Y | Y | Y | CONFIRMED: `didSet` enforces multiple of 64 |
| `steps` | `Int32` | No | `20` | `20` | -- | Y | Y | Y | |
| `sampler` | `SamplerType` (Int8 enum) | No | `.dpmpp2mkarras` (0) | `.dpmpp2mkarras` (0) | -- | Y | Y | Y | CONFIRMED: int 0..19, maps to SamplerType enum |
| `guidanceScale` | `Float` | No | `7.0` | `7.0` | -- | Y | Y | Y | |
| `seed` | `Int64?` | Yes | `nil` | `nil` | -- | Y | Y | Y | CONFIRMED: `-1` means random; `nil` means random; JSON parser treats absent as nil |
| `clipSkip` | `Int32` | No | `1` | `1` | -- | Y | -- | Y | |
| `shift` | `Float` | No | `1.0` | `1.0` | -- | Y | Y | Y | |
| `strength` | `Float` | No | `1.0` | `1.0` | -- | Y | Y | Y | |

### Batch Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `batchCount` | `Int32` | No | `1` | `1` | -- | Y | Y | Y | |
| `batchSize` | `Int32` | No | `1` | `1` | -- | Y | Y | Y | |

### Guidance Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `imageGuidanceScale` | `Float` | No | `1.5` | `1.5` | -- | Y | -- | Y | |
| `clipWeight` | `Float` | No | `1.0` | `1.0` | -- | Y | -- | Y | |
| `guidanceEmbed` | `Float` | No | `3.5` | `3.5` | -- | Y | -- | Y | |
| `speedUpWithGuidanceEmbed` | `Bool` | No | `true` | `true` | -- | Y | -- | Y | |
| `cfgZeroStar` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `cfgZeroInitSteps` | `Int32` | No | `0` | `0` | -- | Y | Y | Y | |

### Compression Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `compressionArtifacts` | `CompressionMethod` (string/int) | No | `.disabled` (0) | `.disabled` (0) | -- | Y | -- | Y | CONFIRMED: JSON accepts both string (`"disabled"`, `"h264"`, `"h265"`, `"jpeg"`) and int (0..3) |
| `compressionArtifactsQuality` | `Float` | No | `43.1` | `43.1` | -- | Y | -- | Y | |

### Mask / Inpaint Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `maskBlur` | `Float` | No | `1.5` | `1.5` | -- | Y | Y | Y | |
| `maskBlurOutset` | `Int32` | No | `0` | `0` | -- | Y | Y | Y | |
| `preserveOriginalAfterInpaint` | `Bool` | No | `true` | `true` | -- | Y | Y | Y | |

### Quality Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `sharpness` | `Float` | No | `0.0` | `0.0` | -- | Y | Y | Y | |
| `stochasticSamplingGamma` | `Float` | No | `0.3` | `0.3` | -- | Y | -- | Y | |
| `aestheticScore` | `Float` | No | `6.0` | `6.0` | -- | Y | -- | Y | |
| `negativeAestheticScore` | `Float` | No | `2.5` | `2.5` | -- | Y | -- | Y | |

### Image Prior Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `negativePromptForImagePrior` | `Bool` | No | `true` | `true` | -- | Y | -- | Y | |
| `imagePriorSteps` | `Int32` | No | `5` | `5` | -- | Y | -- | Y | |

### Crop / Size Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `cropTop` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | |
| `cropLeft` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | |
| `originalImageHeight` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |
| `originalImageWidth` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |
| `targetImageHeight` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |
| `targetImageWidth` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |
| `negativeOriginalImageHeight` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |
| `negativeOriginalImageWidth` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |

### Upscaler Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `upscaler` | `String?` | Yes | `nil` | `nil` | -- | Y | -- | Y | CONFIRMED: `""` and `null` both mean "none"; empty string may trigger default 4x upscaler |
| `upscalerScaleFactor` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | |

### Text Encoder Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `resolutionDependentShift` | `Bool` | No | `false` | `true` | YES | Y | Y | Y | |
| `t5TextEncoder` | `Bool` | No | `true` | `true` | -- | Y | -- | Y | |
| `separateClipL` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |
| `separateOpenClipG` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |
| `separateT5` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |

### Separate Text Encoder Prompts

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `clipLText` | `String?` | Yes | `nil` | `nil` | -- | Y | -- | Y | Cross-field: warning if non-null when `separateClipL` is false |
| `openClipGText` | `String?` | Yes | `nil` | `nil` | -- | Y | -- | Y | Cross-field: warning if non-null when `separateOpenClipG` is false |

### Tiled Diffusion Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `tiledDiffusion` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `diffusionTileWidth` | `Int32` | No | `1024` | `1024` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment (FlatBuffer stores in /64 units) |
| `diffusionTileHeight` | `Int32` | No | `1024` | `1024` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |
| `diffusionTileOverlap` | `Int32` | No | `128` | `128` | -- | Y | -- | Y | UNVERIFIED: stored as /64 in FlatBuffer |

### Tiled Decoding Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `tiledDecoding` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `decodingTileWidth` | `Int32` | No | `640` | `640` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |
| `decodingTileHeight` | `Int32` | No | `640` | `640` | -- | Y | -- | Y | UNVERIFIED: may need 64-alignment |
| `decodingTileOverlap` | `Int32` | No | `128` | `128` | -- | Y | -- | Y | |

### HiRes Fix Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `hiresFix` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `hiresFixWidth` | `Int32` | No | `1024` | `0` | YES | Y | -- | Y | CONFIRMED: `didSet` enforces multiple of 64; `0` is valid sentinel (means "use width") |
| `hiresFixHeight` | `Int32` | No | `1024` | `0` | YES | Y | -- | Y | CONFIRMED: `didSet` enforces multiple of 64; `0` is valid sentinel |
| `hiresFixStrength` | `Float` | No | `0.7` | `0.7` | -- | Y | -- | Y | |

### Stage 2 Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `stage2Steps` | `Int32` | No | `10` | `10` | -- | Y | -- | Y | |
| `stage2Guidance` | `Float` | No | `1.0` | `1.0` | -- | Y | -- | Y | |
| `stage2Shift` | `Float` | No | `1.0` | `1.0` | -- | Y | -- | Y | |

### TEA Cache Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `teaCache` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |
| `teaCacheStart` | `Int32` | No | `5` | `5` | -- | Y | -- | Y | Cross-field: warning when present and `teaCache` is false |
| `teaCacheEnd` | `Int32` | No | `-1` | `-1` | -- | Y | -- | Y | CONFIRMED: `-1` is a valid sentinel |
| `teaCacheThreshold` | `Float` | No | `0.2` | `0.06` | YES | Y | -- | Y | |
| `teaCacheMaxSkipSteps` | `Int32` | No | `3` | `3` | -- | Y | -- | Y | |

### Causal Inference Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `causalInferenceEnabled` | `Bool` | No | `false` | `false` | -- | -- | -- | -- | Not in any fixture; parsed by JSON parser |
| `causalInference` | `Int32` | No | `0` | `3` | YES | Y | -- | Y | |
| `causalInferencePad` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | |

### Video Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `fps` | `Int32` | No | `5` | `5` | -- | Y | -- | Y | Inert on image models |
| `motionScale` | `Int32` | No | `127` | `127` | -- | Y | -- | Y | Inert on image models |
| `guidingFrameNoise` | `Float` | No | `0.02` | `0.02` | -- | Y | -- | Y | Inert on image models |
| `startFrameGuidance` | `Float` | No | `1.0` | `1.0` | -- | Y | -- | Y | Inert on image models |
| `numFrames` | `Int32` | No | `14` | `14` | -- | Y | -- | Y | Inert on image models; UNVERIFIED: Wan may require numFrames % 4 == 1 |

### Refiner Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `refinerModel` | `String?` | Yes | `nil` | `nil` | -- | Y | -- | Y | CONFIRMED: `""` and `null` both mean "none" |
| `refinerStart` | `Float` | No | `0.85` | `0.85` | -- | Y | -- | Y | Cross-field: warning when present and no `refinerModel` set |
| `zeroNegativePrompt` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |

### Face Restoration

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `faceRestoration` | `String?` | Yes | `nil` | `nil` | -- | Y | Y | Y | CONFIRMED: `""` and `null` both mean "none" |

### Seed Mode

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `seedMode` | `Int32` | No | `2` | `2` | -- | Y | Y | Y | CONFIRMED: int 0..3, maps to SeedMode enum |

### Nested Arrays

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `loras` | `[LoRAConfig]` | No | `[]` | `[]` | -- | Y | Y | Y | See nested type table below |
| `controls` | `[ControlConfig]` | No | `[]` | `[]` | -- | Y | Y | Y | See nested type table below |

---

## 2. Nested Type Tables

### `loras[]` (LoRAConfig)

| JSON Key | Swift Type | Optional | Default | Constraints |
|----------|-----------|----------|---------|-------------|
| `file` | `String` | No | *(required)* | Must be non-empty; entry skipped if absent/empty |
| `weight` | `Float` | No | `1.0` | |
| `mode` | `LoRAMode` (string or int) | No | `.all` (0) | CONFIRMED: accepts string (`"all"`, `"base"`, `"refiner"`) or int (0..2) |

### `controls[]` (ControlConfig)

| JSON Key | Swift Type | Optional | Default | Constraints |
|----------|-----------|----------|---------|-------------|
| `file` | `String` | No | *(required)* | Must be non-empty; entry skipped if absent/empty |
| `weight` | `Float` | No | `1.0` | |
| `guidanceStart` | `Float` | No | `0.0` | |
| `guidanceEnd` | `Float` | No | `1.0` | |
| `controlImportance` | `ControlMode` (string or int) | No | `.balanced` (0) | CONFIRMED: JSON key is `controlImportance`, maps to `controlMode` in struct; accepts string (`"balanced"`, `"prompt"`, `"control"`) or int (0..2) |

> **Note:** The FlatBuffer `Control` type has additional fields (`noPrompt`, `globalAveragePooling`,
> `downSamplingRate`, `targetBlocks`, `inputOverride`) that are not exposed in `ControlConfig` or the
> JSON format. The client sets these internally (e.g. for inpainting). They are not user-facing JSON fields.

---

## 3. Enum Reference Tables

### SamplerType (Int8, 0..19)

| Raw | Name | Raw | Name |
|-----|------|-----|------|
| 0 | `dpmpp2mkarras` | 10 | `euleratrailing` |
| 1 | `eulera` | 11 | `dpmppsdetrailing` |
| 2 | `ddim` | 12 | `dpmpp2mays` |
| 3 | `plms` | 13 | `euleraays` |
| 4 | `dpmppsdekarras` | 14 | `dpmppsdeays` |
| 5 | `unipc` | 15 | `dpmpp2mtrailing` |
| 6 | `lcm` | 16 | `ddimtrailing` |
| 7 | `eulerasubstep` | 17 | `unipctrailing` |
| 8 | `dpmppsdesubstep` | 18 | `unipcays` |
| 9 | `tcd` | 19 | `tcdtrailing` |

### SeedMode (Int8, 0..3)

| Raw | Name |
|-----|------|
| 0 | `legacy` |
| 1 | `torchcpucompatible` |
| 2 | `scalealike` |
| 3 | `nvidiagpucompatible` |

### ControlMode (Int8, 0..2)

JSON string-to-int mapping (key `controlImportance` in JSON, `controlMode` in protocol):

| Raw | Enum Name | JSON String |
|-----|-----------|-------------|
| 0 | `balanced` | `"balanced"` |
| 1 | `prompt` | `"prompt"` |
| 2 | `control` | `"control"` |

### LoRAMode (Int8, 0..2)

| Raw | Enum Name | JSON String |
|-----|-----------|-------------|
| 0 | `all` | `"all"` |
| 1 | `base` | `"base"` |
| 2 | `refiner` | `"refiner"` |

### CompressionMethod (Int8, 0..3)

| Raw | Enum Name | JSON String |
|-----|-----------|-------------|
| 0 | `disabled` | `"disabled"` |
| 1 | `h264` | `"h264"` |
| 2 | `h265` | `"h265"` |
| 3 | `jpeg` | `"jpeg"` |

### ColorCalibration (Int8, 0..1)

| Raw | Enum Name |
|-----|-----------|
| 0 | `disabled` |
| 1 | `lab` |

---

## 4. Special Sections

### 4.1 Sentinel Values

| Field | Sentinel | Meaning |
|-------|----------|---------|
| `seed` | `-1` | Random seed (same as `nil` / absent) |
| `teaCacheEnd` | `-1` | Valid; do not apply `min: 0` |
| `hiresFixWidth` | `0` | Use main `width` (struct default; sentinel in krea-full fixture) |
| `hiresFixHeight` | `0` | Use main `height` (struct default; sentinel in krea-full fixture) |

### 4.2 Empty-String / Null Equivalence

These three fields treat `""` and `null` identically as "none":

| Field | Evidence |
|-------|----------|
| `refinerModel` | `ConfigfromJSON.swift:194-197` — `guard let s = ... !s.isEmpty else { return nil }` |
| `upscaler` | `ConfigfromJSON.swift:198-201` — same pattern |
| `faceRestoration` | `ConfigfromJSON.swift:202-205` — same pattern |

The minimal krea fixture (`DT_krea2_robo_min.json`) exports these as `""` while the full fixture uses `null`. Both are valid. An empty-string `upscaler` may trigger a default 4x upscaler in Draw Things (warn).

### 4.3 Cross-Field Dependency Rules (Warnings)

These are all **warnings**, not errors. The config is accepted but semantically suspect.

| # | Condition | Warning |
|---|-----------|---------|
| 1 | `loras[].mode == "refiner"` and `refinerModel` is null/empty | LoRA targets refiner but no refiner model is set |
| 2 | `refinerStart` present (non-default) and `refinerModel` is null/empty | `refinerStart` has no effect without a refiner model |
| 3 | `clipLText` is non-null and `separateClipL` is `false` | `clipLText` is ignored when `separateClipL` is false |
| 4 | `openClipGText` is non-null and `separateOpenClipG` is `false` | `openClipGText` is ignored when `separateOpenClipG` is false |
| 5 | `hiresFixWidth` or `hiresFixHeight` non-zero and `hiresFix` is `false` | HiRes fix dimensions set but HiRes fix is disabled |
| 6 | `teaCacheStart`, `teaCacheEnd`, `teaCacheThreshold`, or `teaCacheMaxSkipSteps` present and `teaCache` is `false` | TEA cache parameters set but TEA cache is disabled |
| 7 | `upscaler` is `""` (empty string, not null) | Empty-string upscaler may trigger default 4x upscaler |

### 4.4 Inert Fields by Model Family

Fields that are syntactically valid but functionally unused by the current model type. Render as `.inert` severity (dimmed), not as warnings.

**Detection:** Use `LatentModelFamily.detect(from: model)`. If `nativeFrameRate != nil`, the model is a video model.

**On image models, these video fields are inert:**
- `fps`
- `motionScale`
- `guidingFrameNoise`
- `startFrameGuidance`
- `numFrames`
- `causalInference` (video-specific inference parameter)
- `causalInferencePad`
- `causalInferenceEnabled`

Evidence: krea-full fixture (image model) carries `numFrames: 14`, `fps: 5`, `motionScale: 127`, `causalInference: 0`.

### 4.5 Struct-Only Fields (Not in JSON)

These fields exist on `DrawThingsConfiguration` but are **not parsed** by `ConfigfromJSON.swift`. They should not appear in JSON exports and should not be in the schema.

| Struct Field | Type | Init Default | Notes |
|-------------|------|-------------|-------|
| `colorCalibration` | `ColorCalibration` | `.disabled` | See anomaly below |
| `expandPromptToJson` | `Bool` | `false` | |
| `enableInpainting` | `Bool` | `false` | Internal; adds inpaint control to FlatBuffer |
| `name` | `String?` | `nil` | Config name, not a generation parameter |
| `t5Text` | `String?` | `nil` | Separate T5 prompt; not parsed from JSON |

### 4.6 `colorCalibration` Anomaly

`colorCalibration` appears in the minimal krea fixture (`DT_krea2_robo_min.json`) as `"none"`, but:
- `ConfigfromJSON.swift` does **not** parse it
- The `ColorCalibration` enum has only `.disabled` (0) and `.lab` (1) — no `"none"` case
- Draw Things exports it, but the client library ignores the JSON value entirely

**Recommendation:** Treat `colorCalibration` as an unknown key. It will trigger the standard "may come from a newer Draw Things version" warning, which is correct behaviour — the client struct has it but the JSON parser doesn't consume it.

### 4.7 Fixture-Only Key Not in Struct

| JSON Key | Appears In | Notes |
|----------|-----------|-------|
| `id` | krea-full, wan22 (value `0`) | Not on `DrawThingsConfiguration`; set internally by `toFlatBufferData()` as `configT.id = 0`. Draw Things exports it but the JSON parser ignores it. Treat as unknown key. |

### 4.8 Default Value Discrepancies (JSON Parser vs Struct Init)

When a key is absent from JSON, `ConfigfromJSON.swift` fills in its default. In 7 cases these differ from the struct's `init` defaults. The **JSON parser defaults are authoritative** for the editor (they define what "absent key" means in a JSON document).

| Field | JSON Parser Default | Struct Init Default | Impact |
|-------|-------------------|-------------------|--------|
| `width` | `1024` | `512` | JSON parser assumes modern model resolution |
| `height` | `1024` | `512` | Same |
| `resolutionDependentShift` | `false` | `true` | JSON parser is conservative; struct enables by default |
| `teaCacheThreshold` | `0.2` | `0.06` | Large difference; struct is more aggressive |
| `causalInference` | `0` | `3` | JSON parser defaults to off; struct defaults to on |
| `hiresFixWidth` | `1024` | `0` | JSON parser sets a real resolution; struct uses sentinel |
| `hiresFixHeight` | `1024` | `0` | Same |

---

## 5. `controls[]` Gap Analysis

### What we know

From `ControlConfig` struct and `ConfigfromJSON.swift`:
- 5 JSON-facing fields: `file`, `weight`, `guidanceStart`, `guidanceEnd`, `controlImportance`
- `controlImportance` uses a string-to-enum mapping (same pattern as `loras[].mode`)

From the FlatBuffer `Control` type (10 fields total):
- 5 additional internal fields: `noPrompt`, `globalAveragePooling`, `downSamplingRate`, `targetBlocks`, `inputOverride`
- These are set programmatically (e.g. `inputOverride = .inpaint` for inpainting) and do not appear in JSON

### What's blocked

- **No fixture with a non-empty `controls` array.** All three fixtures have `"controls": []`.
- Cannot verify whether Draw Things exports additional control fields beyond the 5 known ones.
- Cannot verify actual field values in real exports.

**Priority:** Add a fixture with at least one ControlNet entry. This is the only nested type that remains completely unexercised.

---

## 6. LatentModelFamily Reference

### Families (15 total)

| Family | Latent Channels | Video (`nativeFrameRate`) |
|--------|----------------|--------------------------|
| `sd1` | 4 | No |
| `sdxl` | 4 | No |
| `sd3` | 16 | No |
| `flux` | 16 | No |
| `flux2` | 32 | No |
| `qwen` | 16 | No |
| `zImage` | 16 | No |
| `wan21` | 16 | Yes (16 fps) |
| `wan22` | 48 | Yes (16 fps) |
| `hunyuanVideo` | 16 | Yes (24 fps) |
| `ltx2` | 16 | Yes (25 fps) |
| `ltx23` | 16 | Yes (25 fps) |
| `hiDreamO1` | 3072 | No |
| `kandinsky` | 4 | No |
| `wurstchen` | 3-4 | No |
| `unknown` | 16 | No |

### Detection Logic

`LatentModelFamily.detect(from:)` uses two-phase matching:

1. **Exact version match** (case-insensitive) — e.g. `"krea2"` -> `.qwen`, `"flux1"` -> `.flux`
2. **Substring fallback** — e.g. filename containing `"krea"` -> `.qwen`, `"wan"` -> `.wan21` or `.wan22`

Notable aliases:
- Krea 2 -> `.qwen` (uses Wan 2.1 / Qwen 16-channel coefficients)
- Z Image -> `.zImage` (uses Flux-like coefficients, but distinct family)
- Cosmos 2.5 -> `.qwen`
- Ernie Image, Ideogram 4 -> `.flux2`
- SeedVR2 -> `.flux`
- Pixart, AuraFlow -> `.sdxl`
- SVD (Stable Video Diffusion) -> `.sd1`

### Video Model Detection

A model is a video model if and only if `LatentModelFamily.detect(from: model).nativeFrameRate != nil`.

Video families: `wan21`, `wan22`, `hunyuanVideo`, `ltx2`, `ltx23`.

---

## 7. Open Questions

1. **64-alignment for non-core fields.** Only `width`, `height`, `hiresFixWidth`, `hiresFixHeight` have `didSet` enforcement. The FlatBuffer serialization divides tile dimensions by 64 (`diffusionTileWidth / 64`, etc.), strongly suggesting they should be multiples of 64, but there is no `didSet` constraint. Same question applies to `originalImageWidth/Height`, `targetImageWidth/Height`, `negativeOriginalImageWidth/Height`. Build from corpus observation, not assumption.

2. **Wan `numFrames` modular constraint.** The wan22 fixture has `numFrames: 81` which is `81 = 4*20 + 1` (i.e. `numFrames % 4 == 1`). This may be a requirement for Wan video models. Needs more fixtures to confirm.

3. **Numeric ranges.** No confirmed min/max ranges for `weight`, `guidanceScale`, `shift`, `strength`, `hiresFixStrength`, `refinerStart`, `stochasticSamplingGamma`, etc. The struct has no range clamping. Prefer no rule over a wrong rule.

4. **`compressionArtifacts` as string.** The JSON parser example comment shows `"disabled"`, `"jpeg"`, `"webp"`, but the actual mapping function handles `"disabled"`, `"h264"`, `"h265"`, `"jpeg"`. The `"webp"` in the comment may be outdated; the enum has no `webp` case. Trust the code over the comment.

5. **`colorCalibration` JSON format.** The minimal fixture exports it as `"none"` but the enum only has `disabled`/`lab`. If Draw Things starts exporting this reliably, the JSON parser will need to handle the string-to-enum mapping (similar to `compressionArtifacts`). Currently safe to ignore.

6. **Controls fixture.** No fixture exercises `controls[]`. Cannot verify whether Draw Things exports additional fields beyond the 5 in `ControlConfig`, or what values look like in practice.

7. **`causalInferenceEnabled` vs `causalInference`.** The JSON parser reads both, but no fixture contains `causalInferenceEnabled`. The relationship between the boolean flag and the integer value is unclear. Does `causalInference: 0` imply disabled? Or is the boolean truly independent?
