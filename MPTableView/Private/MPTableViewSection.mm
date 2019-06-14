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
        _startPos = _endPos = 0;
    }
    return self;
}

+ (instancetype)positionStart:(CGFloat)start toEnd:(CGFloat)end {
    MPTableViewPosition *pos = [[[self class] alloc] init];
    pos.startPos = start;
    pos.endPos = end;
    return pos;
}

- (BOOL)isEqual:(id)object {
    if (!object) {
        return NO;
    } else {
        return _startPos == [object startPos] && _endPos == [object endPos];
    }
}

- (NSUInteger)hash {
    return (NSUInteger)fabs(_endPos);
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewPosition *position = [[self class] allocWithZone:zone];
    position.startPos = _startPos;
    position.endPos = _endPos;
    return position;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, startPosition:%.2f, endPosition:%.2f", [super description], _startPos, _endPos];
}

@end

#pragma mark -

class MPTableViewUpdateNode {
public:
    MPTableViewUpdateType updateType;
    MPTableViewRowAnimation animation;
    NSInteger index, lastIndex;
};

typedef vector<MPTableViewUpdateNode> MPTableViewUpdateNodesVec;

NS_INLINE bool
MPUpdateSort(const MPTableViewUpdateNode node1, const MPTableViewUpdateNode node2) {
    return node1.index < node2.index;
}

template <class MPUpdateNode>
void
MPUpdateMove(vector<MPUpdateNode> *updateNodesVec, NSInteger lastIndex, NSInteger index) {
#if DEBUG
    assert(lastIndex < updateNodesVec->size() && index < updateNodesVec->size());
#endif
    
    NSInteger start;
    NSInteger middle;
    NSInteger end;
    if (index < lastIndex) {
        start = index;
        middle = lastIndex;
        end = lastIndex + 1;
    } else if (index > lastIndex) {
        start = lastIndex;
        middle = lastIndex + 1;
        end = index + 1;
    } else {
        return;
    }
    rotate(updateNodesVec->begin() + start, updateNodesVec->begin() + middle, updateNodesVec->begin() + end);
}

template <class MPUpdateNode>
void
MPUpdateConverge(vector<MPUpdateNode> *updateNodesVec) {
    sort(updateNodesVec->begin(), updateNodesVec->end(), MPUpdateSort);
    
    NSInteger backTrackIndex = 0;
    NSInteger step = 0;
    NSUInteger count = updateNodesVec->size();
    
    // make nodes not duplicate
    for (NSInteger i = 0; i < count; ++i) {
        MPUpdateNode *node = &(*updateNodesVec)[i];
        if (node->updateType == MPTableViewUpdateAdjust) {
            continue;
        }
        if (MPTableViewUpdateTypeUnstable(node->updateType)) { // unstable
            node->index += step;
            if (node->updateType != MPTableViewUpdateReload) {
                --step;
            }
            while (backTrackIndex < i) {
                MPUpdateNode *backTrackNode = &(*updateNodesVec)[backTrackIndex];
                if (MPTableViewUpdateTypeStable(backTrackNode->updateType)) {
                    if (node->index >= backTrackNode->index) { // unstable >= stable
                        ++node->index;
                        ++step;
                    } else {
                        MPUpdateMove(updateNodesVec, i, backTrackIndex);
                        ++backTrackIndex;
                        break;
                    }
                    ++backTrackIndex;
                } else {
                    break;
                }
            }
        } else { // stable
            while (backTrackIndex < i) {
                MPUpdateNode *backTrackNode = &(*updateNodesVec)[backTrackIndex];
                if (MPTableViewUpdateTypeUnstable(backTrackNode->updateType)) {
                    if (node->index <= backTrackNode->index) { // stable <= unstable
                        MPUpdateMove(updateNodesVec, i, backTrackIndex);
                        ++step;
                        NSInteger tracking = ++backTrackIndex;
                        do {
                            node = &(*updateNodesVec)[tracking++];
                            ++node->index;
                        } while (tracking <= i);
                        break;
                    }
                    ++backTrackIndex;
                } else {
                    break;
                }
            }
        }
    }
}

