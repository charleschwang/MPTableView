//
//  MyDemoCell.m
//  MPTableViewDemo
//
//  Created by apple on 16/4/1.
//  Copyright © 2016年 SMT. All rights reserved.
//

#import "MyDemoCell.h"

@implementation MyDemoCell

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithReuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = [UIColor colorWithRed:arc4random() % 10 / 10. green:arc4random() % 10 / 10. blue:arc4random() % 10 / 10. alpha:1];
        
        CGRect frame = self.frame;
        frame.origin = CGPointZero;
        self.label_title = [[UILabel alloc] initWithFrame:frame];
        self.label_title.font = [UIFont systemFontOfSize:12];
        [self addSubview:self.label_title];
        
        UIView *separator = [[UIView alloc] init];
        separator.tag = 250;
        separator.backgroundColor = [UIColor lightGrayColor];
        [self addSubview:separator];
        
        self.btn_movement = [[UIButton alloc] initWithFrame:frame];
        [self.btn_movement setTitle:@"drag" forState:UIControlStateNormal];
        [self.btn_movement setTitle:@"dragging" forState:UIControlStateHighlighted];
        [self.btn_movement setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        [self.btn_movement setTitleColor:[UIColor redColor] forState:UIControlStateHighlighted];
        self.btn_movement.titleLabel.font = [UIFont systemFontOfSize:11];
        self.btn_movement.backgroundColor = [UIColor whiteColor];
        
        // =========================================================
        self.btn_movement.userInteractionEnabled = NO; // this button is not used to start dragging the cell.
        // =========================================================
        
        [self addSubview:self.btn_movement];
    }
    
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    self.label_title.frame = self.bounds;
    self.btn_movement.frame = [self rectForDrag];
    [self.btn_movement layoutSubviews]; // UIButton label may not layout immediately after setFrame, force it here to avoid animated layout during table view updates.
}

- (void)prepareForRecycle {
    self.transform = CGAffineTransformMakeScale(1, 1);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted animated:YES];
}

- (CGRect)rectForDrag {
    return CGRectMake(self.bounds.size.width / 4 * 3, 2, self.bounds.size.width / 4, self.bounds.size.height - 3);
}

@end
