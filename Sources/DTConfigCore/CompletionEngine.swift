/// Schema-aware completion engine for Draw Things configuration JSON.
///
/// Given a ``ParseResult`` and a byte offset, returns completions with their
/// replacement range. Works on broken documents — half-typed keys and missing
/// colons are the normal case.
///
/// The engine is synchronous. For ``ValueDomainProvider``-backed fields, pass
/// pre-fetched values via `domainValues`; when absent, those fields get no
/// completions (free-form).

// MARK: - Public types

public struct CompletionItem: Sendable, Equatable {
    /// Text to insert into the document at the replacement range.
    public let text: String
    /// Text used for case-insensitive prefix filtering (unquoted).
    public let filterText: String
    /// Label shown in the popup.
    public let displayLabel: String
    /// Short type description (e.g. "int", "SamplerType").
    public let typeLabel: String?
    /// Documentation string from the schema.
    public let doc: String?

    public init(
        text: String, filterText: String, displayLabel: String,
        typeLabel: String? = nil, doc: String? = nil
    ) {
        self.text = text
        self.filterText = filterText
        self.displayLabel = displayLabel
        self.typeLabel = typeLabel
        self.doc = doc
    }
}

public struct CompletionResult: Sendable, Equatable {
    public let items: [CompletionItem]
    /// Byte range in the source to replace with the selected item's ``CompletionItem/text``.
    public let replacementRange: Range<Int>

    public init(items: [CompletionItem], replacementRange: Range<Int>) {
        self.items = items
        self.replacementRange = replacementRange
    }

    public static let empty = CompletionResult(items: [], replacementRange: 0..<0)
}

// MARK: - Engine

public enum CompletionEngine {

    /// Compute completions at `offset` bytes into the source.
    ///
    /// - Parameters:
    ///   - result: The current parse result (may contain errors).
    ///   - offset: Cursor byte offset (0-based, between characters).
    ///   - schema: Root object schema (defaults to ``DrawThingsSchema/root``).
    ///   - domainValues: Pre-fetched domain values keyed by ``FieldPath``.
    public static func completions(
        in result: ParseResult,
        at offset: Int,
        schema: ObjectSchema = DrawThingsSchema.root,
        domainValues: [FieldPath: [DomainValue]] = [:]
    ) -> CompletionResult {
        let tokens = result.tokens
        guard !tokens.isEmpty else { return .empty }

        let maxOffset = tokens[tokens.count - 1].range.upperBound
        let clamped = max(0, min(offset, maxOffset))

        guard let ctx = analyzePosition(
            tokens: tokens, offset: clamped, rootSchema: schema)
        else { return .empty }

        return buildCompletions(for: ctx, domainValues: domainValues)
    }

    // MARK: - Position analysis

    private enum PositionKind {
        case objectKey
        case objectValue(key: String, fieldSchema: FieldSchema?)
    }

    private struct AnalyzedPosition {
        let kind: PositionKind
        let partial: String
        let replacementRange: Range<Int>
        let schema: ObjectSchema
        let existingKeys: Set<String>
    }

    // State machine types
    private struct ObjFrame {
        let schema: ObjectSchema?
        var existingKeys: Set<String> = []
        var currentKey: String? = nil
    }

    private struct StackEntry {
        let isObject: Bool
        var objFrame: ObjFrame?
        var arrayElemSchema: FieldSchema?
    }

    private enum Phase {
        case expectKey
        case expectColon
        case expectValue
        case other
    }

