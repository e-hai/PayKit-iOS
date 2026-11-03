import Foundation

/// 支付引擎抽象协议
public protocol BillingAbstract: AnyObject, Sendable {
    /// 启动连接/初始化监听
    func startConnection() throws

    /// 断开连接/取消监听
    func endConnection()

    /// 查询商品详情
    func queryProductDetails(productIds: Set<String>) async throws -> [StoreProduct]

    /// 查询当前持有的交易记录（分为订阅与内购）
    func queryPurchases() async throws -> (subs: [StoreTransaction], inapp: [StoreTransaction])

    /// 发起购买流程
    func launchBillingFlow(
        storeProduct: StoreProduct,
        callback: PurchaseCallback
    )

    /// 完成/确认交易（消耗品发货后调用或重试消单）
    func finishTransaction(purchaseToken: String) async throws
}
