//
//  MPTableViewSection.m
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015 PBA. All rights reserved.
//

#import "MPTableViewSection.h"
#import <list>
#import <deque>

using namespace std;

@implementation MPTableViewPosition

- (instancetype)init {
    if (self = [super init]) {
        _start = _end = 0;
    }
    
    return self;
}

+ (instancetype)positionWithStart:(CGFloat)start end:(CGFloat)end {
    MPTableViewPosition *position = [[[self class] alloc] init];
    position.start = start;
    position.end = end;
    
    return position;
}

- (BOOL)isEqual:(id)object {
    if (!object) {
        return NO;
    } else {
        return _start == [(MPTableViewPosition *)object start] && _end == [(MPTableViewPosition *)object end];
    }
}

- (NSUInteger)hash {
    return (NSUInteger)fabs(_end);
}

- (id)copyWithZone:(NSZone *)zone {
    MPTableViewPosition *position = [[self class] allocWithZone:zone];
    position.start = _start;
    position.end = _end;
    
    return position;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@; start = %f; end = %f", [super description], _start, _end];
}

@end

#pragma mark -

class MPTableViewUpdateNode {
public:
    MPTableViewUpdateType type;
    NSInteger index, originalIndex;
    
    virtual ~MPTableViewUpdateNode() = default;
};

typedef list<MPTableViewUpdateNode *> MPTableViewUpdateNodes;

NS_INLINE bool
MPUpdateNodeLess(const MPTableViewUpdateNode *node1, const MPTableViewUpdateNode *node2) {
    return node1->index < node2->index; // if there is a case like `if (node1->index == node2->index) return MPTV_IS_STABLE_UPDATE_TYPE(node1->type)`, this compare must be used in stable_sort.
}

static void
MPNormalizeUpdateNodes(MPTableViewUpdateNodes &updateNodes) {
    // note: in extreme cases, updateNodes.size() can reach 2 * NSIntegerMax.
    if (updateNodes.size() <= 1) {
        return;
    }
    
    updateNodes.sort(MPUpdateNodeLess);
    
    NSInteger step = 0;
    NSInteger increment = 0;
    
    auto iter = updateNodes.begin();
    MPTableViewUpdateNode *node = *iter;
    if (MPTV_IS_UNSTABLE_UPDATE_TYPE(node->type)) {
        node->index += step;
        if (node->type != MPTableViewUpdateReload) {
            step--;
        }
    }
    
    auto cursor = iter;
    ++iter;
    auto end = updateNodes.end();
    for (; iter != end; ++iter) {
        node = *iter;
        //        if (node->type == MPTableViewUpdateRelayout) {
        //            continue;
        //        }
        
        if (MPTV_IS_UNSTABLE_UPDATE_TYPE(node->type)) { // unstable
            node->index += step;
            if (node->type != MPTableViewUpdateReload) {
                step--;
            }
            
            MPTableViewUpdateNode *frontNode = *cursor;
            if (MPTV_IS_UNSTABLE_UPDATE_TYPE(frontNode->type)) {
                continue;
            }
            
            do {
                if (node->index >= frontNode->index) { // unstable >= stable
                    node->index++;
                    step++;
                    ++cursor;
                    frontNode = *cursor;
                } else {
                    auto prevIter = prev(iter, 1);
                    updateNodes.splice(cursor, updateNodes, iter);
                    iter = prevIter;
                    break;
                }
            } while (cursor != iter);
        } else { // stable
            MPTableViewUpdateNode *frontNode = *cursor;
            if (MPTV_IS_STABLE_UPDATE_TYPE(frontNode->type)) {
                continue;
            }
            
            do {
                if (node->index <= frontNode->index + increment) { // stable <= unstable
                    increment++;
                    auto prevIter = prev(iter, 1);
                    updateNodes.splice(cursor, updateNodes, iter);
                    iter = prevIter;
                    break;
                }
                
                if (increment == 0) {
                    ++cursor;
                    frontNode = *cursor;
                    continue;
                }
                
                while (true) {
                    frontNode->index += increment;
                    ++cursor;
                    if (cursor == iter) {
                        step += increment;
                        increment = 0;
                        break;
                    }
                    frontNode = *cursor;
                    if (node->index <= frontNode->index + increment) {
                        break;
                    }
                }
            } while (cursor != iter);
        }
    }
    
    if (increment != 0) {
        do {
            MPTableViewUpdateNode *frontNode = *cursor;
            frontNode->index += increment;
            ++cursor;
        } while (cursor != end);
    }
}

static bool
MPValidateUpdateNodes(const MPTableViewUpdateNodes &updateNodes, NSInteger count, bool stable) {
    if (updateNodes.size() == 0) {
        return YES;
    }
    
    auto riter = updateNodes.rbegin();
    auto rend = updateNodes.rend();
    while (riter != rend) {
        const MPTableViewUpdateNode *node = *riter;
        
        if (stable) {
            if (MPTV_IS_STABLE_UPDATE_TYPE(node->type)) {
                return node->index < count;
            }
        } else {
            if (MPTV_IS_UNSTABLE_UPDATE_TYPE(node->type)) {
                return node->originalIndex < count;
            }
        }
        
        ++riter;
    }
    
    return YES;
}

@implementation MPTableViewUpdateBase {
@public
    MPTableViewUpdateNodes _updateNodes;
}

- (instancetype)init {
    if (self = [super init]) {
        _stableIndexes = [[NSMutableIndexSet alloc] init];
        _unstableIndexes = [[NSMutableIndexSet alloc] init];
        _delta = 0;
        _newCount = NSNotFound;
        _previousCount = NSNotFound;
    }
    
    return self;
}

- (void)dealloc {
    [self clearNodes];
}

- (BOOL)prepareForUpdateWithCheck:(BOOL)needsCheck {
    if (needsCheck) {
        if (self.previousCount + _delta != self.newCount) {
            return NO;
        }
        
        if (_updateNodes.size() == 0) {
            return YES;
        }
        
        MPNormalizeUpdateNodes(_updateNodes);
        
        return MPValidateUpdateNodes(_updateNodes, self.previousCount, false) && MPValidateUpdateNodes(_updateNodes, self.newCount, true);
    } else {
        MPNormalizeUpdateNodes(_updateNodes);
        
        return YES;
    }
}

- (void)clearNodes {
    if (_updateNodes.size() == 0) {
        return;
    }
    
    auto iter = _updateNodes.begin();
    auto end = _updateNodes.end();
    while (iter != end) {
        delete *iter;
        iter = _updateNodes.erase(iter);
    }
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
    NSMutableIndexSet *_updatePartIndexes;
}

