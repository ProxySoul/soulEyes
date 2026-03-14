import Cocoa

// ─── SoulEyes — 20-20-20 Rule by proxySoul ───
// Every 20 minutes: fullscreen overlay → look 20ft away for 20 seconds → dismiss
// Menu bar shows live countdown. Overlay has animations, particles, glow effects.

// MARK: - Colors

struct SoulColors {
    static let purple     = NSColor(red: 0.68, green: 0.51, blue: 1.0, alpha: 1.0)
    static let purpleDim  = NSColor(red: 0.68, green: 0.51, blue: 1.0, alpha: 0.3)
    static let purpleGlow = NSColor(red: 0.68, green: 0.51, blue: 1.0, alpha: 0.15)
    static let bg         = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.96)
    static let text       = NSColor(red: 0.78, green: 0.78, blue: 0.82, alpha: 1.0)
    static let textDim    = NSColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1.0)
    static let ring       = NSColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0)
    static let green      = NSColor(red: 0.30, green: 0.85, blue: 0.55, alpha: 1.0)
}

// MARK: - SF Symbol Helpers

func sfIcon(_ name: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor? = nil) -> NSImage? {
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
    let configured = img.withSymbolConfiguration(config) ?? img
    if let color = color {
        let tinted = configured.copy() as! NSImage
        tinted.lockFocus()
        color.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        return tinted
    }
    return configured
}

func sfAttachment(_ name: String, size: CGFloat, weight: NSFont.Weight = .medium, color: NSColor, baseline: CGFloat = -2) -> NSAttributedString {
    guard let img = sfIcon(name, size: size, weight: weight, color: color) else {
        return NSAttributedString(string: "")
    }
    let attachment = NSTextAttachment()
    attachment.image = img
    let h = img.size.height
    let w = img.size.width
    attachment.bounds = CGRect(x: 0, y: baseline, width: w, height: h)
    return NSAttributedString(attachment: attachment)
}

// MARK: - Clickable View (replaces NSButton for full-rect hit area)

