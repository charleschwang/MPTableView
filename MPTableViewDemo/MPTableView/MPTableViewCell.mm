//
//  MPTableViewCell.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewCell.h"
#import <c++/v1/map>

const CGFloat MPTableViewCellDefaultCellHeight = 44.;

@implementation MPTableReusableView

- (instancetype)initWithReuseIdentifier:(NSString *)identifier {
    if (self = [super initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen]bounds].size.width, MPTableViewCellDefaultCellHeight)]) {
        [super setAutoresizingMask:UIViewAutoresizingNone];
        self.identifier = identifier;
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)setAutoresizingMask:(UIViewAutoresizing)autoresizingMask {
    // ...
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithReuseIdentifier:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [super setAutoresizingMask:UIViewAutoresizingNone];
        self.identifier = NSStringFromClass([self class]);
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)setIdentifier:(NSString *)identifier {
    _identifier = [identifier copy];
}

- (void)prepareForDisplaying {
    
}

- (void)prepareForReuse {
    
}

@end

#pragma mark -

@implementation MPTableViewCell {
    CALayer *_fadeAnimationLayer;
    std::map<NSUInteger, UIColor *> *_cachedSubviewColorsMap;
}

- (void)_initializeData {
    _cachedSubviewColorsMap = new std::map<NSUInteger, UIColor *>;
    _highlighted = NO;
    _selected = NO;
    
    _fadeAnimationLayer = [CALayer new];
    CGFloat color[4] = {0.85, 0.85, 0.85, 1.0};
    _selectionColor = [UIColor colorWithCGColor:_fadeAnimationLayer.backgroundColor = CGColorCreate(CGColorSpaceCreateDeviceRGB(), color)];
    _fadeAnimationLayer.hidden = YES;
    [self.layer addSublayer:_fadeAnimationLayer];
}

- (instancetype)initWithReuseIdentifier:(NSString *)identifier {
    if (self = [super initWithReuseIdentifier:identifier]) {
        [self _initializeData];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self _initializeData];
    }
    return self;
}

- (void)dealloc {
    delete _cachedSubviewColorsMap;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    if (!(CGSizeEqualToSize(self.frame.size, _fadeAnimationLayer.frame.size))) {
        frame.origin = CGPointZero;
        _fadeAnimationLayer.frame = frame;
    }
}

- (void)setSelectionColor:(UIColor *)selectionColor {
    if (!(_selectionColor = selectionColor)) {
        CGFloat color[4] = {0.0, 0.0, 0.0, 0.0};
        _fadeAnimationLayer.backgroundColor = CGColorCreate(CGColorSpaceCreateDeviceRGB(), color);
        if (!_selected && !_highlighted) {
            _cachedSubviewColorsMap->clear();
        }
    } else {
        _fadeAnimationLayer.backgroundColor = _selectionColor.CGColor;
    }
}

- (void)setSelected:(BOOL)selected {
    [self setSelected:selected animated:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    if (_selected == selected) {
        return;
    }
    _selected = selected;
    if (selected && _highlighted) {
        return;
    }
    [self _setFadeLayerEnable:selected animated:animated];
}

- (void)setHighlighted:(BOOL)highlighted {
    [self setHighlighted:highlighted animated:NO];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    if (_highlighted == highlighted) {
        return;
    }
    _highlighted = highlighted;
    if (!highlighted && _selected) {
        return;
    }
    [self _setFadeLayerEnable:highlighted animated:animated];
}

- (void)_setFadeLayerEnable:(BOOL)enable animated:(BOOL)animated {
    if (!_selectionColor) {
        if (enable) {
            return;
        } else {
            if (_cachedSubviewColorsMap->size() == 0) {
                return;
            }
        }
    }
    
    if (animated) {
        _fadeAnimationLayer.hidden = !enable;
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _fadeAnimationLayer.hidden = !enable;
        [CATransaction commit];
    }
    [self _setSubviewsColorWithHighlighted:enable];
    
    if (!_selectionColor && _cachedSubviewColorsMap->size()) {
        _cachedSubviewColorsMap->clear();
    }
}

- (void)_setSubviewsColorWithHighlighted:(BOOL)highlighted {
    if (!highlighted && _cachedSubviewColorsMap->size() == 0) {
        return;
    }
    _setSubviewsHighlightedAndCachedColorIfNeeded(self.subviews, highlighted, _cachedSubviewColorsMap);
}

static bool
_UIColorEqualToClearColor(UIColor *color) {
    if (!color) {
        return YES;
    } else {
        CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
        return [color getRed:&red green:&green blue:&blue alpha:&alpha];
    }
}

static void
_setSubviewsHighlightedAndCachedColorIfNeeded(NSArray *subviews, bool highlighted, std::map<NSUInteger, UIColor *> *cacheColorsMap) {
    for (id subview in subviews) {
        if (highlighted) {
            cacheColorsMap->insert(std::pair<NSUInteger, UIColor *>((NSUInteger)subview, [subview backgroundColor]));
            [subview setBackgroundColor:[UIColor clearColor]];
        } else {
            UIColor *cacheColor = cacheColorsMap->at((NSUInteger)subview);
            if (cacheColor) {
                if (_UIColorEqualToClearColor([subview backgroundColor])) { // clearColor
                    [subview setBackgroundColor:cacheColor];
                }
            }
        }
        
        if ([subview respondsToSelector:@selector(setHighlighted:)] && ![subview isKindOfClass:[UIButton class]]) {
            [subview setHighlighted:highlighted];
        }
        
        _setSubviewsHighlightedAndCachedColorIfNeeded([subview subviews], highlighted, cacheColorsMap);
    }
}

//static void
//_setSubviewsHighlightedAndCachedColorIfNeeded(NSArray *subviews, bool highlighted, NSMutableDictionary *cacheColorsDic, MPIndexPath *indexPath) {
//    NSUInteger _count = subviews.count;
//    for (NSInteger i = 0; i < _count; i++) {
//        id subview = subviews[i];
//        
//        MPIndexPath *newIndexPath = [indexPath copy];
//        [newIndexPath addIndex:i];
//        
//        if (highlighted) {
//            [cacheColorsDic setObject:[subview backgroundColor] forKey:newIndexPath];
//            [subview setBackgroundColor:[UIColor clearColor]];
//        } else {
//            [subview setBackgroundColor:[cacheColorsDic objectForKey:newIndexPath]];
//        }
//        
//        if ([subview respondsToSelector:@selector(setHighlighted:)] && ![subview isKindOfClass:[UIButton class]]) {
//            [subview setHighlighted:highlighted];
//        }
//        
//        _setSubviewsHighlightedAndCachedColorIfNeeded([subview subviews], highlighted, cacheColorsDic, indexPath);
//    }
//}

@end
