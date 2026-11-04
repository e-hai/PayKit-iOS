# PayKit-iOS – AGENTS.md

给 AI Agent（Cursor / Codex / Copilot 等）用的项目说明：快速理解结构、约定与安全改动边界。

## What This Project Is

轻量级 iOS StoreKit 2 支付 SDK（SPM Library）+ SwiftUI 示例 App（`Sample`）。

封装 Apple 原生 **StoreKit 2**（iOS 15+），对外提供简洁、**纯本地无后端**的 Swift 并发（`async/await`）API：

- 商品查询 / 发起购买 / 自动 finish 或账本记录
- 启动时同步购买记录（补单）
- `CustomerInfo` 本地权益计算 + `UserDefaults` 缓存

**关键设计决策**：无服务端验单；商品类型（订阅 / 消耗 / 非消耗）必须由宿主在 `PayKitConfiguration` 中声明，补单时才能正确判断消耗品与有效订阅。

## Project Layout

```
PayKit-iOS/
├── Package.swift                     # SPM 清单定义
├── Sources/
│   └── PayKit/
│       ├── PayKit.swift              # [Entry Point] 单例门面
│       ├── Billing/
│       │   ├── BillingAbstract.swift # 支付抽象层协议
│       │   └── StoreKit2Wrapper.swift# StoreKit 2 原生实现
│       ├── Caching/
│       │   ├── DeviceCache.swift     # CustomerInfo 权益快照持久化 (UserDefaults)
│       │   └── ConsumableLedger.swift# 消耗品履约账本（待 finish）
│       ├── Subscriber/
│       │   └── CustomerInfoHelper.swift# 订单 → 权益归类逻辑
│       ├── Models/
│       │   ├── PayKitConfiguration.swift
│       │   ├── CustomerInfo.swift
│       │   ├── StoreProduct.swift
│       │   ├── StoreTransaction.swift
│       │   ├── ProductType.swift
│       │   ├── PurchaseState.swift
│       │   └── ConsumableLedgerEntry.swift
│       ├── Interfaces/
│       │   ├── PurchaseCallback.swift
│       │   ├── PurchaseVerifier.swift
│       │   ├── UpdatedCustomerInfoListener.swift
│       │   └── PayKitError.swift
│       └── Utils/
│           ├── LogUtil.swift         # 统一日志
│           └── MainActorHelper.swift # 主线程调度辅助
├── Tests/
│   └── PayKitTests/                  # XCTest 单元测试集
├── Sample/                           # SwiftUI Demo 示例
│   ├── Constants.swift
│   ├── ContentView.swift
│   ├── ContentViewModel.swift
│   ├── PayKitSampleApp.swift
│   └── PayKitSample.storekit         # 本地 StoreKit 仿真配置
├── README.md                         # 开发者接入文档
└── AGENTS.md                         # 本文件
```

## Release & Integration

- **Tag**: `1.0.0` / `v1.0.0`
- **SPM Dependency**:
  ```swift
  .package(url: "https://github.com/e-hai/PayKit-iOS.git", from: "1.0.0")
  ```
- **Target Dependency**:
  ```swift
  .product(name: "PayKit", package: "PayKit")
  ```

## Build Toolchain

| Tool | Version |
|---|---|
| Swift | >= 5.9 (Swift 6 ready) |
| Xcode | >= 15.0 |
| StoreKit | StoreKit 2 (iOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+, visionOS 1.0+) |

构建与测试：
```bash
swift build
swift test
```

## Architecture

```
Host App / SwiftUI ViewModel
        │
        ▼
   PayKit (singleton)
        │
   ┌────┼────────────────────┐
   ▼    ▼                    ▼
DeviceCache  CustomerInfoHelper  BillingAbstract
(本地缓存)    (权益计算)          └─ StoreKit2Wrapper
                                      └─ StoreKit 2 (Transaction.updates / currentEntitlements)
```

### Core Data Flow

1. **Init**：`PayKit.configure(configuration:)` → `billing.startConnection()` 监听 `Transaction.updates` → `syncPurchases()` 异步同步。
2. **Sync / 恢复**：`syncPurchases()` / `restorePurchases()` → 查 `Transaction.currentEntitlements` + 未完成交易 → 订阅/非消耗自动 finish 并确认；消耗品仅在履约账本记录时追踪 → 更新 `CustomerInfo`。
3. **Query**：`getProducts(productIds)` 校验 ID 声明后调用 `Product.products(for:)`。
4. **Purchase**：`purchase(...)` → `Product.purchase()` → 成功后消耗品先记账本 → `onCompleted`（宿主发货）→ finish 交易并清理账本；失败留账本重试。
5. **查权益**：启动用 `getCustomerInfo(forceSync: false)` 秒读缓存；未履约消耗品见 `CustomerInfo.unfulfilledConsumables` / `markConsumableFulfilled`。

## Public API（稳定面）

```swift
PayKit.configure(configuration: PayKitConfiguration)
PayKit.reset(clearCache: Bool = true)

PayKit.shared

func getProducts(productIds: Set<String>) async -> Result<[StoreProduct], PayKitError>
func getCustomerInfo(forceSync: Bool = true) async -> CustomerInfo?
func syncPurchases() async -> Result<CustomerInfo, PayKitError>
func restorePurchases() async -> Result<CustomerInfo, PayKitError>
func getPendingPurchases() async -> [StoreTransaction]
func getPurchaseHistory() async -> [StoreTransaction]
func findTransaction(purchaseToken: String) -> StoreTransaction?
func findActiveSubscription(productId: String) -> StoreTransaction?
func getConsumablesPendingConsume() -> [ConsumableLedgerEntry]
func markConsumableFulfilled(purchaseToken: String) async -> Result<Void, PayKitError>

func purchase(storeProduct: StoreProduct, callback: PurchaseCallback)
func purchase(storeProduct: StoreProduct) async -> Result<StoreTransaction, PayKitError>

func setUpdatedCustomerInfoListener(_ listener: UpdatedCustomerInfoListener?)
var customerInfoStream: AsyncStream<CustomerInfo> { get }
func setPurchaseVerifier(_ verifier: PurchaseVerifier)
```

## Important Notes for Agents

1. **对齐 Android 设计哲学**：API 命名、错误码、履约账本、日志格式保持与 Android 版完全一致。
2. **保持单回调设计**：进行中的购买单笔保护，防止多次点击穿透产生并发购买冲突；二次调用返回 `purchaseInProgress`。
3. **默认本地验证**：信赖 StoreKit 2 原生密码学验证，默认使用 `LocalPurchaseVerifier`。
4. **主线程调度**：公开接口的回调及监听器保证在主线程分发。
5. **测试覆盖**：改动核心逻辑后必须执行 `swift test` 保证全部通过。
