//
//  MPTableView.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewCell.h"

@class MPTableView;

@protocol MPTableViewDataSource <NSObject>
@required

- (NSUInteger)MPTableView:(MPTableView *)tableView numberOfRowsInSection:(NSUInteger)section;

- (MPTableViewCell *)MPTableView:(MPTableView *)tableView cellForRowAtIndexPath:(MPIndexPath *)indexPath;

@optional
- (NSUInteger)numberOfSectionsInMPTableView:(MPTableView *)tableView; // Default is 1 if not implemented

// Variable height support
- (CGFloat)MPTableView:(MPTableView *)tableView heightForRowAtIndexPath:(MPIndexPath *)indexPath;
- (CGFloat)MPTableView:(MPTableView *)tableView heightForHeaderInSection:(NSUInteger)section;
- (CGFloat)MPTableView:(MPTableView *)tableView heightForFooterInSection:(NSUInteger)section;

// Use the estimatedHeight methods to quickly calcuate guessed values which will allow for fast load times of the table.
// If these methods are implemented, the above -MPTableView:heightForXXX calls will be deferred until views are ready to be displayed, so more expensive logic can be placed there.

// There is no estimatedRowHeight、estimatedSectionHeaderHeight and estimatedSectionFooterHeight, because they can be modified at any time, and that will cause some trouble.

- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForRowAtIndexPath:(MPIndexPath *)indexPath;
- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForHeaderInSection:(NSUInteger)section;
- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForFooterInSection:(NSUInteger)section;

// custom view for header. will be adjusted to default or specified header height. Implementers should *always* try to reuse section views by setting each section view's reuseIdentifier and querying for available reusable views with dequeueReusableViewWithIdentifier:

- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForHeaderInSection:(NSUInteger)section;
- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForFooterInSection:(NSUInteger)section;

// Movement
- (BOOL)MPTableView:(MPTableView *)tableView canMoveRowAtIndexPath:(MPIndexPath *)indexPath;
- (BOOL)MPTableView:(MPTableView *)tableView canMoveRowToIndexPath:(MPIndexPath *)indexPath;

// If not implemented, touch any position of cell will make it begin to move. Default is [cell bounds].
- (CGRect)MPTableView:(MPTableView *)tableView rectForCellToMoveRowAtIndexPath:(MPIndexPath *)indexPath;

// Called when the dragging action is stopping.
- (void)MPTableView:(MPTableView *)tableView moveRowAtIndexPath:(MPIndexPath *)sourceIndexPath toIndexPath:(MPIndexPath *)destinationIndexPath;

@end

#pragma mark -

@protocol MPTableViewDelegate <UIScrollViewDelegate>
@optional

// Display customization

- (void)MPTableView:(MPTableView *)tableView willDisplayCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath;

- (void)MPTableView:(MPTableView *)tableView willDisplayHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section;
- (void)MPTableView:(MPTableView *)tableView willDisplayFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section;

// Customize animations for updating. a reload-update is composed of a delete and a insert function.

// Called when updating.
// The pathPosition is the origin.y of those animating views that in front of the current cell. In the MPTableViewRowAnimation, the pathPosition is the cell's starting position.
- (void)MPTableView:(MPTableView *)tableView beginToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition;

// The pathPosition in delete is a target position that views will move to. In the MPTableViewRowAnimation, the pathPosition is the cell's target position that make it looks like always follow the font one.

// ※※※※※※※※※※ WARNING: That deleted cell need to be manually removed. ※※※※※※※※※※
- (void)MPTableView:(MPTableView *)tableView beginToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition;

- (void)MPTableView:(MPTableView *)tableView beginToInsertHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView beginToInsertFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition;

- (void)MPTableView:(MPTableView *)tableView beginToDeleteHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView beginToDeleteFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition;

// Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
- (MPIndexPath *)MPTableView:(MPTableView *)tableView willSelectRowForCell:(MPTableViewCell *)cell atIndexPath:(MPIndexPath *)indexPath;
- (MPIndexPath *)MPTableView:(MPTableView *)tableView willDeselectRowAtIndexPath:(MPIndexPath *)indexPath;

// Called after the user changes the selection.

