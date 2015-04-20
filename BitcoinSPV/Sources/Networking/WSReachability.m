//
//  WSReachability.m
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

#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <arpa/inet.h>

#import "WSReachability.h"

static void WSReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);

@interface WSReachability ()

@property (nonatomic, unsafe_unretained) SCNetworkReachabilityRef reachabilityRef;

+ (instancetype)reachabilityWithAddress:(const struct sockaddr_in *)address;
- (instancetype)initWithAddress:(const struct sockaddr_in *)address;
- (WSReachabilityStatus)reachabilityStatusForFlags:(SCNetworkReachabilityFlags)flags;
- (void)notifyReachabilityChange;

@end

@implementation WSReachability

+ (instancetype)reachabilityForInternetConnection
{
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
    
	return [self reachabilityWithAddress:&zeroAddress];
}

+ (instancetype)reachabilityWithAddress:(const struct sockaddr_in *)address
{
    return [[WSReachability alloc] initWithAddress:address];
}

- (instancetype)initWithAddress:(const struct sockaddr_in *)address
{
    if ((self = [super init])) {
        self.reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)address);
        if (!self.reachabilityRef) {
            return nil;
        }
        self.delegateQueue = dispatch_get_main_queue();
    }
    return self;
}

- (void)dealloc
{
	[self stopNotifier];
    CFRelease(self.reachabilityRef);
}

- (BOOL)startNotifier
{
	SCNetworkReachabilityContext context = { 0, (__bridge void *)self, NULL, NULL, NULL };
	if (!SCNetworkReachabilitySetCallback(self.reachabilityRef, WSReachabilityCallback, &context)) {
        return NO;
    }
    return SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, self.delegateQueue);
}

- (void)stopNotifier
{
    SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, NULL);
}

- (WSReachabilityStatus)reachabilityStatus
{
	WSReachabilityStatus status = WSReachabilityStatusUnreachable;
	SCNetworkReachabilityFlags flags;
	if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags)) {
        status = [self reachabilityStatusForFlags:flags];
	}
	return status;
}

- (WSReachabilityStatus)reachabilityStatusForFlags:(SCNetworkReachabilityFlags)flags
{
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
		return WSReachabilityStatusUnreachable;
	}
    
    WSReachabilityStatus status = WSReachabilityStatusUnreachable;
	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {

        // If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
		status = WSReachabilityStatusReachableViaWiFi;
	}
	if (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
        ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {

        // ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {

            // ... and no [user] intervention is needed...
            status = WSReachabilityStatusReachableViaWiFi;
        }
    }
	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {

        // ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
		status = WSReachabilityStatusReachableViaWWAN;
	}
    
	return status;
}

- (NSString *)reachabilityFlagsString
{
	SCNetworkReachabilityFlags flags;
	if (!SCNetworkReachabilityGetFlags(_reachabilityRef, &flags)) {
        return nil;
	}

    NSString *string = [NSString stringWithFormat:@"%c%c %c%c%c%c%c%c%c",
                   
                        (flags & kSCNetworkReachabilityFlagsIsWWAN)                 ? 'W' : '-',
                        (flags & kSCNetworkReachabilityFlagsReachable)              ? 'R' : '-',
                       
                        (flags & kSCNetworkReachabilityFlagsTransientConnection)    ? 't' : '-',
                        (flags & kSCNetworkReachabilityFlagsConnectionRequired)     ? 'c' : '-',
                        (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)    ? 'C' : '-',
                        (flags & kSCNetworkReachabilityFlagsInterventionRequired)   ? 'i' : '-',
                        (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)     ? 'D' : '-',
                        (flags & kSCNetworkReachabilityFlagsIsLocalAddress)         ? 'l' : '-',
                        (flags & kSCNetworkReachabilityFlagsIsDirect)               ? 'd' : '-'];

    return string;
}

- (BOOL)isReachable
{
    return (self.reachabilityStatus != WSReachabilityStatusUnreachable);
}

- (void)notifyReachabilityChange
{
    [self.delegate reachability:self didChangeStatus:self.reachabilityStatus];
}

@end

static void WSReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	NSCAssert(info, @"NULL info in WSReachabilityCallback");
	NSCAssert([(__bridge NSObject *)info isKindOfClass:[WSReachability class]], @"Unexpected info class in WSReachabilityCallback");
    
    WSReachability *reachability = (__bridge WSReachability *)info;
    [reachability notifyReachabilityChange];
}
