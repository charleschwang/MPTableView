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
// MPTableView has no estimatedRowHeight, estimatedSectionHeaderHeight, or estimatedSectionFooterHeight, because these values can be modified at any time, which may lead to inconsistent layout behavior.

- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section;
- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section;

// Custom view for headers/footers. Will be adjusted to default or specified height. Implementers should *always* try to reuse the reusable views by setting each reusable view's reuseIdentifier and querying for available reusable views with -dequeueReusableViewWithIdentifier:
- (MPTableViewReusableView *)MPTableView:(MPTableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (MPTableViewReusableView *)MPTableView:(MPTableView *)tableView viewForFooterInSection:(NSInteger)section;

- (BOOL)MPTableView:(MPTableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;

// Allows customization of the target row for a particular row as it is being moved/reordered
- (NSIndexPath *)MPTableView:(MPTableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath;

// If not implemented, the rect is [cell bounds], meaning that touching any position in the cell will start a drag.
- (CGRect)MPTableView:(MPTableView *)tableView rectForCellToMoveRowAtIndexPath:(NSIndexPath *)indexPath;

// Called when the dragging action stops.
- (void)MPTableView:(MPTableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

@end

#pragma mark -

@protocol MPTableViewDelegate <UIScrollViewDelegate>

@optional

// Display customization

- (void)MPTableView:(MPTableView *)tableView willDisplayCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)MPTableView:(MPTableView *)tableView willDisplayHeaderView:(MPTableViewReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView willDisplayFooterView:(MPTableViewReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingHeaderView:(MPTableViewReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingFooterView:(MPTableViewReusableView *)view forSection:(NSInteger)section;

// Customizes animations for table view updates. A reload update invokes both delete and insert functions.
// Called when the table view is updating.

// The proposedPosition is the position that the deleted view should move to. For built-in animations, the proposedPosition is the frame.origin of the deleted view, making it look like it always follows the front one.
// ※※※※※※※※※※ WARNING: You need to call -removeFromSuperview manually to remove the deleted view, and then you may either discard it immediately or cache it for reuse. ※※※※※※※※※※
- (void)MPTableView:(MPTableView *)tableView startToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withProposedPosition:(CGPoint)proposedPosition;
- (void)MPTableView:(MPTableView *)tableView startToDeleteHeaderView:(MPTableViewReusableView *)view forSection:(NSInteger)section withProposedPosition:(CGPoint)proposedPosition;
- (void)MPTableView:(MPTableView *)tableView startToDeleteFooterView:(MPTableViewReusableView *)view forSection:(NSInteger)section withProposedPosition:(CGPoint)proposedPosition;

// For built-in animations, the view will be added at the proposedLocation first. The cell is already assigned its final frame, so if you want to customize animations using the proposedLocation, please set the cell to the proposedLocation inside this method, and make sure the cell is set to its final frame when the animation finishes.
// ※※※※※※※※※※ If scrolling is allowed during the update, we had better put the update functions (such as -insertSections:withRowAnimation:) inside -performBatchUpdates:duration:delay:completion: to use the same animation duration, which prevents some cells (and headers/footers) from being put into the reuse queue and keeps our custom animations uninterrupted. ※※※※※※※※※※
- (void)MPTableView:(MPTableView *)tableView startToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withProposedLocation:(CGPoint)proposedLocation;
- (void)MPTableView:(MPTableView *)tableView startToInsertHeaderView:(MPTableViewReusableView *)view forSection:(NSInteger)section withProposedLocation:(CGPoint)proposedLocation;
- (void)MPTableView:(MPTableView *)tableView startToInsertFooterView:(MPTableViewReusableView *)view forSection:(NSInteger)section withProposedLocation:(CGPoint)proposedLocation;

// Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
- (NSIndexPath *)MPTableView:(MPTableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)MPTableView:(MPTableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath;

// Called after the user changes the selection.

- (void)MPTableView:(MPTableView *)tableView didSelectCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath;

// -MPTableView:shouldHighlightRowAtIndexPath: is called when a touch comes down on a row.
// Returning NO to that message halts the selection process and does not cause the currently selected row to lose its selected look while the touch is down.
- (BOOL)MPTableView:(MPTableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath;

// Called when the dragging action starts.
- (void)MPTableView:(MPTableView *)tableView shouldMoveRowAtIndexPath:(NSIndexPath *)sourceIndexPath;
// Called when the dragging action finishes.
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

// MPTableViewRowAnimationTop, MPTableViewRowAnimationBottom and MPTableViewRowAnimationMiddle change the subview's height to 0 during animation. When using these animation types, layout code for cells and headers/footers should be placed in -setFrame: instead of -layoutSubviews.
typedef NS_ENUM(NSInteger, MPTableViewRowAnimation) {
    MPTableViewRowAnimationFade,
    MPTableViewRowAnimationRight, // slide in from right (or out to right)
    MPTableViewRowAnimationLeft,
    MPTableViewRowAnimationTop,
    MPTableViewRowAnimationBottom,
    MPTableViewRowAnimationMiddle,
    MPTableViewRowAnimationNone,
    MPTableViewRowAnimationRandom, // not including MPTableViewRowAnimationCustom
    MPTableViewRowAnimationCustom = 103 // requires implementing the delete/insert-related methods in the MPTableViewDelegate protocol to customize the animation
};

@interface MPTableView : UIScrollView

- (instancetype)initWithFrame:(CGRect)frame style:(MPTableViewStyle)style NS_DESIGNATED_INITIALIZER; // must specify style at creation. -initWithFrame: calls this with MPTableViewStylePlain.

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) MPTableViewStyle style;
@property (nonatomic, weak) id<MPTableViewDataSource> dataSource;
@property (nonatomic, weak) id<MPTableViewDelegate> delegate;
@property (nonatomic, weak) id<MPTableViewDataSourcePrefetching> prefetchDataSource;

@property (nonatomic) CGFloat rowHeight; // default is MPTableViewDefaultCellHeight
@property (nonatomic) CGFloat sectionHeaderHeight; // default value is 0 if style is MPTableViewStylePlain, otherwise 35.
@property (nonatomic) CGFloat sectionFooterHeight;

- (NSInteger)numberOfSections;
- (NSInteger)numberOfRowsInSection:(NSInteger)section;

@property (nonatomic, readonly) NSIndexPath *firstVisibleIndexPath; // if the first visible subview is a header or footer, the row will be NSNotFound.
@property (nonatomic, readonly) NSIndexPath *lastVisibleIndexPath;

- (CGRect)rectForSection:(NSInteger)section; // includes header, footer and all rows, returns CGRectNull if section is not found.
- (CGRect)rectForHeaderInSection:(NSInteger)section;
- (CGRect)rectForFooterInSection:(NSInteger)section;
- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath;

- (NSInteger)indexForSectionAtPoint:(CGPoint)point; // returns NSNotFound if point is outside of any section in the table view
- (NSInteger)indexForSectionHeaderAtPoint:(CGPoint)point; // returns NSNotFound if point is outside of any section header in the table view
- (NSInteger)indexForSectionFooterAtPoint:(CGPoint)point;
- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point; // returns nil if point is outside of any row in the table view

- (MPTableViewReusableView *)sectionHeaderInSection:(NSInteger)section;
- (MPTableViewReusableView *)sectionFooterInSection:(NSInteger)section;
- (MPTableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath; // returns nil if cell is not visible or index path is out of range

- (NSIndexPath *)indexPathForCell:(MPTableViewCell *)cell; // returns nil if cell is not visible

- (NSArray *)visibleCells;

- (NSArray *)visibleCellsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForVisibleRows;

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForRowsInSection:(NSInteger)section;

@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) UIView *tableFooterView;

@property (nonatomic, strong) UIView *backgroundView; // the background view will be automatically resized to track the size of the table view. This will be placed as a subview of the table view behind all cells and headers/footers. Default is nil.

@property (nonatomic) BOOL allowsCachingSubviewsDuringReload; // default is YES. When table view is reloading, it will not remove those reusable subviews and will cache all of them. But if you are sure that the table view will reload with a different kind of subview or more, you should set it to NO.

- (void)reloadData;

/**
 Reloads data asynchronously.
 
 During the reload process, the table view remains responsive and can continue scrolling
 and displaying content. Data source methods may be invoked asynchronously on the specified
 dispatch queue.
 This method may be called from any thread. All UI updates and final data application are
 performed on the main thread.
 
 If the queue is NULL, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) is used
 by default.
 Calling -reloadData before completion will discard the loaded data, and the completion
 block will be invoked with finished set to NO.
 */
- (void)reloadDataAsynchronouslyWithQueue:(dispatch_queue_t)queue completion:(void (^)(BOOL finished))completion;

@property (nonatomic) BOOL allowsSelection; // default is YES
@property (nonatomic) BOOL allowsMultipleSelection; // default is NO

@property (nonatomic, readonly) NSIndexPath *indexPathForSelectedRow; // returns nil or index path representing section and row of selection
@property (nonatomic, readonly) NSArray *indexPathsForSelectedRows; // returns nil or a set of index paths representing the sections and rows of the selection

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // scroll to a selected row which closest to the top

- (void)scrollToHeaderInSection:(NSInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // similar to -scrollToRowAtIndexPath:atScrollPosition:animated:, but for a section header.
- (void)scrollToFooterInSection:(NSInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition;

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

/**
 Default is YES.
 
 If set to NO, the table view will not reload data for off-screen views during an update.
 This can significantly improve performance when it is guaranteed that subview heights
 do not change during updates (which is the common case).
 
 If this guarantee cannot be made, and the content offset may change after the update,
 this property should be set to YES.
 */
@property (nonatomic) BOOL shouldReloadAllDataDuringUpdate;

/**
 Default is NO.
 
 By default, the table view creates additional subviews (cells and headers/footers)
 to perform update animations, even though many of these views are only temporarily
 visible and will be moved off-screen once the animation completes.
 
 This behavior improves animation effects, but may result in a large number of
 cached subviews, which then need to be released manually by calling
 -clearReusableCellsAndViews.
 
 If set to YES, the table view avoids creating these additional subviews during updates,
 which can significantly improve performance.
 
 However, excessive reusable subviews may still be created if
 shouldReloadAllDataDuringUpdate is YES and multiple updates are triggered concurrently
 when using estimated heights mode.
 */
@property (nonatomic) BOOL allowsOptimizingNumberOfSubviewsDuringUpdate;

// When the table view is frequently updated using update APIs instead of reloadData, a large number of reusable views may be created and cached. In such cases, the table view may not be able to efficiently reuse these views.
// The following methods are provided to inspect and explicitly manage reusable cells and other reusable views.
- (NSArray *)identifiersForReusableCells;
- (NSArray *)identifiersForReusableViews;

- (NSUInteger)numberOfReusableCellsWithIdentifier:(NSString *)identifier;
- (NSUInteger)numberOfReusableViewsWithIdentifier:(NSString *)identifier;

- (void)discardReusableCellsWithIdentifier:(NSString *)identifier count:(NSUInteger)count;
- (void)discardReusableViewsWithIdentifier:(NSString *)identifier count:(NSUInteger)count;
- (void)clearReusableCellsAndViews;

// Default is YES. When set to YES, the table view uses UIViewAnimationOptionLayoutSubviews for update animations. If set to NO, update animation effects may look unnatural when using Auto Layout together with the built-in table view animations.
@property (nonatomic) BOOL shouldOptimizeUpdateAnimationsForAutoLayout;

@property (nonatomic) BOOL allowsUserInteractionDuringUpdate; // Default is YES. When set to YES, user interaction is allowed during updates, including scrolling and cell selection, by using UIViewAnimationOptionAllowUserInteraction for update animations.

- (BOOL)isUpdating;

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion; // allow multiple insert/delete/reload/move of rows and sections to be animated simultaneously. Nestable.

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(void (^)(BOOL finished))completion; // similar to -performBatchUpdates:completion:, but provides additional animation options.

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options completion:(void (^)(BOOL finished))completion;

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

@property (nonatomic, getter=isDragModeEnabled) BOOL dragModeEnabled; // default is NO. When set to YES, dragging behavior is enabled and should be controlled and tracked through MPTableViewDataSource and MPTableViewDelegate methods.
@property (nonatomic) CFTimeInterval minimumPressDurationToBeginDrag; // default is 0.1
@property (nonatomic) BOOL allowsSelectionInDragMode; // default is NO. Controls whether rows can be selected while in drag mode.
@property (nonatomic) BOOL allowsDraggedCellToFloat; // default is NO. When set to YES, the movement path of the dragged cell is not constrained to the x-axis.
@property (nonatomic, readonly) NSIndexPath *indexPathForDraggingRow; // returns an indexPath where the dragged cell has just moved to, not the sourceIndexPath, and, because the drag has not finished, not the destinationIndexPath either.

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier;
// similar to -dequeueReusableCellWithIdentifier:, but for headers/footers.
- (id)dequeueReusableViewWithIdentifier:(NSString *)identifier;

- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)identifier;
- (void)registerClass:(Class)reusableViewClass forReusableViewReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forReusableViewReuseIdentifier:(NSString *)identifier;

@end
