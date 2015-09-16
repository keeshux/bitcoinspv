//
//  WSBIP37.m
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

#import "WSBIP37.h"
#import "WSBuffer.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

const uint32_t          WSBIP37MaxFilterSize                    = 36000;
const uint32_t          WSBIP37MaxHashFunctions                 = 50;
const uint32_t          WSBIP37HashMultiplier                   = 0xfba4c795;

static uint32_t WSBIP37MurmurHash3(NSData *data, uint32_t seed);

#pragma mark -

@implementation WSBIP37FilterParameters

- (instancetype)init
{
    if ((self = [super init])) {
        self.falsePositiveRate = DBL_EPSILON;
        self.flags = WSBIP37FlagsUpdateNone;
        self.tweak = (uint32_t)arc4random();
    }
    return self;
}

- (void)setFalsePositiveRate:(double)falsePositiveRate
{
    WSExceptionCheckIllegal(falsePositiveRate > 0.0);

    _falsePositiveRate = falsePositiveRate;
}

- (void)setFlags:(WSBIP37Flags)flags
{
    WSExceptionCheckIllegal((flags >= WSBIP37FlagsUpdateNone) && (flags <= WSBIP37FlagsUpdateP2PubKeyOnly));
    
    _flags = flags;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"{falsePositiveRate=%f, tweak=0x%x, flags=%u}",
            self.falsePositiveRate, self.tweak, self.flags];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSBIP37FilterParameters *copy = [[self class] allocWithZone:zone];
    copy.falsePositiveRate = self.falsePositiveRate;
    copy.flags = self.flags;
    copy.tweak = self.tweak;
    return copy;
}

@end

#pragma mark -

@interface WSBIP37Filter ()

@property (nonatomic, strong) WSBIP37FilterParameters *parameters;
@property (nonatomic, assign) NSUInteger capacity;
@property (nonatomic, strong) NSMutableData *filter;
@property (nonatomic, assign) uint32_t elements;
@property (nonatomic, assign) uint32_t hashFunctions;

- (uint32_t)hashData:(NSData *)data atIndex:(uint32_t)index;

@end

@implementation WSBIP37Filter

- (instancetype)initWithParameters:(WSBIP37FilterParameters *)parameters capacity:(NSUInteger)capacity
{
    WSExceptionCheckIllegal(parameters);
    WSExceptionCheckIllegal(capacity > 0);
    
    if ((self = [super init])) {
        self.parameters = parameters;
        
        NSUInteger size = -1.0 / pow(M_LN2, 2) * capacity * log(parameters.falsePositiveRate) / 8.0;
        if (size < 1) {
            size = 1;
        }
        else if (size > WSBIP37MaxFilterSize) {
            size = WSBIP37MaxFilterSize;
        }
        
        uint32_t hashFunctions = size * 8.0 / capacity * M_LN2;
        if (hashFunctions > WSBIP37MaxHashFunctions) {
            hashFunctions = WSBIP37MaxHashFunctions;
        }
        
        self.capacity = capacity;
        self.filter = [[NSMutableData alloc] initWithLength:size];
        self.elements = 0;
        self.hashFunctions = hashFunctions;
    }
    return self;
}

- (instancetype)initWithFullMatch
{
    if ((self = [super init])) {
        self.parameters = [[WSBIP37FilterParameters alloc] init];
        self.parameters.flags = WSBIP37FlagsUpdateNone;
        
        self.filter = [NSMutableData dataWithBytes:"\xFF" length:1];
        self.elements = 0;
        self.hashFunctions = 0;
    }
    return self;
}

- (instancetype)initWithNoMatch
{
    if ((self = [super init])) {
        self.parameters = [[WSBIP37FilterParameters alloc] init];
        self.parameters.flags = WSBIP37FlagsUpdateNone;
        
        self.filter = [NSMutableData dataWithBytes:"\x00" length:1];
        self.elements = 0;
        self.hashFunctions = 0;
    }
    return self;
}

