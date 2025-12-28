#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mssql_connection.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mssql_connection'
  s.version          = '3.0.0'
  s.summary          = 'Flutter plugin for Microsoft SQL Server using FreeTDS.'
  s.description      = <<-DESC
Flutter/Dart plugin to connect to Microsoft SQL Server using Dart FFI + FreeTDS.
Cross-platform: Windows, Android, iOS, macOS, Linux.
                       DESC
  s.homepage         = 'https://github.com/Hiteshdon/mssql_connection'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hiteshdon' => 'hiteshdon@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # FreeTDS static libraries (XCFrameworks)
  s.vendored_frameworks = 'FreeTDS/FreeTDS-DB.xcframework', 'FreeTDS/FreeTDS-CT.xcframework'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
