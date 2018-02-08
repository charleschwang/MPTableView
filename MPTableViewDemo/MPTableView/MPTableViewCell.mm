//
//  MPTableViewCell.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewCell.h"
#import <c++/v1/map>

@implementation MPTableReusableView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, MPTableViewDefaultCellHeight)]) {
        [super setAutoresizingMask:UIViewAutoresizingNone];
        self.reuseIdentifier = reuseIdentifier;
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
        self.reuseIdentifier = [aDecoder decodeObjectForKey:@"_reuseIdentifier"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_reuseIdentifier forKey:@"_reuseIdentifier"];
    [super encodeWithCoder:aCoder];
}

- (UIResponder *)nextResponder {
    return nil;
}

- (void)setReuseIdentifier:(NSString *)reuseIdentifier {
    _reuseIdentifier = [reuseIdentifier copy];
}

- (void)prepareForRecovery {
    
}

- (void)prepareForReuse {
    
}

- (NSString *)description {
    NSString *description = [super description];
    
    return [NSString stringWithFormat:@"%@, reuseIdentifier:%@", description, _reuseIdentifier];
}

@end

#pragma mark -

const CGFloat MPTableViewDefaultCellHeight = 44.;

static CGColor *
_CGColorMPSelectionDefault() {
    static CGColor *selectionCGColor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat color[4] = {0.85, 0.85, 0.85, 1.0};
        CGColorSpace *colorSpaceRef = CGColorSpaceCreateDeviceRGB();
        selectionCGColor = CGColorCreate(colorSpaceRef, color);
        CGColorSpaceRelease(colorSpaceRef);
    });
    return selectionCGColor;
}

static UIColor *
_UIColorMPSelectionDefault() {
    static UIColor *selectionColor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        selectionColor = [UIColor colorWithCGColor:_CGColorMPSelectionDefault()];
    });
    return selectionColor;
}

static CGColor *
_CGColorClearColor() {
    static CGColor *CGColor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat color[4] = {0, 0, 0, 0};
        CGColorSpace *colorSpaceRef = CGColorSpaceCreateDeviceRGB();
        CGColor = CGColorCreate(colorSpaceRef, color);
        CGColorSpaceRelease(colorSpaceRef);
    });
    return CGColor;
}

struct MPCellCachedStatus {
    BOOL highlighted;
    UIColor *backgroundColor;
};

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
_MPCellSetSubviewHighlighted(id subview, std::map<NSUInteger, MPCellCachedStatus> *cacheColorsMap, bool highlighted, bool removeIfUnhighlighted) {
    if (highlighted) {
        MPCellCachedStatus status;
        status.backgroundColor = [(UIView *)subview backgroundColor];
        [(UIView *)subview setBackgroundColor:[UIColor clearColor]];
        
        if ([subview respondsToSelector:@selector(isHighlighted)] && [subview respondsToSelector:@selector(setHighlighted:)]) {
            status.highlighted = [subview isHighlighted];
            [subview setHighlighted:YES];
        }
        
        cacheColorsMap->insert(std::pair<NSUInteger, MPCellCachedStatus>((NSUInteger)subview, status));
    } else {
        std::map<NSUInteger, MPCellCachedStatus>::iterator iter = cacheColorsMap->find((NSUInteger)subview);
        if (iter != cacheColorsMap->end()) {
            MPCellCachedStatus status = iter->second;
            
            if (_UIColorEqualToClearColor([(UIView *)subview backgroundColor])) {
                [(UIView *)subview setBackgroundColor:status.backgroundColor];
            }
            if ([subview respondsToSelector:@selector(isHighlighted)] && [subview respondsToSelector:@selector(setHighlighted:)] && [subview isHighlighted]) {
                [subview setHighlighted:status.highlighted];
            }
            
            if (removeIfUnhighlighted) {
                cacheColorsMap->erase(iter);
            }
        }
    }
}

