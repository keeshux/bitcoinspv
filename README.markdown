# WaSPV

WaSPV (read *wasvee*) is a native Bitcoin SPV ([Simplified Payment Verification](https://en.bitcoin.it/wiki/Thin_Client_Security#Header-Only_Clients)) client library for iOS written in Objective-C. It conveniently supports Bloom filters ([BIP37](https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki)) and hierarchical deterministic wallets ([BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)).

## Donations

WaSPV is *free* software, donations are extremely welcome.

Address: [16w2AWamiH2SS68NYSMDcrbh5MnZ1c5eju](bitcoin:16w2AWamiH2SS68NYSMDcrbh5MnZ1c5eju)

## License

WaSPV is released under the [GPL](http://www.gnu.org/licenses/gpl.html).

Basically those willing to use WaSPV for their software are forced to release their source as well, because the whole point is about keeping Bitcoin-related software as transparent as possible to increase both trust and community contributions.

Nothing more is due as long as this rule of thumb is followed, still a note in the credits would be great!

## Release notes

__Version 0.1__ - July 31, 2014

* Being the first minor release the library is experimental and quite far from being production ready. In other words: __you DO NOT want to use this version in production environments__.

## Quick start

### Dependencies

First of all you'll need to satisfy the following dependencies:

* [OpenSSL-Universal](https://github.com/krzak/OpenSSL.git)
* [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack.git)
* [AutoCoding](https://github.com/nicklockwood/AutoCoding.git)
* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket.git)

#### Git

Clone the above github repositories into local git submodules.

#### CocoaPods

Merge the [WaSPV Podfile](https://github.com/keeshux/WaSPV/blob/master/Podfile) dependencies into your podfile and run `pod update`. A podspec will soon be added to simplify the installation process.

### Installation

The easy way is importing all files under the `WaSPV` directory into your project. Alternatively, you can embed the whole `WaSPV.xcodeproj` subproject and add `libWaSPV.a` to your project's "Build Phases > Link Binary With Libraries".

Please remember that the `WaSPV/Resources` subdirectory won't be compiled into the static library. In case you plan to use Core Data or the bundled [BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki) English word list for mnemonic generation you *must* manually add the `WaSPV/Resources` subdirectory to your targets.

The only import you generally need in your own sources is `#import "WaSPV.h"`.

### Testing

Most of the tests are automated, except those in the `WaSPVTests/Manual` subdirectory. You should disable them before testing the whole suite.

### Basic usage

Developers familiar with bitcoinj may recall some of the class names in the following tests.

#### Create new wallet

    #import "WaSPV.h"

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        WSParametersSetCurrentType(WSParametersTypeTestnet3);
        ...
    }

    - (void)createWallet
    {
        WSSeed *seed = [[WSSeedGenerator sharedInstance] generateRandomSeed];

        // now's the time to backup the seed somewhere, show it to the user etc.

        WSHDWallet *wallet = [[WSHDWallet alloc] initWithSeed:seed];

        id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithGenesisBlock];
        WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:store wallet:wallet];
        [peerGroup startConnections];
        [peerGroup startBlockChainDownload];
    }

#### Restore existing wallet

    #import "WaSPV.h"

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        WSParametersSetCurrentType(WSParametersTypeTestnet3);
        ...
        return YES;
    }

    - (void)restoreWallet
    {
        WSSeed *seed = WSSeedMakeFromISODate(@"enter your bip39 mnemonic seed phrase", @"2014/02/28");

        WSHDWallet *wallet = [[WSHDWallet alloc] initWithSeed:seed];

        id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithGenesisBlock];
        WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithBlockStore:store wallet:wallet];
        [peerGroup startConnections];
        [peerGroup startBlockChainDownload];
    }

### Network parameters

Bitcoin nodes can operate on three networks:

- __Main__: that's the real world network where coins have real value.
- __Testnet3__: test coins are quite hard to mine but have negligible value. Online [faucets](http://faucet.xeno-genesis.com/) exist to earn test coins.
- __Regtest__: mining time is trivial on regtest so it's best suited for testing manually built blockchains.

For security reasons, the library defaults to testnet3. Testnet3 is a full-blown network -it has DNS seeds and a real blockchain- but losing coins there is not an issue. An explicit call to the `WSParametersSetCurrentType()` macro is needed to switch to main or regtest networks.

Current network must be set once on application launch:

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        WSParametersSetCurrentType(WSParametersTypeMain);
        ...
    }

