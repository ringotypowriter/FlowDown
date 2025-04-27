//
//  Created by ktiays on 2025/2/28.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_MACCATALYST

#import <objc/runtime.h>
#import <UIKit/UIKit.h>

#import "FLDCatalystHelper.h"

@interface NSObject ()

@property (nonatomic, strong) id attachedWindow;

- (id)hostWindowForUIWindow:(UIWindow *)window;
- (void)setMaterial:(NSInteger)material;
- (void)setBlendingMode:(NSInteger)blendingMode;

@end

@implementation FLDCatalystHelper

+ (void)load {
    auto appDelegateClass = NSClassFromString(@"UINSApplicationDelegate");
    auto method = class_getInstanceMethod(appDelegateClass, sel_registerName("didCreateUIScene:transitionContext:"));
    auto impl = method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^(id _self, UIScene *scene, id context) {
        ((void (*)(id, SEL, UIScene *, id)) impl)(_self, nil, scene, context);
        
        UIWindowScene *windowScene = (UIWindowScene *) scene;
        if (![windowScene isKindOfClass:[UIWindowScene class]]) {
            return;
        }
        auto uiWindow = windowScene.keyWindow;
        if (!uiWindow) {
            return;
        }
        auto application = [NSClassFromString(@"NSApplication") sharedApplication];
        id delegate = application.delegate;
        if (![delegate respondsToSelector:@selector(hostWindowForUIWindow:)]) {
            return;
        }
        id windowProxy = [delegate hostWindowForUIWindow:uiWindow];
        if (!windowProxy || ![windowProxy respondsToSelector:@selector(attachedWindow)]) {
            return;
        }
        
        id nsWindow = [windowProxy attachedWindow];
        if (![nsWindow isKindOfClass:NSClassFromString(@"UINSWindow")]) {
            return;
        }
        
        id contentView = [nsWindow contentView];
        id themeFrame = [contentView superview];
        if (![themeFrame isKindOfClass:NSClassFromString(@"NSThemeFrame")]) {
            return;
        }
        
        id sceneView = [[contentView subviews] firstObject];
        if (!sceneView) {
            return;
        }
        
        // Create a new NSVisualEffectView.
        id visualEffectView = [[NSClassFromString(@"NSVisualEffectView") alloc] init];
        // NSVisualEffectMaterialSidebar
        [visualEffectView setMaterial:7];
        // NSVisualEffectBlendingModeBehindWindow
        [visualEffectView setBlendingMode:0];
        [contentView addSubview:visualEffectView];
        [contentView addSubview:sceneView];
        [visualEffectView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[visualEffectView topAnchor] constraintEqualToAnchor:[contentView topAnchor]],
            [[visualEffectView leadingAnchor] constraintEqualToAnchor:[contentView leadingAnchor]],
            [[visualEffectView trailingAnchor] constraintEqualToAnchor:[contentView trailingAnchor]],
            [[visualEffectView bottomAnchor] constraintEqualToAnchor:[contentView bottomAnchor]]
        ]];
    }));
}

@end

#endif
