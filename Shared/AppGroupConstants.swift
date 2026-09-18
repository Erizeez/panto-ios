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
}
