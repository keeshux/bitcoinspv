# WaSPV

WaSPV (read *wasvee*) is a native Bitcoin SPV ([Simplified Payment Verification](https://en.bitcoin.it/wiki/Thin_Client_Security#Header-Only_Clients)) client library for iOS written in Objective-C. It conveniently supports Bloom filters ([BIP37](https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki)) and hierarchical deterministic wallets ([BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)).

WaSPV is *free* software, donations are extremely welcome: [16w2AWamiH2SS68NYSMDcrbh5MnZ1c5eju](bitcoin:16w2AWamiH2SS68NYSMDcrbh5MnZ1c5eju)

## License

The library is released under the [GPL](http://www.gnu.org/licenses/gpl.html).

Basically those willing to use the library for their software are forced to release their source as well, because the whole point is about keeping Bitcoin-related software as transparent as possible to increase both trust and community contributions.

Nothing more is due as long as this rule of thumb is followed, still a note in the credits would be great!

## Release notes

__Version 0.1__ - July 31, 2014

* Being the first minor release the library is to be considered experimental, will eventually undergo huge modifications and is quite far from being production ready. In other words: __you DO NOT want to use this version in production environments__.

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

Developers familiar with bitcoinj may recall some of the class naming in the following tests.

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

Current network must be set once on application launch and strictly before any library component is used, e.g.:

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        WSParametersSetCurrentType(WSParametersTypeMain);
        ...
    }

and must not change throughout the application lifecycle.

__WARNING: switching to main network may cost you real money, make sure you know what you're doing!__

### Hierarchical deterministic wallets

BIP32 wallets are instances of the `WSHDWallet` class and are created from a `WSSeed` object, which is in turn made of a mnemonic phrase and a creation time (Apple time). Blockchain sync time can be dramatically faster by specifying the time when the seed was created (called the "fast catch-up time") because blocks before that date won't contain relevant transactions to our wallet and can be safely skipped.

### Block store

Classes implementing the `WSBlockStore` protocol take charge of serializing a blockchain. There are currently two implementations: `WSMemoryBlockStore` and `WSCoreDataBlockStore`. The latter requires `Resources/WSCoreDataBlockStore.xcdatamodeld` to be explicitly added to your project target.

### Peer group

The `WSPeerGroup` class hold the whole connection logic for the Bitcoin network and is also the main notification source. A group can simultaneously connect to several nodes, enforce the number of connected nodes and download the blockchain to a block store. A peer group can also forward the blocks and transactions it receives to a wallet.

Last but not least, the most important interaction with the network is clearly the ability of publishing transactions: not surprisingly, this is done with the `publishTransaction:` method.

## Insights

### Endianness

Bitcoin structures are generally little-endian, an example consequence is that transaction and block hashes are seen "reversed" in hex editors compared to how we see them on web blockchain explorers like [Blockchain.info](http://blockchain.info). There are exceptions, though, because network addresses retain the standard big-endian byte order. Yes, this all makes binary encoding quite error-prone.

That's why WaSPV wraps the encoding internals in the `WSBuffer` and `WSMutableBuffer` classes. From a buffer class you can safely read/write arbitrary bytes or basic structures like hashes, network addresses, inventories etc. without the hassle of protocol byte order.

### Security

HD seeds are not serialized with the other wallet structures in order to allow clients to save them by other, safer means. For example, used addresses and transactions are normally saved to a file, while the secret seed may be separately stored encrypted into the keychain. In fact seeds may even not be saved at all on the device. There's total freedom on how to preserve seeds security.

## Known issues

WaSPV is still a work-in-progress and as such several basic features are still missing.

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

## Disclaimer

The developer takes no responsibility for lost money or any damage due to WaSPV regular usage or bugs. Use at your own risk.

## Credits

* [bitcoinj](http://bitcoinj.github.io/) - The reference Bitcoin library for Java.
* [breadwallet](https://github.com/voisine/breadwallet) - An open source Bitcoin wallet for iOS.
* [bip32.org](http://bip32.org) - Deterministic wallets for JavaScript.
