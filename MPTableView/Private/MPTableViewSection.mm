//
//  MPTableViewSection.m
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015 PBA. All rights reserved.
//

#import "MPTableViewSection.h"
#import <vector>
#import <deque>

using namespace std;

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
    return [NSString stringWithFormat:@"%@; startPos = %f; endPos = %f", [super description], _startPos, _endPos];
}

@end

#pragma mark -

class MPTableViewUpdateNode {
public:
    MPTableViewUpdateType type;
    NSInteger index, lastIndex;
    
    virtual ~MPTableViewUpdateNode() = default;
};

typedef vector<MPTableViewUpdateNode *> MPTableViewUpdateNodes;

NS_INLINE bool
MPCompareUpdateNodes(const MPTableViewUpdateNode *node1, const MPTableViewUpdateNode *node2) {
    return node1->index < node2->index; // if there has a condition like 'if (node1->index == node2->index) return MPTV_IS_STABLE_UPDATE_TYPE(node1->type)', then this compare function must be used in stable_sort() but not in sort().
}

static void
MPMoveUpdateNode(MPTableViewUpdateNodes &updateNodes, NSInteger index, NSInteger newIndex) {
#if DEBUG
    assert(index < updateNodes.size() && newIndex < updateNodes.size());
#endif
    
    if (newIndex == index) {
        return;
    }
    
    NSInteger start;
    NSInteger middle;
    NSInteger end;
    if (newIndex < index) {
        start = newIndex;
        middle = index;
        end = index + 1;
    } else {
        start = index;
        middle = index + 1;
        end = newIndex + 1;
    }
    
    rotate(updateNodes.begin() + start, updateNodes.begin() + middle, updateNodes.begin() + end);
}

static void
MPSortUpdateNodes(MPTableViewUpdateNodes &updateNodes) {
    sort(updateNodes.begin(), updateNodes.end(), MPCompareUpdateNodes);
    
    NSUInteger backTrackIndex = 0;
    NSInteger step = 0;
    NSInteger backTrackStep = 0;
    NSUInteger count = updateNodes.size(); // this count can be twice as much as NSIntegerMax
    
    for (NSUInteger i = 0; i < count; i++) {
        MPTableViewUpdateNode *node = updateNodes[i];
        //        if (node->type == MPTableViewUpdateAdjust) {
        //            continue;
        //        }
        
        if (MPTV_IS_UNSTABLE_UPDATE_TYPE(node->type)) { // unstable
            node->index += step;
            if (node->type != MPTableViewUpdateReload) {
                step--;
            }
            
            while (backTrackIndex < i) {
                MPTableViewUpdateNode *backTrackNode = updateNodes[backTrackIndex];
                if (MPTV_IS_UNSTABLE_UPDATE_TYPE(backTrackNode->type)) {
                    break;
                }
                
                if (node->index >= backTrackNode->index) { // unstable >= stable
                    node->index++;
                    step++;
                    backTrackIndex++;
                } else {
                    MPMoveUpdateNode(updateNodes, i, backTrackIndex);
                    backTrackIndex++;
                    break;
                }
            }
        } else { // stable
            while (backTrackIndex < i) {
                MPTableViewUpdateNode *backTrackNode = updateNodes[backTrackIndex];
                if (MPTV_IS_STABLE_UPDATE_TYPE(backTrackNode->type)) {
                    break;
                }
                
                if (node->index <= (backTrackNode->index + backTrackStep)) { // stable <= unstable
                    MPMoveUpdateNode(updateNodes, i, backTrackIndex);
                    backTrackStep++;
                    backTrackIndex++;
                    break;
                } else if (backTrackStep != 0) {
                    NSInteger tracking = backTrackIndex;
                    while (true) {
                        backTrackNode->index += backTrackStep;
                        if (tracking + 1 >= i) {
                            break;
                        } else {
                            backTrackNode = updateNodes[++tracking];
                        }
                    }
                    
                    step += backTrackStep;
                    backTrackStep = 0;
                } else {
                    backTrackIndex++;
                }
            }
        }
    }
    
    if (backTrackStep != 0) {
        do {
            MPTableViewUpdateNode *backTrackNode = updateNodes[backTrackIndex++];
            backTrackNode->index += backTrackStep;
        } while (backTrackIndex < count);
    }
}

static bool
MPCheckUpdateNodes(const MPTableViewUpdateNodes &updateNodes, NSInteger count, bool stable) {
    NSUInteger i = updateNodes.size();
    if (i == 0) {
        return YES;
    }
    
    while (true) {
        const MPTableViewUpdateNode *node = updateNodes[--i];
        
        if (stable) {
            if (MPTV_IS_STABLE_UPDATE_TYPE(node->type)) {
                return node->index < count;
            }
        } else {
            if (MPTV_IS_UNSTABLE_UPDATE_TYPE(node->type)) {
                return node->lastIndex < count;
            }
        }
        
        if (i == 0) {
            break;
        }
    }
    
    return YES;
}

@implementation MPTableViewUpdateBase {
@public
    MPTableViewUpdateNodes _updateNodes;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingStableIndexes = [[NSMutableIndexSet alloc] init];
        _existingUnstableIndexes = [[NSMutableIndexSet alloc] init];
        _differ = 0;
        _newCount = NSNotFound;
        _lastCount = NSNotFound;
    }
    
    return self;
}

- (void)dealloc {
    [self deleteNodes];
}

- (BOOL)prepareToUpdateThenNeedToCheck:(BOOL)needToCheck {
    MPSortUpdateNodes(_updateNodes);
    
    if (!needToCheck) {
        return YES;
    }
    
    if (self.lastCount + _differ != self.newCount) {
        return NO;
    } else {
        if (_updateNodes.size() == 0) {
            return YES;
        } else {
            return MPCheckUpdateNodes(_updateNodes, self.lastCount, false) && MPCheckUpdateNodes(_updateNodes, self.newCount, true);
        }
    }
}

- (void)deleteNodes {
    NSUInteger count = _updateNodes.size();
    if (count == 0) {
        return;
    }
    
    for (NSUInteger i = 0; i < count; i++) {
        delete _updateNodes[i];
    }
    _updateNodes.clear();
}

