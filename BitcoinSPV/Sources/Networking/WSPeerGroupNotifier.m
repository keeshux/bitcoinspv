//
//  WSPeerGroupNotifier.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 24/07/14.
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

#import <UIKit/UIKit.h>

#import "WSPeerGroupNotifier.h"
#import "WSPeerGroup.h"
#import "WSPeer.h"
#import "WSStorableBlock.h"
#import "WSTransaction.h"
#import "WSMessageReject.h"
#import "WSConfig.h"
#import "WSLogging.h"
#import "WSMacrosCore.h"
#import "WSErrors.h"

NSString *const WSPeerGroupDidConnectNotification               = @"WSPeerGroupDidConnectNotification";
NSString *const WSPeerGroupDidDisconnectNotification            = @"WSPeerGroupDidDisconnectNotification";
NSString *const WSPeerGroupPeerDidConnectNotification           = @"WSPeerGroupPeerDidConnectNotification";
NSString *const WSPeerGroupPeerDidDisconnectNotification        = @"WSPeerGroupPeerDidDisconnectNotification";
NSString *const WSPeerGroupPeerHostKey                          = @"PeerHost";
NSString *const WSPeerGroupReachedMaxConnectionsKey             = @"ReachedMaxConnections";

NSString *const WSPeerGroupDidStartDownloadNotification         = @"WSPeerGroupDidStartDownloadNotification";
NSString *const WSPeerGroupDidFinishDownloadNotification        = @"WSPeerGroupDidFinishDownloadNotification";
NSString *const WSPeerGroupDidFailDownloadNotification          = @"WSPeerGroupDidFailDownloadNotification";
NSString *const WSPeerGroupDidDownloadBlockNotification         = @"WSPeerGroupDidDownloadBlockNotification";
NSString *const WSPeerGroupWillRescanNotification               = @"WSPeerGroupWillRescanNotification";
NSString *const WSPeerGroupDownloadFromHeightKey                = @"FromHeight";
NSString *const WSPeerGroupDownloadToHeightKey                  = @"ToHeight";
NSString *const WSPeerGroupDownloadBlockKey                     = @"Block";

NSString *const WSPeerGroupDidRelayTransactionNotification      = @"WSPeerGroupDidRelayTransactionNotification";
NSString *const WSPeerGroupRelayTransactionKey                  = @"Transaction";
NSString *const WSPeerGroupRelayIsPublishedKey                  = @"IsPublished";

NSString *const WSPeerGroupDidReorganizeNotification            = @"WSPeerGroupDidReorganizeNotification";
NSString *const WSPeerGroupReorganizeOldBlocksKey               = @"OldBlocks";
NSString *const WSPeerGroupReorganizeNewBlocksKey               = @"NewBlocks";

NSString *const WSPeerGroupDidRejectNotification                = @"WSPeerGroupDidRejectNotification";
NSString *const WSPeerGroupRejectCodeKey                        = @"Code";
NSString *const WSPeerGroupRejectReasonKey                      = @"Reason";
NSString *const WSPeerGroupRejectTransactionIdKey               = @"TransactionId";
NSString *const WSPeerGroupRejectBlockIdKey                     = @"BlockId";
NSString *const WSPeerGroupRejectWasPendingKey                  = @"WasPending";

NSString *const WSPeerGroupErrorKey                             = @"Error";

#pragma mark -

@interface WSPeerGroupNotifier ()

@property (nonatomic, weak) WSPeerGroup *peerGroup;
@property (nonatomic, assign) uint32_t syncFromHeight;
@property (nonatomic, assign) uint32_t syncToHeight;
@property (nonatomic, assign) UIBackgroundTaskIdentifier syncTaskId;

- (void)notifyWithName:(NSString *)name userInfo:(NSDictionary *)userInfo;

@end

@implementation WSPeerGroupNotifier

- (instancetype)initWithPeerGroup:(WSPeerGroup *)peerGroup
{
    WSExceptionCheckIllegal(peerGroup);
    
    if ((self = [super init])) {
        self.peerGroup = peerGroup;
        self.syncFromHeight = WSBlockUnknownHeight;
        self.syncToHeight = WSBlockUnknownHeight;
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

- (void)notifyPeerConnected:(WSPeer *)peer reachedMaxConnections:(BOOL)reachedMaxConnections
{
    WSExceptionCheckIllegal(peer);
    
    [self notifyWithName:WSPeerGroupPeerDidConnectNotification userInfo:@{WSPeerGroupPeerHostKey: peer.remoteHost,
                                                                          WSPeerGroupReachedMaxConnectionsKey: @(reachedMaxConnections)}];
}

- (void)notifyPeerDisconnected:(WSPeer *)peer
{
    WSExceptionCheckIllegal(peer);

    [self notifyWithName:WSPeerGroupPeerDidDisconnectNotification userInfo:@{WSPeerGroupPeerHostKey: peer.remoteHost}];
}

- (void)notifyDownloadStartedFromHeight:(uint32_t)fromHeight toHeight:(uint32_t)toHeight
{
    WSExceptionCheckIllegal(toHeight > 0);

    DDLogInfo(@"Download started, status = %u/%u", fromHeight, toHeight);

    self.syncFromHeight = fromHeight;
    self.syncToHeight = toHeight;

    if (self.syncTaskId == UIBackgroundTaskInvalid) {
        self.syncTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
    }
    
    [self notifyWithName:WSPeerGroupDidStartDownloadNotification userInfo:@{WSPeerGroupDownloadFromHeightKey: @(fromHeight),
                                                                            WSPeerGroupDownloadToHeightKey: @(toHeight)}];
}

- (void)notifyDownloadFinished
{
    const uint32_t fromHeight = self.syncFromHeight;
    const uint32_t toHeight = self.syncToHeight;

    self.syncFromHeight = WSBlockUnknownHeight;
    self.syncToHeight = WSBlockUnknownHeight;

    if (self.syncTaskId != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.syncTaskId];
        self.syncTaskId = UIBackgroundTaskInvalid;
    }

    DDLogInfo(@"Download finished, %u -> %u", fromHeight, toHeight);
    
    [self notifyWithName:WSPeerGroupDidFinishDownloadNotification userInfo:@{WSPeerGroupDownloadFromHeightKey: @(fromHeight),
                                                                             WSPeerGroupDownloadToHeightKey: @(toHeight)}];
}

- (void)notifyDownloadFailedWithError:(NSError *)error
{
    DDLogError(@"Download failed%@", WSStringOptional(error, @" (%@)"));
    
    self.syncFromHeight = WSBlockUnknownHeight;
    self.syncToHeight = WSBlockUnknownHeight;

    if (self.syncTaskId != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.syncTaskId];
        self.syncTaskId = UIBackgroundTaskInvalid;
    }
    
    [self notifyWithName:WSPeerGroupDidFailDownloadNotification userInfo:(error ? @{WSPeerGroupErrorKey: error} : nil)];
}

