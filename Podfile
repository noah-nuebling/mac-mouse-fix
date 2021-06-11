# Uncomment the next line to define a global platform for your project
platform :osx, '10.11'

# Pods for all targets

pod 'RHAdditions'

#pod 'CocoaLumberjack'
#pod 'CocoaLumberjack/Swift'
# ^ CocoaLumberjack/Swift doesn't work. See https://stackoverflow.com/questions/58300346/getting-include-of-non-modular-header-inside-framework-module-after-update-coc

target 'Mac Mouse Fix' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Mac Mouse Fix

  target 'Mac Mouse FixTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'Mac Mouse FixUITests' do
    # Pods for testing
  end

end

target 'Mac Mouse Fix Accomplice' do
  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!

  # Pods for Mac Mouse Fix Accomplice

end

target 'Mac Mouse Fix Helper' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Mac Mouse Fix Helper

  pod 'ReactiveObjC', '~> 3.1'
  pod 'ReactiveSwift', '~> 6.6'
  pod 'ReactiveCocoa', '~> 11.2' # Not sure if necessary. Not included with ReactiveSwift but ReactiveObjC might include it.

end

# Script to fix 'Include of non-modular header inside framework module'
# Source: https://developer.apple.com/forums/thread/23554
# The script had syntax errors, which I think I fixed, but it still doesn't work. I just can't find a solution to this problem.
#post_install do |installer|
#    `rm -rf Pods/Headers/Private`
#    `find Pods -regex 'Pods\/.*\.modulemap' -print0 | xargs -0 sed -i '' "s/private header\.*//"`
#end
