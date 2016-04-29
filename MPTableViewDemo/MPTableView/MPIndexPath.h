//
//  MPIndexPath.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPIndexPath : NSObject<NSCopying, NSMutableCopying> {
    @protected
    NSInteger *_indexes;
    NSUInteger _length;
}

@property (readonly) NSUInteger length;

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSInteger)length;
- (NSInteger)indexAtPosition:(NSUInteger)position;
- (NSInteger *)indexsAtRange:(NSRange)range;

@end

@interface MPMutableIndexPath : MPIndexPath

+ (instancetype)indexPath;
+ (instancetype)indexPathWithIndexPath:(MPIndexPath *)indexPath;

- (void)addIndexPaths:(MPIndexPath *)indexPath;
- (void)addIndexes:(const NSInteger [])indexes length:(NSInteger)length;
- (void)removeLastIndexes:(NSInteger)length;

- (void)addIndex:(NSInteger)index;
- (void)removeLastIndex;

@end