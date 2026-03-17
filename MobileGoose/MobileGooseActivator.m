// MobileGooseActivator.m — Standalone MobileGoose port for Coruna
// No substrate, no Theos — pure ObjC runtime
// Original tweak by pixelomer: https://github.com/pixelomer/MobileGoose

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define DEG_TO_RAD(d) ((d) * M_PI / 180.0)
#define FPS 30.0
#define mg_min(a,b) ((a<b)?a:b)

#include "goose_data.h"

@interface UIView (Private)
- (UIViewController *)_viewControllerForAncestor;
@end

#pragma mark - MGContainerView

@interface MGContainerView : UIView {
    UIVisualEffectView *_visualEffect;
}
@property (nonatomic, readonly, strong) UIView *contentView;
@property (nonatomic, assign) BOOL hideOnTap;
@end

@implementation MGContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.layer.masksToBounds = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.125];
        _visualEffect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        _contentView = [UIView new];
        [self addSubview:_visualEffect];
        [self addSubview:_contentView];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)handleTap:(UITapGestureRecognizer *)sender {
    if (_hideOnTap && sender.state == UIGestureRecognizerStateEnded) {
        self.userInteractionEnabled = NO;
        [UIView animateWithDuration:0.5 animations:^{ self.alpha = 0.0; } completion:^(BOOL f){ [self removeFromSuperview]; }];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = 0.1 * mg_min(self.frame.size.width, self.frame.size.height);
    CGRect r = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    _visualEffect.frame = r;
    _contentView.frame = CGRectInset(r, 2.5, 2.5);
}
@end

#pragma mark - MGImageContainerView

@interface MGImageContainerView : MGContainerView
@property (nonatomic, strong, readonly) UILabel *failureLabel;
@property (nonatomic, strong, readonly) UIImageView *imageView;
@end

@implementation MGImageContainerView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _imageView = [UIImageView new];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.layer.masksToBounds = YES;
        _failureLabel = [UILabel new];
        _failureLabel.text = @"Could not\nload meme";
        _failureLabel.font = [UIFont boldSystemFontOfSize:_failureLabel.font.pointSize];
        _failureLabel.textColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        _failureLabel.numberOfLines = 0;
        _failureLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_imageView];
        [self.contentView addSubview:_failureLabel];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _imageView.frame = CGRectMake(0, 0, self.contentView.frame.size.width, self.contentView.frame.size.height);
    _imageView.layer.cornerRadius = 0.1 * mg_min(_imageView.frame.size.width, _imageView.frame.size.height);
    CGSize ls = [_failureLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    _failureLabel.frame = CGRectMake(0, (self.contentView.frame.size.height - ls.height * 2) / 2, self.contentView.frame.size.width, ls.height * 2);
}
- (void)setMemeImage:(UIImage *)img {
    _failureLabel.hidden = !!img;
    _imageView.image = img;
}
@end

#pragma mark - MGTextContainerView

@interface MGTextContainerView : MGContainerView
@property (nonatomic, strong, readonly) UILabel *textLabel;
@end

@implementation MGTextContainerView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _textLabel = [UILabel new];
        _textLabel.textColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        _textLabel.numberOfLines = 0;
        _textLabel.adjustsFontSizeToFitWidth = YES;
        _textLabel.textAlignment = NSTextAlignmentCenter;
        _textLabel.minimumScaleFactor = 0.1;
        [self.contentView addSubview:_textLabel];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _textLabel.frame = CGRectInset(self.contentView.bounds, 3, 3);
}
@end

#pragma mark - Embedded meme/note loader

static UIImage *randomEmbeddedMeme(void) {
    uint32_t r = arc4random_uniform(3);
    const unsigned char *data; unsigned int len;
    switch (r) {
        case 0: data = meme1_png; len = meme1_png_len; break;
        case 1: data = meme2_png; len = meme2_png_len; break;
        default: data = meme3_png; len = meme3_png_len; break;
    }
    return [UIImage imageWithData:[NSData dataWithBytesNoCopy:(void *)data length:len freeWhenDone:NO]];
}