- (void)MPTableView:(MPTableView *)tableView didSelectRowForCell:(MPTableViewCell *)cell atIndexPath:(MPIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didDeselectRowAtIndexPath:(MPIndexPath *)indexPath;

// -MPTableView:shouldHighlightRowAtIndexPath: is called when a touch comes down on a row.
// Returning NO to that message halts the selection process and does not cause the currently selected row to lose its selected look while the touch is down.
- (BOOL)MPTableView:(MPTableView *)tableView shouldHighlightRowAtIndexPath:(MPIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didHighlightRowAtIndexPath:(MPIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didUnhighlightRowAtIndexPath:(MPIndexPath *)indexPath;

// Enter move mode
- (void)MPTableView:(MPTableView *)tableView shouldMoveRowAtIndexPath:(MPIndexPath *)sourceIndexPath;
// Called when the moving animation is completed.
- (void)MPTableView:(MPTableView *)tableView didEndMoveRowAtIndexPath:(MPIndexPath *)sourceIndexPath toIndexPath:(MPIndexPath *)destinationIndexPath;

@end

UIKIT_EXTERN NSString *const MPTableViewSelectionDidChangeNotification;

#pragma mark -

// this protocol can provide information about cells before they are displayed on screen.

@protocol MPTableViewDataSourcePrefetching <NSObject>

@required

// indexPaths are ordered ascending by geometric distance from the table view
- (void)MPTableView:(MPTableView *)tableView prefetchRowsAtIndexPaths:(NSArray *)indexPaths;

@optional

// indexPaths that previously were considered as candidates for pre-fetching, but were not actually used; may be a subset of the previous call to -MPTableView:prefetchRowsAtIndexPaths:
- (void)MPTableView:(MPTableView *)tableView cancelPrefetchingForRowsAtIndexPaths:(NSArray *)indexPaths;

@end

#pragma mark -

typedef NS_ENUM(NSInteger, MPTableViewStyle) {
    MPTableViewStylePlain, MPTableViewStyleGrouped
};

typedef NS_ENUM(NSInteger, MPTableViewScrollPosition) {
    MPTableViewScrollPositionNone,
    MPTableViewScrollPositionTop,
    MPTableViewScrollPositionMiddle,
    MPTableViewScrollPositionBottom
};

// top, bottom and middle should set cell(section header/footer)'s height to 0. So if the property rowAnimationOptions has been changed, we had better not put the layout codes in -(void)layoutSubviews.

typedef NS_ENUM(NSInteger, MPTableViewRowAnimation) {
    MPTableViewRowAnimationFade,
    MPTableViewRowAnimationRight, // slide in from right (or out to right)
    MPTableViewRowAnimationLeft,
    MPTableViewRowAnimationTop, // views will initialize in the positions of those views in front of them, just like UITableViewRowAnimationTop
    MPTableViewRowAnimationBottom,
    MPTableViewRowAnimationMiddle,
    MPTableViewRowAnimationNone,
    MPTableViewRowAnimationCustom,
    MPTableViewRowAnimationRandom = 100
};

@interface MPTableView : UIScrollView

- (instancetype)initWithFrame:(CGRect)frame style:(MPTableViewStyle)style NS_DESIGNATED_INITIALIZER;// must specify style at creation. -initWithFrame: calls this with MPTableViewStylePlain

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) MPTableViewStyle style;
@property (nonatomic, weak) id<MPTableViewDataSource> dataSource;
@property (nonatomic, weak) id<MPTableViewDelegate> delegate;
@property (nonatomic, weak) id<MPTableViewDataSourcePrefetching> prefetchDataSource;

@property (nonatomic) CGFloat rowHeight; // will return the default value if unset
@property (nonatomic) CGFloat sectionHeaderHeight;
@property (nonatomic) CGFloat sectionFooterHeight;

- (NSUInteger)numberOfSections;
- (NSUInteger)numberOfRowsInSection:(NSUInteger)section;

@property (nonatomic, readonly) MPIndexPath *beginIndexPath; // if there are not cells displayed, row will be NSNotFound
@property (nonatomic, readonly) MPIndexPath *endIndexPath;

- (CGRect)rectForSection:(NSUInteger)section; // includes header, footer and all rows, return CGRectNull if section is not found
- (CGRect)rectForHeaderInSection:(NSUInteger)section;
- (CGRect)rectForFooterInSection:(NSUInteger)section;
- (CGRect)rectForRowAtIndexPath:(MPIndexPath *)indexPath;

- (MPIndexPath *)indexPathForRowAtPoint:(CGPoint)point; // returns nil if point is outside of any row in the table
- (NSUInteger)indexForSectionAtPoint:(CGPoint)point; // returns NSNotFound if point is outside of any section in the table

- (MPTableViewCell *)cellForRowAtIndexPath:(MPIndexPath *)indexPath;
- (MPTableReusableView *)sectionHeaderInSection:(NSUInteger)section;
- (MPTableReusableView *)sectionFooterInSection:(NSUInteger)section;

- (MPIndexPath *)indexPathForCell:(MPTableViewCell *)cell; // returns nil if cell is not visible

- (NSArray *)visibleCells;

- (NSArray *)visibleCellsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForVisibleRows;

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForRowsInSection:(NSUInteger)section;

@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) UIView *tableFooterView;

@property (nonatomic, strong) UIView *backgroundView; // will be placed as a subview of the table view behind all cells and headers/footers.

@property (nonatomic, getter=isCachesReloadEnabled) BOOL cachesReloadEnabled; // default is YES, when reloading the table view, without clear reusable views and cache all displayed views to reuse(It is best to make sure that table view will reload with the same cell/reusable class objects);

 // Sometimes we frequently make table view updating, that may produce many caches(reusable views) and you can not make the most of them.
- (void)clearReusableCells;
- (void)clearReusableSectionViews;

- (void)reloadData;
- (void)reloadDataAsyncWithCompletion:(void (^)(void))completion; // reload data asynchronously. In this process, the table view will work as usual. Allows working in a async thread

@property (nonatomic) BOOL allowsSelection;  // default is YES.
@property (nonatomic) BOOL allowsMultipleSelection; // default is NO.

@property (nonatomic, readonly) MPIndexPath *indexPathForSelectedRow; // returns nil or index path representing section and row of selection.
@property (nonatomic, readonly) NSArray *indexPathsForSelectedRows; // returns nil or a set of index paths representing the sections and rows of the selection.

- (void)scrollToRowAtIndexPath:(MPIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // scroll to a selected row which closest to the top

- (void)scrollToHeaderAtSection:(NSUInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // just like scrollToRowAtIndexPath:atScrollPosition:animated:
- (void)scrollToFooterAtSection:(NSUInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;

- (void)selectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition;

- (void)deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated;

@property (nonatomic, getter=isUpdateForceReload) BOOL updateForceReload; // default is YES. If NO, table view will not reload data(mainly is height info) from data source for those off-screen views when updating, that will get better performance. If the updates will make contentOffset change, then you should set updateForceReload to YES.

@property (nonatomic) BOOL updateLayoutSubviewsOptionEnabled; // default is YES, table view will use UIViewAnimationOptionLayoutSubviews as an option in animations of updating. If not, the animation effects may look unnatural when you using Autolayout and default table view animations.

- (BOOL)isUpdating; // update animating

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion; // allow multiple insert/delete/reload/move of rows and sections to be animated simultaneously. Nestable

/**
 similar to -performBatchUpdates:completion:, more animation options have been provided
 */
- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options completion:(void (^)(BOOL finished))completion;

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options completion:(void (^)(BOOL finished))completion;

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveSection:(NSUInteger)section toSection:(NSUInteger)newSection;

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveRowAtIndexPath:(MPIndexPath *)indexPath toIndexPath:(MPIndexPath *)newIndexPath;

@property (nonatomic, getter=isMoveModeEnabled) BOOL moveModeEnabled; // default is NO.
@property (nonatomic) CFTimeInterval minimumPressDurationForMovement; // default is 0.1.
@property (nonatomic, assign) BOOL allowsDragCellOut; // default is NO.
@property (nonatomic) BOOL allowsSelectionDuringMoving;                                 // default is NO. Controls whether rows can be selected when in moving mode
- (MPIndexPath *)movingIndexPath; // default is nil.

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier;
// like dequeueReusableCellWithIdentifier:, but for headers/footers
- (id)dequeueReusableViewWithIdentifier:(NSString *)identifier;

- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)identifier;
- (void)registerClass:(Class)reusableViewClass forReusableViewReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forReusableViewReuseIdentifier:(NSString *)identifier;

@end

#pragma mark -

@interface MPIndexPath (MPTableView)

- (NSInteger)section;
- (NSInteger)row;
+ (MPIndexPath *)indexPathForRow:(NSInteger)row inSection:(NSInteger)section;
- (NSComparisonResult)compareRowSection:(MPIndexPath *)indexPath;

@end
