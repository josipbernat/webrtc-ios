//
//  CSPeerConnectionHandler.m
//  AppRTCDemo
//
//  Created by Josip Bernat on 08/05/14.
//  Copyright (c) 2014 Google. All rights reserved.
//

#import "CSMediaChatClient.h"
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVMediaFormat.h>
#import "RTCMediaStream.h"
#import "RTCICECandidate.h"
#import "APPRTCAppClient.h"
#import "RTCMediaConstraints.h"
#import "RTCPair.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCPeerConnection.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"
#import "RTCSessionDescription.h"
#import "RTCSessionDescriptonDelegate.h"
#import "RTCPeerConnectionDelegate.h"
#import "NSString+Html.h"


@interface CSMediaChatClient () <ICEServerDelegate, GAEMessageHandler, RTCSessionDescriptonDelegate, RTCPeerConnectionDelegate>

@property (nonatomic, strong) APPRTCAppClient *client;
@property (nonatomic, strong) RTCPeerConnectionFactory *peerConnectionFactory;
@property (nonatomic, strong) RTCPeerConnection *peerConnection;
@property (nonatomic, strong) NSMutableArray *queuedRemoteCandidates;
@property (nonatomic, copy) CSBoolBlock loginCompletionHandler;

@end

@implementation CSMediaChatClient

#pragma mark - Shared Instance

+ (instancetype)sharedInstance {

    static CSMediaChatClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - Initialization

- (id)init {

    if (self = [super init]) {
        
        self.shouldReceiveAudio = YES;
        self.shouldReceiveVideo = YES;
        self.shouldUseFrontCamera = YES;
        
        [RTCPeerConnectionFactory initializeSSL];
        
        __weak id this = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          
                                                          __strong CSMediaChatClient *strongThis = this;
                                                          [strongThis disconnect];
                                                      }];
    }
    return self;
}

#pragma mark - Configuration

- (void)configureConnectionForServers:(NSArray *)servers {
    
    self.queuedRemoteCandidates = [[NSMutableArray alloc] init];
    self.peerConnectionFactory = [[RTCPeerConnectionFactory alloc] init];
    self.peerConnection = [self.peerConnectionFactory peerConnectionWithICEServers:servers
                                                                       constraints:[self mediaConstraints]
                                                                          delegate:self];
}

- (void)configureDevices {
    
    RTCMediaStream *mediaStream = [self.peerConnectionFactory mediaStreamWithLabel:@"ARDAMS"];
    [mediaStream addAudioTrack:[self.peerConnectionFactory audioTrackWithID:@"ARDAMSa0"]];
    
    NSString *cameraID = nil;
    if (!self.shouldUseFrontCamera) {
        AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        cameraID = [captureDevice localizedName];
    }
    else {
        for (AVCaptureDevice *captureDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] ) {
            if (captureDevice.position == AVCaptureDevicePositionFront) {
                cameraID = [captureDevice localizedName];
                break;
            }
        }
    }
    
    RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:cameraID];
    RTCVideoSource *videoSource = [self.peerConnectionFactory videoSourceWithCapturer:capturer constraints:nil];
    RTCVideoTrack *localVideoTrack = [self.peerConnectionFactory videoTrackWithID:@"ARDAMSv0" source:videoSource];
    
    if (localVideoTrack) {
        [mediaStream addVideoTrack:localVideoTrack];
    }

    [self.peerConnection addStream:mediaStream constraints:[self mediaConstraints]];
}

#pragma mark - RTCICECandidate Encoding

- (NSData *)encodeICECandidate:(RTCICECandidate *)candidate {

    NSDictionary *json = @{@"type": @"candidate",
                           @"label": @(candidate.sdpMLineIndex),
                           @"id": candidate.sdpMid,
                           @"candidate": candidate.sdp};
    
    return [NSJSONSerialization dataWithJSONObject:json
                                           options:0
                                             error:nil];
}

#pragma mark - Media Constraints

- (RTCMediaConstraints *)mediaConstraints {

    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:[self audioVideoPairs]
                                                 optionalConstraints:@[[[RTCPair alloc] initWithKey:@"internalSctpDataChannels" value:@"true"],
                                                                       [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]]];
}

