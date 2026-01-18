//
//  MPTableViewCell.m
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015 PBA. All rights reserved.
//

#import "MPTableViewCell.h"
#import <unordered_map>

using namespace std;

@implementation MPTableViewReusableView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, MPTableViewDefaultCellHeight)]) {
        [super setAutoresizingMask:UIViewAutoresizingNone];
        self.reuseIdentifier = reuseIdentifier;
    }
    
    return self;
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

- (void)setAutoresizingMask:(UIViewAutoresizing)autoresizingMask {
    // do nothing - no autoresizingMask support
}

- (UIResponder *)nextResponder {
    return nil;
}

- (UIResponder *)_defaultNextResponder {
    return [super nextResponder];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@; reuseIdentifier = %@", [super description], _reuseIdentifier];
}

- (void)setReuseIdentifier:(NSString *)reuseIdentifier {
    _reuseIdentifier = [reuseIdentifier copy];
}

- (void)prepareForRecycle {
    
}

- (void)prepareForReuse {
    
}

- (CGFloat)heightAfterLayoutWithFittingWidth:(CGFloat)width {
    CGRect frame = self.frame;
    if (frame.size.width != width) {
        frame.size.width = width;
        self.frame = frame;
    }
    
    [self layoutIfNeeded];
    return [self systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)].height;
}

@end

#pragma mark -

const CGFloat MPTableViewDefaultCellHeight = 44.0;

static CGColor *
MPTableViewCellSelectionCGColor() {
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
MPTableViewCellSelectionUIColor() {
    static UIColor *selectionUIColor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        selectionUIColor = [UIColor colorWithCGColor:MPTableViewCellSelectionCGColor()];
    });
    
    return selectionUIColor;
}

static CGColor *
MPTableViewCellClearCGColor() {
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

struct MPSubviewStatus {
    BOOL isOpaqueRetained;
    BOOL isHighlightedRetained;
    BOOL isBackgroundColorRetained; // necessary
    UIColor *backgroundColor;
};

typedef unordered_map<uintptr_t, MPSubviewStatus> MPSubviewStatusMap;

NS_INLINE bool
MPNeedsCacheSubviewStatus(const MPSubviewStatus &status) {
    return status.isOpaqueRetained || status.isHighlightedRetained || status.isBackgroundColorRetained;
}

static void
MPSetSubviewsHighlighted(NSArray *, bool, MPSubviewStatusMap &);

static void
MPSetSubviewHighlighted(UIView *subview, MPSubviewStatusMap &subviewStatusMap, bool highlighted, bool shouldRemoveStatusIfUnhighlighted) {
    static Class _UIButtonClass = [UIButton class];
    
    if (highlighted) {
        MPSubviewStatus status = MPSubviewStatus();
        
        if (subview.backgroundColor != [UIColor clearColor]) { // safe here
            status.backgroundColor = [subview backgroundColor]; // may be nil
            status.isBackgroundColorRetained = YES;
            [subview setBackgroundColor:[UIColor clearColor]];
        }
        
        if ([subview isOpaque]) {
            status.isOpaqueRetained = YES;
            subview.opaque = NO;
        }
        
        if (![subview isKindOfClass:_UIButtonClass]) {
            if ([subview respondsToSelector:@selector(isHighlighted)] && [subview respondsToSelector:@selector(setHighlighted:)] && ![(id)subview isHighlighted]) {
                status.isHighlightedRetained = YES;
                [(id)subview setHighlighted:YES];
            }
            
            MPSetSubviewsHighlighted([subview subviews], highlighted, subviewStatusMap);
        }
        
        if (MPNeedsCacheSubviewStatus(status)) {
            subviewStatusMap.insert(pair<uintptr_t, MPSubviewStatus>((uintptr_t)subview, status));
        }
    } else {
        auto iter = subviewStatusMap.find((uintptr_t)subview);
        if (iter != subviewStatusMap.end()) {
            const MPSubviewStatus &status = iter->second;
            
            if (status.isBackgroundColorRetained && subview.backgroundColor == [UIColor clearColor]) {
                [subview setBackgroundColor:status.backgroundColor];
            }
            
            if (status.isOpaqueRetained && ![subview isOpaque]) {
                subview.opaque = YES;
            }
            
            if (![subview isKindOfClass:_UIButtonClass]) {
                if (status.isHighlightedRetained && [(id)subview isHighlighted]) {
                    [(id)subview setHighlighted:NO];
                }
                
                MPSetSubviewsHighlighted([subview subviews], highlighted, subviewStatusMap);
            }
            
            if (shouldRemoveStatusIfUnhighlighted) {
                subviewStatusMap.erase(iter);
            }
        }
    }
}

static void
MPSetSubviewsHighlighted(NSArray *subviews, bool highlighted, MPSubviewStatusMap &subviewStatusMap) {
    for (UIView *subview in subviews) {
        MPSetSubviewHighlighted(subview, subviewStatusMap, highlighted, NO);
    }
}

#pragma mark -

@implementation MPTableViewCell {
    CALayer *_selectionLayer;
    MPSubviewStatusMap _subviewStatusMap;
}

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithReuseIdentifier:reuseIdentifier]) {
        [self _setupComponents];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        _selectionColor = [aDecoder decodeObjectForKey:@"_selectionColor"];
        [self _setupComponents];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_selectionColor forKey:@"_selectionColor"];
    [_selectionLayer removeFromSuperlayer];
    
    [super encodeWithCoder:aCoder];
    
    [self.layer insertSublayer:_selectionLayer atIndex:0];
}

