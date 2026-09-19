import SwiftUI

public struct LatencyBadge: View {
    public let latencyMs: Int?

    public init(_ latencyMs: Int?) {
        self.latencyMs = latencyMs
    }

    public var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 6, height: 6)

            if let ms = latencyMs, ms > 0 {
                Text("\(ms) ms")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(indicatorColor)
            } else {
                Text("测速")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(indicatorColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var indicatorColor: Color {
        guard let ms = latencyMs, ms > 0 else { return .secondary }
        if ms < 60 {
            return .green
        } else if ms < 180 {
            return .orange
        } else {
            return .red
        }
    }
}