@end

#pragma mark -

class MPTableViewUpdateNormalNode : public MPTableViewUpdateNode {
public:
    MPTableViewRowAnimation animation;
};

class MPTableViewUpdateSectionNode : public MPTableViewUpdateNode {
public:
    MPTableViewSection *section;
};

@implementation MPTableViewUpdateManager {
    NSMutableIndexSet *_existingUpdatePartsIndexes;
}

- (instancetype)init {
    if (self = [super init]) {
        _existingUpdatePartsIndexes = [[NSMutableIndexSet alloc] init];
        _transactions = [[NSMutableArray alloc] init];
    }
    
    return self;
}

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView andSectionsArray:(NSMutableArray *)sectionsArray {
    MPTableViewUpdateManager *manager = [[MPTableViewUpdateManager alloc] init];
    manager->_tableView = tableView;
    manager->_sectionsArray = sectionsArray;
    
    return manager;
}

- (void)reset {
    [self deleteNodes];
    
    [_existingStableIndexes removeAllIndexes];
    [_existingUnstableIndexes removeAllIndexes];
    [_existingUpdatePartsIndexes removeAllIndexes];
    
    [_transactions removeAllObjects];
    
    _differ = 0;
    self.lastCount = self.newCount = NSNotFound;
}

- (BOOL)hasUpdateNodes {
    if (_updateNodes.size() > 0 || _existingUpdatePartsIndexes.count > 0) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark -

- (BOOL)addDeleteSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
        _differ--;
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = section;
    node->lastIndex = section;
    node->type = MPTableViewUpdateDelete;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addInsertSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingStableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:section];
        _differ++;
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = section;
    node->lastIndex = section;
    node->type = MPTableViewUpdateInsert;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addReloadSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = section;
    node->lastIndex = section;
    node->type = MPTableViewUpdateReload;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveOutSection:(NSInteger)section {
    if ([_existingUnstableIndexes containsIndex:section] || [_existingUpdatePartsIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:section];
        _differ--;
    }
    
    MPTableViewUpdateNode *node = new MPTableViewUpdateNode();
    node->index = section;
    node->lastIndex = section;
    node->type = MPTableViewUpdateMoveOut;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveInSection:(NSInteger)section fromLastSection:(NSInteger)lastSection {
    if ([_existingStableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:section];
        _differ++;
    }
    
    MPTableViewUpdateSectionNode *node = new MPTableViewUpdateSectionNode();
    node->index = section;
    node->lastIndex = section;
    node->type = MPTableViewUpdateMoveIn;
    node->section = _sectionsArray[lastSection];
    
    _updateNodes.push_back(node);
    return YES;
}

#pragma mark -

- (MPTableViewUpdatePart *)_getPartFromSection:(NSInteger)section {
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    MPTableViewUpdatePart *part = sectionPosition.updatePart;
    if (!part) {
        part = [[MPTableViewUpdatePart alloc] init];
        sectionPosition.updatePart = part;
        [_existingUpdatePartsIndexes addIndex:section];
    }
    
    return part;
}

- (BOOL)addDeleteIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _getPartFromSection:indexPath.section];
    return [part addDeleteRow:indexPath.row withAnimation:animation];
}

- (BOOL)addInsertIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _getPartFromSection:indexPath.section];
    return [part addInsertRow:indexPath.row withAnimation:animation];
}

- (BOOL)addReloadIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _getPartFromSection:indexPath.section];
    return [part addReloadRow:indexPath.row withAnimation:animation];
}

- (BOOL)addMoveOutIndexPath:(NSIndexPath *)indexPath {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _getPartFromSection:indexPath.section];
    return [part addMoveOutRow:indexPath.row];
}

