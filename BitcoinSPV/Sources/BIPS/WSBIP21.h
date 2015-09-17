//
//  WSBIP21.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 08/12/14.
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
@class WSAddress;
@class WSBIP21URLBuilder;

extern NSString *const WSBIP21URLScheme;

@interface WSBIP21URL : NSObject

+ (instancetype)URLWithParameters:(WSParameters *)parameters string:(NSString *)string;
- (instancetype)initWithBuilder:(WSBIP21URLBuilder *)builder;
- (WSAddress *)address;
- (NSString *)label;
- (NSString *)message;
- (uint64_t)amount;
- (NSDictionary *)others;
- (NSString *)string;

@end

@interface WSBIP21URLBuilder : NSObject

+ (instancetype)builder;
- (instancetype)address:(WSAddress *)address;
- (instancetype)label:(NSString *)label;
- (instancetype)message:(NSString *)message;
- (instancetype)amount:(uint64_t)amount;
- (instancetype)others:(NSDictionary *)others;
- (WSBIP21URL *)build;

@end
