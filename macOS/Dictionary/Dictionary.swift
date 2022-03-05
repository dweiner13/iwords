//
//  Dictionary.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/9/22.
//

import Foundation
import Flow

struct DWError: LocalizedError, Identifiable, CustomNSError {
    let id = UUID()

    let description: String

    var errorDescription: String? {
        description
    }

    let _recoverySuggestion: String?

    var recoverySuggestion: String {
        _recoverySuggestion ?? ""
    }

    static var errorDomain: String {
        "org.iwords.iwords.errorDomain"
    }

    var errorCode: Int {
        return 1
    }

    var errorUserInfo: [String : Any] {
        [NSLocalizedRecoverySuggestionErrorKey: recoverySuggestion as Any]
    }

    init(_ description: String, recoverySuggestion: String? = nil) {
        self.description = description
        self._recoverySuggestion = recoverySuggestion
    }
}

protocol DictionaryDelegate: AnyObject {
    /// - note: 0 <= progress <= 1
    func dictionary(_ dictionary: Dictionary, progressChangedTo progress: Double)
}

class Dictionary {

    // MARK: - Types

    @objc
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
    private lazy var bundleWorkingDir = Bundle.main.url(forResource: "DICTFILE", withExtension: "GEN")!
        .deletingLastPathComponent()
    private lazy var workingDir: URL = {
        DictionaryRelocator.wasRelocationPerformed()
            ? ((try? DictionaryRelocator.dictionarySupportURL()) ?? bundleWorkingDir)
            : bundleWorkingDir
    }()

    private var activeCompletionHandler: ((Result<String?, DWError>) -> Void)?
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var inputPipe: Pipe?

    private var timer: Timer?

    // MARK: - Init

    init() {
        startProcess()
    }

    deinit {
        process?.terminate()
    }

    static func sanitize(input: String) -> String? {
        let trimmed = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(["#", "!", "@", "~"]))
        return trimmed.count > 1 ? trimmed : nil
    }

    // MARK: - Methods

    func getDefinitions(_ inputs: [String],
                        direction: Direction,
                        options: Options,
                        completion: @escaping (Result<[(String, String?)], DWError>) -> Void) {
        guard !inputs.isEmpty else {
            completion(.success([]))
            return
        }

        var results: [(String, String?)] = []
        let totalCount = Double(inputs.count)
        var completedCount: Double = 0

        func processInput(at i: Int) {
//            print("Looking up \"\(inputs[i])\"")
            getDefinition(inputs[i], direction: direction, options: options) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let result):
//                    print("Got result for \"\(inputs[i])\"")
                    results.append((inputs[i], result))
                    completedCount += 1
                    let progress = completedCount / totalCount
                    DispatchQueue.main.async {
                        self.delegate?.dictionary(self, progressChangedTo: progress)
                    }
                    if inputs.indices.contains(i + 1) {
                        processInput(at: i + 1)
                    } else {
                        completion(.success(results))
                    }
                }
            }
        }
        processInput(at: 0)
    }

    func getDefinition(_ input: String,
                       direction: Direction,
                       options: Options,
                       completion: @escaping (Result<String?, DWError>) -> Void) {
        guard input.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 else {
            completion(.success(nil))
            return
        }
        guard activeCompletionHandler == nil else {
            completion(.failure(DWError("Lookup already in progress")))
            return
        }

        func write(_ str: String) {
#if DEBUG
//            print("Sending to stdin:", str)
#endif
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

        self.activeCompletionHandler = completion

        timer = .scheduledTimer(withTimeInterval: 5, repeats: false, block: { [weak self] timer in
            guard let self = self else {
                return
            }
            guard self.activeCompletionHandler != nil else {
                return
            }

            self.restartProcess()

            self.complete(with: .failure(DWError("The operation timed out. Please try again.")))
        })
    }

    // MARK: - Private methods

    private var tempData = Data()
    private func handleNewData(from fileHandle: FileHandle) {
        let newData = fileHandle.availableData
        tempData += newData

        #if DEBUG
//        print("New data available:", String(data: newData  , encoding: .utf8))
        #endif

        // Always prefix of an English-to-Latin result
        let englishToLatinPrefix = "Language changed to ENGLISH_TO_LATIN\nInput a single English word (+ part of speech - N, ADJ, V, PREP, . .. )\n\n=>"
        // Always prefix of a Latin-to-English result
        let latinToEnglishPrefix = "Language changed to LATIN_TO_ENGLISH\n\n=>"

        guard let tempDataString = String(data: tempData, encoding: .utf8) else {
            fatalError()
        }

        #if DEBUG
//        print("tempDataString", tempDataString)
        #endif

        if case let cmp = tempDataString.components(separatedBy: englishToLatinPrefix),
           cmp.count > 1,
           let lastCmp = cmp.last,
           lastCmp.hasSuffix("\n=>") {
            tempData.removeAll()
            DispatchQueue.main.async {
                self.handleDefinitionResult(lastCmp)
            }
        } else if case let cmp = tempDataString.components(separatedBy: latinToEnglishPrefix),
                  cmp.count > 1,
                  let lastCmp = cmp.last,
                  lastCmp.hasSuffix("\n=>") {
            tempData.removeAll()
            DispatchQueue.main.async {
                self.handleDefinitionResult(lastCmp)
            }
        }
    }

    private func handleDefinitionResult(_ str: String) {
        assert(Thread.current.isMainThread)

        #if DEBUG
//        print("handleDefinitionResult(\"\(str)\")")
        #endif

        var str = str
        str = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.suffix(2) == "=>" {
            str = String(str.dropLast(2))
        }
        str = str.trimmingCharacters(in: .whitespacesAndNewlines)

        complete(with: .success(str))
    }

    /// - Precondition: is main thread
    private func complete(with result: Result<String?, DWError>) {
        precondition(Thread.isMainThread)

        timer?.invalidate()
        timer = nil

        let handler = activeCompletionHandler
        activeCompletionHandler = nil

        if needsRestart {
            needsRestart = false
            restartProcess()
        }

        handler?(result)
    }

    private var needsRestart = false

    func setNeedsRestart() {
        if activeCompletionHandler != nil {
            needsRestart = true
        } else {
            restartProcess()
        }
    }

    private func restartProcess() {
        complete(with: .failure(DWError("Process restarted")))

        process?.terminate()
        process = nil

        startProcess()
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

            if process.terminationStatus != SIGTERM {
                DispatchQueue.main.async {
                    self.complete(with: .failure(DWError("Process failed with exit code \(process.terminationStatus)")))
                }
                return
            }
        }

        p.launch()
    }
}
