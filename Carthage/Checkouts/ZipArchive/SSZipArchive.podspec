Pod::Spec.new do |s|
  s.name         = 'SSZipArchive'
  s.version      = '2.2.3'
  s.summary      = 'Utility class for zipping and unzipping files on iOS, tvOS, watchOS, and macOS.'
  s.description  = 'SSZipArchive is a simple utility class for zipping and unzipping files on iOS, tvOS, watchOS, and macOS. It supports AES and PKWARE encryption.'
  s.homepage     = 'https://github.com/ZipArchive/ZipArchive'
  s.license      = { :type => 'MIT', :file => 'LICENSE.txt' }
  s.authors      = { 'Sam Soffes' => 'sam@soff.es', 'Joshua Hudson' => nil, 'Antoine Cœur' => nil }
  s.source       = { :git => 'https://github.com/ZipArchive/ZipArchive.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.osx.deployment_target = '10.8'
  s.watchos.deployment_target = '2.0'
  s.source_files = 'SSZipArchive/*.{m,h}', 'SSZipArchive/minizip/*.{c,h}'
  s.public_header_files = 'SSZipArchive/*.h'
  s.libraries = 'z', 'iconv'
  s.framework = 'Security'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'HAVE_INTTYPES_H HAVE_PKCRYPT HAVE_STDINT_H HAVE_WZAES HAVE_ZLIB' }
end
