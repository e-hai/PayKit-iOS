import SwiftUI
import PayKit

public struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 当前权益状态卡片
                    statusCard

                    // 订阅档位切换
                    tierPicker

                    // 订阅选项
                    subscriptionOffers

                    Divider()

                    // 一次性内购
                    inappSection

                    // 恢复购买与底部
                    Button(action: {
                        Task { await viewModel.restorePurchases() }
                    }) {
                        Label("恢复购买 (Restore Purchases)", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
            .navigationTitle("PayKit iOS Demo")
            .alert("提示", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("处理中...")
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.8))
                        .cornerRadius(12)
                }
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("当前会员状态")
                    .font(.headline)
                Spacer()
                Text(viewModel.currentTier.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(tierColor(viewModel.currentTier))
                    .cornerRadius(8)
            }

            Text("金币余额: \(viewModel.coinBalance)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !viewModel.nonConsumables.isEmpty {
                Text("已解锁永久特权")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var tierPicker: some View {
        Picker("选择档位", selection: $viewModel.selectedTier) {
            ForEach(UserTier.allCases.filter { $0 != .free }) { tier in
                Text(tier.rawValue).tag(tier)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }

    private var subscriptionOffers: some View {
        VStack(spacing: 12) {
            let filteredProducts = viewModel.products.filter { prod in
                if viewModel.selectedTier == .pro {
                    return prod.productId.hasPrefix("pro_")
                } else {
                    return prod.productId.hasPrefix("plus_")
                }
            }

            if filteredProducts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "cart.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂未查询到该档位商品")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if viewModel.products.isEmpty && !viewModel.isLoading {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("💡 本地测试提示（未关联 StoreKit 仿真文件）：")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("1. 在 Xcode 菜单栏选择 Product -> Scheme -> Edit Scheme... (⌘ <)")
                                .font(.caption2)
                            Text("2. 左侧点击 Run，右侧切到 Options 选项卡")
                                .font(.caption2)
                            Text("3. 找到 StoreKit Configuration，下拉选中 PayKitSample.storekit")
                                .font(.caption2)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)

                        Button(action: {
                            Task { await viewModel.loadProducts() }
                        }) {
                            Label("重新查询商品", systemImage: "arrow.clockwise")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                ForEach(filteredProducts) { product in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(product.title)
                                    .font(.headline)
                                if product.hasFreeTrial {
                                    Text("免费试用")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .cornerRadius(4)
                                }
                            }
                            Text(product.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            viewModel.purchase(product: product)
                        }) {
                            Text(product.price)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var inappSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内购商品")
                .font(.headline)

            let inappProducts = viewModel.products.filter { prod in
                prod.productId == Constants.inappCoins100 || prod.productId == Constants.inappLifetime
            }

            if inappProducts.isEmpty {
                Text("暂无内购商品")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                ForEach(inappProducts) { product in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.title)
                                .font(.headline)
                            Text(product.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            viewModel.purchase(product: product)
                        }) {
                            Text(product.price)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    private func tierColor(_ tier: UserTier) -> Color {
        switch tier {
        case .free: return .gray
        case .plus: return .blue
        case .pro: return .purple
        }
    }
}
