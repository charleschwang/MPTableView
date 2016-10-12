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

- (instancetype)initWithReuseIdentifier:(NSString *)identifier {
    if (self = [super initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, MPTableViewDefaultCellHeight)]) {
        [super setAutoresizingMask:UIViewAutoresizingNone];
        self.identifier = identifier;
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
        self.identifier = [aDecoder decodeObjectForKey:@"_identifier"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_identifier forKey:@"_identifier"];
    [super encodeWithCoder:aCoder];
}

- (void)setIdentifier:(NSString *)identifier {
    _identifier = [identifier copy];
}

- (void)prepareForRecovery {
    
}

- (void)prepareForReuse {
    
}

- (NSString *)description {
    NSString *description = [super description];
    
    return [NSString stringWithFormat:@"%@, identifier:%@", description, _identifier];
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
        selectionCGColor = CGColorCreate(CGColorSpaceCreateDeviceRGB(), color);
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
        CGColor = CGColorCreate(CGColorSpaceCreateDeviceRGB(), color);
    });
    return CGColor;
}

@implementation MPTableViewCell {
    CALayer *_fadeAnimationLayer;
    std::map<NSUInteger, UIColor *> _cachedSubviewColorsMap;
}

- (void)_initializeData {
    _cachedSubviewColorsMap = std::map<NSUInteger, UIColor *>();
    _highlighted = NO;
    _selected = NO;
    
    _selectionColor = _UIColorMPSelectionDefault();
    
    _fadeAnimationLayer = [[CALayer alloc] init];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fadeAnimationLayer.backgroundColor = _CGColorMPSelectionDefault();
    _fadeAnimationLayer.hidden = YES;
    [CATransaction commit];
    [self.layer insertSublayer:_fadeAnimationLayer atIndex:0];
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

- (void)encodeWithCoder:(NSCoder *)aCoder {
    self.highlighted = self.selected = NO;
    [self setSelectionColor:nil];
    [_fadeAnimationLayer removeFromSuperlayer];
    
    [super encodeWithCoder:aCoder];
}

- (void)dealloc {
    _cachedSubviewColorsMap.clear();
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
        std::map<NSUInteger, UIColor *>::iterator iter = _cachedSubviewColorsMap.find((NSUInteger)subview);
        if (iter != _cachedSubviewColorsMap.end() && _UIColorEqualToClearColor([subview backgroundColor])) {
            [subview setBackgroundColor:iter->second];
        }
    }
    [super willRemoveSubview:subview];
}

- (NSString *)description {
    NSString *description = [super description];
    
    return [NSString stringWithFormat:@"%@, %@, %@", description, _selected ? @"selected" : @"unselected", _highlighted ? @"highlighted" : @"unhighlighted"];
}

- (void)setSelectionColor:(UIColor *)selectionColor {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!(_selectionColor = selectionColor)) {
        _fadeAnimationLayer.backgroundColor = _CGColorClearColor();
        if (!_selected && !_highlighted) {
            _cachedSubviewColorsMap.clear();
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
            if (_cachedSubviewColorsMap.size() == 0) {
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
    
    if (!_selectionColor && _cachedSubviewColorsMap.size()) {
        _cachedSubviewColorsMap.clear();
    }
}

- (void)_setSubviewsColorWithHighlighted:(BOOL)highlighted {
    if (!highlighted && _cachedSubviewColorsMap.size() == 0) {
        return;
    }
    
    _setSubviewsHighlightedAndCachedColorIfNeeded(self.subviews, highlighted, &_cachedSubviewColorsMap);
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
    for (UIView *subview in subviews) {
        if ([subview respondsToSelector:@selector(setHighlighted:)]) {
            [(id)subview setHighlighted:highlighted];
        }
        if (highlighted) {
            cacheColorsMap->insert(std::pair<NSUInteger, UIColor *>((NSUInteger)subview, [subview backgroundColor]));
            [subview setBackgroundColor:[UIColor clearColor]];
        } else {
            std::map<NSUInteger, UIColor *>::iterator iter = cacheColorsMap->find((NSUInteger)subview);
            if (iter != cacheColorsMap->end() && _UIColorEqualToClearColor([subview backgroundColor])) {
                [subview setBackgroundColor:iter->second];
            }
        }
        _setSubviewsHighlightedAndCachedColorIfNeeded([subview subviews], highlighted, cacheColorsMap);
    }
}

@end
