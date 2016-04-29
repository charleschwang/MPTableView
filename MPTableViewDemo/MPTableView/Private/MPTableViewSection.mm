//
//  MPTableViewSection.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewSection.h"
#import <c++/v1/vector>
#import <c++/v1/map>
#import <c++/v1/algorithm>

using namespace std;

@implementation MPTableViewPosition

- (instancetype)init {
    if (self = [super init]) {
        _beginPos = _endPos = 0;
    }
    return self;
}

+ (instancetype)positionWithBegin:(CGFloat)begin toEnd:(CGFloat)end {
    MPTableViewPosition *pos = [[self class] new];
    pos.beginPos = begin;
    pos.endPos = end;
    return pos;
}

- (BOOL)isEqual:(id)object {
    if (!object) {
        return NO;
    } else {
        return _beginPos == [object beginPos] || _endPos == [object endPos];
    }
}

- (NSUInteger)hash {
    return 0;
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewPosition *position = [[self class] allocWithZone:zone];
    position.beginPos = _beginPos;
    position.endPos = _endPos;
    return position;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"beginPos:%.2f, endPos:%.2f", _beginPos, _endPos];
}
@end

#pragma mark -

class MPTableViewUpdateNode {
public:
    MPTableViewUpdateType updateType;
    MPTableViewRowAnimation animation;
    NSInteger index, originIndex;
};

NS_INLINE bool
_mpUpdateSort(const MPTableViewUpdateNode _first_, const MPTableViewUpdateNode _second_) {
    return _first_.index < _second_.index;
}

//NS_INLINE void
//_mpUpdateSwap(vector<MPTableViewUpdateNode> *__vec, NSInteger __first, NSInteger __second) {
//    MPTableViewUpdateNode temp = __vec->at(__first);
//    __vec->at(__first) = __vec->at(__second);
//    __vec->at(__second) = temp;
//}

template <class _Vec_update>
void
_MPUpdateMove(vector<_Vec_update> *__vector, NSInteger __preIndex, NSInteger __currIndex) {
    assert(__preIndex < __vector->size() && __currIndex < __vector->size());
    NSInteger __begin;
    NSInteger __middle;
    NSInteger __end;
    if(__currIndex < __preIndex) {
        __begin = __currIndex;
        __middle = __preIndex;
        __end = __preIndex + 1;
    } else if(__currIndex > __preIndex) {
        __begin = __preIndex;
        __middle = __preIndex + 1;
        __end = __currIndex + 1;
    } else {
        return;
    }
    rotate(__vector->begin() + __begin, __vector->begin() + __middle, __vector->begin() + __end);
}

template <class _Vec_update>
void
_converge(vector<_Vec_update> *__updateVec) {
    sort(__updateVec->begin(), __updateVec->end(), _mpUpdateSort);
    NSInteger __backTracking = 0;
    NSInteger __step = 0;
    NSUInteger __count = __updateVec->size();
    
    // make no duplicate nodes
    for (NSInteger i = 0; i < __count; i++) {
        _Vec_update *_cellNode = &(*__updateVec)[i];
        if (_cellNode->updateType == MPTableViewUpdateAdjust) {
            continue;
        }
        if (MPTableViewUpdateTypeUnstable(_cellNode->updateType)) { // unstable
            _cellNode->index += __step;
            if (_cellNode->updateType != MPTableViewUpdateReload) {
                __step--;
            }
            while (__backTracking < i) {
                _Vec_update *_backTrackingNode = &(*__updateVec)[__backTracking];
                if (MPTableViewUpdateTypeStable(_backTrackingNode->updateType)) { //
                    if (_cellNode->index >= _backTrackingNode->index) { // unstable >= stable
                        _cellNode->index++;
                        __step++;
                    } else { //
                        _MPUpdateMove(__updateVec, i, __backTracking);
                        __backTracking++;
                        break;
                    }
                    __backTracking++;
                } else {
                    break;
                }
            }
        } else { // stable
            while (__backTracking < i) {
                _Vec_update *_backTrackingNode = &(*__updateVec)[__backTracking];
                if (MPTableViewUpdateTypeUnstable(_backTrackingNode->updateType)) {
                    if (_cellNode->index <= _backTrackingNode->index) { // stable <= unstable
                        _MPUpdateMove(__updateVec, i, __backTracking);
                        __step++;
                        NSInteger temp = ++__backTracking;
                        do {
                            _cellNode = &(*__updateVec)[temp++];
                            _cellNode->index++;
                        } while (temp <= i);
                        break;
                    }
                    __backTracking++;
                } else {
                    break;
                }
            }
        }
    }
}

