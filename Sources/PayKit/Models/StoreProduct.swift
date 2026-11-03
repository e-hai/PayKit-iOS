import Foundation
import StoreKit

/// 统一的商店商品模型
public struct StoreProduct: Identifiable, Sendable {
    public var id: String { productId }

    /// 商品唯一标识符
    public let productId: String
    /// 商品大类（SUBS / INAPP）
    public let type: ProductType
    /// 商品标题
    public let title: String
    /// 商品详细描述
    public let description: String
    /// 格式化价格字符串，例如 "$4.99" 或 "¥38.00"
    public let price: String
    /// 微单位价格（如 4.99 美元对应 4,990,000）
    public let priceAmountMicros: Int64
    /// 货币代码（如 USD、CNY、EUR）
    public let priceCurrencyCode: String
    /// 订阅周期描述（如 "P1M" 表示按月，"P1Y" 表示按年）
    public let subscriptionPeriod: String?
    /// 是否包含免费试用
    public let hasFreeTrial: Bool
    /// 免费试用周期描述（如 "P1W"）
    public let freeTrialPeriod: String?
    /// 底层 StoreKit 2 Product（内部购买使用）
    public let nativeProduct: Product?

    public init(
        productId: String,
        type: ProductType,
        title: String,
        description: String,
        price: String,
        priceAmountMicros: Int64,
        priceCurrencyCode: String,
        subscriptionPeriod: String? = nil,
        hasFreeTrial: Bool = false,
        freeTrialPeriod: String? = nil,
        nativeProduct: Product? = nil
    ) {
        self.productId = productId
        self.type = type
        self.title = title
        self.description = description
        self.price = price
        self.priceAmountMicros = priceAmountMicros
        self.priceCurrencyCode = priceCurrencyCode
        self.subscriptionPeriod = subscriptionPeriod
        self.hasFreeTrial = hasFreeTrial
        self.freeTrialPeriod = freeTrialPeriod
        self.nativeProduct = nativeProduct
    }
}
