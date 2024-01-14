//
//  OllamaKit.swift
//
//
//  Created by Kevin Hermawan on 10/11/23.
//

import Alamofire
import Cocoa
import Combine
import CoreServices
import Foundation

/// A Swift library for interacting with the Ollama API.
///
/// `OllamaKit` simplifies the process of connecting Swift applications to the Ollama API, abstracting the complexities of network requests and data handling.
///  Operates as a singleton, starts the Ollama API server process on init
public class OllamaKit {
    public static let shared = OllamaKit(baseURL: URL(string: "http://localhost:11434")!)

    private var router: OKRouter.Type
    private var decoder: JSONDecoder = .default
    private var binaryProcess: Process?

    /// Initializes a new instance of `OllamaKit` with the specified base URL for the Ollama API.
    ///
    /// This initializer configures `OllamaKit` with a base URL, laying the groundwork for all network interactions with the Ollama API. It ensures that the library is properly set up to communicate with the API endpoints.
    ///
    /// - Parameter baseURL: The base URL to be used for Ollama API requests.
    private init(baseURL: URL) {
        let router = OKRouter.self
        router.baseURL = baseURL

        self.router = router

        // Manage Ollama lifecycle
        runBinaryInBackground(withArguments: ["serve"])
    }
}

public extension OllamaKit {
    /// Checks the reachability of the Ollama API.
    ///
    /// This asynchronous method performs a network request to determine if the Ollama API is reachable from the current client.
    /// It can be used to verify network connectivity and API availability before attempting further API interactions.
    ///
    /// - Returns: A Boolean value indicating whether the Ollama API is reachable (`true`) or not (`false`).
    func reachable() async -> Bool {
        let request = AF.request(router.root).validate()
        let response = request.serializingData()

        do {
            _ = try await response.value

            return true
        } catch {
            runBinaryInBackground(withArguments: ["serve"])
            return false
        }
    }
}

