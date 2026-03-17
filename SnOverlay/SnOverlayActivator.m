// SnOverlayActivator.m — Standalone Snoverlay 2 port for Coruna
// No substrate, no Theos — pure ObjC runtime
// Original tweak by ryannair05: https://github.com/ryannair05/Snoverlay-2

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <math.h>

#include "snowflake_data.h"

#pragma mark - Embedded image loader

static UIImage *imageFromEmbeddedPNG(const unsigned char *bytes, unsigned int len) {
    NSData *data = [NSData dataWithBytesNoCopy:(void *)bytes length:len freeWhenDone:NO];
    return [UIImage imageWithData:data];
}

#pragma mark - XMASFallingSnowView

@interface XMASFallingSnowView : UIView {
    CAEmitterLayer *_snowEmitterLayer;
}
@end

@implementation XMASFallingSnowView

- (instancetype)initWithFrame:(CGRect)frame flakeType:(NSInteger)type count:(NSInteger)count {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];

        UIImage *flakeImg;
        CGFloat scale, scaleRange;

        if (type == 0) {
            flakeImg = imageFromEmbeddedPNG(snowflake0_png, snowflake0_png_len);
            scale = 0.3;
            scaleRange = 0.25;
        } else {
            flakeImg = imageFromEmbeddedPNG(snowflake1_png, snowflake1_png_len);
            scale = 0.05;
            scaleRange = 0.03;
        }

        if (!flakeImg) return self;

        CAEmitterCell *cell = [CAEmitterCell emitterCell];
        cell.contents = (__bridge id)flakeImg.CGImage;
        cell.scale = scale;
        cell.scaleRange = scaleRange;
        cell.lifetime = 15.0;
        cell.birthRate = count >> 3;
        cell.emissionRange = M_PI;
        cell.velocity = -20;
        cell.velocityRange = 100;
        cell.yAcceleration = 20;
        cell.zAcceleration = 10;
        cell.xAcceleration = 5;
        cell.spinRange = M_PI * 2;

        _snowEmitterLayer = [CAEmitterLayer layer];
        _snowEmitterLayer.emitterPosition = CGPointMake(frame.size.width / 2.0 - 50, -50);
        _snowEmitterLayer.emitterSize = CGSizeMake(frame.size.width, 0);
        _snowEmitterLayer.emitterShape = kCAEmitterLayerLine;
        _snowEmitterLayer.beginTime = CACurrentMediaTime();
        _snowEmitterLayer.timeOffset = 10;
        _snowEmitterLayer.emitterCells = @[cell];

        [self.layer addSublayer:_snowEmitterLayer];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_snowEmitterLayer) {
        _snowEmitterLayer.emitterPosition = CGPointMake(self.center.x, -50);
        _snowEmitterLayer.emitterSize = CGSizeMake(self.bounds.size.width, 0);
    }
}

@end

#pragma mark - Snow window

static UIWindow *g_snowWindow = nil;

static void createSnowOverlay(void) {
    if (g_snowWindow) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect frame = [UIScreen mainScreen].bounds;

        // Get a window scene (required on iOS 13+)
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
        }

        if (!scene) {
            NSLog(@"[SnOverlay] No window scene found, retrying in 2s...");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                createSnowOverlay();
            });
            return;
        }

        // Create a passthrough window on the scene
        g_snowWindow = [[UIWindow alloc] initWithWindowScene:scene];
        g_snowWindow.frame = frame;
        g_snowWindow.windowLevel = 100000.0f;
        g_snowWindow.userInteractionEnabled = NO;
        g_snowWindow.backgroundColor = [UIColor clearColor];
        g_snowWindow.opaque = NO;

        // Use a root VC so the window works properly
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        g_snowWindow.rootViewController = vc;

        // Create snow view — type 0 (dot flake), 160 particles
        XMASFallingSnowView *snowView = [[XMASFallingSnowView alloc] initWithFrame:frame flakeType:0 count:160];
        snowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [vc.view addSubview:snowView];

        g_snowWindow.hidden = NO;
        [g_snowWindow makeKeyAndVisible];

        NSLog(@"[SnOverlay] Snow overlay active on scene: %@", scene);
    });
}

#pragma mark - Constructor

__attribute__((constructor))
static void SnOverlayActivatorInit(void) {
    NSLog(@"[SnOverlay] Loading...");
    // Small delay to let SpringBoard settle
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        createSnowOverlay();
    });
}
