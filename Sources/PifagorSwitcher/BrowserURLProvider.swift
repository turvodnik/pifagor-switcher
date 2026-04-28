import AppKit

@MainActor
final class BrowserURLProvider {
    func currentURL(for app: NSRunningApplication?) -> String? {
        guard let bundleIdentifier = app?.bundleIdentifier else {
            return nil
        }

        switch bundleIdentifier {
        case "com.apple.Safari":
            return runAppleScript("""
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """)
        case "com.google.Chrome", "com.brave.Browser", "company.thebrowser.Browser", "com.microsoft.edgemac":
            return runChromiumScript(applicationName: app?.localizedName)
        case "org.mozilla.firefox":
            return nil
        default:
            return nil
        }
    }

    private func runChromiumScript(applicationName: String?) -> String? {
        guard let applicationName, !applicationName.isEmpty else {
            return nil
        }

        return runAppleScript("""
        tell application "\(applicationName)"
            if (count of windows) is 0 then return ""
            return URL of active tab of front window
        end tell
        """)
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return nil
        }

        let output = script.executeAndReturnError(&error)
        guard error == nil else {
            return nil
        }

        let value = output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