public extension OllamaKit {
    ///  Starts the Ollama API in a background thread via the ollama-darwin binary bundled in the parent app
    ///  Saves a reference to the process to manage later
    ///  Will start by clearing out any processes using the desired port
    internal func runBinaryInBackground(withArguments args: [String]) {
        // If there already is a running instance of Ollama, we will have to kill it
        killProcessUsingPort(port: 11434)

        // Grab binary
        if let binaryPath = Bundle.main.path(forResource: "ollama-darwin", ofType: nil) {
            print("Ollama binary found")
            // Run in background
            DispatchQueue.global(qos: .background).async {
                let process = Process()
                self.binaryProcess = process
                process.executableURL = URL(fileURLWithPath: binaryPath)
                process.arguments = args

                // Create a pipe and attach it to process's standard output
                let outputPipe = Pipe()
                process.standardOutput = outputPipe

                // Create another pipe for standard error
                let errorPipe = Pipe()
                process.standardError = errorPipe

                print("Running Ollama")
                do {
                    try process.run()

                    // Read the output data
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if let outputString = String(data: outputData, encoding: .utf8) {
                        DispatchQueue.main.async {
                            print("Output: \(outputString)")
                        }
                    }

                    // Read the error data
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                        DispatchQueue.main.async {
                            print("Error: \(errorString)")
                        }
                    }

                    process.waitUntilExit()

                    DispatchQueue.main.async {
                        print("Process terminated with status: \(process.terminationStatus)")
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Failed to start process: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            print("Failed to locate binary in app bundle.")
        }
    }

    func terminateBinaryProcess() {
        // Terminate the binary process
        binaryProcess?.terminate()
        // Kill orphaned processes
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        // Define the command to run
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "ps aux | grep ollama-darwin | grep -v grep | awk '{print $2}' | xargs kill"]

        do {
            try process.run()
            process.waitUntilExit()

            // Read and print the output
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
        } catch {
            print("Failed to execute command: \(error)")
        }
    }

    /// Restarts the Ollama binary process and waits for the API to become reachable.
    ///
    /// - Returns: `true` if the API becomes reachable within 5 seconds, `false` otherwise.
    func restartBinaryAndWaitForAPI() async -> Bool {
        // Terminate existing binary process
        terminateBinaryProcess()

        // Restart the binary process
        runBinaryInBackground(withArguments: ["serve"])

        // Set a timeout for the API to become reachable
        let timeoutSeconds = 5
        let deadline = DispatchTime.now() + .seconds(timeoutSeconds)

        // Check for API reachability within the timeout period
        while DispatchTime.now() < deadline {
            if await reachable() {
                print("API is reachable after restart.")
                return true
            }
            // Wait for a short period before trying again
            try? await Task.sleep(nanoseconds: 500_000_000) // Sleep for 0.5 second
        }

        print("Failed to reach API within \(timeoutSeconds) seconds after restart.")
        return false
    }
}

public extension OllamaKit {
    /// Establishes a Combine publisher for streaming responses from the Ollama API, based on the provided data.
    ///
    /// This method sets up a streaming connection using the Combine framework, allowing for real-time data handling as the responses are generated by the Ollama API.
    ///
    /// - Parameter data: The `OKGenerateRequestData` used to initiate the streaming from the Ollama API.
    /// - Returns: An `AnyPublisher` emitting `OKGenerateResponse` and `AFError`, representing the live stream of responses from the Ollama API.
    func generate(data: OKGenerateRequestData) -> AnyPublisher<OKGenerateResponse, AFError> {
        let subject = PassthroughSubject<OKGenerateResponse, AFError>()
        let request = AF.streamRequest(router.generate(data: data)).validate()

        request.responseStreamDecodable(of: OKGenerateResponse.self, using: decoder) { stream in
            switch stream.event {
            case let .stream(result):
                switch result {
                case let .success(response):
                    subject.send(response)
                case let .failure(error):
                    subject.send(completion: .failure(error))
                }
            case .complete:
                subject.send(completion: .finished)
            }
        }

        return subject.eraseToAnyPublisher()
    }
}

extension OllamaKit {
    /// Establishes a Combine publisher for streaming responses from the Ollama API, based on the provided data.
    ///
    /// This method sets up a streaming connection using the Combine framework, allowing for real-time data handling as the responses are generated by the Ollama API. When proxying stream some events are combined into a single response. To account for this a buffer is implemented to to separate JSON objects.
    ///
    /// - Parameter data: The `OKChatRequestData` used to initiate the streaming from the Ollama API.
    /// - Returns: An `AnyPublisher` emitting `OKGenerateResponse` and `Error`, representing the live stream of responses from the Ollama API.
    public func chat(data: OKChatRequestData) -> AnyPublisher<OKChatResponse, Error> {
        let subject = PassthroughSubject<OKChatResponse, Error>()
        let request = AF.streamRequest(router.chat(data: data)).validate()

        var buffer = Data()

        request.responseStream { stream in
            switch stream.event {
            case let .stream(result):
                switch result {
                case let .success(data):
                    // Append the new data to the buffer
                    buffer.append(data)

                    // Try to decode buffered data
                    while let jsonChunk = self.extractNextJSONObject(from: &buffer) {
                        do {
                            let response = try self.decoder.decode(OKChatResponse.self, from: jsonChunk)
                            subject.send(response)
                        } catch {
                            print("FAILURE: \(jsonChunk)")
                            let jsonObject = try JSONSerialization.jsonObject(with: jsonChunk, options: [])
                            print(jsonObject)
                            subject.send(completion: .failure(error))
                            return
                        }
                    }

                case let .failure(error):
                    subject.send(completion: .failure(error))
                }

            case .complete:
                subject.send(completion: .finished)
            }
        }

        return subject.eraseToAnyPublisher()
    }

