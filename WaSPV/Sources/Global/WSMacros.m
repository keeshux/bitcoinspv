//
//  WSMacros.m
//  WaSPV
//
//  Created by Davide De Rosa on 04/07/14.
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

#import <openssl/bn.h>
#import <arpa/inet.h>

#import "WSMacros.h"
#import "WSHash256.h"
#import "WSKey.h"
#import "WSPublicKey.h"
#import "WSAddress.h"
#import "WSScript.h"
#import "WSInventory.h"
#import "WSNetworkAddress.h"
#import "WSBlockHeader.h"
#import "WSSeed.h"
#import "WSPeer.h"
#import "WSCheckpoint.h"
#import "WSScript.h"
#import "WSTransaction.h"
#import "WSMessageFactory.h"
#import "WSPartialMerkleTree.h"
#import "WSFilteredBlock.h"
#import "NSString+Binary.h"
#import "NSString+Base58.h"
#import "NSData+Binary.h"
#import "NSData+Hash.h"

#pragma mark Utils

#warning XXX: optimize
NSString *WSStringDescriptionFromTokens(NSArray *tokens, NSUInteger indent)
{
    NSMutableString *endingSep = [@"\n" mutableCopy];
    for (NSUInteger i = 0; i < indent; ++i) {
        [endingSep appendString:@"\t"];
    }

    NSString *startingSep = [NSString stringWithFormat:@"%@\t", endingSep];
    NSString *internalSep = [NSString stringWithFormat:@",%@", startingSep];

    return [NSString stringWithFormat:@"%@%@%@", startingSep, [tokens componentsJoinedByString:internalSep], endingSep];
}

#pragma mark - Shortcuts

inline WSHash256 *WSHash256Compute(NSData *sourceData)
{
    NSData *data = [sourceData hash256];
    
    return [[WSHash256 alloc] initWithData:data];
}

inline WSHash256 *WSHash256FromHex(NSString *hexString)
{
    NSData *data = [[hexString dataFromHex] reverse];
    
    return [[WSHash256 alloc] initWithData:data];
}

inline WSHash256 *WSHash256FromData(NSData *data)
{
    return [[WSHash256 alloc] initWithData:data];
}

inline WSHash256 *WSHash256Zero()
{
    static WSHash256 *zero;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        zero = WSHash256FromHex(@"0000000000000000000000000000000000000000000000000000000000000000");
    });
    
    return zero;
}

inline WSBuffer *WSBufferFromHex(NSString *hex)
{
    return [[WSBuffer alloc] initWithData:[hex dataFromHex]];
}

inline WSMutableBuffer *WSMutableBufferFromHex(NSString *hex)
{
    return [[WSMutableBuffer alloc] initWithData:[hex dataFromHex]];
}

inline WSKey *WSKeyFromHex(NSString *hex)
{
    return [WSKey keyWithData:[hex dataFromHex]];
}

inline WSKey *WSKeyFromWIF(NSString *wif)
{
    return [WSKey keyWithWIF:wif];
}

inline WSPublicKey *WSPublicKeyFromHex(NSString *hex)
{
    return [WSPublicKey publicKeyWithData:[hex dataFromHex]];
}

inline WSAddress *WSAddressFromString(NSString *string)
{
    return [[WSAddress alloc] initWithEncoded:string];
}

inline WSAddress *WSAddressFromHex(NSString *hexString)
{
    return WSAddressFromString([hexString base58CheckFromHex]);
}

inline WSAddress *WSAddressP2PKHFromHash160(NSData *hash160)
{
    return [[WSAddress alloc] initWithVersion:[WSCurrentParameters publicKeyAddressVersion] hash160:hash160];
}

inline WSAddress *WSAddressP2SHFromHash160(NSData *hash160)
{
    return [[WSAddress alloc] initWithVersion:[WSCurrentParameters scriptAddressVersion] hash160:hash160];
}

inline WSInventory *WSInventoryTx(WSHash256 *hash)
{
    return [[WSInventory alloc] initWithType:WSInventoryTypeTx hash:hash];
}

inline WSInventory *WSInventoryTxFromHex(NSString *hex)
{
    return WSInventoryTx(WSHash256FromHex(hex));
}

inline WSInventory *WSInventoryBlock(WSHash256 *hash)
{
    return [[WSInventory alloc] initWithType:WSInventoryTypeBlock hash:hash];
}

inline WSInventory *WSInventoryBlockFromHex(NSString *hex)
{
    return WSInventoryBlock(WSHash256FromHex(hex));
}

inline WSInventory *WSInventoryFilteredBlock(WSHash256 *hash)
{
    return [[WSInventory alloc] initWithType:WSInventoryTypeFilteredBlock hash:hash];
}

inline WSInventory *WSInventoryFilteredBlockFromHex(NSString *hex)
{
    return WSInventoryFilteredBlock(WSHash256FromHex(hex));
}

inline WSNetworkAddress *WSNetworkAddressMake(uint32_t address, uint64_t services)
{
    return [[WSNetworkAddress alloc] initWithServices:services ipv4Address:address port:[WSCurrentParameters peerPort]];
}

inline WSCheckpoint *WSCheckpointMake(NSUInteger step, NSString *blockIdHex, uint32_t timestamp, uint32_t bits)
{
    // 2016 is retarget interval on main and test networks
    return [[WSCheckpoint alloc] initWithHeight:(uint32_t)(step * 2016) blockId:WSHash256FromHex(blockIdHex) timestamp:timestamp bits:bits];
}

