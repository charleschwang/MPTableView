//
//  MySectionView.m
//  MPTableViewDemo
//
//  Created by apple on 16/3/28.
//  Copyright © 2016年 SMT. All rights reserved.
//

#import "MySectionView.h"

@implementation MySectionView

// By default, the nextResponder return nil in MPTableReusableView, but if we want to let the cell which below in this sectionview can be selected when we are touching this sectionview, we should do this.
- (UIResponder *)nextResponder {
    return self.superview;
}

@end
