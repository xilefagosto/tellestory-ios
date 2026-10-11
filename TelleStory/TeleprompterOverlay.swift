import SwiftUI

/// Overlay de lectura: visible solamente durante la captura, NO aparece en el video grabado.
struct TeleprompterOverlay: View {
    let script: String
    let speed: Double
    let fontSize: Double
    @Binding var isPlaying: Bool

    @State private var startedAt: Date?
    @State private var distanceAtPause: Double = 0

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { timeline in
                let distance = currentDistance(at: timeline.date)
                Text(script)
                    .font(.system(size: CGFloat(fontSize), weight: .semibold, design: .rounded))
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.95), radius: 3)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: geometry.size.height * 0.35 - distance)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .background(.black.opacity(0.26))
        .onChange(of: isPlaying) { enabled in
            if enabled {
                startedAt = Date()
            } else {
                distanceAtPause = currentDistance(at: Date())
                startedAt = nil
            }
        }
        .onChange(of: speed) { _ in
            distanceAtPause = currentDistance(at: Date())
            if isPlaying { startedAt = Date() }
        }
        .onChange(of: script) { _ in
            startedAt = isPlaying ? Date() : nil
            distanceAtPause = 0
        }
    }

    private func currentDistance(at date: Date) -> Double {
        guard isPlaying, let startedAt else { return distanceAtPause }
        return distanceAtPause + max(0, date.timeIntervalSince(startedAt)) * speed
    }
}
