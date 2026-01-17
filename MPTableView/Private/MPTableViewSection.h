//
//  MPTableViewSection.h
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015 PBA. All rights reserved.
//

#import "MPTableView.h"

#ifndef _MPTV_DEFINE_
#define _MPTV_DEFINE_

#define MPTV_IS_HEADER(_row_) ((_row_) == MPTableViewSectionHeader)
#define MPTV_IS_FOOTER(_row_) ((_row_) == MPTableViewSectionFooter)
#define MPTV_ROW_LESS(_row1_, _row2_) (((_row1_) == (_row2_)) ? NO : (MPTV_IS_HEADER(_row1_) ? YES : MPTV_IS_HEADER(_row2_) ? NO : ((NSUInteger)_row1_) < ((NSUInteger)_row2_)))
#define MPTV_ROW_MORE(_row1_, _row2_) (((_row1_) == (_row2_)) ? NO : (MPTV_IS_HEADER(_row1_) ? NO : MPTV_IS_HEADER(_row2_) ? YES : ((NSUInteger)_row1_) > ((NSUInteger)_row2_)))

#define MPTV_IS_STABLE_UPDATE_TYPE(_type_) ((_type_) == MPTableViewUpdateInsert || (_type_) == MPTableViewUpdateMoveIn)
#define MPTV_IS_UNSTABLE_UPDATE_TYPE(_type_) ((_type_) == MPTableViewUpdateDelete || (_type_) == MPTableViewUpdateMoveOut || (_type_) == MPTableViewUpdateReload)

#define MPTV_THROW_EXCEPTION(_reason_) @throw [NSException exceptionWithName:NSGenericException reason:(_reason_) userInfo:nil]

#endif

#pragma mark -

typedef NS_ENUM(NSInteger, MPTableViewSectionViewType) {
    MPTableViewSectionHeader = NSIntegerMin + 32, MPTableViewSectionFooter = NSIntegerMin + 64
};

typedef NS_ENUM(NSInteger, MPTableViewUpdateType) {
    MPTableViewUpdateDelete,
    MPTableViewUpdateInsert,
    MPTableViewUpdateReload,
    MPTableViewUpdateMoveOut,
    MPTableViewUpdateMoveIn,
    MPTableViewUpdateRelayout
};

static const CGFloat MPTableViewSentinelFloatValue = -87853507.0;

#pragma mark -

@interface MPTableViewPosition : NSObject<NSCopying>

@property (nonatomic) CGFloat start;
@property (nonatomic) CGFloat end;

+ (instancetype)positionWithStart:(CGFloat)start end:(CGFloat)end;

@end

#pragma mark -

@class MPTableViewSection;

@interface MPTableViewUpdateBase : NSObject {
    @package
    NSMutableIndexSet *_stableIndexes;
    NSMutableIndexSet *_unstableIndexes;
    
    NSInteger _delta;
}

@property (nonatomic) NSInteger previousCount;
@property (nonatomic) NSInteger newCount;

- (BOOL)prepareForUpdateWithCheck:(BOOL)needsCheck; // e.g. a section has 5 rows, deleting row 0 makes it invalid to insert row 5.

- (void)clearNodes;

@end

#pragma mark -

@interface MPTableView (MPTableViewUpdate)

- (BOOL)_hasDraggingCell;

- (MPTableViewSection *)_buildSectionForIndex:(NSInteger)section;

- (NSMutableArray *)_updateExecutionActions;

- (CGFloat)_getProposedDeletedPositionY;
- (void)_setProposedDeletedPositionY:(CGFloat)proposedDeletedPositionY;
- (CGFloat)_getProposedInsertedLocationY;
- (void)_setProposedInsertedLocationY:(CGFloat)proposedInsertedLocationY;

- (CGFloat)_cellHeightForInsertionInSection:(NSInteger)section row:(NSInteger)row;
- (CGFloat)_cellHeightDeltaForMoveInToSection:(NSInteger)section row:(NSInteger)row fromPreviousIndexPath:(NSIndexPath *)previousIndexPath previousHeight:(CGFloat)previousHeight withShift:(CGFloat)shift;
- (CGFloat)_cellHeightDeltaForRelayoutInSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow withOffset:(CGFloat)offset shouldLoadHeight:(BOOL *)shouldLoadHeight;
- (CGFloat)_computedHeaderHeightAtSection:(MPTableViewSection *)section fromPreviousSection:(NSInteger)previousSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion;
- (CGFloat)_computedFooterHeightAtSection:(MPTableViewSection *)section fromPreviousSection:(NSInteger)previousSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion;

- (CGFloat)_cellHeightDeltaForCalculatedCellInSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection withShift:(CGFloat)shift shouldLoadHeight:(BOOL *)shouldLoadHeight;

- (BOOL)_needsDisplayAtSection:(MPTableViewSection *)section withUpdateType:(MPTableViewUpdateType)type withOffset:(CGFloat)offset;
- (BOOL)_hasRelevantCellsInPreviousSection:(NSInteger)previousSection;
- (BOOL)_needsDisplayAtSection:(MPTableViewSection *)section forRelayoutWithOffset:(CGFloat)offset;

