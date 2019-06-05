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
- (NSUInteger)numberOfSectionsInMPTableView:(MPTableView *)tableView;

// Variable height support
- (CGFloat)MPTableView:(MPTableView *)tableView heightForRowAtIndexPath:(MPIndexPath *)indexPath;
- (CGFloat)MPTableView:(MPTableView *)tableView heightForHeaderInSection:(NSUInteger)section;
- (CGFloat)MPTableView:(MPTableView *)tableView heightForFooterInSection:(NSUInteger)section;

// Use the estimatedHeight methods to quickly calcuate guessed values which will allow for fast load times of the table.
// If these methods are implemented, the above -MPTableView:heightForXXX calls will be deferred until views are ready to be displayed, so more expensive logic can be placed there.

// MPTableView has no estimatedRowHeight、estimatedSectionHeaderHeight and estimatedSectionFooterHeight, because these properties can be modified at any time, and that may cause some trouble.

- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForRowAtIndexPath:(MPIndexPath *)indexPath;
- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForHeaderInSection:(NSUInteger)section;
- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForFooterInSection:(NSUInteger)section;

// Custom view for header. Will be adjusted to default or specified header height. Implementers should *always* try to reuse section views by setting each section view's reuseIdentifier and querying for available reusable views with -dequeueReusableViewWithIdentifier:

- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForHeaderInSection:(NSUInteger)section;
- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForFooterInSection:(NSUInteger)section;

// Drag mode
// Like -tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath: in the UITableView
- (BOOL)MPTableView:(MPTableView *)tableView canMoveRowAtIndexPath:(MPIndexPath *)indexPath;
- (BOOL)MPTableView:(MPTableView *)tableView canMoveRowToIndexPath:(MPIndexPath *)indexPath;

// If not implemented, the rect is [cell bounds], means that touch any position in cell will make it begin to drag.
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

// Customize animations for table view update. A reload is composed of a delete and a insert function.
// Called when table view is updating.

// The lastInsertionOriginY is the origin.y of those animating views which in front of the insert cell. For those built-in animation types, the lastInsertionOriginY is the cell's start position.
// ※※※※※※※※※※ If the table view should be scrolled during the update, we had better put the insertion functions in a performBatchUpdates, that will stop these cells (and section views) into the reusable queue and keep our custom animations uninterrupted. ※※※※※※※※※※
- (void)MPTableView:(MPTableView *)tableView beginToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withLastInsertionOriginY:(CGFloat)lastInsertionOriginY;

// The lastDeletionOriginY in delete functions is a target position that deleted views will move to. For those built-in animation types, the lastDeletionOriginY is a cell's target position that make it looks like always follow the font one.
// ※※※※※※※※※※ WARNING: These deleted views need to be manually removed. ※※※※※※※※※※
- (void)MPTableView:(MPTableView *)tableView beginToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withLastDeletionOriginY:(CGFloat)lastDeletionOriginY;

- (void)MPTableView:(MPTableView *)tableView beginToInsertHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastInsertionOriginY:(CGFloat)lastInsertionOriginY;
- (void)MPTableView:(MPTableView *)tableView beginToInsertFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastInsertionOriginY:(CGFloat)lastInsertionOriginY;

- (void)MPTableView:(MPTableView *)tableView beginToDeleteHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastDeletionOriginY:(CGFloat)lastDeletionOriginY;
- (void)MPTableView:(MPTableView *)tableView beginToDeleteFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastDeletionOriginY:(CGFloat)lastDeletionOriginY;

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

// Called before table view enter drag mode
- (void)MPTableView:(MPTableView *)tableView shouldMoveRowAtIndexPath:(MPIndexPath *)sourceIndexPath;
// Called when the dragging action is finished.
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

// Animation top, bottom and middle should change subview's height to 0. So if you use these three animation types, you had better put the layout codes in -setFrame: instead of -layoutSubviews for cells and section views.

