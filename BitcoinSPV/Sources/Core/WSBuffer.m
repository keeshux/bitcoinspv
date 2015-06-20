//
//  WSBuffer.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 16/06/14.
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

#import "WSBuffer.h"
#import "WSHash256.h"
#import "WSHash160.h"
#import "WSNetworkAddress.h"
#import "WSInventory.h"
#import "WSLogging.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"
#import "NSData+Hash.h"
#import "NSData+Binary.h"

@interface WSBuffer ()

@property (nonatomic, strong) NSMutableData *mutableData;

- (instancetype)initWithCapacity:(NSUInteger)capacity;

@end

@implementation WSBuffer

- (instancetype)init
{
    if ((self = [super init])) {
        self.mutableData = [[NSMutableData alloc] init];
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    WSExceptionCheckIllegal(data);
    
    if ((self = [super init])) {
        self.mutableData = [data mutableCopy];
    }
    return self;
}

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
    if ((self = [super init])) {
        self.mutableData = [[NSMutableData alloc] initWithCapacity:capacity];
    }
    return self;
}

- (NSData *)data
{
    return _mutableData;
}

- (uint8_t)uint8AtOffset:(NSUInteger)offset
{
    if (self.data.length < offset + sizeof(uint8_t)) {
        return 0;
    }
    return *((const uint8_t *)self.data.bytes + offset);
}

- (uint16_t)uint16AtOffset:(NSUInteger)offset
{
    if (self.data.length < offset + sizeof(uint16_t)) {
        return 0;
    }
    return CFSwapInt16LittleToHost(*(const uint16_t *)((const uint8_t *)self.data.bytes + offset));
}

- (uint32_t)uint32AtOffset:(NSUInteger)offset
{
    if (self.data.length < offset + sizeof(uint32_t)) {
        return 0;
    }
    return CFSwapInt32LittleToHost(*(const uint32_t *)((const uint8_t *)self.data.bytes + offset));
}

- (uint64_t)uint64AtOffset:(NSUInteger)offset
{
    if (self.data.length < offset + sizeof(uint64_t)) {
        return 0;
    }
    return CFSwapInt64LittleToHost(*(const uint64_t *)((const uint8_t *)self.data.bytes + offset));
}

- (uint64_t)varIntAtOffset:(NSUInteger)offset length:(NSUInteger *)length
{
    uint8_t h = [self uint8AtOffset:offset];
    
    if (h == WSBufferVarInt16Byte) {
        if (length) {
            *length = sizeof(h) + sizeof(uint16_t);
        }
        return [self uint16AtOffset:offset + 1];
        
    } else if (h == WSBufferVarInt32Byte) {
        if (length) {
            *length = sizeof(h) + sizeof(uint32_t);
        }
        return [self uint32AtOffset:offset + 1];
        
    } else if (h == WSBufferVarInt64Byte) {
        if (length) {
            *length = sizeof(h) + sizeof(uint64_t);
        }
        return [self uint64AtOffset:offset + 1];
        
    } else {
        if (length) {
            *length = sizeof(h);
        }
        return h;
    }
}

- (NSString *)stringAtOffset:(NSUInteger)offset length:(NSUInteger *)length
{
    NSUInteger varIntLength;
    NSUInteger stringLength = (NSUInteger)[self varIntAtOffset:offset length:&varIntLength];
    const NSUInteger totalLength = varIntLength + stringLength;
    
    if (length) {
        *length = totalLength;
    }
    if ((varIntLength == 0) || (self.data.length < offset + totalLength)) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:((const char *)self.data.bytes + offset + varIntLength) length:stringLength encoding:NSUTF8StringEncoding];
}

- (WSNetworkAddress *)networkAddressAtOffset:(NSUInteger)offset
{
    NSError *error;
    WSNetworkAddress *address = [[WSNetworkAddress alloc] initWithParameters:nil buffer:self from:offset available:WSNetworkAddressLength error:&error];
    if (!address) {
        DDLogDebug(@"Malformed network address (%@)", error);
        return nil;
    }
    return address;
}

