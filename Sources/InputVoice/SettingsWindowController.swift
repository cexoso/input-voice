import AppKit

class SettingsWindowController: NSWindowController {
    private var apiBaseField: NSTextField!
    private var apiKeyField: NSSecureTextField!
    private var modelField: NSTextField!
    private var statusLabel: NSTextField!
    private var testButton: NSButton!
    private var saveButton: NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LLM Refinement Settings"
        window.center()
        self.init(window: window)
        setupUI()
        loadValues()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let padding: CGFloat = 20
        let labelWidth: CGFloat = 110
        let fieldLeft = padding + labelWidth + 8
        let fieldWidth = 480 - fieldLeft - padding
        let rowH: CGFloat = 24
        let rowSpacing: CGFloat = 16

        // --- API Base URL ---
        var y: CGFloat = 230
        let baseLabel = makeLabel("API Base URL:", frame: NSRect(x: padding, y: y, width: labelWidth, height: rowH))
        contentView.addSubview(baseLabel)

        apiBaseField = NSTextField(frame: NSRect(x: fieldLeft, y: y, width: fieldWidth, height: rowH))
        apiBaseField.placeholderString = "https://api.openai.com/v1"
        contentView.addSubview(apiBaseField)

        // --- API Key ---
        y -= rowH + rowSpacing
        let keyLabel = makeLabel("API Key:", frame: NSRect(x: padding, y: y, width: labelWidth, height: rowH))
        contentView.addSubview(keyLabel)

        apiKeyField = NSSecureTextField(frame: NSRect(x: fieldLeft, y: y, width: fieldWidth, height: rowH))
        apiKeyField.placeholderString = "sk-..."
        contentView.addSubview(apiKeyField)

        // --- Model ---
        y -= rowH + rowSpacing
        let modelLabel = makeLabel("Model:", frame: NSRect(x: padding, y: y, width: labelWidth, height: rowH))
        contentView.addSubview(modelLabel)

        modelField = NSTextField(frame: NSRect(x: fieldLeft, y: y, width: fieldWidth, height: rowH))
        modelField.placeholderString = "gpt-4o-mini"
        contentView.addSubview(modelField)

        // --- Status label ---
        y -= rowH + rowSpacing
        statusLabel = NSTextField(frame: NSRect(x: padding, y: y, width: 480 - padding * 2, height: rowH))
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.drawsBackground = false
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = ""
        contentView.addSubview(statusLabel)

        // --- Buttons ---
        y -= rowH + rowSpacing + 8
        saveButton = NSButton(frame: NSRect(x: 480 - padding - 80, y: y, width: 80, height: 28))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        contentView.addSubview(saveButton)

        testButton = NSButton(frame: NSRect(x: 480 - padding - 80 - 90, y: y, width: 80, height: 28))
        testButton.title = "Test"
        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(testConnection)
        contentView.addSubview(testButton)
    }

    private func makeLabel(_ title: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = title
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }

    private func loadValues() {
        apiBaseField.stringValue = UserDefaults.standard.string(forKey: "llmAPIBase") ?? ""
        // NSSecureTextField needs special handling to allow clearing
        apiKeyField.stringValue = UserDefaults.standard.string(forKey: "llmAPIKey") ?? ""
        modelField.stringValue = UserDefaults.standard.string(forKey: "llmModel") ?? "gpt-4o-mini"
    }

    @objc private func saveSettings() {
        UserDefaults.standard.set(apiBaseField.stringValue, forKey: "llmAPIBase")
        // Store raw string value for API key (supports full clear)
        UserDefaults.standard.set(apiKeyField.stringValue, forKey: "llmAPIKey")
        UserDefaults.standard.set(modelField.stringValue, forKey: "llmModel")
        statusLabel.textColor = .systemGreen
        statusLabel.stringValue = "Settings saved."
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.statusLabel.stringValue = ""
        }
    }

    @objc private func testConnection() {
        let apiBase = apiBaseField.stringValue
        let apiKey = apiKeyField.stringValue
        let model = modelField.stringValue.isEmpty ? "gpt-4o-mini" : modelField.stringValue

        guard !apiBase.isEmpty, !apiKey.isEmpty else {
            statusLabel.textColor = .systemOrange
            statusLabel.stringValue = "Please fill in API Base URL and API Key."
            return
        }

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Testing..."
        testButton.isEnabled = false

        let refiner = LLMRefiner()
        refiner.test(apiBase: apiBase, apiKey: apiKey, model: model) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.testButton.isEnabled = true
                self?.statusLabel.textColor = success ? .systemGreen : .systemRed
                self?.statusLabel.stringValue = message
            }
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        loadValues()
        window?.makeKeyAndOrderFront(sender)
        setupEditMenu()
    }

    private func setupEditMenu() {
        guard NSApp.mainMenu == nil || NSApp.mainMenu?.item(withTitle: "Edit") == nil else { return }

        let mainMenu = NSApp.mainMenu ?? NSMenu()

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
