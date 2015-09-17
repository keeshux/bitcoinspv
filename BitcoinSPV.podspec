Pod::Spec.new do |s|
    s.name              = 'BitcoinSPV'
    s.version           = '0.7'
    s.platform          = :ios, '7.0'
    s.license           = 'GPL'

    s.summary           = 'A native Bitcoin SPV client library for iOS with BIP32 support.'

    s.homepage          = 'https://github.com/keeshux/BitcoinSPV'
    s.authors           = { 'Davide De Rosa' => 'keeshux@gmail.com' }
    s.source            = { :git => 'https://github.com/keeshux/BitcoinSPV.git',
                            :tag => s.version.to_s }

    s.source_files      = 'BitcoinSPV/Sources/BitcoinSPV.h'
    s.exclude_files     = [ 'BitcoinSPVDemo', 'BitcoinSPVTests' ]
    s.resource_bundle   = { 'BitcoinSPV' => 'BitcoinSPV/Resources/*' }
    s.requires_arc      = true

    s.dependency 'OpenSSL-Universal', '~> 1.0.1.l'
    s.dependency 'CocoaLumberjack', '~> 1.9.2'
    s.dependency 'CocoaAsyncSocket', '~> 7.3.5'
    s.dependency 'AutoCoding', '~> 2.2.1'

    s.subspec 'Core' do |p|
        p.source_files  = 'BitcoinSPV/Sources/BIPS/*.{h,m}',
                          'BitcoinSPV/Sources/Core/*.{h,m}',
                          'BitcoinSPV/Sources/Global/*.{h,m}',
                          'BitcoinSPV/Sources/Parameters/*.{h,m}',
                          'BitcoinSPV/Sources/Utils/*.{h,m}'
    end

    s.subspec 'Blockchain' do |p|
        p.source_files  = 'BitcoinSPV/Sources/Blockchain/*.{h,m}',
                          'BitcoinSPV/Sources/Model/*.{h,m}'
        p.frameworks    = 'CoreData'

        p.dependency 'BitcoinSPV/Core'
    end

    s.subspec 'Wallet' do |p|
        p.source_files  = 'BitcoinSPV/Sources/Wallet/*.{h,m}'

        p.dependency 'BitcoinSPV/Core'
        p.dependency 'BitcoinSPV/Blockchain'
    end

    s.subspec 'Network' do |p|
        p.source_files  = 'BitcoinSPV/Sources/Networking/*.{h,m}',
                          'BitcoinSPV/Sources/Protocol/*.{h,m}'

        p.dependency 'BitcoinSPV/Core'
        p.dependency 'BitcoinSPV/Blockchain'
        p.dependency 'BitcoinSPV/Wallet'
    end

    s.subspec 'Tools' do |p|
        p.source_files  = 'BitcoinSPV/Sources/Currency/*.{h,m}',
                          'BitcoinSPV/Sources/Web/*.{h,m}'

        p.dependency 'BitcoinSPV/Core'
    end
end
