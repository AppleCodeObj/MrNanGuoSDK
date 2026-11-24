# MrNanGuoSDK

iOS 16+ / Swift 5 的独立 CocoaPods 静态 Framework 项目。只有三个业务源码文件，不包含 App、示例登录页面或图片资源：

```text
MrNanGuoSDK/
├── Sources/
│   ├── MNGEntryViewController.swift
│   ├── MNGSessionService.swift
│   └── MNGPlatformExtensions.swift
├── MrNanGuoSDK.podspec
├── MrNanGuoSDK.xcodeproj
├── MrNanGuoSDK.xcworkspace
├── Podfile
└── Podfile.lock
```

## 开发和编译库

已安装 Alamofire 依赖。打开 `MrNanGuoSDK.xcworkspace`，选择 `MrNanGuoSDK` scheme 和 iOS 设备或模拟器，执行 Product → Build（⌘B）。这是库项目，没有可运行的 App target。

重新安装依赖：

```sh
cd ~/Desktop/MrNanGuoSDK
pod install
```

命令行编译：

```sh
xcodebuild -workspace MrNanGuoSDK.xcworkspace \
  -scheme MrNanGuoSDK -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Xcode target 设置 `MACH_O_TYPE = staticlib`，podspec 设置 `static_framework = true`。
`pod install` 提示没有 host target 是纯库项目的正常提示。

## 在其他 App 中使用

在宿主 App 的 Podfile 中添加以下内容（target 名称换成实际 App 名称）：

```ruby
platform :ios, '16.0'

target 'YourApp' do
  use_frameworks! :linkage => :static
  pod 'MrNanGuoSDK', :path => '/Users/mac/Desktop/MrNanGuoSDK'
end
```

执行 `pod install` 并打开宿主的 `.xcworkspace`。
CocoaPods 会自动编译这三个源码文件并安装 Alamofire 依赖。无需再手动拖入本项目构建的 Framework。

## 外部配置

在宿主 App 的主线程上、创建库页面或发起登录请求之前配置：

```swift
import UIKit
import MrNanGuoSDK

MrNanGuoSDK.configure(.init(
    launchImage: UIImage(named: "YourLaunchImage"),
    loginURL: URL(string: "https://your-server.example/login")!,
    makeLoginViewController: { YourLoginViewController() }
))
window?.rootViewController = MrNanGuoSDK.makeRootViewController()
```

- `launchImage`：宿主加载后传入的图片，允许为 `nil`，用于库中的所有启动占位图。
- `loginURL`：宿主提供的 HTTP(S) 登录接口，无内置业务地址。
- `makeLoginViewController`：当没有缓存登录地址时，调用此闭包创建宿主登录页面；可以返回导航控制器。

`YourLoginViewController` 由宿主 App 自行实现，不属于库。本库不含 `@main`、AppDelegate、Storyboard、entitlements 或宿主图片。
SceneDelegate 项目请使用对应 scene 的 window。

## 宿主登录对接

保留原有登录请求方法和服务端协议。以一键登录为例：

```swift
MNGSessionService.shared.requestLogin(
    type: "\(String.mngRandomToken())cl",
    code: String().mngClientIdentifier
) { path in
    guard let path = path else {
        // 请求或解析失败，由宿主提示。
        return
    }
    guard !path.isEmpty else {
        // 没有返回网页地址，由宿主继续自己的登录流程。
        return
    }
    // 登录地址已由库保存。
    self.view.window?.rootViewController = MrNanGuoSDK.makeWebViewController()
}
```

苹果登录传入 `type: "\(String.mngRandomToken())ap"` 和 Apple authorization code。
账号密码登录传入 `type: "\(String.mngRandomToken())pw"` 和 `Data("\(account),\(password)".utf8).base64EncodedString()`。
登录按钮、输入框、Apple 授权流程、错误提示及宿主自己的登录逻辑均由宿主实现。

## 随机缓存 key

首次使用生成 UUID，UUID 本身保存在当前 App 的 UserDefaults 中。启动判断、登录成功写入、WebView 加载读取都共用这个随机 key，App 重启后也保持一致。每个宿主 App 的记录独立。清除 App 数据后会重新生成。
原项目的 `login_success` 和旧 `ReactWeb` 命名空间的缓存不迁移，首次接入需重新登录。

## 宿主权限

定位功能需要宿主在 Info.plist 设置 `NSLocationWhenInUseUsageDescription`。
宿主如实现 Apple 登录，需要启用 Sign in with Apple capability。相机、麦克风等权限按宿主实际网页功能配置。

## CocoaPods 发布与版本

源码仓库：https://github.com/AppleCodeObj/MrNanGuoSDK

公共 Specs 中发布成功后，宿主可使用：

```ruby
pod 'MrNanGuoSDK', '~> 1.0'
```

也可以直接从 Git tag 接入：

```ruby
pod 'MrNanGuoSDK', :git => 'https://github.com/AppleCodeObj/MrNanGuoSDK.git', :tag => '1.0.0'
```

维护者发布新版本时，先更新 podspec 版本号、提交源码并推送同名 tag，再执行：

```sh
pod spec lint MrNanGuoSDK.podspec --allow-warnings
pod trunk push MrNanGuoSDK.podspec --allow-warnings
```

静态 Framework 的代码会链接进宿主 App。手动分发 Framework 时还需处理 Alamofire、设备/模拟器架构及 Swift 编译器兼容性；建议使用上述 CocoaPods 源码接入方式。

## 命名约定

库自有类型采用 `MNG` 前缀；String、UIWindow 扩展采用 `mng` 前缀，降低与宿主扩展的命名冲突。主入口保持 `MrNanGuoSDK`。登录接口为 `MNGSessionService.shared.requestLogin(type:code:completion:)`。
