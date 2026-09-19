import SwiftUI
import PantoShared
#if canImport(UIKit)
import UIKit
#endif

struct MatrixColumn: Identifiable, Sendable {
    let id: Int
    let sites: [ProbeSite]
}

public struct ProbeView: View {
    @ObservedObject var appState: AppState

    @State private var selectedSiteId: String? = nil
    @State private var selectedCategory: String = "全部"

    // 微型 1:1 正方形网格参数 (GitHub 贡献热力图标准尺寸)
    private let squareSize: CGFloat = 11
    private let squareSpacing: CGFloat = 2.5
    private let matrixRows: Int = 3

    // 触控板平移与边缘自滚状态
    @State private var trackpadScrollOffset: CGFloat = 0
    @State private var isTouchingTrackpad: Bool = false
    @State private var lastTouchLocation: CGPoint = .zero
    @State private var edgeScrollTask: Task<Void, Never>? = nil

    public init(appState: AppState) {
        self.appState = appState
    }

    private var totalColumns: Int {
        max(1, Int(ceil(Double(appState.probeSites.count) / Double(matrixRows))))
    }

    private var totalGridWidth: CGFloat {
        CGFloat(totalColumns) * squareSize + CGFloat(max(0, totalColumns - 1)) * squareSpacing
    }