    private static func analyzePosition(
        tokens: [Token],
        offset: Int,
        rootSchema: ObjectSchema
    ) -> AnalyzedPosition? {

        var phase: Phase = .other
        var stack: [StackEntry] = []

        var cursorPhase: Phase? = nil
        var cursorStack: [StackEntry]? = nil
        var cursorTokenIdx: Int? = nil
        var cursorIsInside = false

        for (i, token) in tokens.enumerated() {
            // Cursor is in the gap before this token.
            if offset < token.range.lowerBound {
                if cursorPhase == nil {
                    cursorPhase = phase
                    cursorStack = stack
                }
                break
            }

            // Cursor is inside this token.
            if offset >= token.range.lowerBound && offset < token.range.upperBound {
                cursorTokenIdx = i
                cursorIsInside = true
                cursorPhase = phase
                cursorStack = stack
                break
            }

            // Cursor at end of an editable value token: unterminated strings
            // always, numbers/keywords only when they're the last significant
            // token (i.e., document is truncated, user is still typing).
            if offset == token.range.upperBound {
                let editable: Bool
                switch token.kind {
                case .string:
                    editable = !token.text.hasSuffix("\"")
                case .number, .unknown, .true, .false, .null:
                    editable = noMoreSignificantTokens(tokens, after: i)
                default:
                    editable = false
                }
                if editable {
                    cursorTokenIdx = i
                    cursorIsInside = true
                    cursorPhase = phase
                    cursorStack = stack
                    break
                }
            }

            // Process token to advance the state machine.
            processToken(token, phase: &phase, stack: &stack, rootSchema: rootSchema)

            // Cursor is right at this token's end boundary.
            if offset == token.range.upperBound {
                cursorPhase = phase
                cursorStack = stack
            }
        }

        if cursorPhase == nil {
            cursorPhase = phase
            cursorStack = stack
        }
        guard let finalPhase = cursorPhase, let finalStack = cursorStack else { return nil }

        // Extract partial text and replacement range.
        let partial: String
        let replacementRange: Range<Int>

        if let idx = cursorTokenIdx, cursorIsInside {
            let token = tokens[idx]
            let byteInToken = offset - token.range.lowerBound
            switch token.kind {
            case .string:
                partial = partialFromString(token.text, bytes: byteInToken)
                replacementRange = token.range
            case .number:
                partial = prefixSlice(token.text, bytes: byteInToken)
                replacementRange = token.range
            case .true, .false, .null:
                partial = prefixSlice(token.text, bytes: byteInToken)
                replacementRange = token.range
            case .unknown:
                partial = prefixSlice(token.text, bytes: byteInToken)
                replacementRange = token.range
            default:
                partial = ""
                replacementRange = offset..<offset
            }
        } else {
            partial = ""
            replacementRange = offset..<offset
        }

        let frame = finalStack.last?.objFrame
        let schema = frame?.schema ?? rootSchema
        let existing = frame?.existingKeys ?? []

        switch finalPhase {
        case .expectKey:
            return AnalyzedPosition(
                kind: .objectKey,
                partial: partial,
                replacementRange: replacementRange,
                schema: schema,
                existingKeys: existing
            )
        case .expectValue:
            let key = frame?.currentKey ?? ""
            let fieldSchema = schema.fields[key]
            return AnalyzedPosition(
                kind: .objectValue(key: key, fieldSchema: fieldSchema),
                partial: partial,
                replacementRange: replacementRange,
                schema: schema,
                existingKeys: existing
            )
        case .expectColon, .other:
            return nil
        }
    }

    // MARK: - State machine step

    private static func processToken(
        _ token: Token,
        phase: inout Phase,
        stack: inout [StackEntry],
        rootSchema: ObjectSchema
    ) {
        switch token.kind {
        case .whitespace:
            break

        case .leftBrace:
            let schema: ObjectSchema?
            if let last = stack.last {
                if last.isObject {
                    if let f = last.objFrame, let k = f.currentKey,
                       let fs = f.schema?.fields[k]
                    {
                        schema = objectSchema(from: fs.type)
                    } else { schema = nil }
                } else {
                    if let es = last.arrayElemSchema {
                        schema = objectSchema(from: es.type)
                    } else { schema = nil }
                }
            } else {
                schema = rootSchema
            }
            stack.append(StackEntry(
                isObject: true,
                objFrame: ObjFrame(schema: schema),
                arrayElemSchema: nil
            ))
            phase = .expectKey

        case .rightBrace:
            if !stack.isEmpty { stack.removeLast() }
            phase = .other

        case .leftBracket:
            var elemSchema: FieldSchema? = nil
            if let last = stack.last, let f = last.objFrame,
               let k = f.currentKey, let fs = f.schema?.fields[k],
               case .array(let elem) = fs.type
            {
                elemSchema = elem
            }
            stack.append(StackEntry(
                isObject: false, objFrame: nil, arrayElemSchema: elemSchema
            ))
            phase = .other

        case .rightBracket:
            if !stack.isEmpty { stack.removeLast() }
            phase = .other

        case .colon:
            phase = .expectValue

        case .comma:
            if let last = stack.last, last.isObject {
                phase = .expectKey
            } else {
                phase = .other
            }

        case .string:
            if phase == .expectKey {
                let key = decodeString(token.text)
                let idx = stack.count - 1
                if idx >= 0 && stack[idx].isObject {
                    var entry = stack[idx]
                    if var frame = entry.objFrame {
                        frame.existingKeys.insert(key)
                        frame.currentKey = key
                        entry.objFrame = frame
                    }
                    stack[idx] = entry
                }
                phase = .expectColon
            } else {
                phase = .other
            }

        case .number, .true, .false, .null:
            phase = .other

        case .unknown:
            break
        }
    }

    // MARK: - Completion building

    private static func buildCompletions(
        for ctx: AnalyzedPosition,
        domainValues: [FieldPath: [DomainValue]]
    ) -> CompletionResult {
        let items: [CompletionItem]
        switch ctx.kind {
        case .objectKey:
            items = keyCompletions(
                schema: ctx.schema,
                existingKeys: ctx.existingKeys,
                partial: ctx.partial)
        case .objectValue(let key, let fieldSchema):
            items = valueCompletions(
                key: key, fieldSchema: fieldSchema,
                partial: ctx.partial, domainValues: domainValues)
        }
        return CompletionResult(items: items, replacementRange: ctx.replacementRange)
    }