static NSString *randomEmbeddedNote(void) {
    return goose_notes[arc4random_uniform(goose_notes_count)];
}

#pragma mark - MGGooseView

typedef void(^MGGooseCommonBlock)(id);

@interface MGGooseView : UIView {
    NSTimer *_timer;
    CGFloat _foot1Y, _foot2Y;
    NSInteger _walkingState;
    CGFloat _targetFacingTo;
    NSInteger _remainingFramesUntilCompletion;
    MGGooseCommonBlock _walkCompletion, _animationCompletion;
    CGFloat _walkMultiplier;
    NSMutableArray *_frameHandlers;
}
@property (nonatomic, assign) CGFloat facingTo;
@property (nonatomic, assign) BOOL stopsAtEdge;
@property (nonatomic, assign) CGPoint positionChange;
- (void)walkForDuration:(NSTimeInterval)d speed:(CGFloat)s completionHandler:(MGGooseCommonBlock)c;
- (void)setFacingTo:(CGFloat)deg animationCompletion:(MGGooseCommonBlock)c;
- (void)stopWalking;
- (BOOL)isFrameAtEdge:(CGRect)frame;
- (NSUInteger)addFrameHandler:(void(^)(MGGooseView *, int))handler;
- (void)removeFrameHandlerAtIndex:(NSUInteger)idx;
@end

static UIColor *g_shadowColor;

@implementation MGGooseView

+ (void)rotatePath:(UIBezierPath *)p degree:(CGFloat)d bounds:(CGRect)b {
    CGPoint c = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
    CGAffineTransform t = CGAffineTransformTranslate(CGAffineTransformRotate(CGAffineTransformMakeTranslation(c.x, c.y), d / 180.0f * M_PI), -c.x, -c.y);
    [p applyTransform:t];
}

- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(80, 80); }

- (NSUInteger)addFrameHandler:(void(^)(MGGooseView *, int))handler {
    [_frameHandlers addObject:handler];
    return _frameHandlers.count - 1;
}

- (void)removeFrameHandlerAtIndex:(NSUInteger)idx {
    _frameHandlers[idx] = [NSNull null];
}

- (void)notifyHandlers:(int)state {
    NSArray *copy = [_frameHandlers copy];
    for (id h in copy) {
        if (!h || [h isKindOfClass:[NSNull class]]) continue;
        ((void(^)(MGGooseView *, int))h)(self, state);
    }
}

