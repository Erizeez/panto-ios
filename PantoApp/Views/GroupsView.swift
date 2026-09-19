import SwiftUI
import PantoShared

public struct GroupsView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部并发测速与自适应调度横幅
                    schedulerBanner

                    // 策略组列表
                    ForEach(appState.groups) { group in
                        groupCard(group)
                    }
                }
                .padding()
            }
            .navigationTitle("策略调度组")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            for g in appState.groups {
                                await appState.testGroupDelay(groupId: g.id)
                            }
                        }
                    }) {
                        Label("全部测速", systemImage: "bolt.fill")
                    }
                    .disabled(appState.isTestingDelays)
                }
            }
        }
    }

    private var schedulerBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("自适应调度管道".localized)
                    .font(.headline)
                    .fontWeight(.bold)
                Text("遵循 Filter (存活过滤) ➔ Score (延时权重打分) ➔ Pick (优选绑定) 机制".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "slider.horizontal.3")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func groupCard(_ group: GroupItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 分组标题与类型
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.id)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("类型: \(kindDisplayName(group.kind))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // 单组并发测速按钮
                Button(action: {
                    Task {
                        await appState.testGroupDelay(groupId: group.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                            .rotationEffect(.degrees(appState.isTestingDelays ? 360 : 0))
                            .animation(appState.isTestingDelays ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isTestingDelays)
                        Text("测速")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())
                }
            }

            Divider()

            // 成员节点列表
            VStack(spacing: 8) {
                ForEach(group.members, id: \.self) { member in
                    memberRow(member: member, group: group)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func memberRow(member: String, group: GroupItem) -> some View {
        let isSelected = group.current == member
        let delay = group.delays?[member]

        return Button(action: {
            #if canImport(UIKit)
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
            #endif
            Task {
                await appState.selectGroupMember(groupId: group.id, memberId: member)
            }
        }) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
                    .font(.body)

                Text(member)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()

                LatencyBadge(delay)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func kindDisplayName(_ kind: String) -> String {
        switch kind {
        case "select": return "手动选择 (Select)"
        case "url-test": return "延迟自动选优 (URL-Test)"
        case "fallback": return "故障倒换 (Fallback)"
        default: return kind
        }
    }
}