- (BOOL)addMoveInIndexPath:(NSIndexPath *)indexPath withLastIndexPath:(NSIndexPath *)lastIndexPath withLastFrame:(CGRect)lastFrame {
    if ([_existingUnstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _getPartFromSection:indexPath.section];
    return [part addMoveInRow:indexPath.row withLastIndexPath:lastIndexPath withLastFrame:lastFrame];
}

#pragma mark -

- (CGFloat)update {
    CGFloat offset = 0;
    NSInteger sectionCount = self.lastCount; // verified
    
    NSInteger index = 0, step = 0;
    NSUInteger nodeCount = _updateNodes.size();
    BOOL hasDraggingCell = [_tableView _hasDraggingCell];
    
    for (NSUInteger i = 0; i < nodeCount; i++) {
        const MPTableViewUpdateNode &node = *_updateNodes[i];
        
        for (NSInteger j = index; j < node.index; j++) {
            MPTableViewSection *section = _sectionsArray[j];
            BOOL needToDisplay = [_tableView _updateNeedToDisplayForSection:section withUpdateType:MPTableViewUpdateAdjust withOffset:offset];
            if (MPTV_IS_UNSTABLE_UPDATE_TYPE(node.type)) {
                needToDisplay = needToDisplay && section.section < node.lastIndex;
            }
            
            offset = [self _updateSectionPosition:section toNewSection:j needToDisplay:needToDisplay hasDraggingCell:hasDraggingCell withOffset:offset];
        }
        
        if (MPTV_IS_STABLE_UPDATE_TYPE(node.type)) {
            step++;
            
            if (node.type == MPTableViewUpdateInsert) {
                MPTableViewSection *insertSection = [_tableView _updateBuildSection:node.index];
                [_sectionsArray insertObject:insertSection atIndex:node.index];
                
                [insertSection rebuildForTableView:_tableView fromLastSection:node.index withDistance:0 isInsertion:YES];
                
                MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                [self _executeInsertionsInSection:insertSection withAnimation:normalNode.animation];
                
                offset += insertSection.endPos - insertSection.startPos;
            } else {
                MPTableViewUpdateSectionNode &sectionNode = (MPTableViewUpdateSectionNode &)node;
                MPTableViewSection *moveInSection = sectionNode.section;
                MPTableViewSection *backup = [moveInSection copy];
                
                moveInSection.section = node.index;
                if (moveInSection.moveOutHeight == MPTableViewInvalidFloatValue) {
                    moveInSection.moveOutHeight = moveInSection.endPos - moveInSection.startPos;
                } else {
                    moveInSection.moveOutHeight = MPTableViewInvalidFloatValue;
                }
                
                CGFloat startPos;
                if (node.index == 0) {
                    startPos = 0;
                } else { // because _sectionsArray[node.index] has not been updated, so its position is not accurate
                    MPTableViewSection *frontSection = _sectionsArray[node.index - 1];
                    startPos = frontSection.endPos;
                }
                CGFloat distance = startPos - moveInSection.startPos;
                [moveInSection makePositionOffset:distance];
                
                [_sectionsArray insertObject:moveInSection atIndex:node.index];
                
                [moveInSection rebuildForTableView:_tableView fromLastSection:backup.section withDistance:distance isInsertion:NO];
                
                [self _executeMovementsInSection:moveInSection withLastSection:backup withDistance:distance];
                
                offset += moveInSection.endPos - moveInSection.startPos;
            }
            
            index = node.index + 1;
        } else if (node.type == MPTableViewUpdateReload) {
            MPTableViewSection *deleteSection = _sectionsArray[node.index];
            MPTableViewSection *insertSection = [_tableView _updateBuildSection:node.index];
            NSAssert(node.lastIndex == deleteSection.section, @"An unexpected bug, please contact the author");
            
            [_sectionsArray replaceObjectAtIndex:node.index withObject:insertSection];
            [insertSection rebuildForTableView:_tableView fromLastSection:node.index withDistance:0 isInsertion:YES];
            
            CGFloat height = insertSection.endPos - insertSection.startPos;
            offset += height - (deleteSection.endPos - deleteSection.startPos);
            
            MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
            MPTableViewRowAnimation animation = normalNode.animation;
            
            // node.index - step == node.lastIndex
            if ([_tableView _updateNeedToDisplayForSection:deleteSection withUpdateType:MPTableViewUpdateDelete withOffset:0]) {
                for (NSInteger j = 0; j < deleteSection.numberOfRows; j++) {
                    [_tableView _updateDeleteCellInSection:node.lastIndex atRow:j withAnimation:animation inSectionPosition:deleteSection];
                }
                
                [_tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionHeader withAnimation:animation withDeleteSection:deleteSection];
                [_tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionFooter withAnimation:animation withDeleteSection:deleteSection];
            }
            
            [self _executeInsertionsInSection:insertSection withAnimation:animation];
            
            index = node.index + 1;
        } else { // node.type == MPTableViewUpdateDelete || node.type == MPTableViewUpdateMoveOut
            step--;
            
            MPTableViewSection *deleteSection = _sectionsArray[node.index];
            CGFloat height;
            if (node.type == MPTableViewUpdateDelete) {
                height = deleteSection.endPos - deleteSection.startPos;
            } else {
                if (deleteSection.moveOutHeight == MPTableViewInvalidFloatValue) {
                    deleteSection.moveOutHeight = height = deleteSection.endPos - deleteSection.startPos;
                } else {
                    height = deleteSection.moveOutHeight;
                    deleteSection.moveOutHeight = MPTableViewInvalidFloatValue;
                }
            }
            offset -= height;
            [_sectionsArray removeObjectAtIndex:node.index];
            
            // node.index - step - 1 == node.lastIndex
            if (node.type == MPTableViewUpdateDelete && [_tableView _updateNeedToDisplayForSection:deleteSection withUpdateType:MPTableViewUpdateDelete withOffset:0]) {
                MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                MPTableViewRowAnimation animation = normalNode.animation;
                
                for (NSInteger j = 0; j < deleteSection.numberOfRows; j++) {
                    [_tableView _updateDeleteCellInSection:node.lastIndex atRow:j withAnimation:animation inSectionPosition:deleteSection];
                }
                
                [_tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionHeader withAnimation:animation withDeleteSection:deleteSection];
                [_tableView _updateDeleteSectionViewInSection:node.lastIndex withType:MPSectionFooter withAnimation:animation withDeleteSection:deleteSection];
            }
            
            index = node.index;
        }
    }
    
    sectionCount += step;
    NSInteger i = index;
    
    if (hasDraggingCell) {
        NSInteger endSection;
        if (_dragFromSection < _dragToSection) {
            i = _dragFromSection;
            endSection = _dragToSection;
        } else {
            i = _dragToSection;
            endSection = _dragFromSection;
        }
        
        BOOL isEstimatedMode = [_tableView _isEstimatedMode];
        if (isEstimatedMode) {
            sectionCount = _sectionsArray.count;
        } else {
            sectionCount = endSection + 1;
        }
        
        for (; i < sectionCount; i++) {
            if (i > endSection && offset == 0) { // only in estimated mode
                break;
            }
            
            MPTableViewSection *section = _sectionsArray[i];
            NSAssert(section.section == i - step, @"An unexpected bug, please contact the author");
            
            BOOL needToDisplay = [_tableView _updateNeedToDisplayForSection:section withUpdateType:MPTableViewUpdateAdjust withOffset:offset];
            
            offset = [self _updateSectionPosition:section toNewSection:i needToDisplay:needToDisplay hasDraggingCell:hasDraggingCell withOffset:offset];
        }
        
        if (!isEstimatedMode) {
            offset = 0; // floating-point precision
        }
    } else {
        for (; i < sectionCount; i++) {
            MPTableViewSection *section = _sectionsArray[i];
            NSAssert(section.section == i - step, @"An unexpected bug, please contact the author");
            
            BOOL needToDisplay = [_tableView _updateNeedToDisplayForSection:section withUpdateType:MPTableViewUpdateAdjust withOffset:offset];
            
            offset = [self _updateSectionPosition:section toNewSection:i needToDisplay:needToDisplay hasDraggingCell:hasDraggingCell withOffset:offset];
        }
    }
    
    return offset;
}

- (CGFloat)_updateSectionPosition:(MPTableViewSection *)sectionPosition toNewSection:(NSInteger)newSection needToDisplay:(BOOL)needToDisplay hasDraggingCell:(BOOL)hasDraggingCell withOffset:(CGFloat)offset {
    NSInteger numberOfRows = hasDraggingCell ? sectionPosition.numberOfRows : [_tableView.dataSource MPTableView:_tableView numberOfRowsInSection:newSection];
    if (numberOfRows < 0) {
        NSAssert(NO, @"the number of rows in section can not be negative");
        numberOfRows = 0;
    }
    
    if (sectionPosition.updatePart) {
        BOOL needToCheck = !hasDraggingCell;
        if (needToCheck) {
            sectionPosition.updatePart.lastCount = sectionPosition.numberOfRows;
            sectionPosition.updatePart.newCount = numberOfRows;
        }
        if (![sectionPosition.updatePart prepareToUpdateThenNeedToCheck:needToCheck]) {
            MPTV_EXCEPTION(@"check the number of rows after insert or delete");
        }
        
        offset = [sectionPosition updateWithPartForTableView:_tableView toNewSection:newSection withOffset:offset needToDisplay:needToDisplay];
    } else {
        if (numberOfRows != sectionPosition.numberOfRows) {
            MPTV_EXCEPTION(@"check the number of rows from data source");
        }
        
        offset = [sectionPosition updateForTableView:_tableView toNewSection:newSection withOffset:offset needToDisplay:needToDisplay];
    }
    
    return offset;
}

- (void)_executeInsertionsInSection:(MPTableViewSection *)insertSection withAnimation:(MPTableViewRowAnimation)animation {
    CGFloat insertedLocationY = [_tableView _updateGetInsertedLocationY]; // may will be changed
    void (^updateAction)(void) = ^{
        if (!_tableView) {
            return;
        }
        
        if (![_tableView _updateNeedToDisplayForSection:insertSection withUpdateType:MPTableViewUpdateInsert withOffset:0]) { // content offset may have been changed
            return;
        }
        
        for (NSInteger i = 0; i < insertSection.numberOfRows; i++) {
            [_tableView _updateInsertCellToSection:insertSection.section atRow:i withAnimation:animation inSectionPosition:insertSection atInsertedLocationY:insertedLocationY];
        }
        
        [_tableView _updateInsertSectionViewToSection:insertSection.section withType:MPSectionHeader withAnimation:animation withInsertSection:insertSection atInsertedLocationY:insertedLocationY];
        [_tableView _updateInsertSectionViewToSection:insertSection.section withType:MPSectionFooter withAnimation:animation withInsertSection:insertSection atInsertedLocationY:insertedLocationY];
    };
    
    [[_tableView _updateExecutionActions] addObject:updateAction];
}

- (void)_executeMovementsInSection:(MPTableViewSection *)moveInSection withLastSection:(MPTableViewSection *)lastSection withDistance:(CGFloat)distance {
    BOOL needToDisplay = [_tableView _updateNeedToDisplayForSection:lastSection withUpdateType:MPTableViewUpdateMoveOut withOffset:0];
    void (^updateAction)(void) = ^{
        if (!_tableView) {
            return;
        }
        
        if (!needToDisplay && ![_tableView _updateNeedToDisplayForSection:moveInSection withUpdateType:MPTableViewUpdateMoveIn withOffset:distance]) {
            return;
        }
        
        for (NSInteger i = 0; i < moveInSection.numberOfRows; i++) {
            [_tableView _updateMoveCellToSection:moveInSection.section atRow:i fromLastSection:lastSection.section andLastRow:i withLastHeight:[lastSection heightAtRow:i] withDistance:distance];
        }
        
        [_tableView _updateMoveSectionViewToSection:moveInSection.section fromLastSection:lastSection.section withType:MPSectionHeader withLastHeight:lastSection.headerHeight withDistance:distance];
        [_tableView _updateMoveSectionViewToSection:moveInSection.section fromLastSection:lastSection.section withType:MPSectionFooter withLastHeight:lastSection.footerHeight withDistance:distance];
    };
    
    [[_tableView _updateExecutionActions] addObject:updateAction];
}

@end

#pragma mark -

class MPTableViewUpdateRowNode : public MPTableViewUpdateNode {
public:
    CGFloat originY, height;
    NSIndexPath *indexPath;
};

@implementation MPTableViewUpdatePart

- (BOOL)addDeleteRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
        _differ--;
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = row;
    node->lastIndex = row;
    node->type = MPTableViewUpdateDelete;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addInsertRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingStableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:row];
        _differ++;
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = row;
    node->lastIndex = row;
    node->type = MPTableViewUpdateInsert;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addReloadRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = row;
    node->lastIndex = row;
    node->type = MPTableViewUpdateReload;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveOutRow:(NSInteger)row {
    if ([_existingUnstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingUnstableIndexes addIndex:row];
        _differ--;
    }
    
    MPTableViewUpdateNode *node = new MPTableViewUpdateNode();
    node->index = row;
    node->lastIndex = row;
    node->type = MPTableViewUpdateMoveOut;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveInRow:(NSInteger)row withLastIndexPath:(NSIndexPath *)lastIndexPath withLastFrame:(CGRect)lastFrame {
    if ([_existingStableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_existingStableIndexes addIndex:row];
        _differ++;
    }
    
    MPTableViewUpdateRowNode *node = new MPTableViewUpdateRowNode();
    node->index = row;
    node->lastIndex = row;
    node->type = MPTableViewUpdateMoveIn;
    node->originY = lastFrame.origin.y;
    node->height = lastFrame.size.height;
    node->indexPath = lastIndexPath;
    
    _updateNodes.push_back(node);
    return YES;
}

@end

#pragma mark -

@implementation MPTableViewSection {
    deque<CGFloat> _rowPositions;
}

- (instancetype)init {
    if (self = [super init]) {
        [self reset];
    }
    
    return self;
}

+ (instancetype)section {
    return [[[self class] alloc] init];
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewSection *section = [super copyWithZone:zone];
    section.section = _section;
    section.headerHeight = _headerHeight;
    section.footerHeight = _footerHeight;
    section->_rowPositions = _rowPositions;
    section.numberOfRows = _numberOfRows;
    section.moveOutHeight = _moveOutHeight;
    
    return section;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@; section = %zd; numberOfRows = %zd; headerHeight = %f; footerHeight = %f", [super description], _section, _numberOfRows, _headerHeight, _footerHeight];
}

- (void)reset {
    if (_rowPositions.size() > 0) {
        _rowPositions.clear();
    }
    
    _numberOfRows = 0;
    self.startPos = self.endPos = 0;
    _headerHeight = _footerHeight = 0;
    _section = NSNotFound;
    _moveOutHeight = MPTableViewInvalidFloatValue;
    
    _updatePart = nil;
}

- (void)addRowPosition:(CGFloat)position {
    _rowPositions.push_back(position);
}

- (CGFloat)startPositionAtRow:(NSInteger)row {
    return _rowPositions[row];
}

- (CGFloat)endPositionAtRow:(NSInteger)row {
    return _rowPositions[row + 1];
}

- (CGFloat)heightAtRow:(NSInteger)row {
    CGFloat height = _rowPositions[row + 1] - _rowPositions[row];
    if (height < 0) { // floating-point precision
        height = 0;
    }
    
    return height;
}

- (NSInteger)rowAtContentOffsetY:(CGFloat)contentOffsetY {
    if (_headerHeight > 0 && (contentOffsetY <= self.startPos + _headerHeight)) {
        return MPSectionHeader;
    }
    if (_footerHeight > 0 && (contentOffsetY >= self.endPos - _footerHeight)) {
        return MPSectionFooter;
    }
    
    if (_numberOfRows == 0) {
        if (contentOffsetY < self.startPos) {
            return MPSectionHeader;
        } else if (contentOffsetY > self.endPos) {
            return MPSectionFooter;
        } else {
            return _headerHeight > 0 ? MPSectionHeader : MPSectionFooter;
        }
    }
    
    NSInteger start = 0;
    NSInteger end = _numberOfRows - 1;
    NSInteger middle = 0;
    while (start <= end) {
        middle = (start + end) / 2;
        CGFloat startPos = [self startPositionAtRow:middle];
        CGFloat endPos = [self endPositionAtRow:middle];
        if (startPos > contentOffsetY) {
            end = middle - 1;
        } else if (endPos < contentOffsetY) {
            start = middle + 1;
        } else {
            return middle;
        }
    }
    
    return middle; // floating-point precision
}

#pragma mark -

- (void)_deleteRow:(NSInteger)row {
    auto iter = _rowPositions.begin() + row + 1;
    _rowPositions.erase(iter);
}

- (void)_insertRow:(NSInteger)row withHeight:(CGFloat)height {
    auto iter = _rowPositions.begin() + row + 1;
    CGFloat endPos = _rowPositions[row] + height;
    _rowPositions.insert(iter, endPos);
}

- (void)_reloadRow:(NSInteger)row withHeight:(CGFloat)height {
    _rowPositions[row + 1] = _rowPositions[row] + height;
}

- (void)makePositionOffset:(CGFloat)offset {
    if (offset == 0) {
        return;
    }
    
    self.startPos += offset;
    self.endPos += offset;
    for (NSInteger i = 0; i <= _numberOfRows; i++) {
        _rowPositions[i] += offset;
    }
}

- (CGFloat)_updateRowForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withOffset:(CGFloat)offset hasDraggingCell:(BOOL)hasDraggingCell needToLoadHeight:(BOOL *)needToLoadHeight {
    CGFloat lastOffset = offset;
    CGFloat lastHeight = [self heightAtRow:row];
    
    if (*needToLoadHeight) {
        CGFloat differ = [tableView _updateGetAdjustCellDifferInSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withOffset:offset needToLoadHeight:needToLoadHeight];
        if (differ != 0) {
            offset += differ;
            _rowPositions[row + 1] += differ;
        }
    }
    
    [self _adjustCellForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:lastOffset hasDraggingCell:hasDraggingCell];
    
    return offset;
}

- (void)_adjustCellForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset hasDraggingCell:(BOOL)hasDraggingCell {
    if (hasDraggingCell) {
        [tableView _updateAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:offset];
    } else {
        void (^updateAction)(void) = ^{
            if (!tableView) {
                return;
            }
            
            [tableView _updateAdjustCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withLastHeight:lastHeight withOffset:offset];
        };
        [[tableView _updateExecutionActions] addObject:updateAction];
    }
}

- (CGFloat)_updateHeaderHeightForTableView:(MPTableView *)tableView fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion {
    CGFloat headerHeight = [tableView _updateGetHeaderHeightInSection:self fromLastSection:lastSection withOffset:offset isInsertion:isInsertion];
    if (headerHeight != MPTableViewInvalidFloatValue) {
        offset += headerHeight - _headerHeight;
        _headerHeight = headerHeight;
    }
    
    return offset;
}

- (CGFloat)_updateFooterHeightForTableView:(MPTableView *)tableView fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion {
    CGFloat footerHeight = [tableView _updateGetFooterHeightInSection:self fromLastSection:lastSection withOffset:offset isInsertion:isInsertion];
    if (footerHeight != MPTableViewInvalidFloatValue) {
        CGFloat differ = footerHeight - _footerHeight;
        offset += differ;
        self.endPos += differ;
        _footerHeight = footerHeight;
    }
    
    return offset;
}

- (void)_adjustSectionViewsForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection fromLastSection:(NSInteger)lastSection withHeaderOffset:(CGFloat)headerOffset andFooterOffset:(CGFloat)footerOffset withLastHeaderHeight:(CGFloat)lastHeaderHeight andLastFooterHeight:(CGFloat)lastFooterHeight hasDraggingCell:(BOOL)hasDraggingCell needToDisplay:(BOOL)needToDisplay {
    BOOL needToAdjustHeader = needToDisplay || [tableView _updateHasHumbleSectionViewInLastSection:lastSection withType:MPSectionHeader];
    BOOL needToAdjustFooter = needToDisplay || [tableView _updateHasHumbleSectionViewInLastSection:lastSection withType:MPSectionFooter];
    
    if (needToAdjustHeader) {
        if (hasDraggingCell) {
            [tableView _updateAdjustSectionViewToSection:newSection fromLastSection:lastSection withType:MPSectionHeader withLastHeight:lastHeaderHeight withOffset:headerOffset];
        } else {
            void (^updateAction)(void) = ^{
                if (!tableView) {
                    return;
                }
                
                [tableView _updateAdjustSectionViewToSection:newSection fromLastSection:lastSection withType:MPSectionHeader withLastHeight:lastHeaderHeight withOffset:headerOffset];
            };
            [[tableView _updateExecutionActions] addObject:updateAction];
        }
    }
    
    if (needToAdjustFooter) {
        if (hasDraggingCell) {
            [tableView _updateAdjustSectionViewToSection:newSection fromLastSection:lastSection withType:MPSectionFooter withLastHeight:lastFooterHeight withOffset:footerOffset];
        } else {
            void (^updateAction)(void) = ^{
                if (!tableView) {
                    return;
                }
                
                [tableView _updateAdjustSectionViewToSection:newSection fromLastSection:lastSection withType:MPSectionFooter withLastHeight:lastFooterHeight withOffset:footerOffset];
            };
            [[tableView _updateExecutionActions] addObject:updateAction];
        }
    }
}

- (CGFloat)updateWithPartForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    [tableView _updateSetInsertedLocationY:self.startPos + _headerHeight];
    
    self.startPos += offset;
    NSInteger lastSection = _section;
    _section = newSection;
    CGFloat headerOffset = offset;
    CGFloat lastHeaderHeight = _headerHeight, lastFooterHeight = _footerHeight;
    BOOL hasDraggingCell = [tableView _hasDraggingCell];
    
    BOOL needToUpdateHeaderHeight = YES;
    if (hasDraggingCell) {
        needToUpdateHeaderHeight = [tableView _needToEstimateHeightForHeader] && offset != 0;
    }
    if (needToDisplay && needToUpdateHeaderHeight) {
        CGFloat lastOffset = offset;
        self.endPos += lastOffset; // as a reference
        offset = [self _updateHeaderHeightForTableView:tableView fromLastSection:lastSection withOffset:offset isInsertion:NO];
        self.endPos -= lastOffset; // reset the reference
    }
    
    [tableView _updateSetDeletedPositionY:self.startPos + _headerHeight];
    
    _rowPositions[0] += offset;
    
    NSUInteger index = 1; // use NSUInteger for a situation like 'index = node.index + 2' and the index could be NSIntegerMax
    NSInteger step = 0;
    NSUInteger nodeCount = _updatePart->_updateNodes.size();
    
    BOOL hasHumbleCell = [tableView _updateHasHumbleCellsInLastSection:lastSection];
    
    for (NSUInteger i = 0; i < nodeCount; i++) {
        const MPTableViewUpdateNode &node = *(_updatePart->_updateNodes[i]);
        
        NSInteger frontIndex;
        BOOL stable;
        if (MPTV_IS_STABLE_UPDATE_TYPE(node.type)) {
            frontIndex = node.index;
            stable = YES;
        } else {
            frontIndex = node.index + 1;
            stable = NO;
        }
        
        BOOL needToUpdateRows;
        if (hasDraggingCell) {
            needToUpdateRows = offset != 0 || step != 0;
        } else {
            needToUpdateRows = offset != 0 || needToDisplay || hasHumbleCell;
        }
        if (needToUpdateRows) {
            BOOL needToLoadHeight = YES;
            if (hasDraggingCell) {
                needToLoadHeight = [tableView _needToEstimateHeightForRow];
            }
            
            for (NSUInteger j = index; j <= frontIndex; j++) {
                [tableView _updateSetInsertedLocationY:_rowPositions[j]];
                
                if (offset != 0) {
                    _rowPositions[j] += offset;
                }
                
                NSInteger row = j - 1;
                NSInteger lastRow = j - step - 1;
                
                BOOL needToAdjust;
                if (stable || lastRow < node.lastIndex) {
                    if (hasHumbleCell) {
                        needToAdjust = [tableView _updateNeedToAdjustHumbleCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow] || needToDisplay; // can't put this "needToDisplay" on left
                    } else {
                        needToAdjust = needToDisplay;
                    }
                } else {
                    needToAdjust = NO;
                }
                
                if (needToAdjust) {
                    offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withOffset:offset hasDraggingCell:hasDraggingCell needToLoadHeight:&needToLoadHeight];
                    
                    [tableView _updateSetDeletedPositionY:_rowPositions[j]];
                } else if (offset == 0 && !hasHumbleCell) {
                    break;
                }
            }
        }
        
        if (stable) {
            step++;
            
            CGFloat height;
            if (node.type == MPTableViewUpdateInsert) {
                height = [tableView _updateGetInsertCellHeightInSection:newSection atRow:node.index];
                [self _insertRow:node.index withHeight:height];
                offset += height;
                _numberOfRows++;
                
                if (needToDisplay) {
                    CGFloat insertedLocationY = [tableView _updateGetInsertedLocationY];
                    NSInteger row = node.index; // A C++ reference will be released in an Objective-C block in release mode
                    MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                    MPTableViewRowAnimation animation = normalNode.animation;
                    void (^updateAction)(void) = ^{
                        if (!tableView) { // necessary
                            return;
                        }
                        
                        [tableView _updateInsertCellToSection:newSection atRow:row withAnimation:animation inSectionPosition:nil atInsertedLocationY:insertedLocationY];
                    };
                    [[tableView _updateExecutionActions] addObject:updateAction];
                }
            } else {
                const MPTableViewUpdateRowNode &rowNode = (MPTableViewUpdateRowNode &)node;
                height = rowNode.height;
                [self _insertRow:node.index withHeight:height];
                offset += height;
                _numberOfRows++;
                
                CGFloat distance = [self startPositionAtRow:node.index] - rowNode.originY;
                
                if (hasDraggingCell) {
                    [tableView _updateMoveCellToSection:newSection atRow:node.index fromLastSection:rowNode.indexPath.section andLastRow:rowNode.indexPath.row withLastHeight:height withDistance:distance];
                } else {
                    CGFloat differ = [tableView _updateGetMoveInCellDifferInSection:newSection atRow:node.index withLastIndexPath:rowNode.indexPath withLastHeight:height withDistance:distance];
                    if (differ != 0) {
                        offset += differ;
                        _rowPositions[node.index + 1] += differ;
                    }
                    
                    NSInteger row = node.index;
                    NSIndexPath *lastIndexPath = rowNode.indexPath;
                    void (^updateAction)(void) = ^{
                        if (!tableView) {
                            return;
                        }
                        
                        [tableView _updateMoveCellToSection:newSection atRow:row fromLastSection:lastIndexPath.section andLastRow:lastIndexPath.row withLastHeight:height withDistance:distance];
                    };
                    [[tableView _updateExecutionActions] addObject:updateAction];
                }
            }
            
            index = node.index + 2;
        } else if (node.type == MPTableViewUpdateReload) {
            CGFloat height = [tableView _updateGetInsertCellHeightInSection:newSection atRow:node.index];
            offset += height - [self heightAtRow:node.index];
            [self _reloadRow:node.index withHeight:height];
            
            MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
            MPTableViewRowAnimation animation = normalNode.animation;
            
            // node.index - step == node.lastIndex
            [tableView _updateDeleteCellInSection:lastSection atRow:node.lastIndex withAnimation:animation inSectionPosition:nil];
            if (needToDisplay) {
                CGFloat insertedLocationY = [tableView _updateGetInsertedLocationY];
                NSInteger row = node.index;
                void (^updateAction)(void) = ^{
                    if (!tableView) { // necessary
                        return;
                    }
                    
                    [tableView _updateInsertCellToSection:newSection atRow:row withAnimation:animation inSectionPosition:nil atInsertedLocationY:insertedLocationY];
                };
                [[tableView _updateExecutionActions] addObject:updateAction];
            }
            
            index = node.index + 2;
        } else { // node.type == MPTableViewUpdateDelete || node.type == MPTableViewUpdateMoveOut
            step--;
            
            CGFloat height = [self heightAtRow:node.index];
            offset -= height;
            [self _deleteRow:node.index];
            _numberOfRows--;
            
            // node.index - step - 1 == node.lastIndex
            if (node.type == MPTableViewUpdateDelete) {
                MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                [tableView _updateDeleteCellInSection:lastSection atRow:node.lastIndex withAnimation:normalNode.animation inSectionPosition:nil];
            }
            
            index = node.index + 1;
        }
    }
    
    BOOL needToUpdateRows;
    if (hasDraggingCell) {
        if ([tableView _isEstimatedMode]) {
            needToUpdateRows = step != 0 || offset != 0;
        } else {
            needToUpdateRows = step != 0;
        }
    } else {
        needToUpdateRows = offset != 0 || needToDisplay || hasHumbleCell;
    }
    if (needToUpdateRows) {
        BOOL needToLoadHeight = YES;
        if (hasDraggingCell) {
            needToLoadHeight = [tableView _needToEstimateHeightForRow];
        }
        
        for (NSUInteger i = index; i <= _numberOfRows; i++) {
            if (offset != 0) {
                _rowPositions[i] += offset;
            }
            
            NSInteger row = i - 1;
            NSInteger lastRow = i - step - 1;
            
            BOOL needToAdjust;
            if (hasHumbleCell) {
                needToAdjust = [tableView _updateNeedToAdjustHumbleCellToSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow] || needToDisplay;
            } else {
                needToAdjust = needToDisplay;
            }
            
            if (needToAdjust) {
                offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:row fromLastSection:lastSection andLastRow:lastRow withOffset:offset hasDraggingCell:hasDraggingCell needToLoadHeight:&needToLoadHeight];
            } else if (offset == 0 && !hasHumbleCell) {
                break;
            }
        }
    }
    
    [tableView _updateSetInsertedLocationY:self.endPos];
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    BOOL needToUpdateFooterHeight = YES;
    if (hasDraggingCell) {
        needToUpdateFooterHeight = [tableView _needToEstimateHeightForFooter] && offset != 0;
    }
    if (needToDisplay && needToUpdateFooterHeight) {
        offset = [self _updateFooterHeightForTableView:tableView fromLastSection:lastSection withOffset:offset isInsertion:NO];
    }
    
    [tableView _updateSetDeletedPositionY:self.endPos];
    
    [self _adjustSectionViewsForTableView:tableView toNewSection:newSection fromLastSection:lastSection withHeaderOffset:headerOffset andFooterOffset:footerOffset withLastHeaderHeight:lastHeaderHeight andLastFooterHeight:lastFooterHeight hasDraggingCell:hasDraggingCell needToDisplay:needToDisplay];
    
    _updatePart = nil;
    
    return offset;
}

