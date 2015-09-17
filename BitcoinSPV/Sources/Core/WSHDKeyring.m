//
//  WSHDKeyring.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 13/06/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  http://github.com/keeshux
//  http://twitter.com/keeshux
//  http://davidederosa.com
//
//  This file is part of BitcoinSPV.
//
//  BitcoinSPV is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  BitcoinSPV is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with BitcoinSPV.  If not, see <http://www.gnu.org/licenses/>.
//

#import <CommonCrypto/CommonCrypto.h>

#import "WSHDKeyring.h"
#import "WSSeedGenerator.h"
#import "WSKey.h"
#import "WSPublicKey.h"
#import "WSHash160.h"
#import "WSErrors.h"

#pragma mark -

@interface WSPublicKey (BIP32)

- (uint32_t)bip32Fingerprint;

@end

@implementation WSPublicKey (BIP32)

- (uint32_t)bip32Fingerprint
{
    uint32_t fingerprint = 0x0;
    [[self hash160].data getBytes:&fingerprint length:4];

    return CFSwapInt32HostToBig(fingerprint);
}

@end

#pragma mark -

@interface WSHDKeyring ()

@property (nonatomic, strong) WSBIP32Key *extendedPrivateKey;
@property (nonatomic, strong) WSBIP32Key *extendedPublicKey;

@end

@implementation WSHDKeyring

- (instancetype)initWithParameters:(WSParameters *)parameters mnemonic:(NSString *)mnemonic
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(mnemonic);

    NSData *keyData = [[WSSeedGenerator sharedInstance] deriveKeyDataFromMnemonic:mnemonic];
    return [self initWithParameters:parameters data:keyData];
}

- (instancetype)initWithParameters:(WSParameters *)parameters seed:(WSSeed *)seed
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(seed);

    NSData *keyData = [seed derivedKeyData];
    return [self initWithParameters:parameters data:keyData];
}

- (instancetype)initWithParameters:(WSParameters *)parameters data:(NSData *)data
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(data);

    NSMutableData *I = [[NSMutableData alloc] initWithLength:CC_SHA512_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA512, WSBIP32InitSeed, strlen(WSBIP32InitSeed), data.bytes, data.length, I.mutableBytes);
    NSData *keyData = [NSData dataWithBytesNoCopy:(unsigned char *)I.bytes length:32 freeWhenDone:NO];
    NSData *chainData = [NSData dataWithBytesNoCopy:((unsigned char *)I.bytes + 32) length:32 freeWhenDone:NO];

    WSBIP32Key *key = [[WSBIP32Key alloc] initPrivateWithParameters:parameters
                                                              depth:0
                                                  parentFingerprint:0x0
                                                              child:0
                                                          chainData:chainData
                                                            keyData:keyData];

    return [self initWithExtendedPrivateKey:key];
}

- (instancetype)initWithExtendedPrivateKey:(WSBIP32Key *)extendedPrivateKey
{
    WSExceptionCheckIllegal(extendedPrivateKey);
    WSExceptionCheckIllegal([extendedPrivateKey isPrivate]);

    if ((self = [super init])) {
        self.extendedPrivateKey = extendedPrivateKey;

        WSPublicKey *publicKey = [WSPublicKey publicKeyWithPrivateData:self.extendedPrivateKey.keyData];

        self.extendedPublicKey = [[WSBIP32Key alloc] initPublicWithParameters:self.parameters
                                                                        depth:self.extendedPrivateKey.depth
                                                            parentFingerprint:self.extendedPrivateKey.parentFingerprint
                                                                        child:self.extendedPrivateKey.child
                                                                    chainData:self.extendedPrivateKey.chainData
                                                                      keyData:publicKey.data];
    }
    return self;
}

- (WSParameters *)parameters
{
    return self.extendedPrivateKey.parameters;
}

#pragma mark WSBIP32Keyring