NS_INLINE vector<MPTableViewUpdateNode>::iterator
__rowReverseFindInsert(vector<MPTableViewUpdateNode>::iterator __first, vector<MPTableViewUpdateNode>::iterator __last) {
    for (; __first != __last; ++__first) {
        if (MPTableViewUpdateTypeStable(__first->updateType)) {
            return __first;
        }
    }
    return __last;
}

@implementation MPTableViewUpdateBase {
@public
    vector<MPTableViewUpdateNode> *_updateVec;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingIndexs = [NSMutableIndexSet indexSet];
        _differ = 0;
        _maxIndexCount = NSNotFound;
        _updateVec = new vector<MPTableViewUpdateNode>();
    }
    return self;
}

- (BOOL)formatNodesStable {
    if (_updateVec->size() == 0) {
        return YES;
    }
    _converge(_updateVec);
    
    vector<MPTableViewUpdateNode>::iterator lastInsertNode = __rowReverseFindInsert(_updateVec->begin(), _updateVec->end());
    if (lastInsertNode != _updateVec->end() && lastInsertNode->index + _differ > self.maxIndexCount) {
        return NO;
    }
    if (self.originCount + _differ != self.maxIndexCount) {
        return NO;
    } else {
        return YES;
    }
}

- (void)dealloc {
    delete _updateVec;
    _existingIndexs = nil;
}

@end

#pragma mark -

class MPTableViewSectionIndex {
public:
    MPTableViewSection *section;
    NSInteger originIndex;
    ~MPTableViewSectionIndex() {
        section = nil;
    }
};

@implementation MPTableViewUpdateManager {
    NSMutableIndexSet *_existingUpdatePartsIndexs;
    map<NSInteger, MPTableViewSectionIndex> _moveOutSectionsMap;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingUpdatePartsIndexs = [NSMutableIndexSet indexSet];
        _moveOutSectionsMap = map<NSInteger, MPTableViewSectionIndex>();
    }
    return self;
}

+ (MPTableViewUpdateManager *)managerWithDelegate:(MPTableView<MPTableViewUpdateDelegate> *)delegate andSections:(NSMutableArray *)sections {
    MPTableViewUpdateManager *result = [MPTableViewUpdateManager new];
    result->_delegate = delegate;
    result->_sections = sections;
    return result;
}

- (NSUInteger)maxIndexCount {
    if ([super maxIndexCount] == NSNotFound) {
        [super setMaxIndexCount:_delegate.numberOfSections];
    }
    return [super maxIndexCount];
}

- (void)resetManager {
    _updateVec->clear();
    _moveOutSectionsMap.clear();
    [_existingUpdatePartsIndexs removeAllIndexes];
    [_existingIndexs removeAllIndexes];
    _differ = 0;
    _isUpdating = NO;
    self.maxIndexCount = NSNotFound;
}

- (void)dealloc {
    [_existingUpdatePartsIndexs removeAllIndexes];
    _existingUpdatePartsIndexs = nil;
    
    _moveOutSectionsMap.clear();
}

