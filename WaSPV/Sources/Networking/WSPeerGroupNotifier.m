//
//  WSPeerGroupNotifier.m
//  WaSPV
//
//  Created by Davide De Rosa on 24/07/14.
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

#import "WSPeerGroupNotifier.h"
#import "WSPeerGroup.h"
#import "WSPeer.h"
#import "WSStorableBlock.h"
#import "WSTransaction.h"
#import "WSConfig.h"
#import "WSMacros.h"
#import "WSErrors.h"

NSString *const WSPeerGroupDidConnectNotification               = @"WSPeerGroupDidConnectNotification";
NSString *const WSPeerGroupDidDisconnectNotification            = @"WSPeerGroupDidDisconnectNotification";

NSString *const WSPeerGroupDidStartDownloadNotification         = @"WSPeerGroupDidStartDownloadNotification";
NSString *const WSPeerGroupDidUpdateDownloadNotification        = @"WSPeerGroupDidUpdateDownloadNotification";
NSString *const WSPeerGroupDidFinishDownloadNotification        = @"WSPeerGroupDidFinishDownloadNotification";
NSString *const WSPeerGroupDidFailDownloadNotification          = @"WSPeerGroupDidFailDownloadNotification";
NSString *const WSPeerGroupDidDownloadBlockNotification         = @"WSPeerGroupDidDownloadBlockNotification";
NSString *const WSPeerGroupDownloadFromHeightKey                = @"FromHeight";
NSString *const WSPeerGroupDownloadToHeightKey                  = @"ToHeight";
NSString *const WSPeerGroupDownloadCurrentHeightKey             = @"CurrentHeight";
NSString *const WSPeerGroupDownloadProgressKey                  = @"Progress";
NSString *const WSPeerGroupDownloadBlockKey                     = @"Block";
NSString *const WSPeerGroupDownloadBlocksLeftKey                = @"BlocksLeft";

NSString *const WSPeerGroupDidRelayTransactionNotification      = @"WSPeerGroupDidRelayTransactionNotification";
NSString *const WSPeerGroupRelayTransactionKey                  = @"Transaction";
NSString *const WSPeerGroupRelayIsPublishedKey                  = @"IsPublished";

NSString *const WSPeerGroupErrorKey                             = @"Error";

#pragma mark -

@interface WSPeerGroupNotifier ()

@property (nonatomic, weak) WSPeerGroup *peerGroup;
@property (nonatomic, assign) NSUInteger syncFromHeight;
@property (nonatomic, assign) NSUInteger syncToHeight;
@property (nonatomic, assign) UIBackgroundTaskIdentifier syncTaskId;

- (void)notifyWithName:(NSString *)name userInfo:(NSDictionary *)userInfo;

@end

@implementation WSPeerGroupNotifier

- (instancetype)initWithPeerGroup:(WSPeerGroup *)peerGroup
{
    WSExceptionCheckIllegal(peerGroup != nil, @"Nil peerGroup");
    
    if ((self = [super init])) {
        self.peerGroup = peerGroup;
        self.syncFromHeight = NSNotFound;
        self.syncToHeight = NSNotFound;
        self.syncTaskId = UIBackgroundTaskInvalid;
    }
    return self;
}

- (void)notifyConnected
{
    [self notifyWithName:WSPeerGroupDidConnectNotification userInfo:nil];
}

- (void)notifyDisconnected
{
    [self notifyWithName:WSPeerGroupDidDisconnectNotification userInfo:nil];
}

- (void)notifyPeerConnected:(WSPeer *)peer
{
}

- (void)notifyPeerDisconnected:(WSPeer *)peer
{
}

