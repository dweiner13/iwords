//
//  Dictionary2.swift
//  iWords (macOS)
//
//  Created by Dan Weiner on 1/9/22.
//

import Foundation
import Combine
import Flow

class Dictionary {
    var process: Process?
    var outputPipe: Pipe?
    var errorPipe: Pipe?
    var inputPipe: Pipe?

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

    init() {
        startProcess()
    }

    private var cancellables: [AnyCancellable] = []

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

        var tempData = Data()
        outputFileHandle.readabilityHandler = { [weak self] fileHandle in
            let newData = fileHandle.availableData
            tempData += newData
            print("Process: \(newData.count) new bytes", String(data: newData, encoding: .utf8))
            if String(data: tempData.dropFirst(41).suffix(2), encoding: .utf8) == "=>" {
                DispatchQueue.main.async {
                    self?.didGetResult(data: tempData.dropFirst(41))
                    tempData.removeAll()
                }
            }
        }
//        outputFileHandle.waitForDataInBackgroundAndNotify()
//        NotificationCenter.default.publisher(for: .NSFileHandleDataAvailable,
//                                             object: outputFileHandle)
//            .sink { [weak self] _ in
//                print("PROCESS: NEW DATA AVAILABLE")
//                let data = self!.outputPipe!.fileHandleForReading.
//                print("PROCESS: output:", String(data: data, encoding: .utf8))
//            }
//            .store(in: &cancellables)

        process = p

        p.terminationHandler = { [weak self] p in
            guard let self = self else { return }

            print("PROCESS KILLED")

            let outputData = self.outputPipe!.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: outputData, as: UTF8.self)

            let errorData = self.errorPipe!.fileHandleForReading.readDataToEndOfFile()
            let error = String(decoding: errorData, as: UTF8.self)

            if p.terminationStatus != 0 {
                print(DWError(description: "Process failed with exit code \(p.terminationStatus)"))
            }

            if error.count > 0 {
                print(DWError(description: error))
            } else {
                print(output)
            }
        }

        print("LAUNCHING PROCESS")

        p.launch()
    }

    var wordsDidFinishLoading = false

    func didGetResult(data: Data) {
        print("Process did get result data")
        guard wordsDidFinishLoading else {
            print("Process ignoring because this is just words loading...")
            wordsDidFinishLoading = true
            return
        }

        var str = String(data: data, encoding: .utf8)

        str = str?.trimmingCharacters(in: .whitespacesAndNewlines)
        if str?.suffix(2) == "=>" {
            str = str.map { $0.dropLast(2) }.map(String.init(_:))
        }
        str = str?.trimmingCharacters(in: .whitespacesAndNewlines)

        print("Process did get result data", str)

        print("Process returning with result data")

        activeContinuation?.resume(returning: str)
        activeContinuation = nil
    }

    private var activeContinuation: CheckedContinuation<String?, Never>?

    func getDefinitions(_ inputs: [String], direction: Direction, options: Options) async throws -> [(String, String?)] {
        var results: [(String, String?)] = []
        for input in inputs {
            print("Process: getting results for \(input)")
            results.append((input, try await getDefinition(input, direction: direction, options: options)))
            print("Process: GOT RESULTS FOR \(input)")
        }
        return results
    }

    private var queue: [(String, Direction, Options, CheckedContinuation<String?, Never>)] = []

    deinit {
        process?.terminate()
    }

    func getDefinition(_ input: String, direction: Direction, options: Options) async throws -> String? {
        guard input.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 else {
            return nil
        }
        guard activeContinuation == nil else {
            throw DWError(description: "Lookup already in progress")
        }
        return await withCheckedContinuation { checkedContinuation in
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
}
