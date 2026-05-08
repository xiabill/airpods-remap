import Cocoa
import SwiftUI
import CoreGraphics
import Combine
import ServiceManagement
import Darwin

// MARK: - 可选键位目录

struct KeyChoice: Identifiable, Hashable {
    let id: String
    let label: String
    let keyCode: UInt16
    let flags: UInt64
}

let keyChoices: [KeyChoice] = [
    .init(id: "lopt",    label: "Left Option ⌥",   keyCode: 58, flags: 0),
    .init(id: "ropt",    label: "Right Option ⌥",  keyCode: 61, flags: 0),
    .init(id: "lcmd",    label: "Left Command ⌘",  keyCode: 55, flags: 0),
    .init(id: "rcmd",    label: "Right Command ⌘", keyCode: 54, flags: 0),
    .init(id: "lctrl",   label: "Left Control ⌃",  keyCode: 59, flags: 0),
    .init(id: "rctrl",   label: "Right Control ⌃", keyCode: 62, flags: 0),
    .init(id: "lshift",  label: "Left Shift ⇧",    keyCode: 56, flags: 0),
    .init(id: "rshift",  label: "Right Shift ⇧",   keyCode: 60, flags: 0),
    .init(id: "fn",      label: "Fn",              keyCode: 63, flags: 0),

    .init(id: "f13", label: "F13", keyCode: 105, flags: 0),
    .init(id: "f14", label: "F14", keyCode: 107, flags: 0),
    .init(id: "f15", label: "F15", keyCode: 113, flags: 0),
    .init(id: "f16", label: "F16", keyCode: 106, flags: 0),
    .init(id: "f17", label: "F17", keyCode:  64, flags: 0),
    .init(id: "f18", label: "F18", keyCode:  79, flags: 0),
    .init(id: "f19", label: "F19", keyCode:  80, flags: 0),
    .init(id: "f20", label: "F20", keyCode:  90, flags: 0),

    .init(id: "space",  label: "Space 空格",       keyCode: 49, flags: 0),
    .init(id: "return", label: "Return / Enter ↵", keyCode: 36, flags: 0),
    .init(id: "esc",    label: "Escape",           keyCode: 53, flags: 0),
    .init(id: "tab",    label: "Tab",              keyCode: 48, flags: 0),

    // 数字键 0–9
    .init(id: "n1", label: "1", keyCode: 18, flags: 0),
    .init(id: "n2", label: "2", keyCode: 19, flags: 0),
    .init(id: "n3", label: "3", keyCode: 20, flags: 0),
    .init(id: "n4", label: "4", keyCode: 21, flags: 0),
    .init(id: "n5", label: "5", keyCode: 23, flags: 0),
    .init(id: "n6", label: "6", keyCode: 22, flags: 0),
    .init(id: "n7", label: "7", keyCode: 26, flags: 0),
    .init(id: "n8", label: "8", keyCode: 28, flags: 0),
    .init(id: "n9", label: "9", keyCode: 25, flags: 0),
    .init(id: "n0", label: "0", keyCode: 29, flags: 0),

    .init(id: "cmd-space",   label: "⌘ Space (Spotlight)",
          keyCode: 49, flags: UInt64(CGEventFlags.maskCommand.rawValue)),
    .init(id: "cmd-tab",     label: "⌘ Tab (App 切换)",
          keyCode: 48, flags: UInt64(CGEventFlags.maskCommand.rawValue)),
    .init(id: "cmd-shift-3", label: "⌘⇧3 (全屏截图)",
          keyCode: 20, flags: UInt64(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue)),
    .init(id: "cmd-shift-4", label: "⌘⇧4 (区域截图)",
          keyCode: 21, flags: UInt64(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue)),
    .init(id: "cmd-shift-5", label: "⌘⇧5 (截图工具)",
          keyCode: 23, flags: UInt64(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue)),
]

func keyChoice(_ id: String) -> KeyChoice? {
    keyChoices.first { $0.id == id }
}

// MARK: - 配置

enum MappingMode: String, Codable, CaseIterable {
    case tap          // 按一下：down + up（瞬时）
    case holdToggle   // 按一下按住，再按一下释放（适合长按型快捷键，如 Typeless 的 Opt 录音）
}

struct GestureMapping: Codable, Equatable {
    var enabled: Bool
    var keyChoiceId: String
    var mode: MappingMode

    init(enabled: Bool, keyChoiceId: String, mode: MappingMode = .tap) {
        self.enabled = enabled
        self.keyChoiceId = keyChoiceId
        self.mode = mode
    }

    enum CodingKeys: String, CodingKey { case enabled, keyChoiceId, mode }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled     = try c.decode(Bool.self, forKey: .enabled)
        keyChoiceId = try c.decode(String.self, forKey: .keyChoiceId)
        mode        = (try? c.decode(MappingMode.self, forKey: .mode)) ?? .tap
    }
}