- (void)drawRect:(CGRect)rect {
    CGFloat facingToDegrees = _facingTo;
    CGFloat facingToRadians = facingToDegrees * M_PI / 180.0;
    [self notifyHandlers:0x80];

    // Shadow
    [g_shadowColor setFill];
    CGRect shadowBounds = CGRectMake(20, 30, 30, 30);
    @autoreleasepool {
        [[UIBezierPath bezierPathWithOvalInRect:shadowBounds] fill];
    }

    // Feet
    [[UIColor orangeColor] setFill];
    @autoreleasepool {
        CGFloat change = (_walkMultiplier / 2.6);
        switch (_walkingState) {
            case 0: _foot1Y = _foot2Y = 36.0; break;
            case 1: _foot1Y += change; _foot2Y -= change; break;
            case 2: _foot1Y -= change; _foot2Y += change; break;
            case 3: _foot1Y += change; break;
        }
        const CGFloat footSize = 6.0;
        const CGFloat foot1X = 24.5;
        const CGFloat foot2X = 38.5;
        if (_walkMultiplier < 0.0) {
            change = _foot2Y; _foot2Y = _foot1Y; _foot1Y = change;
        }
        switch (_walkingState) {
            case 1: case 3:
                if (_foot1Y >= 50.0) { _walkingState = 2; _foot1Y = 50.0; _foot2Y = 36.0; }
                break;
            case 2:
                if (_foot1Y <= 36.0) { _walkingState = 1; _foot2Y = 50.0; _foot1Y = 36.0; }
                break;
        }
        if (_walkMultiplier < 0.0) {
            change = _foot2Y; _foot2Y = _foot1Y; _foot1Y = change;
        }
        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(foot1X, _foot1Y, footSize, footSize)];
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(foot2X, _foot2Y, footSize, footSize)]];
        [MGGooseView rotatePath:path degree:facingToDegrees+90.0 bounds:shadowBounds];
        [path fill];
    }

    // Body
    [[UIColor whiteColor] setFill];
    @autoreleasepool {
        CGRect oval1Rect = CGRectMake(25, 20, 20, 20);
        UIBezierPath *oval1 = [UIBezierPath bezierPathWithOvalInRect:oval1Rect];
        CGRect oval2Rect = CGRectMake(oval1Rect.origin.x, 55-oval1Rect.size.height, oval1Rect.size.width, oval1Rect.size.height);
        UIBezierPath *oval2 = [UIBezierPath bezierPathWithOvalInRect:oval2Rect];
        CGRect rectangleRect = CGRectMake(oval1Rect.origin.x, oval1Rect.origin.y+oval1Rect.size.height/2, oval1Rect.size.width, oval2Rect.origin.y-oval1Rect.origin.y);
        UIBezierPath *finalPath = [UIBezierPath bezierPathWithRect:rectangleRect];
        [finalPath appendPath:oval1];
        [finalPath appendPath:oval2];
        [MGGooseView rotatePath:finalPath degree:facingToDegrees+90.0 bounds:finalPath.bounds];
        [finalPath fill];
    }

    // Neck
    [[UIColor whiteColor] setFill];
    @autoreleasepool {
        const CGFloat neckHeight = 10;
        CGRect neckRect = CGRectMake(10, 20, 15, neckHeight);
        const CGFloat radius = 10.0;
        neckRect.origin.x += 17.5 + (radius * cos(facingToRadians));
        neckRect.origin.y += 4.8 + (radius * sin(facingToRadians));
        UIBezierPath *path = [UIBezierPath bezierPathWithRect:neckRect];
        CGRect capRect = CGRectMake(neckRect.origin.x, neckRect.origin.y - (neckRect.size.width / 2), neckRect.size.width, neckRect.size.width);
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:capRect]];
        capRect.origin.y += capRect.size.width;
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:capRect]];
        [path fill];
    }

    // Face (beak)
    [[UIColor orangeColor] setFill];
    @autoreleasepool {
        const CGFloat beakSize = 8.0;
        CGRect beakRect = CGRectMake(10, 20, beakSize, beakSize);
        const CGFloat beakRadius = 15.0;
        beakRect.origin.x += 21.0 + (beakRadius * cos(facingToRadians));
        beakRect.origin.y += 4.5 + (beakRadius * sin(facingToRadians));
        [[UIBezierPath bezierPathWithOvalInRect:beakRect] fill];

        // Eyes
        [[UIColor blackColor] setFill];
        const CGFloat eyeSize = beakSize * 0.6;
        const CGFloat eyeRadius = beakRadius - 3.0;
        beakRect.size.height = beakRect.size.width = eyeSize;
        for (int8_t i=0, offset=15; i<2; i++) {
            beakRect.origin.x = 32.5 + (eyeRadius * cos(DEG_TO_RAD(facingToDegrees + offset)));
            beakRect.origin.y = 24.5 + (eyeRadius * sin(DEG_TO_RAD(facingToDegrees + offset)));
            [[UIBezierPath bezierPathWithOvalInRect:beakRect] fill];
            offset = -offset;
        }
    }

    if (_remainingFramesUntilCompletion == 0) _walkingState = 0;
    if (_remainingFramesUntilCompletion >= 0) _remainingFramesUntilCompletion--;
    [self notifyHandlers:0];
}

