//
//  WSTransactionOutput.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 26/07/14.
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

#import "WSTransactionOutput.h"
#import "WSScript.h"
#import "WSAddress.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

@interface WSTransactionOutput ()

@property (nonatomic, assign) uint64_t value;
@property (nonatomic, strong) WSScript *script;
@property (nonatomic, strong) WSAddress *address; // inferred

@end

@implementation WSTransactionOutput

- (instancetype)initWithParameters:(WSParameters *)parameters script:(WSScript *)script value:(uint64_t)value
{
    // 0 value is legit
    WSExceptionCheckIllegal(script);
//    WSExceptionCheckIllegal(value > 0);
    
    if ((self = [super init])) {
        self.value = value;
        self.script = script;
        self.address = [script standardOutputAddressWithParameters:parameters];
    }
    return self;
}

- (instancetype)initWithAddress:(WSAddress *)address value:(uint64_t)value
{
    // 0 value is legit
    WSExceptionCheckIllegal(address);
//    WSExceptionCheckIllegal(value > 0);
    
    if ((self = [super init])) {
        self.value = value;
        self.script = [WSScript scriptWithAddress:address];
        self.address = address;
    }
    return self;
}

- (WSParameters *)parameters
{
    return self.address.parameters;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"{%@value=%llu, script='%@'}",
            WSStringOptional(self.address, @"address='%@', "), self.value, self.script];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendUint64:self.value];
    [buffer appendVarInt:[self.script estimatedSize]];
    [self.script appendToMutableBuffer:buffer];
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
    NSUInteger offset = from;
    NSUInteger varIntLength;
    
    const uint64_t value = [buffer uint64AtOffset:offset];
    offset += sizeof(uint64_t);
    
    const NSUInteger scriptLength = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
    offset += varIntLength;
    
    WSScript *script = [[WSScript alloc] initWithParameters:parameters buffer:buffer from:offset available:scriptLength error:error];
    if (!script) {
        return nil;
    }
    
    return [self initWithParameters:parameters script:script value:value];
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    const NSUInteger scriptSize = [self.script estimatedSize];
    
    // value + var_int + script
    return 8 + WSBufferVarIntSize(scriptSize) + scriptSize;
}

@end
