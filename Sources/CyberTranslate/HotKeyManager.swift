import AppKit
import Carbon.HIToolbox

/// Registers a global hotkey (default ⌥⌘C) that captures the current selection.
///
/// Carbon `RegisterEventHotKey` works system-wide WITHOUT Accessibility permission.
/// Synthesizing ⌘C to copy the live selection DOES need Accessibility — when not granted
/// we fall back to reading whatever is already on the clipboard.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Called on the main thread with the captured text.
    var onCapture: ((String) -> Void)?

    func register(keyCode: UInt32 = UInt32(kVK_ANSI_T),
                  modifiers: UInt32 = UInt32(controlKey | optionKey)) {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { mgr.capture() }
            return noErr
        }, 1, &eventType, selfPtr, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x43594252) /* 'CYBR' */, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let handlerRef { RemoveEventHandler(handlerRef); self.handlerRef = nil }
    }

    /// Capture the current selection (or current clipboard) and forward it.
    private func capture() {
        let pb = NSPasteboard.general
        if AXIsProcessTrusted() {
            let previous = pb.changeCount
            Self.synthesizeCopy()
            // Give the frontmost app a moment to write to the pasteboard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                let text = pb.string(forType: .string) ?? ""
                _ = previous
                self.onCapture?(text)
            }
        } else {
            let text = pb.string(forType: .string) ?? ""
            onCapture?(text)
        }
    }

    /// Post a synthetic ⌘C to the focused application.
    private static func synthesizeCopy() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_C)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Ask the system for Accessibility permission (shows the prompt once).
    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
}

/// Polls the pasteboard so any external ⌘C is auto-imported when enabled.
final class ClipboardWatcher {
    private var timer: Timer?
    private var lastChange = NSPasteboard.general.changeCount
    var enabled = false
    var onChange: ((String) -> Void)?

    func start() {
        lastChange = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self else { return }
            let pb = NSPasteboard.general
            let count = pb.changeCount
            guard count != self.lastChange else { return }
            self.lastChange = count
            guard self.enabled,
                  let s = pb.string(forType: .string),
                  !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            self.onChange?(s)
        }
    }

    func stop() { timer?.invalidate(); timer = nil }
}
