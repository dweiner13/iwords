//
//  Dictionary.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/9/22.
//

import Foundation
import Darwin

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

@MainActor
protocol DictionaryDelegate: AnyObject {
    func dictionary(_ dictionary: Dictionary, progressChangedTo progress: Double)
}

/// Compatibility facade for storyboard clients. All process ownership lives in WordsEngine.
@MainActor
final class Dictionary {
    @objc
    enum Direction: Int, CustomStringConvertible, CustomDebugStringConvertible, Codable, CaseIterable, Sendable {
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

    weak var delegate: DictionaryDelegate?
    private let engine: any DictionaryEngine
    private var tasks: [UUID: Task<Void, Never>] = [:]

    init(engine: any DictionaryEngine = WordsEngine()) { self.engine = engine }

    deinit { tasks.values.forEach { $0.cancel() } }

    nonisolated static func sanitize(input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(["#", "!", "@", "~"]))
        return value.isEmpty ? nil : value
    }

    func cancel() { tasks.values.forEach { $0.cancel() } }

    func getDefinition(_ input: String, direction: Direction,
                       completion: @escaping (Swift.Result<String?, DWError>) -> Void) {
        getDefinitions([input], direction: direction) {
            completion($0.map { $0.first?.1 })
        }
    }

    func getDefinitions(_ inputs: [String], direction: Direction,
                        completion: @escaping (Swift.Result<[(String, String?)], DWError>) -> Void) {
        let id = UUID()
        let engine = engine
        tasks[id] = Task { [weak self] in
            do {
                var results: [(String, String?)] = []
                let directory = try DictionaryRelocator.makeWorkspace()
                defer { try? FileManager.default.removeItem(at: directory) }
                for input in inputs {
                    try Task.checkCancellation()
                    let output = try await engine.lookup(input, direction: direction, directory: directory)
                    try Task.checkCancellation()
                    results.append((input, output))
                    if let self { self.delegate?.dictionary(self, progressChangedTo: Double(results.count) / Double(inputs.count)) }
                }
                completion(.success(results))
            } catch {
                completion(.failure(DWError(error.localizedDescription)))
            }
            self?.tasks[id] = nil
        }
    }
}

protocol DictionaryEngine: Sendable {
    func lookup(_ input: String, direction: Dictionary.Direction, directory: URL) async throws -> String?
}

enum EngineError: LocalizedError {
    case missingResources, invalidInput, outputLimit, timeout, exited(Int32)

    var errorDescription: String? {
        switch self {
        case .missingResources: return "Dictionary engine resources are missing."
        case .invalidInput: return "Please enter a single word of at most 256 bytes."
        case .outputLimit: return "Dictionary output exceeded its size limit."
        case .timeout: return "The dictionary lookup timed out."
        case .exited(let status): return "Dictionary engine exited (\(status))."
        }
    }
}

/// The explicit gate remains held across suspension points; actor isolation alone
/// does not serialize complete asynchronous requests.
actor WordsEngine: DictionaryEngine {
    private var busy = false
    private var waiters: [(UUID, CheckedContinuation<Void, Error>)] = []
    private let executable: URL?
    private let outputLimit: Int
    private let timeout: Duration

    init(executable: URL? = Bundle.main.url(forAuxiliaryExecutable: "words"),
         outputLimit: Int = 4 * 1024 * 1024, timeout: Duration = .seconds(5)) {
        self.executable = executable
        self.outputLimit = outputLimit
        self.timeout = timeout
    }

    private func acquire() async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            if busy {
                try await withCheckedThrowingContinuation { waiters.append((id, $0)) }
            } else { busy = true }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.0 == id }) else { return }
        waiters.remove(at: index).1.resume(throwing: CancellationError())
    }

    private func release() {
        if waiters.isEmpty { busy = false }
        else { waiters.removeFirst().1.resume() }
    }

    func lookup(_ input: String, direction: Dictionary.Direction, directory: URL) async throws -> String? {
        try await acquire()
        defer { release() }
        try Task.checkCancellation()
        guard let word = Dictionary.sanitize(input: input) else { return nil }
        guard word.utf8.count <= 256, !word.contains(where: \.isWhitespace),
              word.rangeOfCharacter(from: .controlCharacters) == nil else { throw EngineError.invalidInput }
        guard let executable else { throw EngineError.missingResources }
        let process = Process()
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.executableURL = executable
        process.currentDirectoryURL = directory
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        defer {
            for handle in [stdin.fileHandleForWriting, stdin.fileHandleForReading,
                           stdout.fileHandleForWriting, stdout.fileHandleForReading,
                           stderr.fileHandleForWriting, stderr.fileHandleForReading] { try? handle.close() }
        }
        try process.run()
        do {
            // Fixed nonblocking reads bound memory without accumulating callback tasks.
            for handle in [stdout.fileHandleForReading, stderr.fileHandleForReading] {
                let fd = handle.fileDescriptor
                let flags = fcntl(fd, F_GETFL)
                guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else {
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
            }
            let command = direction == .latinToEnglish ? "~L" : "~E"
            try stdin.fileHandleForWriting.write(contentsOf: Data("\(command)\n\(word)\n".utf8))
            let deadline = ContinuousClock.now + timeout
            var output = Data()
            var total = 0
            let prefix = direction == .latinToEnglish
                ? "Language changed to LATIN_TO_ENGLISH\n\n=>"
                : "Language changed to ENGLISH_TO_LATIN\nInput a single English word (+ part of speech - N, ADJ, V, PREP, . .. )\n\n=>"
            while true {
                try Task.checkCancellation()
                for (handle, capture) in [(stdout.fileHandleForReading, true), (stderr.fileHandleForReading, false)] {
                    var buffer = [UInt8](repeating: 0, count: 8192)
                    let count = read(handle.fileDescriptor, &buffer, buffer.count)
                    if count < 0 && errno != EAGAIN && errno != EINTR {
                        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                    }
                    if count > 0 {
                        total += count
                        guard total <= outputLimit else { throw EngineError.outputLimit }
                        if capture { output.append(contentsOf: buffer.prefix(count)) }
                    }
                }
                if let text = String(data: output, encoding: .utf8),
                   let range = text.range(of: prefix), text[range.upperBound...].hasSuffix("\n=>") {
                    let result = String(text[range.upperBound...].dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    await stop(process)
                    return result
                }
                guard process.isRunning else { throw EngineError.exited(process.terminationStatus) }
                guard ContinuousClock.now < deadline else { throw EngineError.timeout }
                try await Task.sleep(for: .milliseconds(5))
            }
        } catch {
            await stop(process)
            throw error
        }
    }

    private func stop(_ process: Process) async {
        guard process.isRunning else { return }
        process.terminate()
        // Cleanup must finish even when the requesting task has been cancelled.
        await Task.detached {
            let deadline = ContinuousClock.now + .milliseconds(200)
            while process.isRunning && ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(5))
            }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            // Foundation reaps the child before isRunning becomes false. Avoid
            // blocking a cooperative executor thread in waitUntilExit().
            while process.isRunning {
                try? await Task.sleep(for: .milliseconds(5))
            }
        }.value
    }
}