- (BOOL)isFrameAtEdge:(CGRect)f {
    CGRect b = self._viewControllerForAncestor.view.bounds;
    return (f.origin.x + f.size.width >= b.size.width - 1) || (f.origin.y + f.size.height >= b.size.height - 1) || f.origin.x <= 1 || f.origin.y <= 1;
}

- (void)setFacingTo:(CGFloat)d animationCompletion:(MGGooseCommonBlock)c {
    _targetFacingTo = d - floor(d / 360.0) * 360.0;
    _animationCompletion = c;
}

- (void)walkForDuration:(NSTimeInterval)d speed:(CGFloat)s completionHandler:(MGGooseCommonBlock)c {
    _remainingFramesUntilCompletion = d * FPS;
    _walkCompletion = c;
    _walkingState = (s >= 0) ? 3 : 2;
    _walkMultiplier = s;
}

- (void)stopWalking {
    _walkingState = 0; _remainingFramesUntilCompletion = -1;
    MGGooseCommonBlock c = _walkCompletion; _walkCompletion = nil;
    if (c) c(self);
}

- (void)tick:(id)u {
    if (_targetFacingTo >= 0) {
        CGFloat ch = (_targetFacingTo > _facingTo) ? 1.0 : -1.0;
        CGFloat diff = fabs(_facingTo - _targetFacingTo);
        if (diff <= 0.01) {
            _facingTo = _targetFacingTo; _targetFacingTo = -1;
            MGGooseCommonBlock c = _animationCompletion; _animationCompletion = nil;
            if (c) c(self);
        } else {
            if (diff <= 1) ch *= diff; else if (diff > 10) ch *= diff / 5;
            _facingTo += ch;
        }
    }
    CGRect of = self.frame;
    if (_remainingFramesUntilCompletion != -1) {
        CGRect f = self.frame;
        f.origin.x += cos(DEG_TO_RAD(_facingTo)) * _walkMultiplier;
        f.origin.y += sin(DEG_TO_RAD(_facingTo)) * _walkMultiplier;
        if (_stopsAtEdge && [self isFrameAtEdge:f]) { _remainingFramesUntilCompletion = -1; _walkingState = 0; }
        else {
            CGRect vf = self._viewControllerForAncestor.view.frame;
            if (f.origin.x + f.size.width < 0) f.origin.x = vf.size.width + self.frame.size.width;
            else if (f.origin.x - f.size.width > vf.size.width) f.origin.x = -self.frame.size.width;
            if (f.origin.y + f.size.height < 0) f.origin.y = vf.size.height + self.frame.size.height;
            else if (f.origin.y - f.size.height > vf.size.height) f.origin.y = -self.frame.size.height;
            self.frame = f;
        }
    }
    if (_remainingFramesUntilCompletion == -1 && _walkCompletion) [self stopWalking];
    _facingTo -= floor(_facingTo / 360.0) * 360.0;
    _positionChange = CGPointMake(self.frame.origin.x - of.origin.x, self.frame.origin.y - of.origin.y);
    [self setNeedsDisplay];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO; self.backgroundColor = [UIColor clearColor];
        _foot1Y = _foot2Y = 36; _facingTo = 45; _remainingFramesUntilCompletion = -1;
        _targetFacingTo = -1; _stopsAtEdge = YES;
        _frameHandlers = [NSMutableArray new];
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0/FPS target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    }
    return self;
}
@end

#pragma mark - GooseController (full: walk, memes, notes, crazy mode)

static const CGFloat kSpeed = 2.6;

@interface GooseController : NSObject {
    NSInteger _fhIdx;
    BOOL _getMemeFromLeft;
    __kindof MGContainerView *_container;
    NSPointerArray *_containers;
}
@property (nonatomic, strong) MGGooseView *goose;
- (void)startLooping;
@end

@implementation GooseController

