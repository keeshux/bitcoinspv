# BitcoinSPV

BitcoinSPV is a native Bitcoin SPV ([Simplified Payment Verification](https://en.bitcoin.it/wiki/Thin_Client_Security#Header-Only_Clients)) client library for iOS written in Objective-C. It conveniently supports Bloom filters ([BIP37](https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki)) and hierarchical deterministic wallets ([BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)).

BitcoinSPV is still experimental and __you DO NOT want to use it in production environments today__.

## Contacts

Twitter: [@keeshux](https://twitter.com/keeshux)

Website: [davidederosa.com](http://davidederosa.com)

## Structure

The library is thorough and features a moderately high granularity to isolate the smallest bits of the Bitcoin protocol. Many atomic classes make up the whole thing in tiny steps while also decoupling the user from the areas he's not interested in, because files interdependency is kept at an unnoticeable minimum.

Grouped by area:

* Global
    * Constant values of the Bitcoin ecosystem.
    * Specific library settings unrelated to Bitcoin.
    * Domain and codes found in the `NSError` objects returned by the library.
    * Useful macros for frequent operations.

* Parameters
    * Here you find network-specific magic numbers and parameters.

* Core
    * Generic binary data (de)serialization ([WSBuffer](BitcoinSPV/Sources/Core/WSBuffer.h)).
    * Hashes used everywhere for transaction and block ids, addresses, checksums etc. ([WSHash256](BitcoinSPV/Sources/Core/WSHash256.h), [WSHash160](BitcoinSPV/Sources/Core/WSHash160.h)).
    * ECDSA keys wrappers, able to also import WIF private keys ([WSKey](BitcoinSPV/Sources/Core/WSKey.h), [WSPublicKey](BitcoinSPV/Sources/Core/WSPublicKey.h)).
    * Scripts as the key part of the Bitcoin transaction system ([WSScript](BitcoinSPV/Sources/Core/WSScript.h)).
    * Transaction family classes will help you decode binary transactions or build/sign your own from inputs, outputs and keys ([WSTransaction](BitcoinSPV/Sources/Core/WSTransaction.h)).
    * Addresses are just a shorter way to visualize a transaction script, all standard forms (P2PK, P2PKH, P2SH) are supported ([WSAddress](BitcoinSPV/Sources/Core/WSAddress.h)).
    * An extensive implementation of a BIP32 HD keyring ([WSHDKeyring](BitcoinSPV/Sources/Core/WSHDKeyring.h)).

* Blockchain
    * Full blocks as seen on the wire, with clean separation between headers and transactions ([WSBlockHeader](BitcoinSPV/Sources/Blockchain/WSBlockHeader.h), [WSBlock](BitcoinSPV/Sources/Blockchain/WSBlock.h)).
    * Filtered (Merkle) blocks with partial Merkle tree verification ([WSFilteredBlock](BitcoinSPV/Sources/Blockchain/WSFilteredBlock.h), [WSPartialMerkleTree](BitcoinSPV/Sources/Blockchain/WSPartialMerkleTree.h)).
    * Block stores as a means to track and save blocks ([WSMemoryBlockStore](BitcoinSPV/Sources/Blockchain/WSMemoryBlockStore.h)).
    * A blockchain business wrapper doing all the block connection logic, validation and reorganization ([WSBlockChain](BitcoinSPV/Sources/Blockchain/WSBlockChain.h)).

* Protocol
    * Almost all protocol messages are defined here, one class per message.
    * Bloom filters as defined by BIP37 ([WSBloomFilter](BitcoinSPV/Sources/Protocol/WSBloomFilter.h)).

* Networking
    * Enter the P2P Bitcoin network ([WSPeerGroup](BitcoinSPV/Sources/Networking/WSPeerGroup.h)).
    * Download the blockchain from the network ([WSBlockChainDownloader](BitcoinSPV/Sources/Networking/WSBlockChainDownloader.h)).
    * Connection pooling when dealing with multiple peers ([WSConnectionPool](BitcoinSPV/Sources/Networking/WSConnectionPool.h)).
    * Blockchain SPV synchronization with Bloom filtering for low bandwidth usage.

* Wallet
    * Generic wallet representations.
    * A fully BIP32-compliant HD wallet ([WSHDWallet](BitcoinSPV/Sources/Wallet/WSHDWallet.h)).

* Currency
    * Helper classes for currency conversions ([WSCurrency](BitcoinSPV/Sources/Currency/WSCurrency.h)).
    * Bitcoin currency variants (bitcoin, millis, satoshis) ([WSBitcoinCurrency](BitcoinSPV/Sources/Currency/WSBitcoinCurrency.h)).

* Web
    * Useful operations accomplished with the aid of third-party web services.
    * Explorer classes from different providers ([WSWebExplorer](BitcoinSPV/Sources/Web/WSWebExplorer.h)).
    * Ticker classes and unified price monitor ([WSWebTicker](BitcoinSPV/Sources/Web/WSWebTicker.h), [WSWebTickerMonitor](BitcoinSPV/Sources/Web/WSWebTickerMonitor.h)).
    * Sweep an external private key (e.g. a paper wallet), be it plain or password-encrypted (BIP38).

* BIPS
    * BIP21: parsing and building of "bitcoin:" URLs.
    * BIP32: hierarchical deterministic wallets.
    * BIP37: Bloom filtering for fast blockchain synchronization.
    * BIP38: passphrase-protected private keys.
    * BIP39: mnemonics for deterministic keys.
    * BIP44: multi-account hierarchy for deterministic wallets.

## Installation

BitcoinSPV depends on four well known libraries:

* [OpenSSL](https://github.com/krzak/OpenSSL.git)
* [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack.git)
* [AutoCoding](https://github.com/nicklockwood/AutoCoding.git)
* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket.git)

Setup is straightforward thanks to the brilliant [CocoaPods](http://cocoapods.org/) utility. I usually test the software on iOS 7 but everything *should* be fine on 6.x as well.

### Podfile

Add the following line:

    pod 'BitcoinSPV', '~> 0.7'

and run on the terminal:

    $ pod install

Beware that some recent versions of CocoaPods may break static linking unless you remove the following line from the `Pods/Pods.*.xcconfig` configuration files:

    OTHER_LIBTOOLFLAGS = $(OTHER_LDFLAGS)

### Imports

BitcoinSPV declares an implicit `extern const int ddLogLevel` for CocoaLumberjack and the linker will complain if you don't define it somewhere, e.g. in the application delegate:

    #import "AppDelegate.h"

    const int ddLogLevel = LOG_LEVEL_DEBUG;
    ...

All the imports are public but the one you generally need is `#import "BitcoinSPV.h"`.

### Testing

The `BitcoinSPVTests` target comes with a couple of automated tests. They don't completely test all the library features (especially the networking area), but they're certainly required to succeed. A single fail guarantees that something's broken.

Some tests write files on disk in the global `Library/Caches` of the iPhone Simulator. You can find them under the `BitcoinSPVTests` subdirectory.

### Basic usage

Developers familiar with bitcoinj may recall some of the class names in the following snippets:

#### Create new wallet

    #import "BitcoinSPV.h"

    - (void)createWallet
    {
        WSParameters *parameters = WSParametersForNetworkType(WSNetworkTypeTestnet3);

        WSSeed *seed = [[WSSeedGenerator sharedInstance] generateRandomSeed];

        // now's the time to backup the seed somewhere, show it to the user etc.

        id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:parameters];
        WSHDWallet *wallet = [[WSHDWallet alloc] initWithParameters:parameters seed:seed];
        WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store wallet:wallet];
        
        WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:parameters];
        [peerGroup startConnections];
        [peerGroup startDownloadWithDownloader:downloader];

        // strongly retain peer group
        self.peerGroup = peerGroup;
    }

#### Restore existing wallet

    #import "BitcoinSPV.h"

    - (void)restoreWallet
    {
        WSParameters *parameters = WSParametersForNetworkType(WSNetworkTypeTestnet3);

        WSSeed *seed = WSSeedMakeFromISODate(@"enter your bip39 mnemonic seed phrase", @"2014-02-28");

        id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:parameters];
        WSHDWallet *wallet = [[WSHDWallet alloc] initWithParameters:parameters seed:seed];
        WSBlockChainDownloader *downloader = [[WSBlockChainDownloader alloc] initWithStore:store wallet:wallet];
        
        WSPeerGroup *peerGroup = [[WSPeerGroup alloc] initWithParameters:parameters];
        [peerGroup startConnections];
        [peerGroup startDownloadWithDownloader:downloader];

        // strongly retain peer group
        self.peerGroup = peerGroup;
    }

## Overview

### Network parameters

Bitcoin nodes can operate on three networks:

- __Main__: that's the real world network where coins have real value.
- __Testnet3__: test coins are quite hard to mine but have negligible value. Online [faucets](http://faucet.xeno-genesis.com/) exist to earn test coins.
- __Regtest__: mining time is trivial on regtest so it's best suited for testing manually built blockchains.

Most initializers depend on network parameters, you can get a reference with the following code:

    // networkType must be one of: WSNetworkTypeMain, WSNetworkTypeTestnet3, WSNetworkTypeRegtest

    WSParameters *networkParameters = WSParametersForNetworkType(WSNetworkTypeTestnet3);
    ...

__WARNING: operating on main network may cost you real money, make sure you know what you're doing!__

### Mnemonics

[BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki) gives special hints on how human-readable phrases (mnemonics) can produce a binary seed for HD wallets. BitcoinSPV implements the BIP39 specification in the `WSSeedGenerator` class that can be used to:

* Generate a random mnemonic.
* Convert a mnemonic to binary data.
* Convert binary data to a mnemonic.
* Derive key data from a mnemonic.

However, mnemonics in BitcoinSPV are usually wrapped in a `WSSeed` object that also contains the time the mnemonic was first created. Blockchain sync time can be dramatically faster by specifying such a time (called the "fast catch-up time") because blocks found before won't contain relevant transactions to our wallet and can be safely skipped.

### Hierarchical deterministic wallets

HD wallets are described in [BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki). In BitcoinSPV they're instances of the `WSHDWallet` class and built from a `WSSeed` object with an optional gap limit (default is 10). An additional set of look-ahead addresses is also pregenerated internally to prevent Bloom filter from being reloaded each time a transaction consumes a new address.

It's worth noting that the seed mnemonic is a *very* sensitive information -it technically holds all your coins- and as such it's not serialized with the `[WSWallet saveToPath:]` method: this means you must store it elsewhere, e.g. in the keychain. The mnemonic will be vital to restore later a serialized wallet with the `[WSHDWallet loadFromPath:parameters:seed:]` method.

### Block store

Classes implementing the `WSBlockStore` protocol take charge of serializing a blockchain. There is currently one implementation: `WSMemoryBlockStore`. The name is quite self-explanatory.

### Peer group

The `WSPeerGroup` class holds the whole logic for connecting to the Bitcoin network and is the main event notification source. A group can simultaneously connect to several nodes, enforce the number of connected nodes and download the blockchain to a block store. When built with a wallet it also forwards relevant blocks and transactions to the wallet. The wallet in turn registers them and internally updates its history, UTXOs, confirmations etc.

Last but not least, the key interaction with the network is clearly the ability of publishing transactions. Not surprisingly, this is done with the `publishTransaction:` method.

## Insights

### Endianness

Bitcoin structures are generally little-endian, an example consequence is that transaction and block hashes are seen "reversed" in hex editors compared to how we see them on web blockchain explorers like [Blockchain.info](http://blockchain.info). There are exceptions, though, because network addresses retain the standard big-endian byte order. Yes, this all makes binary encoding quite error-prone.

That's why BitcoinSPV wraps the encoding internals in the `WSBuffer` and `WSMutableBuffer` classes. With a buffer class you can safely read/write arbitrary bytes or basic structures like hashes, network addresses, inventories etc. without the hassle of protocol byte order.

### Immutability

BitcoinSPV relies on the [Grand Central Dispatch](https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html), meaning that most of the code is expected to run on multiple queues to achieve best performance. In an attempt to limit the overall complexity, I cut mutable objects usage to a minimum. The immutable approach dramatically simplifies critical sections and guarantees the integrity of serialized data for free. No Core Data entity is mutable, nor are blockchain-related structures in general. Think about it, altering an accepted block would even defeat the purpose of the protocol.

### Security

Sensitive data are never serialized automatically so that clients will be able to save them by other, safer means. For example, transactions and addresses of a HD wallet can be safely written to a file, while the secret mnemonic deserves more attention. You may store it encrypted into the keychain, you may retrieve it encrypted from a service provider and decrypt it locally, you may even decide not to store it at all. In fact there's total freedom on how to preserve mnemonics security.

## Known issues

BitcoinSPV is still a work-in-progress and will eventually undergo huge modifications. Several basic things are left to do, sorted by priority:

* Build multi-signature transactions (support is incomplete).
* Implement payment protocol as described by [BIP70](https://github.com/bitcoin/bips/blob/master/bip-0070.mediawiki)/[BIP71](https://github.com/bitcoin/bips/blob/master/bip-0071.mediawiki)/[BIP72](https://github.com/bitcoin/bips/blob/master/bip-0072.mediawiki)/[BIP73](https://github.com/bitcoin/bips/blob/master/bip-0073.mediawiki).
* Improve SPV security by tracking peer confidence.
* Support basic wallets with static keys.
* Cope with [Core Data versioning](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/Introduction.html).

## License

BitcoinSPV is released under the [GPL](http://www.gnu.org/licenses/gpl.html).

Basically those willing to use BitcoinSPV for their software are forced to release their source as well, because the whole point is about keeping Bitcoin-related software as transparent as possible to increase both trust and community contributions.

Nothing more is due as long as this rule of thumb is followed, still a note in the credits would be appreciated.

## Disclaimer

The developer takes no responsibility for lost money or any damage due to BitcoinSPV regular usage or bugs. Use at your own risk.

## Donations

BitcoinSPV is *free* software, donations are extremely welcome.

Bitcoin address: [16w2AWamiH2SS68NYSMDcrbh5MnZ1c5eju](bitcoin:16w2AWamiH2SS68NYSMDcrbh5MnZ1c5eju)

## Credits

* [bitcoinj](http://bitcoinj.github.io/) - The most popular Bitcoin library for Java.
* [breadwallet](http://github.com/voisine/breadwallet) - An open source Bitcoin wallet for iOS.
* [bip32.org](http://bip32.org) - Deterministic wallets for JavaScript.