typedef NS_ENUM(NSInteger, MPTableViewRowAnimation) {
    MPTableViewRowAnimationFade,
    MPTableViewRowAnimationRight, // slide in from right (or out to right)
    MPTableViewRowAnimationLeft,
    MPTableViewRowAnimationTop,
    MPTableViewRowAnimationBottom,
    MPTableViewRowAnimationMiddle,
    MPTableViewRowAnimationNone,
    MPTableViewRowAnimationCustom, // require to use those protocol functions of MPTableViewDelegate to customize cells and section views animations
    MPTableViewRowAnimationRandom = 100
};

@interface MPTableView : UIScrollView

- (instancetype)initWithFrame:(CGRect)frame style:(MPTableViewStyle)style NS_DESIGNATED_INITIALIZER; // must specify style at creation. -initWithFrame: calls this with MPTableViewStylePlain.

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) MPTableViewStyle style;
@property (nonatomic, weak) id<MPTableViewDataSource> dataSource;
@property (nonatomic, weak) id<MPTableViewDelegate> delegate;
@property (nonatomic, weak) id<MPTableViewDataSourcePrefetching> prefetchDataSource;

@property (nonatomic) CGFloat rowHeight; // default is MPTableViewDefaultCellHeight
@property (nonatomic) CGFloat sectionHeaderHeight; // default value is 0 if style is MPTableViewStylePlain, or it will be 35.
@property (nonatomic) CGFloat sectionFooterHeight;

- (NSUInteger)numberOfSections;
- (NSUInteger)numberOfRowsInSection:(NSUInteger)section;

@property (nonatomic, readonly) MPIndexPath *beginIndexPath; // if the first is a section view, the row will be NSNotFound.
@property (nonatomic, readonly) MPIndexPath *endIndexPath;

- (CGRect)rectForSection:(NSUInteger)section; // includes header, footer and all rows, return CGRectNull if section is not found.
- (CGRect)rectForHeaderInSection:(NSUInteger)section;
- (CGRect)rectForFooterInSection:(NSUInteger)section;
- (CGRect)rectForRowAtIndexPath:(MPIndexPath *)indexPath;

- (NSUInteger)indexForSectionAtPoint:(CGPoint)point; // returns NSNotFound if point is outside of any section in the table view
- (NSUInteger)indexForSectionHeaderAtPoint:(CGPoint)point; // returns NSNotFound if point is outside of any section header in the table view
- (NSUInteger)indexForSectionFooterAtPoint:(CGPoint)point;
- (MPIndexPath *)indexPathForRowAtPoint:(CGPoint)point; // returns nil if point is outside of any row in the table view

- (MPTableReusableView *)sectionHeaderInSection:(NSUInteger)section;
- (MPTableReusableView *)sectionFooterInSection:(NSUInteger)section;
- (MPTableViewCell *)cellForRowAtIndexPath:(MPIndexPath *)indexPath; // returns nil if cell is not visible or index path is out of range

- (MPIndexPath *)indexPathForCell:(MPTableViewCell *)cell; // returns nil if cell is not visible

- (NSArray *)visibleCells;

- (NSArray *)visibleCellsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForVisibleRows;

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForRowsInSection:(NSUInteger)section;

@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) UIView *tableFooterView;

@property (nonatomic, strong) UIView *backgroundView; // will be placed as a subview of the table view behind all cells and headers/footers

@property (nonatomic, getter=isCachesReloadEnabled) BOOL cachesReloadEnabled; // default is YES. When the table view is reloading, it will not clear those reusable views and cache all of them. But if you make sure that the table view will reload with the different kind of cells/reusable views, you should set it to NO.

- (void)reloadData;

/**
 Reload data asynchronously. In this process, the table view will work as usual, and the protocol functions of its data source will be invoked asynchronously. Allow to work in a async thread.
 */
- (void)reloadDataAsyncWithCompletion:(void (^)(void))completion;

@property (nonatomic) BOOL allowsSelection;  // default is YES
@property (nonatomic) BOOL allowsMultipleSelection; // default is NO

@property (nonatomic, readonly) MPIndexPath *indexPathForSelectedRow; // returns nil or index path representing section and row of selection
@property (nonatomic, readonly) NSArray *indexPathsForSelectedRows; // returns nil or a set of index paths representing the sections and rows of the selection

