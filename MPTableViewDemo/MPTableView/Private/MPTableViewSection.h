//
//  MPTableViewSection.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"

#define MPTableViewMaxCount 7883507
#define MPTableViewMaxSize 7883507.0f

typedef struct struct_MPIndexPath {
    NSInteger section, row;
} MPIndexPathStruct;

MPIndexPathStruct MPIndexPathStructMake(NSInteger section, NSInteger row) {
    MPIndexPathStruct result;
    result.section = section;
    result.row = row;
    return result;
}

FOUNDATION_EXTERN const MPIndexPathStruct MPIndexPathStructNotFound;

NS_INLINE BOOL MPEqualIndexPaths(MPIndexPathStruct indexPath1, MPIndexPathStruct indexPath2) {
    return indexPath1.section == indexPath2.section && indexPath2.row == indexPath1.row;
}

NSComparisonResult MPCompareIndexPath(MPIndexPathStruct first, MPIndexPathStruct second) {
    if (first.section > second.section) {
        return NSOrderedDescending;
    } else if (first.section < second.section) {
        return NSOrderedAscending;
    } else {
        if (first.row > second.row) {
            return NSOrderedDescending;
        } else if (first.row < second.row) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }
}

@interface MPTableViewPosition : NSObject<NSCopying>
@property (nonatomic, assign) CGFloat beginPos;
@property (nonatomic, assign) CGFloat endPos;
+ (instancetype)positionWithBegin:(CGFloat)begin toEnd:(CGFloat)end;

@end

#pragma mark -

typedef NS_ENUM(NSInteger, MPSectionType) {
    MPSectionTypeHeader = NSIntegerMin + 32, MPSectionTypeFooter = NSIntegerMax - 32
};

typedef NS_ENUM(NSInteger, MPTableViewUpdateType) {
    MPTableViewUpdateAdjust,
    MPTableViewUpdateDelete,
    MPTableViewUpdateInsert,
    MPTableViewUpdateReload,
    MPTableViewUpdateMoveIn,
    MPTableViewUpdateMoveOut
};

#define MPTableViewUpdateTypeStable(_type_) (_type_ == MPTableViewUpdateInsert || _type_ == MPTableViewUpdateMoveIn)
#define MPTableViewUpdateTypeUnstable(_type_) (_type_ == MPTableViewUpdateDelete || _type_ == MPTableViewUpdateMoveOut || _type_ == MPTableViewUpdateReload)

@class MPTableViewSection;

@interface MPTableViewUpdateBase : NSObject {
@package
    NSMutableIndexSet *_existingStableIndexs;
    NSMutableIndexSet *_existingUnstableIndexs;

    NSInteger _differ;
}
@property (nonatomic, assign) NSUInteger originCount;
@property (nonatomic, assign) NSUInteger newCount;

- (BOOL)formatNodesStable:(BOOL)countCheckIgnored; // For example, a section with 5 cells, it is unable to insert 5 after delete 0.

@end

#pragma mark -

@interface MPTableView (MPTableView_UpdatePrivate)

- (MPIndexPathStruct)__beginIndexPath;
- (MPIndexPathStruct)__endIndexPath;

- (BOOL)__isContentMoving;

- (MPTableViewSection *)__updateGetSectionAt:(NSInteger)section;

- (CGFloat)__updateGetCellHeightAtIndexPath:(MPIndexPath *)indexPath;

- (BOOL)__updateNeedToAnimateSection:(MPTableViewSection *)section updateType:(MPTableViewUpdateType)type andOffset:(CGFloat)offset;

//

- (void)__updateSection:(NSInteger)originSection deleteCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition;
- (void)__updateSection:(NSInteger)section insertCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition;

- (CGFloat)__updateSection:(NSInteger)section moveInCellAtIndex:(NSInteger)index fromOriginIndexPath:(MPIndexPath *)originIndexPath;

- (CGFloat)__updateSection:(NSInteger)section originSection:(NSInteger)originSection exchangeCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withOffset:(CGFloat)cellOffset;

- (void)__updateSection:(NSInteger)section originSection:(NSInteger)originSection exchangeCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex; // selectedIndexPaths change

//
- (void)__updateDeleteSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection;
- (void)__updateInsertSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection;

- (void)__updateMoveInSectionViewAtIndex:(NSInteger)index fromOriginIndex:(NSInteger)originIndex withType:(MPSectionType)type;