class ClickableView: NSView {
    var onClick: (() -> Void)?
    var muteMinutes: Int = 0
    private var isPressed = false
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.animator().alphaValue = 0.85
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        if !isPressed {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self.animator().alphaValue = 1.0
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            self.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.95, y: 0.95))
        }
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            self.layer?.setAffineTransform(.identity)
            self.animator().alphaValue = self.isHovering ? 0.85 : 1.0
        }) {
            let loc = self.convert(event.locationInWindow, from: nil)
            if self.bounds.contains(loc) {
                self.onClick?()
            }
        }
    }

    // Convenience: add a centered text label
    func setLabel(_ text: String, font: NSFont, color: NSColor) {
        subviews.filter { $0 is NSTextField }.forEach { $0.removeFromSuperview() }
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // Convenience: add icon + text (like the start button)
    func setIconLabel(icon: NSImage?, text: String, font: NSFont, color: NSColor, spacing: CGFloat = 6) {
        subviews.forEach { $0.removeFromSuperview() }
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = spacing
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        if let icon = icon {
            let iv = NSImageView(image: icon)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(iv)
        }
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        stack.addArrangedSubview(label)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

// MARK: - Floating Particle View

class ParticleView: NSView {
    struct Particle {
        var x, y, vx, vy, radius, alpha, pulseSpeed, pulsePhase: CGFloat
    }
    var particles: [Particle] = []
    var displayLink: CVDisplayLink?
    var lastTime: CFTimeInterval = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        seedParticles(count: 35)
        startAnimation()
    }
    required init?(coder: NSCoder) { fatalError() }

    func seedParticles(count: Int) {
        particles = (0..<count).map { _ in
            Particle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                vx: CGFloat.random(in: -0.008...0.008),
                vy: CGFloat.random(in: 0.005...0.02),
                radius: CGFloat.random(in: 1.5...4.0),
                alpha: CGFloat.random(in: 0.08...0.3),
                pulseSpeed: CGFloat.random(in: 0.5...2.0),
                pulsePhase: CGFloat.random(in: 0...6.28)
            )
        }
    }

    func startAnimation() {
        let timer = Timer(timeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func tick() {
        for i in 0..<particles.count {
            particles[i].x += particles[i].vx * 0.01
            particles[i].y += particles[i].vy * 0.01
            particles[i].pulsePhase += particles[i].pulseSpeed * 0.03
            // Wrap around
            if particles[i].y > 1.15 { particles[i].y = -0.05 }
            if particles[i].y < -0.1 { particles[i].y = 1.05 }
            if particles[i].x > 1.1 { particles[i].x = -0.05 }
            if particles[i].x < -0.1 { particles[i].x = 1.05 }
        }
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width, h = bounds.height

        for p in particles {
            let pulse = (1.0 + sin(p.pulsePhase)) * 0.5 // 0..1
            let a = p.alpha * (0.5 + pulse * 0.5)
            let r = p.radius * (0.8 + pulse * 0.4)
            let cx = p.x * w, cy = p.y * h

            // Glow
            ctx.setFillColor(SoulColors.purple.withAlphaComponent(a * 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - r * 3, y: cy - r * 3, width: r * 6, height: r * 6))
            // Core
            ctx.setFillColor(SoulColors.purple.withAlphaComponent(a).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
    }

    func stopAnimation() {
        // Timers auto-invalidate when view is removed
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var workTimer: Timer?
    var tickTimer: Timer?          // 1-second tick for menu bar countdown
    var countdownTimer: Timer?
    var overlayWindow: NSWindow?
    var breakCountdownSeconds = 20
    var workIntervalTotal = 20 * 60  // 20 minutes
    var workSecondsLeft = 20 * 60
    var isPaused = false
    var isOnBreak = false
    var isMuted = false
    var muteSecondsLeft = 0
    var muteTimer: Timer?

    // Overlay UI refs
    var countdownLabel: NSTextField?
    var startButton: ClickableView?
    var skipButton: ClickableView?
    var snoozeContainer: NSView?
    var messageLabel: NSTextField?
    var subtitleLabel: NSTextField?
    var progressLayer: CAShapeLayer?
    var glowLayer: CAShapeLayer?
    var particleView: ParticleView?
    var logoLabel: NSTextField?
    var escMonitor: Any?

    // Completion flash
    var completionLabel: NSTextField?

    var isSuspended = false  // true when screen locked or system sleeping

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        registerSleepLockNotifications()
        startWorkCycle()
    }

    // MARK: - Sleep / Lock Detection

    func registerSleepLockNotifications() {
        let dnc = DistributedNotificationCenter.default()
        let wsnc = NSWorkspace.shared.notificationCenter

        // Screen lock / unlock
        dnc.addObserver(self, selector: #selector(onScreenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(onScreenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)

        // System sleep / wake
        wsnc.addObserver(self, selector: #selector(onSystemSleep), name: NSWorkspace.willSleepNotification, object: nil)
        wsnc.addObserver(self, selector: #selector(onSystemWake), name: NSWorkspace.didWakeNotification, object: nil)

        // Screen saver
        dnc.addObserver(self, selector: #selector(onScreenLocked), name: NSNotification.Name("com.apple.screensaver.didstart"), object: nil)
        dnc.addObserver(self, selector: #selector(onScreenUnlocked), name: NSNotification.Name("com.apple.screensaver.didstop"), object: nil)
    }

    @objc func onScreenLocked() {
        suspend(reason: "locked")
    }

    @objc func onSystemSleep() {
        suspend(reason: "sleep")
    }

    @objc func onScreenUnlocked() {
        resume()
    }

    @objc func onSystemWake() {
        // Small delay — screen may still be locked after wake
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.isSuspended else { return }
            self.resume()
        }
    }

    func suspend(reason: String) {
        guard !isSuspended else { return }
        isSuspended = true

        // Kill all timers
        tickTimer?.invalidate()
        tickTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        muteTimer?.invalidate()
        muteTimer = nil
        isMuted = false
        muteSecondsLeft = 0

        // Dismiss overlay if showing
        if overlayWindow != nil {
            forceCloseOverlay()
        }

        if let button = statusItem.button {
            button.image = sfIcon("moon.zzz.fill", size: 14, weight: .semibold)
            button.image?.isTemplate = true
            button.attributedTitle = menuBarTime("")
        }
    }

    func resume() {
        guard isSuspended else { return }
        isSuspended = false
        // Full reset — fresh 20 min cycle
        startWorkCycle()
    }

    /// Close overlay without fade animation (for sleep/lock)
    func forceCloseOverlay() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
        particleView = nil
        progressLayer = nil
        glowLayer = nil
        countdownLabel = nil
        startButton = nil
        skipButton = nil
        snoozeContainer = nil
        messageLabel = nil
        subtitleLabel = nil
        completionLabel = nil
        logoLabel = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        isOnBreak = false
    }

    // MARK: - Menu Bar with Live Countdown

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = sfIcon("eye.fill", size: 14, weight: .semibold)
            button.image?.isTemplate = true  // adapts to light/dark menu bar
            button.imagePosition = .imageLeading
        }
        updateMenuBarTitle()
        updateMenu()
    }

    // Rebuild menu every time it opens so countdown is fresh
    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }

    func updateMenuBarTitle() {
        guard let button = statusItem.button else { return }
        if isMuted {
            let m = muteSecondsLeft / 60
            let s = muteSecondsLeft % 60
            button.image = sfIcon("eye.slash.fill", size: 14, weight: .semibold)
            button.image?.isTemplate = true
            button.attributedTitle = menuBarTime(String(format: "%d:%02d", m, s))
        } else if isPaused {
            button.image = sfIcon("eye.slash", size: 14, weight: .semibold)
            button.image?.isTemplate = true
            button.attributedTitle = menuBarTime("paused")
        } else if isOnBreak {
            button.image = sfIcon("eye.fill", size: 14, weight: .semibold)
            button.image?.isTemplate = true
            button.attributedTitle = menuBarTime("break")
        } else if isSuspended {
            button.image = sfIcon("moon.zzz.fill", size: 14, weight: .semibold)
            button.image?.isTemplate = true
            button.attributedTitle = menuBarTime("")
        } else {
            let m = workSecondsLeft / 60
            let s = workSecondsLeft % 60
            button.image = sfIcon("eye.fill", size: 14, weight: .semibold)
            button.image?.isTemplate = true
            button.attributedTitle = menuBarTime(String(format: "%d:%02d", m, s))
        }
    }

    func menuBarTime(_ text: String) -> NSAttributedString {
        if text.isEmpty { return NSAttributedString(string: "") }
        return NSAttributedString(string: " \(text)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.controlTextColor.withAlphaComponent(0.85)
        ])
    }

    func updateMenu() {
        let menu = NSMenu()

        // Header with SF Symbol
        let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let headerStr = NSMutableAttributedString()
        headerStr.append(sfAttachment("eye.fill", size: 12, weight: .semibold, color: SoulColors.purple, baseline: -1))
        headerStr.append(NSAttributedString(string: "  SoulEyes — 20·20·20", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: SoulColors.purple
        ]))
        header.attributedTitle = headerStr
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        // Timer status with SF icons
        let statusStr = NSMutableAttributedString()
        if isMuted {
            let m = muteSecondsLeft / 60
            let s = muteSecondsLeft % 60
            statusStr.append(sfAttachment("speaker.slash.fill", size: 11, color: NSColor.systemOrange, baseline: -1))
            statusStr.append(NSAttributedString(string: String(format: "  Muted — %d:%02d remaining", m, s), attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.systemOrange.withAlphaComponent(0.85)
            ]))
        } else if isPaused {
            statusStr.append(sfAttachment("pause.circle.fill", size: 11, color: .secondaryLabelColor, baseline: -1))
            statusStr.append(NSAttributedString(string: "  Paused", attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        } else if isOnBreak {
            statusStr.append(sfAttachment("eye.trianglebadge.exclamationmark", size: 11, color: SoulColors.green, baseline: -1))
            statusStr.append(NSAttributedString(string: "  On break — look away!", attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: SoulColors.green
            ]))
        } else {
            let m = workSecondsLeft / 60
            let s = workSecondsLeft % 60
            statusStr.append(sfAttachment("timer", size: 11, color: .secondaryLabelColor, baseline: -1))
            statusStr.append(NSAttributedString(string: String(format: "  Next break in %d:%02d", m, s), attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        }
        let statusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusItem.attributedTitle = statusStr
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())

        if isMuted {
            menu.addItem(makeSFMenuItem("speaker.wave.2.fill", title: "Unmute", action: #selector(unmute), key: "u", color: .controlTextColor))
        } else {
            if isPaused {
                menu.addItem(makeSFMenuItem("play.fill", title: "Resume", action: #selector(resumeTimer), key: "r", color: .controlTextColor))
            } else {
                menu.addItem(makeSFMenuItem("pause.fill", title: "Pause", action: #selector(pauseTimer), key: "p", color: .controlTextColor))
            }
            menu.addItem(makeSFMenuItem("forward.fill", title: "Break Now", action: #selector(triggerBreakNow), key: "b", color: .controlTextColor))
            menu.addItem(NSMenuItem.separator())

            // Mute submenu
            let muteItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            let muteStr = NSMutableAttributedString()
            muteStr.append(sfAttachment("speaker.slash.fill", size: 11, color: .controlTextColor, baseline: -1))
            muteStr.append(NSAttributedString(string: "  Mute", attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.controlTextColor
            ]))
            muteItem.attributedTitle = muteStr
            let muteSub = NSMenu()
            muteSub.addItem(makeMuteItem("5 minutes", minutes: 5))
            muteSub.addItem(makeMuteItem("10 minutes", minutes: 10))
            muteSub.addItem(makeMuteItem("30 minutes", minutes: 30))
            muteSub.addItem(makeMuteItem("1 hour", minutes: 60))
            muteItem.submenu = muteSub
            menu.addItem(muteItem)
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeSFMenuItem("globe", title: "proxysoul.com", action: #selector(openWebsite), key: "", color: .secondaryLabelColor))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeSFMenuItem("xmark.circle", title: "Quit SoulEyes", action: #selector(quitApp), key: "q", color: .secondaryLabelColor))

        menu.delegate = self
        self.statusItem.menu = menu
    }

    func makeSFMenuItem(_ symbol: String, title: String, action: Selector, key: String, color: NSColor) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let img = sfIcon(symbol, size: 13, weight: .medium) {
            img.isTemplate = true
            item.image = img
        }
        return item
    }

    func makeMenuItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func makeMuteItem(_ title: String, minutes: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(muteFromMenu(_:)), keyEquivalent: "")
        item.target = self
        item.tag = minutes
        return item
    }

    // MARK: - Mute

    @objc func muteFromMenu(_ sender: NSMenuItem) {
        startMute(minutes: sender.tag)
    }

    func startMute(minutes: Int) {
        // Dismiss overlay if open
        if overlayWindow != nil {
            forceCloseOverlay()
        }

        // Stop work cycle
        tickTimer?.invalidate()
        tickTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil

        isMuted = true
        isOnBreak = false
        isPaused = false
        muteSecondsLeft = minutes * 60
        updateMenuBarTitle()
        updateMenu()

        // Mute countdown timer
        muteTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.muteSecondsLeft -= 1
            self.updateMenuBarTitle()

            if self.muteSecondsLeft <= 0 {
                self.muteTimer?.invalidate()
                self.muteTimer = nil
                self.isMuted = false
                self.startWorkCycle()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        muteTimer = timer
    }

    @objc func unmute() {
        muteTimer?.invalidate()
        muteTimer = nil
        isMuted = false
        muteSecondsLeft = 0
        startWorkCycle()
    }

    // MARK: - Work Cycle (20 min countdown in menu bar)

    func startWorkCycle() {
        workSecondsLeft = workIntervalTotal
        isOnBreak = false
        isPaused = false
        updateMenuBarTitle()
        updateMenu()

        // Tick every second to update menu bar
        tickTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused, !self.isOnBreak else { return }
            self.workSecondsLeft -= 1
            self.updateMenuBarTitle()

            if self.workSecondsLeft <= 0 {
                self.tickTimer?.invalidate()
                self.tickTimer = nil
                self.showOverlay()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    @objc func pauseTimer() {
        isPaused = true
        updateMenuBarTitle()
        updateMenu()
    }

    @objc func resumeTimer() {
        isPaused = false
        updateMenuBarTitle()
        updateMenu()
    }

    @objc func triggerBreakNow() {
        tickTimer?.invalidate()
        tickTimer = nil
        showOverlay()
    }

    @objc func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://proxysoul.com")!)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Fullscreen Overlay (Animated)

    func showOverlay() {
        isOnBreak = true
        updateMenuBarTitle()
        updateMenu()

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.alphaValue = 0 // start invisible for fade-in

        let contentView = NSView(frame: frame)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = SoulColors.bg.cgColor
        window.contentView = contentView

        // ── Particle background ──
        let pv = ParticleView(frame: frame)
        pv.autoresizingMask = [.width, .height]
        contentView.addSubview(pv)
        particleView = pv

        // ── Container ──
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 580))
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10),
            container.widthAnchor.constraint(equalToConstant: 520),
            container.heightAnchor.constraint(equalToConstant: 580)
        ])

        // ── Eye icon (SF Symbol) ──
        let logoView = NSImageView(frame: .zero)
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.image = sfIcon("eye.fill", size: 56, weight: .light, color: SoulColors.purple)
        logoView.wantsLayer = true
        // Glow behind the eye
        logoView.layer?.shadowColor = SoulColors.purple.cgColor
        logoView.layer?.shadowRadius = 24
        logoView.layer?.shadowOpacity = 0.6
        logoView.layer?.shadowOffset = .zero
        container.addSubview(logoView)
        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            logoView.topAnchor.constraint(equalTo: container.topAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 80),
            logoView.heightAnchor.constraint(equalToConstant: 80)
        ])
        logoLabel = nil  // no longer a text field

        // ── Title ──
        let title = makeLabel(text: "SoulEyes", size: 40, color: SoulColors.purple, weight: .heavy)
        title.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(title)
        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            title.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 6)
        ])

        // ── Message ──
        let msg = makeLabel(text: "Time for an eye break", size: 21, color: SoulColors.text, weight: .medium)
        msg.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(msg)
        NSLayoutConstraint.activate([
            msg.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            msg.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10)
        ])
        messageLabel = msg

        // ── Subtitle ──
        let sub = makeLabel(text: "Look at something 20 feet away for 20 seconds", size: 14, color: SoulColors.textDim, weight: .regular)
        sub.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sub)
        NSLayoutConstraint.activate([
            sub.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            sub.topAnchor.constraint(equalTo: msg.bottomAnchor, constant: 4)
        ])
        subtitleLabel = sub

        // ── Ring container ──
        let ringSize: CGFloat = 170
        let ringView = NSView(frame: NSRect(x: 0, y: 0, width: ringSize, height: ringSize))
        ringView.translatesAutoresizingMaskIntoConstraints = false
        ringView.wantsLayer = true
        container.addSubview(ringView)
        NSLayoutConstraint.activate([
            ringView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ringView.topAnchor.constraint(equalTo: sub.bottomAnchor, constant: 28),
            ringView.widthAnchor.constraint(equalToConstant: ringSize),
            ringView.heightAnchor.constraint(equalToConstant: ringSize)
        ])

        let center = CGPoint(x: ringSize / 2, y: ringSize / 2)
        let radius: CGFloat = 72

        // Outer glow ring
        let glow = CAShapeLayer()
        let glowPath = NSBezierPath()
        glowPath.appendArc(withCenter: center, radius: radius + 4, startAngle: 0, endAngle: 360)
        glow.path = glowPath.cgPath
        glow.fillColor = nil
        glow.strokeColor = SoulColors.purpleGlow.cgColor
        glow.lineWidth = 16
        ringView.layer?.addSublayer(glow)
        glowLayer = glow

        // Background ring
        let bgRing = CAShapeLayer()
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        bgRing.path = bgPath.cgPath
        bgRing.fillColor = nil
        bgRing.strokeColor = SoulColors.ring.cgColor
        bgRing.lineWidth = 7
        ringView.layer?.addSublayer(bgRing)

        // Progress ring
        let progress = CAShapeLayer()
        let circlePath = NSBezierPath()
        circlePath.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360, clockwise: true)
        progress.path = circlePath.cgPath
        progress.fillColor = nil
        progress.strokeColor = SoulColors.purple.cgColor
        progress.lineWidth = 7
        progress.lineCap = .round
        progress.strokeEnd = 0
        // Shadow on progress ring
        progress.shadowColor = SoulColors.purple.cgColor
        progress.shadowRadius = 10
        progress.shadowOpacity = 0.6
        progress.shadowOffset = .zero
        ringView.layer?.addSublayer(progress)
        progressLayer = progress

        // Countdown inside ring
        let countdown = makeLabel(text: "20", size: 50, color: .white, weight: .bold)
        countdown.translatesAutoresizingMaskIntoConstraints = false
        ringView.addSubview(countdown)
        NSLayoutConstraint.activate([
            countdown.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            countdown.centerYAnchor.constraint(equalTo: ringView.centerYAnchor, constant: 2)
        ])
        countdownLabel = countdown

        // "sec" label under number
        let secLabel = makeLabel(text: "sec", size: 12, color: SoulColors.textDim, weight: .medium)
        secLabel.translatesAutoresizingMaskIntoConstraints = false
        ringView.addSubview(secLabel)
        NSLayoutConstraint.activate([
            secLabel.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            secLabel.topAnchor.constraint(equalTo: countdown.bottomAnchor, constant: -4)
        ])

        // ── Start button (pill shape with glow) ──
        let btn = ClickableView(frame: .zero)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.wantsLayer = true
        btn.layer?.backgroundColor = SoulColors.purple.cgColor
        btn.layer?.cornerRadius = 24
        btn.layer?.shadowColor = SoulColors.purple.cgColor
        btn.layer?.shadowRadius = 16
        btn.layer?.shadowOpacity = 0.5
        btn.layer?.shadowOffset = .zero
        let playIcon = sfIcon("play.fill", size: 14, weight: .bold, color: .white)
        btn.setIconLabel(icon: playIcon, text: "Start Break", font: NSFont.systemFont(ofSize: 17, weight: .semibold), color: .white)
        btn.onClick = { [weak self] in self?.startCountdown() }
        container.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            btn.topAnchor.constraint(equalTo: ringView.bottomAnchor, constant: 28),
            btn.widthAnchor.constraint(equalToConstant: 210),
            btn.heightAnchor.constraint(equalToConstant: 48)
        ])
        startButton = btn

        // Button pulse animation
        let pulse = CABasicAnimation(keyPath: "shadowRadius")
        pulse.fromValue = 10
        pulse.toValue = 25
        pulse.duration = 1.5
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        btn.layer?.add(pulse, forKey: "pulse")

        // ── Skip button (below start) ──
        let skip = makeGhostButton(title: "Skip") { [weak self] in self?.skipBreak() }
        container.addSubview(skip)
        NSLayoutConstraint.activate([
            skip.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            skip.topAnchor.constraint(equalTo: btn.bottomAnchor, constant: 12),
            skip.widthAnchor.constraint(equalToConstant: 100),
            skip.heightAnchor.constraint(equalToConstant: 32)
        ])
        skipButton = skip

        // ── Snooze row (below skip) ──
        let snoozeRow = NSView(frame: .zero)
        snoozeRow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(snoozeRow)
        NSLayoutConstraint.activate([
            snoozeRow.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            snoozeRow.topAnchor.constraint(equalTo: skip.bottomAnchor, constant: 14),
            snoozeRow.heightAnchor.constraint(equalToConstant: 32)
        ])
        snoozeContainer = snoozeRow

        let snoozeLabel = makeLabel(text: "Mute for:", size: 12, color: SoulColors.textDim, weight: .medium)
        snoozeLabel.translatesAutoresizingMaskIntoConstraints = false
        snoozeRow.addSubview(snoozeLabel)

        let s5  = makeSnoozeButton(title: "5m",  tag: 5)
        let s10 = makeSnoozeButton(title: "10m", tag: 10)
        let s30 = makeSnoozeButton(title: "30m", tag: 30)
        snoozeRow.addSubview(s5)
        snoozeRow.addSubview(s10)
        snoozeRow.addSubview(s30)

        NSLayoutConstraint.activate([
            snoozeLabel.leadingAnchor.constraint(equalTo: snoozeRow.leadingAnchor),
            snoozeLabel.centerYAnchor.constraint(equalTo: snoozeRow.centerYAnchor),
            s5.leadingAnchor.constraint(equalTo: snoozeLabel.trailingAnchor, constant: 10),
            s5.centerYAnchor.constraint(equalTo: snoozeRow.centerYAnchor),
            s5.widthAnchor.constraint(equalToConstant: 48),
            s5.heightAnchor.constraint(equalToConstant: 28),
            s10.leadingAnchor.constraint(equalTo: s5.trailingAnchor, constant: 8),
            s10.centerYAnchor.constraint(equalTo: snoozeRow.centerYAnchor),
            s10.widthAnchor.constraint(equalToConstant: 48),
            s10.heightAnchor.constraint(equalToConstant: 28),
            s30.leadingAnchor.constraint(equalTo: s10.trailingAnchor, constant: 8),
            s30.centerYAnchor.constraint(equalTo: snoozeRow.centerYAnchor),
            s30.widthAnchor.constraint(equalToConstant: 48),
            s30.heightAnchor.constraint(equalToConstant: 28),
            s30.trailingAnchor.constraint(equalTo: snoozeRow.trailingAnchor),
        ])

        // ── Branding ──
        let brand = makeLabel(text: "proxysoul.com  ·  SoulForge", size: 11, color: SoulColors.textDim.withAlphaComponent(0.5), weight: .regular)
        brand.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(brand)
        NSLayoutConstraint.activate([
            brand.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            brand.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])

        // ── Esc hint ──
        let escStr = NSMutableAttributedString()
        escStr.append(sfAttachment("escape", size: 9, weight: .medium, color: SoulColors.textDim.withAlphaComponent(0.4), baseline: -1))
        escStr.append(NSAttributedString(string: " to skip", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: SoulColors.textDim.withAlphaComponent(0.4)
        ]))
        let esc = NSTextField(labelWithAttributedString: escStr)
        esc.backgroundColor = .clear
        esc.isBezeled = false
        esc.isEditable = false
        esc.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(esc)
        NSLayoutConstraint.activate([
            esc.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            esc.bottomAnchor.constraint(equalTo: brand.topAnchor, constant: -4)
        ])

        // ── Completion label (hidden initially) ──
        let done = makeLabel(text: "Eyes refreshed!", size: 24, color: SoulColors.green, weight: .semibold)
        done.translatesAutoresizingMaskIntoConstraints = false
        done.alphaValue = 0
        container.addSubview(done)
        NSLayoutConstraint.activate([
            done.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            done.topAnchor.constraint(equalTo: ringView.bottomAnchor, constant: 34)
        ])
        completionLabel = done

        // Store & show window
        overlayWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // ── Fade-in animation ──
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        })

        // ── Slide-up container ──
        container.alphaValue = 0
        container.frame = container.frame.offsetBy(dx: 0, dy: -30)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.6
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            container.animator().alphaValue = 1.0
            container.animator().frame = container.frame.offsetBy(dx: 0, dy: 30)
        })

        // ── Breathing glow on ring ──
        let glowPulse = CABasicAnimation(keyPath: "opacity")
        glowPulse.fromValue = 0.3
        glowPulse.toValue = 0.8
        glowPulse.duration = 2.0
        glowPulse.autoreverses = true
        glowPulse.repeatCount = .infinity
        glowPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glow.add(glowPulse, forKey: "breathe")

        // ── Logo gentle bob ──
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = 0
        bob.toValue = -8
        bob.duration = 2.5
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        logoView.layer?.add(bob, forKey: "bob")

        // ESC key monitor
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismissOverlay()
                return nil
            }
            return event
        }

        breakCountdownSeconds = 20
    }

    // MARK: - Break Countdown (20 seconds)

    @objc func startCountdown() {
        // Hide buttons with fade
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            startButton?.animator().alphaValue = 0
            skipButton?.animator().alphaValue = 0
            snoozeContainer?.animator().alphaValue = 0
        }) {
            self.startButton?.isHidden = true
            self.skipButton?.isHidden = true
            self.snoozeContainer?.isHidden = true
        }

        messageLabel?.stringValue = "Relax your eyes..."
        subtitleLabel?.stringValue = "Focus on something far away"
        breakCountdownSeconds = 20

        // Start ring fill animation
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.breakCountdownSeconds -= 1
            let remaining = self.breakCountdownSeconds

            // Animate number change
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                self.countdownLabel?.animator().alphaValue = 0.4
            }) {
                self.countdownLabel?.stringValue = "\(remaining)"
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.15
                    self.countdownLabel?.animator().alphaValue = 1.0
                })
            }

            // Smooth ring progress
            let pct = 1.0 - (Double(remaining) / 20.0)
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.8)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            self.progressLayer?.strokeEnd = CGFloat(pct)
            CATransaction.commit()

            // Intensify glow as progress fills
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.8)
            self.progressLayer?.shadowOpacity = Float(0.4 + pct * 0.6)
            self.glowLayer?.opacity = Float(0.3 + pct * 0.7)
            CATransaction.commit()

            // Color shift: purple → green as completing
            if remaining <= 5 {
                let t = CGFloat(5 - remaining) / 5.0
                let r = 0.68 * (1 - t) + 0.30 * t
                let g = 0.51 * (1 - t) + 0.85 * t
                let b = 1.0 * (1 - t) + 0.55 * t
                let c = NSColor(red: r, green: g, blue: b, alpha: 1.0)
                self.progressLayer?.strokeColor = c.cgColor
                self.progressLayer?.shadowColor = c.cgColor
            }

            if remaining <= 0 {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.showCompletion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    // MARK: - Completion Animation

    func showCompletion() {
        countdownLabel?.stringValue = "✓"
        countdownLabel?.textColor = SoulColors.green
        messageLabel?.stringValue = "Great job!"
        subtitleLabel?.stringValue = "Your eyes thank you"

        // Flash completion
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            completionLabel?.animator().alphaValue = 1.0
        })

        // Ring flash
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        progressLayer?.strokeColor = SoulColors.green.cgColor
        progressLayer?.shadowColor = SoulColors.green.cgColor
        progressLayer?.shadowRadius = 20
        progressLayer?.shadowOpacity = 0.8
        glowLayer?.strokeColor = SoulColors.green.withAlphaComponent(0.15).cgColor
        CATransaction.commit()

        // Auto-dismiss after 1.5s with fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.dismissOverlay()
        }
    }

    // MARK: - Dismiss with Fade

    func dismissOverlay() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }

        // Fade out
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            overlayWindow?.animator().alphaValue = 0
        }) { [weak self] in
            self?.particleView = nil
            self?.progressLayer = nil
            self?.glowLayer = nil
            self?.countdownLabel = nil
            self?.startButton = nil
            self?.skipButton = nil
            self?.snoozeContainer = nil
            self?.messageLabel = nil
            self?.subtitleLabel = nil
            self?.completionLabel = nil
            self?.logoLabel = nil
            self?.overlayWindow?.orderOut(nil)
            self?.overlayWindow = nil
            self?.startWorkCycle()
        }
    }

    // MARK: - Skip & Snooze Actions

    @objc func skipBreak() {
        dismissOverlay()
    }

    @objc func snoozeFromOverlay(_ sender: Any?) {
        var minutes = 5
        if let view = sender as? ClickableView { minutes = view.muteMinutes }
        forceCloseOverlay()
        startMute(minutes: minutes)
    }

    // MARK: - Helpers

    func makeGhostButton(title: String, onClick: @escaping () -> Void) -> ClickableView {
        let btn = ClickableView(frame: .zero)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.wantsLayer = true
        btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        btn.layer?.cornerRadius = 14
        btn.layer?.borderWidth = 1
        btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        btn.setLabel(title, font: NSFont.systemFont(ofSize: 13, weight: .medium), color: SoulColors.textDim)
        btn.onClick = onClick
        return btn
    }

    func makeSnoozeButton(title: String, tag: Int) -> ClickableView {
        let btn = ClickableView(frame: .zero)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.wantsLayer = true
        btn.layer?.backgroundColor = SoulColors.purple.withAlphaComponent(0.1).cgColor
        btn.layer?.cornerRadius = 14
        btn.layer?.borderWidth = 1
        btn.layer?.borderColor = SoulColors.purple.withAlphaComponent(0.25).cgColor
        btn.muteMinutes = tag
        btn.setLabel(title, font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), color: SoulColors.purple)
        btn.onClick = { [weak self] in
            self?.forceCloseOverlay()
            self?.startMute(minutes: tag)
        }
        return btn
    }

    func makeLabel(text: String, size: CGFloat, color: NSColor, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.wantsLayer = true
        return label
    }
}

// MARK: - NSBezierPath → CGPath

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            case .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
            @unknown default: break
            }
        }
        return path
    }
}

// MARK: - Launch

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
