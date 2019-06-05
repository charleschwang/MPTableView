//
//  MyDemoCell.h
//  MPTableViewDemo
//
//  Created by apple on 16/4/1.
//  Copyright © 2016年 SMT. All rights reserved.
//

#import "MPTableViewCell.h"

@interface MyDemoCell : MPTableViewCell

@property (nonatomic, strong) UILabel *label_title;
@property (nonatomic, strong) UIButton *btn_movement;

- (CGRect)rectForDrag;

@end
