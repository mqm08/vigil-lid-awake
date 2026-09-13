<p align="center">
  <img src="docs/icon.png" width="128" alt="Vigil icon">
</p>

<h1 align="center">守夜 Vigil</h1>

<p align="center">
  <b>合上盖子,我替你守着。</b><br>
  让 MacBook 合盖后继续运行的菜单栏小工具——带低电量保护和过热暂停,<br>
  专为让 Claude Code、Codex 这类 AI 编程助手通宵干活而做。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Apple%20Silicon-native-orange" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
</p>

<p align="center">
  <img src="docs/panel-light.png" width="330" alt="浅色模式">
  &nbsp;&nbsp;
  <img src="docs/panel-dark.png" width="330" alt="深色模式">
</p>

---

## 为什么需要它

macOS 合上盖子就会休眠,跑到一半的任务直接暂停。系统自带的 `caffeinate`、以及 KeepingYouAwake 这类工具**都拦不住合盖休眠**——合盖是硬件触发的,只有 `SleepDisabled` 这个系统标志位能压住它。

但直接开这个标志位很危险:电量耗尽强制关机、塞进包里闷到发烫,都没人管。

**守夜**把这件事做成了一个安全的开关。

## 功能

| | |
|---|---|
| 🌙 **合盖继续运行** | 无需外接显示器,电池供电也能用 |
| 🔋 **低电量自动关闭** | 未接电源且电量低于阈值(5%–50% 可调)时,自动恢复休眠 |
| 🌡️ **过热自动暂停** | 实时读取机身温度与系统热压力,超限暂停,降温 5°C 后自动恢复 |
| ⏱️ **定时关闭** | 30 分钟 / 1 / 2 / 4 小时,面板上显示倒计时 |
| 🔌 **仅充电时生效** | 拔掉电源立即恢复休眠 |
| ⚡ **插电自动开启** | 插上电就守夜,拔掉就恢复 |
| 🚪 **无人登录时恢复** | 注销后自动恢复正常休眠,不会一直醒着 |
| 🧯 **冲突检测** | 发现其他程序在修改休眠设置时提醒你 |
| 🇨🇳 **中文原生界面** | SwiftUI 编写,自动适配浅色 / 深色模式 |

## 安装

**不需要终端,不需要开发工具。**

1. 下载最新版 [**Vigil.dmg**](https://github.com/mqm08/vigil-lid-awake/releases/latest/download/Vigil.dmg)
2. 双击打开,把 **守夜** 拖进「应用程序」
3. 打开守夜,菜单栏会出现 🌙,点开面板,点 **「一键安装」**
4. 系统会弹出密码框,输入开机密码即可

之后所有操作都在面板里完成,不再需要密码。守夜中,菜单栏图标会变成**琥珀色的星月**。

<details>
<summary><b>打开时提示「无法验证开发者」怎么办?</b></summary>

守夜是免费开源项目,没有购买苹果开发者证书,所以首次打开会被系统拦截。二选一:

- 打开 **系统设置 → 隐私与安全性**,滚到底部,找到守夜,点 **「仍要打开」**
- 或在终端运行:
  ```bash
  xattr -dr com.apple.quarantine /Applications/Vigil.app
  ```

源码全部公开,可以自行审阅或从源码构建。
</details>

<details>
<summary><b>从源码安装(开发者)</b></summary>

需要 Xcode Command Line Tools(`xcode-select --install`)。

```bash
git clone https://github.com/mqm08/vigil-lid-awake.git
cd vigil-lid-awake
sudo ./install.sh
```
</details>

## 卸载

面板右下角 **⋯ → 卸载守夜**,会移除后台服务、设置和应用本身,休眠行为恢复为系统默认。

从源码安装的也可以用 `sudo ./uninstall.sh`。

## 常见问题

**守夜时断时续,面板提示「有其他程序在修改休眠设置」?**
Amphetamine、Lidless、KeepingYouAwake 等同类工具也会修改休眠设置,同时运行会互相覆盖。关掉其他工具即可。

## 工作原理

```
┌─────────────────────┐   写入意图(无需权限)    ┌──────────────────────────┐
│  Vigil.app          │ ───────────────────────▶ │ ~/.config/vigil/         │
│  菜单栏面板 (用户)   │                          │   config.json            │
└─────────────────────┘                          └────────────┬─────────────┘
          ▲                                                   │ 每 30 秒读取
          │ 读取状态                                           ▼
┌─────────┴───────────┐                          ┌──────────────────────────┐
│ /var/run/           │ ◀─────────────────────── │  vigild  (root, launchd) │
│   vigil.state.json  │        写入状态           │  电量/温度检查 → pmset    │
└─────────────────────┘                          └──────────────────────────┘
```

- **界面进程**以普通用户身份运行,只负责展示和写配置,**从不调用 `pmset`**。
- **守护进程** `vigild` 由 launchd 以 root 身份每 30 秒唤起一次,是唯一修改系统休眠设置的组件。它读取你的意图,叠加所有安全检查后,再决定是否设置 `SleepDisabled`。
- 温度数据来自 IORegistry 中的 `AppleSmartBattery` 与 `NSProcessInfo.thermalState`,均为系统自带接口,零第三方依赖。
- 界面意外退出时,守护进程会在下一次检查中按配置继续执行;点击「退出」会同时关闭守夜。

> **为什么不用 `SMAppService` 注册特权助手?** 在部分 macOS 版本上,它的注册流程会静默失败且不弹出授权窗口。经典的 LaunchDaemon 方式行为可预期、容易排查,卸载也彻底。

## 安全说明

- 守护进程只执行 `pmset -a disablesleep 0|1`,不做其他任何特权操作,源码仅约 150 行,可在 [`daemon/`](daemon) 中审阅。
- 任何以你身份运行的程序都能修改配置文件来开启守夜。最坏的结果是「该休眠时没休眠」,不涉及数据或权限风险。
- 重启电脑、卸载应用,都会让休眠行为回到系统默认。
- 合盖高负载运行会发热。即使有过热保护,也**请放在通风处,不要装进包里**。

## 日志

```bash
tail -f /var/log/vigil.log
```

## 从源码构建

```bash
./build.sh          # 产物: build/Vigil.app
./build.sh --dmg    # 同时打包 build/Vigil.dmg
```

项目结构:

```
App/Sources/        SwiftUI 菜单栏应用
daemon/             root 守护进程 (Python, 使用系统自带 /usr/bin/python3)
scripts/            图标渲染、截图生成
install.sh          安装
uninstall.sh        卸载
```

## 致谢

灵感来自 [Lidless](https://github.com/nghialuong/Lidless)、[Sleepless](https://github.com/Aboudjem/Sleepless) 与 [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704)。

## License

[MIT](LICENSE)
