//
//  WSTransactionTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 21/06/14.
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

#import "XCTestCase+WaSPV.h"
#import "WSTransactionOutPoint.h"
#import "WSTransactionInput.h"
#import "WSTransactionOutput.h"
#import "WSTransaction.h"
#import "WSScript.h"
#import "WSKey.h"
#import "WSPublicKey.h"
#import "WSAddress.h"

@interface WSTransactionTests : XCTestCase

@end

@implementation WSTransactionTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//
// https://blockexplorer.com/tx/a1dd05e0a5acae14d75d5c66c21e36d4ee190456f3480edbf68057bd094137da
//
- (void)testEncodeSigned
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    WSTransactionOutPoint *inputOutpoint = nil;
    WSSignedTransactionInput *input = nil;
    WSTransactionOutput *output = nil;
    WSHash256 *inputTxId = nil;
    uint32_t inputIndex = 0;
    NSData *inputSignatureData = nil;
    WSPublicKey *inputPublicKey = nil;
    WSScript *inputScript = nil;
    uint64_t outputValue = 0;
    WSAddress *outputAddress = nil;
    
    NSMutableOrderedSet *inputs = [[NSMutableOrderedSet alloc] init];
    NSMutableOrderedSet *outputs = [[NSMutableOrderedSet alloc] init];
    
    inputTxId = WSHash256FromHex(@"b1ab2d157aff8d387d8ca690944697c411f086061841efeed1a4fd558fb7cb59");
    inputIndex = 0;
    inputOutpoint = [WSTransactionOutPoint outpointWithTxId:inputTxId index:inputIndex];
    inputSignatureData = [@"3046022100f0dbc62f00bda641833416e34f062234ccf9256daf21aad54ca3cebc87e714540221009e27727760cc2274d7e92d9e23fc781438d641bd934c44547ec8f16af4dd18fa01" dataFromHex];
    inputPublicKey = WSPublicKeyFromHex(@"042a65f36cfbd9f016597e219870bb741b9f5f0a1deaedafea569d6968c2d72b62a4bc8915584ba2bf690d92c737f7cda03a0c1377d9ed90977b044927892294f3");
    inputScript = [WSScript scriptWithSignature:inputSignatureData publicKey:inputPublicKey];
    input = [[WSSignedTransactionInput alloc] initWithOutpoint:inputOutpoint script:inputScript];
    [inputs addObject:input];

    inputTxId = WSHash256FromHex(@"3731de409f21497cf6e919e1bdb77ea7fcfb69c32e7b892f2ab31e64e1e4c4a8");
    inputIndex = 0;
    inputOutpoint = [WSTransactionOutPoint outpointWithTxId:inputTxId index:inputIndex];
    inputSignatureData = [@"304502210086089db5a7445103540ac25b071199828c2fcf4a596df68315788ca7da15563402207c1bef9a5dcb84a7670983688d292a615f217517fb3956d601d999384dfb892001" dataFromHex];
    inputPublicKey = WSPublicKeyFromHex(@"045d6a5319757ea49302cf7bc94499e0aace02cf336a7efc3b335909e473fe51a88d83aa027cee19ab6e8a1413ea5f5647a9b6dbfb50c23c1c16e4d7074bf9fb13");
    inputScript = [WSScript scriptWithSignature:inputSignatureData publicKey:inputPublicKey];
    input = [[WSSignedTransactionInput alloc] initWithOutpoint:inputOutpoint script:inputScript];
    [inputs addObject:input];
    
    inputTxId = WSHash256FromHex(@"ed083386a0466325e8d5bca01408799af5069a963e693fabd0c259a14d61faf4");
    inputIndex = 1;
    inputOutpoint = [WSTransactionOutPoint outpointWithTxId:inputTxId index:inputIndex];
    inputSignatureData = [@"304402204574cf17abe22196da2707ef28adf08d91ee43c70faa4ff80617df004f3a50e802207ff0fb1984ac78f6ad0f382f16d9d6a18d5afe4d62eeed854739b8c1ffaf62ef01" dataFromHex];
    inputPublicKey = WSPublicKeyFromHex(@"043811ceb31510fe4a317b7eb8ae78aa3a523725dcc46ba80101f41363fa189c26663e5abcb33feb11b2c1b12cffe72e14d93c536d3b75ff1d07b0514e121839f4");
    inputScript = [WSScript scriptWithSignature:inputSignatureData publicKey:inputPublicKey];
    input = [[WSSignedTransactionInput alloc] initWithOutpoint:inputOutpoint script:inputScript];
    [inputs addObject:input];
    
    inputTxId = WSHash256FromHex(@"52f54fc8f57818e35bc855a5d8deee19fa58c8760729cf7749298d29ed625e4f");
    inputIndex = 0;
    inputOutpoint = [WSTransactionOutPoint outpointWithTxId:inputTxId index:inputIndex];
    inputSignatureData = [@"30440220365b2950ea43338641151956a3af17e013d2b71251aa67cb43bf36cadfdfebb802205a815577a6cb347dbd803edc3141ac1e4e6f08d03634e6c6a683bbc19fb13fd301" dataFromHex];
    inputPublicKey = WSPublicKeyFromHex(@"046172813a3084d6cc3f838f10ae7583b685164a01dec67f1a9091fe5aa75c7d33fdcfd35842847aa4e85c891520507569aabb4cb5f91caf18ffcc10e809a810bc");
    inputScript = [WSScript scriptWithSignature:inputSignatureData publicKey:inputPublicKey];
    input = [[WSSignedTransactionInput alloc] initWithOutpoint:inputOutpoint script:inputScript];
    [inputs addObject:input];
    
    outputValue = 6559273;
    outputAddress = WSAddressFromString(@"1ApDBwt87ZoZBoKhdrFZq155zofELEqXzG");
    output = [[WSTransactionOutput alloc] initWithValue:outputValue address:outputAddress];
    [outputs addObject:output];

    outputValue = 2231596000;
    outputAddress = WSAddressFromString(@"1DSpC9bStt4hPnZ89Z7MkhMfqdqgbQGr3Z");
    output = [[WSTransactionOutput alloc] initWithValue:outputValue address:outputAddress];
    [outputs addObject:output];
    
    for (WSSignedTransactionInput *input in inputs) {
        const NSUInteger estimatedSize = [input.script estimatedSize];
        const NSUInteger size = [[input.script toBuffer] length];
        DDLogInfo(@"Input script size: %u == %u", estimatedSize, size);
        XCTAssertEqual(estimatedSize, size, @"Estimated input script size differs");
    }

    for (WSTransactionOutput *output in outputs) {
        const NSUInteger estimatedSize = [output.script estimatedSize];
        const NSUInteger size = [[output.script toBuffer] length];
        DDLogInfo(@"Output script size: %u == %u", estimatedSize, size);
        XCTAssertEqual(estimatedSize, size, @"Estimated output script size differs");
    }

