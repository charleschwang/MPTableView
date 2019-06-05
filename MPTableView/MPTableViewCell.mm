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

- (UIResponder *)_mp_superNextResponder {
    return [super nextResponder];
}

- (void)setReuseIdentifier:(NSString *)reuseIdentifier {
    _reuseIdentifier = [reuseIdentifier copy];
}

- (void)prepareForRecycle {
    
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
_CGColorMPSelectionColor() {
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
_UIColorMPSelectionColor() {
    static UIColor *selectionUIColor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        selectionUIColor = [UIColor colorWithCGColor:_CGColorMPSelectionColor()];
    });
    return selectionUIColor;
}

static CGColor *
_CGColorClearColor() {
    static CGColor *clearCGColor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat color[4] = {0, 0, 0, 0};
        CGColorSpace *colorSpaceRef = CGColorSpaceCreateDeviceRGB();
        clearCGColor = CGColorCreate(colorSpaceRef, color);
        CGColorSpaceRelease(colorSpaceRef);
    });
    return clearCGColor;
}

struct MPCellCachedStatus {
    BOOL opaqueRetain;
    BOOL highlightedRetain;
    BOOL backgroundColorRetain;
    UIColor *backgroundColor;
};

static MPCellCachedStatus
MPGetCellCachedStatus() {
    MPCellCachedStatus status;
    status.opaqueRetain = NO;
    status.highlightedRetain = NO;
    status.backgroundColorRetain = NO;
    status.backgroundColor = nil;
    return status;
}

NS_INLINE bool
MPNeedCacheCellStatus(MPCellCachedStatus status) {
    return status.opaqueRetain || status.highlightedRetain || status.backgroundColorRetain;
}

//static bool
//_UIColorEqualToClearColor(UIColor *color) {
//    if (!color) {
//        return YES;
//    } else {
//        CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
//        return [color getRed:&red green:&green blue:&blue alpha:&alpha];
//    }
//}

static void
MPCellSetSubviewsHighlighted(NSArray *, bool , std::map<NSUInteger, MPCellCachedStatus> *);

static void
MPCellSetSubviewHighlighted(UIView *subview, std::map<NSUInteger, MPCellCachedStatus> *cacheColorsMap, bool highlighted, bool removeIfUnhighlighted) {
    static Class _MP_UIButtonClass = [UIButton class];
    
    if (highlighted) {
        MPCellCachedStatus status = MPGetCellCachedStatus();
        
        if (subview.backgroundColor != [UIColor clearColor]) { // this '!=' was verified
            status.backgroundColor = [subview backgroundColor];
            status.backgroundColorRetain = YES;
            [subview setBackgroundColor:[UIColor clearColor]];
        }
        
        if ([subview isOpaque]) {
            status.opaqueRetain = YES;
            subview.opaque = NO;
        }
        
        if (![subview isKindOfClass:_MP_UIButtonClass]) {
            if ([subview respondsToSelector:@selector(isHighlighted)] && [subview respondsToSelector:@selector(setHighlighted:)] && ![(id)subview isHighlighted]) {
                status.highlightedRetain = YES;
                [(id)subview setHighlighted:YES];
            }
            
            MPCellSetSubviewsHighlighted([subview subviews], highlighted, cacheColorsMap);
        }
        
        if (MPNeedCacheCellStatus(status)) {
            cacheColorsMap->insert(std::pair<NSUInteger, MPCellCachedStatus>((NSUInteger)subview, status));
        }
    } else {
        std::map<NSUInteger, MPCellCachedStatus>::iterator iter = cacheColorsMap->find((NSUInteger)subview);
        if (iter != cacheColorsMap->end()) {
            MPCellCachedStatus status = iter->second;
            
            if (status.backgroundColorRetain && subview.backgroundColor == [UIColor clearColor]) {
                [subview setBackgroundColor:status.backgroundColor];
            }
            
            if (status.opaqueRetain && ![subview isOpaque]) {
                subview.opaque = YES;
            }
            
            if (![subview isKindOfClass:_MP_UIButtonClass]) {
                if (status.highlightedRetain && [(id)subview isHighlighted]) {
                    [(id)subview setHighlighted:NO];
                }
                
                MPCellSetSubviewsHighlighted([subview subviews], highlighted, cacheColorsMap);
            }
            
            if (removeIfUnhighlighted) {
                cacheColorsMap->erase(iter);
            }
        }
    }
}

