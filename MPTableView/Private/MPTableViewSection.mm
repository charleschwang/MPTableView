//
//  MPTableViewSection.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewSection.h"
#import <c++/v1/deque>
#import <c++/v1/vector>
#import <c++/v1/map>
#import <c++/v1/algorithm>

using namespace std;

NSExceptionName const MPTableViewException = @"MPTableViewException";
NSExceptionName const MPTableViewUpdateException = @"MPTableViewUpdateException";

@implementation MPTableViewPosition

- (instancetype)init {
    if (self = [super init]) {
        _beginPos = _endPos = 0;
    }
    return self;
}

+ (instancetype)positionWithBegin:(CGFloat)begin toEnd:(CGFloat)end {
    MPTableViewPosition *pos = [[[self class] alloc] init];
    pos.beginPos = begin;
    pos.endPos = end;
    return pos;
}

- (BOOL)isEqual:(id)object {
    if (!object) {
        return NO;
    } else {
        return _beginPos == [object beginPos] && _endPos == [object endPos];
    }
}

- (NSUInteger)hash {
    return (NSUInteger)fabs(_endPos);
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewPosition *position = [[self class] allocWithZone:zone];
    position.beginPos = _beginPos;
    position.endPos = _endPos;
    return position;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, beginPosition:%.2f, endPosition:%.2f", [super description], _beginPos, _endPos];
}

@end

#pragma mark -

class MPTableViewUpdateNode {
public:
    MPTableViewUpdateType updateType;
    MPTableViewRowAnimation animation;
    NSInteger index, originIndex;
};

typedef vector<MPTableViewUpdateNode> MPTableViewUpdateNodesVec;

NS_INLINE bool
_mpUpdateSort(const MPTableViewUpdateNode _first, const MPTableViewUpdateNode _second) {
    return _first.index < _second.index;
}

//NS_INLINE void
//_mpUpdateSwap(MPTableViewUpdateNodesVec *_vec, NSInteger _first, NSInteger _second) {
//    MPTableViewUpdateNode temp = _vec->at(_first);
//    _vec->at(_first) = _vec->at(_second);
//    _vec->at(_second) = temp;
//}

template <class _MPUpdateVec>
void
_MPUpdateMove(vector<_MPUpdateVec> *_vector, NSInteger _preIndex, NSInteger _currIndex) {
#if DEBUG
    assert(_preIndex < _vector->size() && _currIndex < _vector->size());
#endif
    
    NSInteger _begin;
    NSInteger _middle;
    NSInteger _end;
    if (_currIndex < _preIndex) {
        _begin = _currIndex;
        _middle = _preIndex;
        _end = _preIndex + 1;
    } else if (_currIndex > _preIndex) {
        _begin = _preIndex;
        _middle = _preIndex + 1;
        _end = _currIndex + 1;
    } else {
        return;
    }
    rotate(_vector->begin() + _begin, _vector->begin() + _middle, _vector->begin() + _end);
}

template <class _MPUpdateVec>
void
_MPConverge(vector<_MPUpdateVec> *_updateNodesVec) {
    sort(_updateNodesVec->begin(), _updateNodesVec->end(), _mpUpdateSort);
    
    NSInteger _backTracking = 0;
    NSInteger _step = 0;
    NSUInteger _count = _updateNodesVec->size();
    
    // make nodes no duplicate
    for (NSInteger i = 0; i < _count; ++i) {
        _MPUpdateVec *_cellNode = &(*_updateNodesVec)[i];
        if (_cellNode->updateType == MPTableViewUpdateAdjust) {
            continue;
        }
        if (MPTableViewUpdateTypeUnstable(_cellNode->updateType)) { // unstable
            _cellNode->index += _step;
            if (_cellNode->updateType != MPTableViewUpdateReload) {
                --_step;
            }
            while (_backTracking < i) {
                _MPUpdateVec *_backTrackingNode = &(*_updateNodesVec)[_backTracking];
                if (MPTableViewUpdateTypeStable(_backTrackingNode->updateType)) {
                    if (_cellNode->index >= _backTrackingNode->index) { // unstable >= stable
                        ++_cellNode->index;
                        ++_step;
                    } else {
                        _MPUpdateMove(_updateNodesVec, i, _backTracking);
                        ++_backTracking;
                        break;
                    }
                    ++_backTracking;
                } else {
                    break;
                }
            }
        } else { // stable
            while (_backTracking < i) {
                _MPUpdateVec *_backTrackingNode = &(*_updateNodesVec)[_backTracking];
                if (MPTableViewUpdateTypeUnstable(_backTrackingNode->updateType)) {
                    if (_cellNode->index <= _backTrackingNode->index) { // stable <= unstable
                        _MPUpdateMove(_updateNodesVec, i, _backTracking);
                        ++_step;
                        NSInteger tracking = ++_backTracking;
                        do {
                            _cellNode = &(*_updateNodesVec)[tracking++];
                            ++_cellNode->index;
                        } while (tracking <= i);
                        break;
                    }
                    ++_backTracking;
                } else {
                    break;
                }
            }
        }
    }
}

static bool
_updateNodesReverseBoundaryCheck(MPTableViewUpdateNodesVec *_updateNodesVec, NSUInteger _count, bool _isStable) {
    MPTableViewUpdateNodesVec::reverse_iterator _rlast = _updateNodesVec->rend();
    for (MPTableViewUpdateNodesVec::reverse_iterator _rfirst = _updateNodesVec->rbegin(); _rfirst != _rlast; ++_rfirst) {
        if (_isStable) {
            if (MPTableViewUpdateTypeStable(_rfirst->updateType)) {
                return _rfirst->index < _count;
            }
        } else {
            if (MPTableViewUpdateTypeUnstable(_rfirst->updateType)) {
                return _rfirst->originIndex < _count;
            }
        }
    }
    return YES;
}