final class Config: ObservableObject {
    static let shared = Config()
    private let storeKey = "config_v1"

    @Published var single: GestureMapping { didSet { save() } }
    @Published var double: GestureMapping { didSet { save() } }
    @Published var triple: GestureMapping { didSet { save() } }
    // 音量+/- 默认禁用 —— 启用后会失去 AirPods 调音量能力
    @Published var volumeUp:   GestureMapping { didSet { save() } }
    @Published var volumeDown: GestureMapping { didSet { save() } }

    private init() {
        // 默认：单击 = 按住 Opt（用于 Typeless：按一下开始录音，再按一下结束）
        var s = GestureMapping(enabled: true,  keyChoiceId: "lopt", mode: .holdToggle)
        var d = GestureMapping(enabled: false, keyChoiceId: "f14")
        var t = GestureMapping(enabled: false, keyChoiceId: "f15")
        var vu = GestureMapping(enabled: false, keyChoiceId: "f16")
        var vd = GestureMapping(enabled: false, keyChoiceId: "f17")
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let dict = try? JSONDecoder().decode([String: GestureMapping].self, from: data) {
            if let v = dict["single"]     { s = v }
            if let v = dict["double"]     { d = v }
            if let v = dict["triple"]     { t = v }
            if let v = dict["volumeUp"]   { vu = v }
            if let v = dict["volumeDown"] { vd = v }
        }
        self.single = s
        self.double = d
        self.triple = t
        self.volumeUp = vu
        self.volumeDown = vd
    }

    private func save() {
        let dict: [String: GestureMapping] = [
            "single": single, "double": double, "triple": triple,
            "volumeUp": volumeUp, "volumeDown": volumeDown,
        ]
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    func resetToDefaults() {
        single = GestureMapping(enabled: true,  keyChoiceId: "lopt", mode: .holdToggle)
        double = GestureMapping(enabled: false, keyChoiceId: "f14")
        triple = GestureMapping(enabled: false, keyChoiceId: "f15")
        volumeUp   = GestureMapping(enabled: false, keyChoiceId: "f16")
        volumeDown = GestureMapping(enabled: false, keyChoiceId: "f17")
    }
}

// MARK: - Event Tap

private let NX_KEYTYPE_SOUND_UP:   Int32 =  0
private let NX_KEYTYPE_SOUND_DOWN: Int32 =  1
private let NX_KEYTYPE_PLAY:       Int32 = 16
private let NX_KEYTYPE_NEXT:       Int32 = 17
private let NX_KEYTYPE_PREVIOUS:   Int32 = 19

final class EventTap: ObservableObject {
    static let shared = EventTap()

    @Published private(set) var isRunning = false
    @Published private(set) var holdingCount = 0   // 当前处于 hold 状态的映射数（>0 时图标变红）
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var holdingKeys: [Int32: (UInt16, UInt64)] = [:]   // 触发源 keyCode -> (目标 keyCode, flags)

    func hasPermission(prompt: Bool = false) -> Bool {
        let opts = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    @discardableResult
    func start() -> Bool {
        if isRunning { return true }

        // 已有 tap，重新启用即可
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            isRunning = true
            return true
        }

        guard hasPermission(prompt: true) else { return false }

        let mask: CGEventMask = 1 << 14  // NSSystemDefined
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            return false
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = src
        isRunning = true
        return true
    }

    func stop() {
        guard isRunning else { return }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        releaseAllHeld()
        isRunning = false
    }

    func toggle() {
        if isRunning { stop() } else { _ = start() }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // 系统超时禁用了 tap：仅当用户希望运行时再开
            if isRunning, let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14 else { return Unmanaged.passUnretained(event) }
        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }
        let keyCode  = Int32((nsEvent.data1 & 0xFFFF0000) >> 16)
        let keyFlags = nsEvent.data1 & 0x0000FFFF
        let isKeyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A

