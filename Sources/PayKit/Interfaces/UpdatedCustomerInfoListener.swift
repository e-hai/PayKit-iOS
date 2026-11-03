import Foundation

/// 权益变动监听器（每次同步完成、购买完成时回调，主线程分发）
public protocol UpdatedCustomerInfoListener: AnyObject, Sendable {
    func onCustomerInfoUpdated(_ customerInfo: CustomerInfo)
}

/// 闭包封装的权益监听器
public final class ClosureCustomerInfoListener: UpdatedCustomerInfoListener, @unchecked Sendable {
    private let block: @Sendable (CustomerInfo) -> Void

    public init(block: @escaping @Sendable (CustomerInfo) -> Void) {
        self.block = block
    }

    public func onCustomerInfoUpdated(_ customerInfo: CustomerInfo) {
        block(customerInfo)
    }
}
