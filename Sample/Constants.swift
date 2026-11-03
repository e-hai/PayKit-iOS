import Foundation

/// 示例 App 商品常量定义（对齐 Android 示例结构：Free < Plus < Pro）
public enum Constants {
    // 订阅类商品 ID
    public static let subsPlusMonthly = "plus_monthly"
    public static let subsPlusYearly = "plus_yearly"
    public static let subsProMonthly = "pro_monthly"
    public static let subsProYearly = "pro_yearly"

    // 内购一次性商品 ID
    public static let inappCoins100 = "coins_100"
    public static let inappLifetime = "lifetime_pass"

    public static let allSubs: Set<String> = [
        subsPlusMonthly,
        subsPlusYearly,
        subsProMonthly,
        subsProYearly
    ]

    public static let allConsumables: Set<String> = [
        inappCoins100
    ]

    public static let allNonConsumables: Set<String> = [
        inappLifetime
    ]
}
