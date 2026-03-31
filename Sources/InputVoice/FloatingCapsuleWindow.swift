import AppKit

class FloatingCapsuleWindow: NSPanel {
    private let capsuleView = CapsuleContentView()
    private var windowIsShowing = false

    init() {
        let initialWidth: CGFloat = 320
        let height: CGFloat = 56
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - initialWidth / 2
        let y = screenFrame.minY + 40

        let contentRect = NSRect(x: x, y: y, width: initialWidth, height: height)

        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.isMovableByWindowBackground = false

        // Remove title bar
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        contentView = capsuleView
        capsuleView.frame = NSRect(x: 0, y: 0, width: initialWidth, height: height)
    }

    func showWithAnimation() {
        // Position at bottom center of screen
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let currentWidth = frame.width
        let x = screenFrame.midX - currentWidth / 2
        let y = screenFrame.minY + 40

        setFrameOrigin(NSPoint(x: x, y: y))
        alphaValue = 0
        windowIsShowing = true

        // Entry: spring animation — start slightly scaled down
        capsuleView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.85, y: 0.85))
        orderFront(nil)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0) // spring-like
            self.animator().alphaValue = 1.0
        })

        // Layer animation for scale
        let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.85
        scaleAnim.toValue = 1.0
        scaleAnim.mass = 1.0
        scaleAnim.stiffness = 200
        scaleAnim.damping = 20
        scaleAnim.duration = 0.35
        capsuleView.layer?.add(scaleAnim, forKey: "entryScale")
        capsuleView.layer?.setAffineTransform(.identity)
    }

    func hideWithAnimation(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.windowIsShowing = false
            completion()
        })

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.0
        scaleAnim.toValue = 0.88
        scaleAnim.duration = 0.22
        scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        scaleAnim.fillMode = .forwards
        scaleAnim.isRemovedOnCompletion = false
        capsuleView.layer?.add(scaleAnim, forKey: "exitScale")
    }

    func updateText(_ text: String) {
        capsuleView.setText(text)
        adjustWidth()
    }

    func showRefining() {
        capsuleView.setRefining(true)
    }

    func updateRMSLevel(_ level: Float) {
        capsuleView.updateRMSLevel(level)
    }

    private func adjustWidth() {
        let minW: CGFloat = 280
        let maxW: CGFloat = 600
        let textWidth = capsuleView.preferredTextWidth()
        // waveform (64px) + padding (32px) + text + padding
        let needed = 64 + 32 + textWidth + 32
        let newWidth = max(minW, min(maxW, needed))
        let height: CGFloat = 56

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - newWidth / 2
        let y = frame.minY

        let newFrame = NSRect(x: x, y: y, width: newWidth, height: height)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }
}

// MARK: - CapsuleContentView

class CapsuleContentView: NSView {
    private let visualEffect = NSVisualEffectView()
    private let waveformView = WaveformView()
    private let textLabel = NSTextField()
    private var isRefining = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 28
        layer?.masksToBounds = true

        // Visual effect background
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 28
        visualEffect.layer?.masksToBounds = true
        addSubview(visualEffect)

        // Waveform
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(waveformView)

        // Text label
        textLabel.isEditable = false
        textLabel.isBordered = false
        textLabel.drawsBackground = false
        textLabel.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textLabel.textColor = NSColor.labelColor
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.cell?.usesSingleLineMode = true
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textLabel)

        NSLayoutConstraint.activate([
            waveformView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            waveformView.centerYAnchor.constraint(equalTo: centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 44),
            waveformView.heightAnchor.constraint(equalToConstant: 32),

            textLabel.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func layout() {
        super.layout()
        visualEffect.frame = bounds
    }

    func setText(_ text: String) {
        isRefining = false
        textLabel.stringValue = text.isEmpty ? "Listening..." : text
        textLabel.textColor = text.isEmpty ? NSColor.tertiaryLabelColor : NSColor.labelColor
    }

    func setRefining(_ refining: Bool) {
        isRefining = refining
        if refining {
            textLabel.stringValue = "Refining..."
            textLabel.textColor = NSColor.secondaryLabelColor
        }
    }

    func updateRMSLevel(_ level: Float) {
        waveformView.updateLevel(level)
    }

    func preferredTextWidth() -> CGFloat {
        let text = textLabel.stringValue
        let font = textLabel.font ?? NSFont.systemFont(ofSize: 15)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attrs)
        return max(160, min(560, size.width + 8))
    }
}

// MARK: - WaveformView

class WaveformView: NSView {
    // 5 bars with center-high, sides-low weight profile
    private let barWeights: [Float] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var smoothedLevels: [Float] = [0, 0, 0, 0, 0]
    private var currentRMS: Float = 0
    private var displayLink: CVDisplayLink?
    private var jitterSeeds: [Float] = [0, 0, 0, 0, 0]

    // Envelope constants
    private let attackCoeff: Float = 0.40
    private let releaseCoeff: Float = 0.15

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Use a display link for smooth animation
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        if let dl = displayLink {
            let selfPtr = Unmanaged.passRetained(self).toOpaque()
            CVDisplayLinkSetOutputCallback(dl, { _, _, _, _, _, userInfo -> CVReturn in
                let view = Unmanaged<WaveformView>.fromOpaque(userInfo!).takeUnretainedValue()
                view.updateAnimation()
                return kCVReturnSuccess
            }, selfPtr)
            CVDisplayLinkStart(dl)
        }
    }

    deinit {
        if let dl = displayLink {
            CVDisplayLinkStop(dl)
        }
    }

    func updateLevel(_ level: Float) {
        currentRMS = level
    }

    private func updateAnimation() {
        var needsRedraw = false
        for i in 0..<5 {
            let target = currentRMS * barWeights[i]
            let prev = smoothedLevels[i]
            let newVal: Float
            if target > prev {
                newVal = prev + (target - prev) * attackCoeff
            } else {
                newVal = prev + (target - prev) * releaseCoeff
            }
            if abs(newVal - prev) > 0.001 {
                needsRedraw = true
            }
            smoothedLevels[i] = newVal
            // Update jitter seed
            jitterSeeds[i] = Float.random(in: -0.04...0.04)
        }

        if needsRedraw || currentRMS > 0.01 {
            DispatchQueue.main.async { [weak self] in
                self?.needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let totalBars = 5
        let barWidth: CGFloat = 4
        let spacing: CGFloat = (bounds.width - barWidth * CGFloat(totalBars)) / CGFloat(totalBars + 1)
        let minBarHeight: CGFloat = 4
        let maxBarHeight: CGFloat = bounds.height - 4

        // Use white/label color based on appearance
        let color = NSColor.white.withAlphaComponent(0.9)
        ctx.setFillColor(color.cgColor)

        for i in 0..<totalBars {
            let rawLevel = smoothedLevels[i]
            let jittered = max(0, min(1, rawLevel + jitterSeeds[i]))
            let barHeight = minBarHeight + CGFloat(jittered) * (maxBarHeight - minBarHeight)
            let x = spacing + CGFloat(i) * (barWidth + spacing)
            let y = (bounds.height - barHeight) / 2
            let rect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            color.setFill()
            path.fill()
        }
    }
}