inline WSSeed *WSSeedMake(NSString *mnemonic, NSTimeInterval creationTime)
{
    return [[WSSeed alloc] initWithMnemonic:mnemonic creationTime:creationTime];
}

inline WSSeed *WSSeedMakeUnknown(NSString *mnemonic)
{
    return [[WSSeed alloc] initWithMnemonic:mnemonic creationTime:0.0];
}

inline WSSeed *WSSeedMakeNow(NSString *mnemonic)
{
    return [[WSSeed alloc] initWithMnemonic:mnemonic];
}

inline WSSeed *WSSeedMakeFromISODate(NSString *mnemonic, NSString *iso)
{
    const NSTimeInterval creationTime = WSTimestampFromISODate(iso) - NSTimeIntervalSince1970;
    
    return WSSeedMake(mnemonic, creationTime);
}

// assume uint32 already in network byte order

inline NSString *WSNetworkHostFromIPv4(uint32_t ipv4)
{
    const uint8_t a = ipv4 & 0xff;
    const uint8_t b = (ipv4 >> 8) & 0xff;
    const uint8_t c = (ipv4 >> 16) & 0xff;
    const uint8_t d = (ipv4 >> 24) & 0xff;
    return [NSString stringWithFormat:@"%u.%u.%u.%u", a, b, c, d];
}

inline uint32_t WSNetworkIPv4FromHost(NSString *host)
{
    struct in_addr addr;
    inet_aton(host.UTF8String, &addr);
    return addr.s_addr;
}

inline NSString *WSNetworkHostFromIPv6(NSData *ipv6)
{
    NSString *hexAddress = [ipv6 hexString];
    NSMutableArray *groups = [[NSMutableArray alloc] initWithCapacity:4];
    for (NSUInteger i = 0; i < 32; i += 4) {
        [groups addObject:[hexAddress substringWithRange:NSMakeRange(i, 4)]];
    }
    return [groups componentsJoinedByString:@":"];
}

inline NSData *WSNetworkIPv6FromHost(NSString *host)
{
    NSArray *groups = [host componentsSeparatedByString:@":"];
    NSString *hexAddress = [groups componentsJoinedByString:@""];
    
    return [hexAddress dataFromHex];
}

inline NSData *WSNetworkIPv6FromIPv4(uint32_t ipv4)
{
    NSMutableData *address = [[NSMutableData alloc] initWithCapacity:16];
    [address appendBytes:"\0\0\0\0\0\0\0\0\0\0\xff\xff" length:12];
    [address appendBytes:&ipv4 length:4];
    return address;
}

inline uint32_t WSNetworkIPv4FromIPv6(NSData *ipv6)
{
    if (ipv6.length != 16) {
        return 0;
    }
    if (memcmp(ipv6.bytes, "\0\0\0\0\0\0\0\0\0\0\xff\xff", 12)) {
        return 0;
    }
    uint32_t ipv4;
    [ipv6 getBytes:&ipv4 range:NSMakeRange(12, 4)];
    return ipv4;
}

inline WSScript *WSScriptFromHex(NSString *hex)
{
    WSBuffer *buffer = WSBufferFromHex(hex);
    
    return [[WSScript alloc] initWithBuffer:buffer from:0 available:buffer.length error:NULL];
}

inline WSSignedTransaction *WSTransactionFromHex(NSString *hex)
{
    WSBuffer *buffer = WSBufferFromHex(hex);
    
    return [[WSSignedTransaction alloc] initWithBuffer:buffer from:0 available:buffer.length error:NULL];
}

inline WSBlockHeader *WSBlockHeaderFromHex(NSString *hex)
{
    WSBuffer *buffer = WSBufferFromHex(hex);
    
    return [[WSBlockHeader alloc] initWithBuffer:buffer from:0 available:buffer.length error:NULL];
}

inline WSPartialMerkleTree *WSPartialMerkleTreeFromHex(NSString *hex)
{
    WSBuffer *buffer = WSBufferFromHex(hex);
    
    return [[WSPartialMerkleTree alloc] initWithBuffer:buffer from:0 available:buffer.length error:NULL];
}

inline WSFilteredBlock *WSFilteredBlockFromHex(NSString *hex)
{
    WSBuffer *buffer = WSBufferFromHex(hex);
    
    return [[WSFilteredBlock alloc] initWithBuffer:buffer from:0 available:buffer.length error:NULL];
}

//

inline NSString *WSCurrentQueueLabel()
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    return [NSString stringWithUTF8String:dispatch_queue_get_label(dispatch_get_current_queue())];

#pragma clang diagnostic pop
}

static uint32_t WSMockTimestamp = 0;

inline uint32_t WSCurrentTimestamp()
{
    if (WSMockTimestamp) {
        return WSMockTimestamp;
    }
    return NSTimeIntervalSince1970 + [NSDate timeIntervalSinceReferenceDate];
}

inline void WSTimestampSetCurrent(uint32_t timestamp)
{
    WSMockTimestamp = timestamp;
}

inline void WSTimestampUnsetCurrent()
{
    WSMockTimestamp = 0;
}

inline uint32_t WSTimestampFromISODate(NSString *iso)
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd";
    });

    return [[formatter dateFromString:iso] timeIntervalSince1970];
}
