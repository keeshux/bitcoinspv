//
//  WSMessageFactory.h
//  WaSPV
//
//  Created by Davide De Rosa on 06/07/14.
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

#import <Foundation/Foundation.h>

#import "WSMessage.h"

@interface WSMessageFactory : NSObject

+ (instancetype)sharedInstance;
- (id<WSMessage>)messageFromType:(NSString *)type payload:(WSBuffer *)payload error:(NSError **)error;

@end

#import "WSMessageVersion.h"
#import "WSMessageVerack.h"
#import "WSMessageAddr.h"
#import "WSMessageInv.h"
#import "WSMessageGetdata.h"
#import "WSMessageNotfound.h"
#import "WSMessageGetblocks.h"
#import "WSMessageGetheaders.h"
#import "WSMessageTx.h"
#import "WSMessageHeaders.h"
#import "WSMessageGetaddr.h"
#import "WSMessageMempool.h"
#import "WSMessagePing.h"
#import "WSMessagePong.h"
#import "WSMessageReject.h"
#import "WSMessageFilterload.h"
//#import "WSMessageFilteradd.h"
//#import "WSMessageFilterclear.h"
#import "WSMessageMerkleblock.h"
//#import "WSMessageAlert.h"
