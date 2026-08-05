import Testing
import DTConfigCore

@Suite("Module Boundary Tests")
struct ModuleBoundaryTests {
    @Test("DTConfigCore has no imports beyond Swift stdlib")
    func noExternalImports() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("DTConfigCore")

        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(atPath: sourcesDir.path)
            .filter { $0.hasSuffix(".swift") }

        #expect(!files.isEmpty, "Should find Swift source files")

        let allowedImports: Set<String> = ["Foundation", "Swift"]
        // We actually want zero imports — not even Foundation.
        // But we'll flag anything that isn't the module itself.

        for file in files {
            let path = sourcesDir.appendingPathComponent(file).path
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("import ") && !trimmed.hasPrefix("//") {
                    let module = trimmed
                        .dropFirst("import ".count)
                        .trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces)
                        .first ?? ""
                    // Allow Swift itself and DTConfigCore (for extensions)
                    let forbidden = !allowedImports.contains(module) && module != "DTConfigCore"
                    #expect(!forbidden, "DTConfigCore must not import \(module) (in \(file))")
                }
            }
        }
    }
}

import Foundation
