//
//  WSPeerGroupNotifier.h
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

#import <Foundation/Foundation.h>

@class WSPeerGroup;
@class WSPeer;
@class WSStorableBlock;
@protocol WSTransaction;
@class WSSignedTransaction;
@class WSMessageReject;

extern NSString *const WSPeerGroupDidConnectNotification;
extern NSString *const WSPeerGroupDidDisconnectNotification;
extern NSString *const WSPeerGroupPeerDidConnectNotification;
extern NSString *const WSPeerGroupPeerDidDisconnectNotification;
extern NSString *const WSPeerGroupPeerHostKey;
extern NSString *const WSPeerGroupReachedMaxConnectionsKey;

extern NSString *const WSPeerGroupDidStartDownloadNotification;
extern NSString *const WSPeerGroupDidFinishDownloadNotification;
extern NSString *const WSPeerGroupDidFailDownloadNotification;
extern NSString *const WSPeerGroupDidDownloadBlockNotification;
extern NSString *const WSPeerGroupWillRescanNotification;
extern NSString *const WSPeerGroupDownloadFromHeightKey;
extern NSString *const WSPeerGroupDownloadToHeightKey;
extern NSString *const WSPeerGroupDownloadBlockKey;

extern NSString *const WSPeerGroupDidRelayTransactionNotification;
extern NSString *const WSPeerGroupRelayTransactionKey;
extern NSString *const WSPeerGroupRelayIsPublishedKey;

extern NSString *const WSPeerGroupDidReorganizeNotification;
extern NSString *const WSPeerGroupReorganizeOldBlocksKey;
extern NSString *const WSPeerGroupReorganizeNewBlocksKey;

extern NSString *const WSPeerGroupDidRejectNotification;
extern NSString *const WSPeerGroupRejectCodeKey;
extern NSString *const WSPeerGroupRejectReasonKey;
extern NSString *const WSPeerGroupRejectTransactionIdKey;
extern NSString *const WSPeerGroupRejectBlockIdKey;
extern NSString *const WSPeerGroupRejectWasPendingKey;

extern NSString *const WSPeerGroupErrorKey;

#pragma mark -

//
// thread-safe: no
//
@interface WSPeerGroupNotifier : NSObject

- (instancetype)initWithPeerGroup:(WSPeerGroup *)peerGroup;

- (void)notifyConnected;
- (void)notifyDisconnected;
- (void)notifyPeerConnected:(WSPeer *)peer reachedMaxConnections:(BOOL)reachedMaxConnections;
- (void)notifyPeerDisconnected:(WSPeer *)peer;
- (void)notifyDownloadStartedFromHeight:(uint32_t)fromHeight toHeight:(uint32_t)toHeight;
- (void)notifyDownloadFinished;
- (void)notifyDownloadFailedWithError:(NSError *)error;
- (void)notifyBlock:(WSStorableBlock *)block;
- (void)notifyTransaction:(WSSignedTransaction *)transaction isPublished:(BOOL)isPublished fromPeer:(WSPeer *)peer;
- (void)notifyReorganizationWithOldBlocks:(NSArray *)oldBlocks newBlocks:(NSArray *)newBlocks;
- (void)notifyRejectMessage:(WSMessageReject *)message wasPending:(BOOL)wasPending fromPeer:(WSPeer *)peer;
- (void)notifyRescan;

- (BOOL)didNotifyDownloadStarted;
- (double)downloadProgressAtHeight:(uint32_t)height;

@end