    private var trackpadContainerHeight: CGFloat {
        CGFloat(matrixRows) * squareSize + CGFloat(max(0, matrixRows - 1)) * squareSpacing + 12
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    // 快捷分类筛选胶囊栏
                    categoryFilterBar
                        .padding(.top, 8)

                    // 详细站点状态瀑布流列表
                    detailedSitesList
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // 【常驻顶部控制台】：标题 + 紧凑测速按钮 + 微型 1:1 热力图触控板 (Trackpad)
                pinnedMatrixHeader(proxy: proxy)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                Task {
                    if appState.probeSites.isEmpty {
                        appState.probeSites = (try? await appState.client.getProbeSites()) ?? []
                    }
                    if selectedSiteId == nil {
                        selectedSiteId = appState.probeSites.first?.id
                    }
                    if appState.probeResults.isEmpty {
                        await appState.runProbeStream()
                    }
                }
            }
        }
    }

    // MARK: - 1. 常驻顶部控制台 (Pinned Sticky Header)

    private func pinnedMatrixHeader(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 8) {
            // 第一行：标题 + 实时状态统计微型胶囊 + 压缩在右侧的「重新测速」按钮 (完全静态无抖动)
            HStack(alignment: .center, spacing: 8) {
                Text("连通性探测".localized)
                    .font(.headline)
                    .fontWeight(.bold)

                // 状态统计微型图例 (仅保留成功与异常数量，避免动态文本导致布局抖动)
                HStack(spacing: 5) {
                    statusDot(color: Color(red: 0.15, green: 0.78, blue: 0.42), count: successCount)
                    if failureCount > 0 {
                        Button(action: {
                            scrollToFirstFailure(proxy: proxy)
                        }) {
                            statusDot(color: Color(red: 0.95, green: 0.28, blue: 0.28), count: failureCount)
                        }
                        .buttonStyle(.plain)
                    }
                    if inProgressCount > 0 {
                        statusDot(color: Color(red: 0.98, green: 0.75, blue: 0.15), count: inProgressCount)
                    }
                }

                Spacer()

                // 重新测速按钮：与标题同在一行，极度压缩纵向空间
                Button(action: {
                    Task {
                        await appState.runProbeStream()
                    }
                }) {
                    HStack(spacing: 5) {
                        if appState.isProbing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.65)
                            Text("\(appState.probeResults.count)/\(appState.probeSites.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("重新测速".localized)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(appState.isProbing ? Color.orange : Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: (appState.isProbing ? Color.orange : Color.accentColor).opacity(0.25), radius: 3, y: 1)
                }
                .disabled(appState.isProbing)
            }
            .padding(.horizontal)
            .padding(.top, 6)

            // 第二行：微型 1:1 热力图触控板 (仿触控板实时滑移、框选聚焦与边缘自滚)
            trackpadMatrix(proxy: proxy)
        }
        .padding(.bottom, 8)
        .background(Color(uiColor: .systemBackground))
        .overlay(
            Divider()
                .opacity(0.4),
            alignment: .bottom
        )
    }

    private func statusDot(color: Color, count: Int) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - 2. 微型 1:1 热力图触控板核心实现 (Trackpad Scrubber)

    private func trackpadMatrix(proxy: ScrollViewProxy) -> some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            let hPadding: CGFloat = 8
            let isOverflow = totalGridWidth + hPadding * 2 > containerWidth
            let maxOffset = max(0, totalGridWidth + hPadding * 2 - containerWidth)

            ZStack(alignment: .center) {
                // 触控板底座
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isTouchingTrackpad ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08),
                                lineWidth: isTouchingTrackpad ? 1.5 : 1
                            )
                    )

                // 正方形微型方格矩阵 (SwiftUI 原生 Grid 锁列锁行)
                Grid(horizontalSpacing: squareSpacing, verticalSpacing: squareSpacing) {
                    ForEach(0..<matrixRows, id: \.self) { row in
                        GridRow {
                            ForEach(0..<totalColumns, id: \.self) { col in
                                let index = col * matrixRows + row
                                if index < appState.probeSites.count {
                                    squareTile(site: appState.probeSites[index])
                                } else {
                                    Color.clear
                                        .frame(width: squareSize, height: squareSize)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, hPadding)
                .padding(.vertical, 6)
                .offset(x: isOverflow ? -trackpadScrollOffset : 0)
                .frame(maxWidth: .infinity, alignment: isOverflow ? .leading : .center)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
            // 边缘溢出微型指示箭头
            .overlay(alignment: .leading) {
                if isOverflow && trackpadScrollOffset > 4 {
                    Image(systemName: "chevron.compact.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 3)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .trailing) {
                if isOverflow && trackpadScrollOffset < (maxOffset - 4) {
                    Image(systemName: "chevron.compact.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 3)
                        .allowsHitTesting(false)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        isTouchingTrackpad = true
                        handleTrackpadTouch(at: val.location, in: containerWidth, proxy: proxy)
                    }
                    .onEnded { _ in
                        isTouchingTrackpad = false
                        stopEdgeScroll()
                    }
            )
            .onChange(of: selectedSiteId) { newId in
                if !isTouchingTrackpad, let newId = newId {
                    centerTrackpad(on: newId, in: containerWidth)
                }
            }
        }
        .frame(height: trackpadContainerHeight)
        .padding(.horizontal)
    }

    private func squareTile(site: ProbeSite) -> some View {
        let isSelected = selectedSiteId == site.id
        let isProbing = appState.activeProbingId == site.id
        let result = appState.probeResults.first(where: { $0.id == site.id })
        let tileColor = colorForSquare(isProbing: isProbing, result: result)

        return ZStack {
            // 标准微型 1:1 正方形小方块 (w == h)
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(tileColor)
                .frame(width: squareSize, height: squareSize)

            // 正在测速时的黄色呼吸律动边框
            if isProbing {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .stroke(Color.yellow, lineWidth: 1.2)
                    .frame(width: squareSize, height: squareSize)
                    .scaleEffect(1.2)
            }

            // 触控选中/滑动聚焦时的微放大透镜效果与高对比描边
            if isSelected {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: squareSize, height: squareSize)
                    .scaleEffect(1.3)
                    .shadow(color: Color.black.opacity(0.35), radius: 2)
            }
        }
        .frame(width: squareSize, height: squareSize)
        .scaleEffect(isSelected ? 1.28 : 1.0)
        .zIndex(isSelected ? 10 : 1)
    }

    // MARK: - 3. 触控板坐标判定、动效与边缘自动滑移

    private func site(at point: CGPoint, in containerWidth: CGFloat) -> ProbeSite? {
        guard !appState.probeSites.isEmpty else { return nil }

        let hPadding: CGFloat = 8
        let isOverflow = totalGridWidth + hPadding * 2 > containerWidth

        let relX: CGFloat
        if isOverflow {
            relX = point.x - hPadding + trackpadScrollOffset
        } else {
            let startX = (containerWidth - totalGridWidth) / 2
            relX = point.x - startX
        }
        let relY = point.y - 6

        let col = Int(relX / (squareSize + squareSpacing))
        let row = Int(relY / (squareSize + squareSpacing))

        let clampedCol = max(0, min(totalColumns - 1, col))
        let clampedRow = max(0, min(matrixRows - 1, row))

        let index = clampedCol * matrixRows + clampedRow
        if index < appState.probeSites.count {
            return appState.probeSites[index]
        } else {
            return appState.probeSites.last
        }
    }

    private func handleTrackpadTouch(at point: CGPoint, in containerWidth: CGFloat, proxy: ScrollViewProxy) {
        lastTouchLocation = point

        if let site = site(at: point, in: containerWidth) {
            if selectedSiteId != site.id {
                selectedSiteId = site.id

                #if canImport(UIKit)
                let res = appState.probeResults.first(where: { $0.id == site.id })
                let isFailure = (res?.latencyMs ?? 0) < 0 || res?.error != nil
                if isFailure {
                    // 滑过故障红格节点时，给予明显的触觉震动警告
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                } else {
                    // 普通节点滑动提供极度细腻的齿轮步进手感
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }
                #endif

                // 驱动下方列表以原生物理弹簧动效居中平滑滚动
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    proxy.scrollTo(site.id, anchor: .center)
                }
            }
        }

        // 边缘自动滚动判定
        checkEdgeScroll(at: point, in: containerWidth, proxy: proxy)
    }

    private func checkEdgeScroll(at point: CGPoint, in containerWidth: CGFloat, proxy: ScrollViewProxy) {
        let hPadding: CGFloat = 8
        let totalContent = totalGridWidth + hPadding * 2

        guard totalContent > containerWidth else {
            stopEdgeScroll()
            return
        }

        let maxOffset = totalContent - containerWidth
        let edgeThreshold: CGFloat = 36 // 左右两侧边缘 36pt 磁力感应区

        if point.x > containerWidth - edgeThreshold {
            // 手指移动至右侧边缘：向右自动滑移
            let overflow = point.x - (containerWidth - edgeThreshold)
            let speedRatio = min(1.0, max(0.15, overflow / edgeThreshold))
            startEdgeScroll(direction: 1, speed: 3.2 + speedRatio * 7.0, maxOffset: maxOffset, in: containerWidth, proxy: proxy)
        } else if point.x < edgeThreshold {
            // 手指移动至左侧边缘：向左自动滑移
            let overflow = edgeThreshold - point.x
            let speedRatio = min(1.0, max(0.15, overflow / edgeThreshold))
            startEdgeScroll(direction: -1, speed: 3.2 + speedRatio * 7.0, maxOffset: maxOffset, in: containerWidth, proxy: proxy)
        } else {
            stopEdgeScroll()
        }
    }

    private func startEdgeScroll(direction: CGFloat, speed: CGFloat, maxOffset: CGFloat, in containerWidth: CGFloat, proxy: ScrollViewProxy) {
        guard edgeScrollTask == nil else { return }

        edgeScrollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps 丝滑自滚
                let next = trackpadScrollOffset + direction * speed
                let clamped = min(maxOffset, max(0, next))

                if abs(clamped - trackpadScrollOffset) > 0.05 {
                    trackpadScrollOffset = clamped
                    // 随着触控板自动滚动，重新探测当前手指下方的方块并同步联动底层列表
                    if let site = site(at: lastTouchLocation, in: containerWidth), selectedSiteId != site.id {
                        selectedSiteId = site.id
                        #if canImport(UIKit)
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                        #endif
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            proxy.scrollTo(site.id, anchor: .center)
                        }
                    }
                } else {
                    break
                }
            }
        }
    }

    private func stopEdgeScroll() {
        edgeScrollTask?.cancel()
        edgeScrollTask = nil
    }

    private func centerTrackpad(on siteId: String, in containerWidth: CGFloat) {
        guard let idx = appState.probeSites.firstIndex(where: { $0.id == siteId }) else { return }
        let col = idx / matrixRows
        let hPadding: CGFloat = 8
        let totalContent = totalGridWidth + hPadding * 2
        guard totalContent > containerWidth else { return }

        let targetX = hPadding + CGFloat(col) * (squareSize + squareSpacing) + squareSize / 2
        let idealOffset = targetX - containerWidth / 2
        let maxOffset = totalContent - containerWidth
        let clamped = min(maxOffset, max(0, idealOffset))

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            trackpadScrollOffset = clamped
        }
    }

    private func scrollToFirstFailure(proxy: ScrollViewProxy) {
        if let firstFail = appState.probeSites.first(where: { s in
            if let r = appState.probeResults.first(where: { $0.id == s.id }) {
                return r.latencyMs < 0 || r.error != nil
            }
            return false
        }) {
            selectedSiteId = firstFail.id
            #if canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            #endif
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                proxy.scrollTo(firstFail.id, anchor: .center)
            }
        }
    }

    private func colorForSquare(isProbing: Bool, result: ProbeResultItem?) -> Color {
        if isProbing {
            // 黄色：正在探测中
            return Color(red: 0.98, green: 0.75, blue: 0.15)
        }
        guard let res = result else {
            // 待测：中性浅灰
            return Color.secondary.opacity(0.18)
        }
        if res.latencyMs < 0 || res.error != nil {
            // 红色：失败 / 超时
            return Color(red: 0.95, green: 0.28, blue: 0.28)
        }
        // 全绿：根据延迟梯级呈现绿阶
        return colorForLatency(res.latencyMs)
    }

    private func colorForLatency(_ ms: Int) -> Color {
        if ms < 50 {
            return Color(red: 0.12, green: 0.76, blue: 0.38) // 翡翠深绿
        } else if ms < 120 {
            return Color(red: 0.22, green: 0.85, blue: 0.44) // 亮绿
        } else {
            return Color(red: 0.62, green: 0.85, blue: 0.32) // 草绿
        }
    }

    // MARK: - 2. 分类筛选胶囊栏

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryPill(title: "全部")
                categoryPill(title: "开发平台")
                categoryPill(title: "网络基础设施")
                categoryPill(title: "AI 基础设施")
                categoryPill(title: "国际媒体")
                categoryPill(title: "校园内网")
                categoryPill(title: "国内直连")
            }
        }
    }

    private func categoryPill(title: String) -> some View {
        let isSelected = selectedCategory == title
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = title
            }
        }) {
            Text(title.localized)
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. 下方详细节点卡片瀑布流

    private var detailedSitesList: some View {
        VStack(spacing: 10) {
            ForEach(filteredSites) { site in
                let result = appState.probeResults.first(where: { $0.id == site.id })
                let isSelected = selectedSiteId == site.id
                let isProbing = appState.activeProbingId == site.id

                siteCard(site: site, result: result, isSelected: isSelected, isProbing: isProbing)
                    .id(site.id) // 供 ScrollViewReader 精准定位
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedSiteId = site.id
                        }
                    }
            }
        }
    }

    private func siteCard(site: ProbeSite, result: ProbeResultItem?, isSelected: Bool, isProbing: Bool) -> some View {
        let isError = (result?.latencyMs ?? 0) < 0 || result?.error != nil
        let statusColor: Color = isError ? .red : (result != nil ? colorForLatency(result!.latencyMs) : .secondary)
        let focusColor: Color = isError ? .red : .accentColor

        return HStack(spacing: 12) {
            // 1. 服务图标 (Apple 原生 36x36 纯净圆角容器)
            Image(systemName: site.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? focusColor : .secondary)
                .frame(width: 36, height: 36)
                .background(isSelected ? focusColor.opacity(0.12) : Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // 2. 节点主标题与纯净副标题 (异常时直接显示原因，无冗余装饰)
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(.primary)

                if let err = result?.error, isError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else {
                    Text(site.domain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 3. 极简测速状态与延迟排版 (SF Rounded 数字 + 微型单位)
            HStack(spacing: 3) {
                if isProbing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let res = result {
                    if res.latencyMs > 0 {
                        Text("\(res.latencyMs)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                        Text("ms")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Text(res.status)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            isSelected
                ? focusColor.opacity(0.08)
                : Color(uiColor: .secondarySystemGroupedBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? focusColor : Color.primary.opacity(0.04),
                    lineWidth: isSelected ? 1.5 : 1.0
                )
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isSelected)
    }

    // MARK: - 计算属性

    private var filteredSites: [ProbeSite] {
        if selectedCategory == "全部" {
            return appState.probeSites
        }
        return appState.probeSites.filter { $0.category.contains(selectedCategory) }
    }

    private var successCount: Int {
        appState.probeResults.filter { $0.latencyMs > 0 && $0.error == nil }.count
    }

    private var failureCount: Int {
        appState.probeResults.filter { $0.latencyMs < 0 || $0.error != nil }.count
    }

    private var inProgressCount: Int {
        appState.activeProbingId != nil ? 1 : 0
    }
}
