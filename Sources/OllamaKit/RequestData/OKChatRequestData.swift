//
//  OKChatRequestData.swift
//
//
//  Created by Augustinas Malinauskas on 12/12/2023.
//

import Foundation

/// A structure representing the data required to generate responses from the Ollama API.
///
/// It includes the model name, prompt, and other optional parameters that tailor the generation process, such as format and context.
public struct OKChatRequestData: Encodable {
    /// The name of the model to use.
    public let model: String
    /// The chat history (prompt) to use for generation.
    public let messages: [ChatMessage]
    public var format: Format?
    public var options: Options?
    public var template: String?
    /// Whether to stream the response or not. Defaults to true.
    public var stream: Bool = true

    public init(model: String, messages: [ChatMessage]) {
        self.model = model
        self.messages = messages
    }
}

public struct ChatMessage: Encodable {
    /// The role of the message sender. Can be either "user", "assistant", or "system".
    public var role: String
    /// The message content.
    public var content: String
    /// A list of base64-encoded images.
    public var images: [String]?

    public init(role: String, content: String, images: [String]? = nil) {
        self.role = role
        self.content = content
        self.images = images
    }
}

public enum Format: String, Encodable {
    case json
}

public struct Options: Encodable {
    public var mirostat: Int?
    public var mirostatEta: Double?
    public var mirostatTau: Double?
    public var numCtx: Int?
    public var numGqa: Int?
    public var numGpu: Int?
    public var numThread: Int?
    public var repeatLastN: Int?
    public var repeatPenalty: Int?
    public var temperature: Double?
    public var seed: Int?
    public var stop: String?
    public var tfsZ: Double?
    public var numPredict: Int?
    public var topK: Int?
    public var topP: Double?
}
