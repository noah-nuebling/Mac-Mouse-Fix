//
// --------------------------------------------------------------------------
// ButtonInputParser.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonInputParser.h"
#import "Actions.h"
#import "ModifiedDrag.h"
#import "RemapUtility.h"
#import "Utility_HelperApp.h"
#import "ConfigFileInterface_HelperApp.h"
#import "GestureScrollSimulator.h"
#import "TransformationManager.h"

#pragma mark - Definition of private helper class `Button State`

// Instaces of this helper class describe the state of a single button on an input device
// The `_state` class variable of `ButtonInputParser` is a collection of `ButtonState` instances
@interface ButtonState : NSObject
@property NSTimer *holdTimer;
@property NSTimer *levelTimer;
@property int64_t clickLevel;
@property BOOL isZombified;
@property BOOL isPressed;
@end
@implementation ButtonState
@synthesize holdTimer, levelTimer, clickLevel, isZombified, isPressed;
@end

#pragma mark - Implementation of `ButtonInputParser`

@implementation ButtonInputParser

#pragma mark - Class vars

/*
 deviceID:
    buttonNumber:
        ButtonState instance
 */
static NSMutableDictionary *_state;

#pragma mark - Load

+ (void)load {
    _state = [NSMutableDictionary dictionary];
}

#pragma mark - Input parsing

+ (MFEventPassThroughEvaluation)parseInputWithButton:(NSNumber *)btn trigger:(MFButtonInputType)trigger inputDevice:(MFDevice *)device {
    
    // Declare passThroughEval (return value)
    MFEventPassThroughEvaluation passThroughEval;
    
    // Gather info from params
    NSNumber *devID = (__bridge NSNumber *)[device getID];
    ButtonState *bs = _state[devID][btn];
    
    // If no entry exists in _state for the incoming device and button, create one
    if (bs == nil) {
        if (_state[devID] == nil) {
            _state[devID] = [NSMutableDictionary dictionary];
        }
        _state[devID][btn] = [ButtonState alloc];
    }
    
    // Zombify all other buttons of current device which are pressed
    zombifyAllPressedButtonsOnDeviceExcept(devID, btn);
    
    if (trigger == kMFButtonInputTypeButtonDown) {
        
        // Mouse down
        
        // Check if zombified
        // Zombification should only occur during mouse down state, and then be removed with the consequent mouse up event
        if (bs.isZombified) {
            @throw [NSException exceptionWithName:@"ZombifiedDuringMouseUpStateException" reason:@"Button was found to be zombified when mouse down event occured." userInfo:nil];
        }
        
        // Update bs
        bs.isPressed = YES;
        bs.clickLevel += 1;
        
        // Send trigger
        passThroughEval = [TransformationManager handleButtonTriggerWithButton:btn triggerType:kMFActionTriggerTypeButtonDown clickLevel:@(bs.clickLevel) device:devID];
        
        // Restart Timers
        NSDictionary *timerInfo = @{
            @"devID": devID,
            @"btn": btn
        };
        [bs.holdTimer invalidate]; // Probs unnecessary cause it gets killed by mouse up anyways
        [bs.levelTimer invalidate];
        bs.holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                        target:self
                                                      selector:@selector(holdTimerCallback:)
                                                      userInfo:timerInfo
                                                       repeats:NO];
        bs.levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 //NSEvent.doubleClickInterval // The possible doubleClickIntervall
                         // values (configurable in System Preferences) are either too long or too short
                                                         target:self
                                                       selector:@selector(levelTimerCallback:)
                                                       userInfo:timerInfo
                                                        repeats:NO];
        
    } else {
        
        // Mouse up
        
        // Reset button state if zombified
        if (bs.isZombified) {
            resetStateWithDevice(devID, btn);
        }
        
        // Send trigger
        passThroughEval = [TransformationManager handleButtonTriggerWithButton:btn triggerType:kMFActionTriggerTypeButtonUp clickLevel:@(bs.clickLevel) device:devID];
        
        // Update bs
        bs.isPressed = NO;
        
        // Kill hold timer. This is only necessary if the hold timer zombifies I think.
        [bs.holdTimer invalidate];

    }
    
    // Return
    return passThroughEval;
}

