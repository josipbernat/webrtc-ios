//
//  NSString+Html.h
//  AppRTCDemo
//
//  Created by Josip Bernat on 08/05/14.
//  Copyright (c) 2014 Google. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Html)

#pragma mark - HTML
/**
 *  Removes HTML tags from string
 *
 *  @param base Original string
 *
 *  @return NSString object without HTML tags.
 */
- (NSString *)unHTMLifyString:(NSString *)base;

#pragma mark - Regex Matching
/**
 *  Match pattern to string.
 *
 *  @param pattern NSReNSRegularExpression pattern.
 *  @param string  String to match with
 *
 *  @return The first group of the first match, or nil if no match was found.
 */
+ (NSString *)firstMatch:(NSRegularExpression *)pattern
              withString:(NSString *)string;

#pragma mark - Audio Codec
/**
 *  Mangle origSDP to prefer the ISAC/16k audio codec.
 *
 *  @param origSDP origSDP.
 *
 *  @return ISAC/16k audio codec.
 */
+ (NSString *)preferISAC:(NSString *)origSDP;

@end