- (CGFloat)updateForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    BOOL necessaryToAdjust = (offset != 0) && [tableView _updateNecessaryToAdjustSection:self withOffset:offset];
    CGFloat lastOffset = offset;
    
    self.startPos += offset;
    NSInteger lastSection = _section;
    _section = newSection;
    CGFloat headerOffset = offset;
    CGFloat lastHeaderHeight = _headerHeight, lastFooterHeight = _footerHeight;
    BOOL hasDraggingCell = [tableView _hasDraggingCell];
    
    BOOL needToUpdateHeaderHeight = YES;
    if (hasDraggingCell) {
        needToUpdateHeaderHeight = [tableView _needToEstimateHeightForHeader] && offset != 0;
    }
    if (needToDisplay && needToUpdateHeaderHeight) {
        self.endPos += lastOffset; // as a reference
        offset = [self _updateHeaderHeightForTableView:tableView fromLastSection:lastSection withOffset:offset isInsertion:NO];
        self.endPos -= lastOffset; // reset the reference
    }
    
    _rowPositions[0] += offset;
    
    BOOL hasHumbleCell = [tableView _updateHasHumbleCellsInLastSection:lastSection];
    if (offset != 0 || needToDisplay || hasHumbleCell) {
        BOOL needToLoadHeight = YES;
        if (hasDraggingCell) {
            needToLoadHeight = [tableView _needToEstimateHeightForRow];
        }
        
        for (NSInteger i = 0; i < _numberOfRows; i++) {
            if (offset != 0) {
                _rowPositions[i + 1] += offset;
            }
            
            BOOL needToAdjust;
            if (hasHumbleCell) {
                needToAdjust = [tableView _updateNeedToAdjustHumbleCellToSection:newSection atRow:i fromLastSection:lastSection andLastRow:i] || needToDisplay;
            } else {
                needToAdjust = needToDisplay;
            }
            
            if (needToAdjust) {
                offset = [self _updateRowForTableView:tableView toNewSection:newSection atRow:i fromLastSection:lastSection andLastRow:i withOffset:offset hasDraggingCell:hasDraggingCell needToLoadHeight:&needToLoadHeight];
            } else {
                if (offset == 0 && !hasHumbleCell) {
                    break;
                } else if (necessaryToAdjust) {
                    [self _adjustCellForTableView:tableView toNewSection:newSection atRow:i fromLastSection:lastSection andLastRow:i withLastHeight:[self heightAtRow:i] withOffset:offset hasDraggingCell:hasDraggingCell];
                }
            }
        }
    }
    
    [tableView _updateSetInsertedLocationY:self.endPos];
    
    self.endPos += offset;
    CGFloat footerOffset = offset;
    
    BOOL needToUpdateFooterHeight = YES;
    if (hasDraggingCell) {
        needToUpdateFooterHeight = [tableView _needToEstimateHeightForFooter] && offset != 0;
    }
    if (needToDisplay && needToUpdateFooterHeight) {
        offset = [self _updateFooterHeightForTableView:tableView fromLastSection:lastSection withOffset:offset isInsertion:NO];
    }
    
    [tableView _updateSetDeletedPositionY:self.endPos];
    
    [self _adjustSectionViewsForTableView:tableView toNewSection:newSection fromLastSection:lastSection withHeaderOffset:headerOffset andFooterOffset:footerOffset withLastHeaderHeight:lastHeaderHeight andLastFooterHeight:lastFooterHeight hasDraggingCell:hasDraggingCell needToDisplay:needToDisplay || necessaryToAdjust];
    
    return offset;
}