- (void)notifyBlock:(WSStorableBlock *)block
{
    WSExceptionCheckIllegal(block);

    const uint32_t fromHeight = self.syncFromHeight;
    const uint32_t toHeight = self.syncToHeight;
    const uint32_t currentHeight = block.height;

    if (currentHeight <= toHeight) {
        if (currentHeight % 1000 == 0) {
            const double progress = WSUtilsProgress(fromHeight, toHeight, currentHeight);

            DDLogInfo(@"Download progress = %u/%u (%.2f%%)", currentHeight, toHeight, 100.0 * progress);
        }
    }

    [self notifyWithName:WSPeerGroupDidDownloadBlockNotification userInfo:@{WSPeerGroupDownloadBlockKey: block}];
}

- (void)notifyTransaction:(WSSignedTransaction *)transaction isPublished:(BOOL)isPublished fromPeer:(WSPeer *)peer
{
    WSExceptionCheckIllegal(transaction);
    WSExceptionCheckIllegal(peer);

    [self notifyWithName:WSPeerGroupDidRelayTransactionNotification userInfo:@{WSPeerGroupRelayTransactionKey: transaction,
                                                                               WSPeerGroupRelayIsPublishedKey: @(isPublished),
                                                                               WSPeerGroupPeerHostKey: peer.remoteHost}];
}

- (void)notifyReorganizationWithOldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks
{
    WSExceptionCheckIllegal(oldBlocks);
    WSExceptionCheckIllegal(newBlocks);

    [self notifyWithName:WSPeerGroupDidReorganizeNotification userInfo:@{WSPeerGroupReorganizeOldBlocksKey: oldBlocks,
                                                                         WSPeerGroupReorganizeNewBlocksKey: newBlocks}];
}

- (void)notifyRejectMessage:(WSMessageReject *)message wasPending:(BOOL)wasPending fromPeer:(WSPeer *)peer
{
    WSExceptionCheckIllegal(message);
    WSExceptionCheckIllegal(peer);

    if ([message.message isEqualToString:WSMessageRejectMessageTx]) {
        WSHash256 *txId = WSHash256FromData(message.payload);

        [self notifyWithName:WSPeerGroupDidRejectNotification userInfo:@{WSPeerGroupRejectCodeKey: @(message.code),
                                                                         WSPeerGroupRejectReasonKey: message.reason,
                                                                         WSPeerGroupRejectTransactionIdKey: txId,
                                                                         WSPeerGroupRejectWasPendingKey: @(wasPending),
                                                                         WSPeerGroupPeerHostKey: peer.remoteHost}];
    }
    else if ([message.message isEqualToString:WSMessageRejectMessageBlock]) {
        WSHash256 *blockId = WSHash256FromData(message.payload);

        [self notifyWithName:WSPeerGroupDidRejectNotification userInfo:@{WSPeerGroupRejectCodeKey: @(message.code),
                                                                         WSPeerGroupRejectReasonKey: message.reason,
                                                                         WSPeerGroupRejectBlockIdKey: blockId,
                                                                         WSPeerGroupRejectWasPendingKey: @(wasPending),
                                                                         WSPeerGroupPeerHostKey: peer.remoteHost}];
    }
}

- (void)notifyRescan
{
    [self notifyWithName:WSPeerGroupWillRescanNotification userInfo:nil];
}

- (BOOL)didNotifyDownloadStarted
{
    return (self.syncFromHeight != WSBlockUnknownHeight);
}

- (double)downloadProgressAtHeight:(uint32_t)height
{
    WSExceptionCheckIllegal(height > 0);

    if (![self didNotifyDownloadStarted]) {
        return 0.0;
    }
    return WSUtilsProgress(self.syncFromHeight, self.syncToHeight, height);
}

#pragma mark Helpers

- (void)notifyWithName:(NSString *)name userInfo:(NSDictionary *)userInfo
{
    NSParameterAssert(name);

    WSPeerGroup *peerGroup = self.peerGroup;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:peerGroup userInfo:userInfo];
    });
}

@end
