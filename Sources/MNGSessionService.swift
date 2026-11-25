import UIKit
import WebKit
import CoreLocation
import Alamofire

public final class MNGSessionService: NSObject {
    public static let shared = MNGSessionService()
    var locationAuthorizationFlag = Int()
    var locationProvider: CLLocationManager!
    var locationCompletion: ((CGFloat, CGFloat, Bool) -> Void)?
    private  override init() {
        super.init()
        locationProvider = CLLocationManager()
        locationProvider.delegate = self
        
    }
   

    func requestAuthorizedLocation(completion: @escaping (CGFloat, CGFloat, Bool) -> Void) {
        self.locationCompletion = completion
        let authorizationStatus = CLLocationManager.authorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            locationProvider.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationProvider.startUpdatingLocation()
        default:
            locationAuthorizationFlag = 0
            completion(0, 0, false)
            locationProvider.stopUpdatingLocation()
        }
    }
    
    
    
 
    func handleScriptMessage(webView:WKWebView,message:WKScriptMessage){

        guard let messageBody = message.body as? [String: Any] else { return }
        let identifierFields = messageBody.filter { $0.key.hasSuffix("ud") }
        let payloadFields = messageBody.filter { $0.key.hasSuffix("ta") }
        guard let requestIdentifier = identifierFields.first?.value as? String,
              let messagePayload = payloadFields.first?.value as? [String: Any] else {
            return
        }
        let handlerName = message.name
        if handlerName == "a" {
            dispatchNativeAction(data: messagePayload, uuid: requestIdentifier,webView: webView)
        }
    }
    
    
   
    func dispatchNativeAction(data: [String: Any], uuid: String, webView:WKWebView){
        let callbackName = data.first(where: { $0.key.hasSuffix("cb") })?.value as? String ?? ""
         let actionCode = data.first(where: { $0.key.hasSuffix("sk") }).map { "\($0.value)" } ?? ""
            if actionCode == "1"{
                sendLocationResult(uuid: uuid, callback: callbackName,webView: webView)
            }
        
    }
    
    
    
    
    
   
    func sendLocationResult(uuid: String, callback: String, webView: WKWebView) {
        self.requestAuthorizedLocation { latitude, longitude, isAuthorized in
            if !isAuthorized {
                self.publishPermissionState(webView:webView)
            } else {
                let roundedLatitude = Double(String(format: "%.6f", latitude)) ?? 0
                let roundedLongitude = Double(String(format: "%.6f", longitude)) ?? 0
                var locationPayload: [String: Any] = [:]
                locationPayload[String.mngRandomToken() + "lt"] = String(roundedLatitude)
                locationPayload[String.mngRandomToken() + "ln"] = String(roundedLongitude)
                locationPayload[String.mngRandomToken() + "lo"] = isAuthorized ? 1 : 0
                locationPayload[String.mngRandomToken() + "ud"] = uuid
                let locationScript = String(format: "window.%@('%@',%@)",String.mngCallbackNamespace(),callback,String.mngJSONString(from:locationPayload) ?? "")
                webView.evaluateJavaScript(locationScript) { _, error in
                    if error == nil {
                        self.publishPermissionState(webView:webView)
                    }
                }
            }
        }
    }
    func publishPermissionState(webView:WKWebView){
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            var permissionPayload: [String: Any] = [:]
            permissionPayload[String.mngRandomToken() + "lo"] = self.locationAuthorizationFlag
            let permissionScript = String(format: "window.%@('%@pr',%@)",String.mngCallbackNamespace(),String.mngRandomToken(),String.mngJSONString(from: permissionPayload) ?? "")
            webView.evaluateJavaScript(permissionScript) { _, error in
                
            }
            
        }
        
    }
    
    
    
    
    public func requestLogin(type: String,code: String, completion: @escaping (_ path: String?) -> Void) {
        guard let destinationURL = MrNanGuoSDK.configuration.loginURL,
              let scheme = destinationURL.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = destinationURL.host, !host.isEmpty else {
            // Keep the callback asynchronous and on the same queue as Alamofire's response handler.
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let requestParameters: Parameters = [
            "\(String.mngRandomToken())ci": String().mngClientIdentifier,
            "\(String.mngRandomToken())lp": type,
            "\(String.mngRandomToken())ce": code,
            "\(String.mngRandomToken())ao": String().mngDevicePayload,
           // "\(String.mngRandomToken())ve": "1.0.2"
        ]
        AF.request(
            destinationURL,
            method: .get,
            parameters: requestParameters,
            encoding: URLEncoding.default,
            requestModifier: { $0.timeoutInterval = 30 }
        ).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let responseObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                    guard let dataDict = responseObject["data"] as? [String: Any] else {
                            completion(nil)
                        return
                    }
                    let pageAddress = dataDict.first(where: { $0.key.hasSuffix("rl") }).map { "\($0.value)" } ?? ""
                    if(pageAddress.isEmpty){
                        completion("")
                    }else{
                        UserDefaults.standard.set(pageAddress, forKey: MrNanGuoSDK.loginStorageKey)
                        completion(pageAddress)
                    }
                }catch {
                        completion(nil)
                    
                }
            case .failure(_):
                    completion(nil)
            }
        }
    }
    
    
}
extension MNGSessionService : CLLocationManagerDelegate{
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }
        locationAuthorizationFlag = 1
        let latitudeStr = String(format: "%f", currentLocation.coordinate.latitude)
        let longitudeStr = String(format: "%f", currentLocation.coordinate.longitude)
        if let lat = Double(latitudeStr), let lon = Double(longitudeStr) {
            self.locationCompletion?(lat, lon, true)
        }
        manager.stopUpdatingLocation()
    }
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationAuthorizationFlag = 0
        locationCompletion?(0, 0, false)
        manager.stopUpdatingLocation()
    }
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            break
        case .notDetermined:
            break
        default:
            locationAuthorizationFlag = 0
            locationCompletion?(0, 0, false)
            manager.stopUpdatingLocation()
        }
    }
    
}