//    // depending transactions needed to test fee and input value
//    const uint64_t expTotalInputValue = 2238205273;
//    XCTAssertEqual([tx inputValue], expTotalInputValue, @"Tx input value differs");
//    uint64_t fee;
//    const uint64_t expFee = 50000;
//    NSError *error;
//    XCTAssertTrue([tx verifyWithEffectiveFee:&fee error:&error], @"Invalid tx: %@", error);
//    XCTAssertEqual(fee, expFee);

    WSSignedTransaction *tx = [[WSSignedTransaction alloc] initWithSignedInputs:inputs outputs:outputs];

    NSString *txHex = [[tx toBuffer] hexString];
    NSString *expTxHex = @"010000000459cbb78f55fda4d1eeef41180686f011c497469490a68c7d388dff7a152dabb1000000008c493046022100f0dbc62f00bda641833416e34f062234ccf9256daf21aad54ca3cebc87e714540221009e27727760cc2274d7e92d9e23fc781438d641bd934c44547ec8f16af4dd18fa0141042a65f36cfbd9f016597e219870bb741b9f5f0a1deaedafea569d6968c2d72b62a4bc8915584ba2bf690d92c737f7cda03a0c1377d9ed90977b044927892294f3ffffffffa8c4e4e1641eb32a2f897b2ec369fbfca77eb7bde119e9f67c49219f40de3137000000008b48304502210086089db5a7445103540ac25b071199828c2fcf4a596df68315788ca7da15563402207c1bef9a5dcb84a7670983688d292a615f217517fb3956d601d999384dfb89200141045d6a5319757ea49302cf7bc94499e0aace02cf336a7efc3b335909e473fe51a88d83aa027cee19ab6e8a1413ea5f5647a9b6dbfb50c23c1c16e4d7074bf9fb13fffffffff4fa614da159c2d0ab3f693e969a06f59a790814a0bcd5e8256346a0863308ed010000008a47304402204574cf17abe22196da2707ef28adf08d91ee43c70faa4ff80617df004f3a50e802207ff0fb1984ac78f6ad0f382f16d9d6a18d5afe4d62eeed854739b8c1ffaf62ef0141043811ceb31510fe4a317b7eb8ae78aa3a523725dcc46ba80101f41363fa189c26663e5abcb33feb11b2c1b12cffe72e14d93c536d3b75ff1d07b0514e121839f4ffffffff4f5e62ed298d294977cf290776c858fa19eeded8a555c85be31878f5c84ff552000000008a4730440220365b2950ea43338641151956a3af17e013d2b71251aa67cb43bf36cadfdfebb802205a815577a6cb347dbd803edc3141ac1e4e6f08d03634e6c6a683bbc19fb13fd30141046172813a3084d6cc3f838f10ae7583b685164a01dec67f1a9091fe5aa75c7d33fdcfd35842847aa4e85c891520507569aabb4cb5f91caf18ffcc10e809a810bcffffffff0229166400000000001976a9146ba6db5d885b4fcc24307d378664a8db3f9ace4488ace0730385000000001976a91488834d722528175119b77724652b9711cd7818c488ac00000000";
    DDLogInfo(@"Tx      : %@", txHex);
    DDLogInfo(@"Expected: %@", expTxHex);
    XCTAssertEqualObjects(txHex, expTxHex, @"Tx differs");

    WSHash256 *txId = tx.txId;
    WSHash256 *expTxId = WSHash256FromHex(@"a1dd05e0a5acae14d75d5c66c21e36d4ee190456f3480edbf68057bd094137da");
    DDLogInfo(@"TxId    : %@", txId);
    DDLogInfo(@"Expected: %@", expTxId);
    XCTAssertEqualObjects(txId, expTxId, @"TxId differs");
    
    NSUInteger size = tx.size;
    const NSUInteger expSize = 797;
    DDLogInfo(@"Size: %u", size);
    XCTAssertEqual(size, expSize, @"Tx size differs");
    
    const uint64_t expTotalOutputValue = 2238155273;
    XCTAssertEqual([tx outputValue], expTotalOutputValue, @"Tx output value differs");

    DDLogInfo(@"Standard fee: %llu", WSTransactionStandardRelayFee(tx.size));

    DDLogInfo(@"Tx: %@", tx);
}