- (instancetype)init {
    if (self = [super init]) {
        _updatePartIndexes = [[NSMutableIndexSet alloc] init];
        _transactions = [[NSMutableArray alloc] init];
    }
    
    return self;
}

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView sectionArray:(NSMutableArray *)sectionArray {
    MPTableViewUpdateManager *manager = [[MPTableViewUpdateManager alloc] init];
    manager->_tableView = tableView;
    manager->_sectionArray = sectionArray;
    
    return manager;
}

- (void)reset {
    [self clearNodes];
    
    [_stableIndexes removeAllIndexes];
    [_unstableIndexes removeAllIndexes];
    [_updatePartIndexes removeAllIndexes];
    
    [_transactions removeAllObjects];
    
    _delta = 0;
    self.previousCount = self.newCount = NSNotFound;
}

- (BOOL)hasUpdateNodes {
    if (_updateNodes.size() > 0 || _updatePartIndexes.count > 0) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark -

- (BOOL)addDeleteSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_unstableIndexes containsIndex:section] || [_updatePartIndexes containsIndex:section]) {
        return NO;
    } else {
        [_unstableIndexes addIndex:section];
        _delta--;
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = section;
    node->originalIndex = section;
    node->type = MPTableViewUpdateDelete;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addInsertSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_stableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_stableIndexes addIndex:section];
        _delta++;
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = section;
    node->originalIndex = section;
    node->type = MPTableViewUpdateInsert;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addReloadSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation {
    if ([_unstableIndexes containsIndex:section] || [_updatePartIndexes containsIndex:section]) {
        return NO;
    } else {
        [_unstableIndexes addIndex:section];
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = section;
    node->originalIndex = section;
    node->type = MPTableViewUpdateReload;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveOutSection:(NSInteger)section {
    if ([_unstableIndexes containsIndex:section] || [_updatePartIndexes containsIndex:section]) {
        return NO;
    } else {
        [_unstableIndexes addIndex:section];
        _delta--;
    }
    
    MPTableViewUpdateNode *node = new MPTableViewUpdateNode();
    node->index = section;
    node->originalIndex = section;
    node->type = MPTableViewUpdateMoveOut;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveInSection:(NSInteger)section previousSection:(NSInteger)previousSection {
    if ([_stableIndexes containsIndex:section]) {
        return NO;
    } else {
        [_stableIndexes addIndex:section];
        _delta++;
    }
    
    MPTableViewUpdateSectionNode *node = new MPTableViewUpdateSectionNode();
    node->index = section;
    node->originalIndex = section;
    node->type = MPTableViewUpdateMoveIn;
    node->section = _sectionArray[previousSection];
    
    _updateNodes.push_back(node);
    return YES;
}

#pragma mark -

- (MPTableViewUpdatePart *)_updatePartForSection:(NSInteger)section {
    MPTableViewSection *sectionPosition = _sectionArray[section];
    MPTableViewUpdatePart *part = sectionPosition.updatePart;
    if (!part) {
        part = [[MPTableViewUpdatePart alloc] init];
        sectionPosition.updatePart = part;
        [_updatePartIndexes addIndex:section];
    }
    
    return part;
}

- (BOOL)addDeleteIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_unstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _updatePartForSection:indexPath.section];
    return [part addDeleteRow:indexPath.row withAnimation:animation];
}

- (BOOL)addInsertIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_unstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _updatePartForSection:indexPath.section];
    return [part addInsertRow:indexPath.row withAnimation:animation];
}