- (void)insertData:(NSData *)data
{
    WSExceptionCheckIllegal(data);

    // if data matches don't get filter dirtier by reinserting
    if ([self containsData:data]) {
        return;
    }
    
    uint8_t *bytes = _filter.mutableBytes;
    for (uint32_t i = 0; i < self.hashFunctions; ++i) {
        const uint32_t h = [self hashData:data atIndex:i];
        bytes[h >> 3] |= (1 << (7 & h));
    }
    ++self.elements;
}

- (BOOL)containsData:(NSData *)data
{
    WSExceptionCheckIllegal(data);
    
    const uint8_t *bytes = self.filter.bytes;
    for (uint32_t i = 0; i < self.hashFunctions; ++i) {
        const uint32_t h = [self hashData:data atIndex:i];
        if (!(bytes[h >> 3] & (1 << (7 & h)))) {
            return NO;
        }
    }
    return YES;
}

- (NSUInteger)size
{
    return self.filter.length;
}

- (double)estimatedFalsePositiveRate
{
    return pow(1 - pow(M_E, -1.0 * self.hashFunctions * self.elements / (self.filter.length * 8.0)), self.hashFunctions);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"{size=%lu, estimatedFalsePositiveRate=%f}",
            (unsigned long)self.size, self.estimatedFalsePositiveRate];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSBIP37Filter *copy = [[self class] allocWithZone:zone];
    copy.capacity = self.capacity;
    copy.filter = [self.filter mutableCopyWithZone:zone];
    copy.elements = self.elements;
    copy.hashFunctions = self.hashFunctions;
    return copy;
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendVarData:self.filter];
    [buffer appendUint32:self.hashFunctions];
    [buffer appendUint32:self.parameters.tweak];
    [buffer appendUint8:self.parameters.flags];
}

- (WSBuffer *)toBuffer
{
    // var_int + filter + hashes + tweak + flags
    const NSUInteger capacity = 8 + self.filter.length + 4 + 4 + 1;
    
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:capacity];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark Utils

- (uint32_t)hashData:(NSData *)data atIndex:(uint32_t)index
{
    NSParameterAssert(data);
    
    return WSBIP37MurmurHash3(data, self.parameters.tweak + index * WSBIP37HashMultiplier) % (self.filter.length * 8);
}

@end

#pragma mark -

//
// adapted from: https://github.com/voisine/breadwallet/blob/master/BreadWallet/BRBloomFilter.m
//
// murmurHash3 (x86_32): http://code.google.com/p/smhasher/source/browse/trunk/MurmurHash3.cpp
//
static uint32_t WSBIP37MurmurHash3(NSData *data, uint32_t seed)
{
    static const uint32_t c1 = 0xcc9e2d51;
    static const uint32_t c2 = 0x1b873593;
    uint32_t h1 = seed;
    uint32_t k1 = 0;
    uint32_t k2 = 0;
    uint32_t blocks = ((uint32_t)data.length / 4) * 4;
    const uint8_t *b = data.bytes;
    
    for (NSUInteger i = 0; i < blocks; i += 4) {
        k1 = ((uint32_t)b[i] | ((uint32_t)b[i + 1] << 8) |
              ((uint32_t)b[i + 2] << 16) | ((uint32_t)b[i + 3] << 24)) * c1;
        
        k1 = ((k1 << 15) | (k1 >> 17)) * c2;
        h1 ^= k1;
        h1 = ((h1 << 13) | (h1 >> 19)) * 5 + 0xe6546b64;
    }
    
    switch (data.length & 3) {
        case 3: {
            k2 ^= b[blocks + 2] << 16; // fall through
        }
        case 2: {
            k2 ^= b[blocks + 1] << 8; // fall through
        }
        case 1: {
            k2 = (k2 ^ b[blocks])*c1;
            h1 ^= ((k2 << 15) | (k2 >> 17))*c2;
        }
    }
    
    h1 ^= data.length;
    h1 = (h1 ^ (h1 >> 16)) * 0x85ebca6b;
    h1 = (h1 ^ (h1 >> 13)) * 0xc2b2ae35;
    h1 ^= h1 >> 16;
    
    return h1;
}