- (void)testDecodeSigned
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    WSHash256 *expTxId = WSHash256FromHex(@"a1dd05e0a5acae14d75d5c66c21e36d4ee190456f3480edbf68057bd094137da");
    NSString *expTxHex = @"010000000459cbb78f55fda4d1eeef41180686f011c497469490a68c7d388dff7a152dabb1000000008c493046022100f0dbc62f00bda641833416e34f062234ccf9256daf21aad54ca3cebc87e714540221009e27727760cc2274d7e92d9e23fc781438d641bd934c44547ec8f16af4dd18fa0141042a65f36cfbd9f016597e219870bb741b9f5f0a1deaedafea569d6968c2d72b62a4bc8915584ba2bf690d92c737f7cda03a0c1377d9ed90977b044927892294f3ffffffffa8c4e4e1641eb32a2f897b2ec369fbfca77eb7bde119e9f67c49219f40de3137000000008b48304502210086089db5a7445103540ac25b071199828c2fcf4a596df68315788ca7da15563402207c1bef9a5dcb84a7670983688d292a615f217517fb3956d601d999384dfb89200141045d6a5319757ea49302cf7bc94499e0aace02cf336a7efc3b335909e473fe51a88d83aa027cee19ab6e8a1413ea5f5647a9b6dbfb50c23c1c16e4d7074bf9fb13fffffffff4fa614da159c2d0ab3f693e969a06f59a790814a0bcd5e8256346a0863308ed010000008a47304402204574cf17abe22196da2707ef28adf08d91ee43c70faa4ff80617df004f3a50e802207ff0fb1984ac78f6ad0f382f16d9d6a18d5afe4d62eeed854739b8c1ffaf62ef0141043811ceb31510fe4a317b7eb8ae78aa3a523725dcc46ba80101f41363fa189c26663e5abcb33feb11b2c1b12cffe72e14d93c536d3b75ff1d07b0514e121839f4ffffffff4f5e62ed298d294977cf290776c858fa19eeded8a555c85be31878f5c84ff552000000008a4730440220365b2950ea43338641151956a3af17e013d2b71251aa67cb43bf36cadfdfebb802205a815577a6cb347dbd803edc3141ac1e4e6f08d03634e6c6a683bbc19fb13fd30141046172813a3084d6cc3f838f10ae7583b685164a01dec67f1a9091fe5aa75c7d33fdcfd35842847aa4e85c891520507569aabb4cb5f91caf18ffcc10e809a810bcffffffff0229166400000000001976a9146ba6db5d885b4fcc24307d378664a8db3f9ace4488ace0730385000000001976a91488834d722528175119b77724652b9711cd7818c488ac00000000";

    NSError *error;
    WSBuffer *buffer = WSBufferFromHex(expTxHex);
    WSSignedTransaction *tx = [[WSSignedTransaction alloc] initWithBuffer:buffer from:0 available:buffer.length error:&error];
    XCTAssertNotNil(tx, @"Error parsing transaction: %@", error);
    XCTAssertEqualObjects(tx.txId, expTxId);
    
    NSString *txHex = [[tx toBuffer] hexString];
    XCTAssertEqualObjects(txHex, expTxHex);
    
    NSArray *expInTxids = @[WSHash256FromHex(@"b1ab2d157aff8d387d8ca690944697c411f086061841efeed1a4fd558fb7cb59"),
                            WSHash256FromHex(@"3731de409f21497cf6e919e1bdb77ea7fcfb69c32e7b892f2ab31e64e1e4c4a8"),
                            WSHash256FromHex(@"ed083386a0466325e8d5bca01408799af5069a963e693fabd0c259a14d61faf4"),
                            WSHash256FromHex(@"52f54fc8f57818e35bc855a5d8deee19fa58c8760729cf7749298d29ed625e4f")];

    NSArray *expInIndexes = @[@(0), @(0), @(1), @(0)];
    
    NSArray *expInAddresses = @[@"1QU41PkTSwfDETtcMU8jhWz3dreH4F369",
                                @"188ZEDXLnhisB92zABDCVCeJsjgi1WnJJd",
                                @"16nirdfJq95apcRRsUxuss8RKXyQTPtvGE",
                                @"19mrmMHpmt76UnQr8hZRnYQgaUJpSjRsQZ"];
    
    NSArray *expOutAddresses = @[@"1ApDBwt87ZoZBoKhdrFZq155zofELEqXzG",
                                 @"1DSpC9bStt4hPnZ89Z7MkhMfqdqgbQGr3Z"];

    NSArray *expOutValues = @[@(6559273),
                              @(2231596000)];

    NSUInteger ii = 0;
    for (WSSignedTransactionInput *txIn in tx.inputs) {
        DDLogInfo(@"In txid (eff): %@", txIn.outpoint.txId);
        DDLogInfo(@"In txid (exp): %@", expInTxids[ii]);
        XCTAssertEqualObjects(txIn.outpoint.txId, expInTxids[ii]);

        DDLogInfo(@"In index (eff): %u", txIn.outpoint.index);
        DDLogInfo(@"In index (exp): %u", [expInIndexes[ii] unsignedIntegerValue]);
        XCTAssertEqual(txIn.outpoint.index, [expInIndexes[ii] unsignedIntegerValue]);
        
        DDLogInfo(@"In address (eff): %@", txIn.address);
        DDLogInfo(@"In address (exp): %@", expInAddresses[ii]);
        XCTAssertEqualObjects(txIn.address, WSAddressFromString(expInAddresses[ii]));

        ++ii;
    }

    NSUInteger oi = 0;
    for (WSTransactionOutput *txOut in tx.outputs) {
        DDLogInfo(@"Out address (eff): %@", txOut.address);
        DDLogInfo(@"Out address (exp): %@", expOutAddresses[oi]);
        XCTAssertEqualObjects(txOut.address, WSAddressFromString(expOutAddresses[oi]));

        DDLogInfo(@"Out address (eff): %llu", txOut.value);
        DDLogInfo(@"Out address (exp): %llu", [expOutValues[oi] unsignedLongLongValue]);
        XCTAssertEqual(txOut.value, [expOutValues[oi] unsignedLongLongValue]);
        
        ++oi;
    }
}

