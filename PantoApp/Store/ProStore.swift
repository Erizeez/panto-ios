import Foundation
import StoreKit
import os.log

/// ProStore 采用 Apple 最新的 StoreKit 2 框架实现商业化“一次性永久买断 (Lifetime Pro)”。
/// 完全在本地通过 Apple 密码学 JWS 校验收据与凭据，无需自建后端服务器，防篡改且支持离线激活。
@MainActor
public final class ProStore: ObservableObject {
    private static let logger = Logger(subsystem: "org.panto.ios", category: "ProStore")

    @Published public private(set) var isProUnlocked: Bool = false
    @Published public private(set) var lifetimeProduct: Product?
    @Published public private(set) var isPurchasing: Bool = false
    @Published public var errorMessage: String?

    private var transactionListener: Task<Void, Error>?

    public init() {
        transactionListener = listenForTransactions()
        Task {
            await fetchProducts()
            await updateCustomerProductStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// 拉取 App Store 上的内购商品元数据（价格、货币符号、本地化描述）。
    public func fetchProducts() async {
        do {
            let products = try await Product.products(for: [AppGroupConstants.lifetimeProProductID])
            if let product = products.first {
                self.lifetimeProduct = product
                Self.logger.info("✅ 成功加载 StoreKit 2 商品: \(product.displayName) (\(product.displayPrice))")
            }
        } catch {
            Self.logger.error("❌ 拉取商品信息失败: \(error.localizedDescription)")
            self.errorMessage = "无法连接 App Store，请检查网络"
        }
    }

    /// 发起一次性永久买断购买。
    public func purchaseLifetimePro() async -> Bool {
        guard let product = lifetimeProduct else {
            self.errorMessage = "商品尚未就绪，请稍后再试"
            return false
        }

        self.isPurchasing = true
        defer { self.isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                Self.logger.info("🎉 购买成功并通过 JWS 验签！交易 ID: \(transaction.id)")
                await updateCustomerProductStatus()
                await transaction.finish()
                return true

            case .userCancelled:
                Self.logger.info("用户取消了购买流程")
                return false

            case .pending:
                Self.logger.info("购买处于等待状态 (例如家长监护审批)")
                return false

            @unknown default:
                return false
            }
        } catch {
            Self.logger.error("❌ 购买流程异常: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    /// 恢复已购买项目（用于换机或重新安装应用）。
    public func restorePurchases() async {
        try? await AppStore.sync()
        await updateCustomerProductStatus()
    }

    /// 实时监听来自系统的外部交易（例如在设置中兑换促销码、家庭共享等）。
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    Self.logger.error("交易校验失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 扫描当前用户的全部生效权利（Entitlements），判断是否已持有 Pro 授权。
    public func updateCustomerProductStatus() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == AppGroupConstants.lifetimeProProductID {
                    if transaction.revocationDate == nil {
                        hasPro = true
                    }
                }
            } catch {
                Self.logger.error("收据校验失败: \(error.localizedDescription)")
            }
        }
        self.isProUnlocked = hasPro
        Self.logger.info("当前用户的 Pro 权限状态: \(hasPro ? "已解锁 (Pro)" : "免费版 (Free)")")
    }

    /// JWS 密码学签名有效性校验。
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
