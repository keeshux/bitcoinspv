Pod::Spec.new do |s|
    s.name              = 'WaSPV'
    s.version           = '0.2'
    s.license           = 'GPL'

    s.summary           = 'A native Bitcoin SPV client library for iOS with BIP32 support.'

    s.homepage          = 'https://github.com/keeshux/WaSPV'
    s.authors           = { 'Davide De Rosa' => 'keeshux@gmail.com' }
    s.source            = { :git => 'https://github.com/keeshux/WaSPV.git',
                            :tag => s.version.to_s }

    s.platform          = :ios, '7.0'
    s.source_files      = 'WaSPV/Sources/**/*.{h,m}'
    s.resource_bundle   = { 'WaSPV' => 'WaSPV/Resources/*' }
    s.exclude_files     = [ 'WaSPVDemo', 'WaSPVTests' ]
    s.requires_arc      = true

    s.frameworks = 'CoreData'
    s.dependency 'OpenSSL-Universal', '~> 1.0.1.h'
    s.dependency 'CocoaLumberjack', '~> 1.9.0'
    s.dependency 'CocoaAsyncSocket', '~> 7.3.5'
    s.dependency 'AutoCoding', '~> 2.2'
end
