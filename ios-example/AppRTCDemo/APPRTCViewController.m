/*
 * libjingle
 * Copyright 2013, Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 *
 * Last updated by: Gregg Ganley
 * Nov 2013
 *
 */

#import "APPRTCViewController.h"
#import "CSMediaChatClient.h"
#import "APPRTCAppDelegate.h"
#import "RTCVideoRenderer.h"
#import "VideoView.h"
#import <QuartzCore/QuartzCore.h>

@interface APPRTCViewController ()

@property (weak, nonatomic) IBOutlet UIButton *disconnectButton;
@property (nonatomic, strong) CSMediaChatClient *connectionHandler;
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;

@end

@implementation APPRTCViewController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        
        self.connectionHandler = [CSMediaChatClient new];
    }
    return self;
}

- (void)viewDidLoad {
 
    [super viewDidLoad];
  
    self.textField.delegate = self;
    
    self.textField.keyboardType = UIKeyboardTypeNumberPad;
    
    UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    numberToolbar.barStyle = UIBarStyleBlackTranslucent;
    numberToolbar.items = [NSArray arrayWithObjects:
                           [[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(cancelNumberPad)],
                           [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                           [[UIBarButtonItem alloc]initWithTitle:@"Apply" style:UIBarButtonItemStyleDone target:self action:@selector(doneWithNumberPad)],
                            nil];
    [numberToolbar sizeToFit];
    self.textField.inputAccessoryView = numberToolbar;
    
    if ([self connectedToInternet] == NO) {
        NSLog(@"NO INTERNET connection!");
    }
}

-(void)cancelNumberPad{
    [self.textField resignFirstResponder];
    self.textField.text = @"";
}

- (BOOL) connectedToInternet
{
    NSString *URLString = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.google.com"]];
    return ( URLString != NULL ) ? YES : NO;
}

-(void)doneWithNumberPad {
    //**
    //** this overides the textFieldDidEndEditing delegate below
    NSString *numberFromTheKeyboard = self.textField.text;
    [self.textField resignFirstResponder];
    
    NSString *room = numberFromTheKeyboard;
    if ([room length] == 0) {
        return;
    }
    
    [self setVideoCapturer];
    
    [self.indicatorView startAnimating];
    
    __weak id this = self;
    [self.connectionHandler connectToUrl:[NSURL URLWithString:[NSString stringWithFormat:@"apprtc://apprtc.appspot.com/?r=%@", room]]
                       completionHandler:^(BOOL successfull) {
                           
                           __strong APPRTCViewController *strongThis = this;
                           [strongThis.indicatorView stopAnimating];
                       }];
}


- (IBAction)disconnectPressed:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Disconnect device?"
                                                    message:@"Do you want to end session?"
                                                   delegate:self
                                          cancelButtonTitle:@"No"
                                          otherButtonTitles:@"Yes", nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {

        [self.connectionHandler disconnect];
        
        self.disconnectButton.hidden = YES;
        self.videoView.hidden = YES;
    }
}


- (void)displayText:(NSString *)text {
  dispatch_async(dispatch_get_main_queue(), ^(void) {
    NSString *output =
        [NSString stringWithFormat:@"%@\n%@", self.textOutput.text, text];
    self.textOutput.text = output;
  });
}

- (void)resetUI {
  self.textField.text = nil;
  self.textField.hidden = NO;
  self.textInstructions.hidden = NO;
  self.textOutput.hidden = YES;
  self.textOutput.text = nil;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    [textField resignFirstResponder];
    return YES;
}

- (void)setVideoCapturer {

    if (self.videoView) {
        self.videoView.hidden = NO;
        return;
    }
    
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-80);
    _videoView = [[VideoView alloc] initWithFrame:frame];
    [self.view addSubview:_videoView];
    
    self.indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.indicatorView.center = CGPointMake(CGRectGetWidth(self.videoView.frame) / 2,
                                            CGRectGetHeight(self.videoView.frame) / 2);
    self.indicatorView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                           UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    self.indicatorView.hidesWhenStopped = YES;
    [self.videoView addSubview:self.indicatorView];
    
    self.connectionHandler.videoView = self.videoView;
}


@end
