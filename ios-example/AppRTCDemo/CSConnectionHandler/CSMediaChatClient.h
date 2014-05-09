//
//  CSPeerConnectionHandler.h
//  AppRTCDemo
//
//  Created by Josip Bernat on 08/05/14.
//  Copyright (c) 2014 Google. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSVideoRendererProtocol.h"

typedef void (^CSBoolBlock)(BOOL successfull);

@interface CSPeerConnectionHandler : NSObject 

@property (nonatomic, readwrite) BOOL shouldReceiveAudio;
@property (nonatomic, readwrite) BOOL shouldReceiveVideo;
@property (nonatomic, readwrite) BOOL shouldUseFrontCamera;
@property (nonatomic, strong) UIView <CSVideoRendererProtocol> *videoView;

#pragma mark - Connection

/**
 *  Connects peer to given URL.
 *
 *  @param url NSURL object containing valid HTTP address.
 *
 *  @return Boolean value determening if connection was successfull or not.
 */
- (BOOL)connectToUrl:(NSURL *)url
   completionHandler:(CSBoolBlock)completion;

/**
 *  Disconnects peer from current connection.
 */
- (void)disconnect;

@end
