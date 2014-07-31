//
//  WSTransactionMetadata.m
//  WaSPV
//
//  Created by Davide De Rosa on 27/07/14.
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

#import "WSTransactionMetadata.h"
#import "WSStorableBlock.h"

@interface WSTransactionMetadata ()

@property (nonatomic, strong) WSHash256 *parentBlockId;
@property (nonatomic, assign) NSUInteger confirmations;
@property (nonatomic, assign) NSUInteger height;

@end

@implementation WSTransactionMetadata

- (instancetype)initWithParentBlock:(WSStorableBlock *)block networkHeight:(NSUInteger)networkHeight
{
    WSExceptionCheckIllegal(block != nil, @"Nil block");
    
    if ((self = [super init])) {
        self.parentBlockId = block.blockId;
        self.height = block.height;
        self.confirmations = networkHeight - block.height + 1;
    }
    return self;
}

- (instancetype)initWithNoParentBlock
{
    if ((self = [super init])) {
        self.parentBlockId = nil;
        self.height = WSBlockUnknownHeight;
        self.confirmations = 0;
    }
    return self;
}

- (NSString *)description
{
    if (!self.parentBlockId) {
        return @"<unconfirmed>";
    }
    return [NSString stringWithFormat:@"<+%u, #%u, %@>",
            self.confirmations, self.height, self.parentBlockId];
}

@end
