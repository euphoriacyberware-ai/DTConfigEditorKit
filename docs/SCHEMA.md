# Draw Things Configuration JSON Schema Reference

Derived from [DrawThings-Swift](https://github.com/euphoriacyberware-ai/DrawThings-Swift) 2.2 and real Draw Things exports. When sources conflict, priority order is:

1. `DrawThingsConfiguration+JSON.swift` — the `Codable` conformance, which is the behavioural contract. The editor decodes and encodes through it (`ConfigurationInterop`).
2. `DrawThingsConfiguration.swift` — struct definition and init defaults (also the defaults for absent JSON keys)
3. `DrawThingsConfiguration+FlatBuffer.swift` — `validate()` constraints
4. `config_generated.swift` — FlatBuffers enums (canonical enum definitions)
5. Fixture files — real Draw Things exports

In 2.x, the JSON default and the struct default are the same thing: an absent key takes the `DrawThingsConfiguration()` value. The two default columns below are kept for comparison with older notes; `DTConfigBridgeTests` ("Schema sync") fails if `DrawThingsSchema` disagrees with the client.

---

## 1. Top-Level Field Inventory

Legend:
- **JSON default**: value an absent key decodes to (as `DrawThingsConfiguration.toJSON()` writes it)
- **Struct default**: value in `DrawThingsConfiguration.init` parameter default
- **Diff**: marked when JSON parser default differs from struct init default
- **Fixture presence**: K=krea-full, M=krea-min, W=wan22, C=control-example

### Core Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `model` | `String` | No | *(required)* | `"z_image_turbo_1.0_q8p.ckpt"` | -- | Y | Y | Y | CONFIRMED: must be non-empty (`validate()`); the editor treats a document without it as invalid |
| `width` | `Int32` | No | `1024` | `1024` | -- | Y | Y | Y | CONFIRMED: rounded to a multiple of 64 when encoded |
| `height` | `Int32` | No | `1024` | `1024` | -- | Y | Y | Y | CONFIRMED: rounded to a multiple of 64 when encoded |
| `steps` | `Int32` | No | `8` | `8` | -- | Y | Y | Y | |
| `sampler` | `SamplerType` (Int8 enum) | No | `17` (`.unipctrailing`) | `17` (`.unipctrailing`) | -- | Y | Y | Y | CONFIRMED: int 0..19, maps to SamplerType enum |
| `guidanceScale` | `Float` | No | `1` | `1` | -- | Y | Y | Y | CONFIRMED: range 0 to 50.0 |
| `seed` | `UInt32?` | Yes | `-1` (random) | `-1` (random) | -- | Y | Y | Y | CONFIRMED: `-1` (or any value outside `0...UInt32.max`, or absent) means random; written as `-1` |
| `clipSkip` | `Int32` | No | `1` | `1` | -- | Y | -- | Y | |
| `shift` | `Float` | No | `3` | `3` | -- | Y | Y | Y | UI range 0.10..8.00; JSON accepts higher values with unknown upper limit |
| `strength` | `Float` | No | `1` | `1` | -- | Y | Y | Y | |

### Batch Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `batchCount` | `Int32` | No | `1` | `1` | -- | Y | Y | Y | |
| `batchSize` | `Int32` | No | `1` | `1` | -- | Y | Y | Y | |

### Guidance Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `imageGuidanceScale` | `Float` | No | `1.5` | `1.5` | -- | Y | -- | Y | |
| `clipWeight` | `Float` | No | `1` | `1` | -- | Y | -- | Y | |
| `guidanceEmbed` | `Float` | No | `3.5` | `3.5` | -- | Y | -- | Y | |
| `speedUpWithGuidanceEmbed` | `Bool` | No | `true` | `true` | -- | Y | -- | Y | |
| `cfgZeroStar` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `cfgZeroInitSteps` | `Int32` | No | `0` | `0` | -- | Y | Y | Y | |

### Compression Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `compressionArtifacts` | `CompressionMethod` (string/int) | No | `"disabled"` | `"disabled"` | -- | Y | -- | Y | CONFIRMED: JSON accepts both string (`"disabled"`, `"h264"`, `"h265"`, `"jpeg"`) and int (0..3); `"webp"` in example comment is outdated and not a valid value |
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
| `sharpness` | `Float` | No | `0` | `0` | -- | Y | Y | Y | |
| `stochasticSamplingGamma` | `Float` | No | `0.3` | `0.3` | -- | Y | -- | Y | |
| `aestheticScore` | `Float` | No | `6` | `6` | -- | Y | -- | Y | |
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
| `originalImageHeight` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `originalImageWidth` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `targetImageHeight` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `targetImageWidth` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `negativeOriginalImageHeight` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `negativeOriginalImageWidth` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |

### Upscaler Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `upscaler` | `String?` | Yes | `null` | `null` | -- | Y | -- | Y | CONFIRMED: `""` and `null` both mean "none"; empty string may trigger default 4x upscaler |
| `upscalerScaleFactor` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | |

### Text Encoder Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `resolutionDependentShift` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `t5TextEncoder` | `Bool` | No | `true` | `true` | -- | Y | -- | Y | |
| `separateClipL` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |
| `separateOpenClipG` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |
| `separateT5` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |

### Separate Text Encoder Prompts

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `clipLText` | `String?` | Yes | `null` | `null` | -- | Y | -- | Y | Cross-field: warning if non-null when `separateClipL` is false |
| `openClipGText` | `String?` | Yes | `null` | `null` | -- | Y | -- | Y | Cross-field: warning if non-null when `separateOpenClipG` is false |

### Tiled Diffusion Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `tiledDiffusion` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `diffusionTileWidth` | `Int32` | No | `1024` | `1024` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `diffusionTileHeight` | `Int32` | No | `1024` | `1024` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `diffusionTileOverlap` | `Int32` | No | `128` | `128` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |

### Tiled Decoding Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `tiledDecoding` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `decodingTileWidth` | `Int32` | No | `640` | `640` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `decodingTileHeight` | `Int32` | No | `640` | `640` | -- | Y | -- | Y | CONFIRMED: must be multiple of 64 |
| `decodingTileOverlap` | `Int32` | No | `128` | `128` | -- | Y | -- | Y | |

### HiRes Fix Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `hiresFix` | `Bool` | No | `false` | `false` | -- | Y | Y | Y | |
| `hiresFixWidth` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | CONFIRMED: rounded to a multiple of 64 when encoded; `0` is valid sentinel (means "use width") |
| `hiresFixHeight` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | CONFIRMED: rounded to a multiple of 64 when encoded; `0` is valid sentinel |
| `hiresFixStrength` | `Float` | No | `0.7` | `0.7` | -- | Y | -- | Y | |

### Stage 2 Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `stage2Steps` | `Int32` | No | `10` | `10` | -- | Y | -- | Y | |
| `stage2Guidance` | `Float` | No | `1` | `1` | -- | Y | -- | Y | |
| `stage2Shift` | `Float` | No | `1` | `1` | -- | Y | -- | Y | |

### TEA Cache Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `teaCache` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |
| `teaCacheStart` | `Int32` | No | `5` | `5` | -- | Y | -- | Y | Cross-field: warning when present and `teaCache` is false |
| `teaCacheEnd` | `Int32` | No | `-1` | `-1` | -- | Y | -- | Y | CONFIRMED: `-1` is a valid sentinel |
| `teaCacheThreshold` | `Float` | No | `0.06` | `0.06` | -- | Y | -- | Y | |
| `teaCacheMaxSkipSteps` | `Int32` | No | `3` | `3` | -- | Y | -- | Y | |

### Causal Inference Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `causalInferenceEnabled` | `Bool` | No | *(not read)* | `false` | -- | -- | -- | -- | Not in any fixture; parsed by JSON parser |
| `causalInference` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | |
| `causalInferencePad` | `Int32` | No | `0` | `0` | -- | Y | -- | Y | |

### Video Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `fps` | `Int32` | No | `5` | `5` | -- | Y | -- | Y | Inert on image models |
| `motionScale` | `Int32` | No | `127` | `127` | -- | Y | -- | Y | Inert on image models |
| `guidingFrameNoise` | `Float` | No | `0.02` | `0.02` | -- | Y | -- | Y | Inert on image models |
| `startFrameGuidance` | `Float` | No | `1` | `1` | -- | Y | -- | Y | Inert on image models |
| `numFrames` | `Int32` | No | `14` | `14` | -- | Y | -- | Y | Inert on image models; no modular constraint |

### Refiner Parameters

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `refinerModel` | `String?` | Yes | `null` | `null` | -- | Y | -- | Y | CONFIRMED: `""` and `null` both mean "none" |
| `refinerStart` | `Float` | No | `0.85` | `0.85` | -- | Y | -- | Y | Cross-field: warning when present and no `refinerModel` set |
| `zeroNegativePrompt` | `Bool` | No | `false` | `false` | -- | Y | -- | Y | |

### Face Restoration

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `faceRestoration` | `String?` | Yes | `null` | `null` | -- | Y | Y | Y | CONFIRMED: `""` and `null` both mean "none" |

### Seed Mode

| JSON Key | Swift Type | Optional | JSON Default | Struct Default | Diff | K | M | W | Constraints |
|----------|-----------|----------|-------------|---------------|------|---|---|---|-------------|
| `seedMode` | `SeedMode` (Int8 enum) | No | `2` (`.scalealike`) | `2` (`.scalealike`) | -- | Y | Y | Y | CONFIRMED: int 0..3, maps to SeedMode enum |

### Added in DrawThings-Swift 2.x

| JSON Key | Swift Type | Optional | JSON Default | Notes |
|----------|-----------|----------|-------------|-------|
| `id` | `Int64` | No | `0` | Written by Draw Things and the client; always 0 |
| `shiftForAudio` | `Float` | No | `3` | Shift for audio generation |
| `usesSolAttention` | `Bool` | No | `false` | SOL attention |
| `solAttentionStart` | `Int32` | No | `2` | |
| `solAttentionTau` | `Float` | No | `0.5` | |
| `expandPromptToJson` | `Bool` | No | `false` | |
| `colorCalibration` | `ColorCalibration` | No | `"none"` | `"none"` / `"lab"`; `"disabled"` is read as `"none"` |
| `name` | `String?` | Yes | absent | Client-only; written only when set |
| `t5Text` | `String?` | Yes | absent | Written only when set |
| `enableInpainting` | `Bool` | No | absent (`false`) | Client-only; written only when `true` |

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
| `weight` | `Float` | No | `1.0` | CONFIRMED: range -1.5 to 2.5 |
| `mode` | `LoRAMode` (string or int) | No | `.all` (0) | CONFIRMED: accepts string (`"all"`, `"base"`, `"refiner"`) or int (0..2) |

### `controls[]` (ControlConfig)

Draw Things exports **10 fields** per control entry, and `ControlConfig` reads and writes all of them in 2.x.

| JSON Key | Swift Type | Optional | Default | In ControlConfig | Constraints |
|----------|-----------|----------|---------|-----------------|-------------|
| `file` | `String` | No | *(required)* | Yes | Must be non-empty |
| `weight` | `Float` | No | `1.0` | Yes | |
| `guidanceStart` | `Float` | No | `0.0` | Yes | |
| `guidanceEnd` | `Float` | No | `1.0` | Yes | |
| `controlImportance` | `ControlMode` (string) | No | `"balanced"` | Yes | Maps to `controlMode` in the struct; `"balanced"`, `"prompt"`, `"control"`. Integers (0..2) from older tools are mapped by the bridge; the legacy integer key `controlMode` is also read |
| `noPrompt` | `Bool` | No | `false` | Yes | |
| `globalAveragePooling` | `Bool` | No | `false` | Yes | |
| `downSamplingRate` | `Float` | No | `1.0` | Yes | |
| `targetBlocks` | `[String]` | No | `[]` | Yes | |
| `inputOverride` | `String` (enum) | No | `""` | Yes | `ControlInputType` case name; `""` (app) and `"unspecified"` (client 2.2) both mean `.unspecified` |

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
| `refinerModel` | `DrawThingsConfiguration+JSON.swift` — `readName` maps `""` to `nil` |
| `upscaler` | same |
| `faceRestoration` | same |

`clipLText`, `openClipGText`, `t5Text` and `name` follow the same rule.

The minimal krea fixture (`DT_krea2_robo_min.json`) exports these as `""` while the full fixture uses `null`. Both are valid. An empty-string `upscaler` may trigger a default 4x upscaler in Draw Things (warn).

### 4.3 Cross-Field Dependency Rules

None are errors. Rules 1 and 7 are **warnings** (semantically suspect). Rules 2–6 flag settings that have no effect, so they are **inert** (dimmed): Draw Things' full exports include hires-fix sizes and TEA cache values even when those features are off.

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

**Detection:** Use `ModelFamily.detect(from: model)`. If `nativeFrameRate != nil`, the model is a video model.

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

### 4.5 Client-Only Fields

`name` and `enableInpainting` are read and written by DrawThingsClient but ignored by the Draw Things app. Both are written only when set.

### 4.6 Enum Spellings in JSON

DrawThingsClient writes `compressionArtifacts`, `colorCalibration`, LoRA `mode`, control `controlImportance` and `inputOverride` as names. It reads LoRA `mode` and the legacy `controlMode` key as integers too. For the others, the editor's bridge maps integers written by older tools to names before decoding.

`inputOverride`: the Draw Things app writes `""` for "unspecified"; DrawThingsClient 2.2 writes `"unspecified"`. Both decode to `.unspecified`.

### 4.7 `causalInferenceEnabled`

Not a JSON key in 2.x. `causalInference > 0` enables causal inference, and `causalInference: 0` (what the app writes) disables it. The schema keeps `causalInferenceEnabled` so older documents validate, but its value is ignored.

### 4.8 Default Value History

DrawThings-Swift 2.2 changed the defaults to Draw Things' Z Image Turbo preset. Absent keys now mean:

| Field | 2.2 Default | Earlier editor default |
|-------|------------|------------------------|
| `model` | `z_image_turbo_1.0_q8p.ckpt` | *(required)* |
| `steps` | `8` | `20` |
| `sampler` | `17` (UniPC Trailing) | `0` (DPM++ 2M Karras) |
| `guidanceScale` | `1` | `7` |
| `shift` | `3` | `1` |
| `teaCacheThreshold` | `0.06` | `0.2` |
| `hiresFixWidth` / `hiresFixHeight` | `0` | `1024` |
| `seed` | `-1` | `null` |

---

## 5. `controls[]` Analysis

### Confirmed by `DT_Control_Example.json` fixture

Draw Things exports **all 10 FlatBuffer fields** per control entry; DrawThingsClient 2.x reads and writes all of them. The fixture contains one PuLID control entry:

```json
{
  "controlImportance": "balanced",
  "downSamplingRate": 1,
  "file": "pulid_0.9.1_eva02_clip_l14_336_f16.ckpt",
  "globalAveragePooling": false,
  "guidanceEnd": 0.9,
  "guidanceStart": 0.05,
  "inputOverride": "",
  "noPrompt": false,
  "targetBlocks": [],
  "weight": 1
}
```

### Key observations

- `inputOverride` is exported as an empty string (`""`), mapping to `.unspecified` (0). Non-empty values would be ControlInputType enum names (e.g. `"inpaint"`, `"depth"`, `"canny"`).
- `targetBlocks` is an array of strings (empty here). Used for targeted ControlNet block selection.
- `globalAveragePooling` defaults to `false` in `ControlConfig`.

---

## 6. ModelFamily Reference

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

`ModelFamily.detect(from:)` uses two-phase matching:

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

A model is a video model if and only if `ModelFamily.detect(from: model).nativeFrameRate != nil`.

Video families: `wan21`, `wan22`, `hunyuanVideo`, `ltx2`, `ltx23`.

---

## 7. Open Questions

1. **Numeric ranges.** Some ranges confirmed: LoRA `weight` (-1.5..2.5), `guidanceScale` (0..50.0), `shift` (UI 0.10..8.00, JSON accepts higher). Still no confirmed ranges for `strength`, `hiresFixStrength`, `refinerStart`, `stochasticSamplingGamma`, control `weight`, `guidanceEmbed`, etc. The struct has no range clamping. Prefer no rule over a wrong rule.

2. ~~`causalInferenceEnabled` vs `causalInference`~~ — resolved in 2.x; see 4.7.
