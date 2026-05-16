import AppKit
import Foundation

private let controlPath = "/usr/local/bin/vless-vpnctl"
private let configPath = "/opt/homebrew/etc/sing-box/config.json"

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Статус: проверка...", action: nil, keyEquivalent: "")
    private let startMenuItem = NSMenuItem(title: "Включить VPN", action: #selector(startVPN), keyEquivalent: "")
    private let stopMenuItem = NSMenuItem(title: "Выключить VPN", action: #selector(stopVPN), keyEquivalent: "")
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        updateStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func configureMenu() {
        statusItem.autosaveName = "vless_vpn_status"
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
        }
        setStatusIcon(symbolName: "shield.lefthalf.filled", toolTip: "VLESS VPN: проверка")

        startMenuItem.target = self
        stopMenuItem.target = self

        let refreshItem = NSMenuItem(title: "Обновить статус", action: #selector(refreshStatus), keyEquivalent: "r")
        refreshItem.target = self

        let exclusionsItem = NSMenuItem(title: "Исключения", action: nil, keyEquivalent: "")
        exclusionsItem.submenu = makeExclusionsMenu()

        let openConfigItem = NSMenuItem(title: "Открыть конфиг", action: #selector(openConfig), keyEquivalent: "")
        openConfigItem.target = self

        let quitItem = NSMenuItem(title: "Выход", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(startMenuItem)
        menu.addItem(stopMenuItem)
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(exclusionsItem)
        menu.addItem(.separator())
        menu.addItem(openConfigItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func makeExclusionsMenu() -> NSMenu {
        let exclusionsMenu = NSMenu()

        let addDNSItem = NSMenuItem(title: "Добавить DNS имя...", action: #selector(addDNSExclusion), keyEquivalent: "")
        addDNSItem.target = self

        let addCIDRItem = NSMenuItem(title: "Добавить подсеть/IP...", action: #selector(addCIDRExclusion), keyEquivalent: "")
        addCIDRItem.target = self

        let showItem = NSMenuItem(title: "Показать исключения", action: #selector(showExclusions), keyEquivalent: "")
        showItem.target = self

        exclusionsMenu.addItem(addDNSItem)
        exclusionsMenu.addItem(addCIDRItem)
        exclusionsMenu.addItem(.separator())
        exclusionsMenu.addItem(showItem)
        return exclusionsMenu
    }

    @objc private func startVPN() {
        runPrivileged("start", busyTitle: "VPN стартует...") { [weak self] success, message in
            self?.finishPrivilegedAction(success: success, message: message)
        }
    }

    @objc private func stopVPN() {
        runPrivileged("stop", busyTitle: "VPN выключается...") { [weak self] success, message in
            self?.finishPrivilegedAction(success: success, message: message)
        }
    }

    @objc private func refreshStatus() {
        updateStatus()
    }

    @objc private func addDNSExclusion() {
        guard let value = promptForValue(
            title: "Добавить DNS исключение",
            message: "Введите домен, например example.com или *.example.com",
            placeholder: "example.com"
        ) else {
            return
        }

        runPrivileged("add-domain \(shellQuote(value))", busyTitle: "Добавляю DNS исключение...") { [weak self] success, message in
            self?.finishExclusionAction(success: success, message: message, successMessage: "DNS исключение добавлено.")
        }
    }

    @objc private func addCIDRExclusion() {
        guard let value = promptForValue(
            title: "Добавить подсеть/IP",
            message: "Введите IP или CIDR, например 203.0.113.4/32 или 10.0.0.0/8",
            placeholder: "203.0.113.4/32"
        ) else {
            return
        }

        runPrivileged("add-cidr \(shellQuote(value))", busyTitle: "Добавляю подсеть/IP...") { [weak self] success, message in
            self?.finishExclusionAction(success: success, message: message, successMessage: "Подсеть/IP добавлена.")
        }
    }

    @objc private func showExclusions() {
        let output = runCommand("list-exclusions")
        showAlert(title: "Исключения", message: output.isEmpty ? "Исключения не найдены." : output)
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func runPrivileged(_ argument: String, busyTitle: String, completion: @escaping (Bool, String) -> Void) {
        setBusy(true, title: busyTitle)
        let command = "\(controlPath) \(argument)"
        let source = "do shell script \(appleScriptLiteral(command)) with administrator privileges"

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let output = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue ?? ""
            if let error {
                let message = error[NSAppleScript.errorMessage] as? String ?? "Неизвестная ошибка"
                DispatchQueue.main.async { completion(false, message) }
                return
            }
            DispatchQueue.main.async { completion(true, output) }
        }
    }

    private func finishPrivilegedAction(success: Bool, message: String) {
        setBusy(false, title: nil)
        updateStatus()
        if !success {
            showAlert(title: "Не удалось изменить VPN", message: message)
        }
    }

    private func finishExclusionAction(success: Bool, message: String, successMessage: String) {
        setBusy(false, title: nil)
        updateStatus()
        if success {
            showAlert(title: "Исключение добавлено", message: successMessage)
        } else {
            showAlert(title: "Не удалось добавить исключение", message: message)
        }
    }

    private func updateStatus() {
        DispatchQueue.global(qos: .utility).async {
            let status = self.readStatus()
            DispatchQueue.main.async {
                self.applyStatus(status)
            }
        }
    }

    private func readStatus() -> [String: String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: controlPath)
        process.arguments = ["status"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ["state": "missing", "error": error.localizedDescription]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        var values: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                values[String(parts[0])] = String(parts[1])
            }
        }
        return values
    }

    private func runCommand(_ argument: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: controlPath)
        process.arguments = [argument]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return error.localizedDescription
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func applyStatus(_ status: [String: String]) {
        let state = status["state"] ?? "unknown"
        let service = status["service"] ?? "unknown"
        let proxySummary = "HTTP \(status["http_proxy"] ?? "?") / HTTPS \(status["https_proxy"] ?? "?") / SOCKS \(status["socks_proxy"] ?? "?")"

        switch state {
        case "on":
            setStatusIcon(symbolName: "shield.fill", toolTip: "VLESS VPN: включен")
            statusMenuItem.title = "Статус: включен"
            startMenuItem.isEnabled = false
            stopMenuItem.isEnabled = true
            startMenuItem.state = .off
            stopMenuItem.state = .off
        case "off":
            setStatusIcon(symbolName: "shield.slash", toolTip: "VLESS VPN: выключен")
            statusMenuItem.title = "Статус: выключен (\(service), \(proxySummary))"
            startMenuItem.isEnabled = true
            stopMenuItem.isEnabled = false
            startMenuItem.state = .off
            stopMenuItem.state = .off
        default:
            setStatusIcon(symbolName: "exclamationmark.shield", toolTip: "VLESS VPN: статус неизвестен")
            statusMenuItem.title = "Статус: неизвестен"
            startMenuItem.isEnabled = true
            stopMenuItem.isEnabled = true
            startMenuItem.state = .off
            stopMenuItem.state = .off
        }
    }

    private func setBusy(_ isBusy: Bool, title: String?) {
        startMenuItem.isEnabled = !isBusy
        stopMenuItem.isEnabled = !isBusy
        if let title {
            setStatusIcon(symbolName: "hourglass", toolTip: title)
            statusMenuItem.title = title
        }
    }

    private func setStatusIcon(symbolName: String, toolTip: String) {
        guard let button = statusItem.button else {
            return
        }
        button.title = ""
        button.toolTip = toolTip
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "VPN"
        }
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func promptForValue(title: String, message: String, placeholder: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Добавить")
        alert.addButton(withTitle: "Отмена")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.placeholderString = placeholder
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return nil
        }

        let value = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func appleScriptLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