- (void)__updateExchangeSectionViewAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withType:(MPSectionType)type withSectionOffset:(CGFloat)sectionOffset;

//
- (BOOL)__isEstimatedMode;

- (CGFloat)__estimateCellAtSection:(NSInteger)section atIndex:(NSInteger)originIndex withOffset:(CGFloat)cellOffset;
- (void)__estimateSectionViewAtSection:(NSInteger)originIndex withType:(MPSectionType)type;

- (CGFloat)__estimatedHeaderHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection isInsertion:(BOOL)insertion;
- (CGFloat)__spec_estimatedHeaderHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection; // when a section has some rows update

- (CGFloat)__estimatedFooterHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection isInsertion:(BOOL)insertion;

- (CGFloat)__estimateRebuildCellAtSection:(NSInteger)section fromOriginSection:(NSInteger)originSection atIndex:(NSInteger)index;

@end

#pragma mark -

@interface MPTableViewEstimatedManager : NSObject

@property (nonatomic, weak) NSMutableArray *sections;
@property (nonatomic, weak) MPTableView *delegate;

- (CGFloat)startUpdate:(MPIndexPathStruct)firstIndexPath;

@end

#pragma mark -

@interface MPTableViewUpdateManager : MPTableViewUpdateBase

@property (nonatomic, weak) NSMutableArray *sections;
@property (weak, readonly) MPTableView *delegate;

@property (nonatomic, assign) NSUInteger moveFromSection;
@property (nonatomic, assign) NSUInteger moveToSection; // optimize

+ (MPTableViewUpdateManager *)managerWithDelegate:(MPTableView *)delegate andSections:(NSMutableArray *)sections;
- (void)resetManager;

- (BOOL)addMoveOutSection:(NSUInteger)section;
- (BOOL)addMoveInSection:(NSUInteger)section withOriginIndex:(NSInteger)originSection;

- (BOOL)addDeleteSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadSection:(NSUInteger)section withAnimation:(MPTableViewRowAnimation)animation;

- (BOOL)addMoveOutIndexPath:(MPIndexPath *)indexPath;
- (BOOL)addMoveInIndexPath:(MPIndexPath *)indexPath withHeight:(CGFloat)height withOriginIndexPath:(MPIndexPath *)originIndexPath;

- (BOOL)addDeleteIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadIndexPath:(MPIndexPath *)indexPath withAnimation:(MPTableViewRowAnimation)animation;

- (CGFloat)startUpdate;

@end

#pragma mark -

@interface MPTableViewUpdatePart : MPTableViewUpdateBase

- (BOOL)addMoveOutRow:(NSUInteger)row;
- (BOOL)addMoveInRow:(NSUInteger)row withHeight:(CGFloat)height withOriginIndexPath:(MPIndexPath *)originIndexPath;

- (BOOL)addDeleteRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addInsertRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;
- (BOOL)addReloadRow:(NSUInteger)row withAnimation:(MPTableViewRowAnimation)animation;

@end

#pragma mark -

@interface MPTableViewSection : MPTableViewPosition
@property (nonatomic, assign) NSUInteger section;
@property (nonatomic, assign) CGFloat headerHeight;
@property (nonatomic, assign) CGFloat footerHeight;
@property (nonatomic, assign) NSUInteger numberOfRows;

@property (nonatomic, strong) MPTableViewUpdatePart *updatePart;

@property (nonatomic, assign) CGFloat moveOutHeight;

+ (instancetype)section;
- (void)resetSection;

- (void)addRowWithPosition:(CGFloat)position;
- (CGFloat)rowPositionBeginAt:(NSInteger)index;
- (CGFloat)rowHeightAt:(NSInteger)index;
- (CGFloat)rowPositionEndAt:(NSInteger)index;
- (NSInteger)rowAtContentOffset:(CGFloat)contentOffset;

- (void)setPositionOffset:(CGFloat)offset;

- (void)estimatedRebuild:(MPTableView *)updateDelegate fromOriginSection:(NSInteger)originSection;

- (CGFloat)updateUsingPartWith:(MPTableView *)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback;
- (CGFloat)updateWith:(MPTableView *)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback;

- (CGFloat)updateEstimatedWith:(MPTableView *)updateDelegate beginIndex:(NSInteger)beginIndex withOffset:(CGFloat)offset needCallback:(BOOL)callback;

@end