- (void)testDecodeMultiSigned
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);

    WSHash256 *expTxId = WSHash256FromHex(@"7f53001bf79f5a874c018cce58471fd51a9444b564bbbb37032bda7f2beb9439");
    NSString *expTxHex = @"0100000002c60c5a1d539c43101b0d4d36fce86941d132d126670320a02cfeb55d733de76e01000000fdfe00004830450220514685bdf8388e969bb19bdeff8be23cfbb346f096551ed7a9d919f4031881c5022100e5fd38b24c932fcade093c73216c7227aa5acd7c2619b7e6369de3269cf2c3a001483045022052ef60dc14532da93fa7acb82c897daf4d2ac56ddad779dff9f8519453484be5022100e6741933963ec1c09f41fc06bd48cc109d3647655cbfcbabafb5b2dea88dfcf8014c6952210387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec8521034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd21035bdd8633818888875bbc4232d384b411dc67f4efe11e6582de52d196adc6d29a53aeffffffff0efe1d2b69d50fc4271ac76671ac3f549617bde1cab71c715212fb062030725401000000fd000100493046022100bddd0d72c54fce23718d4450720e60a90d6c7c50af1c3caeb25dd49228a7233a022100c905f4bb5c624d594dbb364ffbeffc1f9e8ab72dac297b2f8fb1f07632fdf52801493046022100f8ff9b9fd434bf018c21725047b0205c4ab70bcc999c625c8c5573a836d7b525022100a7cfc4f741386c1b22d0e2a994139f52961d86d51332fc03d117bb422abb9123014c6952210387e679718c6a67f4f2c25a0b58df70067ec9f90c4297368e24fd5342027bec8521034a9ccd9aca88aa9d20c73289a075392e1cd67a5f33938a0443f530afa3675fcd2103082587f27afa0481c6af0e75bead2daabdd0ac17395563bd9282ed6ca00025db53aeffffffff0230cd23f7000000001976a91469611d4ddff939f5ef553f020ba3ba0f1d1d76d688ac032700000000000017a91431ecbf82d5dac9ec751e450fc38f098e3d630cb68700000000";

    WSBuffer *buffer = WSBufferFromHex(expTxHex);
    NSError *error;
    WSSignedTransaction *tx = [[WSSignedTransaction alloc] initWithBuffer:buffer from:0 available:buffer.length error:&error];
    XCTAssertNotNil(tx, @"Error parsing tx: %@", error);

    XCTAssertEqualObjects(tx.txId, expTxId, @"Tx id differs");
    DDLogInfo(@"Tx: %@", tx);
    XCTAssertFalse([tx isCoinbase], @"Tx is coinbase");
}

