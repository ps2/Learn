//
//  NightscoutSetupView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/22/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI


protocol NightscoutSetupViewConfigurationChecker {
    func checkConfiguration(urlString: String, apiSecret: String?, completion: @escaping (NightscoutConfigurationError?) -> Void)
}

struct NightscoutSetupView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var keyboardObserver = KeyboardObserver()

    @State private var urlString: String = ""
    @State private var nickname: String = ""
    @State private var apiSecret: String = ""
    @State private var isCheckingConfig: Bool = false
    @State private var showPasswordEntry: Bool = false
    @State private var shortHostname: String?

    enum FocusedField {
        case url, nickname, apiSecret
    }

    @FocusState private var focusedField: FocusedField?

    private var didFinishSetup: (URL, String, String) -> Void

    var didEditNickname: Bool {
        return !nickname.isEmpty && nickname != shortHostname
    }

    @State private var error: Error?

    private var configurationChecker: NightscoutSetupViewConfigurationChecker?

    init(configurationChecker: NightscoutSetupViewConfigurationChecker?, didFinishSetup: @escaping (URL, String, String) -> Void) {
        self.configurationChecker = configurationChecker
        self.didFinishSetup = didFinishSetup
    }

    var body: some View {
        VStack {
            Text("Nightscout", comment: "Title on Nightscout CredentialsView")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Image(decorative: "nightscout")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)

            TextField("Site URL", text: $urlString)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5.0)
                .onChange(of: urlString) { newValue in
                    error = nil
                    if let newHostname = URL(string: newValue)?.host?.components(separatedBy: ".").first, !didEditNickname {
                        shortHostname = newHostname
                        nickname = newHostname
                    }
                }
            TextField("Nickname (optional)", text: $nickname)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5.0)

            if showPasswordEntry {
                VStack {
                    TextField("API Secret", text: $apiSecret)
                        .focused($focusedField, equals: .apiSecret)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(5.0)
                }
            }

            if let error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
            }

            Button {
                isCheckingConfig = true
                configurationChecker?.checkConfiguration(urlString: urlString, apiSecret: apiSecret) { error in
                    DispatchQueue.main.async {
                        isCheckingConfig = false
                        if let error {
                            if case .needsAuthentication = error {
                                showPasswordEntry = true
                                focusedField = .apiSecret
                            }
                            self.error = error
                        } else {
                            dismiss()
                            didFinishSetup(URL(string: urlString)!, nickname, apiSecret)
                        }
                    }
                }

            } label: {
                if isCheckingConfig {
                    ProgressView()
                } else {
                    Text("Add Data Source", comment: "Action button text on NightscoutSetupView")
                }
            }
            .buttonStyle(ActionButtonStyle(.primary))
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            Button(action: { dismiss() } ) {
                Text("Cancel", comment: "Button text to cancel NightscoutSetupView").padding(.top, 20)
            }
        }
        .padding([.leading, .trailing])
        .offset(y: -keyboardObserver.height*0.4)
        .navigationBarHidden(true)
        .navigationBarTitle("")

    }
}


struct NightscoutCredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        NightscoutSetupView(configurationChecker: nil, didFinishSetup: { url, nickname, password in
            print("did finish")
        })
        .environment(\.colorScheme, .dark)
    }
}
