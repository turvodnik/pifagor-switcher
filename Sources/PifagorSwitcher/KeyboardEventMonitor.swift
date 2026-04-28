import AppKit
import Carbon
import QuartzCore

final class KeyboardEventMonitor {
    typealias Handler = @MainActor (TypingController.Event) -> Void

    private let handler: Handler
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastControlTapTime: CFTimeInterval = 0
    private var lastShiftTapTime: CFTimeInterval = 0
    private(set) var lastStartFailure: String?

    var isRunning: Bool {
        guard let eventTap else {
            return false
        }

        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else {
            return true
        }

        guard CGPreflightListenEventAccess() || CGRequestListenEventAccess() else {
            lastStartFailure = "Нет Input Monitoring"
            NSLog("PifagorSwitcher: Input Monitoring permission is missing")
            return false
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<KeyboardEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            monitor.handle(event, type: type)
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            lastStartFailure = "Не удалось создать event tap"
            NSLog("PifagorSwitcher: failed to create keyboard event tap")
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        lastStartFailure = nil
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
    }

    private func handle(_ event: CGEvent, type: CGEventType) {
        if event.getIntegerValueField(.eventSourceUserData) == SyntheticEventMarker.userData {
            return
        }

        if type == .flagsChanged {
            handleFlagsChanged(event)
            return
        }
        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            dispatch(.cursorMoved)
            return
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        if isCursorMovementKey(keyCode) {
            dispatch(.cursorMoved)
            return
        }
        if handleConfiguredHotkey(keyCode: keyCode, flags: event.flags) {
            return
        }
        if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) || event.flags.contains(.maskAlternate) {
            return
        }

        switch keyCode {
        case kVK_Delete:
            dispatch(.backspace)
            return
        case kVK_ForwardDelete:
            dispatch(.cursorMoved)
            return
        case kVK_Return, kVK_ANSI_KeypadEnter:
            dispatch(.enter)
            return
        case kVK_Escape:
            dispatch(.escape)
            return
        case kVK_Space, kVK_Tab:
            dispatch(.wordBoundary(keyCode == kVK_Tab ? "\t" : " "))
            return
        default:
            break
        }

        if let character = event.firstPrintableCharacter {
            if character.isLetter || character.isPunctuationForTyping {
                dispatch(.character(character))
            } else {
                dispatch(.wordBoundary(String(character)))
            }
        }
    }

    private func isCursorMovementKey(_ keyCode: Int) -> Bool {
        keyCode == kVK_LeftArrow
            || keyCode == kVK_RightArrow
            || keyCode == kVK_UpArrow
            || keyCode == kVK_DownArrow
            || keyCode == kVK_Home
            || keyCode == kVK_End
            || keyCode == kVK_PageUp
            || keyCode == kVK_PageDown
    }

    private func dispatch(_ event: TypingController.Event) {
        DispatchQueue.main.async { [handler] in
            handler(event)
        }
    }

    private func handleConfiguredHotkey(keyCode: Int, flags: CGEventFlags) -> Bool {
        let hasControlOption = flags.contains(.maskControl) && flags.contains(.maskAlternate)
        guard hasControlOption else {
            return false
        }

        switch keyCode {
        case kVK_Space:
            dispatch(.manualSwitch)
            return true
        case kVK_ANSI_P:
            dispatch(.toggleEnabled)
            return true
        case kVK_ANSI_C:
            dispatch(.manualCorrectCurrentWord)
            return true
        case kVK_ANSI_Z:
            dispatch(.undoLastCorrection)
            return true
        default:
            return false
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == kVK_Control || keyCode == kVK_RightControl else {
            handleShiftFlagsChanged(event)
            return
        }

        let flags = event.flags
        let controlOnly = flags.contains(.maskControl)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)

        guard controlOnly else {
            return
        }

        let now = CACurrentMediaTime()
        defer { lastControlTapTime = now }

        if now - lastControlTapTime < 0.35 {
            dispatch(.doubleControl)
            lastControlTapTime = 0
        }
    }

    private func handleShiftFlagsChanged(_ event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == kVK_Shift || keyCode == kVK_RightShift else {
            return
        }

        let flags = event.flags
        let shiftOnly = flags.contains(.maskShift)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)

        guard shiftOnly else {
            return
        }

        let now = CACurrentMediaTime()
        defer { lastShiftTapTime = now }

        if now - lastShiftTapTime < 0.35 {
            dispatch(.manualCorrectSelection)
            lastShiftTapTime = 0
        }
    }
}

private extension CGEvent {
    var firstPrintableCharacter: Character? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        guard length > 0, let scalar = UnicodeScalar(chars[0]) else {
            return nil
        }

        return Character(scalar)
    }
}

private extension Character {
    var isLetter: Bool {
        String(self).unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }

    var isPunctuationForTyping: Bool {
        "`[];',./-".contains(self)
    }
}