- (id<WSBIP32Keyring>)keyringAtPath:(NSString *)path
{
    WSExceptionCheckIllegal(path);

    NSArray *nodes = [WSBIP32Node parseNodesFromPath:path];
    return [self keyringAtNodes:nodes];
}

- (id<WSBIP32Keyring>)keyringAtNode:(WSBIP32Node *)node
{
    WSExceptionCheckIllegal(node);

    return [self keyringAtNodes:@[node]];
}

- (id<WSBIP32Keyring>)keyringAtNodes:(NSArray *)nodes
{
    WSExceptionCheckIllegal(nodes);
    
    if (nodes.count == 0) {
        return self;
    }

    NSMutableData *chainData = [self.extendedPrivateKey.chainData mutableCopy];
    NSMutableData *keyData = [self.extendedPrivateKey.keyData mutableCopy];
    
    uint32_t depth = self.extendedPrivateKey.depth;
    uint32_t parentFingerprint = 0x0;
    uint32_t child = 0;
    
    for (WSBIP32Node *node in nodes) {
        if (node == [nodes lastObject]) {
            parentFingerprint = [[WSPublicKey publicKeyWithPrivateData:keyData] bip32Fingerprint];
        }
        child = node.child;
        
        WSBIP32CKDpriv(keyData, chainData, child);
        ++depth;
    }
    
    WSBIP32Key *key = [[WSBIP32Key alloc] initPrivateWithParameters:self.parameters
                                                              depth:depth
                                                  parentFingerprint:parentFingerprint
                                                              child:child
                                                          chainData:chainData
                                                            keyData:keyData];

    return [[WSHDKeyring alloc] initWithExtendedPrivateKey:key];
}

- (WSHDPublicKeyring *)publicKeyring
{
    return [[WSHDPublicKeyring alloc] initWithExtendedPublicKey:self.extendedPublicKey];
}

- (WSKey *)privateKey
{
    return [WSKey keyWithData:self.extendedPrivateKey.keyData];
}

- (WSPublicKey *)publicKey
{
    return [WSPublicKey publicKeyWithData:self.extendedPublicKey.keyData];
}

- (WSAddress *)address
{
    return [[self publicKey] addressWithParameters:self.parameters];
}

- (id<WSBIP32Keyring>)keyringForAccount:(uint32_t)account
{
    return [self keyringAtNode:[WSBIP32Node nodeWithIndex:account hardened:NO]];
}

- (WSKey *)privateKeyForAccount:(uint32_t)account
{
    NSMutableData *chainData = [self.extendedPrivateKey.chainData mutableCopy];
    NSMutableData *keyData = [self.extendedPrivateKey.keyData mutableCopy];
    
    WSBIP32CKDpriv(keyData, chainData, account);
    
    return [WSKey keyWithData:keyData];
}

- (WSPublicKey *)publicKeyForAccount:(uint32_t)account
{
    if (WSBIP32ChildIsHardened(account)) {
        NSMutableData *chainData = [self.extendedPrivateKey.chainData mutableCopy];
        NSMutableData *keyData = [self.extendedPrivateKey.keyData mutableCopy];
        
        WSBIP32CKDpriv(keyData, chainData, account);
        
        return [WSPublicKey publicKeyWithPrivateData:keyData];
    }
    else {
        NSMutableData *chainData = [self.extendedPublicKey.chainData mutableCopy];
        NSMutableData *keyData = [self.extendedPublicKey.keyData mutableCopy];
        
        WSBIP32CKDpub(keyData, chainData, account);
        
        return [WSPublicKey publicKeyWithData:keyData];
    }
}

- (id<WSBIP32Keyring>)chainForAccount:(uint32_t)account internal:(BOOL)internal
{
    NSMutableArray *nodes = [[NSMutableArray alloc] init];
    [nodes addObject:[WSBIP32Node nodeWithIndex:account hardened:YES]];
    [nodes addObject:[WSBIP32Node nodeWithIndex:(internal ? 1 : 0) hardened:NO]];
    return [self keyringAtNodes:nodes];
}

