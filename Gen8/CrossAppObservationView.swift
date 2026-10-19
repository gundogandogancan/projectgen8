//
//  CrossAppObservationView.swift — user-initiated cross-app observation control (PROMPT 007D)
//  Wraps the OFFICIAL RPSystemBroadcastPickerView. Capture ONLY starts when the user explicitly taps "Start Broadcast"
//  in Apple's system sheet (red recording indicator). No private API, no hidden capture, no recording without consent.
//
import SwiftUI
#if os(iOS)
import ReplayKit

struct BroadcastPicker: UIViewRepresentable {
    let preferredExtension: String
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        v.preferredExtension = preferredExtension   // our Broadcast Upload Extension
        v.showsMicrophoneButton = false             // file/screen analysis only; no mic by default
        return v
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

struct CrossAppObservationView: View {
    // The broadcast extension bundle id (PROPOSED dev id; see signing docs).
    private let ext = "com.gen8.guardian.dev.GuardianBroadcast"

    var body: some View {
        VStack(alignment: .leading, spacing: GTokens.s3) {
            Text("Cross-app observation").font(.subheadline.weight(.semibold))
            Text("Gen8 can observe what’s on screen in other apps only while you explicitly run an Apple system broadcast. Content is analyzed on-device and ephemerally — no frames are saved or uploaded.")
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: GTokens.s3) {
                BroadcastPicker(preferredExtension: ext)
                    .frame(width: 60, height: 60)
                Text("Tap to start / stop the system broadcast").font(.caption).foregroundStyle(.secondary)
            }
            Text("Official iOS path: ReplayKit system broadcast → Broadcast Upload Extension. ScreenCaptureKit is not available for cross-app capture on iOS.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(GTokens.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GTokens.radius))
        .padding(.horizontal, GTokens.s4)
    }
}
#endif