#pragma mark - Timer callbacks

+ (void)holdTimerCallback:(NSTimer *)timer {
    NSNumber *devID;
    NSNumber *btn;
    NSNumber *lvl;
    timerCallbackHelper(timer.userInfo, &devID, &btn, &lvl);
    
    zombifyWithDevice(devID, btn);
    [TransformationManager handleButtonTriggerWithButton:btn triggerType:kMFActionTriggerTypeHoldTimerExpired clickLevel:lvl device:devID];
}

+ (void)levelTimerCallback:(NSTimer *)timer {
    NSNumber *devID;
    NSNumber *btn;
    NSNumber *lvl;
    timerCallbackHelper(timer.userInfo, &devID, &btn, &lvl);
    
    resetStateWithDevice(devID, btn);
    [TransformationManager handleButtonTriggerWithButton:btn triggerType:kMFActionTriggerTypeLevelTimerExpired clickLevel:lvl device:devID];
}
static void timerCallbackHelper(NSDictionary *info, NSNumber **devID, NSNumber **btn,NSNumber **lvl) {
    
    *devID = (NSNumber *)info[@"devID"];
    *btn = (NSNumber *)info[@"btn"];
    
    ButtonState *bs = _state[*devID][*btn];
    *lvl = @(bs.clickLevel);
}

#pragma mark - State control

#pragma mark Reset state

static void resetStateWithDevice(NSNumber *devID, NSNumber *btn) {
    
    ButtonState *bs = _state[devID][btn];
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    bs.clickLevel = 0;
    bs.isZombified = NO;
    
}
// Don't think we'll need this
static void resetAllState() {
    for (NSNumber *devKey in _state) {
        NSDictionary *dev = _state[devKey];
        for (NSNumber *btnKey in dev) {
            resetStateWithDevice(devKey, btnKey);
        }
    }
}

#pragma mark Zombify

// Zombification is kinda like a 'half reset'. Everything except click level is reset and when further input occurs, the button's state will be fully reset before the input is parsed
// This necessary to be able to use buttons as modifiers (e.g. pressing a button to modify the function of another button)
static void zombifyWithDevice(NSNumber *devID, NSNumber *btn) {
    
    ButtonState *bs = _state[devID][btn];
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    bs.isZombified = YES;
    
}

static void zombifyAllPressedButtonsOnDeviceExcept(NSNumber *devID, NSNumber *exceptedBtn) {
    for (NSNumber *btn in _state[devID]) {
        if ([btn isEqualToNumber:exceptedBtn]) continue;
        if (buttonIsPressed(devID, btn)) {
            zombifyWithDevice(devID, btn);
        }
    }
}

#pragma mark Interface

+ (void)handleHasHadDirectEffectWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    resetStateWithDevice(devID, btn);
}

+ (void)handleHasHadEffectAsModifierWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    zombifyWithDevice(devID, btn);
}

+ (NSDictionary *)getActiveButtonModifiersForDevice:(NSNumber *)devID {
    
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    // NSUInteger pressedButtons = NSEvent.pressedMouseButtons; // This only updates after we use it here, which led to problems, so were keeping track of mouse down state ourselves with `bs.isPressed`
    
    NSDictionary *devState = _state[devID];
    for (NSNumber *buttonNumber in devState) {
        ButtonState *bs = devState[buttonNumber];
        //BOOL isPressed = (pressedButtons & (1 << (buttonNumber.unsignedIntegerValue - 1))) != 0;
            // ^ Our button number value starts at 1 (lmb is 1) and pressedButtons starts at 0 (1 << 0 to check for lmb), so we have to do - 1 to make stuff work
        BOOL isPressed = bs.isPressed;
        BOOL isActive = isPressed && (bs.clickLevel != 0);
        
        if (isActive) {
            outDict[buttonNumber] = @(bs.clickLevel);
        }
    }
    return outDict;
}

#pragma mark - Helper

static BOOL buttonIsPressed(NSNumber *devID, NSNumber *btn) {
    ButtonState *bs = _state[devID][btn];
    return [bs.holdTimer isValid] || bs.isZombified;
}

@end