- (BOOL)addMoveOutSection:(NSUInteger)section {
    if (section >= _sections.count) {
        return NO;
    }
    if ([_existingIndexs containsIndex:section] || [_existingUpdatePartsIndexs containsIndex:section]) {
        return NO;
    } else {
        [_existingIndexs addIndex:section];
        _differ--;
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateMoveOut;
    node.originIndex = section;
    
    _updateVec->push_back(node);
    return YES;
}

- (BOOL)addMoveInSection:(NSUInteger)section withOriginIndex:(NSInteger)originSection {
    if ([_existingIndexs containsIndex:section] || [_existingUpdatePartsIndexs containsIndex:section]) {
        return NO;
    } else {
        [_existingIndexs addIndex:section];
        _differ++;
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateMoveIn;
    node.originIndex = section;
    
    _updateVec->push_back(node);
    
    MPTableViewSectionIndex sectionIndex = MPTableViewSectionIndex();
    sectionIndex.section = _sections[originSection];
    sectionIndex.originIndex = originSection;
    _moveOutSectionsMap.insert(pair<NSInteger, MPTableViewSectionIndex>(section, sectionIndex));
    return YES;
}

- (BOOL)addDeleteSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if (section >= _sections.count) {
        return NO;
    }
    if ([_existingIndexs containsIndex:section] || [_existingUpdatePartsIndexs containsIndex:section]) {
        return NO;
    } else {
        [_existingIndexs addIndex:section];
        _differ--;
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateDelete;
    node.animation = animation;
    node.originIndex = section;
    
    _updateVec->push_back(node);
    return YES;
}

- (BOOL)addInsertSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingIndexs containsIndex:section] || [_existingUpdatePartsIndexs containsIndex:section]) {
        return NO;
    } else {
        [_existingIndexs addIndex:section];
        _differ++;
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateInsert;
    node.animation = animation;
    node.originIndex = section;
    
    _updateVec->push_back(node);
    return YES;
}

- (BOOL)addReloadSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if (section >= _sections.count) {
        return NO;
    }
    if ([_existingIndexs containsIndex:section] || [_existingUpdatePartsIndexs containsIndex:section]) {
        return NO;
    } else {
        [_existingIndexs addIndex:section];
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateReload;
    node.animation = animation;
    node.originIndex = section;
    
    _updateVec->push_back(node);
    return YES;
}

#pragma mark -update cells-
- (MPTableViewUpdatePart *)getPartAt:(NSUInteger)index {
    MPTableViewSection *section = _sections[index];
    MPTableViewUpdatePart *part = section.updatePart;
    if (!part) {
        part = [MPTableViewUpdatePart partWithIndexCount:[_delegate.dataSource MPTableView:_delegate numberOfRowsInSection:index]];
        part.originCount = section.numberOfRows;
        section.updatePart = part;
        [_existingUpdatePartsIndexs addIndex:index];
    }
    return part;
}

- (BOOL)addMoveOutIndexPath:(MPIndexPath *)indexPath {
    if (indexPath.section >= _sections.count || [_existingIndexs containsIndex:indexPath.section]) {
        return NO;
    }
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    MPTableViewSection *currSection = _sections[indexPath.section];
    if (indexPath.row >= currSection.numberOfRows) {
        return NO;
    } else {
        return [part addMoveOutRow:indexPath.row];
    }
}

- (BOOL)addMoveInIndexPath:(MPIndexPath *)indexPath withHeight:(CGFloat)height withOriginIndexPath:(MPIndexPath *)originIndexPath {
    if ([_existingIndexs containsIndex:indexPath.section]) {
        return NO;
    }
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    MPTableViewSection *currSection = _sections[indexPath.section];
    if (indexPath.row >= currSection.numberOfRows) {
        return NO;
    } else {
        return [part addMoveInRow:indexPath.row withHeight:height withOriginIndexPath:originIndexPath];
    }
}