@implementation MPTableViewUpdateBase {
@public
    MPTableViewUpdateNodesVec *_updateNodesVec;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingStableIndexes = [[NSMutableIndexSet alloc] init];
        _existingUnstableIndexes = [[NSMutableIndexSet alloc] init];
        _differ = 0;
        _newCount = NSNotFound;
        _originCount = NSNotFound;
        _updateNodesVec = new MPTableViewUpdateNodesVec();
    }
    return self;
}

- (BOOL)formatNodesStable:(BOOL)countCheckIgnored {
    _MPConverge(_updateNodesVec);
    
    if (countCheckIgnored) {
        return YES;
    }
    
    if (self.originCount + _differ != self.newCount) {
        return NO;
    } else {
        if (_updateNodesVec->size() == 0) {
            return YES;
        } else {
            return _updateNodesReverseBoundaryCheck(_updateNodesVec, self.originCount, NO) && _updateNodesReverseBoundaryCheck(_updateNodesVec, self.newCount, YES);
        }
    }
}

- (void)dealloc {
    delete _updateNodesVec;
    _updateNodesVec = NULL;
    _existingUnstableIndexes = _existingStableIndexes = nil;
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
    NSMutableIndexSet *_existingUpdatePartsIndexes;
    
    map<NSInteger, MPTableViewSectionIndex> _moveOutSectionsMap;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingUpdatePartsIndexes = [[NSMutableIndexSet alloc] init];
        
        _moveOutSectionsMap = map<NSInteger, MPTableViewSectionIndex>();
    }
    return self;
}

+ (MPTableViewUpdateManager *)managerWithDelegate:(MPTableView *)delegate andSections:(NSMutableArray *)sections {
    MPTableViewUpdateManager *result = [[MPTableViewUpdateManager alloc] init];
    result->_delegate = delegate;
    result->_sections = sections;
    return result;
}

- (NSUInteger)newCount {
    if ([super newCount] == NSNotFound) { // @optional
        [super setNewCount:[_delegate numberOfSections]];
    }
    return [super newCount];
}

- (NSUInteger)originCount {
    if ([super originCount] == NSNotFound) {
        [super setOriginCount:_sections.count];
    }
    return [super originCount];
}

- (BOOL)hasUpdateNodes {
    if (_updateNodesVec->size() != 0 || _existingUpdatePartsIndexes.count != 0) {
        return YES;
    } else {
        return NO;
    }
}

- (void)resetManager {
    _updateNodesVec->clear();
    _moveOutSectionsMap.clear();
    
    [_existingStableIndexes removeAllIndexes];
    [_existingUnstableIndexes removeAllIndexes];
    [_existingUpdatePartsIndexes removeAllIndexes];
    
    _differ = 0;
    self.originCount = self.newCount = NSNotFound;
}

- (void)dealloc {
    [_existingUpdatePartsIndexes removeAllIndexes];
    _existingUpdatePartsIndexes = nil;
    
    _moveOutSectionsMap.clear();
}

- (void)addEstimatedSection:(NSUInteger)section {
    [self getPartAt:section];
}

- (BOOL)addMoveOutSection:(NSUInteger)section {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
        --_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateMoveOut;
    node.originIndex = section;
    
    _updateNodesVec->push_back(node);
    return YES;
}

- (BOOL)addMoveInSection:(NSUInteger)section withOriginIndex:(NSInteger)originSection {
    if ([_existingStableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:section];
        ++_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateMoveIn;
    node.originIndex = section;
    
    _updateNodesVec->push_back(node);
    
    MPTableViewSectionIndex sectionIndex = MPTableViewSectionIndex();
    sectionIndex.section = _sections[originSection];
    sectionIndex.originIndex = originSection;
    _moveOutSectionsMap.insert(pair<NSInteger, MPTableViewSectionIndex>(section, sectionIndex));
    return YES;
}

- (BOOL)addDeleteSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
        --_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateDelete;
    node.animation = animation;
    node.originIndex = section;
    
    _updateNodesVec->push_back(node);
    return YES;
}

- (BOOL)addInsertSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingStableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:section];
        ++_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateInsert;
    node.animation = animation;
    node.originIndex = section;
    
    _updateNodesVec->push_back(node);
    return YES;
}

- (BOOL)addReloadSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateReload;
    node.animation = animation;
    node.originIndex = section;
    
    _updateNodesVec->push_back(node);
    return YES;
}

#pragma mark - update cells

- (MPTableViewUpdatePart *)getPartAt:(NSUInteger)index {
    MPTableViewSection *section = _sections[index];
    MPTableViewUpdatePart *part = section.updatePart;
    if (!part) {
        part = [[MPTableViewUpdatePart alloc] init];
        part.originCount = section.numberOfRows;
        section.updatePart = part;
        [_existingUpdatePartsIndexes addIndex:index];
    }
    return part;
}

- (BOOL)addMoveOutIndexPath:(MPIndexPath *)indexPath {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    return [part addMoveOutRow:indexPath.row];
}

- (BOOL)addMoveInIndexPath:(MPIndexPath *)indexPath withFrame:(CGRect)frame withOriginIndexPath:(MPIndexPath *)originIndexPath {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    return [part addMoveInRow:indexPath.row withFrame:frame withOriginIndexPath:originIndexPath];
}

- (BOOL)addDeleteIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    return [part addDeleteRow:indexPath.row withAnimation:animation];
}

- (BOOL)addInsertIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    return [part addInsertRow:indexPath.row withAnimation:animation];
}

- (BOOL)addReloadIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartAt:indexPath.section];
    return [part addReloadRow:indexPath.row withAnimation:animation];
}