- (WSNetworkAddress *)legacyNetworkAddressAtOffset:(NSUInteger)offset
{
    NSError *error;
    WSNetworkAddress *address = [[WSNetworkAddress alloc] initWithParameters:nil buffer:self from:offset available:WSNetworkAddressLegacyLength error:&error];
    if (!address) {
        DDLogDebug(@"Malformed legacy network address (%@)", error);
        return nil;
    }
    return address;
}

- (WSInventory *)inventoryAtOffset:(NSUInteger)offset
{
    NSError *error;
    WSInventory *inventory = [[WSInventory alloc] initWithParameters:nil buffer:self from:offset available:WSInventoryLength error:&error];
    if (!inventory) {
        DDLogDebug(@"Malformed inventory (%@)", error);
        return nil;
    }
    return inventory;
}

- (WSHash256 *)hash256AtOffset:(NSUInteger)offset
{
    WSHash256 *hash256 = WSHash256FromData([self.data subdataWithRange:NSMakeRange(offset, WSHash256Length)]);
    if (!hash256) {
        return nil;
    }
    return hash256;
}

- (NSData *)varDataAtOffset:(NSUInteger)offset length:(NSUInteger *)length
{
    NSUInteger varIntLength;
    NSUInteger dataLength = (NSUInteger)[self varIntAtOffset:offset length:&varIntLength];
    const NSUInteger totalLength = varIntLength + dataLength;
    
    if (length) {
        *length = totalLength;
    }
    if ((varIntLength == 0) || (self.data.length < offset + totalLength)) {
        return nil;
    }
    return [self.data subdataWithRange:NSMakeRange(offset + varIntLength, dataLength)];
}

- (NSData *)dataAtOffset:(NSUInteger)offset length:(NSUInteger)length
{
    if (self.data.length < offset + length) {
        return nil;
    }
    return [self.data subdataWithRange:NSMakeRange(offset, length)];
}

- (WSBuffer *)subBufferWithRange:(NSRange)range
{
    return [[WSBuffer alloc] initWithData:[self.data subdataWithRange:range]];
}

- (WSHash256 *)computeHash256
{
    return WSHash256Compute(self.data);
}

- (WSHash160 *)computeHash160
{
    return WSHash160Compute(self.data);
}

- (NSString *)hexString
{
    return [self.data hexString];
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSBuffer *buffer = object;
    return [buffer.data isEqualToData:self.data];
}

- (NSUInteger)hash
{
    return [self.data hash];
}

- (NSString *)description
{
    return [self.data description];
}

#pragma mark NSData

- (const void *)bytes
{
    return self.data.bytes;
}

- (NSUInteger)length
{
    return self.data.length;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    WSBuffer *copy = [[self class] allocWithZone:zone];
    copy.mutableData = [self.data mutableCopyWithZone:zone];
    return copy;
}

#pragma mark NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone
{
    WSMutableBuffer *copy = [WSMutableBuffer allocWithZone:zone];
    copy.mutableData = [self.data mutableCopyWithZone:zone];
    return copy;
}

@end

#pragma mark -

@implementation WSMutableBuffer

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
    return [super initWithCapacity:capacity];
}

- (NSMutableData *)mutableData
{
    return [super mutableData];
}

- (void)appendUint8:(uint8_t)n
{
    [self.mutableData appendBytes:&n length:sizeof(n)];
}

- (void)appendUint16:(uint16_t)n
{
    n = CFSwapInt16HostToLittle(n);
    [self.mutableData appendBytes:&n length:sizeof(n)];
}

- (void)appendUint32:(uint32_t)n
{
    n = CFSwapInt32HostToLittle(n);
    [self.mutableData appendBytes:&n length:sizeof(n)];
}

- (void)appendUint64:(uint64_t)n
{
    n = CFSwapInt64HostToLittle(n);
    [self.mutableData appendBytes:&n length:sizeof(n)];
}

