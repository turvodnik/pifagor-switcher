import AppKit

final class TextReplayer {
    func replaceLastWord(currentWordLength: Int, replacement: String) {
        replaceText(characterCount: currentWordLength, replacement: replacement)
    }

    func replaceText(characterCount: Int, replacement: String) {
        guard characterCount > 0 else {
            return
        }

        for _ in 0..<characterCount {
            postKey(keyCode: 51)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.paste(replacement)
        }
    }

    func replaceSelection(with replacement: String) {
        paste(replacement)
    }

    private func postKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.userData)
        up?.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.userData)
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let oldItems = PasteboardSnapshot(items: pasteboard.pasteboardItems ?? [])

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.postCommandV()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            pasteboard.clearContents()
            pasteboard.writeObjects(oldItems.items)
        }
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeForV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        down?.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.userData)
        up?.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.userData)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}

private struct PasteboardSnapshot {
    let items: [NSPasteboardItem]

    init(items sourceItems: [NSPasteboardItem]) {
        self.items = sourceItems.map { sourceItem in
            let snapshotItem = NSPasteboardItem()
            for type in sourceItem.types {
                if let data = sourceItem.data(forType: type) {
                    snapshotItem.setData(data, forType: type)
                } else if let string = sourceItem.string(forType: type) {
                    snapshotItem.setString(string, forType: type)
                }
            }
            return snapshotItem
        }
    }
}
