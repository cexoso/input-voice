import AppKit
import Speech

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var fnKeyMonitor: FnKeyMonitor!
    var speechEngine: SpeechEngine!
    var floatingWindow: FloatingCapsuleWindow?
    var textInjector: TextInjector!
    var llmRefiner: LLMRefiner!
    var settingsWindowController: SettingsWindowController?

    // Language options
    let languages: [(name: String, code: String)] = [
        ("English", "en-US"),
        ("Simplified Chinese", "zh-CN"),
        ("Traditional Chinese", "zh-TW"),
        ("Japanese", "ja-JP"),
        ("Korean", "ko-KR"),
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        requestSpeechPermission()

        llmRefiner = LLMRefiner()
        textInjector = TextInjector()
        speechEngine = SpeechEngine()
        speechEngine.delegate = self

        setupStatusItem()

        fnKeyMonitor = FnKeyMonitor()
        fnKeyMonitor.onFnDown = { [weak self] in
            self?.startRecording()
        }
        fnKeyMonitor.onFnUp = { [weak self] in
            self?.stopRecording()
        }
        fnKeyMonitor.start()
    }

    func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized: break
            case .denied, .restricted, .notDetermined:
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Speech Recognition Permission Required"
                    alert.informativeText = "Please grant microphone and speech recognition access in System Settings."
                    alert.runModal()
                }
            @unknown default: break
            }
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice Input")
        }
        buildMenu()
        statusItem.menu = menu
    }

    func buildMenu() {
        menu = NSMenu()

        // Language submenu
        let langMenu = NSMenu()
        let currentLang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "zh-CN"
        for lang in languages {
            let item = NSMenuItem(title: lang.name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.representedObject = lang.code
            item.target = self
            item.state = (lang.code == currentLang) ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(NSMenuItem.separator())

        // LLM Refinement submenu
        let llmMenu = NSMenu()
        let llmToggle = NSMenuItem(title: "Enable LLM Refinement", action: #selector(toggleLLM(_:)), keyEquivalent: "")
        llmToggle.target = self
        llmToggle.state = UserDefaults.standard.bool(forKey: "llmEnabled") ? .on : .off
        llmMenu.addItem(llmToggle)
        llmMenu.addItem(NSMenuItem.separator())
        let llmSettings = NSMenuItem(title: "Settings...", action: #selector(openLLMSettings), keyEquivalent: "")
        llmSettings.target = self
        llmMenu.addItem(llmSettings)

        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit InputVoice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        UserDefaults.standard.set(code, forKey: "selectedLanguage")
        speechEngine.updateLanguage(code)
        // Refresh menu states
        if let langMenu = sender.menu {
            for item in langMenu.items {
                item.state = (item.representedObject as? String == code) ? .on : .off
            }
        }
    }

    @objc func toggleLLM(_ sender: NSMenuItem) {
        let newState = sender.state == .on ? false : true
        sender.state = newState ? .on : .off
        UserDefaults.standard.set(newState, forKey: "llmEnabled")
    }

    @objc func openLLMSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func startRecording() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.floatingWindow == nil {
                self.floatingWindow = FloatingCapsuleWindow()
            }
            self.floatingWindow?.showWithAnimation()
            self.speechEngine.startRecording()
        }
    }

    func stopRecording() {
        speechEngine.stopRecording()
    }
}

extension AppDelegate: SpeechEngineDelegate {
    func speechEngine(_ engine: SpeechEngine, didUpdateTranscription text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.floatingWindow?.updateText(text)
        }
    }

    func speechEngine(_ engine: SpeechEngine, didUpdateRMSLevel level: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.floatingWindow?.updateRMSLevel(level)
        }
    }

    func speechEngineDidFinish(_ engine: SpeechEngine, finalText: String) {
        let llmEnabled = UserDefaults.standard.bool(forKey: "llmEnabled")
        let apiKey = UserDefaults.standard.string(forKey: "llmAPIKey") ?? ""
        let apiBase = UserDefaults.standard.string(forKey: "llmAPIBase") ?? ""

        if llmEnabled && !apiKey.isEmpty && !apiBase.isEmpty && !finalText.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.floatingWindow?.showRefining()
            }
            llmRefiner.refine(text: finalText) { [weak self] refined in
                DispatchQueue.main.async {
                    self?.floatingWindow?.updateText(refined)
                    self?.floatingWindow?.hideWithAnimation {
                        self?.floatingWindow = nil
                        self?.textInjector.inject(text: refined)
                    }
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.floatingWindow?.hideWithAnimation {
                    self?.floatingWindow = nil
                    if !finalText.isEmpty {
                        self?.textInjector.inject(text: finalText)
                    }
                }
            }
        }
    }
}
