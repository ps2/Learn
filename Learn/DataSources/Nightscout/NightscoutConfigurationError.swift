//
//  NightscoutConfigurationError.swift
//  Learn
//
//  Created by Pete Schwamb on 2/23/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

enum NightscoutConfigurationError: Error {
    case urlInvalid
    case networkIssue(Error)
    case needsAuthentication
    case invalidCredentials
    case unexpectedResponse
}

extension NightscoutConfigurationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .urlInvalid:
            return NSLocalizedString("URL Invalid", comment: "error description for NightscoutConfigurationError.urlInvalid")
        case .networkIssue(let error):
            return error.localizedDescription
        case .needsAuthentication:
            return NSLocalizedString("Site requires authentication", comment: "error description for NightscoutConfigurationError.needsAuthentication")
        case .invalidCredentials:
            return NSLocalizedString("Invalid API Secret", comment: "error description for NightscoutConfigurationError.invalidCredentials")
        case .unexpectedResponse:
            return NSLocalizedString("Unexpected response", comment: "error description for NightscoutConfigurationError.unexpectedResponse")
        }
    }
}
