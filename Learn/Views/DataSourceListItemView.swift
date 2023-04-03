//
//  DataSourceView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct DataSourceListItemView: View {
    var dataSource: any DataSource

    var body: some View {
        Text(dataSource.name)
    }
}

struct DataSourceView_Previews: PreviewProvider {
    static var previews: some View {
        DataSourceListItemView(dataSource: MockDataSource())
    }
}
