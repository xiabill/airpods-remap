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
| **AirPods Pro 2 / Pro 3** | ❌ **不支持**（实测确认） | Apple 把 Pro 2 的 stem 事件**全部**路由到 MediaRemote 私有 IPC，**包括音量+/- 也拦不到**。v1.3 曾推测音量键能在 Pro 2 工作（理论上音量必须走公开路径），但用户实测仍然失败。第三方工具完全束手无策，Karabiner-Elements、SiriMote 都一样失效。 |

**Pro 2 / Pro 3 用户的现实**：本项目（以及任何同类工具）在 macOS 上**完全无法**拦截 Pro 2 的 stem 事件。详见下方「为什么 Pro 2 不工作」。

---

## 功能

- **五种手势**：单击 / 双击 / 三击 stem + 音量+ / 音量-（stem 上下滑），分别可独立映射
- **音量键映射默认关闭** —— 启用后会失去 AirPods 调系统音量的能力，需用户主动开
- **两种触发模式**：
  - **「点按」**：按一下 → 立即按下并释放（适合 ⌘Space、F13 等普通快捷键）
  - **「按住」**：按一下进入按住状态，再按一下释放（**专为 Typeless / WhisperKey 这种长按 Opt 录音的应用设计**）
- **🆕 任意组合键映射（v2.0）**：每个手势可挂 1 到 N 个按键，触发时按数组顺序「同时按下」。比如把双击设成 `⌘ + V`、三击设成 `⌘ + ⇧ + V`。修饰键的 flags 自动累加，不会出现「⌘ 按下但 V 没收到 ⌘」的脏状态。
- **65+ 个可选按键**：修饰键（左右分别的 ⌥/⌘/⌃/⇧/Fn）、F13–F20、字母键 A–Z、数字键 0–9、Space/Return/Esc/Tab、Delete ⌫ / Forward Delete ⌦。任意搭配组合。
- **左右修饰键独立**：Left Option ⌥ 跟 Right Option ⌥ 在 macOS 内核里是不同 keyCode（58 vs 61），AirPodsRemap 严格区分。某些专业软件（IDE / 视频编辑等）只识别特定一侧 —— 这时候能精确指定就有意义。
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

# (强烈推荐，一次性) 创建本地 self-signed code signing 证书
# 让以后任何 ./build.sh 之后辅助功能权限不再失效
./setup-codesign.sh

