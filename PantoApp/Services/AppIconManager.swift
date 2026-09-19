import Foundation
import SwiftUI
import Combine
import UIKit
import PantoShared

@MainActor
public final class AppIconManager: ObservableObject {
    public static let shared = AppIconManager()

    private let autoRotateKey = "panto_auto_rotate_app_icon"
    private var timer: Timer?

    @Published public var autoRotateEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoRotateEnabled, forKey: autoRotateKey)
            if autoRotateEnabled {
                checkAndRotateIconIfNeeded()
            }
        }
    }

    @Published public var currentActiveIcon: PantoAppIcon = .day
    @Published public var currentScheduledIcon: PantoAppIcon = .day
    @Published public var isSupported: Bool = false

    private init() {
        let savedAuto = UserDefaults.standard.object(forKey: autoRotateKey) as? Bool ?? true
        self.autoRotateEnabled = savedAuto

        #if os(iOS)
        self.isSupported = UIApplication.shared.supportsAlternateIcons
        #else
        self.isSupported = false
        #endif

        updateCurrentActiveIconFromSystem()
        self.currentScheduledIcon = PantoAppIcon.scheduledIcon()

        // 监听 App 进入前台通知，唤醒时自动校验当前时段并轮换
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    @objc private func handleAppDidBecomeActive() {
        Task { @MainActor in
            self.currentScheduledIcon = PantoAppIcon.scheduledIcon()
            self.updateCurrentActiveIconFromSystem()
            if self.autoRotateEnabled {
                self.checkAndRotateIconIfNeeded()
            }
        }
    }

    public func startTimer() {
        timer?.invalidate()
        // 每 60 秒轮询一次，跨越 8 小时时间节点时可无缝响应
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentScheduledIcon = PantoAppIcon.scheduledIcon()
                if self.autoRotateEnabled {
                    self.checkAndRotateIconIfNeeded()
                }
            }
        }
    }

    public func updateCurrentActiveIconFromSystem() {
        #if os(iOS)
        let name = UIApplication.shared.alternateIconName
        if let name = name, let icon = PantoAppIcon(rawValue: name) {
            self.currentActiveIcon = icon
        } else {
            // nil 或未设置时对应主图标 (Day)
            self.currentActiveIcon = .day
        }
        #endif
    }

    /// 检查并在需要时轮换图标
    public func checkAndRotateIconIfNeeded() {
        guard autoRotateEnabled else { return }
        let target = PantoAppIcon.scheduledIcon()
        self.currentScheduledIcon = target

        if currentActiveIcon != target {
            applyIcon(target)
        }
    }

    /// 手动选择并应用指定图标（将自动关闭按时段自动轮换，避免被系统定时覆盖）
    public func selectIconManually(_ icon: PantoAppIcon) {
        if self.autoRotateEnabled {
            self.autoRotateEnabled = false
        }
        applyIcon(icon)
    }

    /// 应用指定图标
    public func applyIcon(_ icon: PantoAppIcon) {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else { return }

        // 如果系统当前图标已是目标图标，无需重复调用系统 API
        let currentSystemName = UIApplication.shared.alternateIconName
        let isAlreadyActive: Bool
        if icon == .day {
            isAlreadyActive = (currentSystemName == nil || currentSystemName == PantoAppIcon.day.rawValue)
        } else {
            isAlreadyActive = (currentSystemName == icon.rawValue)
        }

        if isAlreadyActive {
            self.currentActiveIcon = icon
            return
        }

        let targetName: String? = (icon == .day) ? nil : icon.rawValue
        UIApplication.shared.setAlternateIconName(targetName) { [weak self] error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("[AppIconManager] 切换图标失败: \(error.localizedDescription)")
                } else {
                    self?.currentActiveIcon = icon
                }
            }
        }
        #endif
    }
}
