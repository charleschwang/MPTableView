//
//  MPTableViewSection.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"

#ifndef __MPTV_DEFINE
#define __MPTV_DEFINE

UIKIT_EXTERN NSExceptionName const MPTableViewException;
UIKIT_EXTERN NSExceptionName const MPTableViewUpdateException;

#define MPTV_EXCEPTION(_reason_) @throw [NSException exceptionWithName:MPTableViewException reason:_reason_ userInfo:nil];
#define MPTV_UPDATE_EXCEPTION(_reason_) @throw [NSException exceptionWithName:MPTableViewUpdateException reason:_reason_ userInfo:nil];

#define MPTV_MAXCOUNT 7883507
#define MPTV_MAXSIZE 7883507.0

typedef struct _NSIndexPathStruct {
    NSInteger section, row;
} NSIndexPathStruct;

NS_INLINE NSIndexPath *
_NSIndexPathPrivateForRowSection(NSUInteger row, NSUInteger section) {
    NSUInteger indexes[2] = {section, row};
    return [[NSIndexPath alloc] initWithIndexes:indexes length:2];
}

typedef NS_ENUM(NSInteger, MPSectionViewType) {
    MPSectionHeader = NSIntegerMax - 64, MPSectionFooter = NSIntegerMax - 32
};

#define MPTV_IS_HEADER(_row_) ((_row_) == MPSectionHeader)
#define MPTV_IS_FOOTER(_row_) ((_row_) == MPSectionFooter)
#define MPTV_ROW_LESS(_row1_, _row2_) (((_row1_) == (_row2_)) ? NO : (MPTV_IS_HEADER(_row1_) ? YES : MPTV_IS_HEADER(_row2_) ? NO : (_row1_) < (_row2_)))
#define MPTV_ROW_MORE(_row1_, _row2_) (((_row1_) == (_row2_)) ? NO : (MPTV_IS_HEADER(_row1_) ? NO : MPTV_IS_HEADER(_row2_) ? YES : (_row1_) > (_row2_)))

typedef NS_ENUM(NSInteger, MPTableViewUpdateType) {
    MPTableViewUpdateDelete,
    MPTableViewUpdateInsert,
    MPTableViewUpdateReload,
    MPTableViewUpdateMoveOut,
    MPTableViewUpdateMoveIn,
    MPTableViewUpdateAdjust
};

#define MPTableViewUpdateTypeStable(_type_) (_type_ == MPTableViewUpdateInsert || _type_ == MPTableViewUpdateMoveIn)
#define MPTableViewUpdateTypeUnstable(_type_) (_type_ == MPTableViewUpdateDelete || _type_ == MPTableViewUpdateMoveOut || _type_ == MPTableViewUpdateReload)

#endif

#pragma mark -

@interface MPTableViewPosition : NSObject<NSCopying>
@property (nonatomic, assign) CGFloat startPos;
@property (nonatomic, assign) CGFloat endPos;
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
@property (nonatomic, assign) NSUInteger lastCount;
@property (nonatomic, assign) NSUInteger newCount;

- (BOOL)prepareAndIgnoreCheck:(BOOL)ignoreCheck; // For example, a section has 5 rows, it is unable to insert 5 after delete 0.

@end

#pragma mark -

@interface MPTableView (MPTableView_UpdatePrivate)

- (NSMutableArray *)_updateExecutionActions; // for insertion and movement

- (NSIndexPathStruct)_beginIndexPath;
- (NSIndexPathStruct)_endIndexPath;

- (CGFloat)_updateLastDeletionOriginY;
- (void)_setUpdateLastDeletionOriginY:(CGFloat)updateLastDeletionOriginY;
- (CGFloat)_updateLastInsertionOriginY;
- (void)_setUpdateLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY;

- (BOOL)_hasDragCell;

- (MPTableViewSection *)_updateGetSection:(NSInteger)section;

- (CGFloat)_updateGetInsertCellHeightAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)_updateGetMoveInCellOffsetAtIndexPath:(NSIndexPath *)indexPath fromLastIndexPath:(NSIndexPath *)lastIndexPath lastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;
- (CGFloat)_updateGetAdjustCellOffsetAtIndexPath:(NSIndexPath *)indexPath fromLastIndexPath:(NSIndexPath *)lastIndexPath withOffset:(CGFloat)cellOffset;
- (CGFloat)_updateGetHeaderHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement;
- (CGFloat)_updateGetFooterHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement;

- (CGFloat)_updateGetRebuildCellOffsetInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance;

- (BOOL)_updateNeedToDisplaySection:(MPTableViewSection *)section withUpdateType:(MPTableViewUpdateType)type withOffset:(CGFloat)offset;
- (BOOL)_updateNeedToAdjustCellsFromLastSection:(NSInteger)lastSection;
- (BOOL)_updateNecessaryToAdjustSection:(MPTableViewSection *)section withOffset:(CGFloat)offset;

