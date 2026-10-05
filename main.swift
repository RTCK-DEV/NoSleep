import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var caffeinate: Process?
    private var signalSources: [DispatchSourceSignal] = []
    private var pmsetApplied = false
    private var active = false
    private var vramSliderLabel: NSTextField?

    private let caffeinateLine = NSMenuItem()
    private let pmsetLine = NSMenuItem()
    private let vramLine = NSMenuItem()
    private var toggleItem: NSMenuItem!
    private var vramItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        trapSignals()
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeinate?.terminate()
        if pmsetApplied { _ = runPmset("0") }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        for item in [caffeinateLine, pmsetLine, vramLine] {
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        vramItem = NSMenuItem(title: "VRAM 割り当てを変更…", action: #selector(changeVram), keyEquivalent: "")
        vramItem.target = self
        vramItem.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: nil)
        menu.addItem(vramItem)
        menu.addItem(.separator())

        let setupItem = NSMenuItem(title: "管理者権限をセットアップ…", action: #selector(installSudoers), keyEquivalent: "")
        setupItem.target = self
        setupItem.image = NSImage(systemSymbolName: "key", accessibilityDescription: nil)
        menu.addItem(setupItem)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "NoSleep を終了", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quit)

        statusItem.menu = menu
        updateStatus()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateStatus()
    }

    private func updateStatus() {
        caffeinateLine.title = "caffeinate -dimsu: \(active ? "実行中" : "停止")"
        switch currentDisablesleep() {
        case .some(true):  pmsetLine.title = "pmset disablesleep: 1"
        case .some(false): pmsetLine.title = "pmset disablesleep: 0"
        case .none:        pmsetLine.title = "pmset disablesleep: 不明"
        }
        switch currentVramLimit() {
        case .some(0):       vramLine.title = "VRAM 上限: デフォルト"
        case .some(let mb):  vramLine.title = "VRAM 上限: \(mb) MB (\(mb * 100 / totalMemoryMB)%)"
        case .none:          vramLine.title = "VRAM 上限: 不明"
        }
        toggleItem.title = active ? "スリープ防止を無効化" : "スリープ防止を有効化"
        toggleItem.state = active ? .on : .off

        let name = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "NoSleep")
        img?.isTemplate = true
        statusItem.button?.image = img
        statusItem.button?.title = img == nil ? "NS" : ""
    }

    // MARK: - Toggle

    @objc private func toggle() {
        active ? deactivate() : activate()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func activate() {
        startCaffeinate()
        if runPmset("1") {
            pmsetApplied = true
        } else {
            alert("sudo pmset -a disablesleep 1 を実行できませんでした。\n\nメニューの「管理者権限をセットアップ…」で NOPASSWD 設定をインストールしてください。caffeinate によるスリープ防止は有効です。")
        }
        active = caffeinate != nil
        updateStatus()
    }

    private func deactivate() {
        caffeinate?.terminationHandler = nil
        caffeinate?.terminate()
        caffeinate = nil
        if pmsetApplied {
            if runPmset("0") {
                pmsetApplied = false
            } else {
                alert("sudo pmset -a disablesleep 0 を実行できませんでした。\nターミナルで手動で実行してください。")
            }
        }
        active = false
        updateStatus()
    }

    private func startCaffeinate() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = ["-dimsu"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self, self.caffeinate === proc else { return }
                self.caffeinate = nil
                self.active = false
                self.updateStatus()
            }
        }
        do {
            try p.run()
            caffeinate = p
        } catch {
            alert("caffeinate の起動に失敗しました: \(error.localizedDescription)")
        }
    }

    // MARK: - pmset / sudo

    @discardableResult
    private func runPmset(_ value: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", value]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func currentDisablesleep() -> Bool? {
        guard let out = shell("/usr/bin/pmset", ["-g"]) else { return nil }
        for line in out.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last.flatMap { Int($0) } == 1
        }
        return nil
    }

    private func shell(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - VRAM

    private func currentVramLimit() -> Int? {
        guard let out = shell("/usr/sbin/sysctl", ["-n", "iogpu.wired_limit_mb"]) else { return nil }
        return Int(out.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var totalMemoryMB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / 1_048_576)
    }

    @objc private func changeVram() {
        let totalMB = totalMemoryMB
        let current = currentVramLimit()
        let currentText = current.map { $0 == 0 ? "デフォルト" : "\($0) MB (\($0 * 100 / totalMB)%)" } ?? "不明"

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 66))

        let label = NSTextField(labelWithString: "")
        label.frame = NSRect(x: 0, y: 42, width: 300, height: 18)
        label.alignment = .center
        vramSliderLabel = label

        let initialPct: Int
        if let mb = current, mb > 0 {
            initialPct = min(95, max(5, mb * 100 / totalMB))
        } else {
            initialPct = 75
        }
        let slider = NSSlider(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
        slider.minValue = 5
        slider.maxValue = 95
        slider.integerValue = initialPct
        slider.numberOfTickMarks = 19
        slider.allowsTickMarkValuesOnly = false
        slider.tickMarkPosition = .below
        slider.target = self
        slider.action = #selector(vramSliderChanged(_:))
        vramSliderChanged(slider)

        accessory.addSubview(label)
        accessory.addSubview(slider)

        let a = NSAlert()
        a.messageText = "VRAM 割り当て (iogpu.wired_limit_mb)"
        a.informativeText = "物理メモリ \(totalMB) MB に対する GPU 上限の割合を選んでください。\n現在値: \(currentText)　（再起動で自動リセット）"
        a.accessoryView = accessory
        a.addButton(withTitle: "設定")
        a.addButton(withTitle: "デフォルトに戻す")
        a.addButton(withTitle: "キャンセル")
        activateApp()
        a.window.level = .modalPanel
        let response = a.runModal()
        vramSliderLabel = nil

        let mb: Int
        switch response {
        case .alertFirstButtonReturn:
            mb = slider.integerValue * totalMB / 100
        case .alertSecondButtonReturn:
            mb = 0
        default:
            return
        }
        if runSysctl(mb) {
            updateStatus()
        } else {
            alert("sudo sysctl iogpu.wired_limit_mb=\(mb) を実行できませんでした。\n\nメニューの「管理者権限をセットアップ…」で NOPASSWD 設定をインストール（または再インストール）してください。")
        }
    }

    @objc private func vramSliderChanged(_ sender: NSSlider) {
        let pct = sender.integerValue
        vramSliderLabel?.stringValue = "\(pct)% ≒ \(pct * totalMemoryMB / 100) MB"
    }

    private func runSysctl(_ mb: Int) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n", "/usr/sbin/sysctl", "iogpu.wired_limit_mb=\(mb)"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - sudoers setup

    @objc private func installSudoers() {
        let user = NSUserName()
        let sudoersLine = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1, /usr/sbin/sysctl iogpu.wired_limit_mb=*"
        let script = """
        #!/bin/sh
        set -e
        f=/etc/sudoers.d/nosleep-pmset
        printf '%s\\n' '\(sudoersLine)' > "$f.tmp"
        chmod 440 "$f.tmp"
        if ! visudo -cf "$f.tmp" > /dev/null; then
            rm -f "$f.tmp"
            exit 1
        fi
        mv "$f.tmp" "$f"
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nosleep-sudoers.sh")
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            alert("セットアップスクリプトを作成できませんでした。")
            return
        }

        var err: NSDictionary?
        let source = "do shell script \"/bin/sh '\(url.path)'\" with administrator privileges"
        NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let err {
            if (err[NSAppleScript.errorNumber] as? Int) != -128 {
                let msg = err[NSAppleScript.errorMessage] as? String ?? "不明なエラー"
                alert("セットアップに失敗しました: \(msg)")
            }
            return
        }
        alert("セットアップが完了しました。\n/etc/sudoers.d/nosleep-pmset を作成しました。")
    }

    // MARK: - Misc

    private func trapSignals() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler {
                NSApp.terminate(nil)
            }
            src.resume()
            signalSources.append(src)
        }
    }

    private func alert(_ message: String) {
        activateApp()
        let a = NSAlert()
        a.messageText = "NoSleep"
        a.informativeText = message
        a.alertStyle = .informational
        a.window.level = .modalPanel
        a.runModal()
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
