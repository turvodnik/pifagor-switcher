import AppKit
import ApplicationServices

@MainActor
final class SelectedTextReader {
    func selectedText(in app: NSRunningApplication?) -> String? {
        guard AXIsProcessTrusted(), let focusedElement = focusedElement(in: app) else {
            return nil
        }

        var selectedText: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        ) == .success else {
            return nil
        }

        let text = selectedText as? String
        return text?.isEmpty == false ? text : nil
    }

    private func focusedElement(in app: NSRunningApplication?) -> AXUIElement? {
        guard let app else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success else {
            return nil
        }

        return focusedElement.map { $0 as! AXUIElement }
    }
}