// update cells
- (void)_updateDeleteCellInSection:(NSInteger)lastSection atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition;
- (void)_updateInsertCellToSection:(NSInteger)section atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition withLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY;

- (void)_updateMoveCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastIndexPath:(NSIndexPath *)lastIndexPath withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;

- (BOOL)_updateNeedToAdjustCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow;

- (void)_updateAdjustCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)cellOffset;

// update section views
- (void)_updateDeleteSectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection;
- (void)_updateInsertSectionViewToSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection withLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY;

- (void)_updateMoveSectionViewToSection:(NSInteger)section fromLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;

- (BOOL)_updateNeedToAdjustSectionViewInLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type;

- (void)_updateAdjustSectionViewFromSection:(NSInteger)lastSection toSection:(NSInteger)section withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withSectionOffset:(CGFloat)sectionOffset;

@end

#pragma mark -

@interface MPTableView (MPTableView_EstimatedPrivate)

// estimated mode layout
- (BOOL)_isEstimatedMode;
- (BOOL)_hasEstimatedHeightForRow;
- (BOOL)_hasEstimatedHeightForHeader;
- (BOOL)_hasEstimatedHeightForFooter;

- (BOOL)_hasDisplayedSection:(MPTableViewSection *)section;

- (BOOL)_estimatedNeedToDisplaySection:(MPTableViewSection *)section withOffset:(CGFloat)offset;

- (CGFloat)_estimatedGetSectionViewHeightWithType:(MPSectionViewType)type inSection:(MPTableViewSection *)section;

- (CGFloat)_estimatedDisplayCellInSection:(NSInteger)section atRow:(NSInteger)row withOffset:(CGFloat)cellOffset;

- (void)_estimatedDisplaySectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type;

@end

#pragma mark -

@interface MPTableViewUpdateManager : MPTableViewUpdateBase

@property (nonatomic, weak) NSMutableArray *sections;
@property (weak, readonly) MPTableView *tableView;

@property (nonatomic, assign) NSUInteger dragFromSection;
@property (nonatomic, assign) NSUInteger dragToSection; // for optimization

- (BOOL)hasUpdateNodes;

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView andSections:(NSMutableArray *)sections;
- (void)reset;

- (BOOL)addDeleteSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutSection:(NSUInteger)section;
- (BOOL)addMoveInSection:(NSUInteger)section withLastSection:(NSInteger)lastSection;

- (BOOL)addDeleteIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutIndexPath:(NSIndexPath *)indexPath;
- (BOOL)addMoveInIndexPath:(NSIndexPath *)indexPath withFrame:(CGRect)frame withLastIndexPath:(NSIndexPath *)lastIndexPath;

- (CGFloat)startUpdate;

@end

#pragma mark -

@interface MPTableViewUpdatePart : MPTableViewUpdateBase

- (BOOL)addDeleteRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutRow:(NSUInteger)row;
- (BOOL)addMoveInRow:(NSUInteger)row withFrame:(CGRect)frame withLastIndexPath:(NSIndexPath *)lastIndexPath;

@end

#pragma mark -

@interface MPTableViewEstimatedManager : NSObject

- (CGFloat)startEstimateForTableView:(MPTableView *)tableView atFirstIndexPath:(NSIndexPathStruct)firstIndexPath andSections:(NSMutableArray *)sections; // the firstIndexPath is not always be [tableView _beginIndexPath]

@end

#pragma mark -

@interface MPTableViewSection : MPTableViewPosition
@property (nonatomic, assign) NSUInteger section;
@property (nonatomic, assign) CGFloat headerHeight;
@property (nonatomic, assign) CGFloat footerHeight;
@property (nonatomic, assign) NSUInteger numberOfRows;

@property (nonatomic, strong) MPTableViewUpdatePart *updatePart;

@property (nonatomic, assign) CGFloat moveOutHeight; // backup for update

+ (instancetype)section;
- (void)reset;

- (void)addRowPosition:(CGFloat)position;
- (CGFloat)positionStartAtRow:(NSInteger)row;
- (CGFloat)heightAtRow:(NSInteger)row;
- (CGFloat)positionEndAtRow:(NSInteger)row;
- (NSInteger)rowAtContentOffsetY:(CGFloat)contentOffsetY;

- (void)makeOffset:(CGFloat)offset;

- (void)rebuildForTableView:(MPTableView *)tableView withLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance;

- (CGFloat)startUpdateUsingPartForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;
- (CGFloat)startUpdateForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;

- (CGFloat)startEstimateForTableView:(MPTableView *)tableView atFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;

@end
