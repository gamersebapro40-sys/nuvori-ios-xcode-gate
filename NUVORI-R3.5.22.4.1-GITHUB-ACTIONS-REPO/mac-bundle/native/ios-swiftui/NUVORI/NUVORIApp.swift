import SwiftUI

@main
struct NUVORIApp: App {
    @StateObject private var app = NUVORIAppState()
    var body: some Scene { WindowGroup { RootView().environmentObject(app) } }
}
