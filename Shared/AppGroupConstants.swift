import Foundation

/// AppGroupConstants 定义主 App 与 Network Extension 共享的常量标识符。
public enum AppGroupConstants {
    /// App Group 共享容器标识符，用于在主 App 与 Extension 之间共享配置文件与本地缓存。
    public static let appGroupID = "group.org.panto.ios"

    /// Keychain 共享访问组，用于无缝安全共享 VPN 密钥与凭据。
    public static let keychainAccessGroup = "org.panto.ios.shared"

    /// Network Extension 的 Bundle Identifier。
    public static let extensionBundleID = "org.panto.ios.PantoTunnel"

    /// StoreKit 2 一次性永久买断产品 ID。
    public static let lifetimeProProductID = "org.panto.ios.lifetime_pro"

    /// 隧道默认配置名称。
    public static let defaultTunnelName = "Panto Tunnel"

    /// 获取共享容器或本地沙盒的配置存储路径
    public static var sharedConfigURL: URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return container.appendingPathComponent("config.yaml")
        }
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls.first?.appendingPathComponent("config.yaml")
    }

    /// 检查是否存在有效的活动配置文件
    public static var hasActiveConfig: Bool {
        guard let url = sharedConfigURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// 读取当前活动配置文件内容
    public static func loadConfig() -> String? {
        guard let url = sharedConfigURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// 写入配置内容到共享沙盒
    public static func saveConfig(_ content: String) throws {
        guard let url = sharedConfigURL else {
            throw NSError(domain: "org.panto.ios", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法访问应用沙盒存储路径"])
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
