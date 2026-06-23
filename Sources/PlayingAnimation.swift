import SwiftUI

struct PlayingAnimation: View {
    @State private var phase = 0
    @State private var timer: Timer?

    private let heights: [[CGFloat]] = [
        [6, 10, 8],
        [10, 6, 10],
        [8, 10, 6]
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(DS.Colors.success)
                    .frame(width: 2, height: heights[phase][i])
            }
        }
        .frame(width: 10, height: 14)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % heights.count
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