    func extractNextJSONObject(from buffer: inout Data) -> Data? {
        var depth = 0
        var isInsideString = false
        var isEscape = false
        var lastIndex = buffer.startIndex

        for (index, byte) in buffer.enumerated() {
            let character = Character(UnicodeScalar(byte))

            if isEscape {
                // Skip this character, it's escaped
                isEscape = false
            } else if character == "\\" {
                // Next character is escaped
                isEscape = true
            } else if character == "\"" {
                // Toggle the inside string state
                isInsideString.toggle()
            } else if !isInsideString {
                // Process only if not inside a string
                switch character {
                case "{":
                    depth += 1
                    if depth == 1 {
                        // Mark the start of a JSON object
                        lastIndex = index
                    }
                case "}":
                    depth -= 1
                    if depth == 0 {
                        // Found the end of a JSON object
                        let range = lastIndex ..< buffer.index(after: index)
                        let jsonObjectData = buffer.subdata(in: range)
                        buffer.removeSubrange(range)
                        return jsonObjectData
                    }
                default:
                    break
                }
            }
        }

        return nil
    }
}

public extension OllamaKit {
    /// Asynchronously retrieves a list of available models from the Ollama API.
    ///
    /// This method returns an `OKModelResponse` containing the details of the available models, making it easy to understand what models are currently accessible.
    ///
    /// - Returns: An `OKModelResponse` object listing the available models.
    func models() async throws -> OKModelResponse {
        let request = AF.request(router.models).validate()
        let response = request.serializingDecodable(OKModelResponse.self, decoder: decoder)

        let val = try await response.value
        print(val)
        return val
    }
}

public extension OllamaKit {
    /// Asynchronously fetches detailed information about a specific model from the Ollama API.
    ///
    /// This method provides comprehensive details about the model, such as its modelfile, template, and parameters.
    ///
    /// - Parameter data: The data specifying the model to inquire about.
    /// - Returns: An `OKModelInfoResponse` containing detailed information about the model.
    func modelInfo(data: OKModelInfoRequestData) async throws -> OKModelInfoResponse {
        let request = AF.request(router.modelInfo(data: data)).validate()
        let response = request.serializingDecodable(OKModelInfoResponse.self, decoder: decoder)

        return try await response.value
    }
}

public extension OllamaKit {
    /// Facilitates the duplication of an existing model, creating a new instance under a different name.
    ///
    /// This asynchronous method makes it straightforward to copy a model, requiring only the necessary parameters for the operation.
    ///
    /// - Parameter data: The data required for the model copy operation.
    /// - Throws: An error if the copy operation fails.
    func copyModel(data: OKCopyModelRequestData) async throws {
        let request = AF.request(router.copyModel(data: data)).validate()
        let serializedData = request.serializingData()

        _ = await serializedData.response
    }
}

public extension OllamaKit {
    /// Facilitates the downloading of a model.
    /// Establishes a Combine publisher for streaming responses from the Ollama API, based on the provided data.
    ///
    /// This method sets up a streaming connection using the Combine framework, allowing for real-time data handling as the responses are generated by the Ollama API. When proxying stream some events are combined into a single response. To account for this a buffer is implemented to to separate JSON objects.
    ///
    /// - Parameter data: The `OKPullModelRequestData` used to initiate the streaming from the Ollama API.
    /// - Returns: An `AnyPublisher` emitting `OkPullModelResponse` and `Error`, representing the live stream of responses from the Ollama API.
    func pullModel(data: OKPullModelRequestData) -> AnyPublisher<OKModelPullResponse, Error> {
        let subject = PassthroughSubject<OKModelPullResponse, Error>()
        let request = AF.streamRequest(router.pullModel(data: data)).validate()

        var buffer = Data()

        request.responseStream { stream in
            switch stream.event {
            case let .stream(result):
                switch result {
                case let .success(data):
                    // Append the new data to the buffer
                    buffer.append(data)

                    // Try to decode buffered data
                    while let jsonChunk = self.extractNextJSONObject(from: &buffer) {
                        do {
                            let response = try self.decoder.decode(OKModelPullResponse.self, from: jsonChunk)
                            subject.send(response)
                        } catch {
                            print("FAILURE: \(jsonChunk)")
                            let jsonObject = try JSONSerialization.jsonObject(with: jsonChunk, options: [])
                            print(jsonObject)
                            subject.send(completion: .failure(error))
                            return
                        }
                    }

                case let .failure(error):
                    subject.send(completion: .failure(error))
                }

            case .complete:
                subject.send(completion: .finished)
            }
        }

        return subject.eraseToAnyPublisher()
    }
}

public extension OllamaKit {
    /// Removes a specified model and its data from the Ollama API.
    ///
    /// This asynchronous method allows for the deletion of a model, requiring the model name to be specified for a successful operation.
    ///
    /// - Parameter data: The data specifying the model to be deleted.
    /// - Throws: An error if the deletion fails.
    func deleteModel(data: OKDeleteModelRequestData) async throws {
        let request = AF.request(router.deleteModel(data: data)).validate()
        let serializedData = request.serializingData()

        _ = await serializedData.response
    }
}