- (void)scrollToRowAtIndexPath:(MPIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // scroll to a selected row which closest to the top

- (void)scrollToHeaderInSection:(NSUInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // like scrollToRowAtIndexPath:atScrollPosition:animated:, just for section header
- (void)scrollToFooterInSection:(NSUInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;

- (void)selectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition;

- (void)deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated;

/**
 Default is YES.
 If NO, table view will not reload the heights info from data source for those off-screen views when it is updating.
 So if you can confirm that do not need to change all cells heights when table view is updating (In fact, we usually don't change cells heights in an update), then you should set it to NO to get best performance.
 
 But if you can't, and the updates will make contentOffset change, then you should set it to YES.
 */
@property (nonatomic, getter=isUpdateForceReload) BOOL updateForceReload;

/**
 Default is NO.
 By default, table view will create some subviews(cells and section views) to display update animations, even though most of subviews are outside the screen, or in other words these subviews have not be added to table view before update and they will be hidden when update is finished.
 That is good for animation effect but should make many subviews to join reusable queues, then we must release them manually (call -clearReusableCellsAndViews).
 
 If YES, table view will not create this kind of subviews when it is updating, that will improve performance. But table view still may create too many reusable subviews if updateForceReload is YES and we start too many updates at the same time in the estimated-height mode.
 */
@property (nonatomic, getter=isUpdateOptimizeViews) BOOL updateOptimizeViews;

// Sometimes we frequently update table view (use those update APIs but not reloadData), that may produce many caches (reusable views) and table view can not make the most of them.
- (NSArray *)identifiersForReusableCells;
- (NSArray *)identifiersForReusableViews;

- (NSUInteger)numberOfReusableCellsWithIdentifier:(NSString *)identifier;
- (NSUInteger)numberOfReusableViewsWithIdentifier:(NSString *)identifier;

- (void)clearReusableCellsInCount:(NSUInteger)count withIdentifier:(NSString *)identifier;
- (void)clearReusableViewsInCount:(NSUInteger)count withIdentifier:(NSString *)identifier;
- (void)clearReusableCellsAndViews;

@property (nonatomic) BOOL updateLayoutSubviewsOptionEnabled; // default is YES, table view will use the UIViewAnimationOptionLayoutSubviews as an option in update animations. If NO, the animation effects may look unnatural when you using the Autolayout and those built-in table view animations.

@property (nonatomic) BOOL updateAllowUserInteraction; // default is YES, table view can be scrolled when it is updating (use the UIViewAnimationOptionAllowUserInteraction for update animations), and all subviews can be selected, or you can turn it off and set the userInteractionEnabled of those animated cells to NO.

- (BOOL)isUpdating;

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion; // allow multiple insert/delete/reload/move of rows and sections to be animated simultaneously. Nestable.

/**
 Similar to -performBatchUpdates:completion: , provide more animation options.
 */
- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(void (^)(BOOL finished))completion;

/**
 Similar to -performBatchUpdates:completion: , provide many animation options.
 */
- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options completion:(void (^)(BOOL finished))completion;

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveSection:(NSUInteger)section toSection:(NSUInteger)newSection;

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveRowAtIndexPath:(MPIndexPath *)indexPath toIndexPath:(MPIndexPath *)newIndexPath;

@property (nonatomic, getter=isDragModeEnabled) BOOL dragModeEnabled; // default is NO. If enable it, use the protocol functions of MPTableViewDataSource and MPTableViewDelegate to control and track the drag state of cells.
@property (nonatomic) CFTimeInterval minimumPressDurationForDrag; // default is 0.1
@property (nonatomic, assign) BOOL dragCellFloating; // default is NO. If YES, the movement path for drag cell will not fix its x-axis.
@property (nonatomic) BOOL allowsSelectionForDragMode; // default is NO. Controls whether rows can be selected when in drag mode.
- (MPIndexPath *)indexPathForDragCell; // default is nil.

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
