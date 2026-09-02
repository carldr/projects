import Carbon
import Foundation

/// A global keyboard shortcut via Carbon RegisterEventHotKey. Needs no
/// permission. Call unregister() before dropping the instance.
@MainActor
final class HotKey {
    private static var handlers: [UInt32: @MainActor () -> Void] = [:]
    private static var handlerInstalled = false
    private static var nextID: UInt32 = 1
    private static let signature: OSType = 0x5052_4A53 // "PRJS"

    private let id: UInt32
    private var ref: EventHotKeyRef?

    init?(combo: KeyCombo, handler: @escaping @MainActor () -> Void) {
        Self.installHandlerIfNeeded()
        id = Self.nextID
        Self.nextID += 1
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.carbonModifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        self.ref = ref
        Self.handlers[id] = handler
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Self.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            MainActor.assumeIsolated {
                HotKey.handlers[hotKeyID.id]?()
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
