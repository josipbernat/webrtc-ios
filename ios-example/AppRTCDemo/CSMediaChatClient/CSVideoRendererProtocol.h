//
//  CSVideoRendererProtocol.h
//  AppRTCDemo
//
//  Created by Josip Bernat on 08/05/14.
//  Copyright (c) 2014 Google. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RTCVideoTrack;

@protocol CSVideoRendererProtocol <NSObject>

#pragma mark - Rendered Interface
- (void)renderVideoTrackInterface:(RTCVideoTrack *)track;

@end