- (void)appendVarInt:(uint64_t)n
{
    if (n < WSBufferVarInt16Byte) {
        const uint8_t payload = (uint8_t)n;
        
        [self.mutableData appendBytes:&payload length:sizeof(payload)];
    }
    else if (n <= UINT16_MAX) {
        const uint8_t header = WSBufferVarInt16Byte;
        const uint16_t payload = CFSwapInt16HostToLittle((uint16_t)n);
        
        [self.mutableData appendBytes:&header length:sizeof(header)];
        [self.mutableData appendBytes:&payload length:sizeof(payload)];
    }
    else if (n <= UINT32_MAX) {
        const uint8_t header = WSBufferVarInt32Byte;
        const uint32_t payload = CFSwapInt32HostToLittle((uint32_t)n);
        
        [self.mutableData appendBytes:&header length:sizeof(header)];
        [self.mutableData appendBytes:&payload length:sizeof(payload)];
    }
    else {
        const uint8_t header = WSBufferVarInt64Byte;
        const uint64_t payload = CFSwapInt64HostToLittle(n);
        
        [self.mutableData appendBytes:&header length:sizeof(header)];
        [self.mutableData appendBytes:&payload length:sizeof(payload)];
    }
}

- (void)appendString:(NSString *)string
{
    if (!string) {
        return;
    }
    const NSUInteger length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    [self appendVarInt:length];
    [self.mutableData appendBytes:string.UTF8String length:length];
}

- (void)appendNullPaddedString:(NSString *)string length:(NSUInteger)length
{
    if (!string || (length == 0)) {
        return;
    }
    NSUInteger stringLength = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    [self.mutableData appendBytes:string.UTF8String length:stringLength];
    
    while (stringLength < length) {
        [self.mutableData appendBytes:"\0" length:1];
        ++stringLength;
    }
}

- (void)appendNetworkAddress:(WSNetworkAddress *)networkAddress
{
    [networkAddress appendToMutableBuffer:self];
}

- (void)appendInventory:(WSInventory *)inventory
{
    [inventory appendToMutableBuffer:self];
}

- (void)appendHash256:(WSHash256 *)hash256
{
    if (!hash256) {
        return;
    }
    [self.mutableData appendData:hash256.data];
}

- (void)appendData:(NSData *)data
{
    if (!data) {
        return;
    }
    [self.mutableData appendData:data];
}

- (void)appendVarData:(NSData *)data
{
    if (!data) {
        return;
    }
    [self appendVarInt:data.length];
    [self.mutableData appendData:data];
}

- (void)appendBuffer:(WSBuffer *)buffer
{
    if (!buffer) {
        return;
    }
    [self.mutableData appendData:buffer.data];
}

- (void)appendVarBuffer:(WSBuffer *)buffer
{
    if (!buffer) {
        return;
    }
    [self appendVarInt:buffer.length];
    [self.mutableData appendData:buffer.data];
}

- (void)appendBytes:(const void *)bytes length:(NSUInteger)length
{
    if (!bytes || (length == 0)) {
        return;
    }
    [self.mutableData appendBytes:bytes length:length];
}

#pragma mark NSMutableData

- (void *)mutableBytes
{
    return self.mutableData.mutableBytes;
}

- (void)setLength:(NSUInteger)length
{
    self.mutableData.length = length;
}

- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes length:(NSUInteger)length
{
    [self.mutableData replaceBytesInRange:range withBytes:bytes length:length];
}

@end

#pragma mark -

const uint8_t           WSBufferVarInt16Byte                 = 0xfd;
const uint8_t           WSBufferVarInt32Byte                 = 0xfe;
const uint8_t           WSBufferVarInt64Byte                 = 0xff;

NSUInteger WSBufferVarIntSize(uint64_t i)
{
    if (i < WSBufferVarInt16Byte) {
        return sizeof(uint8_t);
    }
    else if (i <= UINT16_MAX) {
        return sizeof(uint8_t) + sizeof(uint16_t);
    }
    else if (i <= UINT32_MAX) {
        return sizeof(uint8_t) + sizeof(uint32_t);
    }
    else {
        return sizeof(uint8_t) + sizeof(uint64_t);
    }
}
