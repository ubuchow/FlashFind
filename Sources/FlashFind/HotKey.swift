import AppKit
import Carbon
import Foundation

/// 全局热键（可配置，默认 ⌃⌥Space）
final class HotKey {
    private var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private let signature: OSType = 0x5151_5352 // 'QQSR'
    private let onFire: () -> Void

    private(set) var keyCode: UInt32
    private(set) var carbonModifiers: UInt32

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
        let cfg = HotKeyConfig.load()
        self.keyCode = cfg.keyCode
        self.carbonModifiers = cfg.carbonModifiers
    }

    @discardableResult
    func register() -> Bool {
        unregister()
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            EventHotKeyID(signature: signature, id: 1),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        hotKeyRef = ref
        return status == noErr
    }

    /// 重新绑定快捷键并持久化
    @discardableResult
    func rebind(keyCode: UInt32, carbonModifiers: UInt32, display: String) -> Bool {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        HotKeyConfig(keyCode: keyCode, carbonModifiers: carbonModifiers, display: display).save()
        return register()
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]
        let block: EventHandlerUPP = { _, event, userData in
            guard let userData else { return noErr }
            let hk = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            var id = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            if id.signature == hk.signature {
                DispatchQueue.main.async { hk.onFire() }
            }
            return noErr
        }
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), block, 1, &eventTypes, userData, &handlerRef)
    }

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}

// MARK: - Config

struct HotKeyConfig: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    static let `default` = HotKeyConfig(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(controlKey | optionKey),
        display: "⌃⌥Space"
    )

    static func load() -> HotKeyConfig {
        let d = UserDefaults.standard
        let hasNew = d.object(forKey: "ff.hotkey.keyCode") != nil
        let hasOld = d.object(forKey: "qqs.hotkey.keyCode") != nil
        guard hasNew || hasOld else { return .default }
        let p = hasNew ? "ff.hotkey" : "qqs.hotkey"
        let kc = UInt32(d.integer(forKey: p + ".keyCode"))
        let mod = UInt32(d.integer(forKey: p + ".modifiers"))
        let disp = d.string(forKey: p + ".display") ?? Self.displayString(keyCode: kc, carbon: mod)
        return HotKeyConfig(keyCode: kc, carbonModifiers: mod, display: disp)
    }

    func save() {
        let d = UserDefaults.standard
        d.set(Int(keyCode), forKey: "ff.hotkey.keyCode")
        d.set(Int(carbonModifiers), forKey: "ff.hotkey.modifiers")
        d.set(display, forKey: "ff.hotkey.display")
    }

    /// NSEvent → Carbon modifiers + 展示文案
    static func from(event: NSEvent) -> HotKeyConfig? {
        // 至少要有一个修饰键，避免劫持裸字母
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.isEmpty else { return nil }
        // 忽略纯修饰键
        let kc = UInt32(event.keyCode)
        if kc == UInt32(kVK_Command) || kc == UInt32(kVK_Shift)
            || kc == UInt32(kVK_Option) || kc == UInt32(kVK_Control)
            || kc == UInt32(kVK_RightCommand) || kc == UInt32(kVK_RightShift)
            || kc == UInt32(kVK_RightOption) || kc == UInt32(kVK_RightControl) {
            return nil
        }
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        let display = displayString(keyCode: kc, carbon: carbon)
        return HotKeyConfig(keyCode: kc, carbonModifiers: carbon, display: display)
    }

    static func displayString(keyCode: UInt32, carbon: UInt32) -> String {
        var parts: [String] = []
        if carbon & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbon & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbon & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbon & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(keyCode))
        return parts.joined()
    }

    private static func keyName(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Escape: return "Esc"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default: return "Key\(keyCode)"
        }
    }
}
