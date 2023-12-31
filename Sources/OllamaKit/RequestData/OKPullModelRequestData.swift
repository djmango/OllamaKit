//
//  OKCopyModelRequestData.swift
//  
//
//  Created by Sulaiman Ghori on 12/30/23.
//
//

import Foundation

/// A structure representing the request data for copying a model via the Ollama API.
///
/// This structure holds the information necessary to duplicate a model, including the source model's name and the desired destination name.
public struct OKPullModelRequestData: Encodable {
    public let name: String
    public let insecure: Bool?
    public let stream: Bool?
    
    public init(name: String, insecure: Bool? = nil, stream: Bool? = nil) {
        self.name = name
        self.insecure = insecure
        self.stream = stream
    }
}

import Foundation
