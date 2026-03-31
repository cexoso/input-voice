import AppKit
import Carbon
import OSLog

private let logger = Logger(subsystem: "com.inputvoice.app", category: "FnKeyMonitor")

// The Fn key on Apple keyboards produces NX_SYSDEFINED events (event type 14).
// We intercept them via CGEvent tap and suppress to prevent the system Emoji Picker.
// Inside the NX_SYSDEFINED event, NSEvent.data1 encodes:
//   bits [31:16] = key number  (3 = NX_KEYTYPE_FN)
//   bits [15:8]  = key state   (0x0a = down, 0x0b = up)
// NSEvent.subtype == 8 identifies AUX_CONTROL_BUTTONS events (which includes Fn).

private let kNXSysDefined: UInt32 = 14

class FnKeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnDown = false

    func start() {
        let eventMask: CGEventMask = CGEventMask(1) << CGEventType.flagsChanged.rawValue

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: fnKeyCallback,
            userInfo: selfPtr
        ) else {
            logger.error("Failed to create CGEvent tap — grant Accessibility access in System Settings")
            return
        }

        self.eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("CGEvent tap created and enabled")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    fileprivate func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let fnDown = flags.contains(.maskSecondaryFn)

        if fnDown && !isFnDown {
            isFnDown = true
            logger.info("Fn key down detected (flagsChanged)")
            onFnDown?()
        } else if !fnDown && isFnDown {
            isFnDown = false
            logger.info("Fn key up detected (flagsChanged)")
            onFnUp?()
        }

        return Unmanaged.passRetained(event)
    }
}

private func fnKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.handleEvent(proxy: proxy, type: type, event: event)
}
