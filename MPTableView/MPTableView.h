//
//  MPTableView.h
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015 PBA. All rights reserved.
//

#import "MPTableViewCell.h"

@class MPTableView;

@protocol MPTableViewDataSource <NSObject>

@required

- (NSInteger)MPTableView:(MPTableView *)tableView numberOfRowsInSection:(NSInteger)section;

- (MPTableViewCell *)MPTableView:(MPTableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;

@optional

- (NSInteger)numberOfSectionsInMPTableView:(MPTableView *)tableView;

// Variable height support

- (CGFloat)MPTableView:(MPTableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)MPTableView:(MPTableView *)tableView heightForHeaderInSection:(NSInteger)section;
- (CGFloat)MPTableView:(MPTableView *)tableView heightForFooterInSection:(NSInteger)section;

// Use the estimatedHeight methods to quickly calcuate guessed values which will allow for fast load times of the table.
// If these methods are implemented, the above -MPTableView:heightForXXX calls will be deferred until views are ready to be displayed, so more expensive logic can be placed there.
// MPTableView has no estimatedRowHeight, estimatedSectionHeaderHeight and estimatedSectionFooterHeight, because these properties can be modified at any time, and that may cause some trouble.

- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section;
- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section;

// Custom view for headers/footers. Will be adjusted to default or specified height. Implementers should *always* try to reuse the reusable views by setting each reusable view's reuseIdentifier and querying for available reusable views with -dequeueReusableViewWithIdentifier:
- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForFooterInSection:(NSInteger)section;

- (BOOL)MPTableView:(MPTableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;

// Allows customization of the target row for a particular row as it is being moved/reordered
- (NSIndexPath *)MPTableView:(MPTableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath;

// If not implemented, the rect is [cell bounds], means that touch any position in the cell will make it begin to drag.
- (CGRect)MPTableView:(MPTableView *)tableView rectForCellToMoveRowAtIndexPath:(NSIndexPath *)indexPath;

// Called when the dragging action is stopping.
- (void)MPTableView:(MPTableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

@end

#pragma mark -

@protocol MPTableViewDelegate <UIScrollViewDelegate>

@optional

// Display customization

- (void)MPTableView:(MPTableView *)tableView willDisplayCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)MPTableView:(MPTableView *)tableView willDisplayHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView willDisplayFooterView:(MPTableReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingFooterView:(MPTableReusableView *)view forSection:(NSInteger)section;

// Customize animations for table view update. A reload update will invoke both delete and insert functions.
// Called when table view is updating.

// The proposedPosition is a proposed position that the deleted view should move to. For those built-in animations, the proposedPosition is the frame.origin of the deleted view that make it look like always follow the font one.
// ※※※※※※※※※※ WARNING: You need to call -removeFromSuperview manually to remove the deleted view, and then you can discard it immediately or cache it for reuse. ※※※※※※※※※※
- (void)MPTableView:(MPTableView *)tableView beginToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withProposedPosition:(CGPoint)proposedPosition;
- (void)MPTableView:(MPTableView *)tableView beginToDeleteHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section withProposedPosition:(CGPoint)proposedPosition;
- (void)MPTableView:(MPTableView *)tableView beginToDeleteFooterView:(MPTableReusableView *)view forSection:(NSInteger)section withProposedPosition:(CGPoint)proposedPosition;

// For the built-in animations, the view will be added to the proposedLocation at the first.
// ※※※※※※※※※※ If the table view should be scrolled during the update, we had better put the update functions (like -insertSections:withRowAnimation:) inside the -performBatchUpdates:duration:delay:completion: to set the same animation duration, that will stop some cells (and headers/footers) into the reusable queue and keep our custom animations uninterrupted. ※※※※※※※※※※
- (void)MPTableView:(MPTableView *)tableView beginToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withProposedLocation:(CGPoint)proposedLocation;
- (void)MPTableView:(MPTableView *)tableView beginToInsertHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section withProposedLocation:(CGPoint)proposedLocation;
- (void)MPTableView:(MPTableView *)tableView beginToInsertFooterView:(MPTableReusableView *)view forSection:(NSInteger)section withProposedLocation:(CGPoint)proposedLocation;

// Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
- (NSIndexPath *)MPTableView:(MPTableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)MPTableView:(MPTableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath;

// Called after the user changes the selection.

- (void)MPTableView:(MPTableView *)tableView didSelectRowForCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath;

// -MPTableView:shouldHighlightRowAtIndexPath: is called when a touch comes down on a row.
// Returning NO to that message halts the selection process and does not cause the currently selected row to lose its selected look while the touch is down.
- (BOOL)MPTableView:(MPTableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath;

// Called when the dragging action is starting.
- (void)MPTableView:(MPTableView *)tableView shouldMoveRowAtIndexPath:(NSIndexPath *)sourceIndexPath;
// Called when the dragging action is finished.
- (void)MPTableView:(MPTableView *)tableView didEndMovingCell:(MPTableViewCell *)cell fromRowAtIndexPath:(NSIndexPath *)sourceIndexPath;

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

// Use MPTableViewRowAnimationTop, MPTableViewRowAnimationBottom and MPTableViewRowAnimationMiddle should change subview's height to 0. So if you use these three animation types, you had better put the layout codes in -setFrame: instead of in -layoutSubviews for cells and headers/footers.
typedef NS_ENUM(NSInteger, MPTableViewRowAnimation) {
    MPTableViewRowAnimationFade,
    MPTableViewRowAnimationRight, // slide in from right (or out to right)
    MPTableViewRowAnimationLeft,
    MPTableViewRowAnimationTop,
    MPTableViewRowAnimationBottom,
    MPTableViewRowAnimationMiddle,
    MPTableViewRowAnimationNone,
    MPTableViewRowAnimationCustom, // require to use those protocol functions of MPTableViewDelegate to customize the animation
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

- (NSInteger)numberOfSections;
- (NSInteger)numberOfRowsInSection:(NSInteger)section;

@property (nonatomic, readonly) NSIndexPath *beginIndexPath; // if the first subview is a header or a footer, the row will be NSNotFound.
@property (nonatomic, readonly) NSIndexPath *endIndexPath;

- (CGRect)rectForSection:(NSInteger)section; // includes header, footer and all rows, return CGRectNull if section is not found.
- (CGRect)rectForHeaderInSection:(NSInteger)section;
- (CGRect)rectForFooterInSection:(NSInteger)section;
- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath;

- (NSInteger)indexForSectionAtPoint:(CGPoint)point; // returns NSNotFound if point is outside of any section in the table view
- (NSInteger)indexForSectionHeaderAtPoint:(CGPoint)point; // returns NSNotFound if point is outside of any section header in the table view
- (NSInteger)indexForSectionFooterAtPoint:(CGPoint)point;
- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point; // returns nil if point is outside of any row in the table view

- (MPTableReusableView *)sectionHeaderInSection:(NSInteger)section;
- (MPTableReusableView *)sectionFooterInSection:(NSInteger)section;
- (MPTableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath; // returns nil if cell is not visible or index path is out of range

- (NSIndexPath *)indexPathForCell:(MPTableViewCell *)cell; // returns nil if cell is not visible

- (NSArray *)visibleCells;

- (NSArray *)visibleCellsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForVisibleRows;

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForRowsInSection:(NSInteger)section;

@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) UIView *tableFooterView;

@property (nonatomic, strong) UIView *backgroundView; // will be placed as a subview of the table view behind all cells and headers/footers

@property (nonatomic) BOOL cachesSubviewsDuringReload; // default is YES. When table view is reloading, it will not remove those reusable subviews and will cache all of them. But if you make sure that the table view will reload with a different kind of subview or more, you should set it to NO.

- (void)reloadData;

/**
 Reloads data asynchronously. In this process, table view will work as usual, and the protocol functions of its data source will be invoked asynchronously. Allows to work in a async thread.
 If the queue is null, it will use dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) by default.
 Call -reloadData before completion will discard the loaded data and the finished will be NO.
 */
- (void)reloadDataAsyncWithQueue:(dispatch_queue_t)queue completion:(void (^)(BOOL finished))completion;

@property (nonatomic) BOOL allowsSelection; // default is YES
@property (nonatomic) BOOL allowsMultipleSelection; // default is NO

@property (nonatomic, readonly) NSIndexPath *indexPathForSelectedRow; // returns nil or index path representing section and row of selection
@property (nonatomic, readonly) NSArray *indexPathsForSelectedRows; // returns nil or a set of index paths representing the sections and rows of the selection

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // scroll to a selected row which closest to the top

- (void)scrollToHeaderInSection:(NSInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // like scrollToRowAtIndexPath:atScrollPosition:animated:, but for section header
- (void)scrollToFooterInSection:(NSInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition;

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

/**
 Default is YES.
 If NO, table view will not reload data for those off-screen views when it is updating.
 So if you can confirm that needn't to change all subview heights when the table view is updating (In fact, we usually don't change cell heights in an update), then you should set it to NO to get the best performance.
 
 But if you can't, and the content offset will be changed after update, then you should set it to YES.
 */
@property (nonatomic) BOOL reloadsAllDataDuringUpdate;

/**
 Default is NO.
 By default, table view will create some subviews (cells and headers/footers) to display update animations, even though most of subviews are outside the screen, or in other words these subviews have not be added to table view before update and they will be hidden when the update is finished.
 That is good for animation effects but should make many subviews to be cached, then we must release them manually (call -clearReusableCellsAndViews).
 
 If YES, table view will not create this kind of subviews when it is updating, that should improve performance. But table view still may create too many reusable subviews if reloadsAllDataDuringUpdate is YES and we start too many updates at the same time in the estimated-height mode.
 */
@property (nonatomic) BOOL optimizesNumberOfSubviewsDuringUpdate;

// Sometimes we frequently update table view (use those update APIs but not reloadData), that may produce many caches (reusable views) and table view can not make the most of them.
- (NSArray *)identifiersForReusableCells;
- (NSArray *)identifiersForReusableViews;

- (NSUInteger)numberOfReusableCellsWithIdentifier:(NSString *)identifier;
- (NSUInteger)numberOfReusableViewsWithIdentifier:(NSString *)identifier;

- (void)clearReusableCellsInCount:(NSUInteger)count withIdentifier:(NSString *)identifier;
- (void)clearReusableViewsInCount:(NSUInteger)count withIdentifier:(NSString *)identifier;
- (void)clearReusableCellsAndViews;

@property (nonatomic) BOOL optimizesUpdateAnimationsForAutolayout; // default is YES, table view will use the UIViewAnimationOptionLayoutSubviews as an option in update animations. If NO, the update animation effects may look unnatural when you are using the Autolayout and those built-in table view animations.

@property (nonatomic) BOOL allowsUserInteractionDuringUpdate; // default is YES, table view can be scrolled and cells can be selected when the table view is updating (uses the UIViewAnimationOptionAllowUserInteraction for update animations).

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
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

@property (nonatomic, getter=isDragModeEnabled) BOOL dragModeEnabled; // default is NO. If YES, you should use the protocol functions of MPTableViewDataSource and MPTableViewDelegate to control and track the drag state of cells.
@property (nonatomic) CFTimeInterval minimumPressDurationForDrag; // default is 0.1
@property (nonatomic) BOOL allowsSelectionForDragMode; // default is NO. Controls whether rows can be selected when in drag mode.
@property (nonatomic) BOOL allowsDraggedCellToFloat; // default is NO. If YES, the movement path of dragged cell will not fix its x-axis.
@property (nonatomic, readonly) NSIndexPath *indexPathForDraggingRow; // return a indexPath which the dragged cell has just moved to, not the sourceIndexPath.

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier;
// like dequeueReusableCellWithIdentifier:, but for headers/footers
- (id)dequeueReusableViewWithIdentifier:(NSString *)identifier;

- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)identifier;
- (void)registerClass:(Class)reusableViewClass forReusableViewReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forReusableViewReuseIdentifier:(NSString *)identifier;

@end
