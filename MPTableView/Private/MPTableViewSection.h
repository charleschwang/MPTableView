//
//  MPTableViewSection.h
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015 PBA. All rights reserved.
//

#import "MPTableView.h"

#ifndef _MPTV_DEFINE_
#define _MPTV_DEFINE_

#define MPTV_IS_HEADER(_row_) ((_row_) == MPSectionHeader)
#define MPTV_IS_FOOTER(_row_) ((_row_) == MPSectionFooter)
#define MPTV_ROW_LESS(_row1_, _row2_) (((_row1_) == (_row2_)) ? NO : (MPTV_IS_HEADER(_row1_) ? YES : MPTV_IS_HEADER(_row2_) ? NO : ((NSUInteger)_row1_) < ((NSUInteger)_row2_)))
#define MPTV_ROW_MORE(_row1_, _row2_) (((_row1_) == (_row2_)) ? NO : (MPTV_IS_HEADER(_row1_) ? NO : MPTV_IS_HEADER(_row2_) ? YES : ((NSUInteger)_row1_) > ((NSUInteger)_row2_)))

#define MPTV_IS_STABLE_UPDATE_TYPE(_type_) ((_type_) == MPTableViewUpdateInsert || (_type_) == MPTableViewUpdateMoveIn)
#define MPTV_IS_UNSTABLE_UPDATE_TYPE(_type_) ((_type_) == MPTableViewUpdateDelete || (_type_) == MPTableViewUpdateMoveOut || (_type_) == MPTableViewUpdateReload)

#define MPTV_EXCEPTION(_reason_) @throw [NSException exceptionWithName:NSGenericException reason:(_reason_) userInfo:nil]

#endif

#pragma mark -

typedef NS_ENUM(NSInteger, MPSectionViewType) {
    MPSectionHeader = NSIntegerMin + 32, MPSectionFooter = NSIntegerMin + 64
};

typedef NS_ENUM(NSInteger, MPTableViewUpdateType) {
    MPTableViewUpdateDelete,
    MPTableViewUpdateInsert,
    MPTableViewUpdateReload,
    MPTableViewUpdateMoveOut,
    MPTableViewUpdateMoveIn,
    MPTableViewUpdateAdjust
};

const CGFloat MPTableViewInvalidFloatValue = -87853507.0;

#pragma mark -

@interface MPTableViewPosition : NSObject<NSCopying>

@property (nonatomic) CGFloat startPos;
@property (nonatomic) CGFloat endPos;

+ (instancetype)positionStart:(CGFloat)start toEnd:(CGFloat)end;

@end

#pragma mark -

@class MPTableViewSection;

@interface MPTableViewUpdateBase : NSObject {
    @package
    NSMutableIndexSet *_existingStableIndexes;
    NSMutableIndexSet *_existingUnstableIndexes;
    
    NSInteger _differ;
}

@property (nonatomic) NSInteger lastCount;
@property (nonatomic) NSInteger newCount;

- (BOOL)prepareToUpdateThenNeedToCheck:(BOOL)needToCheck; // For example, a section has 5 rows, it is unable to insert 5 after delete 0.

- (void)deleteNodes;

@end

#pragma mark -

@interface MPTableView (MPTableViewUpdate)

- (BOOL)_hasDraggingCell;

- (MPTableViewSection *)_updateBuildSection:(NSInteger)section;

- (NSMutableArray *)_updateExecutionActions; // for insertion and movement

- (CGFloat)_updateGetDeletedPositionY; // not used
- (void)_updateSetDeletedPositionY:(CGFloat)deletedPositionY;
- (CGFloat)_updateGetInsertedLocationY;
- (void)_updateSetInsertedLocationY:(CGFloat)insertedLocationY;

- (CGFloat)_updateGetInsertCellHeightInSection:(NSInteger)section atRow:(NSInteger)row;
- (CGFloat)_updateGetMoveInCellDifferInSection:(NSInteger)section atRow:(NSInteger)row withLastIndexPath:(NSIndexPath *)lastIndexPath withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;
- (CGFloat)_updateGetAdjustCellDifferInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withOffset:(CGFloat)offset needToLoadHeight:(BOOL *)needToLoadHeight;
- (CGFloat)_updateGetHeaderHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion;
- (CGFloat)_updateGetFooterHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion;

- (CGFloat)_updateGetRebuildCellDifferInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance needToLoadHeight:(BOOL *)needToLoadHeight;

