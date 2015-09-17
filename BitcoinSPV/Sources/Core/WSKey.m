//
//  WSKey.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 14/06/14.
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

#import <CommonCrypto/CommonHMAC.h>
#import <openssl/ecdsa.h>
#import <openssl/obj_mac.h>

#import "WSKey.h"
#import "WSPublicKey.h"
#import "WSHash256.h"
#import "WSBitcoinConstants.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSString+Base58.h"
#import "NSString+Binary.h"
#import "NSData+Base58.h"
#import "NSData+Binary.h"

// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRKey.m

static NSData *WSKeyHMAC_DRBG(NSData *entropy, NSData *nonce);

@interface WSKey ()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, unsafe_unretained) EC_KEY *key;

- (instancetype)initWithData:(NSData *)data compressed:(BOOL)compressed;

@end

@implementation WSKey

+ (instancetype)keyWithData:(NSData *)data
{
    return [self keyWithData:data compressed:YES];
}

+ (instancetype)keyWithData:(NSData *)data compressed:(BOOL)compressed
{
    return [[self alloc] initWithData:data compressed:compressed];
}

+ (instancetype)keyWithWIF:(NSString *)wif parameters:(WSParameters *)parameters
{
    WSExceptionCheckIllegal(wif);
    WSExceptionCheckIllegal(parameters);

    NSData *encodedData = [[wif hexFromBase58Check] dataFromHex];
    uint8_t version = *(const uint8_t *)encodedData.bytes;

    WSExceptionCheckIllegal(version == [parameters privateKeyVersion]);
    WSExceptionCheckIllegal((encodedData.length == WSKeyEncodedCompressedLength) || (encodedData.length == WSKeyEncodedUncompressedLength));

    NSData *data = [encodedData subdataWithRange:NSMakeRange(1, WSKeyLength)];
    const BOOL compressed = (encodedData.length == WSKeyEncodedCompressedLength);

    return [[self alloc] initWithData:data compressed:compressed];
}

- (instancetype)initWithData:(NSData *)data compressed:(BOOL)compressed
{
    if (data.length != WSKeyLength) {
        DDLogVerbose(@"Incorrect private key data (length: %lu != %lu)",
                     (unsigned long)data.length, (unsigned long)WSKeyLength);
        return nil;
    }
    
    EC_KEY *key = EC_KEY_new_by_curve_name(NID_secp256k1);
    if (!key) {
        return nil;
    }
    
    const EC_GROUP *group = EC_KEY_get0_group(key);
    EC_POINT *pub = EC_POINT_new(group);
    if (!pub) {
        return nil;
    }

    BN_CTX *ctx = BN_CTX_new();
    if (!ctx) {
        EC_POINT_free(pub);
        return nil;
    }
    
    BIGNUM priv;
    BN_CTX_start(ctx);
    BN_init(&priv);
    BN_bin2bn(data.bytes, (int)WSKeyLength, &priv);
    
    if (EC_POINT_mul(group, pub, &priv, NULL, NULL, ctx)) {
        EC_KEY_set_private_key(key, &priv);
        EC_KEY_set_public_key(key, pub);
        EC_KEY_set_conv_form(key, compressed ? POINT_CONVERSION_COMPRESSED : POINT_CONVERSION_UNCOMPRESSED);
    }
    
    EC_POINT_free(pub);
    BN_clear_free(&priv);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);

    if ((self = [super init])) {
        self.key = key;
        self.data = data;
    }
    return self;
}

- (void)dealloc
{
    if (self.key) {
        EC_KEY_free(self.key);
    }
}

- (WSPublicKey *)publicKey
{
    if (!EC_KEY_check_key(self.key)) {
        return nil;
    }
    
    size_t l = i2o_ECPublicKey(self.key, NULL);
    NSMutableData *pubKey = [[NSMutableData alloc] initWithLength:l];
    unsigned char *bytes = [pubKey mutableBytes];
    if (i2o_ECPublicKey(self.key, &bytes) != l) {
        return nil;
    }
    return [WSPublicKey publicKeyWithData:pubKey];
}

- (NSData *)encodedDataWithParameters:(WSParameters *)parameters
{
    WSExceptionCheckIllegal(parameters);
    
    if (!EC_KEY_check_key(self.key)) {
        return nil;
    }
    
    const BIGNUM *priv = EC_KEY_get0_private_key(self.key);
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:(WSKeyLength + 2)];

    const uint8_t version = [parameters privateKeyVersion];
    [data appendBytes:&version length:1];

    data.length = WSKeyLength + 1;
    BN_bn2bin(priv, (unsigned char *)data.mutableBytes + data.length - BN_num_bytes(priv));
    if ([self isCompressed]) {
        [data appendBytes:"\x01" length:1];
    }
    
    return data;
}

- (NSString *)WIFWithParameters:(WSParameters *)parameters
{
    return [[self encodedDataWithParameters:parameters] base58CheckString];
}

