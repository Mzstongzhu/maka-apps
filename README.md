# 玛卡之声 iOS 客户端（未签名构建）

玛卡之声社区与玛卡管理面板的 Flutter 源码，通过 GitHub Actions 的云端 macOS
自动构建 **未签名 IPA**。无需在本地安装 Xcode，也不需要 Apple 开发者账号即可出包。

## 目录

| 目录 | 应用 | Bundle ID |
| --- | --- | --- |
| `community/` | 玛卡之声社区（完整功能） | `xyz.makazs.maka` |
| `admin/` | 玛卡管理面板（管理员用） | `xyz.makazs.makaadmin` |

最低系统：**iOS 15 / iPadOS 15 及以上**（当前 Flutter 稳定版的官方下限）。

## 如何获取 IPA

1. 本仓库 **Actions** 页签 → 选择 `build-ios-unsigned` → `Run workflow`
2. 构建约 15–25 分钟，完成后在该次运行底部 **Artifacts** 下载两个 zip，
   解压即为 `.ipa`
3. 推送 `ios-x.y.z` 标签时，IPA 会同时发布到 **Releases（预发布）**

`ios/` 原生工程目录由 CI 用 `flutter create --platforms=ios` 现场生成，
Info.plist 权限文案、Bundle ID、应用图标在工作流里自动配置。

## 未签名 IPA 如何安装（重要）

未签名 IPA **无法直接安装**到未越狱的 iPhone，三选一：

| 方式 | 成本 | 有效期 | 适合 |
| --- | --- | --- | --- |
| **Sideloadly / AltStore**（Apple ID 自签） | 免费 | **7 天**，到期重签 | 少量测试机 |
| **Apple Developer 账号**（$99/年） | 付费 | 1 年；可 TestFlight 公测、可多设备 | 正式分发 |
| 第三方企业签名/超级签 | 按设备付费，不稳定 | 不定 | 不推荐 |

用 Sideloadly 安装：电脑装 Sideloadly → 手机连电脑 → 拖入 IPA →
输入 Apple ID → 安装后在 iPhone「设置-通用-VPN与设备管理」信任自己的证书。
免费 Apple ID 同时最多签 3 个 App，7 天后需重新操作。

## 老设备怎么办

- iPhone 6s / 第一代 SE 及以后机型均可升级 iOS 15，使用本 IPA
- iPhone 5s / 6 / 6 Plus（最高只能留在 iOS 12）请用浏览器访问兼容版网页：
  **https://makazs.xyz/old/** （iOS 11+ Safari 可直接用，旧浏览器访问主站会自动跳转）
