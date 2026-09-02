import Carbon
import Foundation
import os

/// A global keyboard shortcut via Carbon RegisterEventHotKey. Needs no
/// permission. Call unregister() before dropping the instance.
@MainActor
final class HotKey {
    private static let log = Logger(subsystem: "uk.co.29degrees.projects", category: "HotKey")
    private static var handlers: [UInt32: @MainActor () -> Void] = [:]
    private static var handlerInstalled = false
    private static var nextID: UInt32 = 1
    private static let signature: OSType = 0x5052_4A53 // "PRJS"

    private let id: UInt32
    private var ref: EventHotKeyRef?

    init?(combo: KeyCombo, handler: @escaping @MainActor () -> Void) {
        let installStatus = Self.installHandlerIfNeeded()
        guard installStatus == noErr else {
            Self.log.error("InstallEventHandler failed with status \(installStatus, privacy: .public)")
            return nil
        }
        id = Self.nextID
        Self.nextID += 1
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.carbonModifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Self.log.error("RegisterEventHotKey failed with status \(status, privacy: .public)")
            return nil
        }
        self.ref = ref
        Self.handlers[id] = handler
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Self.handlers[id] = nil
    }

    /// noErr when the shared Carbon handler is installed, already or now.
    private static func installHandlerIfNeeded() -> OSStatus {
        guard !handlerInstalled else { return noErr }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            MainActor.assumeIsolated {
                HotKey.handlers[hotKeyID.id]?()
            }
            return noErr
        }, 1, &spec, nil, nil)
        if status == noErr { handlerInstalled = true }
        return status
    }
}
