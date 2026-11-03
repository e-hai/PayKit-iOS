import Foundation

/// 确保闭包在主线程安全执行的调度辅助
enum MainActorHelper {
    static func runOnMain<T>(action: @escaping () -> T) {
        if Thread.isMainThread {
            _ = action()
        } else {
            DispatchQueue.main.async {
                _ = action()
            }
        }
    }

    static func runOnMainAsync(action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            action()
        }
    }
}
