//
// --------------------------------------------------------------------------
// EventUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "MFHIDEventImports.h"

NS_ASSUME_NONNULL_BEGIN

@interface EventUtility : NSObject

int64_t fixedScrollDelta(double scrollDelta);
IOHIDDeviceRef _Nullable CGEventGetSendingDevice(CGEventRef cgEvent);
//IOHIDDeviceRef _Nullable HIDEventGetSendingDevice(HIDEvent *event);
CFTimeInterval CGEventGetTimestampInSeconds(CGEventRef event);
//CFTimeInterval machDeltaToTimeInterval(uint64_t machTime1, uint64_t machTime2);

@end

NS_ASSUME_NONNULL_END