- (void)testDecodeCoinbase
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
//    WSHash256 *expTxId = WSHash256FromHex(@"799ee3a382c4857ccc78e9118320a6d90502a549685cbeea1bf63b6bd00127ff");
//    NSString *expTxHex = @"01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff0d03931004016f062f503253482fffffffff01006a059500000000232102a373647ab5aeb6ee1f52462e6b15a021ba047a90c8ab5bce02c7b386a16662abac00000000";
    WSHash256 *expTxId = WSHash256FromHex(@"facad01e5a1196a17a1d59cf76fba12361466f55884528c0892dbbe01ff96307");
    NSString *expTxHex = @"01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff11039311040453b59c390300000022000000ffffffff01b8750595000000001976a91492eccb56e6e2f31a27d48c35b3b8bced30626c8d88ac00000000";

    WSBuffer *buffer = WSBufferFromHex(expTxHex);
    NSError *error;
    WSSignedTransaction *tx = [[WSSignedTransaction alloc] initWithBuffer:buffer from:0 available:buffer.length error:&error];
    XCTAssertNotNil(tx, @"Error parsing tx: %@", error);

    XCTAssertEqualObjects(tx.txId, expTxId, @"Tx id differs");
    DDLogInfo(@"Tx: %@", tx);
    XCTAssertTrue([tx isCoinbase], @"Tx is not coinbase");
}

