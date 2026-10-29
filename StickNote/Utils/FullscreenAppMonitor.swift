import AppKit
import Combine
import Defaults

@MainActor
final class FullscreenAppMonitor {
    static let shared = FullscreenAppMonitor()

    private var observers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func start() {
        guard observers.isEmpty else { return }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let workspaceNames: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ]
        for name in workspaceNames {
            let observer = workspaceCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { _ in
                Self.updateNowAndAfterAnimation()
            }
            observers.append(observer)
        }

        let screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppState.shared.updateFullscreenSuppression()
        }
        observers.append(screenObserver)

        Defaults.publisher(.hideNotesWhenFullscreenApp)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                AppState.shared.updateFullscreenSuppression()
            }
            .store(in: &cancellables)

        AppState.shared.updateFullscreenSuppression()
    }

    /// The space-change notification fires before the fullscreen animation ends, while the window is still small.
    private static func updateNowAndAfterAnimation() {
        AppState.shared.updateFullscreenSuppression()
        for delay in [0.6, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AppState.shared.updateFullscreenSuppression()
            }
        }
    }
}
