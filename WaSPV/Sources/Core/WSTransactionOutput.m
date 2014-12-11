//
//  WSTransactionOutput.m
//  WaSPV
//
//  Created by Davide De Rosa on 26/07/14.
//  Copyright (c) 2014 Davide De Rosa. All rights reserved.
//
//  http://github.com/keeshux
//  http://twitter.com/keeshux
//  http://davidederosa.com
//
//  This file is part of WaSPV.
//
//  WaSPV is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  WaSPV is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with WaSPV.  If not, see <http://www.gnu.org/licenses/>.
//

#import "WSTransactionOutput.h"
#import "WSScript.h"
#import "WSMacros.h"
#import "WSErrors.h"

@interface WSTransactionOutput ()

@property (nonatomic, assign) uint64_t value;
@property (nonatomic, strong) WSScript *script;
@property (nonatomic, strong) WSAddress *address; // inferred

@end

@implementation WSTransactionOutput

- (instancetype)initWithValue:(uint64_t)value address:(WSAddress *)address
{
    // 0 value is legit
//    WSExceptionCheckIllegal(value > 0, @"Zero value");
    WSExceptionCheckIllegal(address != nil, @"Nil address");
    
    if ((self = [super init])) {
        self.value = value;
        self.script = [WSScript scriptWithAddress:address];
        self.address = address;
    }
    return self;
}

- (instancetype)initWithValue:(uint64_t)value script:(WSScript *)script
{
    // 0 value is legit
//    WSExceptionCheckIllegal(value > 0, @"Zero value");
    WSExceptionCheckIllegal(script != nil, @"Nil script");
    
    if ((self = [super init])) {
        self.value = value;
        self.script = [script copy];
        self.address = [script standardOutputAddress];
    }
    return self;
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

- (instancetype)initWithBuffer:(WSBuffer *)buffer from:(NSUInteger)from available:(NSUInteger)available error:(NSError *__autoreleasing *)error
{
    NSUInteger offset = from;
    NSUInteger varIntLength;
    
    const uint64_t value = [buffer uint64AtOffset:offset];
    offset += sizeof(uint64_t);
    
    const NSUInteger scriptLength = (NSUInteger)[buffer varIntAtOffset:offset length:&varIntLength];
    offset += varIntLength;
    
    WSScript *script = [[WSScript alloc] initWithBuffer:buffer from:offset available:scriptLength error:error];
    if (!script) {
        return nil;
    }
    
    return [self initWithValue:value script:script];
}

#pragma mark WSSized

- (NSUInteger)estimatedSize
{
    const NSUInteger scriptSize = [self.script estimatedSize];
    
    // value + var_int + script
    return 8 + WSBufferVarIntSize(scriptSize) + scriptSize;
}

@end
