//
//  MPTableViewCell.h
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015 PBA. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif

@interface MPTableViewReusableView : UIView

@property (nonatomic, copy, readonly) NSString *reuseIdentifier;

// If the view can be reused, you must pass in a reuse identifier, or it will not be reused. You should use the same reuse identifier for all reusable views of the same form.
- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

- (void)prepareForRecycle; // called when the reusable view ends displaying, override as needed to clean up before caching.

- (void)prepareForReuse; // if the reusable view is reusable (has a reuse identifier), this is called just before the reusable view is returned from the table view method -dequeueReusableViewWithIdentifier: (or -dequeueReusableCellWithIdentifier). If you override, you don't need to call super.

/**
 Returns the height of this reusable view for a given width (which will modify its width during calculation),
 calculated based on its auto layout constraints.
 
 This method will only be used by UITableView in estimatedHeight mode if and only if the table view's dataSource
 does not provide -MPTableView:heightForRowAtIndexPath: or similar methods.
 
 By default, it uses -systemLayoutSizeFittingSize: to compute the height.
 If the default computed height is inaccurate, or if you wish to implement custom height logic,
 subclasses can override this behavior to calculate height manually, e.g. using
 -systemLayoutSizeFittingSize:withHorizontalFittingPriority:verticalFittingPriority: or other layout-specific logic.
 */
- (CGFloat)heightAfterLayoutWithFittingWidth:(CGFloat)width;

@end

#pragma mark -

UIKIT_EXTERN const CGFloat MPTableViewDefaultCellHeight;

@interface MPTableViewCell : MPTableViewReusableView

@property (nonatomic, strong) UIColor *selectionColor; // if nil, behaves the same as UITableViewCellSelectionStyleNone.

@property (nonatomic, getter=isSelected) BOOL selected; // set selected state. Default is NO. Animated is NO, you can rewrite -setSelected: to turn animated to YES in subclass ([super setSelected:selected animated:YES]).
@property (nonatomic, getter=isHighlighted) BOOL highlighted; // set highlighted state. Default is NO. Animated is NO.

- (void)setSelectionColor:(UIColor *)selectionColor animated:(BOOL)animated;

- (void)setSelected:(BOOL)selected animated:(BOOL)animated; // animate between regular and selected state
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated;

@end
