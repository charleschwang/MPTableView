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

- (UIResponder *)_backup_nextResponder {
    return [super nextResponder];
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
    BOOL opaqueRetain;
    BOOL highlightedRetain;
    UIColor *backgroundColor;
    BOOL backgroundColorRetain;
};

static MPCellCachedStatus MPCellCachedStatusGet() {
    MPCellCachedStatus status;
    status.opaqueRetain = NO;
    status.highlightedRetain = NO;
    status.backgroundColor = nil;
    status.backgroundColorRetain = NO;
    return status;
}

NS_INLINE bool MPCellCachedStatusNeedRecord(MPCellCachedStatus status) {
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
_MPCellSetSubviewsHighlighted(NSArray *, bool , std::map<NSUInteger, MPCellCachedStatus> *);

static void
_MPCellSetSubviewHighlighted(UIView *subview, std::map<NSUInteger, MPCellCachedStatus> *cacheColorsMap, bool highlighted, bool removeIfUnhighlighted) {
    static Class _UIButtonClass_MP_ = [UIButton class];
    
    if (highlighted) {
        MPCellCachedStatus status = MPCellCachedStatusGet();
        
        if (subview.backgroundColor != [UIColor clearColor]) { // this '!=' was verified
            status.backgroundColor = [subview backgroundColor];
            status.backgroundColorRetain = YES;
            [subview setBackgroundColor:[UIColor clearColor]];
        }
        
        if ([subview isOpaque]) {
            status.opaqueRetain = YES;
            subview.opaque = NO;
        }
        
        if (![subview isKindOfClass:_UIButtonClass_MP_]) {
            if ([subview respondsToSelector:@selector(isHighlighted)] && [subview respondsToSelector:@selector(setHighlighted:)] && ![(id)subview isHighlighted]) {
                status.highlightedRetain = YES;
                [(id)subview setHighlighted:YES];
            }
            
            _MPCellSetSubviewsHighlighted([subview subviews], highlighted, cacheColorsMap);
        }
        
        if (MPCellCachedStatusNeedRecord(status)) {
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
            
            if (![subview isKindOfClass:_UIButtonClass_MP_]) {
                if (status.highlightedRetain && [(id)subview isHighlighted]) {
                    [(id)subview setHighlighted:NO];
                }
                
                _MPCellSetSubviewsHighlighted([subview subviews], highlighted, cacheColorsMap);
            }
            
            if (removeIfUnhighlighted) {
                cacheColorsMap->erase(iter);
            }
        }
    }
}

static void
_MPCellSetSubviewsHighlighted(NSArray *subviews, bool highlighted, std::map<NSUInteger, MPCellCachedStatus> *cacheColorsMap) {
    for (UIView *subview in subviews) {
        _MPCellSetSubviewHighlighted(subview, cacheColorsMap, highlighted, NO);
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
    return [super _backup_nextResponder];
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


// This can only affect subviews of MPTableViewCell, but not other lower-level descendents. The UITableViewCell using a private API named -[UIView _descendent:willMoveFromSuperview:toSuperview:] to solve it.
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
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _fadeAnimationLayer.hidden = !enabled;
        [CATransaction commit];
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
    
    _MPCellSetSubviewsHighlighted(self.subviews, highlighted, &_cachedSubviewStatusMap);
}

@end
