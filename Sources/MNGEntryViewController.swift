import UIKit
import WebKit
import Alamofire

/// Configure once on the main thread before creating any library screens.
public enum MrNanGuoSDK {
    public struct Configuration {
        public let launchImage: UIImage?
        public let loginURL: URL
        public let makeLoginViewController: () -> UIViewController

        public init(launchImage: UIImage?, loginURL: URL,
                    makeLoginViewController: @escaping () -> UIViewController) {
            self.launchImage = launchImage
            self.loginURL = loginURL
            self.makeLoginViewController = makeLoginViewController
        }
    }

    private static var storedConfiguration: Configuration?
    static var configuration: Configuration {
        guard let configuration = storedConfiguration else {
            preconditionFailure("Call MrNanGuoSDK.configure before using MrNanGuoSDK.")
        }
        return configuration
    }

    public static func configure(_ configuration: Configuration) {
        precondition(Thread.isMainThread, "Configure MrNanGuoSDK on the main thread.")
        precondition(["https", "http"].contains(configuration.loginURL.scheme?.lowercased() ?? "")
                     && configuration.loginURL.host != nil, "loginURL must be an HTTP(S) URL.")
        storedConfiguration = configuration
    }

    // Persist the generated key itself so every read/write and subsequent launch uses the same key.
    static let loginStorageKey: String = {
        let registryKey = "MrNanGuoSDK.loginStorageKey.v1"
        let defaults = UserDefaults.standard
        if let key = defaults.string(forKey: registryKey), !key.isEmpty {
            return key
        }
        let key = UUID().uuidString
        defaults.set(key, forKey: registryKey)
        return key
    }()

    public static func makeRootViewController() -> UIViewController {
        _ = configuration
        return MNGEntryViewController()
    }

    public static func makeWebViewController() -> UIViewController {
        _ = configuration
        return MNGWebContentViewController()
    }
}

class MNGEntryViewController: UIViewController {
    lazy var launchImageView : UIImageView = {
        let image = UIImageView(frame: self.view.bounds)
        image.image = MrNanGuoSDK.configuration.launchImage
        return image
    }()
    private let reachabilityMonitor: NetworkReachabilityManager? = .default
    override func viewDidLoad() {
        super.viewDidLoad()
        reachabilityMonitor?.startListening(onUpdatePerforming: { _ in })
        launchImageView.frame = self.view.bounds
        self.view .addSubview(launchImageView)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let destinationURL = String(format: "%@", UserDefaults.standard.string(forKey: MrNanGuoSDK.loginStorageKey) ?? "")
        if(destinationURL.isEmpty){
            DispatchQueue.main.async {
                (self.view.window ?? UIWindow.mngActiveWindow)?.rootViewController = MrNanGuoSDK.configuration.makeLoginViewController()
            }
        }else{
            DispatchQueue.main.async {
                (self.view.window ?? UIWindow.mngActiveWindow)?.rootViewController =  MNGWebContentViewController()
            }
        }
    }
}
    
    class MNGWebContentViewController: UIViewController {
        private lazy var loadingIndicator: UIActivityIndicatorView = {
            let indicator = UIActivityIndicatorView(style: .large)
            indicator.hidesWhenStopped = true
            indicator.translatesAutoresizingMaskIntoConstraints = false
            return indicator
        }()
        lazy var launchImageView : UIImageView = {
            let image = UIImageView(frame: self.view.bounds)
            image.image = MrNanGuoSDK.configuration.launchImage
            return image
        }()
        lazy var contentWebView: WKWebView = {
            let userContentController = WKUserContentController()
            userContentController.add(self, name: "a")
            let config = WKWebViewConfiguration()
            config.userContentController = userContentController
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.navigationDelegate = self
            webView.scrollView.delegate = self
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.scrollView.alwaysBounceVertical = false
            webView.allowsBackForwardNavigationGestures = true
            return webView
        }()
        
        
        override func viewDidLoad() {
            super.viewDidLoad()
            self.contentWebView.frame = self.view.bounds
            self.view .addSubview(self.contentWebView)
            self.launchImageView.frame = self.view.bounds
            self.view .addSubview(self.launchImageView)
            self.view.addSubview(self.loadingIndicator)
            NSLayoutConstraint.activate([
                loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
            loadStoredPage()    
        }
        @objc private func  loadStoredPage(){
            self.loadingIndicator.startAnimating()
            if let destinationURL = URL(string:  UserDefaults.standard.string(forKey: MrNanGuoSDK.loginStorageKey) ?? "") {
                self.contentWebView.load(URLRequest(url: destinationURL))
            }
        }
        @objc private  func dismissLoadingPlaceholder(){
               self.loadingIndicator.stopAnimating()
                self.launchImageView.isHidden = true
                self.launchImageView .removeFromSuperview()
        }
    }
    extension MNGWebContentViewController: WKNavigationDelegate,UIScrollViewDelegate, WKScriptMessageHandler  {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.dismissLoadingPlaceholder()
            MNGSessionService.shared.publishPermissionState(webView: self.contentWebView)
            
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            MNGSessionService.shared.handleScriptMessage(webView: self.contentWebView, message: message)
        }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let newOffset = scrollView.contentOffset
            if newOffset.y > 0 {
                scrollView.contentOffset = .zero
            }
        }
    }

