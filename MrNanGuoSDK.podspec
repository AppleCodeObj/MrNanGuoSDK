Pod::Spec.new do |s|
  s.name = 'MrNanGuoSDK'
  s.version = '1.0.0'
  s.summary = 'Native login and WebKit screens for iOS.'
  s.description = 'Configurable UIKit entry screens, login networking, WebKit and location bridge utilities.'
  s.homepage = 'https://github.com/AppleCodeObj/MrNanGuoSDK'
  s.source = { :git => 'https://github.com/AppleCodeObj/MrNanGuoSDK.git', :tag => s.version.to_s }
  s.author = { 'AppleCodeObj' => '444693592@qq.com' }
  s.license = { :type => 'Proprietary', :text => 'All rights reserved. Use requires permission from the copyright holder.' }
  s.ios.deployment_target = '16.0'
  s.swift_version = '5.0'
  s.static_framework = true
  s.source_files = 'Sources/**/*.swift'
  s.frameworks = 'UIKit', 'WebKit', 'CoreLocation', 'AuthenticationServices', 'Security'
  s.dependency 'Alamofire', '~> 5.11'
end
