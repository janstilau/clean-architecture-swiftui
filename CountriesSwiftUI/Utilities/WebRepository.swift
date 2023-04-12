//
//  WebRepository.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 23.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import Foundation
import Combine

protocol WebRepository {
    var session: URLSession { get }
    var baseURL: String { get }
    var bgQueue: DispatchQueue { get }
}

extension WebRepository {
    func call<Value>(endpoint: APICall, httpCodes: HTTPCodes = .success) -> AnyPublisher<Value, Error>
        where Value: Decodable {
        do {
            let request = try endpoint.urlRequest(baseURL: baseURL)
            return session
                .dataTaskPublisher(for: request)
                .requestJSON(httpCodes: httpCodes)
        } catch let error {
            return Fail<Value, Error>(error: error).eraseToAnyPublisher()
        }
    }
}

// MARK: - Helpers

// typealias URLSession.DataTaskPublisher.Output = (data: Data, response: URLResponse)
// 相比较于, 自定定义 Operator.
// 给 Publisher 添加方法, 利用已有的 Operator 来构建出更加符合业务场景的 Operator, 是更加合理的做法. 
extension Publisher where Output == URLSession.DataTaskPublisher.Output {
    func requestData(httpCodes: HTTPCodes = .success) -> AnyPublisher<Data, Error> {
        return tryMap {
                assert(!Thread.isMainThread)
                guard let code = ($0.1 as? HTTPURLResponse)?.statusCode else {
                    throw APIError.unexpectedResponse
                }
                guard httpCodes.contains(code) else {
                    throw APIError.httpCode(code)
                }
                return $0.0
            }
            .extractUnderlyingError()
            .eraseToAnyPublisher()
    }
}

// 
private extension Publisher where Output == URLSession.DataTaskPublisher.Output {
    func requestJSON<Value>(httpCodes: HTTPCodes) -> AnyPublisher<Value, Error> where Value: Decodable {
        return requestData(httpCodes: httpCodes)
            .decode(type: Value.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