- (BOOL)addDeleteIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if (indexPath.section >= _sections.count || [_existingIndexs containsIndex:indexPath.section]) {
        return NO;
    }
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    MPTableViewSection *currSection = _sections[indexPath.section];
    if (indexPath.row >= currSection.numberOfRows) {
        return NO;
    } else {
        return [part addDeleteRow:indexPath.row withAnimation:animation];
    }
}

- (BOOL)addInsertIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingIndexs containsIndex:indexPath.section]) {
        return NO;
    }
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    MPTableViewSection *currSection = _sections[indexPath.section];
    if (indexPath.row >= currSection.numberOfRows) {
        return NO;
    } else {
        return [part addInsertRow:indexPath.row withAnimation:animation];
    }
}

- (BOOL)addReloadIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if (indexPath.section >= _sections.count || [_existingIndexs containsIndex:indexPath.section]) {
        return NO;
    }
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    MPTableViewSection *currSection = _sections[indexPath.section];
    if (indexPath.row >= currSection.numberOfRows) {
        return NO;
    } else {
        return [part addReloadRow:indexPath.row withAnimation:animation];
    }
}

- (BOOL)formatNodesStable {
    __block BOOL result = YES;
    [_existingUpdatePartsIndexs enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        MPTableViewSection *section = _sections[idx];
        if (![section.updatePart formatNodesStable]) {
            result = NO;
            *stop = YES;
        }
    }];
    if (result) {
        self.originCount = _sections.count;
        return [super formatNodesStable];
    } else {
        return NO;
    }
}