- (BOOL)addReloadIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation {
    if ([_unstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _updatePartForSection:indexPath.section];
    return [part addReloadRow:indexPath.row withAnimation:animation];
}

- (BOOL)addMoveOutIndexPath:(NSIndexPath *)indexPath {
    if ([_unstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _updatePartForSection:indexPath.section];
    return [part addMoveOutRow:indexPath.row];
}

- (BOOL)addMoveInIndexPath:(NSIndexPath *)indexPath previousIndexPath:(NSIndexPath *)previousIndexPath previousFrame:(CGRect)previousFrame {
    if ([_unstableIndexes containsIndex:indexPath.section]) {
        return NO;
    }
    
    MPTableViewUpdatePart *part = [self _updatePartForSection:indexPath.section];
    return [part addMoveInRow:indexPath.row previousIndexPath:previousIndexPath previousFrame:previousFrame];
}

#pragma mark -

- (CGFloat)update {
    CGFloat offset = 0;
    NSInteger sectionCount = self.previousCount; // verified
    
    NSInteger sectionIndex = 0, step = 0;
    BOOL hasDraggingCell = [_tableView _hasDraggingCell];
    
    auto end = _updateNodes.cend();
    for (auto iter = _updateNodes.cbegin(); iter != end; ++iter) {
        const MPTableViewUpdateNode &node = **iter;
        
        for (NSInteger j = sectionIndex; j < node.index; j++) {
            MPTableViewSection *section = _sectionArray[j];
            BOOL needsDisplay = [_tableView _needsDisplayAtSection:section withUpdateType:MPTableViewUpdateRelayout withOffset:offset];
            
            offset = [self _relayoutSectionAtPosition:section toSection:j needsDisplay:needsDisplay hasDraggingCell:hasDraggingCell withOffset:offset];
        }
        
        if (MPTV_IS_STABLE_UPDATE_TYPE(node.type)) {
            step++;
            
            if (node.type == MPTableViewUpdateInsert) {
                MPTableViewSection *insertedSection = [_tableView _buildSectionForIndex:node.index];
                [_sectionArray insertObject:insertedSection atIndex:node.index];
                
                [insertedSection rebuildForTableView:_tableView fromPreviousSection:node.index withShift:0 isInsertion:YES];
                
                MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                [self _executeInsertionsAtSection:insertedSection withAnimation:normalNode.animation];
                
                offset += insertedSection.end - insertedSection.start;
            } else {
                MPTableViewUpdateSectionNode &sectionNode = (MPTableViewUpdateSectionNode &)node;
                MPTableViewSection *movedSection = sectionNode.section;
                MPTableViewSection *originalSection = [movedSection copy];
                
                movedSection.section = node.index;
                if (movedSection.moveOutHeight == MPTableViewSentinelFloatValue) {
                    movedSection.moveOutHeight = movedSection.end - movedSection.start;
                } else {
                    movedSection.moveOutHeight = MPTableViewSentinelFloatValue;
                }
                
                CGFloat startPosition;
                if (node.index == 0) {
                    startPosition = 0;
                } else { // because _sectionArray[node.index] has not been updated, its position is not accurate.
                    MPTableViewSection *frontSection = _sectionArray[node.index - 1];
                    startPosition = frontSection.end;
                }
                CGFloat shift = startPosition - movedSection.start;
                [movedSection makePositionOffset:shift];
                
                [_sectionArray insertObject:movedSection atIndex:node.index];
                
                [movedSection rebuildForTableView:_tableView fromPreviousSection:originalSection.section withShift:shift isInsertion:NO];
                
                [self _executeMovementsAtSection:movedSection fromSection:originalSection withShift:shift];
                
                offset += movedSection.end - movedSection.start;
            }
            
            sectionIndex = node.index + 1;
        } else { // unstable
            if (node.type == MPTableViewUpdateReload) {
                MPTableViewSection *deletedSection = _sectionArray[node.index];
                MPTableViewSection *insertedSection = [_tableView _buildSectionForIndex:node.index];
                NSAssert(node.originalIndex == deletedSection.section, @"unexpected internal state");
                
                [_sectionArray replaceObjectAtIndex:node.index withObject:insertedSection];
                [insertedSection rebuildForTableView:_tableView fromPreviousSection:node.index withShift:0 isInsertion:YES];
                
                CGFloat height = insertedSection.end - insertedSection.start;
                offset += height - (deletedSection.end - deletedSection.start);
                
                MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                MPTableViewRowAnimation animation = normalNode.animation;
                
                // node.index - step == node.originalIndex
                if ([_tableView _needsDisplayAtSection:deletedSection withUpdateType:MPTableViewUpdateDelete withOffset:0]) {
                    for (NSInteger j = 0; j < deletedSection.numberOfRows; j++) {
                        [_tableView _deleteCellInSection:node.originalIndex row:j animation:animation sectionPosition:deletedSection];
                    }
                    
                    [_tableView _deleteSectionViewInSection:node.originalIndex viewType:MPTableViewSectionHeader animation:animation deletedSection:deletedSection];
                    [_tableView _deleteSectionViewInSection:node.originalIndex viewType:MPTableViewSectionFooter animation:animation deletedSection:deletedSection];
                }
                
                [self _executeInsertionsAtSection:insertedSection withAnimation:animation];
                
                sectionIndex = node.index + 1;
            } else { // node.type == MPTableViewUpdateDelete || node.type == MPTableViewUpdateMoveOut
                step--;
                
                MPTableViewSection *deletedSection = _sectionArray[node.index];
                CGFloat height;
                if (node.type == MPTableViewUpdateDelete) {
                    height = deletedSection.end - deletedSection.start;
                } else {
                    if (deletedSection.moveOutHeight == MPTableViewSentinelFloatValue) {
                        deletedSection.moveOutHeight = height = deletedSection.end - deletedSection.start;
                    } else {
                        height = deletedSection.moveOutHeight;
                        deletedSection.moveOutHeight = MPTableViewSentinelFloatValue;
                    }
                }
                offset -= height;
                [_sectionArray removeObjectAtIndex:node.index];
                
                // node.index - step - 1 == node.originalIndex
                if (node.type == MPTableViewUpdateDelete && [_tableView _needsDisplayAtSection:deletedSection withUpdateType:MPTableViewUpdateDelete withOffset:0]) {
                    MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                    MPTableViewRowAnimation animation = normalNode.animation;
                    
                    for (NSInteger j = 0; j < deletedSection.numberOfRows; j++) {
                        [_tableView _deleteCellInSection:node.originalIndex row:j animation:animation sectionPosition:deletedSection];
                    }
                    
                    [_tableView _deleteSectionViewInSection:node.originalIndex viewType:MPTableViewSectionHeader animation:animation deletedSection:deletedSection];
                    [_tableView _deleteSectionViewInSection:node.originalIndex viewType:MPTableViewSectionFooter animation:animation deletedSection:deletedSection];
                }
                
                sectionIndex = node.index;
            }
        }
    }
    
    sectionCount += step;
    NSInteger i = sectionIndex;
    
    if (hasDraggingCell) {
        NSInteger endSection;
        if (_dragSourceSection < _dragDestinationSection) {
            i = _dragSourceSection;
            endSection = _dragDestinationSection;
        } else {
            i = _dragDestinationSection;
            endSection = _dragSourceSection;
        }
        
        BOOL isEstimatedMode = [_tableView _isEstimatedMode];
        if (isEstimatedMode) {
            sectionCount = _sectionArray.count;
        } else {
            sectionCount = endSection + 1;
        }
        
        for (; i < sectionCount; i++) {
            if (i > endSection && offset == 0) { // only in estimated mode
                break;
            }
            
            MPTableViewSection *section = _sectionArray[i];
            NSAssert(section.section == i - step, @"unexpected internal state");
            
            BOOL needsDisplay = [_tableView _needsDisplayAtSection:section withUpdateType:MPTableViewUpdateRelayout withOffset:offset];
            
            offset = [self _relayoutSectionAtPosition:section toSection:i needsDisplay:needsDisplay hasDraggingCell:hasDraggingCell withOffset:offset];
        }
        
        if (!isEstimatedMode) {
            offset = 0; // may have floating-point precision issues
        }
    } else {
        for (; i < sectionCount; i++) {
            MPTableViewSection *section = _sectionArray[i];
            NSAssert(section.section == i - step, @"unexpected internal state");
            
            BOOL needsDisplay = [_tableView _needsDisplayAtSection:section withUpdateType:MPTableViewUpdateRelayout withOffset:offset];
            
            offset = [self _relayoutSectionAtPosition:section toSection:i needsDisplay:needsDisplay hasDraggingCell:hasDraggingCell withOffset:offset];
        }
    }
    
    return offset;
}

- (CGFloat)_relayoutSectionAtPosition:(MPTableViewSection *)sectionPosition toSection:(NSInteger)newSection needsDisplay:(BOOL)needsDisplay hasDraggingCell:(BOOL)hasDraggingCell withOffset:(CGFloat)offset {
    NSInteger numberOfRows = hasDraggingCell ? sectionPosition.numberOfRows : [_tableView.dataSource MPTableView:_tableView numberOfRowsInSection:newSection];
    if (numberOfRows < 0) {
        NSAssert(NO, @"the number of rows must not be negative");
        numberOfRows = 0;
    }
    
    if (sectionPosition.updatePart) {
        BOOL needsCheck = !hasDraggingCell;
        if (needsCheck) {
            sectionPosition.updatePart.previousCount = sectionPosition.numberOfRows;
            sectionPosition.updatePart.newCount = numberOfRows;
        }
        if (![sectionPosition.updatePart prepareForUpdateWithCheck:needsCheck]) {
            MPTV_THROW_EXCEPTION(@"number of rows from dataSource mismatch");
        }
        
        offset = [sectionPosition updateWithPartForTableView:_tableView toSection:newSection withOffset:offset needsDisplay:needsDisplay];
    } else {
        if (numberOfRows != sectionPosition.numberOfRows) {
            MPTV_THROW_EXCEPTION(@"number of rows from dataSource mismatch");
        }
        
        offset = [sectionPosition updateForTableView:_tableView toSection:newSection withOffset:offset needsDisplay:needsDisplay];
    }
    
    return offset;
}

- (void)_executeInsertionsAtSection:(MPTableViewSection *)insertedSection withAnimation:(MPTableViewRowAnimation)animation {
    CGFloat proposedInsertedLocationY = [_tableView _getProposedInsertedLocationY]; // may be changed
    void (^updateAction)(void) = ^{
        if (!_tableView) {
            return;
        }
        
        if (![_tableView _needsDisplayAtSection:insertedSection withUpdateType:MPTableViewUpdateInsert withOffset:0]) { // content offset may have been changed
            return;
        }
        
        for (NSInteger i = 0; i < insertedSection.numberOfRows; i++) {
            [_tableView _insertCellInSection:insertedSection.section row:i animation:animation sectionPosition:insertedSection proposedInsertedLocationY:proposedInsertedLocationY];
        }
        
        [_tableView _insertSectionViewInSection:insertedSection.section viewType:MPTableViewSectionHeader animation:animation insertedSection:insertedSection proposedInsertedLocationY:proposedInsertedLocationY];
        [_tableView _insertSectionViewInSection:insertedSection.section viewType:MPTableViewSectionFooter animation:animation insertedSection:insertedSection proposedInsertedLocationY:proposedInsertedLocationY];
    };
    
    [[_tableView _updateExecutionActions] addObject:updateAction];
}

- (void)_executeMovementsAtSection:(MPTableViewSection *)movedSection fromSection:(MPTableViewSection *)originalSection withShift:(CGFloat)shift {
    BOOL needsDisplay = [_tableView _needsDisplayAtSection:originalSection withUpdateType:MPTableViewUpdateMoveOut withOffset:0];
    void (^updateAction)(void) = ^{
        if (!_tableView) {
            return;
        }
        
        if (!needsDisplay && ![_tableView _needsDisplayAtSection:movedSection withUpdateType:MPTableViewUpdateMoveIn withOffset:shift]) {
            return;
        }
        
        for (NSInteger i = 0; i < movedSection.numberOfRows; i++) {
            [_tableView _moveCellToSection:movedSection.section row:i previousSection:originalSection.section previousRow:i previousHeight:[originalSection heightAtRow:i] withShift:shift];
        }
        
        [_tableView _moveSectionViewToSection:movedSection.section previousSection:originalSection.section viewType:MPTableViewSectionHeader previousHeight:originalSection.headerHeight withShift:shift];
        [_tableView _moveSectionViewToSection:movedSection.section previousSection:originalSection.section viewType:MPTableViewSectionFooter previousHeight:originalSection.footerHeight withShift:shift];
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
    if ([_unstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_unstableIndexes addIndex:row];
        _delta--;
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = row;
    node->originalIndex = row;
    node->type = MPTableViewUpdateDelete;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addInsertRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_stableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_stableIndexes addIndex:row];
        _delta++;
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = row;
    node->originalIndex = row;
    node->type = MPTableViewUpdateInsert;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addReloadRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation {
    if ([_unstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_unstableIndexes addIndex:row];
    }
    
    MPTableViewUpdateNormalNode *node = new MPTableViewUpdateNormalNode();
    node->index = row;
    node->originalIndex = row;
    node->type = MPTableViewUpdateReload;
    node->animation = animation;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveOutRow:(NSInteger)row {
    if ([_unstableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_unstableIndexes addIndex:row];
        _delta--;
    }
    
    MPTableViewUpdateNode *node = new MPTableViewUpdateNode();
    node->index = row;
    node->originalIndex = row;
    node->type = MPTableViewUpdateMoveOut;
    
    _updateNodes.push_back(node);
    return YES;
}

- (BOOL)addMoveInRow:(NSInteger)row previousIndexPath:(NSIndexPath *)previousIndexPath previousFrame:(CGRect)previousFrame {
    if ([_stableIndexes containsIndex:row]) {
        return NO;
    } else {
        [_stableIndexes addIndex:row];
        _delta++;
    }
    
    MPTableViewUpdateRowNode *node = new MPTableViewUpdateRowNode();
    node->index = row;
    node->originalIndex = row;
    node->type = MPTableViewUpdateMoveIn;
    node->originY = previousFrame.origin.y;
    node->height = previousFrame.size.height;
    node->indexPath = previousIndexPath;
    
    _updateNodes.push_back(node);
    return YES;
}

@end

#pragma mark -
typedef deque<CGFloat>::iterator CGFloatDequeIterator;

@implementation MPTableViewSection {
    deque<CGFloat> _rowPositionDeque;
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
    section->_rowPositionDeque = _rowPositionDeque;
    section.numberOfRows = _numberOfRows;
    section.moveOutHeight = _moveOutHeight;
    
    return section;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@; section = %zd; numberOfRows = %zd; headerHeight = %f; footerHeight = %f", [super description], _section, _numberOfRows, _headerHeight, _footerHeight];
}

- (void)reset {
    if (_rowPositionDeque.size() > 0) {
        _rowPositionDeque.clear();
    }
    
    _numberOfRows = 0;
    self.start = self.end = 0;
    _headerHeight = _footerHeight = 0;
    _section = NSNotFound;
    _moveOutHeight = MPTableViewSentinelFloatValue;
    
    _updatePart = nil;
}

- (void)addRowPosition:(CGFloat)position {
    _rowPositionDeque.push_back(position);
}

- (CGFloat)startPositionAtRow:(NSInteger)row {
    return _rowPositionDeque[row];
}

- (CGFloat)endPositionAtRow:(NSInteger)row {
    return _rowPositionDeque[row + 1];
}

- (CGFloat)heightAtRow:(NSInteger)row {
    CGFloat height = _rowPositionDeque[row + 1] - _rowPositionDeque[row];
    if (height < 0) { // may have floating-point precision issues
        height = 0;
    }
    
    return height;
}

- (NSInteger)rowForContentOffsetY:(CGFloat)contentOffsetY {
    if (_headerHeight > 0 && (contentOffsetY <= self.start + _headerHeight)) {
        return MPTableViewSectionHeader;
    }
    if (_footerHeight > 0 && (contentOffsetY >= self.end - _footerHeight)) {
        return MPTableViewSectionFooter;
    }
    
    if (_numberOfRows == 0) {
        if (contentOffsetY < self.start) {
            return MPTableViewSectionHeader;
        } else if (contentOffsetY > self.end) {
            return MPTableViewSectionFooter;
        } else {
            return _headerHeight > 0 ? MPTableViewSectionHeader : MPTableViewSectionFooter;
        }
    }
    
    NSInteger low = 0;
    NSInteger high = _numberOfRows - 1;
    NSInteger mid = 0;
    while (low <= high) {
        mid = (low + high) / 2;
        CGFloat startPosition = [self startPositionAtRow:mid];
        CGFloat endPosition = [self endPositionAtRow:mid];
        if (startPosition > contentOffsetY) {
            high = mid - 1;
        } else if (endPosition < contentOffsetY) {
            low = mid + 1;
        } else {
            return mid;
        }
    }
    
    return mid; // may have floating-point precision issues
}

#pragma mark -

- (void)makePositionOffset:(CGFloat)offset {
    if (offset == 0) {
        return;
    }
    
    self.start += offset;
    self.end += offset;
    for (CGFloat &position : _rowPositionDeque) {
        position += offset;
    }
}

- (CGFloat)_updateRowForTableView:(MPTableView *)tableView toSection:(NSInteger)newSection row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow withOffset:(CGFloat)offset previousHeight:(CGFloat)previousHeight endPositionIterator:(CGFloatDequeIterator &)endPositionIterator hasDraggingCell:(BOOL)hasDraggingCell shouldLoadHeight:(BOOL *)shouldLoadHeight {
    CGFloat previousOffset = offset;
    
    if (*shouldLoadHeight) {
        CGFloat delta = [tableView _cellHeightDeltaForRelayoutInSection:newSection row:row previousSection:previousSection previousRow:previousRow withOffset:offset shouldLoadHeight:shouldLoadHeight];
        if (delta != 0) {
            offset += delta;
            *endPositionIterator += delta;
        }
    }
    
    [self _relayoutCellForTableView:tableView toSection:newSection row:row previousSection:previousSection previousRow:previousRow previousHeight:previousHeight withOffset:previousOffset hasDraggingCell:hasDraggingCell];
    
    return offset;
}

- (void)_relayoutCellForTableView:(MPTableView *)tableView toSection:(NSInteger)newSection row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow previousHeight:(CGFloat)previousHeight withOffset:(CGFloat)offset hasDraggingCell:(BOOL)hasDraggingCell {
    if (hasDraggingCell) {
        [tableView _relayoutCellToSection:newSection row:row previousSection:previousSection previousRow:previousRow previousHeight:previousHeight withOffset:offset];
    } else {
        void (^updateAction)(void) = ^{
            if (!tableView) {
                return;
            }
            
            [tableView _relayoutCellToSection:newSection row:row previousSection:previousSection previousRow:previousRow previousHeight:previousHeight withOffset:offset];
        };
        [[tableView _updateExecutionActions] addObject:updateAction];
    }
}

- (CGFloat)_applyComputedHeaderHeightForTableView:(MPTableView *)tableView fromPreviousSection:(NSInteger)previousSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion {
    CGFloat headerHeight = [tableView _computedHeaderHeightAtSection:self fromPreviousSection:previousSection withOffset:offset isInsertion:isInsertion];
    if (headerHeight != MPTableViewSentinelFloatValue) {
        offset += headerHeight - _headerHeight;
        _headerHeight = headerHeight;
    }
    
    return offset;
}

- (CGFloat)_applyComputedFooterHeightForTableView:(MPTableView *)tableView fromPreviousSection:(NSInteger)previousSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion {
    CGFloat footerHeight = [tableView _computedFooterHeightAtSection:self fromPreviousSection:previousSection withOffset:offset isInsertion:isInsertion];
    if (footerHeight != MPTableViewSentinelFloatValue) {
        CGFloat delta = footerHeight - _footerHeight;
        offset += delta;
        self.end += delta;
        _footerHeight = footerHeight;
    }
    
    return offset;
}

- (void)_relayoutSectionViewsForTableView:(MPTableView *)tableView toSection:(NSInteger)newSection previousSection:(NSInteger)previousSection withHeaderOffset:(CGFloat)headerOffset footerOffset:(CGFloat)footerOffset previousHeaderHeight:(CGFloat)previousHeaderHeight previousFooterHeight:(CGFloat)previousFooterHeight hasDraggingCell:(BOOL)hasDraggingCell needsDisplay:(BOOL)needsDisplay {
    BOOL needsRelayoutHeader = needsDisplay || [tableView _hasAnimatingSectionViewInPreviousSection:previousSection viewType:MPTableViewSectionHeader];
    BOOL needsRelayoutFooter = needsDisplay || [tableView _hasAnimatingSectionViewInPreviousSection:previousSection viewType:MPTableViewSectionFooter];
    
    if (needsRelayoutHeader) {
        if (hasDraggingCell) {
            [tableView _relayoutSectionViewToSection:newSection previousSection:previousSection viewType:MPTableViewSectionHeader previousHeight:previousHeaderHeight withOffset:headerOffset];
        } else {
            void (^updateAction)(void) = ^{
                if (!tableView) {
                    return;
                }
                
                [tableView _relayoutSectionViewToSection:newSection previousSection:previousSection viewType:MPTableViewSectionHeader previousHeight:previousHeaderHeight withOffset:headerOffset];
            };
            [[tableView _updateExecutionActions] addObject:updateAction];
        }
    }
    
    if (needsRelayoutFooter) {
        if (hasDraggingCell) {
            [tableView _relayoutSectionViewToSection:newSection previousSection:previousSection viewType:MPTableViewSectionFooter previousHeight:previousFooterHeight withOffset:footerOffset];
        } else {
            void (^updateAction)(void) = ^{
                if (!tableView) {
                    return;
                }
                
                [tableView _relayoutSectionViewToSection:newSection previousSection:previousSection viewType:MPTableViewSectionFooter previousHeight:previousFooterHeight withOffset:footerOffset];
            };
            [[tableView _updateExecutionActions] addObject:updateAction];
        }
    }
}

- (CGFloat)updateWithPartForTableView:(MPTableView *)tableView toSection:(NSInteger)newSection withOffset:(CGFloat)offset needsDisplay:(BOOL)needsDisplay {
    self.start += offset;
    
    NSInteger previousSection = _section;
    _section = newSection;
    CGFloat headerOffset = offset;
    CGFloat previousHeaderHeight = _headerHeight, previousFooterHeight = _footerHeight;
    BOOL hasDraggingCell = [tableView _hasDraggingCell];
    
    BOOL needsUpdateHeaderHeight = YES;
    if (hasDraggingCell) {
        needsUpdateHeaderHeight = [tableView _needsEstimateHeightForHeader] && offset != 0;
    }
    if (needsDisplay && needsUpdateHeaderHeight) {
        CGFloat previousOffset = offset;
        self.end += previousOffset; // shift end position to a temporary reference
        offset = [self _applyComputedHeaderHeightForTableView:tableView fromPreviousSection:previousSection withOffset:offset isInsertion:NO];
        self.end -= previousOffset; // restore from the temporary reference
    }
    
    CGFloatDequeIterator startPositionIterator = _rowPositionDeque.begin();
    CGFloatDequeIterator endPositionIterator = startPositionIterator + 1;
    
    CGFloat previousPosition = *startPositionIterator;
    CGFloat newPosition = previousPosition + offset;
    *startPositionIterator = newPosition;
    
    if (!hasDraggingCell) {
        [tableView _setProposedInsertedLocationY:previousPosition];
        [tableView _setProposedDeletedPositionY:newPosition];
    }
    
    NSInteger rowIndex = 0;
    NSInteger step = 0;
    
    BOOL hasRelevantCell = [tableView _hasRelevantCellsInPreviousSection:previousSection];
    
    auto end = _updatePart->_updateNodes.cend();
    for (auto iter = _updatePart->_updateNodes.cbegin(); iter != end; ++iter) {
        const MPTableViewUpdateNode &node = **iter;
        
        BOOL needsUpdateRows = rowIndex < node.index;
        if (hasDraggingCell) {
            needsUpdateRows = needsUpdateRows && (offset != 0 || step != 0);
        } else {
            needsUpdateRows = needsUpdateRows && (offset != 0 || needsDisplay || hasRelevantCell);
        }
        if (needsUpdateRows) {
            BOOL shouldLoadHeight = YES;
            if (hasDraggingCell) {
                shouldLoadHeight = [tableView _needsEstimateHeightForRow];
            }
            
            for (; rowIndex < node.index; rowIndex++) { // guaranteed to execute by previous checks
                if (offset != 0) {
                    *endPositionIterator += offset;
                }
                
                NSInteger row = rowIndex;
                NSInteger previousRow = rowIndex - step;
                
                BOOL needsRelayout;
                if (hasRelevantCell) {
                    needsRelayout = [tableView _needsRelayoutRelevantCellInSection:newSection row:row previousSection:previousSection previousRow:previousRow] || needsDisplay; // needsDisplay must not be on the left of ||, the left-hand check returns a BOOL but must be executed.
                } else {
                    needsRelayout = needsDisplay;
                }
                
                if (needsRelayout) {
                    CGFloat previousHeight = *endPositionIterator - *startPositionIterator;
                    offset = [self _updateRowForTableView:tableView toSection:newSection row:row previousSection:previousSection previousRow:previousRow withOffset:offset previousHeight:previousHeight endPositionIterator:endPositionIterator hasDraggingCell:hasDraggingCell shouldLoadHeight:&shouldLoadHeight];
                } else {
                    if (offset == 0 && !hasRelevantCell) {
                        break;
                    }
                }
                
                startPositionIterator = endPositionIterator;
                ++endPositionIterator;
            }
            
            if (!hasDraggingCell && rowIndex == node.index) { // reached only if the loop completes without early break
                newPosition = *startPositionIterator;
                [tableView _setProposedInsertedLocationY:newPosition - offset];
                [tableView _setProposedDeletedPositionY:newPosition];
            }
        }
        
        if (rowIndex < node.index) { // offset is 0 in this case
            startPositionIterator += node.index - rowIndex;
            endPositionIterator = startPositionIterator + 1;
            if (!hasDraggingCell) {
                CGFloat startPosition = *startPositionIterator;
                [tableView _setProposedInsertedLocationY:startPosition];
                [tableView _setProposedDeletedPositionY:startPosition];
            }
        }
        
        if (MPTV_IS_STABLE_UPDATE_TYPE(node.type)) {
            step++;
            
            if (node.type == MPTableViewUpdateInsert) {
                CGFloat height = [tableView _cellHeightForInsertionInSection:newSection row:node.index];
                offset += height;
                
                CGFloat endPosition = *startPositionIterator + height;
                startPositionIterator = _rowPositionDeque.insert(endPositionIterator, endPosition);
                endPositionIterator = startPositionIterator + 1;
                _numberOfRows++;
                
                if (needsDisplay) {
                    CGFloat proposedInsertedLocationY = [tableView _getProposedInsertedLocationY];
                    NSInteger row = node.index; // copy value, C++ reference is unsafe to capture in Objective-C block in release mode.
                    MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                    MPTableViewRowAnimation animation = normalNode.animation;
                    void (^updateAction)(void) = ^{
                        if (!tableView) { // necessary
                            return;
                        }
                        
                        [tableView _insertCellInSection:newSection row:row animation:animation sectionPosition:nil proposedInsertedLocationY:proposedInsertedLocationY];
                    };
                    [[tableView _updateExecutionActions] addObject:updateAction];
                }
            } else {
                const MPTableViewUpdateRowNode &rowNode = (MPTableViewUpdateRowNode &)node;
                CGFloat height = rowNode.height;
                offset += height;
                
                CGFloat startPosition = *startPositionIterator;
                CGFloat endPosition = startPosition + height;
                startPositionIterator = _rowPositionDeque.insert(endPositionIterator, endPosition);
                endPositionIterator = startPositionIterator + 1;
                _numberOfRows++;
                
                CGFloat shift = startPosition - rowNode.originY;
                
                if (hasDraggingCell) {
                    [tableView _moveCellToSection:newSection row:node.index previousSection:rowNode.indexPath.section previousRow:rowNode.indexPath.row previousHeight:height withShift:shift];
                } else {
                    CGFloat delta = [tableView _cellHeightDeltaForMoveInToSection:newSection row:node.index fromPreviousIndexPath:rowNode.indexPath previousHeight:height withShift:shift];
                    if (delta != 0) {
                        offset += delta;
                        *startPositionIterator += delta;
                    }
                    
                    NSInteger row = node.index;
                    NSIndexPath *previousIndexPath = rowNode.indexPath;
                    void (^updateAction)(void) = ^{
                        if (!tableView) {
                            return;
                        }
                        
                        [tableView _moveCellToSection:newSection row:row previousSection:previousIndexPath.section previousRow:previousIndexPath.row previousHeight:height withShift:shift];
                    };
                    [[tableView _updateExecutionActions] addObject:updateAction];
                }
            }
            
            rowIndex = node.index + 1;
        } else { // unstable
            CGFloat previousEndPosition = *endPositionIterator;
            
            if (node.type == MPTableViewUpdateReload) {
                CGFloat height = [tableView _cellHeightForInsertionInSection:newSection row:node.index];
                CGFloat startPosition = *startPositionIterator;
                offset += height - (previousEndPosition + offset - startPosition);
                
                *endPositionIterator = startPosition + height;
                
                MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                MPTableViewRowAnimation animation = normalNode.animation;
                
                // node.index - step == node.originalIndex
                [tableView _deleteCellInSection:previousSection row:node.originalIndex animation:animation sectionPosition:nil];
                if (needsDisplay) {
                    CGFloat proposedInsertedLocationY = [tableView _getProposedInsertedLocationY];
                    NSInteger row = node.index;
                    void (^updateAction)(void) = ^{
                        if (!tableView) { // necessary
                            return;
                        }
                        
                        [tableView _insertCellInSection:newSection row:row animation:animation sectionPosition:nil proposedInsertedLocationY:proposedInsertedLocationY];
                    };
                    [[tableView _updateExecutionActions] addObject:updateAction];
                }
                
                if (!hasDraggingCell) {
                    [tableView _setProposedInsertedLocationY:previousEndPosition];
                    [tableView _setProposedDeletedPositionY:*endPositionIterator];
                }
                
                startPositionIterator = endPositionIterator;
                ++endPositionIterator;
                
                rowIndex = node.index + 1;
            } else { // node.type == MPTableViewUpdateDelete || node.type == MPTableViewUpdateMoveOut
                step--;
                
                CGFloat height = previousEndPosition + offset - *startPositionIterator;
                offset -= height;
                endPositionIterator = _rowPositionDeque.erase(endPositionIterator);
                startPositionIterator = endPositionIterator - 1;
                _numberOfRows--;
                
                // node.index - step - 1 == node.originalIndex
                if (node.type == MPTableViewUpdateDelete) {
                    MPTableViewUpdateNormalNode &normalNode = (MPTableViewUpdateNormalNode &)node;
                    [tableView _deleteCellInSection:previousSection row:node.originalIndex animation:normalNode.animation sectionPosition:nil];
                }
                
                rowIndex = node.index;
            }
        }
    }
    
    BOOL needsUpdateRows = rowIndex < _numberOfRows;
    if (hasDraggingCell) {
        if ([tableView _isEstimatedMode]) {
            needsUpdateRows = needsUpdateRows && (step != 0 || offset != 0);
        } else {
            needsUpdateRows = needsUpdateRows && (step != 0);
        }
    } else {
        needsUpdateRows = needsUpdateRows && (offset != 0 || needsDisplay || hasRelevantCell);
    }
    if (needsUpdateRows) {
        BOOL shouldLoadHeight = YES;
        if (hasDraggingCell) {
            shouldLoadHeight = [tableView _needsEstimateHeightForRow];
        }
        
        for (; rowIndex < _numberOfRows; rowIndex++) {
            if (offset != 0) {
                *endPositionIterator += offset;
            }
            
            NSInteger row = rowIndex;
            NSInteger previousRow = rowIndex - step;
            
            BOOL needsRelayout;
            if (hasRelevantCell) {
                needsRelayout = [tableView _needsRelayoutRelevantCellInSection:newSection row:row previousSection:previousSection previousRow:previousRow] || needsDisplay;
            } else {
                needsRelayout = needsDisplay;
            }
            
            if (needsRelayout) {
                CGFloat previousHeight = *endPositionIterator - *startPositionIterator;
                offset = [self _updateRowForTableView:tableView toSection:newSection row:row previousSection:previousSection previousRow:previousRow withOffset:offset previousHeight:previousHeight endPositionIterator:endPositionIterator hasDraggingCell:hasDraggingCell shouldLoadHeight:&shouldLoadHeight];
            } else {
                if (offset == 0 && !hasRelevantCell) {
                    break;
                }
            }
            
            startPositionIterator = endPositionIterator;
            ++endPositionIterator;
        }
    }
    
    previousPosition = self.end;
    self.end = previousPosition + offset;
    CGFloat footerOffset = offset;
    
    BOOL needsUpdateFooterHeight = YES;
    if (hasDraggingCell) {
        needsUpdateFooterHeight = [tableView _needsEstimateHeightForFooter] && offset != 0;
    }
    if (needsDisplay && needsUpdateFooterHeight) {
        offset = [self _applyComputedFooterHeightForTableView:tableView fromPreviousSection:previousSection withOffset:offset isInsertion:NO];
    }
    
    if (!hasDraggingCell) {
        [tableView _setProposedInsertedLocationY:previousPosition];
        [tableView _setProposedDeletedPositionY:self.end];
    }
    
    [self _relayoutSectionViewsForTableView:tableView toSection:newSection previousSection:previousSection withHeaderOffset:headerOffset footerOffset:footerOffset previousHeaderHeight:previousHeaderHeight previousFooterHeight:previousFooterHeight hasDraggingCell:hasDraggingCell needsDisplay:needsDisplay];
    
    _updatePart = nil;
    
    return offset;
}

- (CGFloat)updateForTableView:(MPTableView *)tableView toSection:(NSInteger)newSection withOffset:(CGFloat)offset needsDisplay:(BOOL)needsDisplay {
    BOOL needsDisplaySectionViews = (offset != 0) && [tableView _needsDisplayAtSection:self forRelayoutWithOffset:offset];
    CGFloat previousOffset = offset;
    
    self.start += offset;
    NSInteger previousSection = _section;
    _section = newSection;
    CGFloat headerOffset = offset;
    CGFloat previousHeaderHeight = _headerHeight, previousFooterHeight = _footerHeight;
    BOOL hasDraggingCell = [tableView _hasDraggingCell];
    
    BOOL needsUpdateHeaderHeight = YES;
    if (hasDraggingCell) {
        needsUpdateHeaderHeight = [tableView _needsEstimateHeightForHeader] && offset != 0;
    }
    if (needsDisplay && needsUpdateHeaderHeight) {
        self.end += previousOffset; // shift end position to a temporary reference
        offset = [self _applyComputedHeaderHeightForTableView:tableView fromPreviousSection:previousSection withOffset:offset isInsertion:NO];
        self.end -= previousOffset; // restore from the temporary reference
    }
    
    CGFloatDequeIterator startPositionIterator = _rowPositionDeque.begin();
    *startPositionIterator += offset;
    
    BOOL hasRelevantCell = [tableView _hasRelevantCellsInPreviousSection:previousSection];
    if (offset != 0 || needsDisplay || hasRelevantCell) {
        BOOL shouldLoadHeight = YES;
        if (hasDraggingCell) {
            shouldLoadHeight = [tableView _needsEstimateHeightForRow];
        }
        
        CGFloatDequeIterator endPositionIterator = startPositionIterator + 1;
        for (NSInteger i = 0; i < _numberOfRows; i++) {
            if (offset != 0) {
                *endPositionIterator += offset;
            }
            
            BOOL needsRelayout;
            if (hasRelevantCell) {
                needsRelayout = [tableView _needsRelayoutRelevantCellInSection:newSection row:i previousSection:previousSection previousRow:i] || needsDisplay;
            } else {
                needsRelayout = needsDisplay;
            }
            
            if (needsRelayout) {
                CGFloat previousHeight = *endPositionIterator - *startPositionIterator;
                offset = [self _updateRowForTableView:tableView toSection:newSection row:i previousSection:previousSection previousRow:i withOffset:offset previousHeight:previousHeight endPositionIterator:endPositionIterator hasDraggingCell:hasDraggingCell shouldLoadHeight:&shouldLoadHeight];
            } else {
                if (offset == 0 && !hasRelevantCell) {
                    break;
                } else if (needsRelayout) {
                    [self _relayoutCellForTableView:tableView toSection:newSection row:i previousSection:previousSection previousRow:i previousHeight:[self heightAtRow:i] withOffset:offset hasDraggingCell:hasDraggingCell];
                }
            }
            
            startPositionIterator = endPositionIterator;
            ++endPositionIterator;
        }
    }
    
    CGFloat previousPosition = self.end;
    self.end = previousPosition + offset;
    CGFloat footerOffset = offset;
    
    BOOL needsUpdateFooterHeight = YES;
    if (hasDraggingCell) {
        needsUpdateFooterHeight = [tableView _needsEstimateHeightForFooter] && offset != 0;
    }
    if (needsDisplay && needsUpdateFooterHeight) {
        offset = [self _applyComputedFooterHeightForTableView:tableView fromPreviousSection:previousSection withOffset:offset isInsertion:NO];
    }
    
    if (!hasDraggingCell) {
        [tableView _setProposedInsertedLocationY:previousPosition];
        [tableView _setProposedDeletedPositionY:self.end];
    }
    
    [self _relayoutSectionViewsForTableView:tableView toSection:newSection previousSection:previousSection withHeaderOffset:headerOffset footerOffset:footerOffset previousHeaderHeight:previousHeaderHeight previousFooterHeight:previousFooterHeight hasDraggingCell:hasDraggingCell needsDisplay:needsDisplay || needsDisplaySectionViews];
    
    return offset;
}

- (void)rebuildForTableView:(MPTableView *)tableView fromPreviousSection:(NSInteger)previousSection withShift:(CGFloat)shift isInsertion:(BOOL)isInsertion {
    if ([tableView _isEstimatedMode]) {
        if (!tableView.shouldReloadAllDataDuringUpdate) {
            if (isInsertion) {
                if (![tableView _needsDisplayAtSection:self withUpdateType:MPTableViewUpdateInsert withOffset:0]) {
                    return;
                }
            } else {
                NSInteger section = _section;
                _section = previousSection;
                BOOL needsDisplay = [tableView _needsDisplayAtSection:self withUpdateType:MPTableViewUpdateMoveIn withOffset:shift] || [tableView _hasDisplayedViewAtSection:self];
                _section = section;
                
                if (!needsDisplay) {
                    return;
                }
            }
        }
    } else {
        if (isInsertion) { // non-estimated insertion
            return;
        }
    }
    
    // for estimated movement and insertion, and non-estimated movement
    CGFloat offset = 0;
    
    if (!isInsertion || [tableView _needsEstimateHeightForHeader]) { // verified (ignores shouldReloadAllDataDuringUpdate)
        offset = [self _applyComputedHeaderHeightForTableView:tableView fromPreviousSection:previousSection withOffset:shift isInsertion:isInsertion];
        offset -= shift;
    }
    
    _rowPositionDeque[0] += offset;
    
    BOOL shouldLoadHeight = !isInsertion || [tableView _needsEstimateHeightForRow];
    if (shouldLoadHeight || offset != 0) {
        for (NSInteger i = 0; i < _numberOfRows; i++) {
            if (offset != 0) {
                _rowPositionDeque[i + 1] += offset;
            }
            
            if (!shouldLoadHeight) {
                if (offset == 0) {
                    break;
                } else {
                    continue;
                }
            }
            CGFloat delta = [tableView _cellHeightDeltaForCalculatedCellInSection:self.section row:i previousSection:previousSection withShift:shift shouldLoadHeight:&shouldLoadHeight];
            if (delta != 0) {
                offset += delta;
                _rowPositionDeque[i + 1] += delta;
            }
        }
    }
    
    self.end += offset;
    if (!isInsertion || [tableView _needsEstimateHeightForFooter]) {
        [self _applyComputedFooterHeightForTableView:tableView fromPreviousSection:previousSection withOffset:shift isInsertion:isInsertion];
    }
}

// called only when needsDisplay is YES or offset != 0
- (CGFloat)applyHeightsDuringEstimateForTableView:(MPTableView *)tableView fromFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needsDisplay:(BOOL)needsDisplay {
    self.start += offset;
    
    NSInteger previousSection = _section;
    
    CGFloat headerHeight = MPTableViewSentinelFloatValue;
    if (needsDisplay && _headerHeight > 0 && [tableView _needsEstimateHeightForHeader]) {
        self.end += offset;
        headerHeight = [tableView _computedHeaderHeightDuringEstimateAtSection:self];
        self.end -= offset;
        if (headerHeight != MPTableViewSentinelFloatValue) {
            offset += headerHeight - _headerHeight;
            _headerHeight = headerHeight;
        }
    }
    
    CGFloatDequeIterator positionIterator = _rowPositionDeque.begin();
    *positionIterator += offset;
    
    BOOL shouldLoadHeight = needsDisplay;
    NSInteger i = (headerHeight == MPTableViewSentinelFloatValue) ? firstRow : 0;
    for (positionIterator += i; i < _numberOfRows; i++) {
        ++positionIterator;
        if (offset != 0) {
            *positionIterator += offset;
        }
        
        if (!shouldLoadHeight) {
            if (offset == 0) {
                break;
            } else {
                continue;
            }
        }
        CGFloat delta = [tableView _displayCellDuringEstimateInSection:previousSection row:i withOffset:offset shouldLoadHeight:&shouldLoadHeight];
        if (delta != 0) {
            offset += delta;
            *positionIterator += delta;
        }
    }
    
    self.end += offset;
    
    if (needsDisplay && _footerHeight > 0 && [tableView _needsEstimateHeightForFooter]) {
        CGFloat footerHeight = [tableView _computedFooterHeightDuringEstimateAtSection:self];
        if (footerHeight != MPTableViewSentinelFloatValue) {
            CGFloat delta = footerHeight - _footerHeight;
            offset += delta;
            self.end += delta;
            _footerHeight = footerHeight;
        }
    }
    
    if (needsDisplay) {
        [tableView _displaySectionViewDuringEstimateInSection:previousSection viewType:MPTableViewSectionHeader];
        [tableView _displaySectionViewDuringEstimateInSection:previousSection viewType:MPTableViewSectionFooter];
    }
    
    return offset;
}

@end