- (void)testEncodeUnsigned
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    WSAddress *expInAddress = WSAddressFromString(@"1PMycacnJaSqwwJqjawXBErnLsZ7RkXUAs");

    WSTransactionBuilder *builder = [[WSTransactionBuilder alloc] init];

    WSKey *inputKey = WSKeyFromHex(@"18e14a7b6a307f426a94f8114701e7c8e774e7f9a47e2c2035db29a206321725");
    WSScript *previousOutputScript = [WSScript scriptWithAddress:[inputKey address]];
    WSTransactionOutput *previousOutput = [[WSTransactionOutput alloc] initWithValue:99900000LL script:previousOutputScript];
    
    WSHash256 *inputTxId = WSHash256FromHex(@"eccf7e3034189b851985d871f91384b8ee357cd47c3024736e5676eb2debb3f2");
    WSTransactionOutPoint *inputOutpoint = [WSTransactionOutPoint outpointWithTxId:inputTxId index:1];
    WSSignableTransactionInput *input = [[WSSignableTransactionInput alloc] initWithPreviousOutput:previousOutput outpoint:inputOutpoint];

    DDLogInfo(@"In address : %@", input.address);
    DDLogInfo(@"Exp address: %@", expInAddress);
    XCTAssertEqualObjects(input.address, expInAddress, @"Input address differs");
    
    uint64_t outputValue = 99900000LL;
    WSAddress *outputAddress = WSAddressFromHex(@"00097072524438d003d23a2f23edb65aae1bb3e469");
    DDLogInfo(@"Out address : %@", outputAddress);
    WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithValue:outputValue address:outputAddress];

    [builder addSignableInput:input];
    [builder addOutput:output];

//    NSString *signable = [[input signableBufferForTransaction:tx] hexString];
//    NSString *expSignable = @"0100000001f2b3eb2deb76566e7324307cd47c35eeb88413f971d88519859b1834307ecfec010000001976a914f54a5851e9372b87810a8e60cdd2e7cfd80b6e3188acffffffff01605af405000000001976a914097072524438d003d23a2f23edb65aae1bb3e46988ac0000000001000000";
//    DDLogInfo(@"Signable: %@", signable);
//    XCTAssertEqualObjects(signable, expSignable, @"Unsigned transaction differs");
//    
//    [tx pack];
//    DDLogInfo(@"Unsigned size: %u", tx.size);
//    XCTAssertEqual(tx.size, 110, @"Unsigned tx size differs");
//
//    DDLogInfo(@"Tx: %@", tx);
    
    //

    NSError *error;
    NSOrderedSet *inputKeys = [[NSOrderedSet alloc] initWithArray:@[inputKey]];
    WSSignedTransaction *tx = [builder signedTransactionWithInputKeys:inputKeys error:&error];
    XCTAssertNotNil(tx, @"Unable to sign transaction: %@", error);

    DDLogInfo(@"Signed tx hex (%u): %@", tx.size, [[tx toBuffer] hexString]);
    DDLogInfo(@"TxId: %@", tx.txId);
    DDLogInfo(@"Tx: %@", tx);
}