- (CGFloat)startUpdate {
    CGFloat offset = 0;
    NSUInteger sectionCount = self.originCount;
    
    MPTableViewUpdateNodesVec *nodes = _updateNodesVec;
    NSInteger index = 0, step = 0;
    NSUInteger indexCount = nodes->size();
    
    for (NSInteger i = 0; i < indexCount; ++i) {
        MPTableViewUpdateNode node = (*nodes)[i];
        
        for (NSInteger j = index; j < node.index; ++j) {
            MPTableViewSection *section = _sections[j];
            BOOL needCallback = [self.delegate _updateNeedToAnimateSection:section updateType:MPTableViewUpdateAdjust andOffset:offset];
            if (MPTableViewUpdateTypeUnstable(node.updateType)) {
                needCallback = needCallback && section.section < node.originIndex;
            }
            
            NSUInteger numberOfRows = [_delegate.dataSource MPTableView:_delegate numberOfRowsInSection:j];
            if (section.updatePart) {
                [section updatePart].newCount = numberOfRows;
                
                if (![section.updatePart formatNodesStable:[self.delegate _isCellDragging]]) {
                    MPTableViewThrowUpdateException(@"check for update indexpaths")
                }
                
                offset = [section updateUsingPartWithDelegate:self.delegate toSection:j withOffset:offset needAnimated:needCallback];
            } else {
                if (numberOfRows != section.numberOfRows) {
                    MPTableViewThrowUpdateException(@"check for the number of sections from data source")
                }
                
                offset = [section updateWithDelegate:self.delegate toSection:j withOffset:offset needAnimated:needCallback];
            }
        }
        
        if (MPTableViewUpdateTypeStable(node.updateType)) {
            ++step;
            
            MPTableViewSection *insertSection;
            if (node.updateType == MPTableViewUpdateInsert) {
                insertSection = [self.delegate _updateGetSectionAt:node.index];
                [_sections insertObject:insertSection atIndex:node.index];
                
                [insertSection rebuildAndBackup:self.delegate fromOriginSection:node.index withDistance:0];
                
                [self saveInsertionsIfNecessaryForSection:insertSection andNode:node andOffset:offset];
            } else {
                MPTableViewSectionIndex sectionIndex = _moveOutSectionsMap.at(node.index);
                insertSection = sectionIndex.section;
                insertSection.section = node.index;
                
                if (insertSection.moveOutHeight < 0) {
                    insertSection.moveOutHeight = insertSection.endPos - insertSection.beginPos;
                } else {
                    insertSection.moveOutHeight = -1;
                }
                
                CGFloat currBeginPos;
                if (node.index == 0) {
                    currBeginPos = 0;
                } else { // _sections[node.index] has not been calculated, so its position is not accurate
                    MPTableViewSection *currSection = _sections[node.index - 1];
                    currBeginPos = currSection.endPos;
                }
                CGFloat distance = currBeginPos - insertSection.beginPos;
                [insertSection setPositionOffset:distance];
                
                [_sections insertObject:insertSection atIndex:node.index];
                
                MPTableViewSection *backup = [insertSection rebuildAndBackup:self.delegate fromOriginSection:sectionIndex.originIndex withDistance:distance];
                
                [self saveMovementsIfNecessaryForSection:insertSection withBackup:backup andNode:node andSectionIndex:sectionIndex withDistance:distance];
            }
            
            offset += insertSection.endPos - insertSection.beginPos;
            index = node.index + 1;
        } else if (node.updateType == MPTableViewUpdateReload) {
            MPTableViewSection *deleteSection = _sections[node.index];
            MPTableViewSection *insertSection = [self.delegate _updateGetSectionAt:node.index];
            NSAssert(node.originIndex == deleteSection.section, @"An unexpected bug, please contact the author"); // beyond the bug
            
            [_sections replaceObjectAtIndex:node.index withObject:insertSection];
            [insertSection rebuildAndBackup:self.delegate fromOriginSection:node.index withDistance:0];
            
            // node.index - step == node.originIndex
            CGFloat height = insertSection.endPos - insertSection.beginPos;
            offset += height - (deleteSection.endPos - deleteSection.beginPos);
            
            if ([self.delegate _updateNeedToAnimateSection:deleteSection updateType:MPTableViewUpdateDelete andOffset:offset]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; ++k) {
                    [self.delegate _updateSection:node.originIndex deleteCellAtIndex:k withAnimation:node.animation inSectionPosition:deleteSection];
                }
                
                [self.delegate _updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [self.delegate _updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeFooter withAnimation:node.animation withDeleteSection:deleteSection];
            }
            
            [self saveInsertionsIfNecessaryForSection:insertSection andNode:node andOffset:offset];
            
            index = node.index + 1;
        } else { // node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut
            --step;
            
            MPTableViewSection *deleteSection = _sections[node.index];
            CGFloat height;
            if (node.updateType == MPTableViewUpdateDelete) {
                height = deleteSection.endPos - deleteSection.beginPos;
            } else {
                if (deleteSection.moveOutHeight < 0) {
                    deleteSection.moveOutHeight = height = deleteSection.endPos - deleteSection.beginPos;
                } else {
                    height = deleteSection.moveOutHeight;
                    deleteSection.moveOutHeight = -1;
                }
            }
            offset -= height;
            [_sections removeObjectAtIndex:node.index];
            
            // node.index - step - 1 == node.originIndex
            if (node.updateType == MPTableViewUpdateDelete && [self.delegate _updateNeedToAnimateSection:deleteSection updateType:MPTableViewUpdateDelete andOffset:offset]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; ++k) {
                    [self.delegate _updateSection:node.originIndex deleteCellAtIndex:k withAnimation:node.animation inSectionPosition:deleteSection];
                }
                
                [self.delegate _updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [self.delegate _updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeFooter withAnimation:node.animation withDeleteSection:deleteSection];
            }
            
            index = node.index;
        }
    }
    
    sectionCount += step;
    NSInteger j = index;
    
    if ([self.delegate _isCellDragging]) {
        if (self.moveToSection > self.moveFromSection) {
            j = self.moveFromSection;
            sectionCount = self.moveToSection + 1;
        } else {
            j = self.moveToSection;
            sectionCount = self.moveFromSection + 1;
        }
    }
    
    for (; j < sectionCount; ++j) {
        MPTableViewSection *section = _sections[j];
        NSAssert(section.section == j - step, @"An unexpected bug, please contact the author");
        
        BOOL needCallback = [self.delegate _updateNeedToAnimateSection:section updateType:MPTableViewUpdateAdjust andOffset:offset];
        
        NSUInteger numberOfRows = [_delegate.dataSource MPTableView:_delegate numberOfRowsInSection:j];
        if (section.updatePart) {
            [section updatePart].newCount = numberOfRows;
            
            if (![section.updatePart formatNodesStable:[self.delegate _isCellDragging]]) {
                MPTableViewThrowUpdateException(@"check for update indexpaths")
            }
            
            offset = [section updateUsingPartWithDelegate:self.delegate toSection:j withOffset:offset needAnimated:needCallback];
        } else {
            if (numberOfRows != section.numberOfRows) {
                MPTableViewThrowUpdateException(@"check for the number of sections from data source")
            }
            
            offset = [section updateWithDelegate:self.delegate toSection:j withOffset:offset needAnimated:needCallback];
        }
    }
    
    return offset;
}