static bool
MPUpdateBoundaryCheckReverse(MPTableViewUpdateNodesVec *updateNodesVec, NSUInteger count, bool isStable) {
    MPTableViewUpdateNodesVec::reverse_iterator rlast = updateNodesVec->rend();
    for (MPTableViewUpdateNodesVec::reverse_iterator rfirst = updateNodesVec->rbegin(); rfirst != rlast; ++rfirst) {
        if (isStable) {
            if (MPTableViewUpdateTypeStable(rfirst->updateType)) {
                return rfirst->index < count;
            }
        } else {
            if (MPTableViewUpdateTypeUnstable(rfirst->updateType)) {
                return rfirst->lastIndex < count;
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
        _lastCount = NSNotFound;
        _updateNodesVec = new MPTableViewUpdateNodesVec();
    }
    return self;
}

- (BOOL)prepareAndIgnoreCheck:(BOOL)ignoreCheck {
    MPUpdateConverge(_updateNodesVec);
    
    if (ignoreCheck) {
        return YES;
    }
    
    if (self.lastCount + _differ != self.newCount) {
        return NO;
    } else {
        if (_updateNodesVec->size() == 0) {
            return YES;
        } else {
            return MPUpdateBoundaryCheckReverse(_updateNodesVec, self.lastCount, NO) && MPUpdateBoundaryCheckReverse(_updateNodesVec, self.newCount, YES);
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

@implementation MPTableViewUpdateManager {
    NSMutableIndexSet *_existingUpdatePartsIndexes;
    map<NSInteger, MPTableViewSection *> _movedSectionsMap;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingUpdatePartsIndexes = [[NSMutableIndexSet alloc] init];
        _movedSectionsMap = map<NSInteger, MPTableViewSection *>();
    }
    return self;
}

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView andSections:(NSMutableArray *)sections {
    MPTableViewUpdateManager *manager = [[MPTableViewUpdateManager alloc] init];
    manager->_tableView = tableView;
    manager->_sections = sections;
    return manager;
}

- (NSUInteger)newCount {
    if ([super newCount] == NSNotFound) { // @optional
        [super setNewCount:[_tableView numberOfSections]];
    }
    return [super newCount];
}

- (NSUInteger)lastCount {
    if ([super lastCount] == NSNotFound) {
        [super setLastCount:_sections.count];
    }
    return [super lastCount];
}

- (BOOL)hasUpdateNodes {
    if (_updateNodesVec->size() != 0 || _existingUpdatePartsIndexes.count != 0) {
        return YES;
    } else {
        return NO;
    }
}

- (void)reset {
    _updateNodesVec->clear();
    _movedSectionsMap.clear();
    
    [_existingStableIndexes removeAllIndexes];
    [_existingUnstableIndexes removeAllIndexes];
    [_existingUpdatePartsIndexes removeAllIndexes];
    
    _differ = 0;
    self.lastCount = self.newCount = NSNotFound;
}

- (void)dealloc {
    [_existingUpdatePartsIndexes removeAllIndexes];
    _existingUpdatePartsIndexes = nil;
    _movedSectionsMap.clear();
}

#pragma mark -

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
    node.lastIndex = section;
    
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
    node.lastIndex = section;
    
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
    node.lastIndex = section;
    
    _updateNodesVec->push_back(node);
    return YES;
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
    node.lastIndex = section;
    
    _updateNodesVec->push_back(node);
    return YES;
}

- (BOOL)addMoveInSection:(NSUInteger)section withLastSection:(NSInteger)lastSection {
    if ([_existingStableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:section];
        ++_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.index = section;
    node.updateType = MPTableViewUpdateMoveIn;
    node.lastIndex = section;
    
    _updateNodesVec->push_back(node);
    _movedSectionsMap.insert(pair<NSInteger, MPTableViewSection *>(section, _sections[lastSection]));
    return YES;
}

#pragma mark -

- (MPTableViewUpdatePart *)getPartFromSection:(NSUInteger)section {
    MPTableViewSection *sectionPosition = _sections[section];
    MPTableViewUpdatePart *part = sectionPosition.updatePart;
    if (!part) {
        part = [[MPTableViewUpdatePart alloc] init];
        part.lastCount = sectionPosition.numberOfRows;
        sectionPosition.updatePart = part;
        [_existingUpdatePartsIndexes addIndex:section];
    }
    return part;
}

- (BOOL)addDeleteIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addDeleteRow:indexPath.row withAnimation:animation];
}

- (BOOL)addInsertIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addInsertRow:indexPath.row withAnimation:animation];
}

- (BOOL)addReloadIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addReloadRow:indexPath.row withAnimation:animation];
}

- (BOOL)addMoveOutIndexPath:(MPIndexPath *)indexPath {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addMoveOutRow:indexPath.row];
}

- (BOOL)addMoveInIndexPath:(MPIndexPath *)indexPath withFrame:(CGRect)frame withLastIndexPath:(MPIndexPath *)lastIndexPath {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self getPartFromSection:indexPath.section];
    return [part addMoveInRow:indexPath.row withFrame:frame withLastIndexPath:lastIndexPath];
}

