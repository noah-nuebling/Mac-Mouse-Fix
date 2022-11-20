//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAttributedString (Additions)

void assignAttributedStringKeepingBase(NSAttributedString *_Nonnull *_Nonnull assignee, NSAttributedString *newValue);

- (NSAttributedString *)attributedStringByCapitalizingFirst;
- (NSAttributedString *)attributedStringByTrimmingWhitespace;

- (NSAttributedString *)attributedStringByAppending:(NSAttributedString *)string;
+ (NSAttributedString *)attributedStringWithAttributedFormat:(NSAttributedString *)format args:(NSArray<NSAttributedString *> *)args;
+ (NSAttributedString * _Nullable)attributedStringWithCoolMarkdown:(NSString *)md;
+ (NSAttributedString * _Nullable)attributedStringWithCoolMarkdown:(NSString *)md fillOutBase:(BOOL)fillOutBase;

- (NSAttributedString *)attributedStringByAddingBaseLineOffset:(CGFloat)offset;

- (NSString *)stringWithAttachmentDescriptions;

- (NSAttributedString *)attributedStringByAddingFontTraits:(NSDictionary<NSFontDescriptorTraitKey, id> *)traits;
- (NSAttributedString *)attributedStringByAddingWeight:(NSFontWeight)weight;

- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits;

- (NSAttributedString *)attributedStringByFillingOutBase;
- (NSAttributedString *)attributedStringByFillingOutBaseAsHint;

- (NSAttributedString *)attributedStringByAddingStringAttributesAsBase:(NSDictionary<NSAttributedStringKey, id> *)baseAttributes;
- (NSAttributedString *)attributedStringByAddingLinkWithURL:(NSURL *)linkURL forSubstring:(NSString *)substring;
- (NSAttributedString *)attributedStringByAddingBoldForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingSemiBoldForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringBySettingSemiBoldColorForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingBold;
- (NSAttributedString *)attributedStringByAddingItalicForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAligningSubstring:(NSString * _Nullable)subStr alignment:(NSTextAlignment)alignment;
- (NSAttributedString *)attributedStringBySettingWeight:(NSInteger)weight;
- (NSAttributedString *)attributedStringBySettingThinForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringBySettingFontSize:(CGFloat)size;
- (NSAttributedString *)attributedStringBySettingSecondaryLabelColorForSubstring:(NSString * _Nullable)subStr;
+ (NSAttributedString *)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)aURL;

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth;
- (CGFloat)heightAtWidth:(CGFloat)width;
//- (CGFloat)preferredWidth;

@end

NS_ASSUME_NONNULL_END
