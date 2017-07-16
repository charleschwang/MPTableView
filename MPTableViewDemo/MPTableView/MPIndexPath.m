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
    NSInteger *integers = (NSInteger *)malloc(size);
    assert(integers != NULL);
    return memset(integers, 0, size);
}

@implementation MPIndexPath

- (instancetype)initWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    if (self = [super init]) {
        _length = length;
        
        if (length > 0) {
            NSParameterAssert(indexes);
            size_t size = length * sizeof(NSInteger);
            _indexes = _NSIntegerMalloc(size);
            memmove(_indexes, indexes, size);
        }
    }
    return self;
}

- (instancetype)init {
    return [self initWithIndexes:NULL length:0];
}

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    return [[self alloc] initWithIndexes:indexes length:length];
}

- (NSInteger)indexAtPosition:(NSUInteger)position {
    NSParameterAssert(position < _length);
    
    return _indexes[position];
}

- (NSInteger *)indexesInRange:(NSRange)range {
    NSParameterAssert(NSMaxRange(range) <= _length);
    
    if (!range.length) {
        return NULL;
    } else {
        size_t size = range.length * sizeof(NSInteger);
        NSInteger *indexes = _NSIntegerMalloc(size);
        return memmove(indexes, _indexes + range.location, size);
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

- (NSComparisonResult)compare:(MPIndexPath *)indexPath {
    if (_length < indexPath.length) {
        return NSOrderedAscending;
    } else if (_length > indexPath.length) {
        return NSOrderedDescending;
    } else {
        int result = memcmp(_indexes, indexPath->_indexes, _length * sizeof(NSInteger));
        return (result == 0) ? NSOrderedSame : (result > 0 ? NSOrderedDescending : NSOrderedAscending);
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

- (NSString *)description {

    NSMutableString *description = [NSMutableString stringWithFormat:@"length = %zd", _length];
    for (NSInteger i = 0; i < _length; i++) {
        [description appendString:[NSString stringWithFormat:@", path%zd = %zd", i, _indexes[i]]];
    }
    return description;
}

- (void)dealloc {
    free(_indexes);
}

@end

#pragma mark -

@implementation MPMutableIndexPath {
    NSInteger _reserved;
    NSUInteger _reservedStep;
}

+ (instancetype)indexPath {
    return [[MPMutableIndexPath alloc] init];
}

+ (instancetype)indexPathWithIndexPath:(MPIndexPath *)indexPath {
    MPMutableIndexPath *mutableIndexPath = [[MPMutableIndexPath alloc] init];
    [mutableIndexPath addIndexPaths:indexPath];
    return mutableIndexPath;
}

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    
    MPMutableIndexPath *mutableIndexPath = [[MPMutableIndexPath alloc] init];
    [mutableIndexPath addIndexes:indexes length:length];
    return mutableIndexPath;
}

- (instancetype)initWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    return [self init];
}

- (instancetype)init {
    if (self = [super initWithIndexes:NULL length:0]) {
        _reservedStep = 2;
        _reserved = 0;
    }
    return self;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems {
    if (self = [super initWithIndexes:NULL length:0]) {
        _reservedStep = 2;
        _reserved = numItems;
        [self _reserve:numItems];
    }
    return self;
}

- (void)_reserve:(NSUInteger)length {
    NSInteger *temp = _NSIntegerMalloc(length * sizeof(NSInteger));
    if (_length) {
        memmove(temp, _indexes, _length * sizeof(NSInteger));
    }
    free(_indexes);
    _indexes = temp;
}

- (void)addIndexPaths:(MPIndexPath *)indexPath {
    if (indexPath && [indexPath length]) {
        if ([indexPath length] > _length + _reserved) {
            if (_reserved <= 0) {
                _reserved = _reservedStep;
            }
            [self _reserve:_length + [indexPath length] + _reserved];
        }
        NSInteger *dest = _indexes + _length;
        memmove(dest, indexPath->_indexes, [indexPath length] * sizeof(NSInteger));
        
        _length += [indexPath length];
    }
}

- (void)addIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    if (length == 0) {
        return;
    }
    NSParameterAssert(indexes);
    
    if (length > _length + _reserved) {
        if (_reserved <= 0) {
            _reserved = _reservedStep;
        }
        [self _reserve:_length + length + _reserved];
    }
    NSInteger *dest = _indexes + _length;
    memmove(dest, indexes, length * sizeof(NSInteger));
    
    _length += length;
}

- (void)removeLastIndexes:(NSUInteger)length {
    NSParameterAssert(length <= _length);
    
    memset(_indexes + (_length -= length), 0, length * sizeof(NSInteger));
    _reserved += length;
}

- (void)addIndex:(NSInteger)index {
    if (_reserved <= 0) {
        _reserved = _reservedStep *= 2;
        [self _reserve:_length + _reserved];
    }
    _indexes[_length] = index;
    _reserved--;
    _length++;
}

- (void)removeLastIndex {
    if (_length > 0) {
        _indexes[--_length] = 0;
        _reserved++;
    }
}

@end