- (id<WSBIP32PublicKeyring>)publicChainForAccount:(uint32_t)account internal:(BOOL)internal
{
    return [[self chainForAccount:account internal:internal] publicKeyring];
}

@end

#pragma mark -

@interface WSHDPublicKeyring ()

@property (nonatomic, strong) WSBIP32Key *extendedPublicKey;

@end

@implementation WSHDPublicKeyring

- (instancetype)initWithExtendedPublicKey:(WSBIP32Key *)extendedPublicKey
{
    WSExceptionCheckIllegal(extendedPublicKey);
    WSExceptionCheckIllegal([extendedPublicKey isPublic]);

    if ((self = [super init])) {
        self.extendedPublicKey = extendedPublicKey;
    }
    return self;
}

- (WSParameters *)parameters
{
    return self.extendedPublicKey.parameters;
}

#pragma mark WSBIP32PublicKeyring

- (id<WSBIP32PublicKeyring>)publicKeyringAtPath:(NSString *)path
{
    WSExceptionCheckIllegal(path);

    NSArray *nodes = [WSBIP32Node parseNodesFromPath:path];
    return [self publicKeyringAtNodes:nodes];
}

- (id<WSBIP32PublicKeyring>)publicKeyringAtNode:(WSBIP32Node *)node
{
    WSExceptionCheckIllegal(node);
    WSExceptionCheckIllegal(!node.hardened);

    return [self publicKeyringAtNodes:@[node]];
}

- (id<WSBIP32PublicKeyring>)publicKeyringAtNodes:(NSArray *)nodes
{
    WSExceptionCheckIllegal(nodes);
    
    if (nodes.count == 0) {
        return self;
    }
    
    NSMutableData *chainData = [self.extendedPublicKey.chainData mutableCopy];
    NSMutableData *keyData = [self.extendedPublicKey.keyData mutableCopy];
    
    uint32_t depth = self.extendedPublicKey.depth;
    uint32_t parentFingerprint = 0x0;
    uint32_t child = 0;
    
    for (WSBIP32Node *node in nodes) {
        WSExceptionCheckIllegal(!node.hardened);
        if (node == [nodes lastObject]) {
            parentFingerprint = [[WSPublicKey publicKeyWithData:keyData] bip32Fingerprint];
        }
        child = node.child;

        WSBIP32CKDpub(keyData, chainData, child);
        ++depth;
    }
    
    WSBIP32Key *key = [[WSBIP32Key alloc] initPublicWithParameters:self.parameters
                                                             depth:depth
                                                 parentFingerprint:parentFingerprint
                                                             child:child
                                                         chainData:chainData
                                                           keyData:keyData];

    return [[WSHDPublicKeyring alloc] initWithExtendedPublicKey:key];
}

- (WSPublicKey *)publicKey
{
    return [WSPublicKey publicKeyWithData:self.extendedPublicKey.keyData];
}

- (WSAddress *)address
{
    return [[self publicKey] addressWithParameters:self.parameters];
}

- (id<WSBIP32PublicKeyring>)publicKeyringForAccount:(uint32_t)account
{
    WSExceptionCheckIllegal(!WSBIP32ChildIsHardened(account));

    return [self publicKeyringAtNode:[WSBIP32Node nodeWithIndex:account hardened:NO]];
}

- (WSPublicKey *)publicKeyForAccount:(uint32_t)account
{
    WSExceptionCheckIllegal(!WSBIP32ChildIsHardened(account));
    
    NSMutableData *chainData = [self.extendedPublicKey.chainData mutableCopy];
    NSMutableData *keyData = [self.extendedPublicKey.keyData mutableCopy];
    
    WSBIP32CKDpub(keyData, chainData, account);
    
    return [WSPublicKey publicKeyWithData:keyData];
}

@end
