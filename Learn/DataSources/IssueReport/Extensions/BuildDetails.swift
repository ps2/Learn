//
//  BuildDetails.swift
//  Learn
//
//  Created by Pete Schwamb on 6/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopIssueReportParser

extension BuildDetails {
    static var mock: BuildDetails {
        return BuildDetails(
            appNameAndVersion: "Loop v3.2.2 (57)",
            profileExpiration: "2024-06-14 13:42:48 +0000",
            gitRevision: "b1d9b07",
            gitBranch: "N/A",
            workspaceGitRevision: "f12c93c",
            workspaceGitBranch: "main",
            sourceRoot: "/Users/pete/dev/LoopWorkspace/Loop",
            buildDateString: "Sat Mar 18 18:44:36 CDT 2023",
            xcodeVersion: "14C18")
    }
}