        let cfg = Config.shared
        let mapping: GestureMapping
        switch keyCode {
        case NX_KEYTYPE_PLAY:       mapping = cfg.single
        case NX_KEYTYPE_NEXT:       mapping = cfg.double
        case NX_KEYTYPE_PREVIOUS:   mapping = cfg.triple
        case NX_KEYTYPE_SOUND_UP:   mapping = cfg.volumeUp
        case NX_KEYTYPE_SOUND_DOWN: mapping = cfg.volumeDown
        default: return Unmanaged.passUnretained(event)
        }
        guard mapping.enabled, let choice = keyChoice(mapping.keyChoiceId) else {
            // 该手势未启用，让原事件通过（音量键继续控制系统音量、play/pause 继续走默认）
            return Unmanaged.passUnretained(event)
        }
        if isKeyDown {
            switch mapping.mode {
            case .tap:
                postKeyDown(keyCode: choice.keyCode, flags: choice.flags)
                postKeyUp(keyCode: choice.keyCode, flags: choice.flags)
            case .holdToggle:
                if holdingKeys[keyCode] != nil {
                    postKeyUp(keyCode: choice.keyCode, flags: choice.flags)
                    holdingKeys.removeValue(forKey: keyCode)
                } else {
                    postKeyDown(keyCode: choice.keyCode, flags: choice.flags)
                    holdingKeys[keyCode] = (choice.keyCode, choice.flags)
                }
                DispatchQueue.main.async { [weak self] in
                    self?.holdingCount = self?.holdingKeys.count ?? 0
                }
            }
        }
        return nil
    }

    /// 释放所有处于 hold 状态的键，防止 Opt 等修饰键卡住。
    /// 在 stop()、quit、配置切换时调用。
    func releaseAllHeld() {
        for (_, (keyCode, flags)) in holdingKeys {
            postKeyUp(keyCode: keyCode, flags: flags)
        }
        holdingKeys.removeAll()
        DispatchQueue.main.async { [weak self] in
            self?.holdingCount = 0
        }
    }

    private func postKeyDown(keyCode: UInt16, flags: UInt64) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        if flags != 0 { down?.flags = CGEventFlags(rawValue: flags) }
        down?.post(tap: .cghidEventTap)
    }

    private func postKeyUp(keyCode: UInt16, flags: UInt64) {
        let src = CGEventSource(stateID: .hidSystemState)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        if flags != 0 { up?.flags = CGEventFlags(rawValue: flags) }
        up?.post(tap: .cghidEventTap)
    }
}

// MARK: - 开机自启动

final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()
    @Published private(set) var isEnabled: Bool = false
    @Published var lastError: String?

    private init() { refresh() }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            NSLog("LaunchAtLogin error: \(error)")
        }
        refresh()
    }
}

// MARK: - SwiftUI 配置面板

struct MappingRow: View {
    let label: String
    @Binding var mapping: GestureMapping

    var body: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $mapping.enabled) {
                Text(label).frame(width: 40, alignment: .leading)
            }
            .toggleStyle(.checkbox)

            Picker("", selection: $mapping.keyChoiceId) {
                ForEach(keyChoices) { c in
                    Text(c.label).tag(c.id)
                }
            }
            .labelsHidden()
            .disabled(!mapping.enabled)

            Picker("", selection: $mapping.mode) {
                Text("点按").tag(MappingMode.tap)
                Text("按住").tag(MappingMode.holdToggle)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 110)
            .disabled(!mapping.enabled)
        }
    }
}

