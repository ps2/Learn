//
//  NightscoutConfigurationChecker.swift
//  Learn
//
//  Created by Pete Schwamb on 2/23/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import NightscoutKit

struct NightscoutConfigurationChecker: NightscoutSetupViewConfigurationChecker {
    func checkConfiguration(urlString: String, apiSecret: String?, completion: @escaping (NightscoutConfigurationError?) -> Void) {
        if let url = URL(string: urlString) {
            let client = NightscoutClient(siteURL: url, apiSecret: apiSecret)
            if apiSecret != nil && !apiSecret!.isEmpty {
                client.checkAuth { error in
                    if let error {
                        if case .unauthorized = error {
                            completion(.invalidCredentials)
                        } else {
                            completion(.networkIssue(error))
                        }
                    } else {
                        completion(nil)
                    }
                }
            } else {
                // If api secret missing, check if we can access glucose without auth
                client.fetchGlucose(dateInterval: DateInterval(start: Date().addingTimeInterval(-60 * 60), end: Date())) { result in
                    switch result {
                    case .failure(let error):
                        switch error {
                        case .unauthorized:
                            completion(.needsAuthentication)
                        default:
                            completion(.networkIssue(error))
                        }
                    case.success:
                        completion(nil)
                    }
                }
            }
        } else {
            completion(.urlInvalid)
        }
    }
}
