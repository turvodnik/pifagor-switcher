import AppKit

@MainActor
final class InputSourceIndicator {
    private let window: NSPanel
    private let label: NSTextField
    private var hideWorkItem: DispatchWorkItem?

    init() {
        label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 170, height: 54),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.78)
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hasShadow = true
        window.contentView = NSView()
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 8
        window.contentView?.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor)
        ])
    }

    func show(text: String) {
        label.stringValue = text
        positionNearTopCenter()
        window.orderFrontRegardless()

        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.window.orderOut(nil)
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: item)
    }

    private func positionNearTopCenter() {
        guard let screen = NSScreen.main else {
            return
        }

        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - window.frame.width / 2,
            y: frame.maxY - window.frame.height - 80
        )
        window.setFrameOrigin(origin)
    }
}