- (NSData *)signatureForHash256:(WSHash256 *)hash256
{
    WSExceptionCheckIllegal(hash256);

    BN_CTX *ctx = BN_CTX_new();
    BIGNUM order, halforder, k, r;
    const BIGNUM *priv = EC_KEY_get0_private_key(self.key);
    const EC_GROUP *group = EC_KEY_get0_group(self.key);
    EC_POINT *p = EC_POINT_new(group);
    NSMutableData *sig = nil;
    NSMutableData *entropy = [[NSMutableData alloc] initWithLength:32];
    unsigned char *b;
    
    BN_CTX_start(ctx);
    BN_init(&order);
    BN_init(&halforder);
    BN_init(&k);
    BN_init(&r);
    EC_GROUP_get_order(group, &order, ctx);
    BN_rshift1(&halforder, &order);
    
    // generate k deterministicly per RFC6979: https://tools.ietf.org/html/rfc6979
    BN_bn2bin(priv, (unsigned char *)[entropy mutableBytes] + entropy.length - BN_num_bytes(priv));
    BN_bin2bn(WSKeyHMAC_DRBG(entropy, hash256.data).bytes, CC_SHA256_DIGEST_LENGTH, &k);
    
    EC_POINT_mul(group, p, &k, NULL, NULL, ctx); // compute r, the x-coordinate of generator*k
    EC_POINT_get_affine_coordinates_GFp(group, p, &r, NULL, ctx);
    
    BN_mod_inverse(&k, &k, &order, ctx); // compute the inverse of k
    
    ECDSA_SIG *s = ECDSA_do_sign_ex(hash256.bytes, (int)hash256.length, &k, &r, self.key);
    
    if (s) {
        // enforce low s values, negate the value (modulo the order) if above order/2.
        if (BN_cmp(s->s, &halforder) > 0) {
            BN_sub(s->s, &order, s->s);
        }
        
        sig = [NSMutableData dataWithLength:ECDSA_size(self.key)];
        b = sig.mutableBytes;
        sig.length = i2d_ECDSA_SIG(s, &b);
        ECDSA_SIG_free(s);
    }
    
    EC_POINT_clear_free(p);
    BN_clear_free(&r);
    BN_clear_free(&k);
    BN_free(&halforder);
    BN_free(&order);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    
    return sig;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSKey *key = object;
    return ([key.data isEqualToData:self.data] && ([key isCompressed] == [self isCompressed]));
}

- (NSUInteger)hash
{
    return [self.data hash];
}

- (NSString *)description
{
    return [self.data hexString];
}

#pragma mark WSAbstractKey

- (BOOL)isCompressed
{
    return (EC_KEY_get_conv_form(self.key) == POINT_CONVERSION_COMPRESSED);
}

- (WSAddress *)addressWithParameters:(WSParameters *)parameters
{
    return [[self publicKey] addressWithParameters:parameters];
}

- (BOOL)verifyHash256:(WSHash256 *)hash256 signature:(NSData *)signature
{
    WSExceptionCheckIllegal(hash256);
    WSExceptionCheckIllegal(signature);
    
    // -1 = error
    //  0 = bad sig
    //  1 = good
    return (ECDSA_verify(0, hash256.bytes, (int)hash256.length, signature.bytes, (int)signature.length, self.key) == 1);
}

@end

// HMAC-SHA256 DRBG, using no prediction resistance or personalization string and outputing 256bits
static NSData *WSKeyHMAC_DRBG(NSData *entropy, NSData *nonce)
{
    NSMutableData *V = [[NSMutableData alloc] initWithCapacity:(CC_SHA256_DIGEST_LENGTH + 1 + entropy.length + nonce.length)];
    NSMutableData *K = [[NSMutableData alloc] initWithCapacity:CC_SHA256_DIGEST_LENGTH];
    NSMutableData *T = [[NSMutableData alloc] initWithLength:CC_SHA256_DIGEST_LENGTH];
    
    V.length = CC_SHA256_DIGEST_LENGTH;
    memset(V.mutableBytes, 0x01, V.length); // V = 0x01 0x01 0x01 ... 0x01
    
    K.length = CC_SHA256_DIGEST_LENGTH;     // K = 0x00 0x00 0x00 ... 0x00

    [V appendBytes:"\0" length:1];
    [V appendBytes:entropy.bytes length:entropy.length];
    [V appendBytes:nonce.bytes length:nonce.length];
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, K.mutableBytes); // K = HMAC_K(V || 0x00 || seed)
    
    V.length = CC_SHA256_DIGEST_LENGTH;
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, V.mutableBytes); // V = HMAC_K(V)
    
    [V appendBytes:"\x01" length:1];
    [V appendBytes:entropy.bytes length:entropy.length];
    [V appendBytes:nonce.bytes length:nonce.length];
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, K.mutableBytes); // K = HMAC_K(V || 0x01 || seed)
    
    V.length = CC_SHA256_DIGEST_LENGTH;
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, V.mutableBytes); // V = HMAC_K(V)
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, T.mutableBytes); // T = HMAC_K(V)
    
    return T;
}
