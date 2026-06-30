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
                AppState.shared.updateFullscreenSuppression()
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
}