- (void)saveInsertionsIfNecessaryForSection:(MPTableViewSection *)insertSection andNode:(MPTableViewUpdateNode)node andOffset:(CGFloat)offset {
    if ([self.delegate _updateNeedToAnimateSection:insertSection updateType:MPTableViewUpdateInsert andOffset:offset]) {
        for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
            if (![self.delegate _updateSection:node.index insertCellAtIndex:k withAnimation:node.animation inSectionPosition:insertSection]) {
                void (^updateAction)(void) = ^{
                    if (!self.delegate) {
                        return;
                    }
                    [self.delegate _updateSection:node.index insertCellAtIndex:k withAnimation:node.animation inSectionPosition:insertSection];
                };
                [self.delegate._ignoredUpdateActions addObject:updateAction];
            }
        }
        
        if (![self.delegate _updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeHeader withAnimation:node.animation withInsertSection:insertSection]) {
            void (^updateAction)(void) = ^{
                if (!self.delegate) {
                    return;
                }
                [self.delegate _updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeHeader withAnimation:node.animation withInsertSection:insertSection];
            };
            [self.delegate._ignoredUpdateActions addObject:updateAction];
        }
        if (![self.delegate _updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeFooter withAnimation:node.animation withInsertSection:insertSection]) {
            void (^updateAction)(void) = ^{
                if (!self.delegate) {
                    return;
                }
                [self.delegate _updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeFooter withAnimation:node.animation withInsertSection:insertSection];
            };
            [self.delegate._ignoredUpdateActions addObject:updateAction];
        }
    } else {
        void (^updateAction)(void) = ^{
            if (!self.delegate) {
                return;
            }
            
            for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
                [self.delegate _updateSection:node.index insertCellAtIndex:k withAnimation:node.animation inSectionPosition:insertSection];
            }
            
            [self.delegate _updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeHeader withAnimation:node.animation withInsertSection:insertSection];
            [self.delegate _updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeFooter withAnimation:node.animation withInsertSection:insertSection];
        };
        [self.delegate._ignoredUpdateActions addObject:updateAction];
    }
}

- (void)saveMovementsIfNecessaryForSection:(MPTableViewSection *)insertSection withBackup:(MPTableViewSection *)backup andNode:(MPTableViewUpdateNode)node andSectionIndex:(MPTableViewSectionIndex)sectionIndex withDistance:(CGFloat)distance {
    for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
        if (![self.delegate _updateSection:node.index moveInCellAtIndex:k fromOriginIndexPath:[MPIndexPath indexPathForRow:k inSection:sectionIndex.originIndex] withOriginHeight:[backup rowHeightAt:k] withDistance:distance]) {
            void (^updateAction)(void) = ^{
                if (!self.delegate) {
                    return;
                }
                [self.delegate _updateSection:node.index moveInCellAtIndex:k fromOriginIndexPath:[MPIndexPath indexPathForRow:k inSection:sectionIndex.originIndex] withOriginHeight:[backup rowHeightAt:k] withDistance:distance];
            };
            [self.delegate._ignoredUpdateActions addObject:updateAction];
        }
    }
    
    if (![self.delegate _updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeHeader withOriginHeight:backup.headerHeight withDistance:distance]) {
        void (^updateAction)(void) = ^{
            if (!self.delegate) {
                return;
            }
            [self.delegate _updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeHeader withOriginHeight:backup.headerHeight withDistance:distance];
        };
        [self.delegate._ignoredUpdateActions addObject:updateAction];
    }
    if (![self.delegate _updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeFooter withOriginHeight:backup.footerHeight withDistance:distance]) {
        void (^updateAction)(void) = ^{
            if (!self.delegate) {
                return;
            }
            [self.delegate _updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeFooter withOriginHeight:backup.footerHeight withDistance:distance];
        };
        [self.delegate._ignoredUpdateActions addObject:updateAction];
    }
}

@end

#pragma mark -

class MPTableViewRowInfo {
public:
    MPIndexPath *indexPath;
    CGRect frame;
    
    ~MPTableViewRowInfo() {
        indexPath = nil;
    }
};

@implementation MPTableViewUpdatePart {
    @package
    map<NSUInteger, MPTableViewRowInfo> _moveOutRowInfosMap;
}

