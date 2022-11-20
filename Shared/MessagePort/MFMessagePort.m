//
// --------------------------------------------------------------------------
// MFMessagePort.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// This class is used to communicate between the MainApp and the Helper.
///     More or less works like a function call across processes.
/// Notes:
/// - Can't be named MessagePort because there's already a class in Foundation with that name
/// - This is a wrapper around CFMessagePort, which itself is a wrapper around mach ports. This was one of the first things we wrote for Mac Mouse Fix. Don't remember why we didn't use the higher level NSMachPort or directly use the low level mach_port C APIs. 

#import "MFMessagePort.h"
#import <Cocoa/Cocoa.h>
#import "Constants.h"
#import "SharedUtility.h"
#import "Locator.h"
#import "HelperServices.h"
#import "Locator.h"

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#import "KeyCaptureView.h"
#import "AlertCreator.h"
#endif

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "AccessibilityCheck.h"
#endif

@implementation MFMessagePort

#pragma mark - Handle incoming messages

static CFDataRef _Nullable didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    assert(SharedUtility.runningMainApp || SharedUtility.runningHelper);
    
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    
    DDLogInfo(@"Received Message: %@ with payload: %@", message, payload);
    
    NSObject *response = nil;
    
#if IS_MAIN_APP
    
#pragma mark MainApp
 
    if ([message isEqualToString:@"addModeEnabled"]) {
        [MainAppState.shared.buttonTabController handleAddModeEnabled];
    } else if ([message isEqualToString:@"addModeDisabled"]) {
        [MainAppState.shared.buttonTabController handleAddModeDisabled];
    } else if ([message isEqualToString:@"addModeFeedback"]) {
        [MainAppState.shared.buttonTabController handleAddModeConcludedWithPayload:(NSDictionary *)payload];
    } else if ([message isEqualToString:@"keyCaptureModeFeedback"]) {
        [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:NO];
    } else if ([message isEqualToString:@"keyCaptureModeFeedbackWithSystemEvent"]) {
        [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:YES];
    } else if ([message isEqualToString:@"helperEnabledWithNoAccessibility"]) {
        
        BOOL isStrange = false;
        if (@available(macOS 13, *)) {
            isStrange = [MessagePortUtility checkHelperStrangenessReactWithPayload:payload];
        }
        if (!isStrange) {
            [AuthorizeAccessibilityView add];
        }
    } else if ([message isEqualToString:@"helperEnabled"]) {
        
        BOOL isStrange = false;
        if (@available(macOS 13, *)) {
            isStrange = [MessagePortUtility checkHelperStrangenessReactWithPayload:payload];
        }
        
        if (!isStrange) { /// Helper matches mainApp instance.
            
            /// Bring mainApp for foreground
            /// In some places like when the accessibilitySheet is dismissed, we have other methods for bringing mainApp to the foreground that might be unnecessary now that we're doing this. Edit: We stopped the accessibiility enabling code from activating the app.
            [NSApp activateIgnoringOtherApps:YES];
            
            /// Dismiss accessibilitySheet
            ///     This is unnecessary under Ventura since `activateIgnoringOtherApps` will trigger `ResizingTabWindowController.windowDidBecomeMain()` which will also call `[AuthorizeAccessibilityView remove]`. But it's better to be safe and explicit about this.
            [AuthorizeAccessibilityView remove];
            
            /// Notify rest of the app
            [EnabledState.shared reactToDidBecomeEnabled];
        }
        
        
    } else if ([message isEqualToString:@"helperDisabled"]) {
        [EnabledState.shared reactToDidBecomeDisabled];
    } else if ([message isEqualToString:@"configFileChanged"]) {
        [Config handleConfigFileChange];
    }
    
#elif IS_HELPER

