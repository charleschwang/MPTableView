//
//  MySectionView.m
//  MPTableViewDemo
//
//  Created by apple on 16/3/28.
//  Copyright © 2016年 SMT. All rights reserved.
//

#import "MySectionView.h"

@implementation MySectionView

// By default, the nextResponder is nil in MPTableReusableView, but if we want to touch a cell which below in this view by through this view, we should do this.
- (UIResponder *)nextResponder {
    return self.superview;
}

@end