strictly before any library component is used and must not change throughout the application lifecycle.

__WARNING: switching to main network may cost you real money, make sure you know what you're doing!__

### Mnemonics

[BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki) gives special hints on how human-readable phrases (mnemonics) can produce a binary seed for HD wallets. WaSPV implements the BIP39 specification in the `WSSeedGenerator` class that can be used to:

* Generate a random mnemonic.
* Convert a mnemonic to binary data.
* Convert binary data to a mnemonic.
* Derive key data from mnemonic.

However, mnemonics in WaSPV are usually wrapped in a `WSSeed` object that also contains the time the mnemonic was first created. Blockchain sync time can be dramatically faster by specifying such a time (called the "fast catch-up time") because blocks found before won't contain relevant transactions to our wallet and can be safely skipped.

### Hierarchical deterministic wallets

HD wallets are described in [BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki). In WaSPV they're instances of the `WSHDWallet` class built from a `WSSeed` object and an optional integer gap limit.

It's worth noting that the seed mnemonic is a *very* sensitive information -it technically holds all your coins- and as such it's not serialized with the `[WSWallet saveToPath:]` method, you must store it elsewhere (e.g. in the keychain). The mnemonic will be required later to restore a serialized wallet with the `[WSHDWallet loadFromPath:mnemonic:]` method.

### Block store

Classes implementing the `WSBlockStore` protocol take charge of serializing a blockchain. There are currently two implementations: `WSMemoryBlockStore` and `WSCoreDataBlockStore`. The latter requires `WaSPV/Resources/WSCoreDataBlockStore.xcdatamodeld` to be explicitly added to your project target.

### Peer group

The `WSPeerGroup` class hold the whole connection logic for the Bitcoin network and is also the main notification source. A group can simultaneously connect to several nodes, enforce the number of connected nodes and download the blockchain to a block store. A peer group can also forward the blocks and transactions it receives to a wallet.

Last but not least, the most important interaction with the network is clearly the ability of publishing transactions. Not surprisingly, this is done with the `publishTransaction:` method.

## Insights

### Endianness

Bitcoin structures are generally little-endian, an example consequence is that transaction and block hashes are seen "reversed" in hex editors compared to how we see them on web blockchain explorers like [Blockchain.info](http://blockchain.info). There are exceptions, though, because network addresses retain the standard big-endian byte order. Yes, this all makes binary encoding quite error-prone.

That's why WaSPV wraps the encoding internals in the `WSBuffer` and `WSMutableBuffer` classes. With a buffer class you can safely read/write arbitrary bytes or basic structures like hashes, network addresses, inventories etc. without the hassle of protocol byte order.

### Security

Sensitive data are never serialized automatically so that clients will be able to save them by other, safer means. For example, transactions and addresses of a HD wallet can be safely written to a file, while the secret mnemonic deserves more attention. You may store it encrypted into the keychain, you may retrieve it encrypted from a service provider and decrypt it locally, you may even decide not to store it at all. In fact there's total freedom on how to preserve mnemonics security.

## Known issues

WaSPV is still a work-in-progress and will eventually undergo huge modifications. Several basic things are left to do:

* Submit CocoaPods podspec.
* Autosave wallet.
* Calculate wallet transaction in/out amounts.
* Disconnect peers on timeout (sync may get stuck).
* Securely cleanse sensitive data from memory.
* Fix transaction relevancy check.
* Checkpoints tool and serialization.
* Establish cross-platform wallet format.
* Support blockchain rescan.
* Cope with [Core Data versioning](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/Introduction.html).
* Discard unpublished transactions.
* Track known inventories.
* Import [BIP38](https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki) keys.
* Support basic wallets with static keys.
* Improve addresses generation time.
* Handle [BIP61](https://github.com/bitcoin/bips/blob/master/bip-0061.mediawiki) REJECT message.
* Full multiSig support.

## Disclaimer

The developer takes no responsibility for lost money or any damage due to WaSPV regular usage or bugs. Use at your own risk.

## Credits

* [bitcoinj](http://bitcoinj.github.io/) - The reference Bitcoin library for Java.
* [breadwallet](https://github.com/voisine/breadwallet) - An open source Bitcoin wallet for iOS.
* [bip32.org](http://bip32.org) - Deterministic wallets for JavaScript.
