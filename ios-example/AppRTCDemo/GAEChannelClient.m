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
 * Last updated by: Josip Bernat
 * May 2014
 *
 */

#import "GAEChannelClient.h"

@interface GAEChannelClient ()

@property(nonatomic, assign) id<GAEMessageHandler> delegate;
@property(nonatomic, strong) UIWebView *webView;

@end

@implementation GAEChannelClient

#pragma mark - Memory Management

- (void)dealloc {
    _webView.delegate = nil;
    [_webView stopLoading];
}

#pragma mark - Initialization

- (id)initWithToken:(NSString *)token delegate:(id<GAEMessageHandler>)delegate {
  
  if (self = [super init]) {
  
      self.webView = [[UIWebView alloc] init];
      self.webView.delegate = self;
      self.delegate = delegate;
      
      NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"ios_channel" ofType:@"html"];
      NSURL *htmlUrl = [NSURL fileURLWithPath:htmlPath];
      NSString *path = [NSString stringWithFormat:@"%@?token=%@", [htmlUrl absoluteString], token];

      [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:path]]];
  }
    
  return self;
}

#pragma mark - UIWebViewDelegate method

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {

    NSString *scheme = [request.URL scheme];
    if (![scheme isEqualToString:@"js-frame"]) {
        return YES;
    }
    NSString *resourceSpecifier = [request.URL resourceSpecifier];
    NSRange range = [resourceSpecifier rangeOfString:@":"];
    NSString *method = nil;
    NSString *message = nil;
    
    if (range.length == 0 && range.location == NSNotFound) {
        method = resourceSpecifier;
    }
    else {
        method = [resourceSpecifier substringToIndex:range.location];
        message = [resourceSpecifier substringFromIndex:range.location + 1];
    }
    
    if ([method isEqualToString:@"onopen"]) {
        
        if ([(NSObject *)_delegate respondsToSelector:@selector(onOpen)]) {
            [self.delegate onOpen];
        }
    }
    else if ([method isEqualToString:@"onmessage"]) {
        
        if ([(NSObject *)_delegate respondsToSelector:@selector(onMessage:)]) {
            [self.delegate onMessage:message];
        }
    }
    else if ([method isEqualToString:@"onclose"]) {
        
        if ([(NSObject *)_delegate respondsToSelector:@selector(onClose)]) {
            [self.delegate onClose];
        }
    }
    else if ([method isEqualToString:@"onerror"]) {
        // TODO(hughv): Get error.
        if ([(NSObject *)_delegate respondsToSelector:@selector(onError:withDescription:)]) {
            [self.delegate onError:-1
                   withDescription:message];
        }
    }
    else {
        NSAssert(NO, @"Invalid message sent from UIWebView: %@",
                 resourceSpecifier);
    }
    
    return YES;
}

@end
