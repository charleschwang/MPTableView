//
//  MPIndexPath.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef NS_DESIGNATED_INITIALIZER
#if __has_attribute(objc_designated_initializer)
#define NS_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
#else
#define NS_DESIGNATED_INITIALIZER
#endif
#endif

#if !(__has_feature(objc_instancetype))
#define instancetype id
#endif

@interface MPIndexPath : NSObject<NSCopying, NSMutableCopying> {
    @protected
    NSInteger *_indexes;
    NSUInteger _length;
}

@property (readonly) NSUInteger length;
- (instancetype)initWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length;
- (NSInteger)indexAtPosition:(NSUInteger)position;
- (NSInteger *)indexesInRange:(NSRange)range;

- (NSComparisonResult)compare:(MPIndexPath *)otherIndexPath;

@end

#pragma mark -

@interface MPMutableIndexPath : MPIndexPath

+ (instancetype)indexPath;
+ (instancetype)indexPathWithIndexPath:(MPIndexPath *)otherIndexPath;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCapacity:(NSUInteger)numItems NS_DESIGNATED_INITIALIZER;

- (void)addIndex:(NSInteger)index;
- (void)removeLastIndex;

- (void)addIndexPath:(MPIndexPath *)otherIndexPath;
- (void)addIndexes:(const NSInteger [])indexes length:(NSUInteger)length;
- (void)removeLastIndexes:(NSUInteger)length;

@end
