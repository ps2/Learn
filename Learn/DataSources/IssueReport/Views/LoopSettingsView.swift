//
//  LoopSettingsView.swift
//  Learn
//
//  Created by Pete Schwamb on 10/27/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopIssueReportParser
import LoopKit

struct LoopSettingsView: View {
    var settings: LoopSettings

    var body: some View {
        List {
            LabeledContent("Dosing Enabled", value: String(describing: settings.dosingEnabled))
            GlucoseRangeScheduleView(name: "Target", schedule: settings.glucoseTargetRangeSchedule!)
            DailyQuantityScheduleView(name: "Sensitivity", schedule: settings.insulinSensitivitySchedule!)
            DailyValueScheduleView(name: "Basal", schedule: settings.basalRateSchedule!)
            DailyQuantityScheduleView(name: "Carb Ratio", schedule: settings.carbRatioSchedule!)
            LabeledContent("Pre-Meal Target", value: String(describing: settings.preMealTargetRange))
            LabeledContent("Workout Target", value: String(describing: settings.legacyWorkoutTargetRange))
            LabeledContent("Temp Preset", value: String(describing: settings.scheduleOverride))
            LabeledContent("Pre-Meal Override", value: String(describing: settings.preMealOverride))
            LabeledContent("Max Basal", value: String(describing: settings.maximumBasalRatePerHour))
            LabeledContent("Max Bolus", value: String(describing: settings.maximumBolus))
            LabeledContent("Suspend Threshold", value: String(describing: settings.suspendThreshold))
            LabeledContent("Dosing Strategy", value: String(describing: settings.automaticDosingStrategy))
            LabeledContent("Rapid Acting Insulin Model", value: String(describing: settings.defaultRapidActingModel))
        }
        .navigationTitle("Build Details")
    }
}

struct LoopSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LoopSettingsView(settings: IssueReport.mock.loopSettings)
    }
}
