//
//  AppDelegate.m
//  GreatExchange
//
//  Created by Christine Abernathy on 6/27/13.
//  Copyright (c) 2013 Elidora LLC. All rights reserved.
//

#import "AppDelegate.h"

// Defining the constants
NSString *const kServiceType = @"rw-cardshare";
NSString *const DataReceivedNotification =
@"com.razeware.apps.CardShare:DataReceivedNotification";
NSString *const PeerConnectionAcceptedNotification =
@"com.razeware.apps.CardShare:PeerConnectionAcceptedNotification";
BOOL const kProgrammaticDiscovery = NO;

// Invitation handler definition
typedef void(^InvitationHandler)(BOOL accept, MCSession *session);

@interface AppDelegate ()
<MCSessionDelegate,
MCNearbyServiceAdvertiserDelegate,
UIAlertViewDelegate>

@property (strong, nonatomic) MCAdvertiserAssistant *advertiserAssistant;
@property (strong, nonatomic) MCNearbyServiceAdvertiser *advertiser;
@property (strong, nonatomic) InvitationHandler handler;
@property (assign, nonatomic) BOOL didSendDataToPeers; // Challenge 2
@property (strong, nonatomic) NSMutableArray *dataReceievedFromPeers; // Challenge 2
@property (strong, nonatomic) NSDictionary *discoveryInfo; // Challenge 1

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    // Set appearance info
    [[UITabBar appearance] setBarTintColor:[self mainColor]];
    
    [[UINavigationBar appearance] setBarStyle:UIBarStyleBlackOpaque];
    [[UINavigationBar appearance] setBarTintColor:[self mainColor]];
    
    [[UIToolbar appearance] setBarStyle:UIBarStyleBlackOpaque];
    [[UIToolbar appearance] setBarTintColor:[self mainColor]];
    
    // Initialize properties
    self.cards = [@[] mutableCopy];
    
    // Initialize any stored data
    self.myCard = nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"myCard"]) {
        NSData *myCardData = [defaults objectForKey:@"myCard"];
        self.myCard = (Card *)[NSKeyedUnarchiver unarchiveObjectWithData:myCardData];
    }
    self.otherCards = [@[] mutableCopy];
    if ([defaults objectForKey:@"otherCards"]) {
        NSData *otherCardsData = [defaults objectForKey:@"otherCards"];
        self.otherCards = (NSMutableArray *)[NSKeyedUnarchiver unarchiveObjectWithData:otherCardsData];
    }
    
    // Challenge 1
    self.discoveryInfo = @{@"code" : @"WWDC"};
    
    // Set up peer connectivity
    [self setUpMultiPeerConnectivity];
    
    return YES;
}

#pragma mark - MCNearbyServiceAdvertiserDelegate delegate methods
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession *))invitationHandler
{
    // Save the invitation handler for later use
    self.handler = invitationHandler;
    // Show the user an alert view so they can decide to accept
    // or reject an invitation
    [[[UIAlertView alloc] initWithTitle:@"Invitation"
                                message:[NSString stringWithFormat:@"%@ wants to connect",
                                         peerID.displayName]
                               delegate:self
                      cancelButtonTitle:@"Nope"
                      otherButtonTitles:@"Sure", nil] show];
}

#pragma mark - AlertView delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Get the user decision
    BOOL accept = (buttonIndex == alertView.cancelButtonIndex) ? NO : YES;
    
    // Call the invitation handler
    self.handler(accept, self.session);
}

#pragma mark - MCSessionDelegate delegate methods
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    if (state == MCSessionStateConnected && self.session) {
        // For programmatic discovery, send a notification to the custom browser
        // that an invitation was accepted.
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PeerConnectionAcceptedNotification
         object:nil
         userInfo:@{
                    @"peer": peerID,
                    @"accept" : @YES
                    }];
    } else if (state == MCSessionStateNotConnected && self.session) {
        // For programmatic discovery, send a notification to the custom browser
        // that an invitation was declined.
        // Send only if the peers are not yet connected
        if (![self.session.connectedPeers containsObject:peerID]) {
            [[NSNotificationCenter defaultCenter]
             postNotificationName:PeerConnectionAcceptedNotification
             object:nil
             userInfo:@{
                        @"peer": peerID,
                        @"accept" : @NO
                        }];
        }
        // Challenge 2
        // Check if need to disconnect
        [self disconnectIfNeeded];
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{    
    // Get the data to be stored
    Card *card = (Card *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    // Add info to the cards array
    [self.cards addObject:card];
    
    // Trigger a notification that data was received
    [[NSNotificationCenter defaultCenter] postNotificationName:DataReceivedNotification object:nil];
    
    // Challenge 2
    // Update list of peers that data has been received from
    [self.dataReceievedFromPeers addObject:peerID];
    // Check if need to disconnect
    [self disconnectIfNeeded];
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
}

#pragma mark - Helper methods
- (UIColor *)mainColor
{
    return [UIColor colorWithRed:28/255.0f green:171/255.0f blue:116/255.0f alpha:1.0f];
}

-(void)sendCardToPeer
{
    // Set flag that data sent out
    self.didSendDataToPeers = YES; // Challenge 2
    // Send data to all connected peers
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.myCard];
    NSError *error;
    [self.session sendData:data
                   toPeers:[self.session connectedPeers]
                  withMode:MCSessionSendDataReliable
                     error:&error];    
}

/*
 * Implement the setter for the user's card
 * so as to set the value in storage as well.
 */
- (void)setMyCard:(Card *)aCard
{
    if (aCard != _myCard) {
        _myCard = aCard;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        // Create an NSData representation
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:aCard];
        [defaults setObject:data forKey:@"myCard"];
        [defaults synchronize];
    }
}

