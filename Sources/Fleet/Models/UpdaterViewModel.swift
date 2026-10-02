import Combine
import Sparkle

/// Wraps SPUStandardUpdaterController for SwiftUI. Owns the Sparkle update
/// controller for the lifetime of the app and bridges canCheckForUpdates
/// (a KVO property on SPUUpdater) into a @Published value SwiftUI can observe.
final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController

    init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil)
        // assign(to:) ties the subscription lifetime to $canCheckForUpdates —
        // no separate AnyCancellable needed, no retain cycle.
        controller.updater
            .publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
