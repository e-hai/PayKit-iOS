# PayKit-iOS

轻量级 iOS StoreKit 2 支付 SDK（Swift Package Manager），对外提供简洁、**纯本地无后端**、现代 Swift 并发（`async/await`）API。

对齐 Android 版本设计哲学与概念模型，提供跨平台一致的支付体验。

---

## 特性亮点

- **现代架构**：完全基于 Apple **StoreKit 2**（iOS 15+ / macOS 12+ / visionOS 1+），采用 Swift 原生并发与 JWS 密码学签名。
- **纯本地无后端**：无需搭建鉴权服务即可计算用户有效订阅与权益快照。
- **冷启动秒开**：基于 `UserDefaults` 的 `DeviceCache` 本地快照，启动首屏秒级获取权益。
- **履约账本机制**：针对消耗品（金币/道具）内置 `ConsumableLedger`，发货先记账，防止掉单、崩溃丢单，支持自动补单重试。
- **双向 API 风格**：同时支持现代 `async/await` 与经典的 `PurchaseCallback` / `UpdatedCustomerInfoListener` 回调。
- **开箱即用扩展**：默认 `LocalPurchaseVerifier`；如需服务端验签，可无缝接入自定义 `PurchaseVerifier`。
- **本地仿真调试**：内置 `PayKitSample.storekit` 配置文件，无需配置 App Store Connect 即可在 Xcode 中模拟测试订阅、内购、试用、扣款失败等各种场景。

---

## 架构概览

```
宿主 App / SwiftUI ViewModel
         │
         ▼
    PayKit (单例)
         │
   ┌─────┼─────────────────────┐
   ▼     ▼                     ▼
DeviceCache   CustomerInfoHelper   StoreKit2Wrapper
(UserDefaults)    (权益计算引擎)        └─ StoreKit 2
                                          └─ Transaction.updates / currentEntitlements
```

---

## 安装集成

### Swift Package Manager (SPM)

在 Xcode 项目中通过 **File > Add Package Dependencies...**，或在 `Package.swift` 中引入：

```swift
dependencies: [
    .package(url: "https://github.com/e-hai/PayKit-iOS.git", branch: "main")
]
```

并在 Target 中依赖：

```swift
.product(name: "PayKit", package: "PayKit")
```

---

## 快速上手

### 1. 初始化配置

在 App 启动生命周期（如 `@main App` 的 `init()`）中配置商品 ID 分类：

```swift
import PayKit

let config = PayKitConfiguration(
    subsProductIds: [
        "plus_monthly", "plus_yearly",
        "pro_monthly", "pro_yearly"
    ],
    consumableProductIds: [
        "coins_100", "coins_500"
    ],
    nonConsumableProductIds: [
        "lifetime_pass"
    ]
)

PayKit.configure(configuration: config)
```

> **注意**：商品 ID 必须按订阅（`subs`）、消耗品（`consumable`）、非消耗品（`nonConsumable`）明确分类，不可交叉。

---

### 2. 查询商品详情

```swift
let result = await PayKit.shared.getProducts(productIds: ["pro_monthly", "coins_100"])

switch result {
case .success(let products):
    for prod in products {
        print("商品: \(prod.title), 价格: \(prod.price), 是否含试用: \(prod.hasFreeTrial)")
    }
case .failure(let error):
    print("查询失败: \(error.message)")
}
```

---

### 3. 发起购买

#### 方式 A：现代 Async/Await

```swift
let purchaseResult = await PayKit.shared.purchase(storeProduct: product)

switch purchaseResult {
case .success(let transaction):
    print("购买成功: 订单 ID=\(transaction.orderId ?? "")")
    // 若为消耗品，在此处发放道具/金币
case .failure(let error):
    if error.code == .purchaseCancelled {
        print("用户取消了购买")
    } else {
        print("购买失败: \(error.message)")
    }
}
```

#### 方式 B：回调协议（主线程自动调度）