#pragma mark HelperApp
    
    if ([message isEqualToString:@"configFileChanged"]) {
        [Config handleConfigFileChange];
    } else if ([message isEqualToString:@"terminate"]) {
//        [NSApp.delegate applicationWillTerminate:[[NSNotification alloc] init]]; /// This creates an infinite loop or something? The statement below is never executed.
        [NSApp terminate:NULL];
    } else if ([message isEqualToString:@"checkAccessibility"]) {
        BOOL isTrusted = [AccessibilityCheck checkAccessibilityAndUpdateSystemSettings];
        response = @(isTrusted);
    } else if ([message isEqualToString:@"enableAddMode"]) {
        [TransformationManager enableAddMode];
    } else if ([message isEqualToString:@"disableAddMode"]) {
        [TransformationManager disableAddMode];
    } else if ([message isEqualToString:@"enableKeyCaptureMode"]) {
        [TransformationManager enableKeyCaptureMode];
    } else if ([message isEqualToString:@"disableKeyCaptureMode"]) {
        [TransformationManager disableKeyCaptureMode];
    } else if ([message isEqualToString:@"getActiveDeviceInfo"]) {
        Device *dev = HelperState.activeDevice;
        if (dev != NULL) {
            
            response = @{
                @"name": dev.name == nil ? @"" : dev.name,
                @"manufacturer": dev.manufacturer == nil ? @"" : dev.manufacturer,
                @"nOfButtons": @(dev.nOfButtons),
            };
        }
    } else if ([message isEqualToString:@"updateActiveDeviceWithEventSenderID"]) {
        
        /// We can't just pass over the CGEvent from the mainApp because the senderID isn't stored when serializing CGEvents
        
        uint64_t senderID = [(NSNumber *)payload unsignedIntegerValue];
        [HelperState updateActiveDeviceWithEventSenderID:senderID];
        
    } else if ([message isEqualToString:@"getBundleVersion"]) {
        response = @(Locator.bundleVersion);
//    } else if ([message isEqualToString:@"getBundleVersion"]) {
//        response = @(Locator.bundleVersion);
    } else {
        DDLogInfo(@"Unknown message received: %@", message);
    }
    
#else
    abort();
#endif
    
    if (response != nil) {
         return (__bridge_retained CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:response];
     }

     return NULL;
}


#pragma mark - Setup port

+ (void)load_Manual {
    
    /// This sets up a local port for listening for incoming messages
    
    /// Notes from Helper:
    /// I'm not sure this is supposed to be `load_Manual` instead of load
    
    /// Notes from mainApp:
    /// We used to do this in `load` but that lead to issues when restarting the app if it's translocated
    /// If the app detects that it is translocated, it will restart itself at the untranslocated location,  after removing the quarantine flags from itself. It starts a copy of itself while it's still running, and only then does it terminate itself. If the message port is already 'claimed' by the translocated instances when it starts the untranslocated copy, then the untranslocated copy can't 'claim' the message port for itself, which leads to things like the accessiblity screen not working.
    /// I hope that moving using `initialize` instead of `load` if `IS_MAIN_APP` should fix this and work just fine for everything else. I don't know why we used load to begin with.
    /// Edit: I don't remember why we moved to `load_Manual` now, but it works fine
    
    assert(SharedUtility.runningMainApp || SharedUtility.runningHelper);
    
    DDLogInfo(@"Initializing MessagePort...");
    
    CFMessagePortRef localPort =
    CFMessagePortCreateLocal(kCFAllocatorDefault,
                             (__bridge CFStringRef)(SharedUtility.runningMainApp ? kMFBundleIDApp : kMFBundleIDHelper),
                             didReceiveMessage,
                             nil,
                             NULL);
    
    DDLogInfo(@"Created localPort: %@", localPort);
    
    /// Setting the name here instead of when creating the port creates some super weird behavior, too.
//    CFMessagePortSetName(localPort, CFSTR("com.nuebling.mousefix.port"));
    
    
    if (localPort != NULL) {
        
        /// Notes from mainApp:
        /// On CatalinM, creating the local Port returns NULL and throws a permission denied error. Trying to schedule it with the runloop yields a crash.
        /// But even if you just skip the runloop scheduling it still works somehow!
        
        /// Notes from Helper:
        /// CFMessagePortCreateRunLoopSource() used to crash when another instance of MMF Helper was already running.
        /// It would log this: `*** CFMessagePort: bootstrap_register(): failed 1100 (0x44c) 'Permission denied', port = 0x1b03, name = 'com.nuebling.mac-mouse-fix.helper'`
        /// I think the reason for this messate is that the existing instance would already 'occupy' the kMFBundleIDHelper name.
        /// Checking if `localPort != nil` should detect this case
        
        CFRunLoopSourceRef runLoopSource =
            CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
        
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           runLoopSource,
                           kCFRunLoopCommonModes);
        
        CFRelease(runLoopSource);
    } else {
        
        if (SharedUtility.runningMainApp) {
            DDLogInfo(@"Failed to create a local message port. It will probably work anyway for some reason");
        } else {
            DDLogError(@"Failed to create a local message port. This might be because there is another instance of %@ already running. Crashing the app.", kMFHelperName);
            @throw [NSException exceptionWithName:@"NoMessagePortException" reason:@"Couldn't create a local CFMessagePort. Can't function properly without local CFMessagePort" userInfo:nil];
        }
        
    }
}

