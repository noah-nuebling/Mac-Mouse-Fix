//
// --------------------------------------------------------------------------
// DeviceManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Device.h"
#import "WannabePrefixHeader.h"
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeviceManager : NSObject


+ (__DISABLE_SWIFT_BRIDGING(NSArray<Device *> *))attachedDevices NS_REFINED_FOR_SWIFT;

+ (void)load_Manual;
+ (void)deconfigureDevices;

+ (BOOL)devicesAreAttached;
+ (Device * _Nullable)attachedDeviceWithIOHIDDevice:(IOHIDDeviceRef)iohidDevice;

+ (BOOL)someDeviceHasScrollWheel;
+ (BOOL)someDeviceHasPointing;
+ (BOOL)someDeviceHasUsableButtons;
+ (int)maxButtonNumberAmongDevices;


@end

NS_ASSUME_NONNULL_END
