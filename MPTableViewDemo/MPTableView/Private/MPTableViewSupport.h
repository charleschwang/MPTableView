//
//  MPTableViewSupport.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MPIndexPath : NSObject<NSCopying> {
    @protected
    NSInteger *_indexes;
    NSUInteger _length;
}

@property (readonly) NSUInteger length;

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSInteger)length;
- (void)addIndex:(NSInteger)index;
- (void)removeLastIndex;
- (NSInteger)indexAtPosition:(NSUInteger)position;

@end

#pragma mark -

@interface NSArray (MPBinarySearch)
- (NSUInteger)indexOfObjectBinarySearch:(NSComparisonResult (^) (id obj, NSUInteger index, BOOL *stop))comparator;
- (NSUInteger)mp_indexOfObjectBinarySearch:(NSComparisonResult (^) (id obj))comparator isApproximate:(BOOL*)approximate;// 

@end