- (instancetype)initWithGoose:(MGGooseView *)g {
    if ((self = [super init])) { _goose = g; _containers = [NSPointerArray weakObjectsPointerArray]; }
    return self;
}

- (void)startLooping { [self walkAround]; }

- (void)walkAround {
    [_goose walkForDuration:(arc4random_uniform(3) + 1) speed:kSpeed completionHandler:^(id s){ [self turnToUser]; }];
}

- (void)turnToUser {
    CGRect b = _goose._viewControllerForAncestor.view.bounds;
    CGFloat to = 45; if (_goose.center.x > b.size.width / 2) to = 135;
    [_goose setFacingTo:to animationCompletion:^(id s){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * ((double)arc4random_uniform(30)/10.0)),
            dispatch_get_main_queue(), ^{ [self pickAction]; });
    }];
}

- (void)pickAction {
    // Compact containers
    for (NSInteger i = _containers.count - 1; i >= 0; i--)
        if ([_containers pointerAtIndex:i] == NULL) [_containers removePointerAtIndex:i];

    uint8_t r = arc4random_uniform(50);
    if (_containers.count >= 5 && r >= 40) r += 10;

    if (r >= 40 && r <= 44) {
        // 10% — bring meme
        [self bringMeme:YES];
    } else if (r >= 30 && r < 33) {
        // 6% — crazy mode
        [_goose setFacingTo:0 animationCompletion:^(id s){ [self goCrazy]; }];
    } else if (r >= 45 && r <= 49) {
        // 10% — bring note
        [self bringMeme:NO];
    } else {
        [self turnToRandom];
    }
}

- (void)bringMeme:(BOOL)isImage {
    _container = isImage
        ? [[MGImageContainerView alloc] initWithFrame:CGRectMake(0,0,125,125)]
        : [[MGTextContainerView alloc] initWithFrame:CGRectMake(0,0,125,125)];
    [_containers addPointer:(__bridge void *)_container];
    _container.hidden = YES;
    [_goose._viewControllerForAncestor.view addSubview:_container];
    _container.layer.zPosition = _containers.count;
    _getMemeFromLeft = arc4random_uniform(2);
    [_goose setFacingTo:(_getMemeFromLeft ? 180.0 : 0.0) animationCompletion:^(id s){ [self walkToEdgeForMeme:isImage]; }];
}

- (void)walkToEdgeForMeme:(BOOL)isImage {
    _goose.stopsAtEdge = NO;
    _fhIdx = [_goose addFrameHandler:^(MGGooseView *g, int state) {
        if (state != 0) return;
        CGFloat edge = _getMemeFromLeft ? -15.0 : (g._viewControllerForAncestor.view.frame.size.width - g.frame.size.width + 26);
        BOOL atEdge = _getMemeFromLeft ? (g.frame.origin.x <= edge) : (g.frame.origin.x >= edge);
        if (!atEdge) return;

        [g removeFrameHandlerAtIndex:self->_fhIdx];
        self->_fhIdx = [g addFrameHandler:^(MGGooseView *g2, int st) {
            if (st != 0) return;
            CGPoint c = self->_container.center;
            c.x += g2.positionChange.x;
            self->_container.center = c;
        }];

        CGPoint pt = CGPointMake(_getMemeFromLeft ? -62.5 : (g._viewControllerForAncestor.view.frame.size.width + 62.5), g.center.y);
        CGFloat minY = 62.5, maxY = g._viewControllerForAncestor.view.frame.size.height - 62.5;
        pt.y = fmax(minY, fmin(maxY, pt.y + (CGFloat)arc4random_uniform(100)/10.0 - 5));
        self->_container.center = pt;
        self->_container.hidden = NO;

        if (isImage) {
            [(MGImageContainerView *)self->_container setMemeImage:randomEmbeddedMeme()];
        } else {
            ((MGTextContainerView *)self->_container).textLabel.text = randomEmbeddedNote();
        }

        [g walkForDuration:(2.25 + (CGFloat)arc4random_uniform(15)/10.0) speed:-2.0 completionHandler:^(id s2){
            [g removeFrameHandlerAtIndex:self->_fhIdx];
            g.stopsAtEdge = YES;
            self->_container.hideOnTap = YES;
            self->_container = nil;
            [self turnToUser];
        }];
    }];
    [_goose walkForDuration:-1 speed:4.8 completionHandler:nil];
}

