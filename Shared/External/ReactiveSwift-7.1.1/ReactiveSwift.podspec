Pod::Spec.new do |s|
  s.name         = "ReactiveSwift"
  # Version goes here and will be used to access the git tag later on, once we have a first release.
  s.version      = "7.1.1"
  s.summary      = "Streams of values over time"
  s.description  = <<-DESC
                   ReactiveSwift is a Swift framework inspired by Functional Reactive Programming. It provides APIs for composing and transforming streams of values over time.
                   DESC
  s.homepage     = "https://github.com/ReactiveCocoa/ReactiveSwift"
  s.license      = { :type => "MIT", :file => "LICENSE.md" }
  s.author       = "ReactiveCocoa"

  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.13"
  s.watchos.deployment_target = "4.0"
  s.tvos.deployment_target = "11.0"

  s.source       = { :git => "https://github.com/ReactiveCocoa/ReactiveSwift.git", :tag => "#{s.version}" }
  # Directory glob for all Swift files
  s.source_files  = ["Sources/*.{swift}", "Sources/**/*.{swift}"]

  s.pod_target_xcconfig = {
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    "OTHER_SWIFT_FLAGS[config=Release]" => "$(inherited) -suppress-warnings"
  }

  s.cocoapods_version = ">= 1.7.0"
  s.swift_versions = ["5.2", "5.3" "5.4", "5.5", "5.6", "5.7"]
end
