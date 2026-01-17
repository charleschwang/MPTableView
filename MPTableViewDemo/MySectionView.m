//
//  MySectionView.m
//  MPTableViewDemo
//
//  Created by apple on 16/3/28.
//  Copyright © 2016年 SMT. All rights reserved.
//

#import "MySectionView.h"

@implementation MySectionView

// The nextResponder is nil in MPTableViewReusableView, forward touch events to the underlying cell by redirecting the responder chain.
- (UIResponder *)nextResponder {
    return self.superview;
}

@end