static void
MPCellSetSubviewsHighlighted(NSArray *subviews, bool highlighted, std::map<NSUInteger, MPCellCachedStatus> *cacheColorsMap) {
    for (UIView *subview in subviews) {
        MPCellSetSubviewHighlighted(subview, cacheColorsMap, highlighted, NO);
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
    
    if ([CATransaction disableActions]) {
        if (!_selectionColor) {
            _selectionColor = _UIColorMPSelectionColor();
            _fadeAnimationLayer.backgroundColor = _CGColorMPSelectionColor();
        } else {
            _fadeAnimationLayer.backgroundColor = _selectionColor.CGColor;
        }
        _fadeAnimationLayer.hidden = YES;
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        
        if (!_selectionColor) {
            _selectionColor = _UIColorMPSelectionColor();
            _fadeAnimationLayer.backgroundColor = _CGColorMPSelectionColor();
        } else {
            _fadeAnimationLayer.backgroundColor = _selectionColor.CGColor;
        }
        _fadeAnimationLayer.hidden = YES;
        
        [CATransaction commit];
    }
    
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
    return [super _mp_superNextResponder];
}

- (void)dealloc {
    _cachedSubviewStatusMap.clear();
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    if (!(CGSizeEqualToSize(frame.size, _fadeAnimationLayer.frame.size))) {
        frame.origin = CGPointZero;
        if ([CATransaction disableActions]) {
            _fadeAnimationLayer.frame = frame;
        } else {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            
            _fadeAnimationLayer.frame = frame;
            
            [CATransaction commit];
        }
    }
}


// This can only affect subviews of MPTableViewCell, but not other lower-level descendents. The UITableViewCell using a private API named -[UIView _descendent:willMoveFromSuperview:toSuperview:] to solve it.
- (void)willRemoveSubview:(UIView *)subview {
    if (_selected || _highlighted) {
        MPCellSetSubviewHighlighted(subview, &_cachedSubviewStatusMap, NO, YES);
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
    
    if ([CATransaction disableActions]) {
        if (!(_selectionColor = selectionColor)) {
            _fadeAnimationLayer.backgroundColor = _CGColorClearColor();
            if (!_selected && !_highlighted) {
                _cachedSubviewStatusMap.clear();
            }
        } else {
            _fadeAnimationLayer.backgroundColor = _selectionColor.CGColor;
        }
    } else {
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
    [self _setFadeLayerEnabled:selected animated:animated];
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
    [self _setFadeLayerEnabled:highlighted animated:animated];
}

- (void)_setFadeLayerEnabled:(BOOL)enabled animated:(BOOL)animated {
    if (!_selectionColor) {
        if (enabled) {
            return;
        } else {
            if (_cachedSubviewStatusMap.size() == 0) {
                return;
            }
        }
    }
    
    if (animated) {
        _fadeAnimationLayer.hidden = !enabled;
    } else {
        if ([CATransaction disableActions]) {
            _fadeAnimationLayer.hidden = !enabled;
        } else {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            
            _fadeAnimationLayer.hidden = !enabled;
            
            [CATransaction commit];
        }
    }
    [self _setSubviewsHighlighted:enabled];
    
    if (!enabled) {
        _cachedSubviewStatusMap.clear();
    }
}

- (void)_setSubviewsHighlighted:(BOOL)highlighted {
    if (!highlighted && _cachedSubviewStatusMap.size() == 0) {
        return;
    }
    
    MPCellSetSubviewsHighlighted(self.subviews, highlighted, &_cachedSubviewStatusMap);
}

@end