- (CGFloat)startUpdate {
    _isUpdating = YES;
    CGFloat offset = 0;
    NSUInteger sectionCount = _sections.count;
    
    vector<MPTableViewUpdateNode> *nodes = _updateVec;
    NSInteger index = 0, step = 0;
    NSUInteger indexCount = nodes->size();
    for (NSInteger i = 0; i < indexCount; i++) {
        MPTableViewUpdateNode node = (*nodes)[i];
        for (NSInteger j = index; j < node.index; j++) {
            MPTableViewSection *section = _sections[j];
            BOOL isNeedCallback = [self.delegate updateNeedToAnimateSection:section updateType:MPTableViewUpdateAdjust andOffset:offset];
            if (MPTableViewUpdateTypeUnstable(node.updateType)) {
                isNeedCallback = isNeedCallback && section.section < node.originIndex;
            }
            if (section.updatePart) {
                offset = [section updateUsingPartWith:self.delegate toSection:j withOffset:offset needCallback:isNeedCallback];
            } else {
                [section updateWith:self.delegate toSection:j withOffset:offset needCallback:isNeedCallback];
            }
        }
        if (MPTableViewUpdateTypeStable(node.updateType)) {
            step++;
            MPTableViewSection *insertSection;
            if (node.updateType == MPTableViewUpdateInsert) {
                insertSection = [self.delegate updateMakeSectionAt:node.index];
            } else {
                insertSection = (_moveOutSectionsMap.at(node.index)).section;
                insertSection.section = node.index;
            }
            CGFloat currBeginPos;
            if (node.index == 0) {
                currBeginPos = 0;
            } else { // _sections[node.index] has not been offsetting, so its position is not accurate
                MPTableViewSection *currSection = _sections[node.index - 1];
                currBeginPos = currSection.endPos;
            }
            currBeginPos = currBeginPos - insertSection.beginPos;
            [insertSection setPositionOffset:currBeginPos];
            [_sections insertObject:insertSection atIndex:node.index];
            offset += insertSection.endPos - insertSection.beginPos;
            if (node.updateType == MPTableViewUpdateMoveIn) {
                MPTableViewSectionIndex sectionIndex = _moveOutSectionsMap.at(node.index);
                for (NSInteger k = 0; k < insertSection.numberOfRows; k++) {
                    [self.delegate updateSection:node.index moveInCellAtIndex:k fromOriginIndexPath:[MPIndexPath indexPathForRow:k inSection:sectionIndex.originIndex]];
                }
                [self.delegate updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeHeader];
                [self.delegate updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeFooter];
            } else {
                if ([self.delegate updateNeedToAnimateSection:insertSection updateType:MPTableViewUpdateInsert andOffset:offset]) {
                    for (NSInteger k = 0; k < insertSection.numberOfRows; k++) {
                        [self.delegate updateSection:node.index insertCellAtIndex:k withAnimation:node.animation isSectionAnimation:insertSection];
                    }
                    [self.delegate updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeHeader withAnimation:node.animation withInsertSection:insertSection];
                    [self.delegate updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeFooter withAnimation:node.animation withInsertSection:insertSection];
                }
            }
            index = node.index + 1;
        } else if (node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut) {
            step--;
            MPTableViewSection *deleteSection = _sections[node.index];
            CGFloat height = deleteSection.endPos - deleteSection.beginPos;
            offset -= height;
            [_sections removeObjectAtIndex:node.index];
            // node.index - step - 1 == node.originIndex
            if ([self.delegate updateNeedToAnimateSection:deleteSection updateType:MPTableViewUpdateDelete andOffset:offset]) {
                if (node.updateType == MPTableViewUpdateDelete) {
                    for (NSInteger k = 0; k < deleteSection.numberOfRows; k++) {
                        [self.delegate updateSection:node.originIndex deleteCellAtIndex:k withAnimation:node.animation isSectionAnimation:deleteSection];
                    }
                    [self.delegate updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeHeader withAnimation:node.animation withDeleteSection:deleteSection];
                    [self.delegate updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeFooter withAnimation:node.animation withDeleteSection:deleteSection];
                }
            }
            index = node.index;
        } else {
            MPTableViewSection *deleteSection = _sections[node.index];
            MPTableViewSection *insertSection = [self.delegate updateMakeSectionAt:node.index];
            if (node.originIndex != deleteSection.section) {
                assert(0); // beyond the bug
            }
            // node.index - step == node.originIndex
            CGFloat height = insertSection.endPos - insertSection.beginPos;
            offset += height - (deleteSection.endPos - deleteSection.beginPos);
            [_sections replaceObjectAtIndex:node.index withObject:insertSection];
            if ([self.delegate updateNeedToAnimateSection:insertSection updateType:MPTableViewUpdateInsert andOffset:offset] || [self.delegate updateNeedToAnimateSection:deleteSection updateType:MPTableViewUpdateDelete andOffset:offset]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; k++) {
                    [self.delegate updateSection:node.originIndex deleteCellAtIndex:k withAnimation:node.animation isSectionAnimation:deleteSection];
                }
                [self.delegate updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [self.delegate updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeFooter withAnimation:node.animation withDeleteSection:deleteSection];
                
                for (NSInteger k = 0; k < insertSection.numberOfRows; k++) {
                    [self.delegate updateSection:node.index insertCellAtIndex:k withAnimation:node.animation isSectionAnimation:insertSection];
                }
                [self.delegate updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeHeader withAnimation:node.animation withInsertSection:insertSection];
                [self.delegate updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeFooter withAnimation:node.animation withInsertSection:insertSection];
            }
            index = node.index + 1;
        }
    }
    sectionCount += step;
    for (NSInteger j = index; j < sectionCount; j++) {
        MPTableViewSection *section = _sections[j];
        if (section.section != j - step) {
            assert(0);
        }
        BOOL isNeedCallback = [self.delegate updateNeedToAnimateSection:section updateType:MPTableViewUpdateAdjust andOffset:offset];
        if (section.updatePart) {
            offset = [section updateUsingPartWith:self.delegate toSection:j withOffset:offset needCallback:isNeedCallback];
        } else {
            [section updateWith:self.delegate toSection:j withOffset:offset needCallback:isNeedCallback];
        }
    }
    return offset;
}

@end

#pragma mark -