- (instancetype)init {
    if (self = [super init]) {
        _moveOutRowInfosMap = map<NSUInteger, MPTableViewRowInfo>();
    }
    return self;
}

- (void)dealloc {
    _moveOutRowInfosMap.clear();
}

- (BOOL)addMoveOutRow:(NSUInteger)row {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
        --_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = row;
    node.updateType = MPTableViewUpdateMoveOut;
    node.originIndex = row;
    
    _updateNodesVec->push_back(node);
    return YES;
}

- (BOOL)addMoveInRow:(NSUInteger)row withFrame:(CGRect)frame withOriginIndexPath:(MPIndexPath *)originIndexPath {
    if ([_existingStableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:row];
        ++_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.originIndex = node.index = row;
    
    node.updateType = MPTableViewUpdateMoveIn;
    _updateNodesVec->push_back(node);
    
    MPTableViewRowInfo rowInfo = MPTableViewRowInfo();
    rowInfo.indexPath = originIndexPath;
    rowInfo.frame = frame;
    _moveOutRowInfosMap.insert(pair<NSUInteger, MPTableViewRowInfo>(row, rowInfo));
    
    return YES;
}

- (BOOL)addDeleteRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
        --_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = row;
    node.updateType = MPTableViewUpdateDelete;
    node.animation = animation;
    node.originIndex = row;
    
    _updateNodesVec->push_back(node);
    return YES;
}

- (BOOL)addInsertRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingStableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:row];
        ++_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = row;
    node.updateType = MPTableViewUpdateInsert;
    node.animation = animation;
    node.originIndex = row;
    
    _updateNodesVec->push_back(node);
    return YES;
}

- (BOOL)addReloadRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = row;
    node.updateType = MPTableViewUpdateReload;
    node.animation = animation;
    node.originIndex = row;
    
    _updateNodesVec->push_back(node);
    return YES;
}

@end

#pragma mark -

@implementation MPTableViewEstimatedManager

- (CGFloat)startUpdate:(MPIndexPathStruct)firstIndexPath {
    CGFloat offset = 0;
    NSUInteger sectionCount = self.sections.count;
    
    for (NSInteger j = firstIndexPath.section; j < sectionCount; ++j) {
        MPTableViewSection *section = _sections[j];
        
        BOOL needCallback = [self.delegate _estimatedNeedToAdjustAt:section withOffset:offset];
        if (!needCallback && offset == 0) {
            continue;
        }
        NSUInteger beginIndex = 0;
        if (j == firstIndexPath.section) {
            if (firstIndexPath.row == MPSectionTypeHeader) {
                beginIndex = 0;
            } else {
                beginIndex = firstIndexPath.row;
            }
        }
        offset = [section updateEstimatedWith:self.delegate beginIndex:beginIndex withOffset:offset needAnimated:needCallback];
    }
    
    return offset;
}

@end

#pragma mark -

@implementation MPTableViewSection {
    deque<CGFloat> *_rowPositionDeque;
}

