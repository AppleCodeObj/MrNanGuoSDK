import UIKit
public extension String {
    static func mngRandomToken() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let length = Int.random(in: 3...15)
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
    static func mngCallbackNamespace() -> String{
        let characters = "abcdefghijklmnopqrstuvwxyz"
        return String(characters.randomElement() ?? "a")
    }

    static func mngRandomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
    static func mngJSONString(from dictionary: [String: Any]) -> String? {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }
    static func mngReadClientIdentifier() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Bundle.main.bundleIdentifier ?? "",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    var mngHardwareIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }
    var mngClientIdentifier: String{
        var value = String()
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        if let saved = String.mngReadClientIdentifier(),!saved.isEmpty{
            return saved
        }else{
            value = String.mngRandomString(length: 21)
            mngStoreClientIdentifier(value: value, for: bundleId)
            return value
        }
    }
    var  mngDevicePayload : String {
        var deviceInfo: [String: Any] = [:]
        deviceInfo[String.mngRandomToken() + "ua"] = String().mngHardwareIdentifier
        return  String.mngJSONString(from:deviceInfo) ?? ""
    }
 


    func mngStoreClientIdentifier(value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
public extension UIWindow {
    static var mngActiveWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            let windowScene: UIWindowScene? = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            if window != nil {
                return window
            }
        }
        let window = UIApplication.shared.keyWindow
        if window != nil {
            return window
        }
        return UIApplication.shared.windows.first
    }

}

