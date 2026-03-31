import AppKit
import Carbon

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
        // Build event mask: NX_SYSDEFINED | flagsChanged
        // NX_SYSDEFINED = 14, so bit = (1 << 14)
        let sysDefinedBit: CGEventMask = CGEventMask(1) << kNXSysDefined
        let flagsChangedBit: CGEventMask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        let eventMask: CGEventMask = sysDefinedBit | flagsChangedBit

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: fnKeyCallback,
            userInfo: selfPtr
        ) else {
            print("[FnKeyMonitor] Failed to create CGEvent tap – grant Accessibility access in System Settings.")
            return
        }

        self.eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
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
        guard type.rawValue == kNXSysDefined else {
            return Unmanaged.passRetained(event)
        }

        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passRetained(event)
        }

        // subtype 8 = NX_SUBTYPE_AUX_CONTROL_BUTTONS (Fn, brightness, volume keys)
        guard nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16   // key number
        let keyState = (data1 & 0x0000_FF00) >> 8    // 0x0a = down, 0x0b = up

        // NX_KEYTYPE_FN = 3
        guard keyCode == 3 else {
            return Unmanaged.passRetained(event)
        }

        if keyState == 0x0a && !isFnDown {
            isFnDown = true
            onFnDown?()
        } else if keyState == 0x0b && isFnDown {
            isFnDown = false
            onFnUp?()
        }

        // Suppress the event to prevent Emoji Picker from appearing
        return nil
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
