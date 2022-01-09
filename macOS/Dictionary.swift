//
//  Dictionary.swift
//  words (iOS)
//
//  Created by Dan Weiner on 4/10/21.
//

import Foundation
import Combine

struct DWError: LocalizedError, Identifiable {
    let id = UUID()

    let description: String

    var errorDescription: String? {
        description
    }
}

// Provides a Swift API around the `words` executable.
class Dictionary {

    enum Direction: Int, CustomStringConvertible, CustomDebugStringConvertible, Codable {
        // Do not change. Reflected in tags in interface builder.
        case latinToEnglish = 0
        case englishToLatin = 1

        var debugDescription: String {
            switch self {
            case .latinToEnglish: return "Ltn->Eng"
            case .englishToLatin: return "Eng->Ltn"
            }
        }

        var description: String {
            switch self {
            case .latinToEnglish: return "Latin → English"
            case .englishToLatin: return "English → Latin"
            }
        }

        mutating func toggle() {
            switch self {
            case .latinToEnglish: self = .englishToLatin
            case .englishToLatin: self = .latinToEnglish
            }
        }
    }

    struct Options: OptionSet {
        let rawValue: Int
        static let diagnosticMode = Options(rawValue: 1 << 0)
    }

    public static let shared = Dictionary()

    private lazy var executableURL: URL = {
        guard let url = Bundle.main.url(forAuxiliaryExecutable: "words") else {
            fatalError("Could not find words program file in bundle.")
        }
        return url
    }()
    private lazy var executablePath = executableURL.path
    private lazy var workingDir: URL = {
        guard var url = Bundle.main.url(forResource: "DICTFILE", withExtension: "GEN") else {
            fatalError("Could not find resource directory.")
        }
        return url.deletingLastPathComponent()
    }()

    func getDefinitions(_ terms: [String], direction: Direction, options: Options) async throws -> [(String, String?)] {
        var result: [(String, String?)] = []
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        #endif
        for term in terms {
            result.append(try await (term, getDefinition(term, direction: direction, options: options)))
        }
        #if DEBUG
        let durationMS = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print("Query took \(durationMS) ms")
        #endif
        return result
    }

    /// - Throws: `DWError`
    func getDefinition(_ search: String, direction: Direction, options: Options) async throws -> String? {
        var arguments: [String] = []
        // Add language control argument
        if direction == .englishToLatin {
            arguments.append("~e")
        }
        let search = trim(input: search)
        let words = Array(search.split(separator: " ")).map(String.init(_:))
        // English to latin only supports up to 2 words in query like "house n" or "travel v"
        if direction == .englishToLatin && words.count > 2 {
            throw DWError(description: "Query too long. For English-to-Latin, you can only enter 1 English word, or 1 English word and a part of speech (such as: \"attack verb\").")
        }
        arguments.append(contentsOf: words)

        if .diagnosticMode ~= options {
            let start = CFAbsoluteTimeGetCurrent()
            let output = try await runProcess(executablePath, arguments: arguments)
            let durationMS = (CFAbsoluteTimeGetCurrent() - start) * 1000
            return output + """
            \n\n\n\n
            time: \(String(format: "%.2f", durationMS))ms

            % words \(arguments.joined(separator: " "))
            \(output)
            """
        } else {
            return try await runProcess(executablePath, arguments: arguments)
        }
    }

    private func trim(input: String) -> String {
        let commandCharacters = CharacterSet(["#", "!", "@"])
        return input.trimmingCharacters(in: commandCharacters)
    }

    @discardableResult
    private func runProcess(
        _ launchPath: String,
        arguments: [String] = [],
        stdin: String? = nil
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let p = Process()
            p.currentDirectoryURL = workingDir
            p.launchPath = launchPath
            p.arguments = arguments
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            p.standardOutput = outputPipe
            p.standardError = errorPipe

            if let stdin = stdin {
                let pipe = Pipe()
                pipe.fileHandleForWriting.write(stdin.data(using: .utf8) ?? Data())
                p.standardInput = pipe
            }

            p.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: outputData, as: UTF8.self)

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let error = String(decoding: errorData, as: UTF8.self)

                if p.terminationStatus != 0 {
                    continuation.resume(with: .failure(DWError(description: "Program failed with exit code \(p.terminationStatus)")))
                }

                if error.count > 0 {
                    continuation.resume(with: .failure(DWError(description: error)))
                } else {
                    continuation.resume(with: .success(output))
                }
            }

            p.launch()
        }
    }
}