- (void)notifyDownloadStartedFromHeight:(NSUInteger)fromHeight toHeight:(NSUInteger)toHeight
{
    DDLogInfo(@"Started download, status = %u/%u", fromHeight, toHeight);

    @synchronized (self) {
        self.syncFromHeight = fromHeight;
        self.syncToHeight = toHeight;

        if (self.syncTaskId == UIBackgroundTaskInvalid) {
            self.syncTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
        }
    }
    
    [self notifyWithName:WSPeerGroupDidStartDownloadNotification userInfo:@{WSPeerGroupDownloadFromHeightKey: @(fromHeight),
                                                                            WSPeerGroupDownloadToHeightKey: @(toHeight)}];
}

- (void)notifyDownloadFinished
{
    NSUInteger fromHeight = 0;
    NSUInteger toHeight = 0;
    @synchronized (self) {
        fromHeight = self.syncFromHeight;
        toHeight = self.syncToHeight;

        self.syncFromHeight = NSNotFound;
        self.syncToHeight = NSNotFound;
    
        if (self.syncTaskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.syncTaskId];
            self.syncTaskId = UIBackgroundTaskInvalid;
        }
    }

    DDLogInfo(@"Finished download, %u -> %u", fromHeight, toHeight);
    
    [self notifyWithName:WSPeerGroupDidFinishDownloadNotification userInfo:@{WSPeerGroupDownloadFromHeightKey: @(fromHeight),
                                                                             WSPeerGroupDownloadToHeightKey: @(toHeight)}];
}

- (void)notifyDownloadFailedWithError:(NSError *)error
{
    DDLogError(@"Download failed%@", WSStringOptional(error, @" (%@)"));
    
    @synchronized (self) {
        self.syncFromHeight = NSNotFound;
        self.syncToHeight = NSNotFound;

        if (self.syncTaskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.syncTaskId];
            self.syncTaskId = UIBackgroundTaskInvalid;
        }
    }
    
    [self notifyWithName:WSPeerGroupDidFailDownloadNotification userInfo:(error ? @{WSPeerGroupErrorKey: error} : nil)];
}

- (void)notifyBlockAdded:(WSStorableBlock *)block
{
    NSUInteger fromHeight = 0;
    NSUInteger toHeight = 0;
    @synchronized (self) {
        fromHeight = self.syncFromHeight;
        toHeight = self.syncToHeight;
    }

    const NSUInteger currentHeight = block.height;
    const NSUInteger blocksLeft = toHeight - block.height;
    const double progress = WSUtilsProgress(fromHeight, toHeight, currentHeight);

    [self notifyWithName:WSPeerGroupDidDownloadBlockNotification userInfo:@{WSPeerGroupDownloadBlockKey: block,
                                                                            WSPeerGroupDownloadBlocksLeftKey: @(blocksLeft)}];

    if (currentHeight % 1000 == 0) {
        DDLogInfo(@"Download progress = %u/%u (%.2f%%)", currentHeight, toHeight, 100.0 * progress);
    }
    
    [self notifyWithName:WSPeerGroupDidUpdateDownloadNotification userInfo:@{WSPeerGroupDownloadFromHeightKey: @(fromHeight),
                                                                             WSPeerGroupDownloadToHeightKey: @(toHeight),
                                                                             WSPeerGroupDownloadCurrentHeightKey: @(currentHeight),
                                                                             WSPeerGroupDownloadProgressKey: @(progress)}];
}

- (void)notifyTransaction:(WSSignedTransaction *)transaction fromPeer:(WSPeer *)peer isPublished:(BOOL)isPublished
{
    [self notifyWithName:WSPeerGroupDidRelayTransactionNotification userInfo:@{WSPeerGroupRelayTransactionKey: transaction,
                                                                               WSPeerGroupRelayIsPublishedKey: @(isPublished)}];
}

- (BOOL)didNotifyDownloadStarted
{
    @synchronized (self) {
        return (self.syncFromHeight != NSNotFound);
    }
}

- (void)notifyWithName:(NSString *)name userInfo:(NSDictionary *)userInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:self.peerGroup userInfo:userInfo];
    });
}

@end
