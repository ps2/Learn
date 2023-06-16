//
//  BuildDetailsView.swift
//  Learn
//
//  Created by Pete Schwamb on 6/15/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopIssueReportParser

struct BuildDetailsView: View {
    var buildDetails: BuildDetails

    var body: some View {
        List {
            LabeledContent("Version", value: buildDetails.appNameAndVersion)
            LabeledContent("Profile Expiration", value: buildDetails.profileExpiration)
            LabeledContent("Git Revision", value: buildDetails.gitRevision)
            LabeledContent("Git Branch", value: buildDetails.gitBranch)
            LabeledContent("Workspace Revision", value: buildDetails.workspaceGitRevision)
            LabeledContent("Workspace Branch", value: buildDetails.workspaceGitBranch)
            LabeledContent("Source Root", value: buildDetails.sourceRoot)
            LabeledContent("Build Date", value: buildDetails.buildDateString)
            LabeledContent("Xcode Version", value: buildDetails.xcodeVersion)
        }
        .navigationTitle("Build Details")
    }
}

struct BuildDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BuildDetailsView(buildDetails: BuildDetails.mock)
        }
    }
}
