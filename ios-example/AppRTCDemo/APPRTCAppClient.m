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

#import "APPRTCAppClient.h"
#import "GAEChannelClient.h"
#import "RTCICEServer.h"

@interface APPRTCAppClient ()

@property(nonatomic, copy) NSString *baseURL;
@property(nonatomic, strong) GAEChannelClient *gaeChannel;
@property(nonatomic, copy) NSString *postMessageUrl;
@property(nonatomic, copy) NSString *pcConfig;
@property(nonatomic, copy) NSString *token;

@property(nonatomic, assign) BOOL verboseLogging;

@property (nonatomic, strong) NSMutableSet *sendingSet;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation APPRTCAppClient

- (id)init {
    
    if (self = [super init]) {
        self.sendingSet = [[NSMutableSet alloc] init];
        self.operationQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

#pragma mark - Room Connection

- (void)connectToRoom:(NSURL *)url {
    
    NSString *path = [NSString stringWithFormat:@"https:%@", [url resourceSpecifier]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:path]];
    
    __weak id this = self;
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:self.operationQueue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                              
                               __strong APPRTCAppClient *strongThis = this;
                               [strongThis parseConnectionResponse:data requestURL:response.URL];
                           }];
}

#pragma mark - Parsing Room Connection Response

- (void)parseConnectionResponse:(NSData *)response requestURL:(NSURL *)requestURL{

    if (!response) { return; }
    
    NSString *roomHtml = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    if ([self isRoomFool:roomHtml]) {
        [self showMessage:@"Room is full"];
        return;
    }
    
    NSString *fullUrl = [requestURL absoluteString];
    NSRange queryRange = [fullUrl rangeOfString:@"?"];
    self.baseURL = [fullUrl substringToIndex:queryRange.location];
    
    self.token = [self findVariable:@"channelToken" inString:roomHtml strippingQuotes:YES];
    if (!self.token) { return; }
    
    NSString *roomKey = [self findVariable:@"roomKey" inString:roomHtml strippingQuotes:YES];
    NSString *me = [self findVariable:@"me" inString:roomHtml strippingQuotes:YES];
    if (!roomKey || !me) { return; }
    
    self.postMessageUrl = [NSString stringWithFormat:@"/message?r=%@&u=%@", roomKey, me];

    NSString *pcConfig = [self findVariable:@"pcConfig" inString:roomHtml strippingQuotes:NO];
    if (!pcConfig) { return; }
    
    NSString *turnServerUrl = [self findVariable:@"turnUrl" inString:roomHtml strippingQuotes:YES];
    if (turnServerUrl) {
        [self maybeLogMessage: [NSString stringWithFormat:@"TURN server request URL: %@", turnServerUrl]];
    }
    
    NSDictionary *json = [self decodeJsonObject:pcConfig];
    
    NSArray *servers = [json objectForKey:@"iceServers"];
    NSString *username = json[@"username"];
    
    NSMutableArray *ICEServers = [self serversFromResponse:servers username:username];
    [self updateICEServers:ICEServers withTurnServer:turnServerUrl];
}

- (BOOL)isRoomFool:(NSString *)response {

    NSParameterAssert(response);
    NSRegularExpression *fullRegex = [NSRegularExpression regularExpressionWithPattern:@"room is full"
                                                                                options:0
                                                                                 error:nil];

    return [fullRegex numberOfMatchesInString:response
                                      options:0
                                        range:NSMakeRange(0, [response length])];
}

- (NSDictionary *)decodeJsonObject:(NSString *)jsonObject {
    
    NSParameterAssert(jsonObject);
    
    NSError *error = nil;
    NSData *pcData = [jsonObject dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:pcData options:0 error:&error];
    NSAssert(!error, @"Unable to parse.  %@", error.localizedDescription);
    
    return json;
}

- (NSMutableArray *)serversFromResponse:(NSArray *)response username:(NSString *)username {
    
    NSParameterAssert(response);
    
    NSMutableArray *ICEServers = [NSMutableArray array];
    if (!username) { username = @""; }
    
    for (NSDictionary *server in response) {
        
        NSString *url = server[@"urls"];
        NSString *credential = server[@"credential"];
        
        if (!credential) { credential = @""; }
        
        [self maybeLogMessage: [NSString stringWithFormat:@"url [%@] - credential [%@]", url, credential]];
        RTCICEServer *ICEServer = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:url]
                                                           username:username
                                                           password:credential];
        [ICEServers addObject:ICEServer];
    }
    
    return ICEServers;
}

#pragma mark - Variable Search