+ (instancetype)section {
    return [[[self class] alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        [self resetSection];
    }
    return self;
}

- (void)resetSection {
    if (!_rowPositionDeque) {
        _rowPositionDeque = new deque<CGFloat>();
    }
    if (_rowPositionDeque->size() > 0) {
        _rowPositionDeque->clear();
    }
    
    _rowPositionDeque->push_back(0);
    _headerHeight = _footerHeight = 0;
    _numberOfRows = 0;
    self.beginPos = self.endPos = 0;
    self.section = NSNotFound;
    self.moveOutHeight = -1;
    
    self.updatePart = nil;
}

- (void)setNumberOfRows:(NSUInteger)numberOfRows {
    NSAssert(numberOfRows < MPTableViewMaxCount, @"too many rows");
    
    _numberOfRows = numberOfRows;
    //_rowPositionVec->resize(numberOfRows + 1);
    _rowPositionDeque->at(0) = self.beginPos + _headerHeight;
}

- (void)addRowWithPosition:(CGFloat)end {
    _rowPositionDeque->push_back(end);
}

- (CGFloat)rowPositionBeginAt:(NSInteger)index {
    return (*_rowPositionDeque)[index];
}

- (CGFloat)rowHeightAt:(NSInteger)index {
    return (*_rowPositionDeque)[index + 1] - (*_rowPositionDeque)[index];
}

- (CGFloat)rowPositionEndAt:(NSInteger)index {
    return (*_rowPositionDeque)[index + 1];
}

- (NSInteger)rowAtContentOffset:(CGFloat)target {
    if (target <= self.beginPos + self.headerHeight) {
        return MPSectionTypeHeader;
    }
    if (target >= self.endPos - self.footerHeight) {
        return MPSectionTypeFooter;
    }
    
    NSInteger start = 0;
    NSInteger end = _numberOfRows;
    NSInteger middle = 0;
    while (start <= end) {
        middle = (start + end) / 2;
        CGFloat beginPos = [self rowPositionBeginAt:middle];
        CGFloat endPos = [self rowPositionEndAt:middle];
        if (beginPos > target) {
            end = middle - 1;
        } else if (endPos < target) {
            start = middle + 1;
        } else {
            return middle;
        }
    }
    return NSNotFound;
}

- (void)removeRowPositionAt:(NSInteger)index {
    deque<CGFloat>::iterator it = _rowPositionDeque->begin() + index + 1;
    _rowPositionDeque->erase(it);
}

- (void)insertRowAt:(NSInteger)index withHeight:(CGFloat)height {
    deque<CGFloat>::iterator it = _rowPositionDeque->begin() + index + 1;
    CGFloat cellEndPos = height + (*_rowPositionDeque)[index];
    _rowPositionDeque->insert(it, cellEndPos);
}

- (void)reloadRowAt:(NSInteger)index withHeight:(CGFloat)height {
    (*_rowPositionDeque)[index + 1] = (*_rowPositionDeque)[index] + height;
}

- (void)setPositionOffset:(CGFloat)offset {
    if (offset == 0) {
        return;
    }
    
    self.beginPos += offset;
    self.endPos += offset;
    for (NSInteger i = 0; i <= _numberOfRows; ++i) {
        (*_rowPositionDeque)[i] += offset;
    }
}

- (CGFloat)updateUsingPartWithDelegate:(MPTableView *)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needAnimated:(BOOL)callback {
    [updateDelegate _setUpdateInsertOriginTopPosition:self.beginPos + self.headerHeight];
    
    self.beginPos += offset;
    MPTableViewUpdatePart *part = self.updatePart;
    
    NSUInteger originSection = self.section;
    self.section = newSection;
    CGFloat headerOffset = offset;
    CGFloat originHeaderHeight = self.headerHeight, originFooterHeight = self.footerHeight;
    
    if (callback) {
        CGFloat headerHeight = [updateDelegate _updateGetHeaderHeightInSection:self fromOriginSection:originSection withOffset:offset force:YES];
        if (headerHeight >= 0) {
            offset += headerHeight - self.headerHeight;
            self.headerHeight = headerHeight;
        }
    }
    
    [updateDelegate _setUpdateDeleteOriginTopPosition:self.beginPos + self.headerHeight];
    
    (*_rowPositionDeque)[0] += offset; // the deque may be empty, but this seems to be safe...
    
    MPTableViewUpdateNodesVec *nodes = part->_updateNodesVec;
    NSInteger index = 1, step = 0;
    NSUInteger indexCount = nodes->size();
    for (NSInteger i = 0; i < indexCount; ++i) {
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
        
        if (![updateDelegate _isCellDragging] || offset != 0) {
            for (NSInteger j = index; j <= idx; ++j) {
                [updateDelegate _setUpdateInsertOriginTopPosition:(*_rowPositionDeque)[j]];
                
                if (offset != 0) {
                    (*_rowPositionDeque)[j] += offset;
                }
                
                NSInteger callBackIndex = j - step - 1;
                
                BOOL needToAdjust = NO;
                if (isInsert || callBackIndex < node.originIndex) {
                    needToAdjust = [updateDelegate _updateSection:newSection originSection:originSection exchangeCellIndex:callBackIndex forIndex:j - 1] || callback;
                }
                
                if ([updateDelegate _isCellDragging] && ((originSection == [updateDelegate _beginIndexPath].section && callBackIndex < [updateDelegate _beginIndexPath].row) || (originSection == [updateDelegate _endIndexPath].section && callBackIndex > [updateDelegate _endIndexPath].row))) {
                    continue;
                }
                
                if (needToAdjust) {
                    CGFloat newOffset = [updateDelegate _updateSection:newSection originSection:originSection adjustCellAtIndex:callBackIndex toIndex:j - 1 withOffset:offset];
                    if (newOffset != 0) {
                        offset += newOffset;
                        (*_rowPositionDeque)[j] += newOffset;
                    }
                    [updateDelegate _setUpdateDeleteOriginTopPosition:(*_rowPositionDeque)[j]];
                }
            }
        }
        
        if (isInsert) {
            ++step;
            CGFloat cellHeight;
            
            if (node.updateType == MPTableViewUpdateInsert) {
                cellHeight = [updateDelegate _updateGetInsertCellHeightAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection]];
                [self insertRowAt:node.index withHeight:cellHeight];
                offset += cellHeight;
                
                if (callback) {
                    if (![updateDelegate _updateSection:newSection insertCellAtIndex:node.index withAnimation:node.animation inSectionPosition:nil]) {
                        void (^updateAction)(void) = ^{
                            if (!updateDelegate) {
                                return;
                            }
                            [updateDelegate _updateSection:newSection insertCellAtIndex:node.index withAnimation:node.animation inSectionPosition:nil];
                        };
                        [updateDelegate._ignoredUpdateActions addObject:updateAction];
                    }
                }
            } else {
                MPTableViewRowInfo rowInfo = part->_moveOutRowInfosMap.at(node.index);
                cellHeight = rowInfo.frame.size.height;
                [self insertRowAt:node.index withHeight:cellHeight];
                offset += cellHeight;
                
                CGFloat distance = [self rowPositionBeginAt:node.index] - rowInfo.frame.origin.y;
                if (![updateDelegate _isCellDragging]) {
                    CGFloat newOffset = [updateDelegate _updateGetMoveInCellHeightAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection] originIndexPath:rowInfo.indexPath originHeight:rowInfo.frame.size.height withDistance:distance] - cellHeight;
                    if (newOffset != 0) {
                        offset += newOffset;
                        (*_rowPositionDeque)[node.index + 1] += newOffset;
                    }
                }
                
                if (![updateDelegate _updateSection:newSection moveInCellAtIndex:node.index fromOriginIndexPath:rowInfo.indexPath withOriginHeight:cellHeight withDistance:distance]) {
                    void (^updateAction)(void) = ^{
                        if (!updateDelegate) {
                            return;
                        }
                        [updateDelegate _updateSection:newSection moveInCellAtIndex:node.index fromOriginIndexPath:rowInfo.indexPath withOriginHeight:cellHeight withDistance:distance];
                    };
                    [updateDelegate._ignoredUpdateActions addObject:updateAction];
                }
            }
            
            index = node.index + 2;
        } else if (node.updateType == MPTableViewUpdateReload) {
            CGFloat cellHeight = [updateDelegate _updateGetInsertCellHeightAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection]];
            offset += cellHeight - [self rowHeightAt:node.index];
            [self reloadRowAt:node.index withHeight:cellHeight];
            
            // node.index - step == node.originIndex
            [updateDelegate _updateSection:originSection deleteCellAtIndex:node.originIndex withAnimation:node.animation inSectionPosition:nil];
            if (callback) {
                [updateDelegate _updateSection:newSection insertCellAtIndex:node.index withAnimation:node.animation inSectionPosition:nil];
            }
            
            index = node.index + 2;
        } else { // node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut
            --step;
            
            CGFloat height = [self rowHeightAt:node.index];
            offset -= height;
            [self removeRowPositionAt:node.index];
            
            // node.index - step - 1 == node.originIndex
            if (node.updateType == MPTableViewUpdateDelete) {
                [updateDelegate _updateSection:originSection deleteCellAtIndex:node.originIndex withAnimation:node.animation inSectionPosition:nil];
            }
            
            index = node.index + 1;
        }
    }
    
    _numberOfRows += step;
    
    if (![updateDelegate _isCellDragging] || step != 0) {
        for (NSInteger i = index; i <= _numberOfRows; ++i) {
            [updateDelegate _setUpdateInsertOriginTopPosition:(*_rowPositionDeque)[i]];
            
            if (offset != 0) {
                (*_rowPositionDeque)[i] += offset;
            }
            
            NSInteger callBackIndex = i - step - 1;
            BOOL needToAdjust = [updateDelegate _updateSection:newSection originSection:originSection exchangeCellIndex:callBackIndex forIndex:i - 1] || callback;
            
            if ([updateDelegate _isCellDragging] && ((originSection == [updateDelegate _beginIndexPath].section && callBackIndex < [updateDelegate _beginIndexPath].row) || (originSection == [updateDelegate _endIndexPath].section && callBackIndex > [updateDelegate _endIndexPath].row))) {
                continue;
            }
            
            if (needToAdjust) {
                CGFloat newOffset = [updateDelegate _updateSection:newSection originSection:originSection adjustCellAtIndex:callBackIndex toIndex:i - 1 withOffset:offset];
                if (newOffset != 0) {
                    offset += newOffset;
                    (*_rowPositionDeque)[i] += newOffset;
                }
                [updateDelegate _setUpdateDeleteOriginTopPosition:(*_rowPositionDeque)[i]];
            }
        }
    }
    
    [updateDelegate _setUpdateInsertOriginTopPosition:self.endPos];
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    if (callback) {
        CGFloat footerHeight = [updateDelegate _updateGetFooterHeightInSection:self fromOriginSection:originSection withOffset:offset force:YES];
        if (footerHeight >= 0) {
            CGFloat newOffset = footerHeight - self.footerHeight;
            offset += newOffset;
            self.endPos += newOffset;
            self.footerHeight = footerHeight;
        }
    }
    
    [updateDelegate _setUpdateDeleteOriginTopPosition:self.endPos];
    
    BOOL needToAdjustHeader = [updateDelegate _updateExchangeSectionViewAtIndex:originSection forIndex:newSection withType:MPSectionTypeHeader] || callback; // can't put this "callback" on left
    BOOL needToAdjustFooter = [updateDelegate _updateExchangeSectionViewAtIndex:originSection forIndex:newSection withType:MPSectionTypeFooter] || callback;
    if (needToAdjustHeader) {
        [updateDelegate _updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeHeader withOriginHeight:originHeaderHeight withSectionOffset:headerOffset];
    }
    if (needToAdjustFooter) {
        [updateDelegate _updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeFooter withOriginHeight:originFooterHeight withSectionOffset:footerOffset];
    }
    
    self.updatePart = nil;
    
    return offset;
}