- (CGFloat)startUpdate {
    CGFloat offset = 0;
    NSUInteger sectionsCount = self.lastCount;
    
    MPTableViewUpdateNodesVec *nodes = _updateNodesVec;
    NSInteger index = 0, step = 0;
    NSUInteger nodesCount = nodes->size();
    
    BOOL hasDragCell = [self.tableView _hasDragCell];
    
    for (NSInteger i = 0; i < nodesCount; ++i) {
        MPTableViewUpdateNode node = (*nodes)[i];
        
        for (NSInteger j = index; j < node.index; ++j) {
            MPTableViewSection *section = _sections[j];
            BOOL needToDisplay = [self.tableView _updateNeedToDisplaySection:section updateType:MPTableViewUpdateAdjust withOffset:offset];
            if (MPTableViewUpdateTypeUnstable(node.updateType)) {
                needToDisplay = needToDisplay && section.section < node.lastIndex;
            }
            
            offset = [self _updateAdjustSection:j inSectionPosition:section needToDisplay:needToDisplay hasDragCell:hasDragCell withOffset:offset];
        }
        
        if (MPTableViewUpdateTypeStable(node.updateType)) {
            ++step;
            
            if (node.updateType == MPTableViewUpdateInsert) {
                MPTableViewSection *insertSection = [self.tableView _updateGetSection:node.index];
                [_sections insertObject:insertSection atIndex:node.index];
                
                [insertSection rebuildForTableView:self.tableView withLastSection:node.index withDistance:0];
                
                [self _executeInsertionsForSection:insertSection andNode:node];
                
                offset += insertSection.endPos - insertSection.startPos;
            } else {
                MPTableViewSection *moveInSection = _movedSectionsMap.at(node.index);
                MPTableViewSection *backup = [moveInSection copy];
                
                moveInSection.section = node.index;
                if (moveInSection.moveOutHeight < 0) {
                    moveInSection.moveOutHeight = moveInSection.endPos - moveInSection.startPos;
                } else {
                    moveInSection.moveOutHeight = -1;
                }
                
                CGFloat startPos;
                if (node.index == 0) {
                    startPos = 0;
                } else { // because _sections[node.index] has not been calculated, so its position is not accurate
                    MPTableViewSection *frontSection = _sections[node.index - 1];
                    startPos = frontSection.endPos;
                }
                CGFloat distance = startPos - moveInSection.startPos;
                [moveInSection makeOffset:distance];
                
                [_sections insertObject:moveInSection atIndex:node.index];
                
                [moveInSection rebuildForTableView:self.tableView withLastSection:backup.section withDistance:distance];
                
                [self _executeMovementsForSection:moveInSection fromLastSection:backup andNode:node withDistance:distance];
                
                offset += moveInSection.endPos - moveInSection.startPos;
            }
            
            index = node.index + 1;
        } else if (node.updateType == MPTableViewUpdateReload) {
            MPTableViewSection *deleteSection = _sections[node.index];
            MPTableViewSection *insertSection = [self.tableView _updateGetSection:node.index];
            NSAssert(node.lastIndex == deleteSection.section, @"An unexpected bug, please contact the author"); // beyond the bug
            
            [_sections replaceObjectAtIndex:node.index withObject:insertSection];
            [insertSection rebuildForTableView:self.tableView withLastSection:node.index withDistance:0];
            
            // node.index - step == node.lastIndex
            CGFloat height = insertSection.endPos - insertSection.startPos;
            offset += height - (deleteSection.endPos - deleteSection.startPos);
            
            if ([self.tableView _updateNeedToDisplaySection:deleteSection updateType:MPTableViewUpdateDelete withOffset:0]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; ++k) {
                    [self.tableView _updateDeleteCellInSection:node.lastIndex atRow:k withAnimation:node.animation inSectionPosition:deleteSection];
                }
                
                [self.tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [self.tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionFooter withAnimation:node.animation withDeleteSection:deleteSection];
            }
            
            [self _executeInsertionsForSection:insertSection andNode:node];
            
            index = node.index + 1;
        } else { // node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut
            --step;
            
            MPTableViewSection *deleteSection = _sections[node.index];
            CGFloat height;
            if (node.updateType == MPTableViewUpdateDelete) {
                height = deleteSection.endPos - deleteSection.startPos;
            } else {
                if (deleteSection.moveOutHeight < 0) {
                    deleteSection.moveOutHeight = height = deleteSection.endPos - deleteSection.startPos;
                } else {
                    height = deleteSection.moveOutHeight;
                    deleteSection.moveOutHeight = -1;
                }
            }
            offset -= height;
            [_sections removeObjectAtIndex:node.index];
            
            // node.index - step - 1 == node.lastIndex
            if (node.updateType == MPTableViewUpdateDelete && [self.tableView _updateNeedToDisplaySection:deleteSection updateType:MPTableViewUpdateDelete withOffset:0]) {
                for (NSInteger k = 0; k < deleteSection.numberOfRows; ++k) {
                    [self.tableView _updateDeleteCellInSection:node.lastIndex atRow:k withAnimation:node.animation inSectionPosition:deleteSection];
                }
                
                [self.tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionHeader withAnimation:node.animation withDeleteSection:deleteSection];
                [self.tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionFooter withAnimation:node.animation withDeleteSection:deleteSection];
            }
            
            index = node.index;
        }
    }
    
    sectionsCount += step;
    NSInteger j = index;
    
    if (hasDragCell) {
        if (self.moveToSection > self.moveFromSection) {
            j = self.moveFromSection;
            sectionsCount = self.moveToSection + 1;
        } else {
            j = self.moveToSection;
            sectionsCount = self.moveFromSection + 1;
        }
    }
    
    for (; j < sectionsCount; ++j) {
        MPTableViewSection *section = _sections[j];
        NSAssert(section.section == j - step, @"An unexpected bug, please contact the author");
        
        BOOL needToDisplay = [self.tableView _updateNeedToDisplaySection:section updateType:MPTableViewUpdateAdjust withOffset:offset];
        
        offset = [self _updateAdjustSection:j inSectionPosition:section needToDisplay:needToDisplay hasDragCell:hasDragCell withOffset:offset];
    }
    
    return offset;
}

- (CGFloat)_updateAdjustSection:(NSUInteger)section inSectionPosition:(MPTableViewSection *)sectionPosition needToDisplay:(BOOL)needToDisplay hasDragCell:(BOOL)hasDragCell withOffset:(CGFloat)offset {
    NSUInteger numberOfRows = hasDragCell ? sectionPosition.numberOfRows : [_tableView.dataSource MPTableView:_tableView numberOfRowsInSection:section];
    if (sectionPosition.updatePart) {
        sectionPosition.updatePart.newCount = numberOfRows;
        
        if (![sectionPosition.updatePart prepareAndIgnoreCheck:hasDragCell]) {
            MPTableViewThrowUpdateException(@"check the number of rows after insert or delete")
        }
        
        offset = [sectionPosition startUpdateUsingPartForTableView:self.tableView toNewSection:section withOffset:offset needToDisplay:needToDisplay];
    } else {
        if (numberOfRows != sectionPosition.numberOfRows) {
            MPTableViewThrowUpdateException(@"check the number of rows from data source")
        }
        
        offset = [sectionPosition startUpdateForTableView:self.tableView toNewSection:section withOffset:offset needToDisplay:needToDisplay];
    }
    
    return offset;
}

