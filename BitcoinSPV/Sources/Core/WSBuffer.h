//
//  WSBuffer.h
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

#import <Foundation/Foundation.h>

@class WSParameters;
@class WSHash256;
@class WSHash160;
@class WSNetworkAddress;
@class WSInventory;

#pragma mark -

@interface WSBuffer : NSObject <NSCopying, NSMutableCopying>

- (instancetype)init;
- (instancetype)initWithData:(NSData *)data;
- (NSData *)data;

- (uint8_t)uint8AtOffset:(NSUInteger)offset;
- (uint16_t)uint16AtOffset:(NSUInteger)offset;
- (uint32_t)uint32AtOffset:(NSUInteger)offset;
- (uint64_t)uint64AtOffset:(NSUInteger)offset;
- (uint64_t)varIntAtOffset:(NSUInteger)offset length:(NSUInteger *)length;
- (NSString *)stringAtOffset:(NSUInteger)offset length:(NSUInteger *)length;
- (WSNetworkAddress *)networkAddressAtOffset:(NSUInteger)offset;
- (WSNetworkAddress *)legacyNetworkAddressAtOffset:(NSUInteger)offset;
- (WSInventory *)inventoryAtOffset:(NSUInteger)offset;
- (WSHash256 *)hash256AtOffset:(NSUInteger)offset;
- (NSData *)varDataAtOffset:(NSUInteger)offset length:(NSUInteger *)length;
- (NSData *)dataAtOffset:(NSUInteger)offset length:(NSUInteger)length;

- (WSBuffer *)subBufferWithRange:(NSRange)range;
- (WSHash256 *)computeHash256;
- (WSHash160 *)computeHash160;
- (NSString *)hexString;

- (const void *)bytes;
- (NSUInteger)length;

@end

#pragma mark -

@interface WSMutableBuffer : WSBuffer

- (instancetype)initWithCapacity:(NSUInteger)capacity;
- (NSMutableData *)mutableData;

- (void)appendUint8:(uint8_t)n;
- (void)appendUint16:(uint16_t)n;
- (void)appendUint32:(uint32_t)n;
- (void)appendUint64:(uint64_t)n;
- (void)appendVarInt:(uint64_t)n;
- (void)appendString:(NSString *)string;
- (void)appendNullPaddedString:(NSString *)string length:(NSUInteger)length;
- (void)appendNetworkAddress:(WSNetworkAddress *)networkAddress;
- (void)appendInventory:(WSInventory *)inventory;
- (void)appendHash256:(WSHash256 *)hash256;
- (void)appendData:(NSData *)data;
- (void)appendVarData:(NSData *)data;
- (void)appendBuffer:(WSBuffer *)buffer;
- (void)appendVarBuffer:(WSBuffer *)buffer;
- (void)appendBytes:(const void *)bytes length:(NSUInteger)length;

- (void *)mutableBytes;
- (void)setLength:(NSUInteger)length;
- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes length:(NSUInteger)length;

@end

#pragma mark -

@protocol WSBufferDecoder <NSObject>

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError **)error;

@end

#pragma mark -

@protocol WSBufferEncoder <NSObject>

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer;
- (WSBuffer *)toBuffer;

@end

#pragma mark -

extern const uint8_t            WSBufferVarInt16Byte;
extern const uint8_t            WSBufferVarInt32Byte;
extern const uint8_t            WSBufferVarInt64Byte;
extern NSUInteger               WSBufferVarIntSize(uint64_t i);
