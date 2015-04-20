Pod::Spec.new do |s|
    s.name              = 'ios-bitcoin-spv'
    s.version           = '0.5'
    s.license           = 'GPL'

    s.summary           = 'A native Bitcoin SPV client library for iOS with BIP32 support.'

    s.homepage          = 'https://github.com/keeshux/ios-bitcoin-spv'
    s.authors           = { 'Davide De Rosa' => 'keeshux@gmail.com' }
    s.source            = { :git => 'https://github.com/keeshux/ios-bitcoin-spv.git',
                            :tag => s.version.to_s }

    s.platform          = :ios, '7.0'
    s.source_files      = 'BitcoinSPV/Sources/**/*.{h,m}'
    s.resource_bundle   = { 'BitcoinSPV' => 'BitcoinSPV/Resources/*' }
    s.exclude_files     = [ 'BitcoinSPVDemo', 'BitcoinSPVTests', 'BitcoinSPV/Sources/Blockchain/WSCoreDataBlockStore.*' ]
    s.requires_arc      = true

    s.frameworks = 'CoreData'
    s.dependency 'OpenSSL-Universal', '~> 1.0.1.h'
    s.dependency 'CocoaLumberjack', '~> 1.9.0'
    s.dependency 'CocoaAsyncSocket', '~> 7.3.5'
    s.dependency 'AutoCoding', '~> 2.2'
end
