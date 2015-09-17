//
//  WSFilteredBlock.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 02/07/14.
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

#import "WSFilteredBlock.h"
#import "WSHash256.h"
#import "WSBlockHeader.h"
#import "WSPartialMerkleTree.h"
#import "WSBitcoinConstants.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSFilteredBlock ()

@property (nonatomic, strong) WSBlockHeader *header;
@property (nonatomic, strong) WSPartialMerkleTree *partialMerkleTree;

@end

@implementation WSFilteredBlock

- (instancetype)initWithHeader:(WSBlockHeader *)header partialMerkleTree:(WSPartialMerkleTree *)partialMerkleTree
{
    WSExceptionCheckIllegal(header);
    WSExceptionCheckIllegal(partialMerkleTree);

    if ((self = [super init])) {
        self.header = header;
        self.partialMerkleTree = partialMerkleTree;
    }
    return self;
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

- (WSParameters *)parameters
{
    return self.header.parameters;
}

#pragma mark WSFilteredBlock

- (BOOL)verifyWithError:(NSError *__autoreleasing *)error
{
    return ([self.header.merkleRoot isEqual:self.partialMerkleTree.merkleRoot] &&
            [self.header verifyWithError:error]);
}

- (BOOL)containsTransactionWithId:(WSHash256 *)txId
{
    return [self.partialMerkleTree matchesTransactionWithId:txId];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendUint32:self.header.version];
    [buffer appendHash256:self.header.previousBlockId];
    [buffer appendHash256:self.header.merkleRoot];
    [buffer appendUint32:self.header.timestamp];
    [buffer appendUint32:self.header.bits];
    [buffer appendUint32:self.header.nonce];
    [self.partialMerkleTree appendToMutableBuffer:buffer];
}

- (WSBuffer *)toBuffer
{
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] init];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSBufferDecoder

- (instancetype)initWithParameters:(WSParameters *)parameters buffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    if (available < WSFilteredBlockBaseSize) {
        WSErrorSetNotEnoughBytes(error, [self class], available, WSFilteredBlockBaseSize);
        return nil;
    }
    NSUInteger offset = from;

    WSBlockHeader *header = [[WSBlockHeader alloc] initWithParameters:parameters buffer:buffer from:offset available:available error:error];
    if (!header) {
        return nil;
    }

    // txCount is always 0 in headers (var_int of 1 byte), go back
    // searching for it because in filtered blocks txCount is != 0 instead
    offset += WSBlockHeaderSize - sizeof(uint8_t);

    WSPartialMerkleTree *partialMerkleTree = [[WSPartialMerkleTree alloc] initWithParameters:parameters buffer:buffer from:offset available:(available - offset + from) error:error];
    if (!partialMerkleTree) {
        return nil;
    }
    
    return [self initWithHeader:header partialMerkleTree:partialMerkleTree];
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    NSMutableArray *tokens = [[NSMutableArray alloc] init];
    [tokens addObject:[NSString stringWithFormat:@"header = %@", [self.header descriptionWithIndent:(indent + 1)]]];
    [tokens addObject:[NSString stringWithFormat:@"partialMerkleTree = %@", [self.partialMerkleTree descriptionWithIndent:(indent + 1)]]];
    return [NSString stringWithFormat:@"{%@}", WSStringDescriptionFromTokens(tokens, indent)];
}
 
@end
