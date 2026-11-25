import XCTest
import UIKit
@testable import MrNanGuoSDK

final class LoginConfigurationTests: XCTestCase {
    func testInvalidEndpointsDoNotCrashStartupAndReturnFailure() {
        let addresses: [URL?] = [
            nil,
            URL(string: ""),
            URL(string: "example.com"),
            URL(string: "/login"),
            URL(string: "https:/login"),
            URL(string: "ftp://example.com/login"),
        ]
        let finished = expectation(description: "Every invalid endpoint completes once")
        finished.expectedFulfillmentCount = addresses.count
        finished.assertForOverFulfill = true
        let defaults = UserDefaults.standard
        let key = MrNanGuoSDK.loginStorageKey
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue = previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        DispatchQueue.main.async {
            defaults.set("https://example.com/existing-session", forKey: key)
            for address in addresses {
                MrNanGuoSDK.configure(.init(
                    launchImage: nil,
                    loginURL: address,
                    makeLoginViewController: { UIViewController() }
                ))
                let root = MrNanGuoSDK.makeRootViewController()
                root.loadViewIfNeeded()
                var returnedFromRequest = false
                MNGSessionService.shared.requestLogin(type: "test", code: "unused") { path in
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(returnedFromRequest, "Failure must be delivered asynchronously")
                    XCTAssertNil(path)
                    XCTAssertEqual(defaults.string(forKey: key), "https://example.com/existing-session")
                    finished.fulfill()
                }
                returnedFromRequest = true
            }
        }
        wait(for: [finished], timeout: 5)
    }

    func testValidHTTPSEndpointIsPreserved() {
        let finished = expectation(description: "Valid configuration")
        DispatchQueue.main.async {
            for text in ["https://example.com/login", "http://127.0.0.1/login"] {
                let address = URL(string: text)!
                MrNanGuoSDK.configure(.init(
                    launchImage: nil, loginURL: address,
                    makeLoginViewController: { UIViewController() }
                ))
                XCTAssertEqual(MrNanGuoSDK.configuration.loginURL, address)
                XCTAssertTrue(MrNanGuoSDK.makeRootViewController() is MNGEntryViewController)
            }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }
}
