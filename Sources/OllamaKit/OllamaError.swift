//
//  OllamaError.swift
//
//
//  Created by Sulaiman Ghori on 1/15/24.
//

import Foundation

enum OllamaError: LocalizedError {
    case apiNotReachable

    var errorDescription: String? {
        switch self {
        case .apiNotReachable:
            return "The API could not be reached."
        }
    }
}
