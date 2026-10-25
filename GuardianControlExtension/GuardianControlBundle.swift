//
//  GuardianControlBundle.swift — @main WidgetBundle for the Gen8 Guardian extension (PROMPT 007A §7,§9,§10)
//  Combines the Control Center control + the Live Activity surface in one widget-extension bundle.
//
import WidgetKit
import SwiftUI

@main
struct GuardianControlBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        GuardianLiveActivityWidget()
        if #available(iOS 18.0, *) {
            GuardianControlWidget()
            GuardianIdleControlWidget()   // §6 — the one-tap ACTIVE/IDLE control
            GuardianLaunchControlWidget() // §A — OpenIntent launcher → app's broadcast-start screen
        }
    }
}
