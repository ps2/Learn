//
//  DocumentPicker.swift
//  Learn
//
//  Created by Pete Schwamb on 4/3/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {

    @Binding var fileContent: URL?

    func makeCoordinator() -> DocumentPickerCoordinator {
        return DocumentPickerCoordinator(fileContent: $fileContent)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIDocumentPickerViewController {
        let controller: UIDocumentPickerViewController
        let markdownUTType = UTType(filenameExtension: "md", conformingTo: .text)!
        controller = UIDocumentPickerViewController(forOpeningContentTypes: [markdownUTType], asCopy: true)

        if #available(iOS 11.0, *) {
            controller.allowsMultipleSelection = false
        }
        controller.delegate = context.coordinator
        return controller
    }


    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<DocumentPicker>) {
    }
}


class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {

    @Binding var fileContent: URL?

    init(fileContent: Binding<URL?>) {
        _fileContent = fileContent
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Canceled")
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let fileURL = urls.first {
            print("url: \(fileURL)")
            fileContent = fileURL
        } else {
            print("error, no file picked")
        }

    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        print("here")
    }

}