- (void)testDecodeUnsigned
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    NSError *error;
    NSString *expTxHex = @"0100000001eccf7e3034189b851985d871f91384b8ee357cd47c3024736e5676eb2debb3f2010000006a47304402202d5f2cf848a00cbd695f1eda2bbab05c23e882e0a19c5d93d112a9c8392bcb4302204307e7abddad6cd329194a1930d30f7717dc20fcde0bdc69f7014305bdd8f2f501210250863ad64a87ae8a2fe83c1af1a8403cb53f53e486d8511dad8a04887e5b2352ffffffff01605af405000000001976a914097072524438d003d23a2f23edb65aae1bb3e46988ac00000000";
    WSBuffer *buffer = WSBufferFromHex(expTxHex);
    WSSignedTransaction *tx = [[WSSignedTransaction alloc] initWithBuffer:buffer from:0 available:buffer.length error:&error];
    XCTAssertNotNil(tx, @"Error parsing transaction: %@", error);

    NSString *txHex = [[tx toBuffer] hexString];
    DDLogInfo(@"Tx      : %@", txHex);
    DDLogInfo(@"Expected: %@", expTxHex);
    XCTAssertEqualObjects(txHex, expTxHex);

    WSSignedTransactionInput *txIn = [tx.inputs lastObject];
    WSAddress *expInAddress = WSAddressFromString(@"1PMycacnJaSqwwJqjawXBErnLsZ7RkXUAs");
    DDLogInfo(@"Input  (eff): %@", txIn.address);
    DDLogInfo(@"Input  (exp): %@", expInAddress);
    XCTAssertEqualObjects(txIn.address, expInAddress);

    WSTransactionOutput *txOut = [tx.outputs lastObject];
    WSAddress *expOutAddress = WSAddressFromString(@"1runeksijzfVxyrpiyCY2LCBvYsSiFsCm");
    DDLogInfo(@"Output (eff): %@", txOut.address);
    DDLogInfo(@"Output (exp): %@", expOutAddress);
    XCTAssertEqualObjects(txOut.address, expOutAddress);
}

- (void)testAddressFromInput
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    WSHash256 *txId = WSHash256FromHex(@"b1ab2d157aff8d387d8ca690944697c411f086061841efeed1a4fd558fb7cb59");
    uint32_t index = 0;
    NSData *signatureData = [@"3046022100f0dbc62f00bda641833416e34f062234ccf9256daf21aad54ca3cebc87e714540221009e27727760cc2274d7e92d9e23fc781438d641bd934c44547ec8f16af4dd18fa01" dataFromHex];
    WSPublicKey *publicKey = WSPublicKeyFromHex(@"042a65f36cfbd9f016597e219870bb741b9f5f0a1deaedafea569d6968c2d72b62a4bc8915584ba2bf690d92c737f7cda03a0c1377d9ed90977b044927892294f3");
    WSScript *script = [WSScript scriptWithSignature:signatureData publicKey:publicKey];

    WSTransactionOutPoint *outpoint = [WSTransactionOutPoint outpointWithTxId:txId index:index];
    WSSignedTransactionInput *input = [[WSSignedTransactionInput alloc] initWithOutpoint:outpoint script:script];
    WSAddress *address = input.address;
    WSAddress *expAddress = WSAddressFromString(@"1QU41PkTSwfDETtcMU8jhWz3dreH4F369");
    DDLogInfo(@"Input address (eff): %@", [address hexEncoded]);
    DDLogInfo(@"Input address (exp): %@", [expAddress hexEncoded]);
    XCTAssertEqualObjects(address, expAddress);
}

- (void)testAddressFromOutput
{
    WSParametersSetCurrentType(WSParametersTypeMain);

    uint64_t value = 6559273;
    WSAddress *expAddress = WSAddressFromString(@"1ApDBwt87ZoZBoKhdrFZq155zofELEqXzG");
    WSScript *scriptPubKey = [WSScript scriptWithAddress:expAddress];

    WSTransactionOutput *output = [[WSTransactionOutput alloc] initWithValue:value script:scriptPubKey];
    WSAddress *address = output.address;
    DDLogInfo(@"Output address (eff): %@", [address hexEncoded]);
    DDLogInfo(@"Output address (exp): %@", [expAddress hexEncoded]);
    XCTAssertEqualObjects(address, expAddress);
}

- (void)testBuggedScriptDecoding1
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);

    // chunk #3 of input script was erroneously parsed as simple push data while it's a PUSHDATA1 chunk
    WSSignedTransaction *tx = WSTransactionFromHex(@"0100000001abd8dc69c94055ec6fb0b4060410766beb5a5b9f2579e95f3e326aa0bcfc8f3701000000db0047304402205b74804f2bc74ec1a1bec93b91a7bb3d9c7cbc07c3eae0925df9100646c76c37022052a5a6e30a17d9c041e09ad7a6813a1b34638e1ad235d26820dcc1dada8e2fae0148304502200d92f533d701e215e9521bbaa598a967af789d51f3592e1fe75bb62bad042e3d022100a21d300047cb16617837c1a1601ca7d9ed5f9f1794806efc5891812b812af7af014c47522102a24a23eb4bef1144e2998c3bfafc91bb9675e860d003750a68fe8ab5327b8d552103176339eec79b4a3a5fd91eb10b0cdd644b1ae80034dbaa92125f82d68b33871752aeffffffff03b8e69700000000001976a914a9a63cdf9183f81a9879daf129f546f2d9840ace88aca8610000000000001976a9143c21350e06c7834a2cce34f94f92da2f703d432488ac80c3c9010000000017a9141ec00101c0bd13440d53599ad2e963d1afe14db68700000000");
    DDLogInfo(@"Tx: %@", tx);
}

