//
//  MPTableViewSection.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"

#define MPTableViewMaxCount 7883507
#define MPTableViewMaxSize 7883507.0

#define MPTableViewUpdateTypeStable(_type_) (_type_ == MPTableViewUpdateInsert || _type_ == MPTableViewUpdateMoveIn)
#define MPTableViewUpdateTypeUnstable(_type_) (_type_ == MPTableViewUpdateDelete || _type_ == MPTableViewUpdateMoveOut || _type_ == MPTableViewUpdateReload)

UIKIT_EXTERN NSExceptionName const MPTableViewException;
UIKIT_EXTERN NSExceptionName const MPTableViewUpdateException;

#define MPTableViewThrowException(_reason_) @throw [NSException exceptionWithName:MPTableViewException reason:_reason_ userInfo:nil];
#define MPTableViewThrowUpdateException(_reason_) @throw [NSException exceptionWithName:MPTableViewUpdateException reason:_reason_ userInfo:nil];

#pragma mark -

@interface MPTableViewPosition : NSObject<NSCopying>
@property (nonatomic, assign) CGFloat startPos;
@property (nonatomic, assign) CGFloat endPos;
+ (instancetype)positionStart:(CGFloat)start toEnd:(CGFloat)end;

@end

#pragma mark -

typedef struct struct_MPIndexPath {
    NSInteger section, row;
} MPIndexPathStruct;

typedef NS_ENUM(NSInteger, MPSectionViewType) {
    MPSectionHeader = NSIntegerMin + 32, MPSectionFooter = NSIntegerMax - 32
};

typedef NS_ENUM(NSInteger, MPTableViewUpdateType) {
    MPTableViewUpdateDelete,
    MPTableViewUpdateInsert,
    MPTableViewUpdateReload,
    MPTableViewUpdateMoveOut,
    MPTableViewUpdateMoveIn,
    MPTableViewUpdateAdjust
};

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

- (MPIndexPathStruct)_beginIndexPath;
- (MPIndexPathStruct)_endIndexPath;

- (CGFloat)_updateLastDeletionOriginY;
- (void)_setUpdateLastDeletionOriginY:(CGFloat)updateLastDeletionOriginY;
- (CGFloat)_updateLastInsertionOriginY;
- (void)_setUpdateLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY;

- (BOOL)_hasDragCell;

- (MPTableViewSection *)_updateGetSection:(NSInteger)section;

- (CGFloat)_updateGetInsertCellHeightAtIndexPath:(MPIndexPath *)indexPath;
- (CGFloat)_updateGetMoveInCellOffsetAtIndexPath:(MPIndexPath *)indexPath fromLastIndexPath:(MPIndexPath *)lastIndexPath lastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;
- (CGFloat)_updateGetAdjustCellOffsetAtIndexPath:(MPIndexPath *)indexPath fromLastIndexPath:(MPIndexPath *)lastIndexPath withOffset:(CGFloat)cellOffset;
- (CGFloat)_updateGetHeaderHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement;
- (CGFloat)_updateGetFooterHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement;

- (CGFloat)_updateGetRebuildCellOffsetInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance;

- (BOOL)_updateNeedToDisplaySection:(MPTableViewSection *)section updateType:(MPTableViewUpdateType)type withOffset:(CGFloat)offset;
- (BOOL)_updateNeedToAdjustCellsFromLastSection:(NSInteger)lastSection;
- (BOOL)_updateNecessaryToAdjustSection:(MPTableViewSection *)section withOffset:(CGFloat)offset;

// update cells
- (void)_updateDeleteCellInSection:(NSInteger)lastSection atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition;
- (void)_updateInsertCellToSection:(NSInteger)section atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition withLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY;

- (void)_updateMoveCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastIndexPath:(MPIndexPath *)lastIndexPath withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance;

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

@property (nonatomic, assign) NSUInteger moveFromSection;
@property (nonatomic, assign) NSUInteger moveToSection; // for optimize

- (BOOL)hasUpdateNodes;

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView andSections:(NSMutableArray *)sections;
- (void)reset;

- (BOOL)addDeleteSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutSection:(NSUInteger)section;
- (BOOL)addMoveInSection:(NSUInteger)section withLastSection:(NSInteger)lastSection;

- (BOOL)addDeleteIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutIndexPath:(MPIndexPath *)indexPath;
- (BOOL)addMoveInIndexPath:(MPIndexPath *)indexPath withFrame:(CGRect)frame withLastIndexPath:(MPIndexPath *)lastIndexPath;

- (CGFloat)startUpdate;

@end

#pragma mark -

@interface MPTableViewUpdatePart : MPTableViewUpdateBase

- (BOOL)addDeleteRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutRow:(NSUInteger)row;
- (BOOL)addMoveInRow:(NSUInteger)row withFrame:(CGRect)frame withLastIndexPath:(MPIndexPath *)lastIndexPath;

@end

#pragma mark -

@interface MPTableViewEstimatedManager : NSObject

- (CGFloat)startEstimateForTableView:(MPTableView *)tableView atFirstIndexPath:(MPIndexPathStruct)firstIndexPath andSections:(NSMutableArray *)sections; // the firstIndexPath is not always be [tableView _beginIndexPath]

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

- (void)rebuildForTableView:(MPTableView *)tableView withLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance; // return a backup

- (CGFloat)startUpdateUsingPartForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;
- (CGFloat)startUpdateForTableView:(MPTableView *)tableView toNewSection:(NSInteger)newSection withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;

- (CGFloat)startEstimateForTableView:(MPTableView *)tableView atFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needToDisplay:(BOOL)needToDisplay;

@end
