import SwiftUI

public struct ProUpgradeView: View {
    @EnvironmentObject private var proStore: ProStore
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .padding(.top, 40)

                Text("解锁 Panto Pro 终身版")
                    .font(.title)
                    .fontWeight(.bold)

                Text("一次性购买，永久拥有。支持家庭共享，免去循环订阅烦恼。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    featureBenefit(icon: "square.stack.3d.up.fill", title: "多层 Underlay Chain 嵌套", desc: "任意编排 Tailscale over IKEv2 等复杂多层拓扑")
                    featureBenefit(icon: "cpu.fill", title: "自适应高级调度管道", desc: "毫秒级自适应 Filter 与 Score 路由优选")
                    featureBenefit(icon: "icloud.fill", title: "iCloud 跨设备加密漫游", desc: "配置文件在多台 iOS / Mac 设备间安全漫游")
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            let ok = await proStore.purchaseLifetimePro()
                            if ok { dismiss() }
                        }
                    }) {
                        HStack {
                            if proStore.isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(proStore.lifetimeProduct != nil ? "立即买断 · \(proStore.lifetimeProduct!.displayPrice)" : "立即买断 Pro")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button("恢复已购买项目") {
                        Task {
                            await proStore.restorePurchases()
                            if proStore.isProUnlocked { dismiss() }
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func featureBenefit(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