- (void)addToOtherCardsList:(Card *)card
{
    [self.otherCards addObject:card];
    // Update stored value
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.otherCards];
    [defaults setObject:data forKey:@"otherCards"];
    [defaults synchronize];
}

- (void) removeCardFromExchangeList:(Card *)card
{
    NSMutableSet *cardsSet = [NSMutableSet setWithArray:self.cards];
    [cardsSet removeObject:card];
    self.cards = [[cardsSet allObjects] mutableCopy];
}

- (void) setUpMultiPeerConnectivity {
    // Set up a peer
    NSString *peerName =
    self.myCard.firstName ? self.myCard.firstName :
    [[UIDevice currentDevice] name];
    self.peerId = [[MCPeerID alloc] initWithDisplayName:peerName];
    
    // Set up a session
    self.session = [[MCSession alloc] initWithPeer:self.peerId
                                  securityIdentity:nil
                              encryptionPreference:MCEncryptionNone];
    // Set the session delegate
    self.session.delegate = self;
    
    // Set up an advertiser
    // Challenge 1, add discoveryInfo
    if (kProgrammaticDiscovery) {
        // Set it up programmatically
        self.advertiser =
        [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.peerId
                                          discoveryInfo:self.discoveryInfo
                                            serviceType:kServiceType];
        self.advertiser.delegate = self;
        // Start advertising
        [self.advertiser startAdvertisingPeer];
    } else {
        // Set it up using the convenience class
        self.advertiserAssistant =
        [[MCAdvertiserAssistant alloc] initWithServiceType:kServiceType
                                             discoveryInfo:self.discoveryInfo
                                                   session:self.session];
        // Start advertising
        [self.advertiserAssistant start];
    }
    
    // Challenge 2
    // Initialize whether this is a browser
    self.didSendDataToPeers = NO;
    // Initialize list of peers data has been received from
    self.dataReceievedFromPeers = [@[] mutableCopy];
}

// Challenge 2
- (void) cleanUpMultiPeerConnectivity {
    // Disconnect session
    [self.session disconnect];
    // Cleanup session delegate
    self.session.delegate = nil;
    // Cleanup advertiser
    if (kProgrammaticDiscovery) {
        [self.advertiser stopAdvertisingPeer];
        self.advertiser.delegate = nil;
    } else {
        [self.advertiserAssistant stop];
    }
    // Cleanup the session
    self.session = nil;
    // Cleanup peer info
    self.peerId = nil;
    // Reset list of peers data has been received from
    self.dataReceievedFromPeers = [@[] mutableCopy];
    // Reset browser flag
    self.didSendDataToPeers = NO;
}

// Challenge 2
- (void) disconnectIfNeeded {
    // Check if data was already sent out to at least one peer
    if (self.didSendDataToPeers) {
        // Initialize whether the session should disconnect
        BOOL shouldDisconnect = YES;
        // Loop through all currently connected peers
        for (MCPeerID *peer in self.session.connectedPeers) {
            // Check if data has not been received from this peer
            if (![self.dataReceievedFromPeers containsObject:peer]) {
                shouldDisconnect = NO;
                break;
            }
        }
        // If flag still true
        if (shouldDisconnect) {
            // Clean up peer connectivity
            [self cleanUpMultiPeerConnectivity];
            // Set up peer connectivity
            [self setUpMultiPeerConnectivity];
        }
    }
}

// Challenge 1
- (BOOL) isMatchingDiscoveryInfo:(NSDictionary *) info {
    if (nil == self.discoveryInfo) {
        // Not checking incoming info
        return YES;
    } else {
        // Check if dictionary keys and objects
        // match (case sensitive)
        return [info isEqualToDictionary:self.discoveryInfo];
    }
}

@end
