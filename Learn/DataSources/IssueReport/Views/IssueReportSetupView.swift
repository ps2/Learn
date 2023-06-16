//
//  IssueReportSetupView.swift
//  Learn
//
//  Created by Pete Schwamb on 4/3/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct IssueReportSetupView: View {
    @Environment(\.dismiss) var dismiss

    @State var isFilePickerShown = false

    @State private var importURL: URL?

    @State private var nickname: String = ""

    private var didFinishSetup: (URL, String) -> Void

    init(didFinishSetup: @escaping (URL, String) -> Void) {
        self.didFinishSetup = didFinishSetup
    }

    var body: some View {
        VStack {
            Text("Loop Issue Report", comment: "Title on IssueReportSetupView")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding(.top, 25)
            Image(decorative: "loop")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)

            Spacer()

            HStack {
                Button(action: {
                    isFilePickerShown.toggle()
                }) {
                    Image(systemName: "rectangle.and.paperclip").resizable().frame(width: 50, height: 50)
                }
                if let importURL {
                    Text(importURL.lastPathComponent)
                } else if isFilePickerShown {
                    ProgressView()
                } else {
                    Text("Please select an issue report to import...")
                }
            }
            TextField("Nickname", text: $nickname)
                .frame(width: 300)
                .padding()
            Spacer()
            HStack {
                Spacer()
                Button("Import") {
                    if let importURL {
                        didFinishSetup(importURL, nickname)
                        dismiss()
                    }
                }
                .disabled(importURL == nil)
                .buttonStyle(.borderedProminent)
                .padding()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
        .presentationDetents([.medium   ])
        .fileImporter(
            isPresented: $isFilePickerShown,
            allowedContentTypes: [UTType(filenameExtension: "md", conformingTo: .text)!],
            allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    importURL = urls.first
                case .failure(let error):
                    print(error.localizedDescription)
                    importURL = nil
                }
            }
    }
}

