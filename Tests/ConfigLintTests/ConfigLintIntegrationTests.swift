import Testing
import Foundation
import DTConfigCore

@Suite("ConfigLint Integration Tests")
struct ConfigLintIntegrationTests {

    private func fixturesPath() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .path
    }

    private func fixtureFiles() throws -> [String] {
        let dir = fixturesPath()
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(atPath: dir)
        return contents
            .filter { $0.hasSuffix(".json") && !$0.hasSuffix(".expected.json") }
            .sorted()
            .map { (dir as NSString).appendingPathComponent($0) }
    }

    // MARK: - All fixtures produce zero errors

    @Test("All fixture files validate with zero errors")
    func allFixturesZeroErrors() throws {
        let files = try fixtureFiles()
        #expect(!files.isEmpty, "Fixture directory should contain .json files")

        for file in files {
            let source = try String(contentsOfFile: file, encoding: .utf8)
            let result = Parser.parse(source)

            let parseErrors = result.errors
            #expect(parseErrors.isEmpty,
                    "Parse errors in \(file): \(parseErrors)")

            let diagnostics = Validator.validate(result)
            let errors = diagnostics.filter { $0.severity == .error }
            #expect(errors.isEmpty,
                    "Validation errors in \(file): \(errors)")
        }
    }

    // MARK: - CLI smoke test

    @Test("configlint runs over fixture directory with exit code 0")
    func cliExitCodeZero() throws {
        let binaryPath = try findBinary()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [fixturesPath()]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0,
                "configlint should exit 0 on valid fixtures. stderr: \(readPipe(stderr))")
    }

    @Test("configlint --format json produces valid JSON output")
    func cliJSONFormat() throws {
        let binaryPath = try findBinary()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--format", "json", fixturesPath()]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)

        let output = readPipe(stdout)
        let data = Data(output.utf8)
        // Should parse as valid JSON
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }

    @Test("configlint with nonexistent file exits with code 2")
    func cliNonexistentFile() throws {
        let binaryPath = try findBinary()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["/nonexistent/path/to/file.json"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 2)
    }

    @Test("configlint --version prints version")
    func cliVersion() throws {
        let binaryPath = try findBinary()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--version"]

        let stdout = Pipe()
        process.standardOutput = stdout

        try process.run()
        process.waitUntilExit()

        let output = readPipe(stdout)
        #expect(output.contains("0.1.0"))
    }

    // MARK: - Helpers

    private func findBinary() throws -> String {
        // The binary should be adjacent to the test bundle in the build directory.
        // Try common locations.
        let candidates = [
            // When running via `swift test`, the binary is in the build artifacts.
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(".build/debug/configlint")
                .path,
        ]

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        // Fallback: use `swift build` output path by searching common paths
        let fallback = findBinaryViaWhich()
        if let fallback {
            return fallback
        }

        throw ConfigLintTestError.binaryNotFound
    }

    private func findBinaryViaWhich() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["configlint"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let out = readPipe(pipe).trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? nil : out
    }

    private func readPipe(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum ConfigLintTestError: Error {
    case binaryNotFound
}