- (void)_executeInsertionsForSection:(MPTableViewSection *)insertSection andNode:(MPTableViewUpdateNode)node {
    CGFloat updateLastInsertionOriginY = [self.tableView _updateLastInsertionOriginY];
    void (^updateAction)(void) = ^{
        if (!self.tableView) {
            return;
        }
        
        if (![self.tableView _updateNeedToDisplaySection:insertSection updateType:MPTableViewUpdateInsert withOffset:0]) {
            return;
        }
        
        for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
            [self.tableView _updateInsertCellToSection:node.index atRow:k withAnimation:node.animation inSectionPosition:insertSection withLastInsertionOriginY:updateLastInsertionOriginY];
        }
        
        [self.tableView _updateInsertSectionViewToSection:node.index withType:MPSectionHeader withAnimation:node.animation withInsertSection:insertSection withLastInsertionOriginY:updateLastInsertionOriginY];
        [self.tableView _updateInsertSectionViewToSection:node.index withType:MPSectionFooter withAnimation:node.animation withInsertSection:insertSection withLastInsertionOriginY:updateLastInsertionOriginY];
    };
    
    [self.tableView._updateExecutionActions addObject:updateAction];
}

- (void)_executeMovementsForSection:(MPTableViewSection *)insertSection fromLastSection:(MPTableViewSection *)lastSection andNode:(MPTableViewUpdateNode)node withDistance:(CGFloat)distance {
    BOOL onscreen = [self.tableView _updateNeedToDisplaySection:lastSection updateType:MPTableViewUpdateMoveOut withOffset:0];
    void (^updateAction)(void) = ^{
        if (!self.tableView) {
            return;
        }
        
        if (!onscreen && ![self.tableView _updateNeedToDisplaySection:insertSection updateType:MPTableViewUpdateMoveIn withOffset:distance]) {
            return;
        }
        
        for (NSInteger k = 0; k < insertSection.numberOfRows; ++k) {
            [self.tableView _updateMoveCellToSection:node.index atRow:k fromLastIndexPath:[MPIndexPath indexPathForRow:k inSection:lastSection.section] withLastHeight:[lastSection heightAtRow:k] withDistance:distance];
        }
        
        [self.tableView _updateMoveSectionViewToSection:node.index fromLastSection:lastSection.section withType:MPSectionHeader withLastHeight:lastSection.headerHeight withDistance:distance];
        [self.tableView _updateMoveSectionViewToSection:node.index fromLastSection:lastSection.section withType:MPSectionFooter withLastHeight:lastSection.footerHeight withDistance:distance];
    };
    
    [self.tableView._updateExecutionActions addObject:updateAction];
}

@end

#pragma mark -

class MPTableViewUpdateRowInfo {
public:
    MPIndexPath *indexPath;
    CGFloat originY, height;
    
    ~MPTableViewUpdateRowInfo() {
        indexPath = nil;
    }
};

@implementation MPTableViewUpdatePart {
    @package
    map<NSUInteger, MPTableViewUpdateRowInfo> _moveOutRowInfosMap;
}

- (instancetype)init {
    if (self = [super init]) {
        _moveOutRowInfosMap = map<NSUInteger, MPTableViewUpdateRowInfo>();
    }
    return self;
}

- (void)dealloc {
    _moveOutRowInfosMap.clear();
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
    node.lastIndex = row;
    
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
    node.lastIndex = row;
    
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
    node.lastIndex = row;
    
    _updateNodesVec->push_back(node);
    return YES;
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
    node.lastIndex = row;
    
    _updateNodesVec->push_back(node);
    return YES;
}

- (BOOL)addMoveInRow:(NSUInteger)row withFrame:(CGRect)frame withLastIndexPath:(MPIndexPath *)lastIndexPath {
    if ([_existingStableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:row];
        ++_differ;
    }
    
    MPTableViewUpdateNode node = MPTableViewUpdateNode();
    node.lastIndex = node.index = row;
    
    node.updateType = MPTableViewUpdateMoveIn;
    _updateNodesVec->push_back(node);
    
    MPTableViewUpdateRowInfo rowInfo = MPTableViewUpdateRowInfo();
    rowInfo.indexPath = lastIndexPath;
    rowInfo.originY = frame.origin.y;
    rowInfo.height = frame.size.height;
    _moveOutRowInfosMap.insert(pair<NSUInteger, MPTableViewUpdateRowInfo>(row, rowInfo));
    
    return YES;
}

@end

#pragma mark -

@implementation MPTableViewEstimatedManager

- (CGFloat)startEstimateForTableView:(MPTableView *)tableView atFirstIndexPath:(MPIndexPathStruct)firstIndexPath andSections:(NSMutableArray *)sections {
    CGFloat offset = 0;
    NSUInteger sectionsCount = sections.count;
    
    for (NSInteger j = firstIndexPath.section; j < sectionsCount; ++j) {
        MPTableViewSection *section = sections[j];
        
        BOOL needToDisplay = [tableView _estimatedNeedToDisplaySection:section withOffset:offset];
        if (!needToDisplay && offset == 0) {
            continue;
        }
        NSUInteger firstRow = 0;
        if (j == firstIndexPath.section) {
            if (firstIndexPath.row == MPSectionHeader) {
                firstRow = 0;
            } else {
                firstRow = firstIndexPath.row;
            }
        }
        
        offset = [section startEstimateForTableView:tableView atFirstRow:firstRow withOffset:offset needToDisplay:needToDisplay];
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
        [self reset];
    }
    return self;
}

- (void)reset {
    if (!_rowPositionDeque) {
        _rowPositionDeque = new deque<CGFloat>();
    }
    if (_rowPositionDeque->size() > 0) {
        _rowPositionDeque->clear();
    }
    
    _rowPositionDeque->push_back(0);
    _headerHeight = _footerHeight = 0;
    _numberOfRows = 0;
    self.startPos = self.endPos = 0;
    self.section = NSNotFound;
    self.moveOutHeight = -1;
    
    self.updatePart = nil;
}