- (void)_setupComponents {
    _highlighted = NO;
    _selected = NO;
    
    _selectionLayer = [[CALayer alloc] init];
    
    if ([CATransaction disableActions]) {
        _selectionLayer.hidden = YES;
        if (!_selectionColor) {
            _selectionColor = MPTableViewCellSelectionUIColor();
            _selectionLayer.backgroundColor = MPTableViewCellSelectionCGColor();
        } else {
            _selectionLayer.backgroundColor = _selectionColor.CGColor;
        }
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        
        _selectionLayer.hidden = YES;
        if (!_selectionColor) {
            _selectionColor = MPTableViewCellSelectionUIColor();
            _selectionLayer.backgroundColor = MPTableViewCellSelectionCGColor();
        } else {
            _selectionLayer.backgroundColor = _selectionColor.CGColor;
        }
        
        [CATransaction commit];
    }
    
    [self.layer insertSublayer:_selectionLayer atIndex:0];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    if (!(CGSizeEqualToSize(frame.size, _selectionLayer.frame.size))) {
        frame.origin = CGPointZero;
        if ([CATransaction disableActions]) {
            _selectionLayer.frame = frame;
        } else {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            
            _selectionLayer.frame = frame;
            
            [CATransaction commit];
        }
    }
}

// willRemoveSubview only affects direct subviews, manually removing deeper descendants relies on a UIView private API -[UIView _descendant:willMoveFromSuperview:toSuperview:], not accessible here, and may cause incorrect selection appearance.
- (void)willRemoveSubview:(UIView *)subview {
    if (_selected || _highlighted) {
        MPSetSubviewHighlighted(subview, _subviewStatusMap, NO, YES);
    }
    
    [super willRemoveSubview:subview];
}

- (UIResponder *)nextResponder {
    return [super _defaultNextResponder];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@; %@; %@", [super description], _selected ? @"selected" : @"unselected", _highlighted ? @"highlighted" : @"unhighlighted"];
}

- (void)setSelectionColor:(UIColor *)selectionColor {
    [self setSelectionColor:selectionColor animated:NO];
}

- (void)setSelectionColor:(UIColor *)selectionColor animated:(BOOL)animated {
    if (!selectionColor && !_selectionColor) {
        return;
    }
    
    if (animated) {
        if (selectionColor) {
            _selectionLayer.backgroundColor = selectionColor.CGColor;
        } else {
            _selectionLayer.backgroundColor = MPTableViewCellClearCGColor();
            if (_selected || _highlighted) {
                [self _setSelectionLayerAndSubviewsHighlighted:NO animated:YES];
            }
        }
    } else {
        if ([CATransaction disableActions]) {
            if (selectionColor) {
                _selectionLayer.backgroundColor = selectionColor.CGColor;
            } else {
                _selectionLayer.backgroundColor = MPTableViewCellClearCGColor();
                if (_selected || _highlighted) {
                    [self _setSelectionLayerAndSubviewsHighlighted:NO animated:YES]; // verified
                }
            }
        } else {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            
            if (selectionColor) {
                _selectionLayer.backgroundColor = selectionColor.CGColor;
            } else {
                _selectionLayer.backgroundColor = MPTableViewCellClearCGColor();
                if (_selected || _highlighted) {
                    [self _setSelectionLayerAndSubviewsHighlighted:NO animated:YES];
                }
            }
            
            [CATransaction commit];
        }
    }
    
    _selectionColor = selectionColor;
}

- (void)setSelected:(BOOL)selected {
    [self setSelected:selected animated:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    if (_selected == selected) {
        return;
    }
    
    _selected = selected;
    if (_selected && _highlighted) {
        return;
    }
    
    if (!_selectionColor) {
        return;
    }
    
    [self _setSelectionLayerAndSubviewsHighlighted:selected animated:animated];
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
    
    if (!_selectionColor) {
        return;
    }
    
    [self _setSelectionLayerAndSubviewsHighlighted:highlighted animated:animated];
}

- (void)_setSelectionLayerAndSubviewsHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    if (animated) {
        _selectionLayer.hidden = !highlighted;
    } else {
        if ([CATransaction disableActions]) {
            _selectionLayer.hidden = !highlighted;
        } else {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            
            _selectionLayer.hidden = !highlighted;
            
            [CATransaction commit];
        }
    }
    
    [self _setSubviewsHighlighted:highlighted];
}

- (void)_setSubviewsHighlighted:(BOOL)highlighted {
    if (!highlighted && _subviewStatusMap.size() == 0) {
        return;
    }
    
    MPSetSubviewsHighlighted(self.subviews, highlighted, _subviewStatusMap);
    if (!highlighted) {
        _subviewStatusMap.clear(); // unordered_map::clear checks size internally
    }
}

@end
