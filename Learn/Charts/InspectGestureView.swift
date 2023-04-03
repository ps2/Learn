//
//  InspectGestureView.swift
//  Learn
//
//  Created by Pete Schwamb on 2/24/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

extension UIGestureRecognizer.State {
    var name: String {
        switch self {
        case .possible:
            return "possible"
        case .began:
            return "began"
        case .changed:
            return "changed"
        case .ended:
            return "ended"
        case .cancelled:
            return "cancelled"
        case .failed:
            return "failed"
        @unknown default:
            return "@unknown"
        }
    }
}

class InspectionGestureRecognizer: UIGestureRecognizer {
    var timer: Timer?
    var startPosition: CGPoint?

    var onChange: ((CGPoint) -> Void)?
    var onEnded: (() -> Void)?
    private let minimumDuration: TimeInterval

    public init(target: Any?, action: Selector?, minimumDuration: TimeInterval = 0.2) {
        self.minimumDuration = minimumDuration
        super.init(target: target, action: action)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let firstTouch = touches.first {
            startPosition = firstTouch.location(in: view)
            timer = Timer.scheduledTimer(withTimeInterval: minimumDuration, repeats: false) { timer in
                self.state = .began
                if let startPosition = self.startPosition {
                    self.onChange?(startPosition)
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        timer?.invalidate()
        timer = nil
        state = .ended
        onEnded?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let firstTouch = touches.first {
            switch state {
            case .possible:
                startPosition = firstTouch.location(in: view)
            case .changed, .began:
                onChange?(firstTouch.location(in: view))
            default:
                break
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        state = .possible
        timer?.invalidate()
        timer = nil
        state = .cancelled
    }

    override func reset() {
        super.reset()
        timer?.invalidate()
        timer = nil
    }
}

struct InspectGestureView: UIViewRepresentable {

    let minimumDuration: TimeInterval
    let onChange: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        addGestureRecognizer(view: view)
        return view
    }

    private func addGestureRecognizer(view: UIView) {
        let gesture = InspectionGestureRecognizer(target: nil, action: nil, minimumDuration: minimumDuration)
        gesture.onChange = onChange
        gesture.onEnded = onEnded
        view.addGestureRecognizer(gesture)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let recognizers = uiView.gestureRecognizers {
            for recognizer in recognizers {
                if let inspectionRecognizer = recognizer as? InspectionGestureRecognizer {
                    inspectionRecognizer.onChange = onChange
                    inspectionRecognizer.onEnded = onEnded
                }
            }
        }
    }
}