- (void)setNumberOfRows:(NSUInteger)numberOfRows {
    NSAssert(numberOfRows <= MPTableViewMaxCount, @"the number of rows in section is too many");
    
    _numberOfRows = numberOfRows;
    //_rowPositionVec->resize(numberOfRows + 1);
    _rowPositionDeque->at(0) = self.startPos + _headerHeight;
}

- (void)addRowPosition:(CGFloat)end {
    _rowPositionDeque->push_back(end);
}

- (CGFloat)positionStartAtRow:(NSInteger)row {
    return (*_rowPositionDeque)[row];
}

- (CGFloat)heightAtRow:(NSInteger)row {
    return (*_rowPositionDeque)[row + 1] - (*_rowPositionDeque)[row];
}

- (CGFloat)positionEndAtRow:(NSInteger)row {
    return (*_rowPositionDeque)[row + 1];
}

- (NSInteger)rowAtContentOffsetY:(CGFloat)contentOffsetY {
    if (contentOffsetY <= self.startPos + self.headerHeight) {
        return MPSectionHeader;
    }
    if (contentOffsetY >= self.endPos - self.footerHeight) {
        return MPSectionFooter;
    }
    
    NSInteger start = 0;
    NSInteger end = _numberOfRows;
    NSInteger middle = 0;
    while (start <= end) {
        middle = (start + end) / 2;
        CGFloat startPos = [self positionStartAtRow:middle];
        CGFloat endPos = [self positionEndAtRow:middle];
        if (startPos > contentOffsetY) {
            end = middle - 1;
        } else if (endPos < contentOffsetY) {
            start = middle + 1;
        } else {
            return middle;
        }
    }
    return NSNotFound;
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewSection *section = [super copyWithZone:zone];
    section.section = self.section;
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

#pragma mark -

- (void)_removeRowPositionAtIndex:(NSInteger)index {
    deque<CGFloat>::iterator it = _rowPositionDeque->begin() + index + 1;
    _rowPositionDeque->erase(it);
}

- (void)_insertRow:(NSInteger)row withHeight:(CGFloat)height {
    deque<CGFloat>::iterator it = _rowPositionDeque->begin() + row + 1;
    CGFloat endPos = height + (*_rowPositionDeque)[row];
    _rowPositionDeque->insert(it, endPos);
}

- (void)_reloadRow:(NSInteger)row withHeight:(CGFloat)height {
    (*_rowPositionDeque)[row + 1] = (*_rowPositionDeque)[row] + height;
}

- (void)makeOffset:(CGFloat)offset {
    if (offset == 0) {
        return;
    }
    
    self.startPos += offset;
    self.endPos += offset;
    for (NSInteger i = 0; i <= _numberOfRows; ++i) {
        (*_rowPositionDeque)[i] += offset;
    }
}

- (CGFloat)_updateRowForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withOffset:(CGFloat)offset hasDragCell:(BOOL)hasDragCell needToLoadHeight:(BOOL *)needToLoadHeight {
    CGFloat lastOffset = offset;
    CGFloat lastHeight = [self heightAtRow:row];
    
    if (*needToLoadHeight == YES) {
        CGFloat newOffset = [tableView _updateGetAdjustCellOffsetAtIndexPath:[MPIndexPath indexPathForRow:row inSection:newSection] fromLastIndexPath:[MPIndexPath indexPathForRow:lastRow inSection:lastSection] withOffset:offset];
        if (newOffset != 0) {
            if (newOffset > MPTableViewMaxSize) {
                *needToLoadHeight = NO;
            } else {
                offset += newOffset;
                (*_rowPositionDeque)[row + 1] += newOffset;
            }
        }
    }
    
    [self _adjustCellsForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:lastOffset hasDragCell:hasDragCell];
    
    return offset;
}

- (void)_adjustCellsForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset hasDragCell:(BOOL)hasDragCell {
    if (hasDragCell) {
        [tableView _updateAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:offset];
    } else {
        void (^updateAction)(void) = ^{
            if (!tableView) {
                return;
            }
            
            [tableView _updateAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:offset];
        };
        [tableView._updateExecutionActions addObject:updateAction];
    }
}

- (CGFloat)_updateHeaderForTableView:(MPTableView *)tableView fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset  isMovement:(BOOL)isMovement {
    CGFloat headerHeight = [tableView _updateGetHeaderHeightInSection:self fromLastSection:lastSection withOffset:offset isMovement:isMovement];
    if (headerHeight >= 0) {
        offset += headerHeight - self.headerHeight;
        self.headerHeight = headerHeight;
    }
    
    return offset;
}

- (CGFloat)_updateFooterForTableView:(MPTableView *)tableView fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset  isMovement:(BOOL)isMovement {
    CGFloat footerHeight = [tableView _updateGetFooterHeightInSection:self fromLastSection:lastSection withOffset:offset isMovement:isMovement];
    if (footerHeight >= 0) {
        CGFloat newOffset = footerHeight - self.footerHeight;
        offset += newOffset;
        self.endPos += newOffset;
        self.footerHeight = footerHeight;
    }
    
    return offset;
}

- (void)_adjustSectionViewsForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection fromLastSection:(NSInteger)lastSection withHeaderOffset:(CGFloat)headerOffset andFooterOffset:(CGFloat)footerOffset withLastHeaderHeight:(CGFloat)lastHeaderHeight andLastFooterHeight:(CGFloat)lastFooterHeight needToDisplay:(BOOL)needToDisplay {
    BOOL needToAdjustHeader = [tableView _updateNeedToAdjustSectionViewInLastSection:lastSection withType:MPSectionHeader] || needToDisplay; // can't put this "needToDisplay" on left
    BOOL needToAdjustFooter = [tableView _updateNeedToAdjustSectionViewInLastSection:lastSection withType:MPSectionFooter] || needToDisplay;
    
    if (needToAdjustHeader) {
        void (^updateAction)(void) = ^{
            if (!tableView) {
                return;
            }
            
            [tableView _updateAdjustSectionViewFromSection:lastSection toSection:newSection withType:MPSectionHeader withLastHeight:lastHeaderHeight withSectionOffset:headerOffset];
        };
        [tableView._updateExecutionActions addObject:updateAction];
    }
    
    if (needToAdjustFooter) {
        void (^updateAction)(void) = ^{
            if (!tableView) {
                return;
            }
            
            [tableView _updateAdjustSectionViewFromSection:lastSection toSection:newSection withType:MPSectionFooter withLastHeight:lastFooterHeight withSectionOffset:footerOffset];
        };
        [tableView._updateExecutionActions addObject:updateAction];
    }
}

- (CGFloat)startUpdateUsingPartForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    [tableView _setUpdateLastInsertionOriginY:self.startPos + self.headerHeight];
    
    MPTableViewUpdatePart *part = self.updatePart;
    
    self.startPos += offset;
    NSUInteger lastSection = self.section;
    self.section = newSection;
    CGFloat headerOffset = offset;
    CGFloat lastHeaderHeight = self.headerHeight, lastFooterHeight = self.footerHeight;
    BOOL hasDragCell = [tableView _hasDragCell];
    
    if (needToDisplay && !hasDragCell) {
        CGFloat lastOffset = offset;
        self.endPos += lastOffset; // as a reference
        offset = [self _updateHeaderForTableView:tableView fromLastSection:lastSection withOffset:offset isMovement:NO];
        self.endPos -= lastOffset; // reset the reference
    }
    
    [tableView _setUpdateLastDeletionOriginY:self.startPos + self.headerHeight];
    
    (*_rowPositionDeque)[0] += offset; // the deque may be empty, but this seems to be safe...
    
    MPTableViewUpdateNodesVec *nodes = part->_updateNodesVec;
    NSInteger index = 1, step = 0;
    NSUInteger nodesCount = nodes->size();
    BOOL isBeginSection = (lastSection == [tableView _beginIndexPath].section);
    BOOL isEndSection = (lastSection == [tableView _endIndexPath].section);
    NSInteger beginSectionRow = [tableView _beginIndexPath].row;
    NSInteger endSectionRow = [tableView _endIndexPath].row;
    BOOL hasCells = [tableView _updateNeedToAdjustCellsFromLastSection:lastSection];
    
    for (NSInteger i = 0; i < nodesCount; ++i) {
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
        
        BOOL needCallback = !hasDragCell && (offset != 0 || needToDisplay || hasCells);
        needCallback = needCallback || (hasDragCell && offset != 0);
        if (needCallback) {
            BOOL needToLoadHeight = !hasDragCell;
            for (NSInteger j = index; j <= idx; ++j) {
                [tableView _setUpdateLastInsertionOriginY:(*_rowPositionDeque)[j]];
                
                if (offset != 0) {
                    (*_rowPositionDeque)[j] += offset;
                }
                
                NSInteger row = j - 1;
                NSInteger lastRow = j - step - 1;
                
                BOOL needToAdjust = NO;
                if (isInsert || lastRow < node.lastIndex) {
                    if (hasCells) {
                        needToAdjust = [tableView _updateNeedToAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow] || needToDisplay;
                    } else {
                        needToAdjust = needToDisplay;
                    }
                }
                
                if (hasDragCell && ((isBeginSection && lastRow < beginSectionRow) || (isEndSection && lastRow > endSectionRow))) {
                    continue;
                }
                
                if (needToAdjust) {
                    offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withOffset:offset hasDragCell:hasDragCell needToLoadHeight:&needToLoadHeight];
                    
                    [tableView _setUpdateLastDeletionOriginY:(*_rowPositionDeque)[j]];
                } else if (offset == 0 && !hasCells) {
                    break;
                }
            }
        }
        
        if (isInsert) {
            ++step;
            CGFloat cellHeight;
            
            if (node.updateType == MPTableViewUpdateInsert) {
                cellHeight = [tableView _updateGetInsertCellHeightAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection]];
                [self _insertRow:node.index withHeight:cellHeight];
                offset += cellHeight;
                
                if (needToDisplay) {
                    CGFloat updateLastInsertionOriginY = [tableView _updateLastInsertionOriginY];
                    void (^updateAction)(void) = ^{
                        if (!tableView) { // necessary
                            return;
                        }
                        [tableView _updateInsertCellToSection:newSection atRow:node.index withAnimation:node.animation inSectionPosition:nil withLastInsertionOriginY:updateLastInsertionOriginY];
                    };
                    [tableView._updateExecutionActions addObject:updateAction];
                }
            } else {
                MPTableViewUpdateRowInfo rowInfo = part->_moveOutRowInfosMap.at(node.index);
                cellHeight = rowInfo.height;
                [self _insertRow:node.index withHeight:cellHeight];
                offset += cellHeight;
                
                CGFloat distance = [self positionStartAtRow:node.index] - rowInfo.originY;
                
                if (hasDragCell) {
                    [tableView _updateMoveCellToSection:newSection atRow:node.index fromLastIndexPath:rowInfo.indexPath withLastHeight:cellHeight withDistance:distance];
                } else {
                    CGFloat newOffset = [tableView _updateGetMoveInCellOffsetAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection] fromLastIndexPath:rowInfo.indexPath lastHeight:cellHeight withDistance:distance];
                    if (newOffset != 0) {
                        offset += newOffset;
                        (*_rowPositionDeque)[node.index + 1] += newOffset;
                    }
                    
                    void (^updateAction)(void) = ^{
                        if (!tableView) {
                            return;
                        }
                        [tableView _updateMoveCellToSection:newSection atRow:node.index fromLastIndexPath:rowInfo.indexPath withLastHeight:cellHeight withDistance:distance];
                    };
                    [tableView._updateExecutionActions addObject:updateAction];
                }
            }
            
            index = node.index + 2;
        } else if (node.updateType == MPTableViewUpdateReload) {
            CGFloat cellHeight = [tableView _updateGetInsertCellHeightAtIndexPath:[MPIndexPath indexPathForRow:node.index inSection:newSection]];
            offset += cellHeight - [self heightAtRow:node.index];
            [self _reloadRow:node.index withHeight:cellHeight];
            
            // node.index - step == node.lastIndex
            [tableView _updateDeleteCellInSection:lastSection atRow:node.lastIndex withAnimation:node.animation inSectionPosition:nil];
            if (needToDisplay) {
                CGFloat updateLastInsertionOriginY = [tableView _updateLastInsertionOriginY];
                void (^updateAction)(void) = ^{
                    if (!tableView) { // necessary
                        return;
                    }
                    [tableView _updateInsertCellToSection:newSection atRow:node.index withAnimation:node.animation inSectionPosition:nil withLastInsertionOriginY:updateLastInsertionOriginY];
                };
                [tableView._updateExecutionActions addObject:updateAction];
            }
            
            index = node.index + 2;
        } else { // node.updateType == MPTableViewUpdateDelete || node.updateType == MPTableViewUpdateMoveOut
            --step;
            
            CGFloat height = [self heightAtRow:node.index];
            offset -= height;
            [self _removeRowPositionAtIndex:node.index];
            
            // node.index - step - 1 == node.lastIndex
            if (node.updateType == MPTableViewUpdateDelete) {
                [tableView _updateDeleteCellInSection:lastSection atRow:node.lastIndex withAnimation:node.animation inSectionPosition:nil];
            }
            
            index = node.index + 1;
        }
    }
    
    _numberOfRows += step;
    
    BOOL needCallback = !hasDragCell && (offset != 0 || needToDisplay || hasCells);
    needCallback = needCallback || (hasDragCell && step != 0);
    if (needCallback) {
        BOOL needToLoadHeight = !hasDragCell;
        for (NSInteger j = index; j <= _numberOfRows; ++j) {
            if (offset != 0) {
                (*_rowPositionDeque)[j] += offset;
            }
            
            NSInteger row = j - 1;
            NSInteger lastRow = j - step - 1;
            
            BOOL needToAdjust;
            if (hasCells) {
                needToAdjust = [tableView _updateNeedToAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow] || needToDisplay;
            } else {
                needToAdjust = needToDisplay;
            }
            
            if (hasDragCell && ((isBeginSection && lastRow < beginSectionRow) || (isEndSection && lastRow > endSectionRow))) {
                continue;
            }
            
            if (needToAdjust) {
                offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withOffset:offset hasDragCell:hasDragCell needToLoadHeight:&needToLoadHeight];
            } else if (offset == 0 && !hasCells) {
                break;
            }
        }
    }
    
    [tableView _setUpdateLastInsertionOriginY:self.endPos];
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    if (needToDisplay && !hasDragCell) {
        offset = [self _updateFooterForTableView:tableView fromLastSection:lastSection withOffset:offset isMovement:NO];
    }
    
    [tableView _setUpdateLastDeletionOriginY:self.endPos];
    
    [self _adjustSectionViewsForTableView:tableView toNewSection:newSection fromLastSection:lastSection withHeaderOffset:headerOffset andFooterOffset:footerOffset withLastHeaderHeight:lastHeaderHeight andLastFooterHeight:lastFooterHeight needToDisplay:needToDisplay];
    
    self.updatePart = nil;
    
    return offset;
}