- (NSArray *)audioVideoPairs {
    
    return @[[[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:(self.shouldReceiveAudio ? @"true" : @"false")],
             [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:(self.shouldReceiveVideo ? @"true" : @"false")]];
}

#pragma mark - Connection 

- (BOOL)connectToUrl:(NSURL *)url
   completionHandler:(void(^)(BOOL successfull))completion {

    if (self.client) { return NO; }

    self.loginCompletionHandler = completion;
    
    self.client = [[APPRTCAppClient alloc] init];
    self.client.ICEServerDelegate = self;
    self.client.messageHandler = self;
    [self.client connectToRoom:url];
    
    return YES;
}

- (void)disconnect {

    [self.client sendData:[@"{\"type\": \"bye\"}" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self.peerConnection close];
    self.peerConnection = nil;
    
    self.peerConnectionFactory = nil;
    self.client.ICEServerDelegate = nil;
    self.client.messageHandler = nil;
    self.client = nil;
    
    [RTCPeerConnectionFactory deinitializeSSL];
}

- (void)drainRemoteCandidates {

    for (RTCICECandidate *candidate in self.queuedRemoteCandidates) {
        [self.peerConnection addICECandidate:candidate];
    }
    
    [self.queuedRemoteCandidates removeAllObjects];
}

#pragma mark - RTCPeerConnectionDelegate

- (void)peerConnectionOnError:(RTCPeerConnection *)peerConnection {

}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged {

    NSLog(@"** signalingStateChanged: %d **", stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream {

    if (![stream.videoTracks count]) {
        NSLog(@"Expected at least 1 video stream");
        return;
    }
    
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self peerConnection:peerConnection
                     addedStream:stream];
        });
        return;
    }
    
    NSLog(@"** STREAM ADDED **");
    [[self videoView] renderVideoTrackInterface:[stream.videoTracks objectAtIndex:0]];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream {

    [stream removeVideoTrack:[stream.videoTracks objectAtIndex:0]];
}

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {

}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState {

    if (newState == RTCICEConnectionConnected &&
        self.loginCompletionHandler) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loginCompletionHandler(YES);
            self.loginCompletionHandler = nil;
        });
    }
    else if (newState == RTCICEConnectionFailed &&
             self.loginCompletionHandler) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loginCompletionHandler(NO);
            self.loginCompletionHandler = nil;
        });
    }
    else if (newState == RTCICEConnectionClosed) {
        NSLog(@"ICE connection closed");
        [self disconnect];
    }
    NSLog(@"** iceConnectionChanged: %d **", newState);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState {

    NSLog(@"** iceGatheringChanged: %d **", newState);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate {
    
    NSData *encodedCandidate = [self encodeICECandidate:candidate];
    if (encodedCandidate) {
        [self.client sendData:encodedCandidate];
    }
}

#pragma mark - ICEServerDelegate

- (void)onICEServers:(NSArray *)servers {

    [self configureConnectionForServers:servers];
    [self configureDevices];
}

#pragma mark - GAEMessageHandler

- (void)onOpen {

    [self.peerConnection createOfferWithDelegate:self
                                     constraints:[self mediaConstraints]];
}

- (void)onMessage:(NSString *)data {

    NSString *message = [data unHTMLifyString:data];
    
    NSError *error = nil;
    NSDictionary *objects = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:&error];
    if (error || !objects.count) {
        NSAssert(!error, @"%@", [NSString stringWithFormat:@"Error: %@", error.description]);
        NSAssert([objects count] > 0, @"Invalid JSON object");
        return;
    }
    
    NSString *value = objects[@"type"];
    if ([value compare:@"candidate"] == NSOrderedSame) {
    
        RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:objects[@"id"]
                                                                    index:[objects[@"label"] intValue]
                                                                      sdp:objects[@"candidate"]];
        if (self.queuedRemoteCandidates) {
            [self.queuedRemoteCandidates addObject:candidate];
        }
        else {
            [self.peerConnection addICECandidate:candidate];
        }
    }
    else if (([value compare:@"offer"] == NSOrderedSame) ||
             ([value compare:@"answer"] == NSOrderedSame)) {
    
        RTCSessionDescription *sessionDescription = [[RTCSessionDescription alloc] initWithType:value
                                                                                            sdp:[NSString preferISAC:objects[@"sdp"]]];
        
        [self.peerConnection setRemoteDescriptionWithDelegate:self
                                           sessionDescription:sessionDescription];
    }
    else if ([value compare:@"bye"] == NSOrderedSame) {
        [self disconnect];
    }
    else {
        NSAssert(NO, @"Invalid message: %@", data);
    }
}

- (void)onClose {

    [self disconnect];
}

- (void)onError:(int)code withDescription:(NSString *)description {

    NSLog(@"Error: %@", description);
    [self disconnect];
}

#pragma mark - RTCSessionDescriptonDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {

    if (error) {
        NSAssert(NO, error.description);
        return;
    }
    
    NSLog(@"Session state: %@", sdp.type);
    RTCSessionDescription * sessionDescription = [[RTCSessionDescription alloc] initWithType:sdp.type
                                                                                         sdp:[NSString preferISAC:sdp.description]];
    
    [self.peerConnection setLocalDescriptionWithDelegate:self
                                      sessionDescription:sessionDescription];
    
    NSDictionary *json = @{@"type": sdp.type,
                           @"sdp" : sdp.description };
    NSError *anError = nil;;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json
                                                   options:0
                                                     error:&anError];
    NSAssert(!anError, @"%@", [NSString stringWithFormat:@"Error: %@", error.description]);
    [self.client sendData:data];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error {

    if (error) {
        NSLog(@"%@", error.description);
//        NSAssert(NO, error.description);
        return;
    }
    
    if (self.peerConnection.remoteDescription) {
        [self drainRemoteCandidates];
    }
}

@end
