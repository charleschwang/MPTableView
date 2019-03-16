//
//  MPTableViewCell.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MPIndexPath.h"

@interface MPTableReusableView : UIView

@property (nonatomic, copy, readonly) NSString *reuseIdentifier;

// If the view can be reused, you must pass in a reuse identifier, or it will not be reused.  You should use the same reuse identifier for all reusable views of the same form.
- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

- (void)prepareForRecovery; // called when the reusable view end displaying (will enter the reuse queue)

- (void)prepareForReuse; // if the reusable view is reusable (has a reuse identifier), this is called just before the reusable view is returned from the table view method dequeueReusableViewWithIdentifier:(or dequeueReusableCellWithIdentifier).  If you override, you don't need to call super.

@end

#pragma mark -

UIKIT_EXTERN const CGFloat MPTableViewDefaultCellHeight;

@interface MPTableViewCell : MPTableReusableView

@property (nonatomic, strong) UIColor *selectionColor; // if nil, it will be like UITableViewCellSelectionStyleNone.

@property (nonatomic, getter=isSelected) BOOL selected; // set selected state. default is NO. animated is NO, you can rewrite -setSelected: to turn animated to YES in subclass([super setSelected:selected animated:YES]).
@property (nonatomic, getter=isHighlighted) BOOL highlighted; // set highlighted state. default is NO. animated is NO.
- (void)setSelected:(BOOL)selected animated:(BOOL)animated; // animate between regular and selected state
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated;

@end