- (CGFloat)startUpdateForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    BOOL necessaryToDisplay = (offset != 0) && [tableView _updateNecessaryToAdjustSection:self withOffset:offset];
    CGFloat lastOffset = offset;
    
    self.startPos += offset;
    NSUInteger lastSection = self.section;
    self.section = newSection;
    CGFloat headerOffset = offset;
    CGFloat lastHeaderHeight = self.headerHeight, lastFooterHeight = self.footerHeight;
    BOOL hasDragCell = [tableView _hasDragCell];
    
    if (needToDisplay && !hasDragCell) {
        self.endPos += lastOffset; // as a reference
        offset = [self _updateHeaderForTableView:tableView fromLastSection:lastSection withOffset:offset isMovement:NO];
        self.endPos -= lastOffset; // reset the reference
    }
    
    (*_rowPositionDeque)[0] += offset;
    
    BOOL hasCells = [tableView _updateNeedToAdjustCellsFromLastSection:lastSection];
    if (offset != 0 || needToDisplay || hasCells) {
        BOOL needToLoadHeight = !hasDragCell;
        for (NSUInteger i = 0; i < _numberOfRows; ++i) {
            if (offset != 0) {
                (*_rowPositionDeque)[i + 1] += offset;
            }
            
            BOOL needToAdjust;
            if (hasCells) {
                needToAdjust = [tableView _updateNeedToAdjustCellToSection:newSection atRow:i fromLastSection:lastSection andLastRow:i] || needToDisplay;
            } else {
                needToAdjust = needToDisplay;
            }
            
            if (needToAdjust) {
                offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:i fromLastSection:lastSection andLastRow:i withOffset:offset hasDragCell:hasDragCell needToLoadHeight:&needToLoadHeight];
            } else {
                if (offset == 0 && !hasCells) {
                    break;
                } else if (necessaryToDisplay) {
                    [self _adjustCellsForTableView:tableView toNewSection:newSection atRow:i fromLastSection:lastSection andLastRow:i withLastHeight:[self heightAtRow:i] withOffset:offset hasDragCell:hasDragCell];
                }
            }
        }
    }
    
    [tableView _setUpdateLastInsertionOriginY:self.endPos];
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    if (needToDisplay && !hasDragCell) {
        offset = [self _updateFooterForTableView:tableView fromLastSection:lastSection withOffset:offset isMovement:NO];
    }
    
    [tableView _setUpdateLastDeletionOriginY:self.endPos];
    
    [self _adjustSectionViewsForTableView:tableView toNewSection:newSection fromLastSection:lastSection withHeaderOffset:headerOffset andFooterOffset:footerOffset withLastHeaderHeight:lastHeaderHeight andLastFooterHeight:lastFooterHeight needToDisplay:needToDisplay || necessaryToDisplay];
    
    return offset;
}

