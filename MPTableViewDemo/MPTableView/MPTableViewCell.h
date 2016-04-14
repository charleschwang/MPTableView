//
//  MPTableViewCell.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewSupport.h"

UIKIT_EXTERN const CGFloat MPTableViewCellDefaultCellHeight;

@interface MPTableReusableView : UIView

@property (nonatomic, copy, readonly) NSString *identifier;

// If the view can be reused, you must pass in a reuse identifier, or it will not be reused.  You should use the same reuse identifier for all reusableViews of the same form.
- (instancetype)initWithReuseIdentifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

- (void)prepareForDisplaying; // the frame has been set.

- (void)prepareForReuse; // if the reusableView is reusable (has a reuse identifier), this is called just before the reusableView is returned from the table view method dequeueReusableViewWithIdentifier:(or dequeueReusableCellWithIdentifier).  If you override, you don't need to call super.

@end

#pragma mark -

@interface MPTableViewCell : MPTableReusableView

@property (nonatomic, strong) UIColor *selectionColor; // nil is selectionStyleNone

@property (nonatomic, getter=isSelected) BOOL selected; // set selected state. default is NO. animated is NO
@property (nonatomic, getter=isHighlighted) BOOL highlighted; // set highlighted state. default is NO. animated is NO
- (void)setSelected:(BOOL)selected animated:(BOOL)animated; // animate between regular and selected state
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated;

@end
