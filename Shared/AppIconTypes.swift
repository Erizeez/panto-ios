import Foundation

/// Panto 支持的 3 套时段轮换图标。
/// 按照用户专属设计与 8 小时轮换时段划分：
/// 1. 早上 8 点到下午 4 点 (08:00 - 16:00): 白昼·元气 (icon_uwu_day.svg)
/// 2. 下午 4 点到晚上 12 点 (16:00 - 24:00): 黄昏·活力 (icon_happy_twilight.svg)
/// 3. 晚上 12 点到早上 8 点 (00:00 - 08:00): 暗夜·酣睡 (icon_sleep_night.svg)
public enum PantoAppIcon: String, CaseIterable, Identifiable, Sendable {
    case day = "AppIcon-Day"
    case twilight = "AppIcon-Twilight"
    case night = "AppIcon-Night"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .day: return NSLocalizedString("白昼·元气", comment: "")
        case .twilight: return NSLocalizedString("黄昏·活力", comment: "")
        case .night: return NSLocalizedString("暗夜·酣睡", comment: "")
        }
    }

    public var timeRangeDescription: String {
        switch self {
        case .day: return "08:00 - 16:00"
        case .twilight: return "16:00 - 24:00"
        case .night: return "00:00 - 08:00"
        }
    }

    public var previewImageName: String {
        switch self {
        case .day: return "IconPreview-Day"
        case .twilight: return "IconPreview-Twilight"
        case .night: return "IconPreview-Night"
        }
    }

    public var sourceSVGName: String {
        switch self {
        case .day: return "icon_uwu_day.svg"
        case .twilight: return "icon_happy_twilight.svg"
        case .night: return "icon_sleep_night.svg"
        }
    }

    /// 根据指定时间计算应当使用的 8 小时轮换时段图标
    /// - 08:00 - 15:59: 白昼 (day)
    /// - 16:00 - 23:59: 黄昏 (twilight)
    /// - 00:00 - 07:59: 暗夜 (night)
    public static func scheduledIcon(for date: Date = Date(), calendar: Calendar = .current) -> PantoAppIcon {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 8..<16:
            return .day
        case 16..<24:
            return .twilight
        default: // 0..<8
            return .night
        }
    }
}
