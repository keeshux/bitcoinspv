//
//  WSBIP32.m
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
#import <openssl/ecdsa.h>
#import <openssl/obj_mac.h>
#import <openssl/bn.h>

#import "WSBIP32.h"
#import "WSKey.h"
#import "WSPublicKey.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSData+Base58.h"

const char *            WSBIP32InitSeed                         = "Bitcoin seed";
const uint32_t          WSBIP32HardenedMask                     = 0x80000000;
const NSUInteger        WSBIP32KeyLength                        = 78;

static NSString *const  WSBIP32PathValidityRegex                = @"m(/[1-9]?\\d+'?)*";
static const unichar    WSBIP32PrimeChar                        = '\'';

static NSString *const  WSBIP32PathFormat                       = @"m/%u'";

NSString *WSBIP32PathForAccount(uint32_t account)
{
    return [NSString stringWithFormat:WSBIP32PathFormat, account];
}

#pragma mark -

@interface WSBIP32Key ()

@property (nonatomic, strong) WSParameters *parameters;
@property (nonatomic, assign) uint32_t version;
@property (nonatomic, assign) uint8_t depth;
@property (nonatomic, assign) uint32_t parentFingerprint;
@property (nonatomic, assign) uint32_t child;
@property (nonatomic, copy) NSData *chainData;
@property (nonatomic, copy) NSData *keyData;

- (instancetype)initWithParameters:(WSParameters *)parameters
                           version:(uint32_t)version
                             depth:(uint8_t)depth
                 parentFingerprint:(uint32_t)parentFingerprint
                             child:(uint32_t)child
                         chainData:(NSData *)chainData
                           keyData:(NSData *)keyData;

@end

@implementation WSBIP32Key

- (instancetype)initPrivateWithParameters:(WSParameters *)parameters depth:(uint8_t)depth parentFingerprint:(uint32_t)parentFingerprint child:(uint32_t)child chainData:(NSData *)chainData keyData:(NSData *)keyData
{
    return [self initWithParameters:parameters version:[parameters bip32PrivateKeyVersion] depth:depth parentFingerprint:parentFingerprint child:child chainData:chainData keyData:keyData];
}

- (instancetype)initPublicWithParameters:(WSParameters *)parameters depth:(uint8_t)depth parentFingerprint:(uint32_t)parentFingerprint child:(uint32_t)child chainData:(NSData *)chainData keyData:(NSData *)keyData
{
    return [self initWithParameters:parameters version:[parameters bip32PublicKeyVersion] depth:depth parentFingerprint:parentFingerprint child:child chainData:chainData keyData:keyData];
}

- (instancetype)initWithParameters:(WSParameters *)parameters
                           version:(uint32_t)version
                             depth:(uint8_t)depth
                 parentFingerprint:(uint32_t)parentFingerprint
                             child:(uint32_t)child
                         chainData:(NSData *)chainData
                           keyData:(NSData *)keyData
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(chainData);
    WSExceptionCheckIllegal(keyData);

    if ((self = [super init])) {
        self.parameters = parameters;
        self.version = version;
        self.depth = depth;
        self.parentFingerprint = parentFingerprint;
        self.child = child;
        self.chainData = chainData;
        self.keyData = keyData;
    }
    return self;
}

- (BOOL)isPrivate
{
    return (self.version == [self.parameters bip32PrivateKeyVersion]);
}

- (BOOL)isPublic
{
    return (self.version == [self.parameters bip32PublicKeyVersion]);
}

- (WSKey *)privateKey
{
    if ([self isPrivate]) {
        return [WSKey keyWithData:self.keyData];
    }
    else {
        return nil;
    }
}

- (WSPublicKey *)publicKey
{
    if ([self isPrivate]) {
        return [WSPublicKey publicKeyWithPrivateData:self.keyData];
    }
    else {
        return [WSPublicKey publicKeyWithData:self.keyData];
    }
}

- (NSString *)serializedKey
{
    NSMutableData *encoded = [[NSMutableData alloc] initWithCapacity:WSBIP32KeyLength];
    
    const uint32_t encVersion = CFSwapInt32HostToBig(self.version);
    const uint8_t encDepth = self.depth;
    const uint32_t encParentFingerprint = CFSwapInt32HostToBig(self.parentFingerprint);
    const uint32_t encChild = CFSwapInt32HostToBig(self.child);
    
    [encoded appendBytes:&encVersion length:sizeof(encVersion)];
    [encoded appendBytes:&encDepth length:sizeof(encDepth)];
    [encoded appendBytes:&encParentFingerprint length:sizeof(encParentFingerprint)];
    [encoded appendBytes:&encChild length:sizeof(encChild)];
    [encoded appendData:self.chainData];
    if ([self isPrivate]) {
        [encoded appendBytes:"\0" length:1];
    }
    [encoded appendData:self.keyData];
    
    return [encoded base58CheckString];
}

