//
// --------------------------------------------------------------------------
// RemapsAnalyzer.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Device.h"
#import "WannabePrefixHeader.h"
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface RemapsAnalyzer : NSObject

#pragma mark General

+ (void)reload;

#pragma mark For SwitchMaster

+ (BOOL)modificationsModifyButtons:(NSDictionary *)modifications maxButton:(MFMouseButtonNumber)maxButton MF_SWIFT_HIDDEN;
+ (BOOL)__SWIFT_UNBRIDGED_modificationsModifyButtons:(id)modifications maxButton:(int)maxButton;

+ (BOOL)modificationsModifyScroll:(NSDictionary *)modifications MF_SWIFT_HIDDEN;
+ (BOOL)modificationsModifyPointing:(NSDictionary *)modifications MF_SWIFT_HIDDEN;
+ (BOOL)__SWIFT_UNBRIDGED_modificationsModifyScroll:(id)modifications;
+ (BOOL)__SWIFT_UNBRIDGED_modificationsModifyPointing:(id)modifications;

#pragma mark For Buttons.swift

///
/// Original declartions
///

+ (void)assessMappingLandscapeWithButton:(NSNumber *)button
                                   level:(NSNumber *)level
         modificationsActingOnThisButton:(NSDictionary *)remapsActingOnThisButton
                                  remaps:(NSDictionary *)remaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists MF_SWIFT_HIDDEN;

+ (BOOL)effectExistsForButton:(NSNumber *)button remaps:(NSDictionary *)remaps modificationsActingOnButton:(NSDictionary *)effectiveRemaps MF_SWIFT_HIDDEN;

+ (NSInteger)maxLevelForButton:(NSNumber *)button remaps:(NSDictionary *)remaps modificationsActingOnThisButton:(NSDictionary *)modificationsActingOnThisButton MF_SWIFT_HIDDEN;

///
/// Typeless declarations to prevent slow swift autobridging
///

+ (void)__SWIFT_UNBRIDGED_assessMappingLandscapeWithButton:(id)button
                                  level:(id)level
        modificationsActingOnThisButton:(id)remapsActingOnThisButton
                                 remaps:(id)remaps
                          thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                           thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                            greaterDoBe:(BOOL *)effectOfGreaterLevelExists;

+ (BOOL)__SWIFT_UNBRIDGED_effectExistsForButton:(id)button remaps:(id)remaps modificationsActingOnButton:(id)effectiveRemaps;

+ (NSInteger)__SWIFT_UNBRIDGED_maxLevelForButton:(id)button remaps:(id)remaps modificationsActingOnThisButton:(id)modificationsActingOnThisButton;

@end

NS_ASSUME_NONNULL_END