struct ContentView: View {
    @ObservedObject var config = Config.shared
    @ObservedObject var tap = EventTap.shared
    @ObservedObject var loginItem = LaunchAtLogin.shared
    @State private var hasPermission = EventTap.shared.hasPermission()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack(spacing: 6) {
                Image(systemName: "earbuds").imageScale(.large)
                Text("AirPods Remap").font(.headline)
                Spacer()
                Circle()
                    .fill(tap.isRunning ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(tap.isRunning ? "运行中" : "已暂停")
                    .font(.caption).foregroundColor(.secondary)
            }

            // 启停 + 权限
            HStack(spacing: 8) {
                Button {
                    if tap.isRunning {
                        tap.stop()
                    } else {
                        hasPermission = EventTap.shared.hasPermission(prompt: true)
                        if hasPermission { _ = tap.start() }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tap.isRunning ? "pause.fill" : "play.fill")
                        Text(tap.isRunning ? "暂停" : "启动")
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
                .keyboardShortcut("s")

                Button("辅助功能…") {
                    NSWorkspace.shared.open(URL(string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }

            if !hasPermission {
                Text("⚠️ 需要在「辅助功能」里授权 AirPodsRemap")
                    .font(.caption).foregroundColor(.orange)
            }

            Divider()

            // 映射
            MappingRow(label: "单击", mapping: $config.single)
            MappingRow(label: "双击", mapping: $config.double)
            MappingRow(label: "三击", mapping: $config.triple)
            MappingRow(label: "音量+", mapping: $config.volumeUp)
            MappingRow(label: "音量-", mapping: $config.volumeDown)
            if config.volumeUp.enabled || config.volumeDown.enabled {
                Text("⚠️ 启用音量键映射后，AirPods 将无法用来调系统音量")
                    .font(.caption2).foregroundColor(.orange)
            }

            HStack {
                Spacer()
                Button("重置默认") { config.resetToDefaults() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            Divider()

            Toggle(isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            )) {
                Text("开机时自动启动")
            }
            .toggleStyle(.checkbox)

            if let err = loginItem.lastError {
                Text("自启动设置失败：\(err)")
                    .font(.caption2).foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("说明：单/双/三击 + 音量+/- 触发对应映射键。「点按」=按一下立刻松开；「按住」=按一下按住、再按一下释放（适合 Typeless 长按 Opt 录音）。音量键默认关闭，开启后会失去 AirPods 调音量能力。")
                .font(.caption2).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("退出 AirPods Remap") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 460)
    }
}

// MARK: - AppDelegate（状态栏 + 弹层 + 右键菜单）

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setvbuf(stdout, nil, _IOLBF, 0)
        _ = Config.shared

        // 默认启动
        _ = EventTap.shared.start()

        // 状态栏
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "earbuds", accessibilityDescription: "AirPods Remap")
            img?.isTemplate = true
            button.image = img
            button.target = self
            button.action = #selector(handleStatusClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIconAlpha()

        // 监听运行状态以更新图标透明度
        EventTap.shared.$isRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIconAlpha() }
            .store(in: &cancellables)

        // 监听 hold 状态，正在按住时图标变红，提醒用户「录音中」
        EventTap.shared.$holdingCount
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIconAlpha() }
            .store(in: &cancellables)

        // Popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }

    private func updateIconAlpha() {
        let tap = EventTap.shared
        statusItem?.button?.alphaValue = tap.isRunning ? 1.0 : 0.4
        statusItem?.button?.contentTintColor = tap.holdingCount > 0 ? .systemRed : nil
    }

    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu(from: sender, event: event)
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(from button: NSStatusBarButton, event: NSEvent) {
        let menu = NSMenu()

        // 启停
        let isRun = EventTap.shared.isRunning
        let toggle = NSMenuItem(
            title: isRun ? "⏸  暂停" : "▶  启动",
            action: #selector(menuToggleRunning),
            keyEquivalent: "s")
        toggle.target = self
        menu.addItem(toggle)

        // 状态信息
        let stateItem = NSMenuItem(
            title: isRun ? "状态：运行中" : "状态：已暂停",
            action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        menu.addItem(.separator())

        // 当前映射快览
        let cfg = Config.shared
        for (label, m) in [("单击", cfg.single), ("双击", cfg.double), ("三击", cfg.triple),
                           ("音量+", cfg.volumeUp), ("音量-", cfg.volumeDown)] {
            let title: String = {
                if !m.enabled { return "\(label)：— 关闭" }
                let key = keyChoice(m.keyChoiceId)?.label ?? "?"
                return "\(label)： \(key)"
            }()
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // 操作
        let openConfig = NSMenuItem(
            title: "打开配置面板",
            action: #selector(menuOpenConfig),
            keyEquivalent: ",")
        openConfig.target = self
        menu.addItem(openConfig)

        let openAccess = NSMenuItem(
            title: "辅助功能权限设置…",
            action: #selector(menuOpenAccessibility),
            keyEquivalent: "")
        openAccess.target = self
        menu.addItem(openAccess)

        let resetItem = NSMenuItem(
            title: "重置为默认映射",
            action: #selector(menuReset),
            keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "开机时自动启动",
            action: #selector(menuToggleLoginItem),
            keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LaunchAtLogin.shared.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // 关于 / 退出
        let about = NSMenuItem(
            title: "关于 AirPods Remap",
            action: #selector(menuAbout),
            keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(
            title: "退出",
            action: #selector(menuQuit),
            keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // 用 popUpContextMenu 弹出，避免覆盖左键 action
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    // MARK: 菜单 actions

    @objc private func menuToggleRunning() { EventTap.shared.toggle() }
    @objc private func menuOpenConfig() { togglePopover(nil) }
    @objc private func menuOpenAccessibility() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func menuReset() { Config.shared.resetToDefaults() }
    @objc private func menuToggleLoginItem() {
        LaunchAtLogin.shared.setEnabled(!LaunchAtLogin.shared.isEnabled)
    }
    @objc private func menuAbout() {
        let alert = NSAlert()
        alert.messageText = "AirPods Remap"
        alert.informativeText = """
            把 AirPods 单击 / 双击 / 三击映射到任意键盘按键。

            • 左键状态栏图标 → 配置面板
            • 右键状态栏图标 → 快捷菜单

            版本 1.3.1
            """
        alert.runModal()
    }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前释放所有 hold 的键，避免 Opt 等修饰键卡住
        EventTap.shared.releaseAllHeld()
    }
}

// MARK: - SwiftUI App 入口

@main
struct AirPodsRemapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }  // 占位，无窗口；状态栏由 AppDelegate 管理
    }
}