- (void)rebuildForTableView:(MPTableView *)tableView fromLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance isInsertion:(BOOL)isInsertion {
    if ([tableView _isEstimatedMode]) {
        if (!tableView.reloadsAllDataDuringUpdate) {
            if (isInsertion) {
                if (![tableView _updateNeedToDisplayForSection:self withUpdateType:MPTableViewUpdateInsert withOffset:0]) {
                    return;
                }
            } else {
                NSInteger section = _section;
                _section = lastSection;
                BOOL needToDisplay = [tableView _updateNeedToDisplayForSection:self withUpdateType:MPTableViewUpdateMoveIn withOffset:distance] || [tableView _hasDisplayedInSection:self];
                _section = section;
                
                if (!needToDisplay) {
                    return;
                }
            }
        }
    } else {
        if (isInsertion) { // non-estimated insertion
            return;
        }
    }
    
    // for estimated movement and insertion, non-estimated movement
    CGFloat offset = 0;
    
    if (!isInsertion || [tableView _needToEstimateHeightForHeader]) { // verified (ignores reloadsAllDataDuringUpdate)
        offset = [self _updateHeaderHeightForTableView:tableView fromLastSection:lastSection withOffset:distance isInsertion:isInsertion];
        offset -= distance;
    }
    
    _rowPositions[0] += offset;
    
    BOOL needToLoadHeight = !isInsertion || [tableView _needToEstimateHeightForRow];
    if (needToLoadHeight || offset != 0) {
        for (NSInteger i = 0; i < _numberOfRows; i++) {
            if (offset != 0) {
                _rowPositions[i + 1] += offset;
            }
            
            if (!needToLoadHeight) {
                if (offset == 0) {
                    break;
                } else {
                    continue;
                }
            }
            CGFloat differ = [tableView _updateGetRebuildCellDifferInSection:self.section atRow:i fromLastSection:lastSection withDistance:distance needToLoadHeight:&needToLoadHeight];
            if (differ != 0) {
                offset += differ;
                _rowPositions[i + 1] += differ;
            }
        }
    }
    
    self.endPos += offset;
    if (!isInsertion || [tableView _needToEstimateHeightForFooter]) {
        [self _updateFooterHeightForTableView:tableView fromLastSection:lastSection withOffset:distance isInsertion:isInsertion];
    }
}

