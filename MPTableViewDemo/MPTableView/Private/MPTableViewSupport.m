//
//  MPTableViewSupport.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewSupport.h"

@implementation MPIndexPath {
    NSInteger _reserved, _reservedStep;
    dispatch_semaphore_t _semaphore_lock;
}

- (instancetype)init {
    if (self = [super init]) {
        _reserved = 0;
        _reservedStep = 1;
        _length = 0;
        _semaphore_lock = dispatch_semaphore_create(1);
    }
    return self;
}

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSInteger)length {
    MPIndexPath *indexPath = [[self class] new];
    indexPath->_reserved = indexPath->_reservedStep *= 2;
    indexPath->_indexes = (NSInteger *)malloc(sizeof(NSInteger) * (length + indexPath->_reserved));
    memmove(indexPath->_indexes, indexes, (indexPath->_length = length) * sizeof(NSInteger));
    return indexPath;
}

- (void)addIndex:(NSInteger)index {
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    
    if (_reserved == 0) {
        _reserved = _reservedStep *= 2;
        NSInteger *temp = (NSInteger *)malloc(sizeof(NSInteger) * (_length + _reserved));
        if (_length) {
            memmove(temp, _indexes, _length * sizeof(NSInteger));
        }
        free(_indexes);
        _indexes = temp;
    }
    _indexes[_length] = index;
    _reserved--;
    _length++;
    
    dispatch_semaphore_signal(_semaphore_lock);
}

- (void)removeLastIndex {
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    
    _indexes[--_length] = 0;
    _reserved++;
    
    dispatch_semaphore_signal(_semaphore_lock);
}

- (NSInteger)indexAtPosition:(NSUInteger)position {
    if (position >= _length) {
        return NSNotFound;
    }
    return _indexes[position];
}

- (NSUInteger)length {
    return _length;
}

- (BOOL)isEqual:(MPIndexPath *)object {
    if (object == self) {
        return YES;
    } else {
        if (!object || _length != object->_length) {
            return NO;
        } else {
            return memcmp(_indexes, object->_indexes, _length * sizeof(NSInteger)) == 0;
        }
    }
}

- (id)copyWithZone:(NSZone *)zone {
    MPIndexPath *copyObj = [[self class] allocWithZone:zone];
    copyObj->_semaphore_lock = dispatch_semaphore_create(1);
    copyObj->_indexes = (NSInteger *)malloc(sizeof(NSInteger) * (_length + _reserved));
    memcpy(copyObj->_indexes, _indexes, _length + _reserved * sizeof(NSInteger));
    copyObj->_reserved = _reserved;
    copyObj->_length = _length;
    copyObj->_reservedStep = _reservedStep;
    return copyObj;
}

- (NSUInteger)hash {
    if (_length > 0) {
        return _indexes[_length - 1] + _length; // NSIndexPath
    } else {
        return 0;
    }
}

- (NSString*)description {
    if (!_length) {
        return @"empty index path";
    }
    NSMutableString *_desc = [NSMutableString string];
    for (NSInteger i = 0; i < _length; i++) {
        [_desc appendString:[NSString stringWithFormat:@" node%zd:%zd", i, _indexes[i]]];
    }
    return _desc;
}

- (void)dealloc {
    free(_indexes);
}

@end

#pragma mark -

@implementation NSArray (MPBinarySearch)

- (NSUInteger)indexOfObjectBinarySearch:(NSComparisonResult (^)(id, NSUInteger, BOOL *))comparator {
    NSInteger __start = 0;
    NSInteger __end = self.count - 1;
    NSInteger __middle = 0;
    BOOL __stop = NO;
    NSComparisonResult mcase = NSOrderedDescending;
    while (mcase != NSOrderedSame) {
        __middle = (__start + __end) / 2;
        mcase = comparator(self[__middle], __middle, &__stop);
        if (__stop) {
            return __middle;
        }
        if (mcase == NSOrderedAscending) {
            __end = __middle - 1;
        } else if (mcase == NSOrderedDescending) {
            __start = __middle + 1;
        } else {
            break;
        }
        if (__start > __end) {
            return NSNotFound;
        }
    }
    return __middle;
}

- (NSUInteger)mp_indexOfObjectBinarySearch:(NSComparisonResult (^)(id))comparator isApproximate:(BOOL *)approximate {
    NSInteger __start = 0;
    NSInteger __end = self.count - 1;
    NSInteger __middle = 0;
    NSComparisonResult mcase = NSOrderedDescending;
    while (mcase != NSOrderedSame) {
        __middle = (__start + __end) / 2;
        mcase = comparator(self[__middle]);
        if (mcase == NSOrderedAscending) {
            __end = __middle - 1;
        } else if (mcase == NSOrderedDescending) {
            __start = __middle + 1;
        } else {
            break;
        }
        if (__start > __end) {
            *approximate = YES;
            return __middle;//
        }
    }
    return __middle;
}
@end