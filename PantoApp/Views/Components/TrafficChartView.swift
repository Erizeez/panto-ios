import SwiftUI
import PantoShared

/// 上下行速率监控组件 (Throughput Monitor)
/// - 格子规格：标准正方形 (固定 4.0 像素/点，等宽高)
/// - 横轴：时间轴，最右侧为当前实时采样，向左回溯历史
/// - 纵轴：中心为 0 速率中线，向上为上行 (Upload)，向下为下行 (Download)
/// - 色阶：越靠近中心基线为冷色 (冰海蓝/极光青)，越靠近上下外缘为暖色 (明黄/橙红/炽红，代表高负载)
public struct TrafficChartView: View {
    public let history: [TrafficPoint]
    public let upRate: Int64
    public let downRate: Int64

    /// 固定标准正方形像素尺寸 (4.0 pt)
    private let pixelSize: CGFloat = 4.0
    /// 像素间距 (1.8 pt)
    private let pixelGap: CGFloat = 1.8
    /// 上下各 10 级正方形点阵行数
    private let rowsPerSide: Int = 10
    /// 中心基线间距 (5.0 pt)
    private let centerGap: CGFloat = 5.0

    public init(history: [TrafficPoint], upRate: Int64, downRate: Int64) {
        self.history = history
        self.upRate = upRate
        self.downRate = downRate
    }

    // 轴向 10 级阶梯色彩配置 (越靠近中心基线为冷色，越靠近上下外缘为暖色)
    private static let levelColors: [Color] = [
        Color(red: 0.00, green: 0.70, blue: 0.98), // Level 0 (紧贴中心基线): 冰海深蓝 (最冷基底)
        Color(red: 0.00, green: 0.82, blue: 0.92), // Level 1: 极光青蓝 (冷)
        Color(red: 0.00, green: 0.86, blue: 0.78), // Level 2: 碧水青 (微冷)
        Color(red: 0.08, green: 0.88, blue: 0.55), // Level 3: 薄荷翠绿 (冷转温)
        Color(red: 0.40, green: 0.88, blue: 0.20), // Level 4: 亮草绿
        Color(red: 0.75, green: 0.88, blue: 0.10), // Level 5: 青柠黄
        Color(red: 0.96, green: 0.82, blue: 0.08), // Level 6: 荧光金黄 (中等偏高)
        Color(red: 1.00, green: 0.60, blue: 0.04), // Level 7: 琥珀金橙 (高负载)
        Color(red: 1.00, green: 0.36, blue: 0.02), // Level 8: 炽焰橙红 (重度负载)
        Color(red: 1.00, green: 0.12, blue: 0.30)  // Level 9 (最外缘外延): 极速炽红 (满载爆表)
    ]

    // 每一级点亮所需的感知对数速率阈值 (KB/s)
    private static let rateThresholds: [Double] = [
        1.5,        // Level 0 (1 格点亮，微弱心跳)
        12.0,       // Level 1 (2 格)
        45.0,       // Level 2 (3 格)
        150.0,      // Level 3 (4 格)
        500.0,      // Level 4 (5 格, ~500 KB/s)
        1_500.0,    // Level 5 (6 格, ~1.5 MB/s)
        4_500.0,    // Level 6 (7 格, ~4.5 MB/s)
        12_000.0,   // Level 7 (8 格, ~12 MB/s)
        30_000.0,   // Level 8 (9 格, ~30 MB/s)
        70_000.0    // Level 9 (10 格, 70+ MB/s 满载爆表)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. 顶部 Header 与实时速率指示 (去除解释性噪声，统一专业命名)
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Self.levelColors[0])

                    Text("上下行速率".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()

                // 上下行实时速率数值
                HStack(spacing: 6) {
                    rateBadge(icon: "arrow.up", text: formatRate(upRate), accentColor: Self.levelColors[8])
                    rateBadge(icon: "arrow.down", text: formatRate(downRate), accentColor: Self.levelColors[1])
                }
            }

