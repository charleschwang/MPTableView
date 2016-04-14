//
//  MyDemoCell.m
//  MPTableViewDemo
//
//  Created by apple on 16/4/1.
//  Copyright © 2016年 SMT. All rights reserved.
//

#import "MyDemoCell.h"

@implementation MyDemoCell

- (instancetype)initWithReuseIdentifier:(NSString *)identifier {
    if (self = [super initWithReuseIdentifier:identifier]) {
        CGRect frame = self.frame;
        frame.origin = CGPointZero;
        self.label_title = [[UILabel alloc]initWithFrame:frame];
        self.label_title.backgroundColor = [UIColor colorWithRed:arc4random() % 10 / 10. green:arc4random() % 10 / 10. blue:arc4random() % 10 / 10. alpha:1];
        self.label_title.autoresizesSubviews = YES;
        self.label_title.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.label_title.font = [UIFont systemFontOfSize:12];
        [self addSubview:self.label_title];
        
        UIView *separator = [UIView new];
        separator.tag = 250;
        separator.backgroundColor = [UIColor lightGrayColor];
        [self addSubview:separator];
    }
    return self;
}

- (void)layoutSubviews {
    
}

- (void)prepareForReuse {
    self.transform = CGAffineTransformMakeScale(1, 1);
}

@end
