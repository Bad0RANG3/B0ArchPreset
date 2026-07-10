# B0ArchPreset — 一键部署 Shorin DMS + niri 桌面环境

在刚安装好的 **Arch Linux** 或任意 Arch 体系衍生版上，一条命令即可自动配置出与 [Shorin DMS](https://github.com/SHORiN-KiWATA/shorin-dms-niri-git) 完全一致的 niri 桌面环境。

> 不需要自己装桌面、配输入法、调主题、写配置。脚本从头到尾自动完成，装完重启即可使用。

## 适用环境

- **Arch Linux** 或 **Arch 系发行版**（CachyOS、EndeavourOS、Garuda、Manjaro、ArcoLinux 等）
- systemd 启动
- x86_64
- 已联网

## 使用方法

在刚装好的系统上（**root 用户下**或使用 **sudo**）：

```bash
pacman -Sy --noconfirm git
git clone https://github.com/Bad0RANG3/B0ArchPreset.git
cd B0ArchPreset
sudo bash install.sh
```

等待脚本跑完，看到 `现在请重启: systemctl reboot` 的提示后：

```bash
reboot
```

重启后会出现 SDDM 登录界面，选择 **niri** 会话即可进入 Shorin DMS 桌面。

## 可自定义参数

如果你需要指定用户名、主机名或时区，通过环境变量传入即可，不设置脚本会自动检测：

```bash
sudo TARGET_USER=yourname TARGET_HOSTNAME=myhost TARGET_TIMEZONE=Europe/London bash install.sh
```

| 变量 | 说明 | 默认值 |
|---|---|---|
| `TARGET_USER` | 目标普通用户 | 自动检测（UID 1000 或 sudo 用户） |
| `TARGET_HOSTNAME` | 主机名 | `archlinux` |
| `TARGET_TIMEZONE` | 时区 | `Asia/Shanghai` |
| `TARGET_LOCALE` | 系统语言 | `zh_CN.UTF-8` |
| `TARGET_SHELL` | 用户默认 shell | `/usr/bin/fish` |
| `AUR_HELPER` | AUR 辅助工具 | `yay` |

## 装了什么

### 桌面核心
- **niri** — Wayland 滚动平铺窗口管理器
- **Shorin DMS** — 基于 quickshell 的桌面 shell，含设置面板、剪贴板、电源菜单、应用启动器
- **SDDM** + sugar-candy 主题

### 终端 & 工具
- **Kitty** 终端 + DMS 深色主题
- **Fish** shell + Starship 提示符
- **fuzzel** 应用启动器
- **fastfetch** / **btop** / **yazi** / **zoxide**

### 输入法
- **fcitx5**（shorin-patched）+ **Rime-ice** 词库
- 键盘布局 `us`，Super+Space 切换输入法

### 主题
- **matugen** 自动从壁纸取色，同步 GTK/kitty/fcitx5/btop/starship/fuzzel/fastfetch 配色
- **adw-gtk-theme** 深色 + Adwaita 光标

### 驱动
- 自动检测 CPU/GPU，安装对应微码与显卡驱动
- NVIDIA 现代卡按 open 驱动安装

### 常用软件（可选）
QQ、微信、VS Code、Edge、网易云音乐、mpv、OBS、qemu/virt-manager、Wine、Python/Node.js 开发套件等。这些安装失败不影响桌面部署。

## 中途失败怎么办

脚本每个阶段完成后会记录状态，再次运行 `sudo bash install.sh` 会从中断处继续。强制重跑全部：

```bash
sudo bash install.sh --force
```

如果某个环节持续失败，错误信息会标明具体环节名。把以下信息发给 AI 助手即可定位：

- 失败的**环节名称**（脚本会在终端输出）
- `tail -n 80 /var/log/bad0rang3-shorin-niri-install.log`
- `cat /etc/os-release`

## 已知限制

- 不支持非 systemd、非 x86_64、非 pacman 的发行版
- 不安装第三方内核（可自行追加）
- 显示器输出由 niri/DMS 自动识别，无需手动配置
- 如果你有特殊显示器需求，装完后编辑 `~/.config/niri/dms/outputs.kdl` 即可

## License

MIT