static void
_MPCellSetSubviewsHighlightedIfNeeded(NSArray *subviews, bool highlighted, std::map<NSUInteger, MPCellCachedStatus> *cacheColorsMap) {
    for (id subview in subviews) {
        static Class _UIButtonClass_MP_ = [UIButton class];
        
        if ([subview isKindOfClass:_UIButtonClass_MP_]) {
            continue;
        }
        
        _MPCellSetSubviewHighlighted(subview, cacheColorsMap, highlighted, NO);
        _MPCellSetSubviewsHighlightedIfNeeded([subview subviews], highlighted, cacheColorsMap);
    }
}

#pragma mark -

@implementation MPTableViewCell {
    CALayer *_fadeAnimationLayer;
    std::map<NSUInteger, MPCellCachedStatus> _cachedSubviewStatusMap;
}

- (void)_initializeData {
    _cachedSubviewStatusMap = std::map<NSUInteger, MPCellCachedStatus>();
    _highlighted = NO;
    _selected = NO;
    
    _fadeAnimationLayer = [[CALayer alloc] init];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!_selectionColor) {
        _selectionColor = _UIColorMPSelectionDefault();
        _fadeAnimationLayer.backgroundColor = _CGColorMPSelectionDefault();
    } else {
        _fadeAnimationLayer.backgroundColor = _selectionColor.CGColor;
    }
    _fadeAnimationLayer.hidden = YES;
    [CATransaction commit];
    [self.layer insertSublayer:_fadeAnimationLayer atIndex:0];
}

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithReuseIdentifier:reuseIdentifier]) {
        [self _initializeData];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        _selectionColor = [aDecoder decodeObjectForKey:@"_selectionColor"];
        [self _initializeData];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_selectionColor forKey:@"_selectionColor"];
    [_fadeAnimationLayer removeFromSuperlayer];
    
    [super encodeWithCoder:aCoder];
    
    [self.layer insertSublayer:_fadeAnimationLayer atIndex:0];
}

- (UIResponder *)nextResponder {
    return [self superview];
}

- (void)dealloc {
    _cachedSubviewStatusMap.clear();
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    if (!(CGSizeEqualToSize(self.frame.size, _fadeAnimationLayer.frame.size))) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        frame.origin = CGPointZero;
        _fadeAnimationLayer.frame = frame;
        [CATransaction commit];
    }
}

- (void)willRemoveSubview:(UIView *)subview {
    if (_selected || _highlighted) {
        _MPCellSetSubviewHighlighted(subview, &_cachedSubviewStatusMap, NO, YES);
    }
    [super willRemoveSubview:subview];
}

- (NSString *)description {
    NSString *description = [super description];
    
    return [NSString stringWithFormat:@"%@, %@, %@", description, _selected ? @"selected" : @"unselected", _highlighted ? @"highlighted" : @"unhighlighted"];
}

- (void)setSelectionColor:(UIColor *)selectionColor {
    if (!selectionColor && !_selectionColor) {
        return;
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!(_selectionColor = selectionColor)) {
        _fadeAnimationLayer.backgroundColor = _CGColorClearColor();
        if (!_selected && !_highlighted) {
            _cachedSubviewStatusMap.clear();
        }
    } else {
        _fadeAnimationLayer.backgroundColor = _selectionColor.CGColor;
    }
    [CATransaction commit];
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
    if (_selected) {
        return;
    }
    [self _setFadeLayerEnable:highlighted animated:animated];
}

- (void)_setFadeLayerEnable:(BOOL)enable animated:(BOOL)animated {
    if (!_selectionColor) {
        if (enable) {
            return;
        } else {
            if (_cachedSubviewStatusMap.size() == 0) {
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
    [self _setSubviewsHighlighted:enable];
    
    if (!enable) {
        _cachedSubviewStatusMap.clear();
    }
}

- (void)_setSubviewsHighlighted:(BOOL)highlighted {
    if (!highlighted && _cachedSubviewStatusMap.size() == 0) {
        return;
    }
    
    _MPCellSetSubviewsHighlightedIfNeeded(self.subviews, highlighted, &_cachedSubviewStatusMap);
}

@end
