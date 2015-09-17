//
//  WSBIP32.h
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

#import <Foundation/Foundation.h>

//
// HD wallets
//
// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
//

@class WSParameters;
@class WSBIP32Key;
@protocol WSBIP32PublicKeyring;
@class WSBIP32Node;
@class WSKey;
@class WSPublicKey;
@class WSAddress;

#pragma mark -

extern const char *             WSBIP32InitSeed;
extern const uint32_t           WSBIP32HardenedMask;
extern const NSUInteger         WSBIP32KeyLength;

NSString *WSBIP32PathForAccount(uint32_t account);

static inline uint32_t WSBIP32ChildIndex(uint32_t child)
{
    return (child & ~WSBIP32HardenedMask);
}

static inline BOOL WSBIP32ChildIsHardened(uint32_t child)
{
    return ((child & WSBIP32HardenedMask) != 0);
}

void WSBIP32CKDpriv(NSMutableData *privKey, NSMutableData *chain, uint32_t i);
void WSBIP32CKDpub(NSMutableData *pubKey, NSMutableData *chain, uint32_t i);

#pragma mark -

@protocol WSBIP32Keyring <NSObject>

//
// Generic
//
- (id<WSBIP32Keyring>)keyringAtPath:(NSString *)path;
- (id<WSBIP32Keyring>)keyringAtNode:(WSBIP32Node *)node;
- (id<WSBIP32Keyring>)keyringAtNodes:(NSArray *)nodes;
- (id<WSBIP32PublicKeyring>)publicKeyring;
- (WSKey *)privateKey;
- (WSPublicKey *)publicKey;
- (WSAddress *)address;

//
// Master: "m"
//
- (WSBIP32Key *)extendedPrivateKey;
- (WSBIP32Key *)extendedPublicKey;

//
// Accounts: "m/k"
//
//      k: [0, WSBIP32HardenedMask)
//
- (id<WSBIP32Keyring>)keyringForAccount:(uint32_t)account;
- (WSKey *)privateKeyForAccount:(uint32_t)account;
- (WSPublicKey *)publicKeyForAccount:(uint32_t)account;

//
// Chains: "m/k'/h"
//
//      k: [0, WSBIP32HardenedMask)
//      h: {0, 1}
//
- (id<WSBIP32Keyring>)chainForAccount:(uint32_t)account internal:(BOOL)internal;
- (id<WSBIP32PublicKeyring>)publicChainForAccount:(uint32_t)account internal:(BOOL)internal;

//
// Addresses: "m/k'/h/i"
//
//      k: [WSBIP32HardenedMask, UINT32_MAX)
//      h: {0, 1}
//      i: [0, UINT32_MAX)
//

@end

#pragma mark -

@protocol WSBIP32PublicKeyring <NSObject>

- (id<WSBIP32PublicKeyring>)publicKeyringAtPath:(NSString *)path;
- (id<WSBIP32PublicKeyring>)publicKeyringAtNode:(WSBIP32Node *)node;
- (id<WSBIP32PublicKeyring>)publicKeyringAtNodes:(NSArray *)nodes;
- (WSPublicKey *)publicKey;
- (WSAddress *)address;

//
// Master: "m"
//
- (WSBIP32Key *)extendedPublicKey;

//
// Accounts: "m/k"
//
//      k: [0, WSBIP32HardenedMask)
//
- (id<WSBIP32PublicKeyring>)publicKeyringForAccount:(uint32_t)account;
- (WSPublicKey *)publicKeyForAccount:(uint32_t)account;

@end

#pragma mark -

@interface WSBIP32Key : NSObject

- (instancetype)initPrivateWithParameters:(WSParameters *)parameters
                                    depth:(uint8_t)depth
                        parentFingerprint:(uint32_t)parentFingerprint
                                    child:(uint32_t)child
                                chainData:(NSData *)chainData
                                  keyData:(NSData *)keyData;

- (instancetype)initPublicWithParameters:(WSParameters *)parameters
                                   depth:(uint8_t)depth
                       parentFingerprint:(uint32_t)parentFingerprint
                                   child:(uint32_t)child
                               chainData:(NSData *)chainData
                                 keyData:(NSData *)keyData;

- (WSParameters *)parameters;
- (uint32_t)version;
- (uint8_t)depth;
- (uint32_t)parentFingerprint;
- (uint32_t)child;
- (NSData *)chainData;
- (NSData *)keyData;

- (BOOL)isPrivate;
- (BOOL)isPublic;
- (WSKey *)privateKey;
- (WSPublicKey *)publicKey;
- (NSString *)serializedKey;

@end

#pragma mark -

@interface WSBIP32Node : NSObject

+ (NSArray *)parseNodesFromPath:(NSString *)path;
+ (instancetype)nodeWithString:(NSString *)string;
+ (instancetype)nodeWithChild:(uint32_t)child;
+ (instancetype)nodeWithIndex:(uint32_t)index hardened:(BOOL)hardened;
- (uint32_t)index;
- (BOOL)hardened;
- (uint32_t)child;

@end
