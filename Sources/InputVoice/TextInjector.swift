import AppKit
import Carbon

class TextInjector {
    func inject(text: String) {
        guard !text.isEmpty else { return }

        // 1. Save original clipboard
        let pasteboard = NSPasteboard.general
        let originalContents = pasteboard.string(forType: .string)

        // 2. Detect current input source
        let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        let sourceID = inputSourceID(currentSource)
        let isCJK = isCJKInputSource(sourceID)
        var switchedToASCII = false

        // 3. If CJK input method, switch to ASCII first
        if isCJK {
            switchedToASCII = switchToASCIIInputSource()
            if switchedToASCII {
                // Wait for input source switch to take effect
                Thread.sleep(forTimeInterval: 0.08)
            }
        }

        // 4. Set clipboard text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 5. Simulate Cmd+V
        simulateCmdV()

        // 6. Restore original clipboard and input source after paste completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let original = originalContents {
                pasteboard.setString(original, forType: .string)
            }
            if switchedToASCII, let source = currentSource {
                TISSelectInputSource(source)
            }
        }
    }

    private func inputSourceID(_ source: TISInputSource?) -> String? {
        guard let source = source else { return nil }
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private func isCJKInputSource(_ sourceID: String?) -> Bool {
        guard let id = sourceID else { return false }
        let cjkPrefixes = [
            "com.apple.inputmethod.SCIM",
            "com.apple.inputmethod.TCIM",
            "com.apple.inputmethod.Japanese",
            "com.apple.inputmethod.Korean",
            "com.apple.inputmethod.ChineseHandwriting",
            "com.apple.inputmethod.Kotoeri",
            "com.sogou",
            "com.baidu",
            "com.tencent",
            "com.iflytek",
        ]
        return cjkPrefixes.contains { id.hasPrefix($0) }
    }

    @discardableResult
    private func switchToASCIIInputSource() -> Bool {
        let asciiIDs: Set<String> = [
            "com.apple.keylayout.ABC",
            "com.apple.keylayout.US",
            "com.apple.keylayout.USExtended",
        ]

        let filter: [String: Any] = [
            kTISPropertyInputSourceIsEnabled as String: true,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]

        guard let cfList = TISCreateInputSourceList(filter as CFDictionary, false) else { return false }
        let list = cfList.takeRetainedValue()
        let count = CFArrayGetCount(list)

        for i in 0..<count {
            let ptr = CFArrayGetValueAtIndex(list, i)!
            let source = Unmanaged<TISInputSource>.fromOpaque(ptr).takeUnretainedValue()
            if let id = inputSourceID(source), asciiIDs.contains(id) {
                TISSelectInputSource(source)
                return true
            }
        }
        return false
    }

    private func simulateCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        // Virtual key 0x09 = 'v'
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
