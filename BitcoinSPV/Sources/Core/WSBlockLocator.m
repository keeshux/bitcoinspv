//
//  WSBlockLocator.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/07/14.
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

#import "WSBlockLocator.h"
#import "WSBitcoinConstants.h"
#import "WSErrors.h"

@interface WSBlockLocator ()

@property (nonatomic, strong) NSArray *hashes;

@end

@implementation WSBlockLocator

- (instancetype)initWithHashes:(NSArray *)hashes
{
    WSExceptionCheckIllegal(hashes);
    
    if ((self = [super init])) {
        self.hashes = hashes;
    }
    return self;
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

#pragma mark WSBufferEncoder

- (void)appendToMutableBuffer:(WSMutableBuffer *)buffer
{
    [buffer appendVarInt:self.hashes.count];
    for (WSHash256 *hash in self.hashes) {
        [buffer appendHash256:hash];
    }
}

- (WSBuffer *)toBuffer
{
    // var_int + hashes
    const NSUInteger capacity = 8 + self.hashes.count * WSHash256Length;
    
    WSMutableBuffer *buffer = [[WSMutableBuffer alloc] initWithCapacity:capacity];
    [self appendToMutableBuffer:buffer];
    return buffer;
}

#pragma mark WSIndentableDescription

- (NSString *)descriptionWithIndent:(NSUInteger)indent
{
    return [self.hashes descriptionWithLocale:nil indent:indent];
}

@end