class MPTableViewHeightIndexPath {
public:
    MPIndexPath *indexPath;
    CGFloat height;
};

@implementation MPTableViewUpdatePart {
    @package
    map<NSUInteger, MPTableViewHeightIndexPath> _moveOutHeightsMap;
}

- (instancetype)init {
    if (self = [super init]) {
        _moveOutHeightsMap = map<NSUInteger, MPTableViewHeightIndexPath>();
    }
    return self;
}

- (void)dealloc {
    _moveOutHeightsMap.clear();
}

+ (MPTableViewUpdatePart *)partWithIndexCount:(NSInteger)indexCount {
    MPTableViewUpdatePart *part = [MPTableViewUpdatePart new];
    part.maxIndexCount = indexCount;
    return part;
}

- (BOOL)addMoveOutRow:(NSUInteger)row {
    if ([_existingIndexs containsIndex:row]) {
        return NO;
    } else {
        [_existingIndexs addIndex:row];
        _differ--;
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = row;
    node.updateType = MPTableViewUpdateMoveOut;
    node.originIndex = row;
    
    _updateVec->push_back(node);    
    return YES;
}

- (BOOL)addMoveInRow:(NSUInteger)row withHeight:(CGFloat)height withOriginIndexPath:(MPIndexPath *)originIndexPath {
    if ([_existingIndexs containsIndex:row]) {
        return NO;
    } else {
        [_existingIndexs addIndex:row];
        _differ++;
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.originIndex = node.index = row;
    
    node.updateType = MPTableViewUpdateMoveIn;
    _updateVec->push_back(node);
    
    MPTableViewHeightIndexPath indexPathHeight = MPTableViewHeightIndexPath();
    indexPathHeight.indexPath = originIndexPath;
    indexPathHeight.height = height;
    _moveOutHeightsMap.insert(pair<NSUInteger, MPTableViewHeightIndexPath>(row, indexPathHeight));
    return YES;
}

- (BOOL)addDeleteRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingIndexs containsIndex:row]) {
        return NO;
    } else {
        [_existingIndexs addIndex:row];
        _differ--;
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = row;
    node.updateType = MPTableViewUpdateDelete;
    node.animation = animation;
    node.originIndex = row;
    
    _updateVec->push_back(node);
    return YES;
}

- (BOOL)addInsertRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingIndexs containsIndex:row]) {
        return NO;
    } else {
        [_existingIndexs addIndex:row];
        _differ++;
    }
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = row;
    node.updateType = MPTableViewUpdateInsert;
    node.animation = animation;
    node.originIndex = row;
    
    _updateVec->push_back(node);
    return YES;
}

- (BOOL)addReloadRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingIndexs containsIndex:row]) {
        return NO;
    } else {
        [_existingIndexs addIndex:row];
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = row;
    node.updateType = MPTableViewUpdateReload;
    node.animation = animation;
    node.originIndex = row;
    
    _updateVec->push_back(node);
    return YES;
}
@end

#pragma mark -

@implementation MPTableViewSection {
    vector<CGFloat> *_rowPositionVec;
}

+ (instancetype)section {
    return [[self class] new];
}

- (instancetype)init {
    if (self = [super init]) {
        [self resetData];
    }
    return self;
}

- (void)resetData {
    if (!_rowPositionVec) {
        _rowPositionVec = new vector<CGFloat>();
    }
    if (_rowPositionVec->size() > 0) {
        _rowPositionVec->clear();
    }
    _rowPositionVec->push_back(0);
    _headerHeight = _footerHeight = 0;
    _numberOfRows = 0;
    self.beginPos = self.endPos = 0;
    self.section = NSNotFound;
}

- (void)setNumberOfRows:(NSUInteger)numberOfRows {
    _rowPositionVec->reserve(_numberOfRows = numberOfRows);
    _rowPositionVec->at(0) = self.beginPos + _headerHeight;
}