- (BOOL)_updateNeedToDisplayForSection:(MPTableViewSection *)section withUpdateType:(MPTableViewUpdateType)type withOffset:(CGFloat)offset;
- (BOOL)_updateHasHumbleCellsInLastSection:(NSInteger)lastSection;
- (BOOL)_updateNecessaryToAdjustSection:(MPTableViewSection *)section withOffset:(CGFloat)offset;

- (BOOL)_updateNeedToAdjustHumbleCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow;
- (BOOL)_updateHasHumbleSectionViewInLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type;

- (void)_updateDeleteCellInSection:(NSInteger)lastSection atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition;
- (void)_updateInsertCellToSection:(NSInteger)section atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition atInsertedLocationY:(CGFloat)insertedLocationY;
- (void)_updateMoveCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;
- (void)_updateAdjustCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset;

- (void)_updateDeleteSectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection;
- (void)_updateInsertSectionViewToSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection atInsertedLocationY:(CGFloat)insertedLocationY;
- (void)_updateMoveSectionViewToSection:(NSInteger)section fromLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;
- (void)_updateAdjustSectionViewToSection:(NSInteger)section fromLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset;

@end

#pragma mark -

@interface MPTableViewUpdateManager : MPTableViewUpdateBase

@property (nonatomic, weak, readonly) MPTableView *tableView;
@property (nonatomic, weak) NSMutableArray *sectionsArray;

@property (nonatomic, strong) NSMutableArray *transactions;

@property (nonatomic) NSInteger dragFromSection;
@property (nonatomic) NSInteger dragToSection;

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView andSectionsArray:(NSMutableArray *)sectionsArray;
- (void)reset;
- (BOOL)hasUpdateNodes;

- (BOOL)addDeleteSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutSection:(NSInteger)section;
- (BOOL)addMoveInSection:(NSInteger)section fromLastSection:(NSInteger)lastSection;

- (BOOL)addDeleteIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutIndexPath:(NSIndexPath *)indexPath;
- (BOOL)addMoveInIndexPath:(NSIndexPath *)indexPath withLastIndexPath:(NSIndexPath *)lastIndexPath withLastFrame:(CGRect)lastFrame;

- (CGFloat)update;

@end

#pragma mark -

@interface MPTableViewUpdatePart : MPTableViewUpdateBase

- (BOOL)addDeleteRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutRow:(NSInteger)row;
- (BOOL)addMoveInRow:(NSInteger)row withLastIndexPath:(NSIndexPath *)lastIndexPath withLastFrame:(CGRect)lastFrame;

@end

#pragma mark -

@interface MPTableView (MPTableViewEstimate)

- (BOOL)_isEstimatedMode;
- (BOOL)_needToEstimateHeightForRow;
- (BOOL)_needToEstimateHeightForHeader;
- (BOOL)_needToEstimateHeightForFooter;

- (BOOL)_hasDisplayedInSection:(MPTableViewSection *)section;

- (CGFloat)_estimatedGetHeaderHeightInSection:(MPTableViewSection *)section;
- (CGFloat)_estimatedGetFooterHeightInSection:(MPTableViewSection *)section;
- (CGFloat)_estimatedDisplayCellInSection:(NSInteger)section atRow:(NSInteger)row withOffset:(CGFloat)offset needToLoadHeight:(BOOL *)needToLoadHeight;
- (void)_estimatedDisplaySectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type;

@end

#pragma mark -

@interface MPTableViewSection : MPTableViewPosition

@property (nonatomic) NSInteger section;
@property (nonatomic) CGFloat headerHeight;
@property (nonatomic) CGFloat footerHeight;
@property (nonatomic) NSInteger numberOfRows;

@property (nonatomic, strong) MPTableViewUpdatePart *updatePart;
@property (nonatomic) CGFloat moveOutHeight;

+ (instancetype)section;
- (void)reset;

- (void)addRowPosition:(CGFloat)position;
- (CGFloat)startPositionAtRow:(NSInteger)row;
- (CGFloat)endPositionAtRow:(NSInteger)row;
- (CGFloat)heightAtRow:(NSInteger)row;
- (NSInteger)rowAtContentOffsetY:(CGFloat)contentOffsetY; // includes header or footer

- (void)makePositionOffset:(CGFloat)offset;

- (void)rebuildForTableView:(MPTableView *)tableView fromLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance isInsertion:(BOOL)isInsertion;

- (CGFloat)updateWithPartForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;
- (CGFloat)updateForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;

- (CGFloat)estimateForTableView:(MPTableView *)tableView atFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;

@end
