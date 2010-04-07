// Created by Satoshi Nakagawa.
// You can redistribute it and/or modify it under the Ruby's license or the GPL2.

#import <Cocoa/Cocoa.h>


@interface PreferencesController : NSWindowController
{
	id delegate;
}

@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) int maxLogLines;
@property (nonatomic, assign) NSString* fontDisplayName;
@property (nonatomic, assign) CGFloat fontPointSize;

- (void)show;

- (void)onTranscriptFolderChanged:(id)sender;
- (void)onLayoutChanged:(id)sender;
- (void)onChangedTheme:(id)sender;
- (void)onOpenThemePath:(id)sender;
- (void)onSelectFont:(id)sender;
- (void)onAddHighlightWord:(id)sender;
- (void)onAddDislikeWord:(id)sender;
- (void)onAddIgnoreWord:(id)sender;
- (void)onChangedTransparency:(id)sender;

@end
