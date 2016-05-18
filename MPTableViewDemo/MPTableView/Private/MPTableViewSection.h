//
//  MPTableViewSection.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"

@interface MPTableViewPosition : NSObject<NSCopying>
@property (nonatomic, assign) CGFloat beginPos;
@property (nonatomic, assign) CGFloat endPos;
+ (instancetype)positionWithBegin:(CGFloat)begin toEnd:(CGFloat)end;

@end

#pragma mark -
typedef NS_ENUM (NSInteger, MPSectionType) {
    MPSectionTypeHeader = NSIntegerMin + 32, MPSectionTypeFooter = NSIntegerMax - 32
};

typedef NS_ENUM (NSInteger, MPTableViewUpdateType) {
    MPTableViewUpdateAdjust,
    MPTableViewUpdateDelete,
    MPTableViewUpdateInsert,
    MPTableViewUpdateReload,
    MPTableViewUpdateMoveIn,
    MPTableViewUpdateMoveOut
};

#define MPTableViewUpdateTypeStable(_type_) (_type_ == MPTableViewUpdateMoveIn || _type_ == MPTableViewUpdateInsert)
#define MPTableViewUpdateTypeUnstable(_type_) (_type_ == MPTableViewUpdateMoveOut || _type_ == MPTableViewUpdateDelete || _type_ == MPTableViewUpdateReload)

@class MPTableViewSection;

@interface MPTableViewUpdateBase : NSObject {
@package
    NSMutableIndexSet *_existingStableIndexs;
    NSMutableIndexSet *_existingUnstableIndexs;

    NSInteger _differ;
}
@property (nonatomic, assign) NSUInteger originCount;
@property (nonatomic, assign) NSUInteger newCount;

- (BOOL)formatNodesStable; // For example, a section with 5 cells, it is unable to insert 5 after delete 0 and 1

@end

#pragma mark -

@protocol MPTableViewUpdateDelegate
@required

- (MPTableViewSection *)updateMakeSectionAt:(NSInteger)section;
- (CGFloat)updateSection:(NSInteger)section cellHeightAtIndex:(NSInteger)index;

- (BOOL)updateNeedToAnimateSection:(MPTableViewSection *)section updateType:(MPTableViewUpdateType)type andOffset:(CGFloat)offset;

//

- (void)updateSection:(NSInteger)originSection deleteCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition;
- (void)updateSection:(NSInteger)section insertCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition;

- (void)updateSection:(NSInteger)section moveInCellAtIndex:(NSInteger)index fromOriginIndexPath:(MPIndexPath *)originIndexPath;

- (void)updateSection:(NSInteger)section originSection:(NSInteger)originSection exchangeCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withOffset:(CGFloat)cellOffset;

- (void)updateSection:(NSInteger)section originSection:(NSInteger)originSection exchangeCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex; // selectedIndexPaths change

//
- (void)updateDeleteSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection;
- (void)updateInsertSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection;

- (void)updateMoveInSectionViewAtIndex:(NSInteger)index fromOriginIndex:(NSInteger)originIndex withType:(MPSectionType)type;

- (void)updateExchangeSectionViewAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withType:(MPSectionType)type withSectionOffset:(CGFloat)sectionOffset;

@end

#pragma mark -

@interface MPTableViewUpdateManager : MPTableViewUpdateBase

@property (nonatomic, weak) NSMutableArray *sections;
@property (weak, readonly) MPTableView<MPTableViewUpdateDelegate> *delegate;
@property (nonatomic) BOOL isUpdating;

+ (MPTableViewUpdateManager *)managerWithDelegate:(MPTableView<MPTableViewUpdateDelegate> *)delegate andSections:(NSMutableArray *)sections;
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

@property (nonatomic, weak) MPTableViewUpdatePart *updatePart;

+ (instancetype)section;
- (void)resetSection;

- (void)addRowWithPosition:(CGFloat)position;
- (CGFloat)rowPositionBeginAt:(NSInteger)index;
- (CGFloat)rowHeightAt:(NSInteger)index;
- (CGFloat)rowPositionEndAt:(NSInteger)index;
- (NSInteger)rowAtContentOffset:(CGFloat)contentOffset;

- (void)setPositionOffset:(CGFloat)offset;

- (CGFloat)updateUsingPartWith:(id<MPTableViewUpdateDelegate>)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback;
- (void)updateWith:(id<MPTableViewUpdateDelegate>)updateDelegate toSection:(NSInteger)newSection withOffset:(CGFloat)offset needCallback:(BOOL)callback;

@end
