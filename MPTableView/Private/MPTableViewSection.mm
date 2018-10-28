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
_mpUpdateSort(const MPTableViewUpdateNode _first_, const MPTableViewUpdateNode _second_) {
    return _first_.index < _second_.index;
}

//NS_INLINE void
//_mpUpdateSwap(MPTableViewUpdateNodesVec *__vec, NSInteger __first, NSInteger __second) {
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
_converge(vector<_Vec_update> *__updateNodesVec) {
    sort(__updateNodesVec->begin(), __updateNodesVec->end(), _mpUpdateSort);
    NSInteger __backTracking = 0;
    NSInteger __step = 0;
    NSUInteger __count = __updateNodesVec->size();
    
    // make nodes no duplicate
    for (NSInteger i = 0; i < __count; ++i) {
        _Vec_update *_cellNode = &(*__updateNodesVec)[i];
        if (_cellNode->updateType == MPTableViewUpdateAdjust) {
            continue;
        }
        if (MPTableViewUpdateTypeUnstable(_cellNode->updateType)) { // unstable
            _cellNode->index += __step;
            if (_cellNode->updateType != MPTableViewUpdateReload) {
                --__step;
            }
            while (__backTracking < i) {
                _Vec_update *_backTrackingNode = &(*__updateNodesVec)[__backTracking];
                if (MPTableViewUpdateTypeStable(_backTrackingNode->updateType)) { //
                    if (_cellNode->index >= _backTrackingNode->index) { // unstable >= stable
                        ++_cellNode->index;
                        ++__step;
                    } else { //
                        _MPUpdateMove(__updateNodesVec, i, __backTracking);
                        ++__backTracking;
                        break;
                    }
                    ++__backTracking;
                } else {
                    break;
                }
            }
        } else { // stable
            while (__backTracking < i) {
                _Vec_update *_backTrackingNode = &(*__updateNodesVec)[__backTracking];
                if (MPTableViewUpdateTypeUnstable(_backTrackingNode->updateType)) {
                    if (_cellNode->index <= _backTrackingNode->index) { // stable <= unstable
                        _MPUpdateMove(__updateNodesVec, i, __backTracking);
                        ++__step;
                        NSInteger temp = ++__backTracking;
                        do {
                            _cellNode = &(*__updateNodesVec)[temp++];
                            ++_cellNode->index;
                        } while (temp <= i);
                        break;
                    }
                    ++__backTracking;
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
    _converge(_updateNodesVec);
    
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

#pragma mark - -update cells-

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
            BOOL isNeedCallback = [self.delegate __updateNeedToAnimateSection:section updateType:MPTableViewUpdateAdjust andOffset:offset];
            if (MPTableViewUpdateTypeUnstable(node.updateType)) {
                isNeedCallback = isNeedCallback && section.section < node.originIndex;
            }
            
            NSUInteger numberOfRows = [_delegate.dataSource MPTableView:_delegate numberOfRowsInSection:j];
            if (section.updatePart) {
                [section updatePart].newCount = numberOfRows;
                
                if (![section.updatePart formatNodesStable:[self.delegate __isContentMoving]]) {
                    MPTableViewThrowUpdateException(@"check for update indexpaths");
                }
                
                offset = [section updateUsingPartWithDelegate:self.delegate toSection:j withOffset:offset needCallback:isNeedCallback];
            } else {
                if (numberOfRows != section.numberOfRows) {
                    MPTableViewThrowUpdateException(@"check for the number of sections from data source");
                }
                
                offset = [section updateWithDelegate:self.delegate toSection:j withOffset:offset needCallback:isNeedCallback];
            }
        }
        
        if (MPTableViewUpdateTypeStable(node.updateType)) {
            ++step;
            
            MPTableViewSection *insertSection;
            if (node.updateType == MPTableViewUpdateInsert) {
                insertSection = [self.delegate __updateGetSectionAt:node.index];
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
                } else { // _sections[node.index] has not been offsetting, so its position is not accurate
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
            MPTableViewSection *insertSection = [self.delegate __updateGetSectionAt:node.index];
            if (node.originIndex != deleteSection.section) {
                assert(0); // beyond the bug
            }
            
            [_sections replaceObjectAtIndex:node.index withObject:insertSection];
            [insertSection rebuildAndBackup:self.delegate fromOriginSection:node.index withDistance:0];
            
            // node.index - step == node.originIndex
            CGFloat height = insertSection.endPos - insertSection.beginPos;
            offset += height - (deleteSection.endPos - deleteSection.beginPos);
            
            if ([self.delegate __updateNeedToAnimateSection:deleteSection updateType:MPTableViewUpdateDelete andOffset:offset]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; ++k) {
                    [self.delegate __updateSection:node.originIndex deleteCellAtIndex:k withAnimation:node.animation isSectionAnimation:deleteSection];
                }
                
                [self.delegate __updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [self.delegate __updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeFooter withAnimation:node.animation withDeleteSection:deleteSection];
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
            if (node.updateType == MPTableViewUpdateDelete && [self.delegate __updateNeedToAnimateSection:deleteSection updateType:MPTableViewUpdateDelete andOffset:offset]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; ++k) {
                    [self.delegate __updateSection:node.originIndex deleteCellAtIndex:k withAnimation:node.animation isSectionAnimation:deleteSection];
                }
                
                [self.delegate __updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [self.delegate __updateDeleteSectionViewAtIndex:node.originIndex withType:MPSectionTypeFooter withAnimation:node.animation withDeleteSection:deleteSection];
            }
            
            index = node.index;
        }
    }
    
    sectionCount += step;
    NSInteger j = index;
    
    if ([self.delegate __isContentMoving]) {
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
        if (section.section != j - step) {
            assert(0);
        }
        
        BOOL isNeedCallback = [self.delegate __updateNeedToAnimateSection:section updateType:MPTableViewUpdateAdjust andOffset:offset];
        
        NSUInteger numberOfRows = [_delegate.dataSource MPTableView:_delegate numberOfRowsInSection:j];
        if (section.updatePart) {
            [section updatePart].newCount = numberOfRows;
            
            if (![section.updatePart formatNodesStable:[self.delegate __isContentMoving]]) {
                MPTableViewThrowUpdateException(@"check for update indexpaths");
            }
            
            offset = [section updateUsingPartWithDelegate:self.delegate toSection:j withOffset:offset needCallback:isNeedCallback];
        } else {
            if (numberOfRows != section.numberOfRows) {
                MPTableViewThrowUpdateException(@"check for the number of sections from data source");
            }
            
            offset = [section updateWithDelegate:self.delegate toSection:j withOffset:offset needCallback:isNeedCallback];
        }
    }
    
    return offset;
}

- (void)saveInsertionsIfNecessaryForSection:(MPTableViewSection *)insertSection andNode:(MPTableViewUpdateNode)node andOffset:(CGFloat)offset {
    if ([self.delegate __updateNeedToAnimateSection:insertSection updateType:MPTableViewUpdateInsert andOffset:offset]) {
        for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
            if (![self.delegate __updateSection:node.index insertCellAtIndex:k withAnimation:node.animation isSectionAnimation:insertSection]) {
                void (^updateAction)(void) = ^{
                    if (!self.delegate) {
                        return ;
                    }
                    [self.delegate __updateSection:node.index insertCellAtIndex:k withAnimation:node.animation isSectionAnimation:insertSection];
                };
                [self.delegate._ignoredUpdateActions addObject:updateAction];
            }
        }
        
        if (![self.delegate __updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeHeader withAnimation:node.animation withInsertSection:insertSection]) {
            void (^updateAction)(void) = ^{
                if (!self.delegate) {
                    return ;
                }
                [self.delegate __updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeHeader withAnimation:node.animation withInsertSection:insertSection];
            };
            [self.delegate._ignoredUpdateActions addObject:updateAction];
        }
        if (![self.delegate __updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeFooter withAnimation:node.animation withInsertSection:insertSection]) {
            void (^updateAction)(void) = ^{
                if (!self.delegate) {
                    return ;
                }
                [self.delegate __updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeFooter withAnimation:node.animation withInsertSection:insertSection];
            };
            [self.delegate._ignoredUpdateActions addObject:updateAction];
        }
    } else {
        void (^updateAction)(void) = ^{
            if (!self.delegate) {
                return ;
            }
            
            for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
                [self.delegate __updateSection:node.index insertCellAtIndex:k withAnimation:node.animation isSectionAnimation:insertSection];
            }
            
            [self.delegate __updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeHeader withAnimation:node.animation withInsertSection:insertSection];
            [self.delegate __updateInsertSectionViewAtIndex:node.index withType:MPSectionTypeFooter withAnimation:node.animation withInsertSection:insertSection];
        };
        [self.delegate._ignoredUpdateActions addObject:updateAction];
    }
}

- (void)saveMovementsIfNecessaryForSection:(MPTableViewSection *)insertSection withBackup:(MPTableViewSection *)backup andNode:(MPTableViewUpdateNode)node andSectionIndex:(MPTableViewSectionIndex)sectionIndex withDistance:(CGFloat)distance {
    for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
        if (![self.delegate __updateSection:node.index moveInCellAtIndex:k fromOriginIndexPath:[MPIndexPath indexPathForRow:k inSection:sectionIndex.originIndex] withOriginHeight:[backup rowHeightAt:k] withDistance:distance]) {
            void (^updateAction)(void) = ^{
                if (!self.delegate) {
                    return ;
                }
                [self.delegate __updateSection:node.index moveInCellAtIndex:k fromOriginIndexPath:[MPIndexPath indexPathForRow:k inSection:sectionIndex.originIndex] withOriginHeight:[backup rowHeightAt:k] withDistance:distance];
            };
            [self.delegate._ignoredUpdateActions addObject:updateAction];
        }
    }
    
    if (![self.delegate __updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeHeader withOriginHeight:backup.headerHeight withDistance:distance]) {
        void (^updateAction)(void) = ^{
            if (!self.delegate) {
                return ;
            }
            [self.delegate __updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeHeader withOriginHeight:backup.headerHeight withDistance:distance];
        };
        [self.delegate._ignoredUpdateActions addObject:updateAction];
    }
    if (![self.delegate __updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeFooter withOriginHeight:backup.footerHeight withDistance:distance]) {
        void (^updateAction)(void) = ^{
            if (!self.delegate) {
                return ;
            }
            [self.delegate __updateMoveInSectionViewAtIndex:node.index fromOriginIndex:sectionIndex.originIndex withType:MPSectionTypeFooter withOriginHeight:backup.footerHeight withDistance:distance];
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
        
        BOOL isNeedCallback = [self.delegate __estimatedNeedToAdjustAt:section withOffset:offset];
        if (!isNeedCallback && offset == 0) {
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
        offset = [section updateEstimatedWith:self.delegate beginIndex:beginIndex withOffset:offset needCallback:isNeedCallback];
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
    
    NSInteger __start = 0;
    NSInteger __end = _numberOfRows; //
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

- (CGFloat)updateUsingPartWithDelegate:(MPTableView *)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback {
    updateDelegate._updateInsertOriginTopPosition = self.beginPos + self.headerHeight;
    
    self.beginPos += offset;
    MPTableViewUpdatePart *part = self.updatePart;
    
    NSUInteger originSection = self.section;
    self.section = newSection;
    CGFloat headerOffset = offset;
    CGFloat originHeaderHeight = self.headerHeight, originFooterHeight = self.footerHeight;
    
    if (callback) {
        CGFloat headerHeight = [updateDelegate __updateGetHeaderHeightInSection:self fromOriginSection:originSection withOffset:offset force:YES];
        if (headerHeight >= 0) {
            offset += headerHeight - self.headerHeight;
            self.headerHeight = headerHeight;
        }
    }
    
    updateDelegate._updateDeleteOriginTopPosition = self.beginPos + self.headerHeight;
    
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
        
        if (![updateDelegate __isContentMoving] || offset != 0) {
            for (NSInteger j = index; j <= idx; ++j) {
                updateDelegate._updateInsertOriginTopPosition = (*_rowPositionDeque)[j];
                
                if (offset != 0) {
                    (*_rowPositionDeque)[j] += offset;
                }
                
                NSInteger callBackIndex = j - step - 1;
                
                BOOL needToAdjust = NO;
                if (isInsert || callBackIndex < node.originIndex) {
                    needToAdjust = [updateDelegate __updateSection:newSection originSection:originSection adjustCellAtIndex:callBackIndex toIndex:j - 1] || callback;
                }
                
                if ([updateDelegate __isContentMoving] && ((originSection == [updateDelegate __beginIndexPath].section && callBackIndex < [updateDelegate __beginIndexPath].row) || (originSection == [updateDelegate __endIndexPath].section && callBackIndex > [updateDelegate __endIndexPath].row))) {
                    continue;
                }
                
                if (needToAdjust) {
                    CGFloat newOffset = [updateDelegate __updateSection:newSection originSection:originSection adjustCellAtIndex:callBackIndex toIndex:j - 1 withOffset:offset];
                    if (newOffset != 0) {
                        offset += newOffset;
                        (*_rowPositionDeque)[j] += newOffset;
                    }
                    updateDelegate._updateDeleteOriginTopPosition = (*_rowPositionDeque)[j];
                }
            }
        }
        
        if (isInsert) {
            ++step;
            CGFloat cellHeight;
            
            if (node.updateType == MPTableViewUpdateInsert) {
                cellHeight = [updateDelegate __updateInsertCellHeightAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection]];
                [self insertRowAt:node.index withHeight:cellHeight];
                offset += cellHeight;
                
                if (callback) {
                    if (![updateDelegate __updateSection:newSection insertCellAtIndex:node.index withAnimation:node.animation isSectionAnimation:nil]) {
                        void (^updateAction)(void) = ^{
                            if (!updateDelegate) {
                                return ;
                            }
                            [updateDelegate __updateSection:newSection insertCellAtIndex:node.index withAnimation:node.animation isSectionAnimation:nil];
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
                if (![updateDelegate __isContentMoving]) {
                    CGFloat newOffset = [updateDelegate __updateMoveInCellHeightAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection] originIndexPath:rowInfo.indexPath originHeight:rowInfo.frame.size.height withDistance:distance] - cellHeight;
                    if (newOffset != 0) {
                        offset += newOffset;
                        (*_rowPositionDeque)[node.index + 1] += newOffset;
                    }
                }
                
                if (![updateDelegate __updateSection:newSection moveInCellAtIndex:node.index fromOriginIndexPath:rowInfo.indexPath withOriginHeight:cellHeight withDistance:distance]) {
                    void (^updateAction)(void) = ^{
                        if (!updateDelegate) {
                            return ;
                        }
                        [updateDelegate __updateSection:newSection moveInCellAtIndex:node.index fromOriginIndexPath:rowInfo.indexPath withOriginHeight:cellHeight withDistance:distance];
                    };
                    [updateDelegate._ignoredUpdateActions addObject:updateAction];
                }
            }
            
            index = node.index + 2;
        } else if (node.updateType == MPTableViewUpdateReload) {
            CGFloat cellHeight = [updateDelegate __updateInsertCellHeightAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection]];
            offset += cellHeight - [self rowHeightAt:node.index];
            [self reloadRowAt:node.index withHeight:cellHeight];
            
            // node.index - step == node.originIndex
            [updateDelegate __updateSection:originSection deleteCellAtIndex:node.originIndex withAnimation:node.animation isSectionAnimation:nil];
            if (callback) {
                [updateDelegate __updateSection:newSection insertCellAtIndex:node.index withAnimation:node.animation isSectionAnimation:nil];
            }
            
            index = node.index + 2;
        } else { // node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut
            --step;
            
            CGFloat height = [self rowHeightAt:node.index];
            offset -= height;
            [self removeRowPositionAt:node.index];
            
            // node.index - step - 1 == node.originIndex
            if (node.updateType == MPTableViewUpdateDelete) {
                [updateDelegate __updateSection:originSection deleteCellAtIndex:node.originIndex withAnimation:node.animation isSectionAnimation:nil];
            }
            
            index = node.index + 1;
        }
    }
    
    _numberOfRows += step;
    
    if (![updateDelegate __isContentMoving] || step != 0) {
        for (NSInteger i = index; i <= _numberOfRows; ++i) {
            updateDelegate._updateInsertOriginTopPosition = (*_rowPositionDeque)[i];
            
            if (offset != 0) {
                (*_rowPositionDeque)[i] += offset;
            }
            
            NSInteger callBackIndex = i - step - 1;
            BOOL needToAdjust = [updateDelegate __updateSection:newSection originSection:originSection adjustCellAtIndex:callBackIndex toIndex:i - 1] || callback;
            
            if ([updateDelegate __isContentMoving] && ((originSection == [updateDelegate __beginIndexPath].section && callBackIndex < [updateDelegate __beginIndexPath].row) || (originSection == [updateDelegate __endIndexPath].section && callBackIndex > [updateDelegate __endIndexPath].row))) {
                continue;
            }
            
            if (needToAdjust) {
                CGFloat newOffset = [updateDelegate __updateSection:newSection originSection:originSection adjustCellAtIndex:callBackIndex toIndex:i - 1 withOffset:offset];
                if (newOffset != 0) {
                    offset += newOffset;
                    (*_rowPositionDeque)[i] += newOffset;
                }
                updateDelegate._updateDeleteOriginTopPosition = (*_rowPositionDeque)[i];
            }
        }
    }
    
    updateDelegate._updateInsertOriginTopPosition = self.endPos;
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    if (callback) {
        CGFloat footerHeight = [updateDelegate __updateGetFooterHeightInSection:self fromOriginSection:originSection withOffset:offset force:YES];
        if (footerHeight >= 0) {
            CGFloat newOffset = footerHeight - self.footerHeight;
            offset += newOffset;
            self.endPos += newOffset;
            self.footerHeight = footerHeight;
        }
    }
    
    updateDelegate._updateDeleteOriginTopPosition = self.endPos;
    
    BOOL needToAdjustHeader = [updateDelegate __updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeHeader] || callback;
    BOOL needToAdjustFooter = [updateDelegate __updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeFooter] || callback;
    if (needToAdjustHeader) {
        [updateDelegate __updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeHeader withOriginHeight:originHeaderHeight withSectionOffset:headerOffset];
    }
    if (needToAdjustFooter) {
        [updateDelegate __updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeFooter withOriginHeight:originFooterHeight withSectionOffset:footerOffset];
    }
    
    self.updatePart = nil; //
    
    return offset;
}

- (CGFloat)updateWithDelegate:(MPTableView *)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback {
    
    self.beginPos += offset;
    NSUInteger originSection = self.section;
    self.section = newSection;
    CGFloat headerOffset = offset;
    CGFloat originHeaderHeight = self.headerHeight, originFooterHeight = self.footerHeight;
    
    if (callback) {
        self.endPos += offset; // as a reference
        CGFloat headerHeight = [updateDelegate __updateGetHeaderHeightInSection:self fromOriginSection:originSection withOffset:offset force:YES];
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
        
        BOOL needToAdjust = [updateDelegate __updateSection:newSection originSection:originSection adjustCellAtIndex:i toIndex:i] || callback;
        
        if (needToAdjust) {
            CGFloat newOffset = [updateDelegate __updateSection:newSection originSection:originSection adjustCellAtIndex:i toIndex:i withOffset:offset];
            if (newOffset != 0) {
                offset += newOffset;
                (*_rowPositionDeque)[i + 1] += newOffset;
            }
        }
    }
    
    updateDelegate._updateInsertOriginTopPosition = self.endPos;
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    if (callback) {
        CGFloat footerHeight = [updateDelegate __updateGetFooterHeightInSection:self fromOriginSection:originSection withOffset:offset force:YES];
        if (footerHeight >= 0) {
            CGFloat newOffset = footerHeight - self.footerHeight;
            offset += newOffset;
            self.endPos += newOffset;
            self.footerHeight = footerHeight;
        }
    }
    
    updateDelegate._updateDeleteOriginTopPosition = self.endPos;
    
    BOOL needToAdjustHeader = [updateDelegate __updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeHeader] || callback;
    BOOL needToAdjustFooter = [updateDelegate __updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeFooter] || callback;
    if (needToAdjustHeader) {
        [updateDelegate __updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeHeader withOriginHeight:originHeaderHeight withSectionOffset:headerOffset];
    }
    if (needToAdjustFooter) {
        [updateDelegate __updateAdjustSectionViewAtIndex:originSection toIndex:newSection withType:MPSectionTypeFooter withOriginHeight:originFooterHeight withSectionOffset:footerOffset];
    }
    
    return offset;
}

//
- (MPTableViewSection *)rebuildAndBackup:(MPTableView *)updateDelegate fromOriginSection:(NSInteger)originSection withDistance:(CGFloat)distance {
    if ([updateDelegate __isEstimatedMode]) {
        if (![updateDelegate isUpdateForceReload] && ![updateDelegate __updateNeedToAnimateSection:self updateType:MPTableViewUpdateInsert andOffset:0]) {
            if (self.section == originSection) {
                return nil;
            } else {
                NSInteger temp = self.section;
                self.section = originSection;
                BOOL onscreen = [updateDelegate __updateNeedToAnimateSection:self updateType:MPTableViewUpdateMoveOut andOffset:0];
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
    
    CGFloat headerHeight = [updateDelegate __updateGetHeaderHeightInSection:self fromOriginSection:originSection withOffset:distance force:[updateDelegate isUpdateForceReload] || ![updateDelegate __isEstimatedMode]];
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
            CGFloat newOffset = [updateDelegate __rebuildCellAtSection:self.section fromOriginSection:originSection atIndex:i];
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
    
    CGFloat footerHeight = [updateDelegate __updateGetFooterHeightInSection:self fromOriginSection:originSection withOffset:distance force:[updateDelegate isUpdateForceReload] || ![updateDelegate __isEstimatedMode]];
    if (footerHeight >= 0) {
        CGFloat newOffset = footerHeight - self.footerHeight;
        //offset += newOffset;
        self.endPos += newOffset;
        self.footerHeight = footerHeight;
    }
    
    return backup;
}

- (CGFloat)updateEstimatedWith:(MPTableView *)updateDelegate beginIndex:(NSInteger)beginIndex withOffset:(CGFloat)offset needCallback:(BOOL)callback {
    self.beginPos += offset;
    
    CGFloat originSection = self.section;
    
    self.endPos += offset;
    CGFloat headerHeight = [updateDelegate __estimateAdjustSectionViewHeight:MPSectionTypeHeader inSection:self];
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
            CGFloat newOffset = [updateDelegate __estimateAdjustCellAtSection:originSection atIndex:i withOffset:offset];
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
    
    CGFloat footerHeight = [updateDelegate __estimateAdjustSectionViewHeight:MPSectionTypeFooter inSection:self];
    if (footerHeight >= 0) {
        CGFloat newOffset = footerHeight - self.footerHeight;
        offset += newOffset;
        self.endPos += newOffset;
        self.footerHeight = footerHeight;
    }
    
    if (callback) {
        [updateDelegate __estimateAdjustSectionViewAtSection:originSection withType:MPSectionTypeHeader];
        [updateDelegate __estimateAdjustSectionViewAtSection:originSection withType:MPSectionTypeFooter];
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
}

@end
