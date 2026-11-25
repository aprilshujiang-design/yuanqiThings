# 元气小事

一个用 SwiftUI 构建的 iOS 高能量小事打卡 App。

## 功能

- 两列网格形式的按日期小事打卡与 `+1 元气` 即时正反馈
- 支持周视图快速切换及月历选择，为任意过去日期补记，未来日期不可打卡
- 首页使用独立的粉色晨光元气插画背景
- 首页显示所选日期实际完成的小事数量
- 今日小胜利、月度小胜利与连续元气统计
- 五档能量强度日历与每日完成详情
- 自定义新增、编辑和删除小事，并可选最多 8 件常用小事
- 内置丰富的高能量小事可选库，每日只统计实际完成数，不设置必须全部完成的目标
- 本地 JSON 快照持久化，支持导出和恢复备份
- 通过 CloudKit 私有数据库在用户设备间合并同步记录
- WidgetKit 小组件：主屏小号状态展示和中号交互打卡
- App 与小组件通过 `group.com.april.smallwins` App Group 双向共享数据

## 运行

1. 使用 Xcode 16 或更高版本打开 `YuanQiThings.xcodeproj`。
2. 在 Signing & Capabilities 中选择自己的开发团队。
3. 确认主 App 和 `YuanQiWidget` Target 都启用了 App Groups 和 iCloud/CloudKit。
4. 将 App Group、CloudKit Container 和 Bundle Identifier 替换为自己开发者账户下的标识。
5. 选择 iOS 17 或更高版本的模拟器或真机运行。

安装后长按主屏幕进入编辑状态，搜索“元气小事”即可添加小组件。中号小组件可直接完成或取消常用小事。

工程默认 Bundle Identifier 为 `com.april.smallwins`。
