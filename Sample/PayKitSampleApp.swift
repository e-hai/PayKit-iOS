import SwiftUI
import PayKit

@main
struct PayKitSampleApp: App {
    init() {
        LogUtil.enabled = true
        LogUtil.i(LogUtil.tagSample, "PayKitSampleApp launching")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
