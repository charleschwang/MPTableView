//
//  MPIndexPath.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPIndexPath.h"

//#define _NSIntegers_len_check(_indexes_, _length_) assert((sizeof(_indexes_) / sizeof(NSInteger)) == _length_)
#define _NSInteger_sizeof(_size_) ((_size_) * sizeof(NSInteger))

#define MPIndexPath_exception(_reason_) @throw [NSException exceptionWithName:@"MPIndexPathException" reason:_reason_ userInfo:nil]

NS_INLINE NSInteger *
_NSIntegerMalloc(size_t size) {
    NSInteger *integers = (NSInteger *)malloc(size);
    if (integers == NULL) {
        MPIndexPath_exception(@"malloc failure");
    }
    return memset(integers, 0, size);
}

@implementation MPIndexPath

- (instancetype)initWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    if (self = [super init]) {
        _length = length;
        if (length > 0) {
            NSParameterAssert(indexes);
            size_t size = _NSInteger_sizeof(length);
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
        size_t size = _NSInteger_sizeof(range.length);
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
        }
        if (_length == 0) {
            return YES;
        }
        
        return memcmp(_indexes, object->_indexes, _NSInteger_sizeof(_length)) == 0;
    }
}

- (NSComparisonResult)compare:(MPIndexPath *)indexPath {
    NSParameterAssert(indexPath);
    NSUInteger length = indexPath->_length;
    if (_length < length) {
        return NSOrderedAscending;
    } else if (_length > length) {
        return NSOrderedDescending;
    } else {
        if (length == 0) {
            return NSOrderedSame;
        } else {
            int result = memcmp(_indexes, indexPath->_indexes, _NSInteger_sizeof(_length));
            return (result == 0) ? NSOrderedSame : (result > 0 ? NSOrderedDescending : NSOrderedAscending);
        }
    }
}

- (id)copyWithZone:(NSZone *)zone {
    MPIndexPath *copyObj = [[MPIndexPath allocWithZone:zone] init];
    copyObj->_length = _length;
    if (_length) {
        size_t size = _NSInteger_sizeof(_length);
        copyObj->_indexes = _NSIntegerMalloc(size);
        memmove(copyObj->_indexes, _indexes, size);
    }
    return copyObj;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    MPMutableIndexPath *mutableCopyObj = [[MPMutableIndexPath allocWithZone:zone] init];
    if (_length) {
        [mutableCopyObj addIndexPath:self];
    }
    return mutableCopyObj;
}

- (NSUInteger)hash {
    if (_length > 0) {
        return _indexes[_length - 1] + _length; // like NSIndexPath.hash
    } else {
        return 0;
    }
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"%@ {length = %zd, path = ", [super description], _length];
    for (NSInteger i = 0; i < _length; i++) {
        [description appendString:[NSString stringWithFormat:@"%zd - ", _indexes[i]]];
    }
    NSRange range;
    if (_length) {
        range = NSMakeRange(description.length - 3, 3);
    } else {
        range = NSMakeRange(description.length - 9, 9);
    }
    [description deleteCharactersInRange:range];
    [description appendString:@"}"];
    
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
    [mutableIndexPath addIndexPath:indexPath];
    return mutableIndexPath;
}

+ (instancetype)indexPathWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    MPMutableIndexPath *mutableIndexPath = [[MPMutableIndexPath alloc] init];
    [mutableIndexPath addIndexes:indexes length:length];
    return mutableIndexPath;
}

- (instancetype)initWithIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    if (self = [self init]) {
        [self addIndexes:indexes length:length];
    }
    return self;
}

- (instancetype)init {
    if (self = [super initWithIndexes:NULL length:0]) {
        _reservedStep = 1;
    }
    return self;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems {
    if (self = [super initWithIndexes:NULL length:0]) {
        if (numItems) {
            _indexes = _NSIntegerMalloc(_NSInteger_sizeof(_reserved = _reservedStep = numItems));
        } else {
            _reservedStep = 1;
        }
    }
    return self;
}

- (void)_reserve {
    NSInteger *temp = realloc(_indexes, _NSInteger_sizeof(_length + _reserved + _reservedStep * 2));
    if (!temp) {
        free(_indexes);
        MPIndexPath_exception(@"realloc failure");
    }
    _indexes = temp;
    _reservedStep *= 2;
    _reserved += _reservedStep;
}

- (void)addIndex:(NSInteger)index {
    if (_reserved < 1) {
        [self _reserve];
    }
    _indexes[_length] = index;
    _reserved--;
    _length++;
}

- (void)removeLastIndex {
    NSParameterAssert(_length > 0);
    if (_length > 0) {
        _indexes[--_length] = 0;
        _reserved++;
    }
}

- (void)addIndexPath:(MPIndexPath *)indexPath {
    NSParameterAssert(indexPath);
    NSUInteger length = [indexPath length];
    if (!indexPath || !length) {
        return;
    }
    
    if (length > _reserved) {
        if (_reservedStep < length) {
            _reservedStep = length;
        }
        [self _reserve];
    }
    NSInteger *dest = _indexes + _length;
    memmove(dest, indexPath->_indexes, _NSInteger_sizeof(length));
    
    _reserved -= length;
    _length += length;
}

- (void)addIndexes:(const NSInteger [])indexes length:(NSUInteger)length {
    NSParameterAssert(indexes && length);
    if (!indexes || !length) {
        return;
    }
    
    if (length > _reserved) {
        if (_reservedStep < length) {
            _reservedStep = length;
        }
        [self _reserve];
    }
    NSInteger *dest = _indexes + _length;
    memmove(dest, indexes, _NSInteger_sizeof(length));
    
    _reserved -= length;
    _length += length;
}

- (void)removeLastIndexes:(NSUInteger)length {
    NSParameterAssert(_length >= length);
    if (_length >= length) {
        memset(_indexes + (_length -= length), 0, _NSInteger_sizeof(length));
        _reserved += length;
    }
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    MPMutableIndexPath *mutableCopyObj = [[MPMutableIndexPath allocWithZone:zone] init];
    mutableCopyObj->_length = _length;
    mutableCopyObj->_reserved = _reserved;
    mutableCopyObj->_reservedStep = _reservedStep;
    if (_length) {
        size_t size = _NSInteger_sizeof(_length + _reserved);
        mutableCopyObj->_indexes = _NSIntegerMalloc(size);
        memmove(mutableCopyObj->_indexes, _indexes, _NSInteger_sizeof(_length));
    }
    return mutableCopyObj;
}

@end