- (NSString *)description
{
    return [self serializedKey];
}

@end

#pragma mark -

@interface WSBIP32Node ()

@property (nonatomic, assign) uint32_t index;
@property (nonatomic, assign) BOOL hardened;
@property (nonatomic, assign) uint32_t child;

@end

@implementation WSBIP32Node

+ (NSArray *)parseNodesFromPath:(NSString *)path
{
    WSExceptionCheckIllegal(path);
    
    static NSRegularExpression *rx;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rx = [[NSRegularExpression alloc] initWithPattern:WSBIP32PathValidityRegex options:0 error:nil];
    });

    if ([rx numberOfMatchesInString:path options:0 range:NSMakeRange(0, [path length])] == 0) {
        DDLogDebug(@"Path format is incorrect");
        return nil;
    }
    
    NSArray *components = [path componentsSeparatedByString:@"/"];
    NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:components.count];
    
    for (NSString *component in components) {
        WSBIP32Node *node = [WSBIP32Node nodeWithString:component];
        if (node) {
            [nodes addObject:node];
        }
    }
    return nodes;
}

// WARNING: assumes correct format for efficiency, "[1-9]?[0-9]+'?" (e.g.: "12'")
+ (instancetype)nodeWithString:(NSString *)string
{
    WSExceptionCheckIllegal(string.length > 0);

    if ([string isEqualToString:@"m"]) {
        return nil;
    }
    
    const NSUInteger lastIndex = string.length - 1;
    const BOOL hardened = ([string characterAtIndex:lastIndex] == WSBIP32PrimeChar);
    
    NSString *indexString;
    if (hardened) {
        indexString = [string substringToIndex:lastIndex];
    }
    else {
        indexString = string;
    }
    const uint32_t index = (uint32_t)[indexString integerValue];

    return [self nodeWithIndex:index hardened:hardened];
}

+ (instancetype)nodeWithChild:(uint32_t)child
{
    return [[self alloc] initWithIndex:WSBIP32ChildIndex(child) hardened:WSBIP32ChildIsHardened(child)];
}

+ (instancetype)nodeWithIndex:(uint32_t)index hardened:(BOOL)hardened
{
    return [[self alloc] initWithIndex:index hardened:hardened];
}

- (instancetype)initWithIndex:(uint32_t)index hardened:(BOOL)hardened
{
    if ((self = [super init])) {
        self.index = index;
        self.hardened = hardened;
        self.child = self.index;
        if (self.hardened) {
            self.child |= WSBIP32HardenedMask;
        }
    }
    return self;
}

- (NSString *)description
{
    if (self.hardened) {
        return [NSString stringWithFormat:@"%u%c", self.index, WSBIP32PrimeChar];
    }
    else {
        return [NSString stringWithFormat:@"%u", self.index];
    }
}

@end

#pragma mark -

