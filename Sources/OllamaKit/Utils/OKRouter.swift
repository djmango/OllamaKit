//
//  OKRouter.swift
//
//
//  Created by Kevin Hermawan on 10/11/23.
//

import Alamofire
import Foundation

enum OKRouter {
    case root
    case models
    case modelInfo(data: OKModelInfoRequestData)
    case generate(data: OKGenerateRequestData)
    case chat(data: OKChatRequestData)
    case copyModel(data: OKCopyModelRequestData)
    case pullModel(data: OKPullModelRequestData)
    case deleteModel(data: OKDeleteModelRequestData)

    var path: String {
        switch self {
        case .root:
            return "/"
        case .models:
            return "/api/tags"
        case .modelInfo:
            return "/api/show"
        case .generate:
            return "/api/generate"
        case .chat:
            return "/api/chat"
        case .copyModel:
            return "/api/copy"
        case .pullModel:
            return "/api/pull"
        case .deleteModel:
            return "/api/delete"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .root:
            return .head
        case .models:
            return .get
        case .modelInfo:
            return .post
        case .generate:
            return .post
        case .chat:
            return .post
        case .copyModel:
            return .post
        case .pullModel:
            return .post
        case .deleteModel:
            return .delete
        }
    }

    var headers: HTTPHeaders {
        ["Content-Type": "application/json"]
    }
}

extension OKRouter: URLRequestConvertible {
    func asURLRequest() throws -> URLRequest {
        let url = OllamaKit.shared.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.method = method
        request.headers = headers

        switch self {
        case let .modelInfo(data):
            request.httpBody = try JSONEncoder.default.encode(data)
        case let .generate(data):
            request.httpBody = try JSONEncoder.default.encode(data)
        case let .chat(data):
            request.httpBody = try JSONEncoder.default.encode(data)
        case let .copyModel(data):
            request.httpBody = try JSONEncoder.default.encode(data)
        case let .pullModel(data):
            request.httpBody = try JSONEncoder.default.encode(data)
        case let .deleteModel(data):
            request.httpBody = try JSONEncoder.default.encode(data)
        default:
            break
        }

        return request
    }
}