./build.sh                                  # 生成 AirPodsRemap.app
open AirPodsRemap.app
```

第一次运行后在系统设置里授权辅助功能，然后重启 app。**之后再 `./build.sh` 多少次权限都保留**（前提是跑过 setup-codesign.sh）。

#### 为什么要 setup-codesign.sh？

macOS 的 TCC（辅助功能权限数据库）用 app 的 **designated requirement** 作为身份键：

- **ad-hoc 签名**（默认 fallback，`codesign --sign -`）→ DR 包含 binary cdhash，重 build 后 hash 变 → DR 变 → TCC 视作新 app → 权限失效
- **self-signed 证书签名** → DR 包含证书指纹（不变）→ 重 build 后 hash 变但 DR 不变 → 权限保留

`setup-codesign.sh` 用 OpenSSL 生成一个 10 年有效期的本地证书，导入登录钥匙串并标记为 codeSign 信任。**只在一台电脑上跑一次**。从此 `build.sh` 自动检测并优先用这个证书签名；没找到则 fallback 到 ad-hoc。

---

## 快速上手 — 配 Typeless 用

这是本工具最典型的使用场景。

### 1. 装好 [Typeless](https://typeless.dev/)，把它的快捷键设为 **按住 Left Option (⌥)**

   按住 Opt → 录音 → 松开 Opt → 转写并粘贴。

### 2. 在 AirPodsRemap 配置面板里把「单击」设为：

   - 启用 ✅
   - 按键：**Left Option ⌥**（只一个）
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
| **单/双/三击/音量+/音量- 行** | 每行：启用 toggle、按键列表（每个按键独立一行 + 可加减）、模式 segmented control |
| **+ 添加按键（组合）** | 给当前手势再挂一个按键，组成 chord（最多任意多个，按数组顺序同时按下） |
| **重置默认** | 单击=按住⌥（Typeless 友好），双/三击禁用，音量+/-禁用 |
| **开机自启动** | macOS 13+ ServiceManagement API 实现 |

右键状态栏图标可以快速切换运行状态、打开授权设置、退出。

---

## 组合键映射示例（v2.0+）

每个手势可以挂任意多个按键。触发时按数组顺序「同时按下」，flags 自动累加修饰键状态。常见用法：

| 你想要的快捷键 | 按键列表（按数组顺序） |
|---|---|
| 粘贴 `⌘V` | `Left Command ⌘` → `V` |
| 粘贴并匹配样式 `⌘⌥⇧V` | `Left Command ⌘` → `Left Option ⌥` → `Left Shift ⇧` → `V` |
| 关闭标签 `⌘W` | `Left Command ⌘` → `W` |
| Spotlight `⌘Space` | `Left Command ⌘` → `Space 空格` |
| App 切换 `⌘Tab` | `Left Command ⌘` → `Tab` |
| 全屏截图 `⌘⇧3` | `Left Command ⌘` → `Left Shift ⇧` → `3` |

**步骤**：

1. 左键状态栏图标打开配置面板
2. 找到要配置的手势行（单击 / 双击 / 三击 / 音量+ / 音量-）
3. 启用 toggle
4. 点 **「+ 添加按键（组合）」** 添加第一个按键，从下拉选 `Left Command ⌘`
5. 重复 4 直到所有按键都加好（修饰键放前面，base key 放最后）
6. 选「点按」或「按住」模式
7. 改动即时生效，自动保存

**注意：左右修饰键独立**。Left Option ⌥（keyCode 58）和 Right Option ⌥（keyCode 61）在 macOS 里是两个不同的按键。某些专业软件只识别其中一侧 —— 这时按需选对应的那个。

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

如果你**没跑过** `setup-codesign.sh`，那是 ad-hoc 签名每次 build 后 hash 变化导致的，重新授权一次即可。**长期解决**：在源码目录下跑：

```bash
./setup-codesign.sh    # 一次性
```

之后再 `./build.sh` 多少次都不会失效（详见上方「方式 B：从源码构建」）。

### 暂停 / 退出后 Opt 卡住怎么办

正常情况下 app 退出会自动释放所有按住的键。如果异常卡住：

- 在状态栏点暂停或重启 app
- 或在终端按一下 ESC

### 我有 AirPods Pro 2，能用吗

**不能。** 实测所有 stem 手势（单击/双击/三击/上下滑）在 macOS 上都拦不到 —— Apple 把它们全部路由到 MediaRemote 私有 IPC。要做 vibe coding 类工作流，**只能用普通 AirPods 或 AirPods Max**。

---

## 为什么 Pro 2 不工作

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

这是 Apple 在 macOS Sonoma 时期改的设计。第三方 app 拦不到 Pro 2 的任何 stem 事件，**所有同类工具（Karabiner-Elements、SiriMote、AirPodsRemap）对 Pro 2 都失效**。详见 [Karabiner-Elements Issue #2398](https://github.com/pqrs-org/Karabiner-Elements/issues/2398)（开 6 年未解决）。

> 关于音量+/- 的更正：v1.3 发布时曾推测「系统音量是 OS 级状态、必须走公开 NSSystemDefined 路径，所以音量键应该可以拦」。理论上没错，但用户实测确认 Pro 2 上音量键事件**也**进不到 CGEventTap。Apple 似乎给 Pro 2 做了完整的 MediaRemote 路由，无视事件类别。本项目的音量+/- 映射只对**普通 AirPods / AirPods Max** 有效。

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
├── setup-codesign.sh      一次性创建 self-signed code signing 证书
├── build.sh               编译 universal binary（arm64 + x86_64）+ 签名
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

1. **AirPods Pro 2 / Pro 3 完全不支持**（包括音量键，详见上方）
2. **长按手势无法拦截** —— 系统占用做 Siri / 降噪切换
3. **每次重新 `./build.sh` 后辅助功能权限会失效** —— ad-hoc 签名固有问题；跑一次 `./setup-codesign.sh` 切到 self-signed 证书后永久解决
4. **配对到 Mac 后**，AirPods 单击 stem 在其他设备（iPhone / Apple TV）上的行为不变；只是 macOS 内的事件被拦截

---

## 贡献

欢迎 PR！特别是这些方向：

- [x] ~~加 self-signed 证书签名~~ (v1.4.0 已加，跑 `./setup-codesign.sh`)
- [ ] 用付费 Apple Developer ID 做 codesign + notarize，让普通用户下载 dmg 时不再被 macOS 拦下
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
