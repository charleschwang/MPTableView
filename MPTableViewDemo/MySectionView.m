//
//  MySectionView.m
//  MPTableViewDemo
//
//  Created by apple on 16/3/28.
//  Copyright © 2016年 SMT. All rights reserved.
//

#import "MySectionView.h"

@implementation MySectionView

// If we do not do this, cell might be selected when we touching this section view.
// Similarly, you may not want to do this
- (UIResponder *)nextResponder {
    return nil;
}

@end
