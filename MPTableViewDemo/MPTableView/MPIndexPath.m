//
//  MPIndexPath.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPIndexPath.h"

NS_INLINE NSInteger *
_NSIntegerMalloc(size_t size) {
    NSInteger *temp = (NSInteger *)malloc(size);
    assert(temp != NULL);
    return memset(temp, 0, size);
}

@interface MPMutableIndexPath () {
    NSInteger _reserved, _reservedStep;
    dispatch_semaphore_t _semaphore_lock;
}

@end

@implementation MPIndexPath

- (instancetype)init {
    if (self = [super init]) {
        _length = 0;
    }
    return self;
}

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    NSParameterAssert(indexes && length);
    
    MPIndexPath *indexPath = [[self class] new];
    indexPath->_length = length;
    size_t size = length * sizeof(NSInteger);
    indexPath->_indexes = _NSIntegerMalloc(size);
    memmove(indexPath->_indexes, indexes, size);
    return indexPath;
}

- (NSInteger)indexAtPosition:(NSUInteger)position {
    NSParameterAssert(position < _length);
    return _indexes[position];
}

- (NSInteger *)indexsInRange:(NSRange)range {
    NSParameterAssert(NSMaxRange(range) <= _length);
    if (!range.length) {
        return NULL;
    } else {
        size_t size = range.length * sizeof(NSInteger);
        NSInteger *indexs = _NSIntegerMalloc(size);
        return memmove(indexs, _indexes + range.location, size);
    }
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
    MPIndexPath *copyObj = [MPIndexPath allocWithZone:zone];
    copyObj->_length = _length;
    if (_length) {
        size_t size = _length * sizeof(NSInteger);
        copyObj->_indexes = _NSIntegerMalloc(size);
        memmove(copyObj->_indexes, _indexes, size);
    }
    return copyObj;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    MPMutableIndexPath *mutableCopyObj = [[MPMutableIndexPath allocWithZone:zone] init];
    if (_length) {
        [mutableCopyObj addIndexPaths:self];
    }
    return mutableCopyObj;
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

#pragma mark-

@implementation MPMutableIndexPath

+ (instancetype)indexPath {
    return [MPMutableIndexPath new];
}

+ (instancetype)indexPathWithIndexPath:(MPIndexPath *)indexPath {
    MPMutableIndexPath *mutableIndexPath = [MPMutableIndexPath indexPath];
    [mutableIndexPath addIndexPaths:indexPath];
    return mutableIndexPath;
}

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    NSParameterAssert(indexes && length);
    
    MPMutableIndexPath *indexPath = [MPMutableIndexPath indexPath];
    [indexPath addIndexes:indexes length:length];
    return indexPath;
}

- (instancetype)init {
    if (self = [super init]) {
        _reservedStep = 2;
        _reserved = 0;
        _semaphore_lock = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)_reserve:(NSInteger)length {
    NSInteger *temp = _NSIntegerMalloc(length * sizeof(NSInteger));
    if (_length) {
        memmove(temp, _indexes, _length * sizeof(NSInteger));
    }
    free(_indexes);
    _indexes = temp;
}

- (void)addIndexPaths:(MPIndexPath *)indexPath {
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    
    if ([indexPath length] > _length + _reserved) {
        if (_reserved <= 0) {
            _reserved = _reservedStep;
        }
        [self _reserve:_length + [indexPath length] + _reserved];
    }
    NSInteger *dest = _indexes + _length;
    memmove(dest, indexPath->_indexes, [indexPath length] * sizeof(NSInteger));
    
    _length += [indexPath length];
    
    dispatch_semaphore_signal(_semaphore_lock);
}

- (void)addIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    
    if (length > _length + _reserved) {
        if (_reserved <= 0) {
            _reserved = _reservedStep;
        }
        [self _reserve:_length + length + _reserved];
    }
    NSInteger *dest = _indexes + _length;
    memmove(dest, indexes, length * sizeof(NSInteger));
    
    _length += length;
    
    dispatch_semaphore_signal(_semaphore_lock);
}

- (void)removeLastIndexes:(NSUInteger)length {
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    
    NSParameterAssert(length <= _length);
    
    memset(_indexes + (_length -= length), 0, length * sizeof(NSInteger));
    _reserved += length;
    
    dispatch_semaphore_signal(_semaphore_lock);
}

- (void)addIndex:(NSInteger)index {
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    
    if (_reserved <= 0) {
        _reserved = _reservedStep *= 2;
        [self _reserve:_length + _reserved];
    }
    _indexes[_length] = index;
    _reserved--;
    _length++;
    
    dispatch_semaphore_signal(_semaphore_lock);
}

- (void)removeLastIndex {
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    
    if (_length > 0) {
        _indexes[--_length] = 0;
        _reserved++;
    }
    
    dispatch_semaphore_signal(_semaphore_lock);
}

- (NSInteger *)indexsInRange:(NSRange)range {
    NSInteger *indexs = NULL;
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    indexs = [super indexsInRange:range];
    dispatch_semaphore_signal(_semaphore_lock);
    return indexs;
}

- (id)copyWithZone:(NSZone *)zone {
    MPIndexPath *copyObj = nil;
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    copyObj = [super copyWithZone:zone];
    dispatch_semaphore_signal(_semaphore_lock);
    return copyObj;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    MPMutableIndexPath *mutableCopyObj = nil;
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    mutableCopyObj = [super mutableCopyWithZone:zone];
    dispatch_semaphore_signal(_semaphore_lock);
    return mutableCopyObj;
}

- (NSString*)description {
    NSString *description;
    dispatch_semaphore_wait(_semaphore_lock, DISPATCH_TIME_FOREVER);
    description = [super description];
    dispatch_semaphore_signal(_semaphore_lock);
    return description;
}

@end