- (void)addRowWithPosition:(CGFloat)end {
    _rowPositionVec->push_back(end);
}

- (CGFloat)rowPositionBeginAt:(NSInteger)index {
    return (*_rowPositionVec)[index];
}

- (CGFloat)rowHeightAt:(NSInteger)index {
    return (*_rowPositionVec)[index + 1] - (*_rowPositionVec)[index];
}

- (CGFloat)rowPositionEndAt:(NSInteger)index {
    return (*_rowPositionVec)[index + 1];
}

- (NSInteger)rowAtContentOffset:(CGFloat)target {
    if (target < self.beginPos + self.headerHeight) {
        return MPSectionTypeHeader;
    }
    if (target > self.endPos - self.footerHeight) {
        return MPSectionTypeFooter;
    }
    NSInteger __start = 0;
    NSInteger __end = _rowPositionVec->size() - 1;
    NSInteger __middle = 0;
    while (__start <= __end) {
        __middle = (__start + __end) / 2;
        CGFloat beginPos = [self rowPositionBeginAt:__middle];
        CGFloat endPos = [self rowPositionEndAt:__middle];
        if (beginPos > target) {
            __end = __middle - 1;
        } else if (endPos < target) {
            __start = __middle + 1;
        } else {
            return __middle;
        }
    }
    return NSNotFound;
}

- (void)removeRowPositionAt:(NSInteger)index {
    vector<CGFloat>::iterator it = _rowPositionVec->begin() + index + 1;
    _rowPositionVec->erase(it);
}

- (void)insertRowAt:(NSInteger)index withHeight:(CGFloat)height {
    vector<CGFloat>::iterator it = _rowPositionVec->begin() + index + 1;
    CGFloat cellEndPos = height + (*_rowPositionVec)[index];
    _rowPositionVec->insert(it, cellEndPos);
}

- (void)reloadRowAt:(NSInteger)index withHeight:(CGFloat)height {
    (*_rowPositionVec)[index + 1] = (*_rowPositionVec)[index] + height;
}

- (void)setPositionOffset:(CGFloat)offset {
    self.beginPos += offset;
    self.endPos += offset;
    for (NSInteger i = 0; i <= _numberOfRows; i++) {
        (*_rowPositionVec)[i] += offset;
    }
}