- (NSString *)findVariable:(NSString *)name inString:(NSString *)string strippingQuotes:(BOOL)strippingQuotes {
    
    NSError* error = nil;
    NSString* pattern = [NSString stringWithFormat:@".*\n *var %@ = ([^\n]*);\n.*", name];
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                            options:0
                                                                              error:&error];
    
    NSAssert(!error, @"Unexpected error compiling regex: ", error.localizedDescription);
    
    NSRange fullRange = NSMakeRange(0, [string length]);
    NSArray *matches = [regexp matchesInString:string options:0 range:fullRange];
    
    if ([matches count] != 1) {
        
        [self showMessage:[NSString stringWithFormat:@"%d matches for %@ in %@", [matches count], name, string]];
        return nil;
    }
    
    NSRange matchRange = [matches[0] rangeAtIndex:1];
    NSString *value = [string substringWithRange:matchRange];
    
    if (strippingQuotes) {
        NSAssert([value length] > 2, @"Can't strip quotes from short string: [%@]", value);
        NSAssert(([value characterAtIndex:0] == '\'' && [value characterAtIndex:[value length] - 1] == '\''), @"Can't strip quotes from unquoted string: [%@]", value);
        value = [value substringWithRange:NSMakeRange(1, [value length] - 2)];
    }
    
    return value;
}

#pragma mark - Data Sending

- (void)sendData:(NSData *)data {

    [self maybeLogMessage:@"Send message"];
    [self.sendingSet addObject:[data copy]];
    
    [self requestQueueDrainInBackground];
}

- (void)requestQueueDrainInBackground {

    __weak id this = self;
    void (^blockOperation)() = ^(){
    
        __strong APPRTCAppClient *strongThis = this;
        if ([strongThis.postMessageUrl length] < 1) { return; }
        
        NSArray *sendQueue = [NSArray arrayWithArray:[strongThis.sendingSet allObjects]];
        for (NSData *data in sendQueue) {
            NSString *url = [NSString stringWithFormat:@"%@/%@", self.baseURL, self.postMessageUrl];
            [self sendData:data withUrl:url];
        }
        
        [strongThis.sendingSet minusSet:[NSSet setWithArray:sendQueue]];
    };
    
    if (![NSThread isMainThread]) {
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:blockOperation];
        [self.operationQueue addOperation:operation];
    }
    else {
        blockOperation();
    }
}

- (void)sendData:(NSData *)data withUrl:(NSString *)url {

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"POST";
    [request setHTTPBody:data];

    // Since sendData is called from background thread
    // We can create synchronus request
    NSError *sendingError = nil;
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:nil
                                      error:&sendingError];
    NSAssert(!sendingError, @"Error while sending data:%@ ", sendingError.localizedDescription);
}

- (void)showMessage:(NSString *)message {

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Unable to join"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)updateICEServers:(NSMutableArray *)ICEServers withTurnServer:(NSString *)turnServerUrl {
    
    if ([turnServerUrl length] < 1) {
        
        if ([self.ICEServerDelegate respondsToSelector:@selector(onICEServers:)]) {
            [self.ICEServerDelegate onICEServers:ICEServers];
        }
        
        self.gaeChannel =  [[GAEChannelClient alloc] initWithToken:self.token delegate:self.messageHandler];
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:turnServerUrl]];
    [request addValue:@"Mozilla/5.0" forHTTPHeaderField:@"user-agent"];
    [request addValue:@"https://apprtc.appspot.com" forHTTPHeaderField:@"origin"];
    
    // Since updateICEServers is called from background thread
    // We can create synchronus request
    NSError *sendingError = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:nil
                                                             error:&sendingError];

    NSDictionary *json = [self decodeJsonObject:[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]];
    
    NSString *username = json[@"username"];
    NSString *password = json[@"password"];
    NSArray *uris = json[@"uris"];
    
    for (NSString *turnServer in uris) {
        
        RTCICEServer *ICEServer = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:turnServer]
                                                           username:username
                                                           password:password];
        [ICEServers addObject:ICEServer];
    }
    
    if ([self.ICEServerDelegate respondsToSelector:@selector(onICEServers:)]) {
        [self.ICEServerDelegate onICEServers:ICEServers];
    }
    
    __weak id this = self;
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        __strong APPRTCAppClient *strongThis = this;
        if (strongThis.token && strongThis.token.length && strongThis.messageHandler ) {
            
            strongThis.gaeChannel = [[GAEChannelClient alloc] initWithToken:strongThis.token
                                                                   delegate:strongThis.messageHandler];
        }
    });
}

#pragma mark - Logging

- (void)maybeLogMessage:(NSString *)message {
    if (self.verboseLogging) {
        //NSLog(@"%@", message);
    }
}

@end
