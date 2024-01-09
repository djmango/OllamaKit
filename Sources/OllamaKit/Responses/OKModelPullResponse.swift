//
//  OKModelPullResponse.swift
//
//
//  Created by Sulaiman Khan Ghori on 1/9/24.
//

import Foundation

/// A structure representing the response from a model pull request to the Ollama API.
public struct OKModelPullResponse: Decodable {
    /// The status of the model pull request.
    public let status: String
    /// The name of the model.
    public let digest: String?
    /// The number of bytes in the model.
    public let total: Int?
    /// The number of bytes downloaded so far.
    public let completed: Int?
}
