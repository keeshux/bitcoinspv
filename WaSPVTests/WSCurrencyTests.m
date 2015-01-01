//
//  WSCurrencyTests.m
//  WaSPV
//
//  Created by Davide De Rosa on 01/01/15.
//  Copyright (c) 2015 Davide De Rosa. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "WaSPV.h"

#define DEC(s) [NSDecimalNumber decimalNumberWithString:s]

@interface WSCurrencyTests : XCTestCase

@end

@implementation WSCurrencyTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBasic
{
    WSBitcoinCurrency *btc = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeBTC];
    WSBitcoinCurrency *millis = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeMilliBTC];
    WSBitcoinCurrency *sat = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeSatoshi];

    XCTAssertEqualObjects([btc valueFromSatoshi:100], DEC(@"0.000001"));
    XCTAssertEqualObjects([millis valueFromSatoshi:100], DEC(@"0.001"));
    XCTAssertEqualObjects([btc valueFromSatoshi:100000000], DEC(@"1"));
    XCTAssertEqualObjects([millis valueFromSatoshi:100000], DEC(@"1"));
    XCTAssertEqualObjects([sat valueFromSatoshi:100000], DEC(@"100000"));
}

- (void)testCrossed
{
    WSBitcoinCurrency *btc = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeBTC];
    WSBitcoinCurrency *millis = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeMilliBTC];
    WSBitcoinCurrency *sat = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeSatoshi];

    XCTAssertEqualObjects([btc convertValue:DEC(@"0.00456") toCurrency:millis], DEC(@"4.56"));
    XCTAssertEqualObjects([millis convertValue:DEC(@"4.56") toCurrency:btc], DEC(@"0.00456"));
    XCTAssertEqualObjects([btc convertValue:DEC(@"120") toCurrency:millis], DEC(@"120000"));
    XCTAssertEqualObjects([btc convertValue:DEC(@"120") toCurrency:btc], DEC(@"120"));
    XCTAssertEqualObjects([btc convertValue:DEC(@"120") toCurrency:sat], DEC(@"12000000000"));
    XCTAssertEqualObjects([millis convertValue:DEC(@"120000") toCurrency:btc], DEC(@"120"));
    XCTAssertEqualObjects([millis convertValue:DEC(@"120000") toCurrency:millis], DEC(@"120000"));
    XCTAssertEqualObjects([millis convertValue:DEC(@"4.56") toCurrency:sat], DEC(@"456000"));
}

- (void)testPhysical
{
    WSBitcoinCurrency *btc = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeBTC];
    WSBitcoinCurrency *millis = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeMilliBTC];
    WSBitcoinCurrency *sat = [WSBitcoinCurrency currencyForCode:WSBitcoinCurrencyCodeSatoshi];

    WSPhysicalCurrency *usd = [[WSPhysicalCurrency alloc] initWithCode:WSPhysicalCurrencyCodeUSD
                                                       conversionRates:@{WSBitcoinCurrencyCodeBTC: @0.003125,
                                                                         WSPhysicalCurrencyCodeEUR: @0.83}];

    WSPhysicalCurrency *eur = [[WSPhysicalCurrency alloc] initWithCode:WSPhysicalCurrencyCodeEUR
                                                       conversionRates:@{WSBitcoinCurrencyCodeBTC: @0.0038,
                                                                         WSPhysicalCurrencyCodeUSD: @1.2}];
    
    XCTAssertEqualObjects([btc convertValue:DEC(@"120") toCurrency:millis], DEC(@"120000"));
    XCTAssertEqualObjects([btc convertValue:DEC(@"120") toCurrency:btc], DEC(@"120"));
    XCTAssertEqualObjects([btc convertValue:DEC(@"120") toCurrency:usd], DEC(@"38400"));
    XCTAssertEqualObjects([millis convertValue:DEC(@"120000") toCurrency:usd], DEC(@"38400"));
    XCTAssertEqualObjects([eur convertValue:DEC(@"3") toCurrency:millis], DEC(@"11.4"));
    XCTAssertEqualObjects([usd convertValue:DEC(@"12.5") toCurrency:sat], DEC(@"3906250"));
    XCTAssertEqualObjects([usd convertValue:DEC(@"1") toCurrency:eur], DEC(@"0.83"));
    XCTAssertEqualObjects([eur convertValue:DEC(@"1") toCurrency:usd], DEC(@"1.2"));
}

@end
