//
//  WSAppDelegate.m
//  BitcoinSPV
//
//  Created by Davide De Rosa on 12/06/14.
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

#import "DDTTYLogger.h"
#import "BitcoinSPV.h"

#import "WSAppDelegate.h"

//int ddLogLevel = LOG_LEVEL_VERBOSE;
int ddLogLevel = LOG_LEVEL_DEBUG;
//int ddLogLevel = LOG_LEVEL_INFO;

static NSString *const      CHAIN_FILE              = @"Demo.sqlite";
static NSString *const      WALLET_FILE             = @"Demo.wallet";
static NSString *const      WALLET_MNEMONIC         = @"news snake whip verb camera renew siege never eager physical type wet";
static const NSTimeInterval WALLET_CREATION_TIME    = 423352800;

@interface WSAppDelegate ()

@property (nonatomic, strong) id<WSParameters> parameters;

@property (nonatomic, strong) UILabel *labelBalance;
@property (nonatomic, strong) UITextField *textAddress;
@property (nonatomic, strong) UIView *viewSync;

@property (nonatomic, strong) NSString *chainPath;
@property (nonatomic, strong) NSString *walletPath;
@property (nonatomic, strong) WSBlockChainDownloader *downloader;
@property (nonatomic, strong) WSPeerGroup *peerGroup;
@property (nonatomic, strong) WSHDWallet *wallet;

- (void)createWallet;
- (void)createPeerGroup;

- (void)printWallet;
- (void)updateBalanceLabel;
- (void)updateAddressText;

@end

@implementation WSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.parameters = WSParametersForNetworkType(WSNetworkTypeTestnet3);
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    UIViewController *controller = [[UIViewController alloc] init];
    controller.edgesForExtendedLayout = UIRectEdgeNone;

    self.textAddress = [[UITextField alloc] initWithFrame:CGRectMake(0, 10, 320, 40)];
    self.textAddress.textAlignment = NSTextAlignmentCenter;
    self.textAddress.font = [UIFont systemFontOfSize:13];
    self.textAddress.delegate = self;
    [controller.view addSubview:self.textAddress];
    
    UIButton *buttonConnect = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [buttonConnect setTitle:@"Connect" forState:UIControlStateNormal];
    buttonConnect.frame = CGRectMake(110, 60, 100, 40);
    [buttonConnect addTarget:self action:@selector(toggleConnection:) forControlEvents:UIControlEventTouchUpInside];
    [controller.view addSubview:buttonConnect];
    
    UIButton *buttonSync = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [buttonSync setTitle:@"Start download" forState:UIControlStateNormal];
    buttonSync.frame = CGRectMake(70, 110, 180, 40);
    [buttonSync addTarget:self action:@selector(toggleSync:) forControlEvents:UIControlEventTouchUpInside];
    [controller.view addSubview:buttonSync];
    
    self.labelBalance = [[UILabel alloc] initWithFrame:CGRectMake(110, 160, 100, 40)];
    self.labelBalance.textAlignment = NSTextAlignmentCenter;
    [controller.view addSubview:self.labelBalance];
    
    self.viewSync = [[UIView alloc] initWithFrame:CGRectMake(140, 210, 40, 40)];
    [controller.view addSubview:self.viewSync];

    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:controller];
    [self.window makeKeyAndVisible];

    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    self.chainPath = [cachePath stringByAppendingPathComponent:CHAIN_FILE];
    self.walletPath = [cachePath stringByAppendingPathComponent:WALLET_FILE];

    [self createWallet];
    [self printWallet];
    [self updateBalanceLabel];
    [self updateAddressText];
    [self createPeerGroup];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

#pragma mark Events

- (void)toggleConnection:(id)sender
{
    UIButton *button = sender;
    if (![self.peerGroup isStarted]) {
        if ([self.peerGroup startConnections]) {
            [button setTitle:@"Disconnect" forState:UIControlStateNormal];
        }
    }
    else {
        if ([self.peerGroup stopConnections]) {
            [button setTitle:@"Connect" forState:UIControlStateNormal];
        }
    }
}

- (void)toggleSync:(id)sender
{
    UIButton *button = sender;
    if (![self.peerGroup isDownloading]) {
        if ([self.peerGroup startDownloadWithDownloader:self.downloader]) {
            [button setTitle:@"Stop download" forState:UIControlStateNormal];
        }
    }
    else {
        [self.peerGroup stopDownload];
        [button setTitle:@"Start download" forState:UIControlStateNormal];
    }
}

- (void)stopSyncing
{
    [self.peerGroup stopDownload];
}

#pragma mark Helpers

- (void)createWallet
{
    WSSeed *seed = WSSeedMake(WALLET_MNEMONIC, WALLET_CREATION_TIME);

    self.wallet = [WSHDWallet loadFromPath:self.walletPath parameters:self.parameters seed:seed];
    if (!self.wallet) {
        self.wallet = [[WSHDWallet alloc] initWithParameters:self.parameters seed:seed];
    }

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:WSWalletDidRegisterTransactionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self.wallet saveToPath:self.walletPath];
        
        WSSignedTransaction *transaction = note.userInfo[WSWalletTransactionKey];
        DDLogInfo(@"Registered transaction: %@", transaction);
    }];
}

- (void)createPeerGroup
{
    [[NSNotificationCenter defaultCenter] addObserverForName:WSPeerGroupDidStartDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        self.viewSync.backgroundColor = [UIColor redColor];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:WSPeerGroupDidFinishDownloadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self updateAddressText];
        [self updateBalanceLabel];

        self.viewSync.backgroundColor = [UIColor greenColor];
    }];
    
    id<WSBlockStore> store = [[WSMemoryBlockStore alloc] initWithParameters:self.parameters];
    self.downloader = [[WSBlockChainDownloader alloc] initWithStore:store wallet:self.wallet];
//    self.downloader = [[WSBlockChainDownloader alloc] initWithStore:store fastCatchUpTimestamp:1404424800];
    
    self.peerGroup = [[WSPeerGroup alloc] initWithParameters:self.parameters];
    self.peerGroup.maxConnections = 10;
//    self.peerGroup.peerHosts = @[@"127.0.0.1"];
}

- (void)printWallet
{
    DDLogInfo(@"Balance: %llu", self.wallet.balance);
    DDLogInfo(@"Receive addresses: %@", self.wallet.allReceiveAddresses);
    DDLogInfo(@"Current receive address: %@", self.wallet.receiveAddress);
    DDLogInfo(@"Transactions: %@", self.wallet.allTransactions);
}

- (void)updateBalanceLabel
{
    DDLogInfo(@"Balance: %llu", [self.wallet balance]);
    self.labelBalance.text = [NSString stringWithFormat:@"%.8f", (double)[self.wallet balance] / 100000000ULL];
}

- (void)updateAddressText
{
    DDLogInfo(@"Receive address: %@", [self.wallet receiveAddress]);
    self.textAddress.text = [[self.wallet receiveAddress] encoded];
}

#pragma mark UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
