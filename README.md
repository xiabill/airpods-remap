# AirPods Remap

把 AirPods 的 **单击 / 双击 / 三击 / 音量+ / 音量-** 手势映射到任意键盘按键的 macOS 菜单栏小工具。专为搭配 [Typeless](https://typeless.dev/) / [WhisperKey](https://whisperkey.app/) 这类「按住 Opt 录音」的 AI 输入工具设计 —— 戴着 AirPods 单击一下就开录，再单击一下就上文字。

> **代码完全由 [Claude Code](https://claude.com/claude-code) 写就。** 我（仓库主人）只是把需求讲给 Claude，所有实现、调试、文档、打包都是它做的。

---

## ⚠️ 兼容性（必看）

| 设备 | 状态 | 说明 |
|---|---|---|
| AirPods 1 / 2 / 3 / 4（普通版） | ✅ 全部工作 | 单/双/三击 + 音量+/- 都能拦 |
| AirPods Max | ✅ 全部工作 | 同普通版 |
| AirPods Pro 1 | ⚠️ 待测试 | 理论上和普通版一样 |
| **AirPods Pro 2 / Pro 3** | ⚠️ **部分支持** | **stem 单击/双击/三击 拦不到**（Apple 改走 MediaRemote 私有 IPC，绕过 CGEventTap）。但 **stem 上下滑（音量+/-）可以拦**（音量必须走 NSSystemDefined 公开路径）。 |

**Pro 2 / Pro 3 用户注意**：你只能映射音量+/-（stem 上下滑）。stem 单击是 macOS 系统级限制，所有第三方工具（Karabiner-Elements、SiriMote、本项目）都拦不到，详见下方「为什么 Pro 2 stem 单击不工作」。

---

## 功能

- **五种手势**：单击 / 双击 / 三击 stem + 音量+ / 音量-（stem 上下滑），分别可独立映射
- **音量键映射默认关闭** —— 启用后会失去 AirPods 调系统音量的能力，需用户主动开
- **两种触发模式**：
  - **「点按」**：按一下 → 立即按下并释放（适合 ⌘Space、F13 等普通快捷键）
  - **「按住」**：按一下进入按住状态，再按一下释放（**专为 Typeless / WhisperKey 这种长按 Opt 录音的应用设计**）
- **27 种可选目标键**：所有修饰键（⌥/⌘/⌃/⇧/Fn）、F13–F20、空格/回车/ESC/Tab、以及常用组合键（⌘Space / ⌘Tab / ⌘⇧3/4/5）
- **状态栏图标**：左键打开配置面板，右键弹出快捷菜单；按住状态下图标变红
- **暂停/启动**：不用时一键暂停，AirPods 恢复原本 play/pause 行为
- **开机自启动**：可选
- **配置即时生效，自动保存**到 UserDefaults
- **退出/暂停时自动释放按住的键**，不会卡住 Opt

---

## 安装

### 方式 A：下载 dmg（推荐）

1. 到 [Releases](https://github.com/xiabill/airpods-remap/releases) 下载最新的 `AirPodsRemap-x.y.dmg`
2. 双击挂载 dmg，把 **AirPodsRemap.app** 拖到 **Applications** 文件夹
3. 在 Launchpad 启动 AirPodsRemap
4. **首次启动会被 macOS 拦下**（"未受信任的开发者"），原因是这个 app 是 ad-hoc 签名（不是 Apple 开发者签名）。绕过：
   - 在访达 → 应用程序 → 右键 AirPodsRemap → **打开** → **仍要打开**
   - 或：系统设置 → 隐私与安全性 → 拉到底 → 允许 AirPodsRemap 运行
5. **授权辅助功能**：系统设置 → 隐私与安全性 → **辅助功能** → 找到 AirPodsRemap → 打开 toggle
6. **杀掉 app 重新启动一次**（让权限生效）：

   ```bash
   pkill -f AirPodsRemap && open /Applications/AirPodsRemap.app
   ```

7. 状态栏出现耳塞图标 = 成功

### 方式 B：从源码构建

需要 Xcode Command Line Tools（`xcode-select --install`）。

```bash
git clone https://github.com/xiabill/airpods-remap.git
cd airpods-remap
./build.sh                                  # 生成 AirPodsRemap.app
open AirPodsRemap.app
```

第一次运行后同样要在系统设置里授权辅助功能，然后重启 app。

---

## 快速上手 — 配 Typeless 用

这是本工具最典型的使用场景。

### 1. 装好 [Typeless](https://typeless.dev/)，把它的快捷键设为 **按住 Left Option (⌥)**

   按住 Opt → 录音 → 松开 Opt → 转写并粘贴。

### 2. 在 AirPodsRemap 配置面板里把「单击」设为：

   - 启用 ✅
   - 目标键：**Left Option ⌥**
   - 模式：**按住**

### 3. 戴上普通 AirPods，打开任意输入框

### 4. **单击 stem 一下** → 状态栏图标变红 → Typeless 录音弹出 → 说话 → **再单击 stem** → 图标恢复 → 文字粘到光标位置

> **「按住」模式的工作原理**：第一次单击 → app 发送 ⌥ keyDown 事件并保持按住状态 → Typeless 看到「Opt 被按住」开始录音；第二次单击 → app 发送 ⌥ keyUp 事件 → Typeless 看到 Opt 释放，转写并提交。

---

## 配置面板说明

| UI 元素 | 作用 |
|---|---|
| **▶/⏸ 按钮** | 启动 / 暂停 EventTap。暂停后 AirPods 恢复系统默认行为 |
| **辅助功能…** | 直接跳转到系统设置授权页 |
| **单/双/三击 行** | 每行三个控件：启用 toggle、目标键 picker、模式 segmented control |
| **重置默认** | 单击=按住⌥（Typeless 友好），双/三击禁用 |
| **开机自启动** | macOS 13+ ServiceManagement API 实现 |

右键状态栏图标可以快速切换运行状态、打开授权设置、退出。

---

## 故障排除

### 单击 AirPods 后图标不变红、Typeless 也没反应

99% 是辅助功能权限问题。三步检查：

1. **系统设置 → 辅助功能** 里 AirPodsRemap 的 toggle 是否开着
2. **杀掉 app 重启**：

   ```bash
   pkill -f AirPodsRemap && open /Applications/AirPodsRemap.app
   ```

3. 仍然不行：把 AirPodsRemap 从辅助功能列表里 **删除（点 -）**，重启 app，等系统弹提示，再次添加

### 重新构建 (`./build.sh`) 后权限失效

ad-hoc 签名每次 build 后 hash 变化，macOS 视作新 app。要么重新授权一次，要么用稳定的 self-signed 证书签名（[贡献欢迎](#贡献)）。

### 暂停 / 退出后 Opt 卡住怎么办

正常情况下 app 退出会自动释放所有按住的键。如果异常卡住：

- 在状态栏点暂停或重启 app
- 或在终端按一下 ESC

### 我有 AirPods Pro 2，能用吗

部分能用：
- **stem 单击/双击/三击** —— ❌ 拦不到（macOS 系统限制，详见下方）
- **stem 上下滑（音量+/-）** —— ✅ 能拦，但默认关闭，要在配置面板里启用

如果你只想要「按一下 AirPods 触发 Typeless」这种场景，Pro 2 上**没有可行的 stem 单击替代方案**，只能用普通 AirPods。但如果你愿意用「上滑/下滑触发」，Pro 2 也能做。

---

## 为什么 Pro 2 stem 单击不工作（音量键例外）

普通 AirPods 的 stem 单击事件链：

```
单击 stem
   ↓
AirPods 固件发媒体键 HID code (NX_KEYTYPE_PLAY)
   ↓ macOS HID 系统接收
NSSystemDefined 事件 (type=14, subtype=8)
   ↓ 我们的 CGEventTap 拦截 ✅
模拟 ⌥ 键事件
```

AirPods Pro 2 的事件链：

```
单击 stem
   ↓
Pro 2 固件直接发私有 BLE 命令到 macOS BT daemon
   ↓
直接调 MediaRemote 私有 IPC（com.apple.* 进程才能用）
   ↓ 不经过 NSSystemDefined / IOKit HID 任何公开层
当前 player app 收到（如果有）
```

这是 Apple 在 macOS Sonoma 时期改的设计。第三方 app 拦不到 Pro 2 的 stem 单击，**所有同类工具（Karabiner-Elements、SiriMote、AirPodsRemap）对 Pro 2 stem 都失效**。详见 [Karabiner-Elements Issue #2398](https://github.com/pqrs-org/Karabiner-Elements/issues/2398)（开 6 年未解决）。

**音量+/- 例外**：因为系统音量是 OS 级状态、不是 app 级命令，AirPods Pro 2 的 stem 上下滑必须走公开 NSSystemDefined 路径，CGEventTap 拦得到。所以本项目对 Pro 2 用户支持音量键映射。

唯一能工作的 hack 是 [MutePod](https://apps.apple.com/app/mutepod/id6473896725)（监听 mic 静音状态切换），但它跟「按住 Opt 录音」场景**自相矛盾**（按一下 mic 就被静音了，录什么）。

---

## 工作原理

`AirPodsRemap.swift`（单文件，~635 行 Swift / SwiftUI / Cocoa）

核心是一个 `CGEventTap`，注册在 `.cghidEventTap` 层级，事件 mask `1 << 14`（NSSystemDefined）。

```
AirPods 媒体键事件
  ↓
NSSystemDefined (type=14, subtype=8)
  ↓ EventTap.handle()
解码 data1：高 16 位 = 媒体键 keyCode (16=PLAY, 17=NEXT, 19=PREVIOUS)
            低 16 位的 0xFF00 = 按下 (0x0A) / 抬起 (0x0B)
  ↓
查 Config.single/double/triple → 拿到 (目标键, 模式)
  ↓
- 「点按」模式 → 模拟目标键 down + up（瞬时）
- 「按住」模式 → 维护 holdingKeys 字典，按下时 toggle：
    · 不在字典 → 模拟 down + 加入字典 + 图标变红
    · 在字典 → 模拟 up + 移出字典 + 图标恢复
  ↓
swallow 原始事件（return nil）
```

按住模式的安全机制：

- `EventTap.stop()` 和 `applicationWillTerminate` 都调用 `releaseAllHeld()`
- 防止 macOS 异常退出时 ⌥ 永久卡住

---

## 项目结构

```
.
├── AirPodsRemap.swift     源码（单文件 SwiftUI app）
├── AppIcon.icns           应用图标
├── make-icon.swift        图标生成脚本（首次构建时用）
├── build.sh               编译 universal binary（arm64 + x86_64）+ ad-hoc 签名
├── make-dmg.sh            打包 .dmg
├── package.sh             一键生成 dmg + zip
├── USAGE.txt              使用说明（dmg/zip 里的简版）
└── README.md              本文件
```

构建产物 `AirPodsRemap.app/` 和 `dist/` 在 `.gitignore` 里。

---

## 系统要求

- **macOS 13.0** (Ventura) 及以上
- Apple Silicon 或 Intel x86_64（universal binary）
- 蓝牙能配 AirPods

---

## 已知限制

1. **AirPods Pro 2 / Pro 3 的 stem 单击/双击/三击不支持**（音量+/- 可用，详见上方）
2. **长按手势无法拦截** —— 系统占用做 Siri / 降噪切换
3. **每次重新 `./build.sh` 后辅助功能权限会失效** —— ad-hoc 签名固有问题，需要重新授权
4. **配对到 Mac 后**，AirPods 单击 stem 在其他设备（iPhone / Apple TV）上的行为不变；只是 macOS 内的事件被拦截

---

## 贡献

欢迎 PR！特别是这些方向：

- [ ] 加 self-signed 证书或 Developer ID 签名，避免每次 build 后权限失效
- [ ] 加 GitHub Actions 自动构建 release
- [ ] AirPods 连接状态实时显示在状态栏
- [ ] 加可选「双击/三击」预设快捷键（截图、Spotlight 等）
- [ ] 英文 README

---

## 致谢

- [SiriMote](https://github.com/eternalstorms/SiriMote) — 拦截 NSSystemDefined 事件的祖师爷思路
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) — Issue #2398 帮我们确认了 Pro 2 stem 限制
- 所有为 macOS 第三方工具开路的逆向工程师们

---

## License

[MIT](LICENSE)

---

**项目主页：** <https://github.com/xiabill/airpods-remap>
**问题反馈：** [Issues](https://github.com/xiabill/airpods-remap/issues)
