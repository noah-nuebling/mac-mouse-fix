import Cocoa

@objc(M720CaptureUIController)
final class M720CaptureUIController: NSObject {
    @objc static let shared = M720CaptureUIController()

    private enum AlertRequest {
        case conflict(UUID)
        case failure(M720StableErrorCode)
    }

    private let ipcQueue = DispatchQueue(
        label: "com.nuebling.mac-mouse-fix.m720-capture-ui-ipc"
    )
    private var alertReducer = M720CaptureAlertReducer()
    private var pendingAlerts: [AlertRequest] = []
    private var isPresentingAlert = false

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(presentationOpportunity(_:)),
            name: NSWindow.didEndSheetNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(presentationOpportunity(_:)),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
    }

    @objc(refreshCaptureStates)
    func refreshCaptureStates() {
        ipcQueue.async { [weak self] in
            let raw = MFMessagePort.sendMessage(
                M720IPCMessage.getCaptureStates,
                withPayload: nil,
                waitForReply: true
            )
            guard let states = try? M720CaptureStates.decode(raw) else { return }
            DispatchQueue.main.async {
                self?.replaceCaptureStates(states.states)
            }
        }
    }

    @objc(handleCaptureStateChangedWithPayload:)
    func handleCaptureStateChanged(payload: NSDictionary) {
        guard let state = try? M720CaptureState.decode(payload) else {
            presentFailure(.protocol)
            return
        }
        onMain { [weak self] in
            self?.receiveCaptureState(state)
        }
    }

    func presentFailure(_ error: M720StableErrorCode) {
        guard error != .cancelled, error != .conflict else { return }
        onMain { [weak self] in
            self?.enqueue(.failure(error))
        }
    }

    func presentConflictSample() {
        onMain { [weak self] in
            self?.enqueue(.conflict(
                UUID(uuidString: "72000000-0000-0000-0000-000000000001")!
            ))
        }
    }

    func presentFailureSample(_ error: M720StableErrorCode) {
        onMain { [weak self] in
            self?.enqueue(.failure(error))
        }
    }

    private func replaceCaptureStates(_ states: [M720CaptureState]) {
        for state in alertReducer.replaceSnapshot(states) {
            enqueue(.conflict(state.deviceToken))
        }
        presentNextAlertIfPossible()
    }

    private func receiveCaptureState(_ state: M720CaptureState) {
        if alertReducer.shouldPresent(state) {
            enqueue(.conflict(state.deviceToken))
        } else {
            presentNextAlertIfPossible()
        }
    }

    private func enqueue(_ request: AlertRequest) {
        pendingAlerts.append(request)
        presentNextAlertIfPossible()
    }

    private func presentNextAlertIfPossible() {
        guard !isPresentingAlert,
              !pendingAlerts.isEmpty,
              let window = MainAppState.shared.window,
              window.attachedSheet == nil
        else { return }

        let request = pendingAlerts.removeFirst()
        let alert = makeAlert(for: request)
        isPresentingAlert = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.isPresentingAlert = false
            if case let .conflict(deviceToken) = request,
               response == .alertFirstButtonReturn {
                self.retry(deviceToken: deviceToken, requestID: UUID())
            }
            self.presentNextAlertIfPossible()
        }
    }

    private func makeAlert(for request: AlertRequest) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        switch request {
        case .conflict:
            alert.messageText = MFLocalizedString("m720.conflict.title", comment: "")
            alert.informativeText = MFLocalizedString("m720.conflict.body", comment: "")
            alert.addButton(withTitle: MFLocalizedString("m720.conflict.retry", comment: ""))
            alert.addButton(withTitle: MFLocalizedString("m720.conflict.not-now", comment: ""))
        case let .failure(error):
            alert.messageText = MFLocalizedString("m720.error.title", comment: "")
            alert.informativeText = localizedExplanation(for: error)
            alert.addButton(withTitle: MFLocalizedString("m720.error.ok", comment: ""))
        }
        return alert
    }

    private func localizedExplanation(for error: M720StableErrorCode) -> String {
        let key: String
        switch error {
        case .timeout:
            key = "m720.error.timeout"
        case .unsupported:
            key = "m720.error.unsupported"
        case .disconnected, .deviceSetChanged, .appUnavailable:
            key = "m720.error.disconnected"
        case .protocol, .conflict, .cancelled:
            key = "m720.error.protocol"
        }
        return MFLocalizedString(key, comment: "")
    }

    private func retry(deviceToken: UUID, requestID: UUID) {
        let payload = M720RetryCaptureRequest(
            requestID: requestID,
            deviceToken: deviceToken
        ).payload
        ipcQueue.async { [weak self] in
            let raw = MFMessagePort.sendMessage(
                M720IPCMessage.retryCapture,
                withPayload: payload,
                waitForReply: true
            )
            let acknowledgement = try? M720IPCAcknowledgement.decode(raw)
            guard acknowledgement?.isAccepted != true else { return }
            let error = acknowledgement?.error ?? .disconnected
            DispatchQueue.main.async {
                self?.handleRetryRejection(deviceToken: deviceToken, error: error)
            }
        }
    }

    private func handleRetryRejection(
        deviceToken: UUID,
        error: M720StableErrorCode
    ) {
        guard alertReducer.shouldPresentRetryError(
            deviceToken: deviceToken,
            errorCode: error
        ) else { return }
        enqueue(.failure(error))
    }

    private func onMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    @objc private func presentationOpportunity(_ notification: Notification) {
        presentNextAlertIfPossible()
    }
}
