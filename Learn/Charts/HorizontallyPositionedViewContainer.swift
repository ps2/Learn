//
//  HorizontallyPositionedViewContainer.swift
//  Learn
//
//  Created by Pete Schwamb on 1/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

/* Positions a subview at specified location horizontally, constrained to the container's bounds */

struct HorizontallyPositionedViewContainer: Layout {

    private var centeredAt: CGFloat

    init(centeredAt: CGFloat) {
        self.centeredAt = centeredAt
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        assert(subviews.count == 1)
        let subviewSize = subviews[0].sizeThatFits(proposal)
        return CGSize(width: proposal.width ?? subviewSize.width, height: subviewSize.height)
    }

    // bounds = bounds of this container in parent view coordinate system
    // proposal = the proposal this container used to generate the bounds
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let containerWidth = proposal.width ?? .zero
        let subviewSize = subviews[0].sizeThatFits(proposal)
        let offset = max(0, min(centeredAt - subviewSize.width/2, containerWidth - subviewSize.width))
        let newOrigin = CGPoint(x: bounds.origin.x + offset, y: bounds.origin.y)
        subviews[0].place(at: newOrigin, proposal: proposal)
    }
}
