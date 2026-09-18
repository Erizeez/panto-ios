import Foundation
import NetworkExtension
import os.log
import PantoShared

#if canImport(PantoKit)
import PantoKit
#endif

/// PacketTunnelProvider 是 iOS 系统级别的网络扩展守护进程。
/// 负责接管虚拟网卡 TUN 报文收发，并通过 IPC 承接主应用发来的控制指令。
public class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "org.panto.ios", category: "PacketTunnelProvider")
    private var watchdog: MemoryWatchdog?

    public override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("🚀 Panto Tunnel 扩展正在启动...")

        // 1. 初始化 15MB 内存硬红线看门狗
        watchdog = MemoryWatchdog { [weak self] in
            self?.logger.warning("⚠️ 触发紧急内存回收，调用 Rust 底层释放堆内存与物理页...")
            #if canImport(PantoKit)
            panto_mobile_free_memory()
            #endif
        }

        // 2. 配置基础网络路由参数
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let ipv4Settings = NEIPv4Settings(addresses: ["10.201.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        tunnelNetworkSettings.ipv4Settings = ipv4Settings

        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        tunnelNetworkSettings.dnsSettings = dnsSettings

        // 3. 应用网络配置
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                self?.logger.error("❌ 应用网络配置失败: \(error.localizedDescription)")
                completionHandler(error)
                return
            }

            self?.logger.info("✅ Panto Tunnel 虚拟网卡装载成功，准备启动底层核心...")
            #if canImport(PantoKit)
            // 在实际集成中，传递配置 YAML 给 Rust 核心引擎
            // _ = panto_mobile_start(configYAML)
            #endif

            completionHandler(nil)
        }
    }

    public override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("🛑 Panto Tunnel 正在停止，原因代码: \(reason.rawValue)")

        #if canImport(PantoKit)
        _ = panto_mobile_stop()
        panto_mobile_free_memory()
        #endif

        watchdog = nil
        completionHandler()
    }

    /// handleAppMessage 是跨进程 IPC 防火墙的关键接收端。
    /// 接收主 App 发送的强类型控制动作（无需开启任何本地 TCP/HTTP 端口）。
    public override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let request = try? JSONDecoder().decode(IPCRequest.self, from: messageData) else {
            logger.error("❌ 收到非法的 IPC 数据帧")
            let errResp = IPCResponse(success: false, error: "Invalid IPCRequest")
            completionHandler?(try? JSONEncoder().encode(errResp))
            return
        }

        logger.debug("📩 收到主 App IPC 请求动作: \(request.action)")

        #if canImport(PantoKit)
        let actionStr = request.action
        let payloadStr = request.payload.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let cResult = panto_mobile_dispatch(actionStr, payloadStr)
        var resultData: Data? = nil
        if let cResult = cResult {
            let str = String(cString: cResult)
            resultData = str.data(using: .utf8)
            panto_free_string(cResult)
        }
        let resp = IPCResponse(success: true, data: resultData)
        completionHandler?(try? JSONEncoder().encode(resp))
        #else
        // Mock 回复（未导入 PantoKit 框架时的自测回路）
        if request.action == "ping" {
            let resp = IPCResponse(success: true, data: "{\"status\":\"ok\",\"mock\":true}".data(using: .utf8))
            completionHandler?(try? JSONEncoder().encode(resp))
        } else {
            let resp = IPCResponse(success: true, data: "{}".data(using: .utf8))
            completionHandler?(try? JSONEncoder().encode(resp))
        }
        #endif
    }
}