- (void)rebuildForTableView:(MPTableView *)tableView withLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance {
    BOOL isMovement = self.section != lastSection;
    
    if ([tableView _isEstimatedMode]) {
        if (![tableView isUpdateForceReload]) {
            if (isMovement) {
                NSInteger section = self.section;
                self.section = lastSection;
                BOOL onscreen = [tableView _updateNeedToDisplaySection:self updateType:MPTableViewUpdateMoveIn withOffset:distance] || [tableView _hasDisplayedSection:self];
                self.section = section;
                
                if (!onscreen) {
                    return;
                }
            } else {
                if (![tableView _updateNeedToDisplaySection:self updateType:MPTableViewUpdateInsert withOffset:0]) {
                    return;
                }
            }
        }
    } else {
        if (!isMovement) { // non-estimated insertion
            return;
        }
    }
    
    // estimated movement and insertion, non-estimated movement
    CGFloat offset = 0;
    
    if (isMovement || [tableView _hasEstimatedHeightForHeader]) {
        offset = [self _updateHeaderForTableView:tableView fromLastSection:lastSection withOffset:distance isMovement:self.section != lastSection];
        offset -= distance;
    }
    
    (*_rowPositionDeque)[0] += offset;
    
    BOOL needToLoadHeight = isMovement || [tableView _hasEstimatedHeightForRow];
    if (needToLoadHeight || offset != 0) {
        for (NSUInteger i = 0; i < _numberOfRows; ++i) {
            if (offset != 0) {
                (*_rowPositionDeque)[i + 1] += offset;
            }
            
            if (!needToLoadHeight) {
                if (offset == 0) {
                    break;
                } else {
                    continue;
                }
            }
            CGFloat newOffset = [tableView _updateGetRebuildCellOffsetInSection:self.section atRow:i fromLastSection:lastSection withDistance:distance];
            if (newOffset != 0) {
                if (newOffset > MPTableViewMaxSize) {
                    needToLoadHeight = NO;
                } else {
                    offset += newOffset;
                    (*_rowPositionDeque)[i + 1] += newOffset;
                }
            }
        }
    }
    
    self.endPos += offset;
    if (isMovement || [tableView _hasEstimatedHeightForFooter]) {
        [self _updateFooterForTableView:tableView fromLastSection:lastSection withOffset:distance isMovement:self.section != lastSection];
    }
}

