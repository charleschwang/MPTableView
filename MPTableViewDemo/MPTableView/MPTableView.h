//
//  MPTableView.h
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableViewCell.h"

@class MPTableView, MPIndexPath;

@protocol MPTableViewDelegate <UIScrollViewDelegate>
@optional

// Display customization

- (void)MPTableView:(MPTableView *)tableView willDisplayCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath;

- (void)MPTableView:(MPTableView *)tableView willDisplayHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView willDisplayFooterView:(MPTableReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section;
- (void)MPTableView:(MPTableView *)tableView didEndDisplayingFooterView:(MPTableReusableView *)view forSection:(NSInteger)section;

// Custom animations for updating. cell will be nil while it is ouside of the display area. a reload-update is composed of a delete and a insert function.

// Called before animation start. The pathPosition is the origin.y of those animating views that in front of the current cell. In the MPTableViewRowAnimation, the pathPosition is the cell's starting position.
- (void)MPTableView:(MPTableView *)tableView willInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition;

// Called when animating(in [UIView Animation] block).
- (void)MPTableView:(MPTableView *)tableView beginInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition;

// The pathPosition in delete is a target position that views will move to. In the MPTableViewRowAnimation, the pathPosition is the cell's target position that make it looks like always follow the font one.
- (void)MPTableView:(MPTableView *)tableView willDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView beginDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition;

- (void)MPTableView:(MPTableView *)tableView willInsertHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView beginInsertHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView willInsertFooterView:(MPTableReusableView *)view forSection:(NSInteger)section withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView beginInsertFooterView:(MPTableReusableView *)view forSection:(NSInteger)section withAnimationPathPosition:(CGFloat)pathPosition;

- (void)MPTableView:(MPTableView *)tableView willDeleteHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView beginDeleteHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView willDeleteFooterView:(MPTableReusableView *)view forSection:(NSInteger)section withAnimationPathPosition:(CGFloat)pathPosition;
- (void)MPTableView:(MPTableView *)tableView beginDeleteFooterView:(MPTableReusableView *)view forSection:(NSInteger)section withAnimationPathPosition:(CGFloat)pathPosition;

// Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
- (MPIndexPath *)MPTableView:(MPTableView *)tableView willSelectCell:(MPTableViewCell *)cell atIndexPath:(MPIndexPath *)indexPath;
- (MPIndexPath *)MPTableView:(MPTableView *)tableView willDeselectRowAtIndexPath:(MPIndexPath *)indexPath;

// Called after the user changes the selection.

- (void)MPTableView:(MPTableView *)tableView didSelectCell:(MPTableViewCell *)cell atIndexPath:(MPIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didDeselectRowAtIndexPath:(MPIndexPath *)indexPath;

// -MPTableView:shouldHighlightRowAtIndexPath: is called when a touch comes down on a row.
// Returning NO to that message halts the selection process and does not cause the currently selected row to lose its selected look while the touch is down.
- (BOOL)MPTableView:(MPTableView *)tableView shouldHighlightRowAtIndexPath:(MPIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didHighlightRowAtIndexPath:(MPIndexPath *)indexPath;
- (void)MPTableView:(MPTableView *)tableView didUnhighlightRowAtIndexPath:(MPIndexPath *)indexPath;

@end

UIKIT_EXTERN NSString *const MPTableViewSelectionDidChangeNotification;

#pragma mark -

@protocol MPTableViewDataSource <NSObject>
@required

- (NSUInteger)MPTableView:(MPTableView *)tableView numberOfRowsInSection:(NSUInteger)section;

- (MPTableViewCell *)MPTableView:(MPTableView *)tableView cellForRowAtIndexPath:(MPIndexPath *)indexPath;

@optional
- (NSUInteger)numberOfSectionsInMPTableView:(MPTableView *)tableView; // Default is 1 if not implemented

// Variable height support
- (CGFloat)MPTableView:(MPTableView *)tableView heightForIndexPath:(MPIndexPath *)indexPath;
- (CGFloat)MPTableView:(MPTableView *)tableView heightForHeaderInSection:(NSUInteger)section;
- (CGFloat)MPTableView:(MPTableView *)tableView heightForFooterInSection:(NSUInteger)section;

// custom view for header. will be adjusted to default or specified header height. Implementers should *always* try to reuse sectionViews by setting each sectionView's reuseIdentifier and querying for available reusable sectionViews with dequeueReusableViewWithIdentifier:

- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForHeaderInSection:(NSUInteger)section;
- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForFooterInSection:(NSUInteger)section;

@end

#pragma mark -

typedef NS_ENUM(NSUInteger, MPTableViewStyle) {
    MPTableViewStylePlain, MPTableViewStyleGrouped
};

typedef NS_ENUM(NSInteger, MPTableViewScrollPosition) {
    MPTableViewScrollPositionNone,
    MPTableViewScrollPositionTop,
    MPTableViewScrollPositionMiddle,
    MPTableViewScrollPositionBottom
};

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

@property (nonatomic) CGFloat rowHeight; // will return the default value if unset
@property (nonatomic) CGFloat sectionHeaderHeight;
@property (nonatomic) CGFloat sectionFooterHeight;

- (NSUInteger)numberOfSections;
- (NSUInteger)numberOfRowsInSection:(NSInteger)section;

@property (nonatomic, readonly) MPIndexPath *beginIndexPath; // displaying
@property (nonatomic, readonly) MPIndexPath *endIndexPath;

- (CGRect)rectForSection:(NSUInteger)section; // includes header, footer and all rows, return CGRectNull if section is not found
- (CGRect)rectForHeaderInSection:(NSUInteger)section;
- (CGRect)rectForFooterInSection:(NSUInteger)section;
- (CGRect)rectForRowAtIndexPath:(MPIndexPath *)indexPath;

- (MPIndexPath *)indexPathForRowAtPoint:(CGPoint)point; // returns nil if point is outside of any row in the table
- (NSUInteger)indexForSectionAtPoint:(CGPoint)point; // returns NSNotFound if point is outside of any section in the table

- (MPTableViewCell *)cellForRowAtIndexPath:(MPIndexPath *)indexPath;

- (MPIndexPath *)indexPathForCell:(MPTableViewCell *)cell; // returns nil if cell is not visible

- (NSArray *)visibleCells;

- (NSArray *)visibleCellsInRect:(CGRect)rect; // returns nil if rect not valid

- (NSArray *)indexPathsForVisibleRows;

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect; // returns nil if rect not valid

@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) UIView *tableFooterView;

@property (nonatomic, strong) UIView *backgroundView; // will be placed as a subview of the table view behind all cells and headers/footers.

@property (nonatomic, assign) BOOL enableCachesReload; // default is NO, when reloading tableview, without clear reusable views and cache all displayed views to reuse(It is best to make sure that tableview will reload with the same cells/reusableViews);
- (void)clearReusableCells;
- (void)clearReusableSectionViews;

- (void)reloadData;
- (void)reloadDataAsyncWithCompletion:(void (^)(void))completion; // reload data asynchronously. In this process, tableview will work as usual.

@property (nonatomic) BOOL allowsSelection;  // default is YES.
@property (nonatomic) BOOL allowsMultipleSelection; // default is NO.

@property (nonatomic, readonly) MPIndexPath *indexPathForSelectedRow; // returns nil or index path representing section and row of selection.
@property (nonatomic, readonly) NSArray *indexPathsForSelectedRows; // returns nil or a set of index paths representing the sections and rows of the selection.

- (void)scrollToRowAtIndexPath:(MPIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated; // scroll to a selected row which closest to the top

- (void)selectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition;

- (void)deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated;

- (BOOL)isUpdating; // animating

@property (nonatomic, assign) NSTimeInterval rowAnimationDuration; // default is 0.3
@property (nonatomic, assign) NSTimeInterval rowAnimationDelay; // default is 0
@property (nonatomic) UIViewAnimationOptions rowAnimationOptions; // default is UIViewAnimationOptionCurveEaseInOut.

- (void)beginUpdates; // allow multiple insert/delete of rows and sections to be animated simultaneously. Nestable
- (void)endUpdates; // only call insert/delete/reload calls or sections inside an update block.  otherwise things like row count, etc. may be invalid.

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveSection:(NSUInteger)section toSection:(NSUInteger)newSection;

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation;
- (void)moveRowAtIndexPath:(MPIndexPath *)indexPath toIndexPath:(MPIndexPath *)newIndexPath;

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
- (NSComparisonResult)compare:(MPIndexPath *)indexPath;

@end
