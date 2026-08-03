import ArgumentParser
import DTConfigCore
import Foundation

@main
struct ConfigLint: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "configlint",
        abstract: "Validate Draw Things configuration JSON files.",
        version: "0.1.0"
    )

    @Argument(help: "Files or directories to lint.")
    var paths: [String]

    @Option(name: .long, help: "Output format: text (default) or json.")
    var format: OutputFormat = .text

    @Flag(name: .long, help: "Treat warnings as errors.")
    var strict: Bool = false

    @Flag(name: .long, help: "Suppress inert diagnostics.")
    var quiet: Bool = false

    @Flag(name: .long, help: "Rewrite sibling .expected.json files.")
    var updateExpected: Bool = false

    mutating func run() throws {
        let files: [String]
        do {
            files = try collectFiles(from: paths)
        } catch {
            printError("Error: \(error.localizedDescription)")
            throw ExitCode(2)
        }

        if files.isEmpty {
            printError("No .json files found in the specified paths.")
            throw ExitCode(2)
        }

        var allDiagnostics: [(file: String, diagnostics: [Diagnostic])] = []
        var hadReadError = false

        for file in files {
            let source: String
            do {
                source = try String(contentsOfFile: file, encoding: .utf8)
            } catch {
                printError("\(file): \(error.localizedDescription)")
                hadReadError = true
                continue
            }

            let result = Parser.parse(source)

            var diagnostics = Validator.validate(result)

            // Also surface parse errors as diagnostics
            for parseError in result.errors {
                diagnostics.append(Diagnostic(
                    range: parseError.range,
                    severity: .error,
                    code: parseError.code,
                    message: parseError.message))
            }

            diagnostics.sort { $0.range.lowerBound < $1.range.lowerBound }

            if updateExpected {
                let validationOnly = Validator.validate(result)
                try writeExpected(file: file, diagnostics: validationOnly)
            }

            allDiagnostics.append((file: file, diagnostics: diagnostics))
        }

        if hadReadError && allDiagnostics.isEmpty {
            throw ExitCode(2)
        }

        // Filter and output
        let filtered = allDiagnostics.map { entry -> (file: String, diagnostics: [Diagnostic]) in
            var diags = entry.diagnostics
            if quiet {
                diags = diags.filter { $0.severity != .inert }
            }
            return (file: entry.file, diagnostics: diags)
        }

        switch format {
        case .text:
            outputText(filtered)
        case .json:
            outputJSON(filtered)
        }

        // Determine exit code
        let hasErrors = filtered.contains { entry in
            entry.diagnostics.contains { diag in
                if diag.severity == .error { return true }
                if strict && diag.severity == .warning { return true }
                return false
            }
        }

        if hasErrors || hadReadError {
            throw ExitCode(hadReadError ? 2 : 1)
        }
    }

    // MARK: - File Collection

    private func collectFiles(from paths: [String]) throws -> [String] {
        let fm = FileManager.default
        var result: [String] = []

        for path in paths {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
                throw LintError.fileNotFound(path)
            }

            if isDir.boolValue {
                guard let enumerator = fm.enumerator(atPath: path) else {
                    throw LintError.cannotRead(path)
                }
                while let relative = enumerator.nextObject() as? String {
                    if relative.hasSuffix(".json") && !relative.hasSuffix(".expected.json") {
                        let full = (path as NSString).appendingPathComponent(relative)
                        result.append(full)
                    }
                }
            } else {
                result.append(path)
            }
        }

        return result.sorted()
    }

    // MARK: - Output

    private func outputText(_ entries: [(file: String, diagnostics: [Diagnostic])]) {
        for entry in entries {
            if entry.diagnostics.isEmpty { continue }
            let source: String
            do {
                source = try String(contentsOfFile: entry.file, encoding: .utf8)
            } catch {
                continue
            }
            let index = LineIndex(source)

            for diag in entry.diagnostics {
                let pos = index.position(at: diag.range.lowerBound)
                let sev = diag.severity.rawValue
                print("\(entry.file):\(pos.line):\(pos.column): \(sev) [\(diag.code)] \(diag.message)")
            }
        }
    }

    private func outputJSON(_ entries: [(file: String, diagnostics: [Diagnostic])]) {
        struct FileDiagnostics: Encodable {
            let file: String
            let diagnostics: [Diagnostic]
        }

        let output = entries.map { FileDiagnostics(file: $0.file, diagnostics: $0.diagnostics) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(output),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    // MARK: - Update Expected

    private func writeExpected(file: String, diagnostics: [Diagnostic]) throws {
        let baseName = (file as NSString).deletingPathExtension
        let expectedPath = baseName + ".expected.json"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(diagnostics)
        let json = String(data: data, encoding: .utf8)! + "\n"

        let existing = try? String(contentsOfFile: expectedPath, encoding: .utf8)
        if existing == json {
            printError("  unchanged: \(expectedPath)")
        } else {
            try json.write(toFile: expectedPath, atomically: true, encoding: .utf8)
            printError("  updated:   \(expectedPath)")
        }
    }

    // MARK: - Helpers

    private func printError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json
}

enum LintError: LocalizedError {
    case fileNotFound(String)
    case cannotRead(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "File not found: \(path)"
        case .cannotRead(let path): return "Cannot read: \(path)"
        }
    }
}
