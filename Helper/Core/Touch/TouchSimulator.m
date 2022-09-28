//
// --------------------------------------------------------------------------
// TouchSimulator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// Credits:
/// I originally found the code for the `postNavigationSwipeWithDirection:` function in Alexei Baboulevitch's SensibleSideButtons project under the name `SBFFakeSwipe:`. SensibleSideButtons was itself heavily based on natevw's macOS touch reverse engineering work ("CalfTrail Touch") for his app Sesamouse from wayy back in the day. Nate's work was the basis for all all of this. Thanks Nate! :)
///
/// On licenses:
/// SensibleSideButtons is published under the GPL license, which requires derivative work to be published under the same or equivalent license. However we're not using any code from SensibleSideButtons any more, since we rewrote that code based on our deeper understanding of the "CalTrail Touch" code. So therefore it should be fine that we're publishing MMF under the "MMF License" now.

/// Notes:
/// 
/// Between TouchSimulator.m and GestureScrollSimulator, we have all interesting touch input covered. Except a Force Touch, but we have the kMFSHLookUp symbolic hotkey which works almost as well.
///     Edit: Actually using LookUp by any other method except force touch is broken in Safari and Mail since few versions.

#import "TouchSimulator.h"
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Scroll.h"
#import "SharedUtility.h"
#import <Foundation/Foundation.h>
#import "HelperUtility.h"

@implementation TouchSimulator

static NSArray *_nullArray;
static NSMutableDictionary *_swipeInfo;