- (void)testBuggedScriptDecoding2
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    // coinbase script is malformed
    WSSignedTransaction *tx = WSTransactionFromHex(@"01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff1103c016040453bdbc2d0100000018000000ffffffff0110200395000000001976a91492eccb56e6e2f31a27d48c35b3b8bced30626c8d88ac00000000");
    DDLogInfo(@"Tx: %@", tx);
}

- (void)testBuggedScriptDecoding3
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    // chunk #3 of output scripts was erroneously parsed as simple push data while it's a PUSHDATA1 chunk
    WSSignedTransaction *tx = WSTransactionFromHex(@"0100000002090337869c896bc9228d19771a0bb9c1a38866aeea5280c7b6fc7b170c3c87a600000000de00493046022100cd7a20a6f066c5ca38d03fc881540764d7ad7e3610d883eb5c6af51a87564a0e022100b7b765b72d767f505bb97f704be24fe238b122e2c223b69808740ec5c67f410f01493046022100d2d2787996963e4cfa0b872034f2ed3b5e6493af4b41b25ad94b5ccec5860457022100bcfcdeda5fa09b9767d132da6d50858165c81184a70c786278118f923697cc2e014c47522102b17618332fc6429bf7ec3668666729b60d1d0c29dc7da96fd7343d5de75ccc0121027bc8492461d5f01e4191c55c690e2feabbaa2a5c74365535dba099ff514e503752aeffffffffada23dc535ec76719dce858d3ce584794b3bebcddeb59d2d8687fd32f678aa3400000000dd004830450220261cac5048e4849998bae5e570f8218e17164440cbf6786d7d79d79b4fa124dd022100d266b4e23eb9c44da481d23b66a0e333ae5daa22185764370d36380e27ab561901493046022100e1f11b55e8a00dfad91bdd60310b32f2b41901ba943c2a74317f2be49936a1e8022100cb6999df327d0b545854b512642db401938f1e193496fe424285d2d1b448336c014c47522102038315ca4756d8b99b847d03391c9024444b1b6a8f0b5b2cd72a66302dea48272102053e06f5950907d20b9afffcfd801de2d6d92d417e709de425b371c10f4a6f0b52aeffffffff024865e300000000001976a914f043be6aa802968747449606881bc206e1f7172688ac18920000000000001976a9143c21350e06c7834a2cce34f94f92da2f703d432488ac00000000");
    DDLogInfo(@"Tx: %@", tx);
}

- (void)testBuggedMultiSigDecoding
{
    WSParametersSetCurrentType(WSParametersTypeTestnet3);
    
    // output is a 2-to-3 multisig script (block #268691 on testnet3)
    WSSignedTransaction *tx = WSTransactionFromHex(@"0100000002ca18ec2556f55582e461a1c8d57871d512f28af8064a32c6060af168f7b9b38a000000004a00483045022100f9e04c1e703f277cda2c5a13d9c3c2877639c526db68b1babaf46f930674be3802201b0e1a24407cf81794a23e0d7c2c52f92721111a6c77f4f06e264274449bdf4401fffffffffc88317c2bf21146363ed90e1b0c34e052989de886d150a692e1403d6f5f9025000000004900473044022079e5ca82ab625d957198a80a825dd045d435e2193208028f6013dae323a970a302203e5053c08f05a51a37e1344673eb58fa723963701061c75f0214757d6caf728801ffffffff01dc747a0000000000695221037bf122821ae522f67b7bc09387c2907607cdd66e6bd67bcb53f39d5346adc7482103540be1c323e54ad38f45a12d42d409fb798fab71551559d2feabf2ac473aeffc2103540be1c323e54ad38f45a12d42d409fb798fab71551559d2feabf2ac473aeffc53ae00000000");
    DDLogInfo(@"Tx: %@", tx);
}

@end
