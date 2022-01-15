//
//  Dictionary.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/9/22.
//

import Foundation
import Combine
import Flow

struct DWError: LocalizedError, Identifiable {
    let id = UUID()

    let description: String

    var errorDescription: String? {
        description
    }
}

protocol DictionaryDelegate: AnyObject {
    /// - note: 0 <= progress <= 1
    func dictionary(_ dictionary: Dictionary, progressChangedTo progress: Double)
}

class Dictionary {

    // MARK: - Types

    enum Direction: Int, CustomStringConvertible, CustomDebugStringConvertible, Codable, CaseIterable {
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

    weak var delegate: DictionaryDelegate?

    // MARK: - Private vars

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

    private var wordsDidFinishLoading = false
    private var activeContinuation: CheckedContinuation<String?, Error>?
    private var queue: [(String, Direction, Options, CheckedContinuation<String?, Never>)] = []
    private var cancellables: [AnyCancellable] = []
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var inputPipe: Pipe?

    // MARK: - Init

    init() {
        startProcess()
    }

    deinit {
        process?.terminate()
    }

    // MARK: - Methods

    func getDefinitions(_ inputs: [String], direction: Direction, options: Options) async throws -> [(String, String?)] {
        var results: [(String, String?)] = []
        let totalCount = Double(inputs.count)
        var completedCount: Double = 0
        for input in inputs {
            print("Looking up \"\(input)\"")
            results.append((input, try await getDefinition(input, direction: direction, options: options)))
            completedCount += 1
            let progress = completedCount / totalCount
            DispatchQueue.main.async {
                self.delegate?.dictionary(self, progressChangedTo: progress)
            }
            print("Got result for \"\(input)\"")
        }
        return results
    }

    func getDefinition(_ input: String, direction: Direction, options: Options) async throws -> String? {
        guard input.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 else {
            return nil
        }
        guard activeContinuation == nil else {
            throw DWError(description: "Lookup already in progress")
        }
        return try await withCheckedThrowingContinuation { checkedContinuation in
            func write(_ str: String) {
                inputPipe!.fileHandleForWriting.write(str.data(using: .utf8)!)
            }

            switch direction {
            case .latinToEnglish:
                write("~L\n")
            case .englishToLatin:
                write("~E\n")
            }
            write(input)
            write("\n")

            self.activeContinuation = checkedContinuation
        }
    }

    // MARK: - Private methods

    private var tempData = Data()
    private func handleNewData(from fileHandle: FileHandle) {
        let newData = fileHandle.availableData
        tempData += newData

        #if DEBUG
        print("New data available:", String(data: tempData, encoding: .utf8))
        #endif

        // Always prefix of an English-to-Latin result
        let englishToLatinPrefix = "Language changed to ENGLISH_TO_LATIN\nInput a single English word (+ part of speech - N, ADJ, V, PREP, . .. )\n\n=>"
        // Always prefix of a Latin-to-English result
        let latinToEnglishPrefix = "Language changed to LATIN_TO_ENGLISH\n\n=>"

        guard let string = String(data: tempData, encoding: .utf8) else {
            return
        }

        if string.hasPrefix(englishToLatinPrefix),
           case let trimmed = string.dropFirst(englishToLatinPrefix.count),
           trimmed.hasSuffix("\n=>") {
            DispatchQueue.main.async {
                self.handleDefinitionResult(String(trimmed))
                self.tempData.removeAll()
            }
        } else if string.hasPrefix(latinToEnglishPrefix),
                  case let trimmed = string.dropFirst(latinToEnglishPrefix.count),
                  trimmed.hasSuffix("\n=>") {
            DispatchQueue.main.async {
                self.handleDefinitionResult(String(trimmed))
                self.tempData.removeAll()
            }
        } else if string.hasSuffix("[tilde E]\n\n=>") {
            // This is the end of the initialization message, just ignore it
            DispatchQueue.main.async {
                self.tempData.removeAll()
            }
        }
    }

    private func handleDefinitionResult(_ str: String) {
        #if DEBUG
        print("handleDefinitionResult(\"\(str)\")")
        #endif

        var str = str
        str = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.suffix(2) == "=>" {
            str = String(str.dropLast(2))
        }
        str = str.trimmingCharacters(in: .whitespacesAndNewlines)

        activeContinuation?.resume(returning: str)
        activeContinuation = nil
    }

    private func startProcess() {
        guard process == nil else {
            fatalError("Process already exists")
        }

        let p = Process()
        p.currentDirectoryURL = workingDir
        p.launchPath = executablePath
        p.arguments = []
        outputPipe = Pipe()
        errorPipe = Pipe()
        inputPipe = Pipe()
        p.standardOutput = outputPipe
        p.standardError = errorPipe
        p.standardInput = inputPipe

        let outputFileHandle = outputPipe!.fileHandleForReading

        outputFileHandle.readabilityHandler = { [weak self] fh in
            self?.handleNewData(from: fh)
        }

        process = p

        p.terminationHandler = { [weak self] process in
            guard let self = self else { return }

            if process.terminationStatus != 0 {
                self.activeContinuation!.resume(throwing: DWError(description: "Process failed with exit code \(process.terminationStatus)"))
                return
            }
        }

        p.launch()
    }
}
