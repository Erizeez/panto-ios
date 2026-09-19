import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()

    private let userDefaultsKey = "panto_app_selected_language"
    private var activeBundle: Bundle = .main

    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
            updateBundle()
        }
    }

    public init() {
        let saved = UserDefaults.standard.string(forKey: userDefaultsKey) ?? AppLanguage.system.rawValue
        let lang = AppLanguage(rawValue: saved) ?? .system
        self.currentLanguage = lang
        updateBundle()
    }

    private func updateBundle() {
        let selectedBundle: Bundle
        switch currentLanguage {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            let code = preferred.hasPrefix("en") ? "en" : "zh-Hans"
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let b = Bundle(path: path) {
                selectedBundle = b
            } else {
                selectedBundle = .main
            }
        case .zhHans:
            if let path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
               let b = Bundle(path: path) {
                selectedBundle = b
            } else {
                selectedBundle = .main
            }
        case .en:
            if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let b = Bundle(path: path) {
                selectedBundle = b
            } else {
                selectedBundle = .main
            }
        }
        self.activeBundle = selectedBundle
    }

    public func localized(_ key: String) -> String {
        activeBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    public func localized(_ key: String, _ arguments: [CVarArg]) -> String {
        let format = localized(key)
        return String(format: format, arguments: arguments)
    }

    public var locale: Locale {
        switch currentLanguage {
        case .system:
            return Locale.autoupdatingCurrent
        case .zhHans:
            return Locale(identifier: "zh_CN")
        case .en:
            return Locale(identifier: "en_US")
        }
    }
}

extension String {
    /// 获取当前语言环境下的本地化文本 (线程安全)
    public var localized: String {
        LanguageManager.shared.localized(self)
    }

    public func localizedFormat(_ arguments: CVarArg...) -> String {
        LanguageManager.shared.localized(self, arguments)
    }
}
