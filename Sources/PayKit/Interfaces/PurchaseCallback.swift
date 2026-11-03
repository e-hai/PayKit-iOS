import Foundation

/// 购买操作结果回调协议（所有回调均在主线程分发）
public protocol PurchaseCallback: AnyObject, Sendable {
    /// 购买完成且已确认/记账（对于消耗品，宿主应在此回调中发放金币/道具）
    func onCompleted(transaction: StoreTransaction)

    /// 购买处于挂起/待授权状态（如家长控制 Ask to Buy、银行二次验证，宿主此时切勿发货）
    func onPending(transaction: StoreTransaction)

    /// 购买失败或取消
    func onError(error: PayKitError)
}

/// 闭包风格的购买回调封装
public final class ClosurePurchaseCallback: PurchaseCallback, @unchecked Sendable {
    private let completedBlock: @Sendable (StoreTransaction) -> Void
    private let pendingBlock: @Sendable (StoreTransaction) -> Void
    private let errorBlock: @Sendable (PayKitError) -> Void

    public init(
        onCompleted: @escaping @Sendable (StoreTransaction) -> Void,
        onPending: @escaping @Sendable (StoreTransaction) -> Void = { _ in },
        onError: @escaping @Sendable (PayKitError) -> Void
    ) {
        self.completedBlock = onCompleted
        self.pendingBlock = onPending
        self.errorBlock = onError
    }

    public func onCompleted(transaction: StoreTransaction) {
        completedBlock(transaction)
    }

    public func onPending(transaction: StoreTransaction) {
        pendingBlock(transaction)
    }

    public func onError(error: PayKitError) {
        errorBlock(error)
    }
}