            // 2. 核心正方形像素点阵图谱 (Canvas 极速绘制)
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                // 计算横向列数：每列固定占用 pixelSize + pixelGap
                let totalColStride = pixelSize + pixelGap
                let columns = max(10, Int((width + pixelGap) / totalColStride))

                Canvas { context, size in
                    let centerY = size.height / 2.0

                    // (1) 绘制中心零基准线
                    let baselinePath = Path { p in
                        p.move(to: CGPoint(x: 0, y: centerY))
                        p.addLine(to: CGPoint(x: size.width, y: centerY))
                    }
                    context.stroke(
                        baselinePath,
                        with: .color(Color.primary.opacity(0.12)),
                        style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                    )

                    // (2) 从右向左绘制每一列 (最右侧列为当前最新)
                    for col in 0..<columns {
                        let reverseColIndex = (columns - 1) - col
                        let colX = size.width - CGFloat(reverseColIndex + 1) * totalColStride + pixelGap

                        let dataIndex = history.count - 1 - reverseColIndex
                        let point: TrafficPoint? = (dataIndex >= 0 && dataIndex < history.count) ? history[dataIndex] : nil

                        let upLevels = point != nil ? levelCount(for: point!.upRate) : 0
                        let downLevels = point != nil ? levelCount(for: point!.downRate) : 0

                        // A. 上半部绘制：上行 (Upload)，从中心基线向上延伸
                        for row in 0..<rowsPerSide {
                            let level = row
                            let isLit = level < upLevels
                            let cellY = (centerY - centerGap / 2.0) - CGFloat(row + 1) * pixelSize - CGFloat(row) * pixelGap

                            let rect = CGRect(x: colX, y: cellY, width: pixelSize, height: pixelSize)
                            let squarePath = Path(roundedRect: rect, cornerRadius: 0.5)

                            if isLit {
                                let cellColor = Self.levelColors[min(level, Self.levelColors.count - 1)]
                                context.fill(squarePath, with: .color(cellColor))
                            } else {
                                context.fill(squarePath, with: .color(Color.primary.opacity(0.045)))
                            }
                        }

                        // B. 下半部绘制：下行 (Download)，从中心基线向下延伸
                        for row in 0..<rowsPerSide {
                            let level = row
                            let isLit = level < downLevels
                            let cellY = (centerY + centerGap / 2.0) + CGFloat(row) * (pixelSize + pixelGap)

                            let rect = CGRect(x: colX, y: cellY, width: pixelSize, height: pixelSize)
                            let squarePath = Path(roundedRect: rect, cornerRadius: 0.5)

                            if isLit {
                                let cellColor = Self.levelColors[min(level, Self.levelColors.count - 1)]
                                context.fill(squarePath, with: .color(cellColor))
                            } else {
                                context.fill(squarePath, with: .color(Color.primary.opacity(0.045)))
                            }
                        }
                    }
                }
            }
            .frame(height: CGFloat(rowsPerSide * 2) * pixelSize + CGFloat(rowsPerSide - 1) * 2 * pixelGap + centerGap)

            // 3. 底部极简时间与轴向标尺 (去除冗余自我解释，保持克制)
            HStack {
                Text("-60s")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))

                Spacer()

                Text("实时".localized)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.top, 1)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func levelCount(for rateKB: Double) -> Int {
        if rateKB <= 0.8 { return 0 }
        for (idx, threshold) in Self.rateThresholds.enumerated().reversed() {
            if rateKB >= threshold {
                return idx + 1
            }
        }
        return 1
    }

    private func rateBadge(icon: String, text: String, accentColor: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(accentColor)

            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
        .fixedSize()
    }

    private func formatRate(_ bps: Int64) -> String {
        let kb = Double(bps) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB/s", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.2f MB/s", mb)
    }
}
