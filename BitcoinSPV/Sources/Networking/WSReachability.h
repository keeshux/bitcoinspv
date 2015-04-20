//
//  WSReachability.h
//  BitcoinSPV
//
//  Created by Davide De Rosa on 09/07/14.
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

// adapted from: https://developer.apple.com/library/ios/samplecode/Reachability/Introduction/Intro.html

typedef enum {
	WSReachabilityStatusUnreachable = 0,
	WSReachabilityStatusReachableViaWiFi,
	WSReachabilityStatusReachableViaWWAN
} WSReachabilityStatus;

#pragma mark -

@protocol WSReachabilityDelegate;

@interface WSReachability : NSObject

@property (nonatomic, weak) id<WSReachabilityDelegate> delegate;
@property (nonatomic, weak) dispatch_queue_t delegateQueue;

+ (instancetype)reachabilityForInternetConnection;
- (BOOL)startNotifier;
- (void)stopNotifier;
- (WSReachabilityStatus)reachabilityStatus;
- (NSString *)reachabilityFlagsString;
- (BOOL)isReachable;

@end

#pragma mark -

@protocol WSReachabilityDelegate <NSObject>

- (void)reachability:(WSReachability *)reachability didChangeStatus:(WSReachabilityStatus)reachabilityStatus;

@end
