//
//  VideoView.m
//
/*
 *
 * Last updated by: Josip Bernat
 * May 2014
 *
 */


#import "VideoView.h"
#import <QuartzCore/QuartzCore.h>
#import "RTCVideoRenderer.h"
#import "RTCVideoTrack.h"

@interface VideoView ()

@property (nonatomic, strong) RTCVideoTrack *track;
@property (nonatomic, strong) RTCVideoRenderer *renderer;

@property (nonatomic, strong) UIView<RTCVideoRenderView> *renderView;
@property (nonatomic, strong) UIImageView *placeholderView;
@property (nonatomic, strong) UILabel *loadingLabel;

@end

@implementation VideoView

#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame {
    
    if (self = [super initWithFrame:frame]) {
        setupRenderer(self);
        [self setupInterface];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    if (self = [super initWithCoder:aDecoder]) {
        setupRenderer(self);
        [self setupInterface];
    }
    return self;
}

#pragma mark - Interface Setup

- (void)setupInterface {
    
    [[self layer] setMasksToBounds:YES];
    [self setBackgroundColor:[UIColor darkGrayColor]];
    
    self.placeholderView = [[UIImageView alloc] initWithFrame:self.renderView.frame];
    [self.placeholderView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:self.placeholderView];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self
                                                     attribute:NSLayoutAttributeCenterX
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self.placeholderView
                                                     attribute:NSLayoutAttributeCenterX
                                                    multiplier:1
                                                      constant:0]];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self
                                                     attribute:NSLayoutAttributeCenterY
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self.placeholderView
                                                     attribute:NSLayoutAttributeCenterY
                                                    multiplier:1
                                                      constant:0]];
    
    self.loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(32,
                                                                  32,
                                                                  CGRectGetWidth(self.frame) - 32 * 2,
                                                                  [UIFont systemFontOfSize:18.0f].lineHeight)];
    self.loadingLabel.center = CGPointMake(CGRectGetWidth(self.frame) / 2,
                                           CGRectGetHeight(self.frame) / 2);
    self.loadingLabel.textColor = [UIColor whiteColor];
    self.loadingLabel.textAlignment = NSTextAlignmentCenter;
    self.loadingLabel.backgroundColor = [UIColor darkGrayColor];
    self.loadingLabel.font = [UIFont systemFontOfSize:18.0f];
    self.loadingLabel.text = @"Loading... (tap to dismiss)";
    [self addSubview:self.loadingLabel];
    
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(handleTap:)];
    [self addGestureRecognizer:recognizer];
}

#pragma mark - Renderer Setup

static void setupRenderer(VideoView *self) {
    
    self.renderView = [RTCVideoRenderer newRenderViewWithFrame:CGRectMake(200, 100, 240, 180)];
    [self.renderView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:self.renderView];
    
    NSDictionary *views = @{@"renderView": self.renderView};
    NSDictionary *metrics = @{@"VIDEO_WIDTH" : @(CGRectGetWidth(self.frame)),
                              @"VIDEO_HEIGHT" : @(CGRectGetHeight(self.frame))};
    
    [self.renderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[renderView(VIDEO_WIDTH)]"
                                                                            options:0
                                                                            metrics:metrics
                                                                              views:views]];
    
    [self.renderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[renderView(VIDEO_HEIGHT)]"
                                                                            options:0 metrics:metrics
                                                                              views:views]];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self
                                                     attribute:NSLayoutAttributeCenterX
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self.renderView
                                                     attribute:NSLayoutAttributeCenterX
                                                    multiplier:1
                                                      constant:0]];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self
                                                     attribute:NSLayoutAttributeCenterY
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self.renderView
                                                     attribute:NSLayoutAttributeCenterY
                                                    multiplier:1
                                                      constant:0]];
}

#pragma mark - UITapGestureRecognizer Selector

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    
    if (self.loadingLabel.superview) {
        [self.loadingLabel removeFromSuperview];
    }
}

#pragma mark - Placeholder Image

-(UIImage *)placeholderImage {
    return [[self placeholderView] image];
}

- (void)setPlaceholderImage:(UIImage *)placeholderImage {
    [[self placeholderView] setImage:placeholderImage];
}

#pragma mark - Video Orientation

- (void)setVideoOrientation:(UIInterfaceOrientation)videoOrientation {
    
//    if (_videoOrientation == videoOrientation) { return; }
    
    _videoOrientation = videoOrientation;
    
    CGFloat angle = 0.0;
    switch (videoOrientation) {
        case UIInterfaceOrientationPortrait:
            angle = M_PI;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            angle = -M_PI_2;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            angle = M_PI;
            break;
        case UIInterfaceOrientationLandscapeRight:
            angle = 0;
            break;
    }
    
    // The video comes in mirrored. That is fine for the local video, but the remote video should be put back to original
    CGAffineTransform xform = CGAffineTransformMakeScale(1, 1);
    xform = CGAffineTransformRotate(xform, angle);
    [[self renderView] setTransform:xform];
}

#pragma mark - Controlls

- (void)pause:(id)sender {
    [_renderer stop];
}

- (void)resume:(id)sender {
    [_renderer start];
}

- (void)stop:(id)sender {
    [_track removeRenderer:_renderer];
    [_renderer stop];
}

#pragma mark - CSVideoRendererProtocol

- (void)renderVideoTrackInterface:(RTCVideoTrack *)videoTrack {
    [self stop:nil];
    
    _track = videoTrack;
    
    if (_track) {
        if (!_renderer) {
            _renderer = [[RTCVideoRenderer alloc] initWithRenderView:[self renderView]];
        }
        [_track addRenderer:_renderer];
        [self resume:self];
    }
    
    [self setVideoOrientation:UIInterfaceOrientationPortrait];
}

@end