- (void)goCrazy {
    _goose.stopsAtEdge = NO;
    [_goose walkForDuration:-1 speed:kSpeed completionHandler:nil];
    _fhIdx = [_goose addFrameHandler:^(MGGooseView *g, int state) {
        if (state != 0) return;
        if (g.positionChange.x <= -10) {
            [g removeFrameHandlerAtIndex:self->_fhIdx];
            self->_fhIdx = [g addFrameHandler:^(MGGooseView *g2, int st) {
                if (st != 0) return;
                g2.facingTo += (CGFloat)arc4random_uniform(150)/10.0 - 7.5;
            }];
            [g walkForDuration:((CGFloat)arc4random_uniform(30)/10.0) + 6.0 speed:kSpeed * 3.0 completionHandler:^(id s){
                [g removeFrameHandlerAtIndex:self->_fhIdx];
                g.stopsAtEdge = YES;
                [self turnToUser];
            }];
        }
    }];
}

- (void)turnToRandom {
    CGFloat deg = (CGFloat)arc4random_uniform(360);
    for (int i = 0; i < 36; i++) {
        CGRect f = _goose.frame;
        deg += 10;
        f.origin.x += cos(DEG_TO_RAD(deg)) * kSpeed * 5;
        f.origin.y += sin(DEG_TO_RAD(deg)) * kSpeed * 5;
        if (![_goose isFrameAtEdge:f]) break;
    }
    [_goose setFacingTo:deg animationCompletion:^(id s){ [self walkAround]; }];
}
@end

#pragma mark - Pass-through window

@interface MGPassthroughWindow : UIWindow
@end

@implementation MGPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (!hit || hit == self || hit == self.rootViewController.view)
        return nil;
    // Only intercept if hit is a container or inside one
    UIView *v = hit;
    while (v) {
        if ([v isKindOfClass:[MGContainerView class]]) return hit;
        v = v.superview;
    }
    return nil;
}
@end

#pragma mark - Constructor

__attribute__((constructor))
static void MobileGooseInit(void) {
    NSLog(@"[MobileGoose] Loading...");
    g_shadowColor = [UIColor colorWithWhite:0.25 alpha:0.25];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
        if (!scene) return;

        CGRect frame = [UIScreen mainScreen].bounds;
        UIWindow *window = [[MGPassthroughWindow alloc] initWithWindowScene:scene];
        window.frame = frame;
        window.windowLevel = CGFLOAT_MAX / 2.0;
        window.backgroundColor = [UIColor clearColor];
        window.opaque = NO;
        window.userInteractionEnabled = YES;

        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        window.rootViewController = vc;

        MGGooseView *honk = [[MGGooseView alloc] initWithFrame:CGRectZero];
        CGRect gf = CGRectZero;
        gf.size = [honk sizeThatFits:CGSizeZero];
        gf.origin = CGPointMake(arc4random_uniform(frame.size.width - gf.size.width),
                                arc4random_uniform(frame.size.height - gf.size.height));
        honk.frame = gf;
        honk.facingTo = 0;
        honk.layer.zPosition = 100;
        [vc.view addSubview:honk];

        GooseController *ctrl = [[GooseController alloc] initWithGoose:honk];
        [ctrl startLooping];

        objc_setAssociatedObject([UIApplication sharedApplication], "gooseWindow", window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject([UIApplication sharedApplication], "gooseCtrl", ctrl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        window.hidden = NO;
        NSLog(@"[MobileGoose] Honk!");
    });
}