#pragma mark - Send messages


+ (NSObject *_Nullable)sendMessage:(NSString * _Nonnull)message withPayload:(NSObject <NSCoding> * _Nullable)payload expectingReply:(BOOL)replyExpected { // TODO: Consider renaming last arg to `expectingReturn` or `waitForReply`
    
    /// Validate
    assert(SharedUtility.runningMainApp || SharedUtility.runningHelper);
    
    /// Get remote port
    /// Note: We can't just create the port once and cache it, trying to send with that port will yield ``kCFMessagePortIsInvalid``
    
    NSString *remotePortName = SharedUtility.runningMainApp ? kMFBundleIDHelper : kMFBundleIDApp;
    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, (__bridge CFStringRef)remotePortName);

    if (remotePort == NULL) {
        DDLogInfo(@"Can't send message \'%@\', because there is no CFMessagePort", message);
        return nil;
    }
    
    CFMessagePortSetInvalidationCallBack(remotePort, invalidationCallback);

    /// Create message dict
    
    NSDictionary *messageDict;
    if (payload) {
        messageDict = @{
            kMFMessageKeyMessage: message,
            kMFMessageKeyPayload: payload, /// This crashes if payload is nil for some reason
        };
    } else {
        messageDict = @{
            kMFMessageKeyMessage: message,
        };
    }
    
    DDLogInfo(@"Sending message: %@ with payload: %@ from bundle: %@ via message port", message, payload, NSBundle.mainBundle.bundleIdentifier);
    
    /// Send message
    
    SInt32 messageID = 0x420666; /// Arbitrary
    CFDataRef messageData = (__bridge CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:messageDict];
    CFTimeInterval sendTimeout = 0.0;
    CFTimeInterval recieveTimeout = 0.0;
    CFStringRef replyMode = NULL;
    CFDataRef returnData = NULL;
    if (replyExpected) {
//        sendTimeout = 1.0;
        recieveTimeout = 1.0;
        replyMode = kCFRunLoopDefaultMode;
    }

    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &returnData);
    CFRelease(remotePort);
    
    /// Handle errors & response
    
    if (status != 0) {
        DDLogError(@"Non-zero CFMessagePortSendRequest status: %d", status);
        return nil;
    }
    
    NSObject *returnObject = nil;
    if (returnData != NULL && replyExpected /*&& status == 0*/) {
        returnObject = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)returnData];
    }
    
    /// Return
    
    return returnObject;
}

void invalidationCallback(CFMessagePortRef ms, void *info) {
    DDLogInfo(@"MessagePort invalidated in %@", SharedUtility.runningHelper ? @"Helper" : @"MainApp");
}

@end
