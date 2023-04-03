//
//  NightscoutSummaryView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/23/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct NightscoutSummaryView: View {

    var name: String

    var body: some View {
        HStack {
            Image(decorative: "nightscout")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 40)
            Text(name)
        }
    }
}

struct NightscoutSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        NightscoutSummaryView(name: "Nightscout")
    }
}