    private static func keyCompletions(
        schema: ObjectSchema,
        existingKeys: Set<String>,
        partial: String
    ) -> [CompletionItem] {
        let lp = partial.lowercased()
        var items: [CompletionItem] = []
        for (key, field) in schema.fields {
            if existingKeys.contains(key) { continue }
            if !lp.isEmpty && !key.lowercased().hasPrefix(lp) { continue }
            items.append(CompletionItem(
                text: "\"\(key)\"",
                filterText: key,
                displayLabel: field.label ?? key,
                typeLabel: typeLabel(for: field.type),
                doc: field.doc
            ))
        }
        items.sort { $0.filterText < $1.filterText }
        return items
    }

    private static func valueCompletions(
        key: String,
        fieldSchema: FieldSchema?,
        partial: String,
        domainValues: [FieldPath: [DomainValue]]
    ) -> [CompletionItem] {
        guard let schema = fieldSchema else { return [] }
        var items: [CompletionItem] = []

        switch schema.type {
        case .bool:
            items = [
                CompletionItem(text: "true", filterText: "true",
                               displayLabel: "true", typeLabel: "bool"),
                CompletionItem(text: "false", filterText: "false",
                               displayLabel: "false", typeLabel: "bool"),
            ]

        case .intEnum(let name, let range, let labels):
            for i in range {
                let label = labels[i]
                let display = label != nil ? "\(i) (\(label!))" : "\(i)"
                items.append(CompletionItem(
                    text: "\(i)", filterText: "\(i)",
                    displayLabel: display, typeLabel: name
                ))
            }

        case .stringOrIntEnum(let name, let strings, let intRange):
            for s in strings {
                items.append(CompletionItem(
                    text: "\"\(s)\"", filterText: s,
                    displayLabel: s, typeLabel: name
                ))
            }
            for i in intRange {
                items.append(CompletionItem(
                    text: "\(i)", filterText: "\(i)",
                    displayLabel: "\(i)", typeLabel: name
                ))
            }

        case .nullableString:
            items.append(CompletionItem(
                text: "null", filterText: "null",
                displayLabel: "null", typeLabel: "null"
            ))
            if let dp = schema.domainPath, let vals = domainValues[dp] {
                items += domainItems(vals)
            }

        case .nullableInt:
            items.append(CompletionItem(
                text: "null", filterText: "null",
                displayLabel: "null", typeLabel: "null"
            ))

        case .string:
            if let dp = schema.domainPath, let vals = domainValues[dp] {
                items = domainItems(vals)
            }

        default:
            break
        }

        // Filter by partial.
        if !partial.isEmpty {
            let lp = partial.lowercased()
            items = items.filter { $0.filterText.lowercased().hasPrefix(lp) }
        }
        return items
    }

    private static func domainItems(_ values: [DomainValue]) -> [CompletionItem] {
        values.map { v in
            CompletionItem(
                text: "\"\(v.value)\"", filterText: v.value,
                displayLabel: v.label ?? v.value, typeLabel: "string"
            )
        }
    }

    // MARK: - Helpers

    private static func noMoreSignificantTokens(_ tokens: [Token], after index: Int) -> Bool {
        for j in (index + 1)..<tokens.count {
            if tokens[j].kind != .whitespace { return false }
        }
        return true
    }

    private static func objectSchema(from type: FieldType) -> ObjectSchema? {
        switch type {
        case .object(let s): return s
        case .array(let elem): return objectSchema(from: elem.type)
        default: return nil
        }
    }

    private static func partialFromString(_ text: String, bytes: Int) -> String {
        let utf8 = Array(text.utf8)
        guard !utf8.isEmpty, utf8[0] == UInt8(ascii: "\"") else {
            return prefixSlice(text, bytes: bytes)
        }
        let start = 1
        let end = min(bytes, utf8.count)
        guard end > start else { return "" }
        return String(decoding: utf8[start..<end], as: UTF8.self)
    }

    private static func prefixSlice(_ text: String, bytes: Int) -> String {
        let utf8 = Array(text.utf8)
        let n = min(bytes, utf8.count)
        guard n > 0 else { return "" }
        return String(decoding: utf8[0..<n], as: UTF8.self)
    }

    private static func decodeString(_ raw: String) -> String {
        guard raw.count >= 2, raw.hasPrefix("\"") else { return raw }
        if raw.hasSuffix("\"") {
            return String(raw.dropFirst().dropLast())
        }
        return String(raw.dropFirst())
    }

    private static func typeLabel(for type: FieldType) -> String {
        switch type {
        case .bool: return "bool"
        case .int: return "int"
        case .float: return "number"
        case .string: return "string"
        case .nullableString: return "string?"
        case .nullableInt: return "int?"
        case .intEnum(let n, _, _): return n
        case .stringOrIntEnum(let n, _, _): return n
        case .array: return "array"
        case .object: return "object"
        case .stringArray: return "[string]"
        }
    }
}
