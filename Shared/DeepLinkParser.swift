import Foundation

/// PantoDeepLink 表示从系统 URL Scheme (panto:// 或 clash://) 解析出的强类型操作指令。
public enum PantoDeepLink: Equatable, Sendable {
    /// 引用式远程或局域网配置导入
    case installConfig(downloadURL: URL, name: String?, token: String?)
    /// 内联 Base64 数据导入
    case importData(content: String, name: String?)
}

/// DeepLinkParser 提供跨平台的深度链接 URI 规范解析与参数清洗。
public struct DeepLinkParser: Sendable {
    public static func parse(_ url: URL) -> PantoDeepLink? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "panto" || scheme == "clash" else {
            return nil
        }

        // 处理主机名或路径标识 (例如 panto://install-config 或 panto:///install-config)
        let action = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let queryItems = components.queryItems ?? []
        let queryDict = Dictionary(queryItems.compactMap { item in
            item.value.map { (item.name.lowercased(), $0) }
        }, uniquingKeysWith: { first, _ in first })

        switch action {
        case "install-config", "install", "add-profile":
            guard let urlStr = queryDict["url"],
                  let downloadURL = URL(string: urlStr) else {
                return nil
            }
            let name = queryDict["name"]
            let token = queryDict["token"]
            return .installConfig(downloadURL: downloadURL, name: name, token: token)

        case "import", "data":
            guard let rawData = queryDict["data"] else {
                return nil
            }
            // 尝试 Base64 解码，若不是 Base64 则直接作为原始内容
            let content: String
            if let decodedData = Data(base64Encoded: rawData),
               let str = String(data: decodedData, encoding: .utf8) {
                content = str
            } else {
                content = rawData
            }
            let name = queryDict["name"]
            return .importData(content: content, name: name)

        default:
            return nil
        }
    }
}