/// This function allows you to go back and forward in apps like Safari.
///
/// Navigation swipe events are actually quite complex and seem to be similar to dock swipes internally (They seem to also have an origin offset and other similar fields from what i've seen)
/// However, this simple function replicates all of their interesting functionality, so I didn't bother reverse engineering them more thoroughly.
/// Navigation swipes are naturally produced by three finger swipes, but only if you set "System Preferences > Trackpad > More Gestures > Swipe between pages" to "Swipe with three fingers" or to "Swipe with two or three fingers"
+ (void)postNavigationSwipeEventWithDirection:(IOHIDSwipeMask)dir {
    
    CGEventRef e = CGEventCreate(NULL);
    CGEventSetIntegerValueField(e, 55, NSEventTypeGesture);
    CGEventSetIntegerValueField(e, 110, kIOHIDEventTypeNavigationSwipe);
    CGEventSetIntegerValueField(e, 132, kIOHIDEventPhaseBegan);
    CGEventSetIntegerValueField(e, 115, dir);
    
    CGEventPost(kCGHIDEventTap, e);
    CGEventSetIntegerValueField(e, 115, kIOHIDSwipeNone);
    CGEventSetIntegerValueField(e, 132, kIOHIDEventPhaseEnded);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postSmartZoomEvent {
    
    CGEventRef e = CGEventCreate(NULL);
    CGEventSetIntegerValueField(e, 55, 29); /// NSEventTypeGesture
    CGEventSetIntegerValueField(e, 110, 22); /// kIOHIDEventTypeZoomToggle
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postRotationEventWithRotation:(double)rotation phase:(IOHIDEventPhaseBits)phase {
    
    CGEventRef e = CGEventCreate(NULL);
    /// Could also use CGEventSetType() here
    CGEventSetIntegerValueField(e, 55, 29); /// NSEventTypeGesture
    CGEventSetIntegerValueField(e, 110, 5); /// kIOHIDEventTypeRotation
    CGEventSetDoubleValueField(e, 114, rotation);
    CGEventSetIntegerValueField(e, 132, phase);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postMagnificationEventWithMagnification:(double)magnification phase:(IOHIDEventPhaseBits)phase {
    
    /// Using undocumented CGEventFields found through Calftrail TouchExtractor and through analyzing Calftrail TouchSynthesis to create a working magnification event from scratch
    ///  This was the the start of this whole touch simulation thing!
    
    /// Debug
    
    DDLogDebug(@"Posting magnification event with amount: %f, phase: %d", magnification, phase);
    
    /// Create and post event
    
    CGEventRef event = CGEventCreate(NULL);
    CGEventSetType(event, 29); /// 29 -> NSEventTypeGesture
    CGEventSetIntegerValueField(event, 110, 8); /// 8 -> kIOHIDEventTypeZoom
    CGEventSetIntegerValueField(event, 132, phase);
    CGEventSetDoubleValueField(event, 113, magnification);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

+ (void)postDockSwipeEventWithDelta:(double)d type:(MFDockSwipeType)type phase:(IOHIDEventPhaseBits)phase {
    
    /// State
    
    static double _dockSwipeOriginOffset = 0.0;
    static double _dockSwipeLastDelta = 0.0;
    static NSTimer *_doubleSendTimer;
    static NSTimer *_tripleSendTimer;
    
    /// Constants
    
    int valFor41 = 33231;
    int vertInvert = 1;
    
    /// Update originOffset
    
    if (phase == kIOHIDEventPhaseBegan) {
        _dockSwipeOriginOffset = d;
    } else if (phase == kIOHIDEventPhaseChanged){
        if (d == 0) {
            return;
        }
        _dockSwipeOriginOffset += d;
    }
    
    /// Debug
    
    static CFTimeInterval _dockSwipeLastTimeStamp = 0.0;
    CFTimeInterval ts = CACurrentMediaTime();
//    CFTimeInterval timeDiff = ts - _dockSwipeLastTimeStamp;
    _dockSwipeLastTimeStamp = ts;
    DDLogDebug(@"\nSending dockSwipe with delta: %@,"
//               @"lastDelta: %@, "
//               @"prevOriginOffset: %@ "
//               @"type: %@, "
               @"phase: %@, "
//               @"timeSinceLastEvent: %@"
               ,@(d*600)
//               ,@(_dockSwipeLastDelta)
//               ,@(_dockSwipeOriginOffset)
//               ,@(type)
               ,@(phase)
//               ,@(timeDiff)
   );
    
    /// Override end phase with canceled phase
    
    if (phase == kIOHIDEventPhaseEnded) {
        if ([SharedUtility signOf:_dockSwipeLastDelta] == [SharedUtility signOf:_dockSwipeOriginOffset]) {
            phase = kIOHIDEventPhaseEnded;
        } else {
            phase = kIOHIDEventPhaseCancelled;
        }
    }
    
    ///
    /// Create events
    ///
    
    /// Create type 29 (NSEventTypeGesture) event
    
    CGEventRef e29 = CGEventCreate(NULL);
    CGEventSetDoubleValueField(e29, 55, NSEventTypeGesture); /// Set event type
    CGEventSetDoubleValueField(e29, 41, valFor41); /// No idea what this does but it might help. // TODO: Why?
    
    /// Create type 30 event
    
    CGEventRef e30 = CGEventCreate(NULL);
    
    CGEventSetDoubleValueField(e30, 55,  NSEventTypeMagnify); /// Set event type (idk why it's magnify but it is...)
    CGEventSetDoubleValueField(e30, 110, kIOHIDEventTypeDockSwipe); /// Set subtype
    CGEventSetDoubleValueField(e30, 132, phase);
    CGEventSetDoubleValueField(e30, 134, phase); /// Not sure if necessary

    CGEventSetDoubleValueField(e30, 124, _dockSwipeOriginOffset); /// Origin offset
    Float32 ofsFloat32 = (Float32)_dockSwipeOriginOffset;
    uint32_t ofsInt32; /// Has to be `uint32_t` not `int32_t`!
    memcpy(&ofsInt32, &ofsFloat32, sizeof(ofsFloat32));
    int64_t ofsInt64 = (int64_t)ofsInt32;
    CGEventSetIntegerValueField(e30, 135, ofsInt64); /// Weird ass encoded version of origin offset. It's a 64 bit integer containing the bits for a 32 bit float. No idea why this is necessary, but it is.
    
    CGEventSetDoubleValueField(e30, 41, valFor41); /// This mighttt help not sure what it do
    
    /// The values below are probably an encoded version of the values in MFDockSwipeType. We could probably somehow convert that and put it in here instead of assigning these weird constants
    
    double weirdTypeOrSum = -1;
    if (type == kMFDockSwipeTypeHorizontal) {
        weirdTypeOrSum = 1.401298464324817e-45;
    } else if (type == kMFDockSwipeTypeVertical) {
        weirdTypeOrSum = 2.802596928649634e-45;
    } else if (type == kMFDockSwipeTypePinch) {
        weirdTypeOrSum = 4.203895392974451e-45;
    } else {
        assert(false);
    }
    
    CGEventSetDoubleValueField(e30, 119, weirdTypeOrSum);
    CGEventSetDoubleValueField(e30, 139, weirdTypeOrSum);  /// Probs not necessary
    
    CGEventSetDoubleValueField(e30, 123, type); /// Horizontal or vertical
    CGEventSetDoubleValueField(e30, 165, type); /// Horizontal or vertical // Probs not necessary
    
    CGEventSetDoubleValueField(e30, 136, vertInvert); /// Vertical invert
    
    if (phase == kIOHIDEventPhaseEnded || phase == kIOHIDEventPhaseCancelled) {
        
        /// Set Exit Speed
        ///     Note: `*100` cause that's closer to how the real values look, but it doesn't make a difference
        CGEventSetDoubleValueField(e30, 129, _dockSwipeLastDelta*100); /// 'Exit speed'
        CGEventSetDoubleValueField(e30, 130, _dockSwipeLastDelta*100); /// Probs not necessary
        
        /// Debug
        ///     Debugging of stuck-bug. When the stuck bug occurs, This always seems to be called and in the appropriate order (The fake dockSwipe with the end-phase is always called after all other phases).
        ///     Random observation: I just got it stuck with just the trackpad! Right after getting it stuck with mouse.
        ///     This makes me think the bug is about timing / how slow the events are sent, and not in which order the events are sent or with on which thread the events are sent as I suspected initially.
        ///     Another hint towards this is, that the stuck-bug seems to occur more, the slower and more stuttery the UI is (the longer the computer has been running)
        /// I fixed the stuck-bug now. (See the comment with "This fixed the stuck-bug!" in ModifiedDrag.m) But I still don't know what caused it exactly.
//        DDLogDebug(@"EXIT SPEED: %f, originOffset: %f, phase: %hu", _dockSwipeLastDelta, _dockSwipeOriginOffset, phase);

    }
    
    ///
    /// Send events
    ///
    
    CGEventPost(kCGSessionEventTap, e30); /// Not sure if order matters
    CGEventPost(kCGSessionEventTap, e29);
    
    if (phase == kIOHIDEventPhaseEnded || phase == kIOHIDEventPhaseCancelled) {
        
        /// Double-send events
        /// Notes:
        ///     - The inital dockSwipe event we post will be ignored by the system when it is under load (I called this the "stuck bug" in other places). Sending the event again with a delay of 200ms (0.2s) gets it unstuck almost always. Sending the event twice gives us the best of both responsiveness and reliability.
        ///     - In Scroll.m, even with sending the event again after 0.2 seconds, the stuck bug still happens a bunch for some reason. Even though this almost completely eliminates the bug in ModifiedDrag. Sending it again after 0.5 seconds works better but still sometimes happens. Edit: Doesn't happen anymore on M1.
        
        /// Put the events into a dict
        ///     Note: Using `__bridge_transfer` should make it so the events are released when the dict is autoreleased, which is when the timer that the dict gets stored in is invalidated.
        
        NSDictionary *events = @{@"e30": (__bridge_transfer id)e30, @"e29": (__bridge_transfer id)e29};
        
        /// Invalidate existing timers
        
        if (_doubleSendTimer != nil) [_doubleSendTimer invalidate];
        if (_tripleSendTimer != nil) [_tripleSendTimer invalidate];
        
        /// Schedule new timers
        
        _doubleSendTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dockSwipeTimerFired:) userInfo:events repeats:NO];
        _tripleSendTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(dockSwipeTimerFired:) userInfo:events repeats:NO];
    }
    
    ///
    /// Update state
    ///
    
    _dockSwipeLastDelta = d;
}

+ (void)dockSwipeTimerFired:(NSTimer *)timer {
    
    NSDictionary *events = timer.userInfo;
    CGEventRef e30 = (__bridge CGEventRef)events[@"e30"];
    CGEventRef e29 = (__bridge CGEventRef)events[@"e29"];
    
    CGEventPost(kCGSessionEventTap, e30);
    CGEventPost(kCGSessionEventTap, e29);
}


@end

