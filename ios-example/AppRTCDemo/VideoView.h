//
//  VideoView.h
//
/*
 *
 * Last updated by: Josip Bernat
 * May 2014
 *
 */

#import <UIKit/UIKit.h>
#import "CSVideoRendererProtocol.h"

@interface VideoView : UIView <CSVideoRendererProtocol>

@property (nonatomic, readwrite) UIInterfaceOrientation videoOrientation;
@property (nonatomic, strong) UIImage *placeholderImage;
@property (nonatomic, readonly) BOOL isRemote;

#pragma mark - Controlls
- (void)pause:(id)sender;
- (void)resume:(id)sender;
- (void)stop:(id)sender;

@end
