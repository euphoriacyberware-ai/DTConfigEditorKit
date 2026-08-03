public enum Validator {

    // MARK: - Public API

    public static func validate(
        _ result: ParseResult,
        schema: ObjectSchema = DrawThingsSchema.root
    ) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        guard let objectNode = findRootObject(result.root) else {
            if result.errors.isEmpty {
                diagnostics.append(Diagnostic(
                    range: result.root.byteRange,
                    severity: .error,
                    code: "type.expected-object",
                    message: "Expected a JSON object at the top level"))
            }
            return diagnostics
        }

        var fieldValues: [String: FieldEntry] = [:]
        var loraInfos: [LoRAInfo] = []

        for member in objectNode.children where member.kind == .member && member.children.count >= 2 {
            let keyNode = member.children[0]
            let valueNode = member.children[1]
            guard valueNode.kind != .error else { continue }

            guard let key = extractKey(keyNode, tokens: result.tokens) else { continue }
            let keyRange = tokenRange(for: .string, in: keyNode, tokens: result.tokens)

            let value = result.value(for: valueNode)
            fieldValues[key] = FieldEntry(
                keyRange: keyRange, valueRange: valueNode.byteRange, value: value)

            if let fieldSchema = schema.fields[key] {
                validateField(
                    key: key, valueNode: valueNode, schema: fieldSchema,
                    tokens: result.tokens, result: result,
                    diagnostics: &diagnostics, loraInfos: &loraInfos)
            } else {
                diagnostics.append(Diagnostic(
                    range: keyRange,
                    severity: .warning,
                    code: "unknown-key",
                    message: "Unknown key \"\(key)\"; may be from a newer Draw Things version"))
            }
        }

        // Required: model
        if fieldValues["model"] == nil {
            diagnostics.append(Diagnostic(
                range: objectNode.byteRange.lowerBound..<objectNode.byteRange.lowerBound,
                severity: .error,
                code: "required.model",
                message: "Required key \"model\" is missing"))
        } else if case .string("") = fieldValues["model"]?.value {
            let r = fieldValues["model"]!.valueRange
            diagnostics.append(Diagnostic(
                range: r,
                severity: .error,
                code: "value.model-empty",
                message: "\"model\" must not be empty"))
        }

        crossFieldChecks(
            fields: fieldValues, schema: schema,
            loraInfos: loraInfos, diagnostics: &diagnostics)

        diagnostics.sort { $0.range.lowerBound < $1.range.lowerBound }
        return diagnostics
    }

    // MARK: - Types

    private struct FieldEntry {
        let keyRange: Range<Int>
        let valueRange: Range<Int>
        let value: JSONValue?
    }

    private struct LoRAInfo {
        let mode: String
        let modeRange: Range<Int>
    }

    private enum ValueKind {
        case null, bool, int, float, string, array, object, unknown
    }

    // MARK: - CST Helpers

    private static func findRootObject(_ root: CSTNode) -> CSTNode? {
        for child in root.children where child.kind == .value {
            for grandchild in child.children where grandchild.kind == .object {
                return grandchild
            }
        }
        return nil
    }

    private static func extractKey(_ node: CSTNode, tokens: [Token]) -> String? {
        for i in node.tokenRange where i < tokens.count {
            if tokens[i].kind == .string {
                return decodeString(tokens[i].text)
            }
        }
        return nil
    }

    private static func tokenRange(for kind: TokenKind, in node: CSTNode, tokens: [Token]) -> Range<Int> {
        for i in node.tokenRange where i < tokens.count {
            if tokens[i].kind == kind {
                return tokens[i].range
            }
        }
        return node.byteRange
    }

    private static func decodeString(_ raw: String) -> String {
        guard raw.count >= 2, raw.hasPrefix("\"") else { return raw }
        if raw.hasSuffix("\"") {
            return String(raw.dropFirst().dropLast())
        }
        return String(raw.dropFirst())
    }

    // MARK: - Value Analysis

    private static func valueKind(of node: CSTNode, tokens: [Token]) -> ValueKind {
        for child in node.children {
            if child.kind == .object { return .object }
            if child.kind == .array { return .array }
        }
        for i in node.tokenRange where i < tokens.count {
            switch tokens[i].kind {
            case .string: return .string
            case .number:
                let t = tokens[i].text
                if t.contains(".") || t.contains("e") || t.contains("E") {
                    return .float
                }
                return .int
            case .true, .false: return .bool
            case .null: return .null
            default: continue
            }
        }
        return .unknown
    }

    private static func typeMatches(kind: ValueKind, expected: FieldType) -> Bool {
        switch (expected, kind) {
        case (.bool, .bool): return true
        case (.int, .int): return true
        case (.float, .int), (.float, .float): return true
        case (.string, .string): return true
        case (.nullableString, .string), (.nullableString, .null): return true
        case (.nullableInt, .int), (.nullableInt, .null): return true
        case (.intEnum, .int): return true
        case (.stringOrIntEnum, .string), (.stringOrIntEnum, .int): return true
        case (.array, .array), (.stringArray, .array): return true
        case (.object, .object): return true
        default: return false
        }
    }

    private static func typeDescription(_ type: FieldType) -> String {
        switch type {
        case .bool: return "bool"
        case .int: return "int"
        case .float: return "number"
        case .string: return "string"
        case .nullableString: return "string or null"
        case .nullableInt: return "int or null"
        case .intEnum(let n, _, _): return n
        case .stringOrIntEnum(let n, _, _): return n
        case .array: return "array"
        case .object: return "object"
        case .stringArray: return "array of strings"
        }
    }

    private static func kindDescription(_ kind: ValueKind) -> String {
        switch kind {
        case .null: return "null"
        case .bool: return "bool"
        case .int: return "int"
        case .float: return "float"
        case .string: return "string"
        case .array: return "array"
        case .object: return "object"
        case .unknown: return "unknown"
        }
    }

    // MARK: - Field Validation

    private static func validateField(
        key: String,
        valueNode: CSTNode,
        schema: FieldSchema,
        tokens: [Token],
        result: ParseResult,
        diagnostics: inout [Diagnostic],
        loraInfos: inout [LoRAInfo]
    ) {
        let kind = valueKind(of: valueNode, tokens: tokens)

        if !typeMatches(kind: kind, expected: schema.type) {
            diagnostics.append(Diagnostic(
                range: valueNode.byteRange,
                severity: .error,
                code: "type.mismatch",
                message: "\(key) expects \(typeDescription(schema.type)), got \(kindDescription(kind))"))
            return
        }

        // MultipleOf64
        if schema.multipleOf64, kind == .int {
            checkMultipleOf64(key: key, valueNode: valueNode, tokens: tokens, diagnostics: &diagnostics)
        }

        // Enum checks
        switch schema.type {
        case .intEnum(let name, let range, let labels):
            checkIntEnum(
                key: key, name: name, range: range, labels: labels,
                valueNode: valueNode, tokens: tokens, diagnostics: &diagnostics)
        case .stringOrIntEnum(let name, let strings, let intRange):
            checkStringOrIntEnum(
                key: key, name: name, kind: kind, strings: strings, intRange: intRange,
                valueNode: valueNode, tokens: tokens, diagnostics: &diagnostics)
        case .array(let elemSchema):
            validateArray(
                key: key, valueNode: valueNode, elementSchema: elemSchema,
                tokens: tokens, result: result,
                diagnostics: &diagnostics, loraInfos: &loraInfos)
        default:
            break
        }
    }

    // MARK: - Constraint Checks

    private static func checkMultipleOf64(
        key: String, valueNode: CSTNode, tokens: [Token], diagnostics: inout [Diagnostic]
    ) {
        guard let numToken = findToken(.number, in: valueNode, tokens: tokens),
              let intVal = Int(numToken.text),
              intVal % 64 != 0
        else { return }

        let lower = (intVal / 64) * 64
        let upper = lower + 64
        diagnostics.append(Diagnostic(
            range: numToken.range,
            severity: .error,
            code: "dimension.not-multiple-of-64",
            message: "\(key) must be a multiple of 64 (got \(intVal))",
            fixIts: [
                FixIt(range: numToken.range, replacement: "\(lower)", label: "Change to \(lower)"),
                FixIt(range: numToken.range, replacement: "\(upper)", label: "Change to \(upper)"),
            ]))
    }

    private static func checkIntEnum(
        key: String, name: String, range: ClosedRange<Int>, labels: [Int: String],
        valueNode: CSTNode, tokens: [Token], diagnostics: inout [Diagnostic]
    ) {
        guard let numToken = findToken(.number, in: valueNode, tokens: tokens),
              let intVal = Int(numToken.text)
        else { return }

        if !range.contains(intVal) {
            diagnostics.append(Diagnostic(
                range: numToken.range,
                severity: .error,
                code: "enum.out-of-range",
                message: "\(key) must be a \(name) value (\(range.lowerBound)...\(range.upperBound)), got \(intVal)"))
        }
    }

    private static func checkStringOrIntEnum(
        key: String, name: String, kind: ValueKind,
        strings: [String], intRange: ClosedRange<Int>,
        valueNode: CSTNode, tokens: [Token], diagnostics: inout [Diagnostic]
    ) {
        if kind == .string {
            guard let strToken = findToken(.string, in: valueNode, tokens: tokens) else { return }
            let str = decodeString(strToken.text)
            if !strings.contains(str) {
                diagnostics.append(Diagnostic(
                    range: strToken.range,
                    severity: .error,
                    code: "enum.invalid-value",
                    message: "\(key) must be one of \(strings.map { "\"\($0)\"" }.joined(separator: ", ")), got \"\(str)\""))
            }
        } else if kind == .int {
            guard let numToken = findToken(.number, in: valueNode, tokens: tokens),
                  let intVal = Int(numToken.text)
            else { return }
            if !intRange.contains(intVal) {
                diagnostics.append(Diagnostic(
                    range: numToken.range,
                    severity: .error,
                    code: "enum.out-of-range",
                    message: "\(key) must be a \(name) value (\(intRange.lowerBound)...\(intRange.upperBound)), got \(intVal)"))
            }
        }
    }

    // MARK: - Nested Validation

    private static func validateArray(
        key: String,
        valueNode: CSTNode,
        elementSchema: FieldSchema,
        tokens: [Token],
        result: ParseResult,
        diagnostics: inout [Diagnostic],
        loraInfos: inout [LoRAInfo]
    ) {
        guard let arrayNode = valueNode.children.first(where: { $0.kind == .array }) else { return }

        var index = 0
        for elementNode in arrayNode.children where elementNode.kind == .value {
            let elemKind = valueKind(of: elementNode, tokens: tokens)

            switch elementSchema.type {
            case .object(let objSchema):
                if elemKind != .object {
                    diagnostics.append(Diagnostic(
                        range: elementNode.byteRange,
                        severity: .error,
                        code: "type.mismatch",
                        message: "\(key)[\(index)] expects object, got \(kindDescription(elemKind))"))
                } else {
                    validateNestedObject(
                        path: "\(key)[\(index)]",
                        valueNode: elementNode,
                        schema: objSchema,
                        tokens: tokens,
                        result: result,
                        diagnostics: &diagnostics,
                        isLora: key == "loras",
                        loraInfos: &loraInfos)
                }
            default:
                break
            }
            index += 1
        }
    }

    private static func validateNestedObject(
        path: String,
        valueNode: CSTNode,
        schema: ObjectSchema,
        tokens: [Token],
        result: ParseResult,
        diagnostics: inout [Diagnostic],
        isLora: Bool,
        loraInfos: inout [LoRAInfo]
    ) {
        guard let objectNode = valueNode.children.first(where: { $0.kind == .object }) else { return }

        var hasFile = false
        var fileIsEmpty = false

        for member in objectNode.children where member.kind == .member && member.children.count >= 2 {
            let keyNode = member.children[0]
            let valNode = member.children[1]
            guard valNode.kind != .error else { continue }

            guard let memberKey = extractKey(keyNode, tokens: tokens) else { continue }
            let memberKeyRange = tokenRange(for: .string, in: keyNode, tokens: tokens)

            if let fieldSchema = schema.fields[memberKey] {
                let kind = valueKind(of: valNode, tokens: tokens)

                // Type check
                if !typeMatches(kind: kind, expected: fieldSchema.type) {
                    diagnostics.append(Diagnostic(
                        range: valNode.byteRange,
                        severity: .error,
                        code: "type.mismatch",
                        message: "\(path).\(memberKey) expects \(typeDescription(fieldSchema.type)), got \(kindDescription(kind))"))
                } else {
                    // Enum checks within nested objects
                    switch fieldSchema.type {
                    case .stringOrIntEnum(let name, let strings, let intRange):
                        checkStringOrIntEnum(
                            key: "\(path).\(memberKey)", name: name, kind: kind,
                            strings: strings, intRange: intRange,
                            valueNode: valNode, tokens: tokens, diagnostics: &diagnostics)
                    default:
                        break
                    }
                }

                // Track file presence
                if memberKey == "file" {
                    hasFile = true
                    if kind == .string {
                        let str = extractStringValue(valNode, tokens: tokens)
                        if str?.isEmpty == true { fileIsEmpty = true }
                    }
                }

                // Collect LoRA mode
                if isLora && memberKey == "mode" {
                    if let mode = extractLoRAMode(kind: kind, valNode: valNode, tokens: tokens) {
                        loraInfos.append(LoRAInfo(mode: mode, modeRange: valNode.byteRange))
                    }
                }
            } else {
                diagnostics.append(Diagnostic(
                    range: memberKeyRange,
                    severity: .warning,
                    code: "unknown-key",
                    message: "Unknown key \"\(memberKey)\" in \(path); may be from a newer Draw Things version"))
            }
        }

        if !hasFile {
            diagnostics.append(Diagnostic(
                range: objectNode.byteRange,
                severity: .warning,
                code: "value.missing-file",
                message: "\(path) has no \"file\" key; entry will be skipped"))
        } else if fileIsEmpty {
            diagnostics.append(Diagnostic(
                range: objectNode.byteRange,
                severity: .warning,
                code: "value.empty-file",
                message: "\(path).file is empty; entry will be skipped"))
        }
    }

    private static func extractLoRAMode(kind: ValueKind, valNode: CSTNode, tokens: [Token]) -> String? {
        if kind == .string {
            return extractStringValue(valNode, tokens: tokens)
        } else if kind == .int, let numToken = findToken(.number, in: valNode, tokens: tokens),
                  let intVal = Int(numToken.text) {
            switch intVal {
            case 0: return "all"
            case 1: return "base"
            case 2: return "refiner"
            default: return nil
            }
        }
        return nil
    }

    // MARK: - Cross-Field Rules

    private static func crossFieldChecks(
        fields: [String: FieldEntry],
        schema: ObjectSchema,
        loraInfos: [LoRAInfo],
        diagnostics: inout [Diagnostic]
    ) {
        let refinerModelValue = fields["refinerModel"]?.value
        let hasRefiner: Bool = {
            guard let v = refinerModelValue else { return false }
            switch v {
            case .null: return false
            case .string(let s): return !s.isEmpty
            default: return false
            }
        }()

        // Rule 1: loras[].mode == "refiner" with no refinerModel
        if !hasRefiner {
            for lora in loraInfos where lora.mode == "refiner" {
                diagnostics.append(Diagnostic(
                    range: lora.modeRange,
                    severity: .warning,
                    code: "cross-field.lora-refiner-no-model",
                    message: "LoRA targets refiner but no refiner model is set"))
            }
        }

        // Rule 2: refinerStart non-default with no refinerModel
        if !hasRefiner, let entry = fields["refinerStart"], let val = entry.value {
            if !isDefault(val, field: "refinerStart", schema: schema) {
                diagnostics.append(Diagnostic(
                    range: entry.valueRange,
                    severity: .warning,
                    code: "cross-field.refiner-start-no-model",
                    message: "refinerStart has no effect without a refiner model"))
            }
        }

        // Rule 3: clipLText non-null with separateClipL false
        if let clipEntry = fields["clipLText"], let clipVal = clipEntry.value,
           !clipVal.isNull,
           isBoolField(fields["separateClipL"], expected: false)
        {
            diagnostics.append(Diagnostic(
                range: clipEntry.valueRange,
                severity: .warning,
                code: "cross-field.clip-l-text-ignored",
                message: "clipLText is ignored when separateClipL is false"))
        }

        // Rule 4: openClipGText non-null with separateOpenClipG false
        if let clipEntry = fields["openClipGText"], let clipVal = clipEntry.value,
           !clipVal.isNull,
           isBoolField(fields["separateOpenClipG"], expected: false)
        {
            diagnostics.append(Diagnostic(
                range: clipEntry.valueRange,
                severity: .warning,
                code: "cross-field.open-clip-g-text-ignored",
                message: "openClipGText is ignored when separateOpenClipG is false"))
        }

        // Rule 5: hiresFixWidth/Height non-zero with hiresFix false
        if isBoolField(fields["hiresFix"], expected: false) {
            if let entry = fields["hiresFixWidth"], let val = entry.value,
               intFromValue(val) != 0 {
                diagnostics.append(Diagnostic(
                    range: entry.valueRange,
                    severity: .warning,
                    code: "cross-field.hires-fix-disabled",
                    message: "hiresFixWidth is set but hiresFix is disabled"))
            }
            if let entry = fields["hiresFixHeight"], let val = entry.value,
               intFromValue(val) != 0 {
                diagnostics.append(Diagnostic(
                    range: entry.valueRange,
                    severity: .warning,
                    code: "cross-field.hires-fix-disabled",
                    message: "hiresFixHeight is set but hiresFix is disabled"))
            }
        }

        // Rule 6: teaCache params non-default with teaCache false
        if isBoolField(fields["teaCache"], expected: false) {
            let teaParams = ["teaCacheStart", "teaCacheEnd", "teaCacheThreshold", "teaCacheMaxSkipSteps"]
            for paramKey in teaParams {
                if let entry = fields[paramKey], let val = entry.value,
                   !isDefault(val, field: paramKey, schema: schema)
                {
                    diagnostics.append(Diagnostic(
                        range: entry.valueRange,
                        severity: .warning,
                        code: "cross-field.tea-cache-disabled",
                        message: "\(paramKey) is set but teaCache is disabled"))
                }
            }
        }

        // Rule 7: upscaler empty string
        if let entry = fields["upscaler"], let val = entry.value {
            if case .string("") = val {
                diagnostics.append(Diagnostic(
                    range: entry.valueRange,
                    severity: .warning,
                    code: "value.upscaler-empty-string",
                    message: "Empty-string upscaler may trigger default 4x upscaler; use null instead"))
            }
        }
    }

    // MARK: - Helpers

    private static func findToken(_ kind: TokenKind, in node: CSTNode, tokens: [Token]) -> Token? {
        for i in node.tokenRange where i < tokens.count {
            if tokens[i].kind == kind {
                return tokens[i]
            }
        }
        return nil
    }

    private static func extractStringValue(_ node: CSTNode, tokens: [Token]) -> String? {
        guard let t = findToken(.string, in: node, tokens: tokens) else { return nil }
        return decodeString(t.text)
    }

    private static func isBoolField(_ entry: FieldEntry?, expected: Bool) -> Bool {
        guard let entry = entry, let val = entry.value else { return expected }
        if case .bool(let b) = val { return b == expected }
        return false
    }

    private static func intFromValue(_ val: JSONValue) -> Int? {
        switch val {
        case .int(let s): return Int(s)
        case .float(let s): return Int(Double(s) ?? 0)
        default: return nil
        }
    }

    private static func isDefault(_ val: JSONValue, field: String, schema: ObjectSchema) -> Bool {
        guard let fieldSchema = schema.fields[field],
              let defaultVal = fieldSchema.jsonDefault
        else { return false }
        return numericEqual(val, defaultVal)
    }

    private static func numericEqual(_ a: JSONValue, _ b: JSONValue) -> Bool {
        switch (a, b) {
        case (.null, .null): return true
        case (.bool(let x), .bool(let y)): return x == y
        case (.string(let x), .string(let y)): return x == y
        case (.int(let x), .int(let y)): return Int(x) == Int(y)
        case (.float(let x), .float(let y)): return Double(x) == Double(y)
        case (.int(let x), .float(let y)): return Double(x) == Double(y)
        case (.float(let x), .int(let y)): return Double(x) == Double(y)
        default: return a == b
        }
    }
}

// MARK: - JSONValue helpers

extension JSONValue {
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}