//
// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRBIP32Sequence.m
//
// Private child key derivation:
//
// To define CKDpriv((kpar, cpar), i) -> (ki, ci):
//
// - Check whether the highest bit (0x80000000) of i is set
//     - If 1, private derivation is used: let I = HMAC-SHA512(Key = cpar, Data = 0x00 || kpar || i)
//       [Note: The 0x00 pads the private key to make it 33 bytes long.]
//     - If 0, public derivation is used: let I = HMAC-SHA512(Key = cpar, Data = X(kpar*G) || i)
// - Split I = Il || Ir into two 32-byte sequences, Il and Ir.
// - ki = Il + kpar (mod n).
// - ci = Ir.
//
void WSBIP32CKDpriv(NSMutableData *privKey, NSMutableData *chain, uint32_t i)
{
    NSCAssert(privKey, @"Deriving nil private key");
    
    NSMutableData *I = [[NSMutableData alloc] initWithLength:CC_SHA512_DIGEST_LENGTH];
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:(33 + sizeof(i))];
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM order, Ilbn, kbn;
    EC_GROUP *group = EC_GROUP_new_by_curve_name(NID_secp256k1);
    
    // hardened: private derivation
    if (WSBIP32ChildIsHardened(i)) {
        data.length = 33 - privKey.length;
        [data appendData:privKey];
    }
    // non-hardened: public derivation
    else {
#warning TODO: public key calculation can probably be optimized
        WSPublicKey *pubKey = [WSPublicKey publicKeyWithPrivateData:privKey];
        [data setData:pubKey.data];
    }
    
    i = CFSwapInt32HostToBig(i);
    [data appendBytes:&i length:sizeof(i)];
    
    CCHmac(kCCHmacAlgSHA512, chain.bytes, chain.length, data.bytes, data.length, I.mutableBytes);
    
    BN_CTX_start(ctx);
    BN_init(&order);
    BN_init(&Ilbn);
    BN_init(&kbn);
    BN_bin2bn(I.bytes, 32, &Ilbn);
    BN_bin2bn(privKey.bytes, (int)privKey.length, &kbn);
    EC_GROUP_get_order(group, &order, ctx);
    
    BN_mod_add(&kbn, &Ilbn, &kbn, &order, ctx);
    
    privKey.length = 32;
    [privKey resetBytesInRange:NSMakeRange(0, 32)];
    BN_bn2bin(&kbn, (unsigned char *)privKey.mutableBytes + 32 - BN_num_bytes(&kbn));
    [chain replaceBytesInRange:NSMakeRange(0, chain.length) withBytes:((const unsigned char *)I.bytes + 32) length:32];
    
    EC_GROUP_free(group);
    BN_clear_free(&kbn);
    BN_clear_free(&Ilbn);
    BN_free(&order);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
}

//
// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRBIP32Sequence.m
//
// Public child key derivation (cannot derive hardened children):
//
// To define CKDpub((Kpar, cpar), i) -> (Ki, ci):
//
// - Check whether the highest bit (0x80000000) of i is set
//     - If 1, return error
//     - If 0, let I = HMAC-SHA512(Key = cpar, Data = X(Kpar) || i)
// - Split I = Il || Ir into two 32-byte sequences, Il and Ir.
// - Ki = (Il + kpar)*G = Il*G + Kpar
// - ci = Ir.
//
void WSBIP32CKDpub(NSMutableData *pubKey, NSMutableData *chain, uint32_t i)
{
    NSCAssert(pubKey, @"Deriving nil public key");
    WSExceptionCheckIllegal(!WSBIP32ChildIsHardened(i));
    
    NSMutableData *I = [[NSMutableData alloc] initWithLength:CC_SHA512_DIGEST_LENGTH];
    NSMutableData *data = [pubKey mutableCopy];
    uint8_t form = POINT_CONVERSION_COMPRESSED;
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM Ilbn;
    EC_GROUP *group = EC_GROUP_new_by_curve_name(NID_secp256k1);
    EC_POINT *pubKeyPoint = EC_POINT_new(group);
    EC_POINT *IlPoint = EC_POINT_new(group);
    
    i = CFSwapInt32HostToBig(i);
    [data appendBytes:&i length:sizeof(i)];
    
    CCHmac(kCCHmacAlgSHA512, chain.bytes, chain.length, data.bytes, data.length, I.mutableBytes);
    
    BN_CTX_start(ctx);
    BN_init(&Ilbn);
    BN_bin2bn(I.bytes, 32, &Ilbn);
    EC_GROUP_set_point_conversion_form(group, form);
    EC_POINT_oct2point(group, pubKeyPoint, pubKey.bytes, pubKey.length, ctx);
    
    EC_POINT_mul(group, IlPoint, &Ilbn, NULL, NULL, ctx);
    EC_POINT_add(group, pubKeyPoint, IlPoint, pubKeyPoint, ctx);
    
    pubKey.length = EC_POINT_point2oct(group, pubKeyPoint, form, NULL, 0, ctx);
    EC_POINT_point2oct(group, pubKeyPoint, form, pubKey.mutableBytes, pubKey.length, ctx);
    [chain replaceBytesInRange:NSMakeRange(0, chain.length) withBytes:((const unsigned char *)I.bytes + 32) length:32];
    
    EC_POINT_clear_free(IlPoint);
    EC_POINT_clear_free(pubKeyPoint);
    EC_GROUP_free(group);
    BN_clear_free(&Ilbn);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
}