// called only when needToDisplay is YES or offset isn't equal to 0
- (CGFloat)startEstimateForTableView:(MPTableView *)tableView atFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    self.startPos += offset;
    
    CGFloat lastSection = self.section;
    
    CGFloat newHeaderHeight = 0;
    if (needToDisplay && [tableView _hasEstimatedHeightForHeader]) {
        self.endPos += offset;
        newHeaderHeight = [tableView _estimatedGetSectionViewHeightWithType:MPSectionHeader inSection:self];
        self.endPos -= offset;
        if (newHeaderHeight >= 0) {
            offset += newHeaderHeight - self.headerHeight;
            self.headerHeight = newHeaderHeight;
        }
    }
    
    (*_rowPositionDeque)[0] += offset;
    
    BOOL needCallback = needToDisplay;
    for (NSUInteger i = (newHeaderHeight < 0 ? firstRow : 0); i < _numberOfRows; ++i) {
        if (offset != 0) {
            (*_rowPositionDeque)[i + 1] += offset;
        }
        
        if (!needCallback) {
            if (offset == 0) {
                break;
            } else {
                continue;
            }
        }
        CGFloat newOffset = [tableView _estimatedDisplayCellInSection:lastSection atRow:i withOffset:offset];
        if (newOffset != 0) {
            if (newOffset > MPTableViewMaxSize) {
                needCallback = NO;
            } else {
                offset += newOffset;
                (*_rowPositionDeque)[i + 1] += newOffset;
            }
        }
    }
    
    self.endPos += offset;
    
    if (needToDisplay && [tableView _hasEstimatedHeightForFooter]) {
        CGFloat footerHeight = [tableView _estimatedGetSectionViewHeightWithType:MPSectionFooter inSection:self];
        if (footerHeight >= 0) {
            CGFloat newOffset = footerHeight - self.footerHeight;
            offset += newOffset;
            self.endPos += newOffset;
            self.footerHeight = footerHeight;
        }
    }
    
    if (needToDisplay) {
        [tableView _estimatedDisplaySectionViewInSection:lastSection withType:MPSectionHeader];
        [tableView _estimatedDisplaySectionViewInSection:lastSection withType:MPSectionFooter];
    }
    
    return offset;
}

@end