- (CGFloat)updateWithDelegate:(MPTableView *)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needAnimated:(BOOL)callback {
    
    self.beginPos += offset;
    NSUInteger originSection = self.section;
    self.section = newSection;
    CGFloat headerOffset = offset;
    CGFloat originHeaderHeight = self.headerHeight, originFooterHeight = self.footerHeight;
    
    if (callback) {
        self.endPos += offset; // as a reference
        CGFloat headerHeight = [updateDelegate _updateGetHeaderHeightInSection:self fromOriginSection:originSection withOffset:offset force:YES];
        self.endPos -= offset; // reset the reference
        if (headerHeight >= 0) {
            offset += headerHeight - self.headerHeight;
            self.headerHeight = headerHeight;
        }
    }
    
    (*_rowPositionDeque)[0] += offset;
    
    for (NSUInteger i = 0; i < _numberOfRows; ++i) {
        if (offset != 0) {
            (*_rowPositionDeque)[i + 1] += offset;
        }
        
        BOOL needToAdjust = [updateDelegate _updateSection:newSection originSection:originSection exchangeCellIndex:i forIndex:i] || callback;
        
        if (needToAdjust) {
            CGFloat newOffset = [updateDelegate _updateSection:newSection originSection:originSection adjustCellAtIndex:i toIndex:i withOffset:offset];
            if (newOffset != 0) {
                offset += newOffset;
                (*_rowPositionDeque)[i + 1] += newOffset;
            }
        }
    }
    
    [updateDelegate _setUpdateInsertOriginTopPosition:self.endPos];
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    if (callback) {
        CGFloat footerHeight = [updateDelegate _updateGetFooterHeightInSection:self fromOriginSection:originSection withOffset:offset force:YES];
        if (footerHeight >= 0) {
            CGFloat newOffset = footerHeight - self.footerHeight;
            offset += newOffset;
            self.endPos += newOffset;
            self.footerHeight = footerHeight;
        }
    }
    
    [updateDelegate _setUpdateDeleteOriginTopPosition:self.endPos];
    
    BOOL needToAdjustHeader = [updateDelegate _updateExchangeSectionViewAtIndex:originSection forIndex:newSection withType:MPSectionTypeHeader] || callback;
    BOOL needToAdjustFooter = [updateDelegate _updateExchangeSectionViewAtIndex:originSection forIndex:newSection withType:MPSectionTypeFooter] || callback;
    if (needToAdjustHeader) {
        [updateDelegate _updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeHeader withOriginHeight:originHeaderHeight withSectionOffset:headerOffset];
    }
    if (needToAdjustFooter) {
        [updateDelegate _updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeFooter withOriginHeight:originFooterHeight withSectionOffset:footerOffset];
    }
    
    return offset;
}