// called only when the needToDisplay is YES or the offset isn't equal to 0
- (CGFloat)estimateForTableView:(MPTableView *)tableView atFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay {
    self.startPos += offset;
    
    NSInteger lastSection = _section;
    
    CGFloat headerHeight = MPTableViewInvalidFloatValue;
    if (needToDisplay && _headerHeight > 0 && [tableView _needToEstimateHeightForHeader]) {
        self.endPos += offset;
        headerHeight = [tableView _estimatedGetHeaderHeightInSection:self];
        self.endPos -= offset;
        if (headerHeight != MPTableViewInvalidFloatValue) {
            offset += headerHeight - _headerHeight;
            _headerHeight = headerHeight;
        }
    }
    
    _rowPositions[0] += offset;
    
    BOOL needToLoadHeight = needToDisplay;
    for (NSInteger i = ((headerHeight == MPTableViewInvalidFloatValue) ? firstRow : 0); i < _numberOfRows; i++) {
        if (offset != 0) {
            _rowPositions[i + 1] += offset;
        }
        
        if (!needToLoadHeight) {
            if (offset == 0) {
                break;
            } else {
                continue;
            }
        }
        CGFloat differ = [tableView _estimatedDisplayCellInSection:lastSection atRow:i withOffset:offset needToLoadHeight:&needToLoadHeight];
        if (differ != 0) {
            offset += differ;
            _rowPositions[i + 1] += differ;
        }
    }
    
    self.endPos += offset;
    
    if (needToDisplay && _footerHeight > 0 && [tableView _needToEstimateHeightForFooter]) {
        CGFloat footerHeight = [tableView _estimatedGetFooterHeightInSection:self];
        if (footerHeight != MPTableViewInvalidFloatValue) {
            CGFloat differ = footerHeight - _footerHeight;
            offset += differ;
            self.endPos += differ;
            _footerHeight = footerHeight;
        }
    }
    
    if (needToDisplay) {
        [tableView _estimatedDisplaySectionViewInSection:lastSection withType:MPSectionHeader];
        [tableView _estimatedDisplaySectionViewInSection:lastSection withType:MPSectionFooter];
    }
    
    return offset;
}

@end