```swift
PayKit.shared.purchase(
    storeProduct: product,
    callback: ClosurePurchaseCallback(
        onCompleted: { txn in
            print("支付成功并已确认: \(txn.productIds)")
            // 发放金币/道具
        },
        onPending: { txn in
            print("等待授权（家长控制或银行验证），切勿发货")
        },
        onError: { error in
            print("购买失败: \(error.message)")
        }
    )
)
```

---

### 4. 获取与监听权益快照

#### 启动秒读本地缓存

```swift
// forceSync = false: 优先读取本地持久化快照，零等待
if let info = await PayKit.shared.getCustomerInfo(forceSync: false) {
    let isVip = info.activeSubscriptions.contains("pro_monthly")
    print("当前会员状态: \(isVip)")
}
```

#### 注册全局权益监听

```swift
PayKit.shared.setUpdatedCustomerInfoListener(ClosureCustomerInfoListener { info in
    print("权益更新: 活跃订阅=\(info.activeSubscriptions), 永久权益=\(info.nonConsumablePurchases)")
})
```

或使用现代 `AsyncStream`：

```swift
Task {
    for await info in PayKit.shared.customerInfoStream {
        self.activeSubs = info.activeSubscriptions
    }
}
```

---

### 5. 恢复购买

```swift
let restoreResult = await PayKit.shared.restorePurchases()
switch restoreResult {
case .success(let info):
    print("恢复成功，当前有效订阅: \(info.activeSubscriptions)")
case .failure(let error):
    print("恢复失败: \(error.message)")
}
```

---

### 6. 消耗品补单机制

PayKit 在启动或调用 `syncPurchases()` 时会自动检查未完成的消耗品交易：

```swift
if let info = await PayKit.shared.getCustomerInfo() {
    for item in info.unfulfilledConsumables {
        print("发现未履约消耗品: \(item.productIds)")
        // 1. 补发道具
        myCoinService.addCoins(100)
        // 2. 通知 PayKit finish 交易并清理账本
        _ = await PayKit.shared.markConsumableFulfilled(purchaseToken: item.purchaseToken)
    }
}
```

---

### 7. 服务端验单扩展（可选）

默认情况下使用 `LocalPurchaseVerifier`。若需要对接您的自有业务服务端：

```swift
let customVerifier = PurchaseVerifier { txn in
    // 将 txn.purchaseToken / txn.signature / txn.originalJson 发送给您的后端验单
    let ok = await myBackendApi.verifyAppleReceipt(token: txn.purchaseToken, signature: txn.signature)
    return ok ? .success(()) : .failure(PayKitError(code: .verificationFailed, message: "Server verify failed"))
}

PayKit.shared.setPurchaseVerifier(customVerifier)
```

---

## 本地 StoreKit 仿真测试

无需配置真实 Apple Developer 账号即可测试全流程：

1. 在 Xcode 打开项目，将 `Sample/PayKitSample.storekit` 添加到 Scheme:
   - **Product > Scheme > Edit Scheme...**
   - 选中 **Run > Options > StoreKit Configuration**，选择 `PayKitSample.storekit`。
2. 运行 App 即可模拟测试：
   - 切换 Plus 与 Pro 档位
   - 免费试用体验
   - 消耗品发货与重购
   - 撤销购买与恢复购买

---

## 跨平台对齐表

| 功能点 | PayKit Android | PayKit iOS |
|---|---|---|
| 底层技术栈 | Google Play Billing Library 8.3.0 | StoreKit 2 (iOS 15+) |
| 异步编程模型 | Kotlin Coroutines (`suspend fun`) | Swift Concurrency (`async/await`) |
| 交易模型 | `StoreTransaction` | `StoreTransaction` |
| 权益模型 | `CustomerInfo` | `CustomerInfo` |
| 本地缓存 | `DeviceCache` (SharedPreferences) | `DeviceCache` (UserDefaults) |
| 消耗品防掉单 | `ConsumableLedger` | `ConsumableLedger` |
| 服务端验签插槽 | `PurchaseVerifier` | `PurchaseVerifier` |
| 恢复购买语义 | `restorePurchases()` | `restorePurchases()` |
| 状态/错误码 | `ErrorCode` 统一枚举 | `PayKitErrorCode` 统一枚举 |

---

## License

MIT License
