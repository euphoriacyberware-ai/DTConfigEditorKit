import SwiftUI
import DTConfigCore
import Observation

// MARK: - Preview model (self-contained, no DTConfigBridge needed)

@Observable
@MainActor
final class PreviewModel: ConfigTextEditing {
    var text: String {
        didSet { reparse() }
    }
    var diagnostics: [Diagnostic] = []
    var currentParseResult: ParseResult?

    init(text: String) {
        self.text = text
        reparse()
    }

    private func reparse() {
        let result = Parser.parse(text)
        self.currentParseResult = result
        self.diagnostics = Validator.validate(result)
    }
}

// MARK: - Inline fixture content

private let kreaMinJSON = """
{"shift":3,"colorCalibration":"none","refinerModel":"","tiledDecoding":false,\
"maskBlur":1.5,"batchCount":1,"batchSize":4,"maskBlurOutset":0,"sampler":10,\
"preserveOriginalAfterInpaint":true,"causalInferencePad":0,"sharpness":0,\
"steps":10,"seedMode":2,"hiresFix":false,"cfgZeroStar":false,\
"resolutionDependentShift":false,"loras":[{"mode":"all",\
"file":"k2_robo_lora_f16.ckpt","weight":0.80000000000000004},\
{"mode":"all","file":"krea2_textfusion_refusal_reduction_lora_f16.ckpt",\
"weight":1}],"upscaler":"","seed":3792474977,"controls":[],\
"model":"krea_2_turbo_q8p.ckpt","width":1280,"height":1024,\
"guidanceScale":1,"cfgZeroInitSteps":0,"faceRestoration":"",\
"strength":1,"tiledDiffusion":false}
"""

private let wanJSON = """
{"model":"wan2.2_i2v_480p_q8p.ckpt","width":832,"height":480,\
"steps":30,"sampler":1,"guidanceScale":5,"seed":-1,"shift":8,\
"strength":1,"numFrames":81,"fps":16,"motionScale":127,\
"loras":[],"controls":[]}
"""

private let truncatedJSON = """
{"wid
"""

private let unknownKeyJSON = """
{"model":"test.ckpt","width":1024,"height":1024,\
"futureQuantization":"q4_k_s","newScheduler":42}
"""

private let wrongTypeJSON = """
{"model":"test.ckpt","width":"not-a-number","height":true,\
"steps":"ten","sampler":"invalid"}
"""

private func generateLargeDocument() -> String {
    var parts: [String] = ["\"model\": \"test.ckpt\""]
    for i in 0..<500 {
        parts.append("\"param_\(i)\": \(i)")
    }
    return "{\n" + parts.joined(separator: ",\n") + "\n}"
}

// MARK: - Previews

#Preview("Krea Minimal") {
    ConfigTextView(model: PreviewModel(text: kreaMinJSON))
        .frame(minWidth: 600, minHeight: 400)
}

#Preview("Wan 2.2") {
    ConfigTextView(model: PreviewModel(text: wanJSON))
        .frame(minWidth: 600, minHeight: 400)
}

#Preview("Empty Document") {
    ConfigTextView(model: PreviewModel(text: ""))
        .frame(minWidth: 600, minHeight: 300)
}

#Preview("Truncated Mid-Key") {
    ConfigTextView(model: PreviewModel(text: truncatedJSON))
        .frame(minWidth: 600, minHeight: 300)
}

#Preview("Unknown Keys") {
    ConfigTextView(model: PreviewModel(text: unknownKeyJSON))
        .frame(minWidth: 600, minHeight: 300)
}

#Preview("Wrong Types") {
    ConfigTextView(model: PreviewModel(text: wrongTypeJSON))
        .frame(minWidth: 600, minHeight: 300)
}

#Preview("500-Key Document") {
    ConfigTextView(model: PreviewModel(text: generateLargeDocument()))
        .frame(minWidth: 600, minHeight: 600)
}

#Preview("Dark Mode - Krea") {
    ConfigTextView(model: PreviewModel(text: kreaMinJSON))
        .frame(minWidth: 600, minHeight: 400)
        .preferredColorScheme(.dark)
}

#Preview("Problems List - Errors & Warnings") {
    let model = PreviewModel(text: wrongTypeJSON)
    VStack(spacing: 0) {
        ConfigTextView(model: model)
            .frame(minHeight: 200)
        Divider()
        ProblemsListView(
            diagnostics: model.diagnostics,
            text: model.text,
            onSelect: { _ in }
        )
        .frame(minHeight: 200)
    }
    .frame(minWidth: 600, minHeight: 400)
}

#Preview("Problems List - With Inert") {
    let model = PreviewModel(text: wanJSON)
    ProblemsListView(
        diagnostics: model.diagnostics,
        text: model.text,
        onSelect: { _ in }
    )
    .frame(minWidth: 400, minHeight: 300)
}
