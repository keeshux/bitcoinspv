//
//  WSPublicKey.m
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

#import "WSPublicKey.h"
#import "WSKey.h"
#import "WSHash256.h"
#import "WSBitcoinConstants.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"
#import "NSData+Hash.h"
#import "NSData+Binary.h"

// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRKey.m

@interface WSPublicKey ()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, unsafe_unretained) EC_KEY *key;

- (instancetype)initWithData:(NSData *)data;

@end

@implementation WSPublicKey

+ (instancetype)publicKeyWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

+ (instancetype)publicKeyWithPrivateData:(NSData *)data
{
    return [self publicKeyWithPrivateData:data compressed:YES];
}

+ (instancetype)publicKeyWithPrivateData:(NSData *)data compressed:(BOOL)compressed
{
    return [[WSKey keyWithData:data compressed:compressed] publicKey];
}

- (instancetype)initWithData:(NSData *)data
{
    if ((data.length != WSPublicKeyUncompressedLength) && (data.length != WSPublicKeyCompressedLength)) {
        DDLogVerbose(@"Incorrect public key data (length: %u != %u | %u)",
                     data.length, WSPublicKeyUncompressedLength, WSPublicKeyCompressedLength);

        return nil;
    }

    EC_KEY *key = EC_KEY_new_by_curve_name(NID_secp256k1);
    if (!key) {
        return nil;
    }

    if ((self = [super init])) {
        self.key = key;

        const unsigned char *bytes = data.bytes;
        o2i_ECPublicKey(&_key, &bytes, data.length);
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

- (BOOL)isCompressed
{
    return (self.data.length == WSPublicKeyCompressedLength);
}

- (NSData *)encodedData
{
    if (!EC_KEY_check_key(_key)) {
        return nil;
    }
    
    size_t l = i2o_ECPublicKey(_key, NULL);
    NSMutableData *data = [[NSMutableData alloc] initWithLength:l];
    unsigned char *bytes = [data mutableBytes];
    if (i2o_ECPublicKey(_key, &bytes) != l) {
        return nil;
    }
    return data;
}

- (WSHash160 *)hash160
{
    return WSHash160FromData([[self encodedData] hash160]);
}

- (WSAddress *)addressWithParameters:(id<WSParameters>)parameters
{
    WSExceptionCheckIllegal(parameters != nil, @"Nil parameters");
    
    return WSAddressP2PKHFromHash160(parameters, [self hash160]);
}

- (BOOL)verifyHash256:(WSHash256 *)hash256 signature:(NSData *)signature
{
    // -1 = error
    //  0 = bad sig
    //  1 = good
    return (ECDSA_verify(0, hash256.bytes, (int)hash256.length, signature.bytes, (int)signature.length, _key) == 1);
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSPublicKey *key = object;
    return ([key.data isEqualToData:self.data] && ([key isCompressed] == [self isCompressed]));
}

- (NSUInteger)hash
{
    return [self.data hash];
}

- (NSString *)description
{
    return [[self encodedData] hexString];
}

@end