- (MPTableViewSection *)rebuildAndBackup:(MPTableView *)updateDelegate fromOriginSection:(NSInteger)originSection withDistance:(CGFloat)distance {
    if ([updateDelegate _isEstimatedMode]) {
        if (![updateDelegate isUpdateForceReload] && ![updateDelegate _updateNeedToAnimateSection:self updateType:MPTableViewUpdateInsert andOffset:0]) {
            if (self.section == originSection) {
                return nil;
            } else {
                NSInteger temp = self.section;
                self.section = originSection;
                BOOL onscreen = [updateDelegate _updateNeedToAnimateSection:self updateType:MPTableViewUpdateMoveOut andOffset:0];
                self.section = temp;
                
                if (!onscreen) {
                    return nil;
                }
            }
        }
    } else {
        if (self.section == originSection) { // insertion
            return nil;
        }
    }
    
    MPTableViewSection *backup;
    if (self.section == originSection) {
        backup = nil;
    } else {
        backup = [self copy];
    }
    
    CGFloat offset = 0;
    
    CGFloat headerHeight = [updateDelegate _updateGetHeaderHeightInSection:self fromOriginSection:originSection withOffset:distance force:[updateDelegate isUpdateForceReload] || ![updateDelegate _isEstimatedMode]];
    if (headerHeight >= 0) {
        offset += headerHeight - self.headerHeight;
        self.headerHeight = headerHeight;
    }
    
    (*_rowPositionDeque)[0] += offset;
    
    BOOL cellCallback = YES;
    for (NSUInteger i = 0; i < _numberOfRows; ++i) {
        if (offset != 0) {
            (*_rowPositionDeque)[i + 1] += offset;
        }
        
        if (cellCallback) {
            CGFloat newOffset = [updateDelegate _rebuildCellAtSection:self.section fromOriginSection:originSection atIndex:i];
            if (newOffset != 0) {
                if (newOffset == MPTableViewMaxSize) {
                    cellCallback = NO;
                } else {
                    offset += newOffset;
                    (*_rowPositionDeque)[i + 1] += newOffset;
                }
            }
        }
    }
    
    self.endPos += offset;
    
    CGFloat footerHeight = [updateDelegate _updateGetFooterHeightInSection:self fromOriginSection:originSection withOffset:distance force:[updateDelegate isUpdateForceReload] || ![updateDelegate _isEstimatedMode]];
    if (footerHeight >= 0) {
        CGFloat newOffset = footerHeight - self.footerHeight;
        self.endPos += newOffset;
        self.footerHeight = footerHeight;
    }
    
    return backup;
}

- (CGFloat)updateEstimatedWith:(MPTableView *)updateDelegate beginIndex:(NSInteger)beginIndex withOffset:(CGFloat)offset needAnimated:(BOOL)callback {
    self.beginPos += offset;
    
    CGFloat originSection = self.section;
    
    self.endPos += offset;
    CGFloat headerHeight = [updateDelegate _estimateAdjustSectionViewHeight:MPSectionTypeHeader inSection:self];
    self.endPos -= offset;
    if (headerHeight >= 0) {
        offset += headerHeight - self.headerHeight;
        self.headerHeight = headerHeight;
    }
    
    (*_rowPositionDeque)[0] += offset;
    
    BOOL cellCallback = YES;
    for (NSUInteger i = (headerHeight < 0 ? beginIndex : 0); i < _numberOfRows; ++i) {
        if (offset != 0) {
            (*_rowPositionDeque)[i + 1] += offset;
        }
        
        if (callback && cellCallback) {
            CGFloat newOffset = [updateDelegate _estimateAdjustCellAtSection:originSection atIndex:i withOffset:offset];
            if (newOffset != 0) {
                if (newOffset == MPTableViewMaxSize) {
                    cellCallback = NO;
                } else {
                    offset += newOffset;
                    (*_rowPositionDeque)[i + 1] += newOffset;
                }
            }
        }
    }
    
    self.endPos += offset;
    
    CGFloat footerHeight = [updateDelegate _estimateAdjustSectionViewHeight:MPSectionTypeFooter inSection:self];
    if (footerHeight >= 0) {
        CGFloat newOffset = footerHeight - self.footerHeight;
        offset += newOffset;
        self.endPos += newOffset;
        self.footerHeight = footerHeight;
    }
    
    if (callback) {
        [updateDelegate _estimateAdjustSectionViewAtSection:originSection withType:MPSectionTypeHeader];
        [updateDelegate _estimateAdjustSectionViewAtSection:originSection withType:MPSectionTypeFooter];
    }
    
    return offset;
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewSection *section = [super copyWithZone:zone];
    section.headerHeight = self.headerHeight;
    section.footerHeight = self.footerHeight;
    section->_rowPositionDeque = new deque<CGFloat>(*_rowPositionDeque);
    section.numberOfRows = self.numberOfRows;
    section.moveOutHeight = self.moveOutHeight;
    
    return section;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, section:%zd, numberOfRows:%zd, headerHeight:%.2f, footerHeight:%.2f", [super description], self.section, _numberOfRows, _headerHeight, _footerHeight];
}

- (void)dealloc {
    delete _rowPositionDeque;
    _rowPositionDeque = NULL;
}

@end
