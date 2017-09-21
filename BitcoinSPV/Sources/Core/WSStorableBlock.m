//
//  WSStorableBlock.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 11/07/14.
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

#import <openssl/bn.h>
#import "AutoCoding.h"

#import "WSStorableBlock.h"
#import "WSHash256.h"
#import "WSBlockHeader.h"
#import "WSFilteredBlock.h"
#import "WSPartialMerkleTree.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSMacrosPrivate.h"
#import "WSErrors.h"

@interface WSStorableBlock ()

@property (nonatomic, strong) WSBlockHeader *header;
@property (nonatomic, assign) uint32_t height;
@property (nonatomic, unsafe_unretained) BIGNUM *work;
@property (nonatomic, strong) NSOrderedSet *transactions; // WSSignedTransaction

- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions previousBlock:(WSStorableBlock *)previousBlock;

@end

@implementation WSStorableBlock

- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions
{
    return [self initWithHeader:header transactions:transactions height:WSBlockUnknownHeight work:[header workData]];
}

- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions height:(uint32_t)height
{
    return [self initWithHeader:header transactions:transactions height:height work:[header workData]];
}

- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions height:(uint32_t)height work:(NSData *)work
{
    WSExceptionCheckIllegal(header);
    
    if ((self = [super init])) {
        self.header = header;
        self.transactions = transactions;
        self.height = height;
        self.work = BN_new();
        
        WSBlockWorkFromData(self.work, work);
    }
    return self;
}

- (instancetype)initWithHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions previousBlock:(WSStorableBlock *)previousBlock
{
    WSExceptionCheckIllegal(header);
    
    if ((self = [super init])) {
        self.header = header;
        self.transactions = transactions;
        self.height = WSBlockUnknownHeight;
        self.work = BN_new();
        NSAssert(self.work, @"Unable to allocate work BIGNUM");
        
        // start from own work
        NSData *workData = [header workData];
        BN_bin2bn(workData.bytes, (int)workData.length, self.work);
        
        // accumulate previous block work (if any)
        if (previousBlock) {
            if (previousBlock.height == WSBlockUnknownHeight) {
                self.height = WSBlockUnknownHeight;
            }
            else {
                self.height = previousBlock.height + 1;
            }
            BN_add(self.work, self.work, previousBlock.work);
        }
    }
    return self;
}

- (void)dealloc
{
    BN_free(self.work);
    self.work = NULL;
}

- (NSData *)workData
{
    return WSBlockDataFromWork(self.work);
}

- (NSString *)workString
{
    return [NSString stringWithUTF8String:BN_bn2dec(self.work)];
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    WSStorableBlock *block = object;
    return [block.blockId isEqual:self.blockId];
}

- (NSUInteger)hash
{
    return [self.blockId hash];
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

#pragma mark Intrinsic

- (WSParameters *)parameters
{
    return self.header.parameters;
}

- (WSHash256 *)blockId
{
    return self.header.blockId;
}

- (WSHash256 *)previousBlockId
{
    return self.header.previousBlockId;
}

- (BOOL)isTransitionBlock
{
    return ((self.height > 0) && (self.height % [self.parameters retargetInterval] == 0));
}

- (BOOL)hasMoreWorkThanBlock:(WSStorableBlock *)block
{
    return (BN_cmp(self.work, block.work) > 0);
}

- (WSStorableBlock *)buildNextBlockFromHeader:(WSBlockHeader *)header transactions:(NSOrderedSet *)transactions
{
    return [[WSStorableBlock alloc] initWithHeader:header transactions:transactions previousBlock:self];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [self.header appendToMutableBuffer:buffer];
    [buffer appendUint32:self.height];
    [buffer appendVarData:self.workData];
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:[self estimatedSize]];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if (available < WSBlockHeaderSize) {
        WSErrorSetNotEnoughBytes(error, [self class], available, WSBlockHeaderSize);
        return nil;
    }
    NSUInteger offset = from;
    
    WSBlockHeader *header = [[WSBlockHeader alloc] initWithParameters:parameters buffer:buffer from:offset available:available error:error];
    if (!header) {
        return nil;
    }
    
    offset += WSBlockHeaderSize;

    const uint32_t height = [buffer uint32AtOffset:offset];
    offset += sizeof(uint32_t);
    NSData *workData = [buffer varDataAtOffset:offset length:NULL];
    
    return [self initWithHeader:header transactions:nil height:height work:workData];
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    const NSUInteger workLength = BN_num_bytes(self.work);
    const NSUInteger workLengthLength = WSBufferVarIntSize(workLength);
    
    return WSBlockHeaderSize + sizeof(uint32_t) + workLengthLength + workLength;
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    [tokens addObject:[NSString stringWithFormat:@"header = %@", [self.header descriptionWithIndent:(indent + 1)]]];
    [tokens addObject:[NSString stringWithFormat:@"transactions = %lu", (unsigned long)self.transactions.count]];
    [tokens addObject:[NSString stringWithFormat:@"height = %u", self.height]];
    [tokens addObject:[NSString stringWithFormat:@"work = %@", self.workString]];
    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}

#pragma mark AutoCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        self.work = BN_new();
        WSBlockWorkFromData(self.work, [aDecoder decodeDataObject]);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
 
    [aCoder encodeDataObject:WSBlockDataFromWork(self.work)];
}

+ (NSDictionary *)codableProperties
{
    return @{@"header": [NSObject class],
             @"height": [NSNumber class]};
}

@end
