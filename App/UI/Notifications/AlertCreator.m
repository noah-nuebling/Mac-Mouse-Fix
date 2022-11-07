//
// --------------------------------------------------------------------------
// AlertCreator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "AlertCreator.h"
#import "NSAttributedString+Additions.h"

#pragma mark - NSAlert subclass

@interface MFAlert : NSAlert<NSWindowDelegate> {
    @public BOOL stayOnTop; /// Fun fact: Instance vars are automatically initialized to 0 aka NO.
    @public BOOL asSheet;
}
    
@end

@implementation MFAlert

/// Always-on-top hack
/// Notes:
/// - This is a hack to keep the Alert window always on top of all other windows. It's very ugly.
/// - We managed to achieve always-on-top another way for OverridePanel, but I don't know what we did there.

- (void)windowDidBecomeKey:(NSNotification *)notification {

    /// Notes:
    /// - `windowDidBecomeMain` is never called
    
    /// Invoke super implementation

    if ([self.class.superclass instancesRespondToSelector:_cmd]) {
        
        IMP imp = [self.class.superclass instanceMethodForSelector:_cmd];
        void (*imp2)(id, SEL, NSNotification *) = (void *)imp;
        imp2(self, _cmd, notification);
    }

    if (stayOnTop) {

        /// Get main window
        NSWindow *w = asSheet ? self.window.sheetParent : self.window;

        /// Set window level to floating
        /// Notes:
        /// - Window will already  be on top here so this will not immediately have a noticable effect.. But this will prevent strange flickering when the window resigns key.
        /// - When we replace all the setting of `level` with calling `orderFrontRegardless`, the flickering will always occur.
        w.level = NSFloatingWindowLevel;
    }
}

- (void)windowDidResignKey:(NSNotification *)notification {

    /// Invoke super implementation

    if ([self.class.superclass instancesRespondToSelector:_cmd]) {
        
        IMP imp = [self.class.superclass instanceMethodForSelector:_cmd];
        void (*imp2)(id, SEL, NSNotification *) = (void *)imp;
        imp2(self, _cmd, notification);
    }

    /// Keep window on top
    if (stayOnTop) {

        /// Get main window
        NSWindow *w = asSheet ? self.window.sheetParent : self.window;

        /// Bring that window on top
        w.level = NSFloatingWindowLevel;
        
    }

}

@end

#pragma mark - AlertCreator

@implementation AlertCreator

+ (void)showPersistenNotificationWithTitle:(NSString *)title markdownBody:(NSString *)bodyRaw maxWidth:(int)maxWidth stayOnTop:(BOOL)isAlwaysOnTop asSheet:(BOOL)asSheet {
    
    /// \discussion Created this for when we receive a "helperEnabled" message from a strange helper under Ventura. In that case we show the user prettty long instructions which involve following a link. Toasts were too "transient" for this, because they automatically disappear. So we designed this as a "persistent" alternative to a toast.
    ///
    /// This is EXTREMELY OVERENGINEERED for this one, extremely rare use case.
    ///
    /// To justify this madness we could:
    ///
    /// 1. Transition other Toasts which (show instructions / would benefit from being persistent) to using this method.
    ///     - I can only think of the toast that shows when MMF is disabled in System Settings since it also has instructions
    /// 2. Transition other uses of NSAlert to abstractions like this one.
    ///     - The only thing this implementation has over normal NSAlerts is that its body is markdown-capable. This might be nice for the "Send Me an Email" alert.
    /// 3. Make this implementation totally custom and not dependent on NSAlert
    ///     - I don't like that NSAlert forces an image and a title. Having just an AttributedString like the toasts would be cleaner. But I guess this is good enough and the visuals will update if Apple updates NSAlert.
    ///
    /// Notes:
    /// - This is currently untested, but also unused pre-Ventura
    
    /// Override body alignment
    
    NSAttributedString *body = [NSAttributedString attributedStringWithCoolMarkdown:bodyRaw];
    if (@available(macOS 11.0, *)) {
        body = [body attributedStringByAligningSubstring:nil alignment:NSTextAlignmentCenter];
    } else { /// The ways this looks pre-Big Sur is untested at the time of writing
        body = [body attributedStringByAligningSubstring:nil alignment:NSTextAlignmentNatural];
    }
    
    /// Create alert
    
    MFAlert *alert = [[MFAlert alloc] init];
    
    /// Set alert stye
    alert.alertStyle = NSAlertStyleInformational;
    
    /// Set instance vars on alert
    alert->stayOnTop = isAlwaysOnTop;
    alert->asSheet = asSheet;
    
    /// Set title
    alert.messageText = title;
    
    /// Create view for body
    NSTextView *bodyView = [[NSTextView alloc] init];
    bodyView.editable = NO;
    bodyView.drawsBackground = NO;
    [bodyView.textStorage setAttributedString:body];
    [bodyView setFrameSize:[body sizeAtMaxWidth:maxWidth]];
    
    /// Set alert body
    alert.accessoryView = bodyView;
    
    /// Show
    if (asSheet) {
        [alert beginSheetModalForWindow:NSApp.mainWindow completionHandler:^(NSModalResponse returnCode) {}];
    } else {
        [alert runModal];
    }
}

@end