- (BOOL)_needsRelayoutRelevantCellInSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow;
- (BOOL)_hasAnimatingSectionViewInPreviousSection:(NSInteger)previousSection viewType:(MPTableViewSectionViewType)type;

- (void)_deleteCellInSection:(NSInteger)previousSection row:(NSInteger)row animation:(MPTableViewRowAnimation)animation sectionPosition:(MPTableViewSection *)sectionPosition;
- (void)_insertCellInSection:(NSInteger)section row:(NSInteger)row animation:(MPTableViewRowAnimation)animation sectionPosition:(MPTableViewSection *)sectionPosition proposedInsertedLocationY:(CGFloat)proposedInsertedLocationY;
- (void)_moveCellToSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow previousHeight:(CGFloat)previousHeight withShift:(CGFloat)shift;
- (void)_relayoutCellToSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow previousHeight:(CGFloat)previousHeight withOffset:(CGFloat)offset;

- (void)_deleteSectionViewInSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type animation:(MPTableViewRowAnimation)animation deletedSection:(MPTableViewSection *)deletedSection;
- (void)_insertSectionViewInSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type animation:(MPTableViewRowAnimation)animation insertedSection:(MPTableViewSection *)insertedSection proposedInsertedLocationY:(CGFloat)proposedInsertedLocationY;
- (void)_moveSectionViewToSection:(NSInteger)section previousSection:(NSInteger)previousSection viewType:(MPTableViewSectionViewType)type previousHeight:(CGFloat)previousHeight withShift:(CGFloat)shift;
- (void)_relayoutSectionViewToSection:(NSInteger)section previousSection:(NSInteger)previousSection viewType:(MPTableViewSectionViewType)type previousHeight:(CGFloat)previousHeight withOffset:(CGFloat)offset;

@end

#pragma mark -

@interface MPTableViewUpdateManager : MPTableViewUpdateBase

@property (nonatomic, weak, readonly) MPTableView *tableView;
@property (nonatomic, weak) NSMutableArray *sectionArray;

@property (nonatomic, strong) NSMutableArray *transactions;

@property (nonatomic) NSInteger dragSourceSection;
@property (nonatomic) NSInteger dragDestinationSection;

+ (MPTableViewUpdateManager *)managerForTableView:(MPTableView *)tableView sectionArray:(NSMutableArray *)sectionArray;
- (void)reset;
- (BOOL)hasUpdateNodes;

- (BOOL)addDeleteSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadSection:(NSInteger)section withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutSection:(NSInteger)section;
- (BOOL)addMoveInSection:(NSInteger)section previousSection:(NSInteger)previousSection;

- (BOOL)addDeleteIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadIndexPath:(NSIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutIndexPath:(NSIndexPath *)indexPath;
- (BOOL)addMoveInIndexPath:(NSIndexPath *)indexPath previousIndexPath:(NSIndexPath *)previousIndexPath previousFrame:(CGRect)previousFrame;

- (CGFloat)update;

@end

#pragma mark -

@interface MPTableViewUpdatePart : MPTableViewUpdateBase

- (BOOL)addDeleteRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutRow:(NSInteger)row;
- (BOOL)addMoveInRow:(NSInteger)row previousIndexPath:(NSIndexPath *)previousIndexPath previousFrame:(CGRect)previousFrame;

@end

#pragma mark -

@interface MPTableView (MPTableViewEstimate)

- (BOOL)_isEstimatedMode;
- (BOOL)_needsEstimateHeightForRow;
- (BOOL)_needsEstimateHeightForHeader;
- (BOOL)_needsEstimateHeightForFooter;

- (BOOL)_hasDisplayedViewAtSection:(MPTableViewSection *)section;

- (CGFloat)_computedHeaderHeightDuringEstimateAtSection:(MPTableViewSection *)section;
- (CGFloat)_computedFooterHeightDuringEstimateAtSection:(MPTableViewSection *)section;
- (CGFloat)_displayCellDuringEstimateInSection:(NSInteger)section row:(NSInteger)row withOffset:(CGFloat)offset shouldLoadHeight:(BOOL *)shouldLoadHeight;
- (void)_displaySectionViewDuringEstimateInSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type;

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
- (NSInteger)rowForContentOffsetY:(CGFloat)contentOffsetY; // includes header and footer

- (void)makePositionOffset:(CGFloat)offset;

- (CGFloat)updateWithPartForTableView:(MPTableView *)tableView toSection:(NSInteger)newSection withOffset:(CGFloat)offset needsDisplay:(BOOL)needsDisplay;
- (CGFloat)updateForTableView:(MPTableView *)tableView toSection:(NSInteger)newSection withOffset:(CGFloat)offset needsDisplay:(BOOL)needsDisplay;

- (void)rebuildForTableView:(MPTableView *)tableView fromPreviousSection:(NSInteger)previousSection withShift:(CGFloat)shift isInsertion:(BOOL)isInsertion;

- (CGFloat)applyHeightsDuringEstimateForTableView:(MPTableView *)tableView fromFirstRow:(NSInteger)firstRow withOffset:(CGFloat)offset needsDisplay:(BOOL)needsDisplay;

@end
