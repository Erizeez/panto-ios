import Foundation
import os.log

/// MemoryWatchdog 专为 iOS Network Extension 的严苛内存限制（通常 15MB~50MB）设计。
/// 通过 GCD 内存压力源监控系统压力，并在临界点主动通知 Go 运行时执行堆释放，防止 Jetsam 击杀。
public final class MemoryWatchdog {
    private static let logger = Logger(subsystem: "org.panto.ios", category: "Watchdog")
    private var source: DispatchSourceMemoryPressure?
    private let onMemoryWarning: () -> Void

    public init(onMemoryWarning: @escaping () -> Void) {
        self.onMemoryWarning = onMemoryWarning
        setupPressureSource()
    }

    private func setupPressureSource() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .userInitiated))
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = source.data
            if event.contains(.critical) {
                Self.logger.error("🚨 捕获到系统严重内存警告 (Critical)！紧急触发 Go 堆内存释放...")
            } else if event.contains(.warning) {
                Self.logger.warning("⚠️ 捕获到系统内存警告 (Warning)！执行轻量垃圾回收...")
            }
            self.onMemoryWarning()
        }
        source.resume()
        self.source = source
    }

    deinit {
        source?.cancel()
    }

    /// 获取当前进程占用的物理常驻内存（Resident Size，字节）。
    public static func currentMemoryUsageBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
}
