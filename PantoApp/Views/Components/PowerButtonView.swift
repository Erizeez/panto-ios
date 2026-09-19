import SwiftUI
import NetworkExtension

public struct PowerButtonView: View {
    public let status: NEVPNStatus
    public let action: () -> Void

    @State private var isAnimating = false

    public init(status: NEVPNStatus, action: @escaping () -> Void) {
        self.status = status
        self.action = action
    }

    public var body: some View {
        Button(action: {
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
            action()
        }) {
            ZStack {
                // 外层呼吸发光环
                Circle()
                    .stroke(
                        statusGradient.opacity(isConnected ? 0.35 : 0.1),
                        lineWidth: 12
                    )
                    .frame(width: 144, height: 144)
                    .scaleEffect(isAnimating && isConnected ? 1.08 : 1.0)
                    .opacity(isAnimating && isConnected ? 0.8 : 0.4)

                // 中层半透明背景
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 120, height: 120)

                // 核心主圆按钮
                Circle()
                    .fill(statusGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: statusColor.opacity(0.45), radius: isConnected ? 16 : 6, x: 0, y: 8)

                // 中心电源图标
                Image(systemName: "power")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(isConnecting ? .degrees(isAnimating ? 360 : 0) : .zero)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private var isConnected: Bool {
        status == .connected
    }

    private var isConnecting: Bool {
        status == .connecting || status == .reasserting
    }

    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        case .disconnecting: return .red
        default: return .secondary
        }
    }

    private var statusGradient: LinearGradient {
        switch status {
        case .connected:
            return LinearGradient(
                colors: [Color(red: 0.15, green: 0.85, blue: 0.5), Color(red: 0.05, green: 0.65, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .connecting, .reasserting:
            return LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .disconnecting:
            return LinearGradient(
                colors: [Color.red, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.gray.opacity(0.7), Color.gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