- (CGFloat)updateUsingPartWith:(id<MPTableViewUpdateDelegate>)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback {
    self.beginPos += offset;
    (*_rowPositionVec)[0] += offset;
    MPTableViewUpdatePart *part = self.updatePart;
    
    CGFloat originSection = self.section;
    self.section = newSection;
    CGFloat headerOffset = offset;

    vector<MPTableViewUpdateNode> *nodes = part->_updateVec;
    NSInteger index = 1, step = 0;
    NSUInteger indexCount = nodes->size();
    for (NSInteger i = 0; i < indexCount; i++) {
        MPTableViewUpdateNode node = (*nodes)[i];
        NSUInteger idx;
        BOOL isInsert;
        if (MPTableViewUpdateTypeStable(node.updateType)) {
            idx = node.index;
            isInsert = YES;
        } else {
            idx = node.index + 1;
            isInsert = NO;
        }
        for (NSInteger j = index; j <= idx; j++) {
            if (offset != 0) {
                (*_rowPositionVec)[j] += offset;
            }
            NSInteger callBackIndex = j - step - 1;
            
            [updateDelegate updateSection:newSection originSection:originSection exchangeCellAtIndex:callBackIndex toIndex:j - 1];
            
            if (callback && (isInsert || callBackIndex < node.originIndex)) {
                [updateDelegate updateSection:newSection originSection:originSection exchangeCellAtIndex:callBackIndex toIndex:j - 1 withOffset:offset];
            }
        }
        if (isInsert) {
            step++;
            CGFloat cellHeight;
            if (node.updateType == MPTableViewUpdateInsert) {
                cellHeight = [updateDelegate updateSection:newSection cellHeightAtIndex:node.index];
            } else {
                cellHeight = (part->_moveOutHeightsMap.at(node.index)).height;
            }
            [self insertRowAt:node.index withHeight:cellHeight];
            offset += cellHeight;
            if (node.updateType == MPTableViewUpdateMoveIn) {
                [updateDelegate updateSection:newSection moveInCellAtIndex:node.index fromOriginIndexPath:(part->_moveOutHeightsMap.at(node.index)).indexPath];
            } else {
                if (callback) {
                    [updateDelegate updateSection:newSection insertCellAtIndex:node.index withAnimation:node.animation isSectionAnimation:nil];
                }
            }
            index = node.index + 2;
        } else if (node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut) {
            step--;
            CGFloat height = [self rowHeightAt:node.index];
            offset -= height;
            [self removeRowPositionAt:node.index];
            // node.index - step - 1 == node.originIndex
            if (callback) {
                if (node.updateType == MPTableViewUpdateDelete) {
                    [updateDelegate updateSection:originSection deleteCellAtIndex:node.originIndex withAnimation:node.animation isSectionAnimation:nil];
                }
            }
            index = node.index + 1;
        } else {
            CGFloat cellHeight = [updateDelegate updateSection:newSection cellHeightAtIndex:node.index];
            offset += cellHeight - [self rowHeightAt:node.index];
            [self reloadRowAt:node.index withHeight:cellHeight];
            // node.index - step == node.originIndex
            if (callback) {
                [updateDelegate updateSection:originSection deleteCellAtIndex:node.originIndex withAnimation:node.animation isSectionAnimation:nil];
                [updateDelegate updateSection:newSection insertCellAtIndex:node.index withAnimation:node.animation isSectionAnimation:nil];
            }
            index = node.index + 2;
        }
    }
    _numberOfRows += step;
    for (NSInteger i = index; i <= _numberOfRows; i++) {
        if (offset != 0) {
            (*_rowPositionVec)[i] += offset;
        }
        
        [updateDelegate updateSection:newSection originSection:originSection exchangeCellAtIndex:i - step - 1 toIndex:i - 1];
        
        if (callback) {
            [updateDelegate updateSection:newSection originSection:originSection exchangeCellAtIndex:i - step - 1 toIndex:i - 1 withOffset:offset];
        }
    }
    self.endPos += offset;
    if (callback) {
        [updateDelegate updateExchangeSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeHeader withSectionOffset:headerOffset];
        [updateDelegate updateExchangeSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeFooter withSectionOffset:offset];
    }
    self.updatePart = nil; //
    return offset;
}

- (void)updateWith:(id<MPTableViewUpdateDelegate>)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback {
    self.beginPos += offset;
    (*_rowPositionVec)[0] += offset;
    
    CGFloat originSection = self.section;
    self.section = newSection;
    
    for (NSUInteger i = 0; i < _numberOfRows; i++) {
        (*_rowPositionVec)[i + 1] += offset;
        
        [updateDelegate updateSection:newSection originSection:originSection exchangeCellAtIndex:i toIndex:i];
        
        if (callback) {
            [updateDelegate updateSection:newSection originSection:originSection exchangeCellAtIndex:i toIndex:i withOffset:offset];
        }
    }
    self.endPos += offset;
    if (callback) {
        [updateDelegate updateExchangeSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeHeader withSectionOffset:offset];
        [updateDelegate updateExchangeSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeFooter withSectionOffset:offset];
    }
}

- (NSString*)description {
    NSString *superDesc = [super description];
    return [NSString stringWithFormat:@"%@, section:%zd, numberOfRows:%zd, headerViewHeight:%.2f, footerViewHeight:%.2f", superDesc, self.section, _numberOfRows, _headerHeight, _footerHeight];
}

- (void)dealloc {
    delete _rowPositionVec;
}

@end