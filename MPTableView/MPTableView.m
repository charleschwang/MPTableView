//
//  MPTableView.m
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015 PBA. All rights reserved.
//

#import "MPTableView.h"
#import "MPTableViewSection.h"

typedef struct {
    NSInteger section, row;
} NSIndexPathStruct;

NS_INLINE NSIndexPathStruct
_NSIndexPathMakeStruct(NSInteger section, NSInteger row) {
    NSIndexPathStruct indexPath;
    indexPath.section = section;
    indexPath.row = row;
    return indexPath;
}

NS_INLINE NSIndexPathStruct
_NSIndexPathGetStruct(NSIndexPath *indexPath) {
    NSIndexPathStruct indexPathStruct;
    indexPathStruct.section = indexPath.section;
    indexPathStruct.row = indexPath.row;
    return indexPathStruct;
}

NS_INLINE NSIndexPath *
_NSIndexPathFromStruct(NSIndexPathStruct indexPathStruct) {
    //    NSUInteger indexes[2] = {(NSUInteger)indexPathStruct.section, (NSUInteger)indexPathStruct.row};
    //    return [[NSIndexPath alloc] initWithIndexes:indexes length:2];
    return [NSIndexPath indexPathForRow:indexPathStruct.row inSection:indexPathStruct.section];
}

NS_INLINE NSIndexPath *
_NSIndexPathInSectionForRow(NSInteger section, NSInteger row) {
    //    NSUInteger indexes[2] = {(NSUInteger)section, (NSUInteger)row};
    //    return [[NSIndexPath alloc] initWithIndexes:indexes length:2];
    return [NSIndexPath indexPathForRow:row inSection:section];
}

NS_INLINE BOOL
_NSIndexPathStructEqualToStruct(NSIndexPathStruct indexPath1, NSIndexPathStruct indexPath2) {
    return indexPath1.section == indexPath2.section && indexPath2.row == indexPath1.row;
}

NS_INLINE NSComparisonResult
_NSIndexPathStructCompareStruct(NSIndexPathStruct indexPath1, NSIndexPathStruct indexPath2) {
    if (indexPath1.section > indexPath2.section) {
        return NSOrderedDescending;
    } else if (indexPath1.section < indexPath2.section) {
        return NSOrderedAscending;
    } else {
        return (indexPath1.row == indexPath2.row) ? NSOrderedSame : (MPTV_ROW_LESS(indexPath1.row, indexPath2.row) ? NSOrderedAscending : NSOrderedDescending);
    }
}

NS_INLINE NSComparisonResult
_NSIndexPathCompareStruct(NSIndexPath *indexPath, NSIndexPathStruct indexPathStruct) {
    return _NSIndexPathStructCompareStruct(_NSIndexPathGetStruct(indexPath), indexPathStruct);
}

#pragma mark -

@interface MPTableView (UIGestureRecognizer)

- (BOOL)_mp_gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;

@end

@interface MPTableViewLongGestureRecognizer : UILongPressGestureRecognizer<UIGestureRecognizerDelegate>

@property (nonatomic, weak) MPTableView *tableView;

@end

@implementation MPTableViewLongGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    if (self = [super initWithTarget:target action:action]) {
        self.cancelsTouchesInView = YES;
        self.delaysTouchesBegan = NO;
        self.delaysTouchesEnded = YES;
        self.allowableMovement = 0;
        self.delegate = self;
    }
    
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return [self.tableView _mp_gestureRecognizerShouldBegin:gestureRecognizer];
}

@end

#pragma mark -

@interface MPTableReusableView (MPTableView)

@property (nonatomic, copy, readwrite) NSString *reuseIdentifier;

@end

#pragma mark -

static void
MPSetFrameForViewWithoutAnimation(UIView *view, CGRect frame) {
    if (CGRectEqualToRect(view.frame, frame)) {
        return;
    }
    
    if ([UIView areAnimationsEnabled]) {
        [UIView setAnimationsEnabled:NO];
        
        view.frame = frame;
        
        [UIView setAnimationsEnabled:YES];
    } else {
        view.frame = frame;
    }
}

NS_INLINE CGRect
MPSetWidthForView(UIView *view, CGFloat width) {
    CGRect frame = view.frame;
    if (frame.size.width != width) {
        frame.size.width = width;
        view.frame = frame;
    }
    return frame;
}

NS_INLINE void
MPMakeViewOffset(UIView *view, CGFloat offset) {
    CGRect frame = view.frame;
    frame.origin.y += offset;
    view.frame = frame;
}

static CGFloat
MPGetViewHeightAfterLayout(UIView *view, CGFloat width) {
    CGRect frame;
    if ([UIView areAnimationsEnabled]) {
        [UIView setAnimationsEnabled:NO];
        
        frame = MPSetWidthForView(view, width);
        [view layoutIfNeeded];
        frame.size.height = [view systemLayoutSizeFittingSize:CGSizeMake(width, 0)].height;
        view.frame = frame;
        
        [UIView setAnimationsEnabled:YES];
    } else {
        frame = MPSetWidthForView(view, width);
        [view layoutIfNeeded];
        frame.size.height = [view systemLayoutSizeFittingSize:CGSizeMake(width, 0)].height;
        view.frame = frame;
    }
    
    return frame.size.height;
}

static MPTableViewRowAnimation
MPGetRandomAnimation() {
    u_int32_t random = arc4random() % 7;
    return (MPTableViewRowAnimation)random;
}

static void
MPMakeViewDisappearWithAnimation(UIView *view, CGFloat top, MPTableViewRowAnimation animation, MPTableViewPosition *sectionPosition) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (!view.opaque) {
                view.hidden = YES;
                return;
            } else {
                frame.origin.y = top;
                view.alpha = 0;
            }
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin.y = top;
            frame.origin.x = frame.size.width;
            view.alpha = 0;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin.y = top;
            frame.origin.x = -frame.size.width;
            view.alpha = 0;
        }
            break;
        case MPTableViewRowAnimationTop: {
            frame.origin.y = top;
            frame.size.height = 0;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = bounds.size.height;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationBottom: {
            frame.origin.y = top;
            frame.size.height = 0;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = -bounds.size.height;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationMiddle: {
            if (sectionPosition) {
                frame.origin.y = top + (sectionPosition.endPos - sectionPosition.startPos) / 2;
            } else {
                frame.origin.y = top;
            }
            frame.size.height = 0;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = bounds.size.height / 2;
            view.bounds = bounds;
            
            view.alpha = 0;
        }
            break;
            
        default:
            break;
    }
    
    view.frame = frame;
}

static void
MPMakeViewAppearWithAnimation(UIView *view, CGRect lastFrame, CGFloat alpha, MPTableViewRowAnimation animation) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (!view.opaque) {
                view.hidden = NO;
                return;
            } else {
                frame.origin.y = lastFrame.origin.y;
                view.alpha = alpha;
            }
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin = lastFrame.origin;
            view.alpha = alpha;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin = lastFrame.origin;
            view.alpha = alpha;
        }
            break;
        case MPTableViewRowAnimationTop: {
            frame.origin.y = lastFrame.origin.y;
            frame.size.height = lastFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationBottom: {
            frame.origin.y = lastFrame.origin.y;
            frame.size.height = lastFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationMiddle: {
            frame.origin.y = lastFrame.origin.y;
            frame.size.height = lastFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
            
            view.alpha = alpha;
        }
            break;
            
        default:
            break;
    }
    
    view.frame = frame;
}

NS_INLINE CGPoint
MPPointsSubtraction(CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x - point2.x, point1.y - point2.y);
}

//NS_INLINE CGPoint
//MPPointsAddition(CGPoint point1, CGPoint point2) {
//    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
//}

NSString *const MPTableViewSelectionDidChangeNotification = @"MPTableViewSelectionDidChangeNotification";

const NSTimeInterval MPTableViewDefaultAnimationDuration = 0.3;

#pragma mark -

@implementation MPTableView {
    UIView *_contentWrapperView;
    MPTableViewPosition *_contentListPosition; // the position between tableHeaderView and tableFooterView
    MPTableViewPosition *_contentOffsetPosition;
    MPTableViewPosition *_contentListOffsetPosition; // the position of _contentOffsetPosition minus the _contentListPosition.startPos
    
    NSIndexPathStruct _beginIndexPath, _endIndexPath;
    
    NSMutableSet *_selectedIndexPaths;
    NSIndexPath *_highlightedIndexPath;
    
    BOOL
    _layoutSubviewsLock,
    _reloadDataLock, // will be YES when table view is reloading data.
    _updateSubviewsLock; // will be YES when table view is invoking -layoutSubviews or starting a new update transaction
    
    NSInteger _numberOfSections;
    NSMutableArray *_sectionsArray;
    NSMutableDictionary *_displayedCellsDic, *_displayedSectionViewsDic;
    NSMutableDictionary *_reusableCellsDic, *_registerCellClassesDic, *_registerCellNibsDic;
    NSMutableDictionary *_reusableReusableViewsDic, *_registerReusableViewClassesDic, *_registerReusableViewNibsDic;
    
    __weak id <MPTableViewDelegate> _tableViewDelegate;
    __weak id <MPTableViewDataSource> _tableViewDataSource;
    
    BOOL
    _reloadDataNeededFlag, // change the dataSource will set it to YES
    _layoutSubviewsNeededFlag,
    _supplementSubviewsNeededFlag;
    
    NSMutableDictionary *_estimatedCellsDic, *_estimatedSectionViewsDic;
    
    // update
    NSMutableArray *_updateManagersStack;
    NSInteger _updateContextStep;
    
    NSInteger _updateAnimationStep;
    
    CGFloat _updateInsertedLocationY, _updateDeletedPositionY;
    
    NSMutableDictionary *_updateNewCellsDic, *_updateNewSectionViewsDic;
    
    NSMutableDictionary *_updateDeletedCellsDic, *_updateDeletedSectionViewsDic;
    
    NSMutableArray *_updateAnimationBlocks;
    NSMutableSet *_updateAnimatedIndexPaths, *_updateAnimatedNewIndexPaths;
    NSMutableSet *_updateExchangedSelectedIndexPaths;
    
    BOOL _updateWillChangeContentOffset;
    NSMutableArray *_updateExecutionActions;
    
    // drag mode
    CGPoint _dragModeMinuendPoint;
    CGFloat _dragModeAutoScrollRate, _dragModeDifferFromBounds;
    MPTableViewLongGestureRecognizer *_dragModeLongGestureRecognizer;
    NSIndexPath *_draggingIndexPath, *_draggingSourceIndexPath;
    MPTableViewCell *_draggingCell;
    NSUInteger _draggedStep;
    CADisplayLink *_dragModeAutoScrollDisplayLink;
    
    // prefetch
    CGFloat _lastContentOffsetY;
    NSMutableArray *_prefetchIndexPaths;
    
    // protocols
    BOOL
    _respond_numberOfSectionsInMPTableView,
    
    _respond_heightForRowAtIndexPath,
    _respond_heightForHeaderInSection,
    _respond_heightForFooterInSection,
    
    _respond_estimatedHeightForRowAtIndexPath,
    _respond_estimatedHeightForHeaderInSection,
    _respond_estimatedHeightForFooterInSection,
    
    _respond_viewForHeaderInSection,
    _respond_viewForFooterInSection,
    
    _respond_canMoveRowAtIndexPath,
    _respond_targetIndexPathForMoveFromRowAtIndexPathToProposedIndexPath,
    _respond_rectForCellToMoveRowAtIndexPath,
    _respond_moveRowAtIndexPathToIndexPath;
    
    BOOL
    _respond_willDisplayCellForRowAtIndexPath,
    _respond_willDisplayHeaderViewForSection,
    _respond_willDisplayFooterViewForSection,
    _respond_didEndDisplayingCellForRowAtIndexPath,
    _respond_didEndDisplayingHeaderViewForSection,
    _respond_didEndDisplayingFooterViewForSection,
    
    _respond_willSelectRowAtIndexPath,
    _respond_willDeselectRowAtIndexPath,
    _respond_didSelectRowForCellForRowAtIndexPath,
    _respond_didDeselectRowAtIndexPath,
    
    _respond_shouldHighlightRowAtIndexPath,
    _respond_didHighlightRowAtIndexPath,
    _respond_didUnhighlightRowAtIndexPath,
    
    _respond_beginToDeleteCellForRowAtIndexPath,
    _respond_beginToDeleteHeaderViewForSection,
    _respond_beginToDeleteFooterViewForSection,
    
    _respond_beginToInsertCellForRowAtIndexPath,
    _respond_beginToInsertHeaderViewForSection,
    _respond_beginToInsertFooterViewForSection,
    
    _respond_shouldMoveRowAtIndexPath,
    _respond_didEndMovingCellFromRowAtIndexPath;
    
    BOOL
    _respond_prefetchRowsAtIndexPaths,
    _respond_cancelPrefetchingForRowsAtIndexPaths;
}

@dynamic delegate;

#define MPTV_CHECK_DATASOURCE do { \
if (!_tableViewDataSource) { \
return MPTableViewInvalidFloatValue; \
} \
} while (0)

#define MPTV_START_POS(_pos_) ((_pos_) - 0.1)
#define MPTV_END_POS(_pos_) ((_pos_) + 0.1)
#define MPTV_OFF_SCREEN(_frame_) ((_frame_).size.height <= 0 || MPTV_START_POS((_frame_).origin.y) > _contentOffsetPosition.endPos || MPTV_END_POS(CGRectGetMaxY(_frame_)) < _contentOffsetPosition.startPos)
#define MPTV_ON_SCREEN(_frame_) ((_frame_).size.height > 0 && MPTV_START_POS((_frame_).origin.y) <= _contentOffsetPosition.endPos && MPTV_END_POS(CGRectGetMaxY(_frame_)) >= _contentOffsetPosition.startPos)

#pragma mark -

- (instancetype)initWithFrame:(CGRect)frame style:(MPTableViewStyle)style {
    if (self = [super initWithFrame:frame]) {
        _style = style;
        [self _initializeWithoutDecoder];
        [self _initializeData];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame style:MPTableViewStylePlain];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        _style = (MPTableViewStyle)[aDecoder decodeIntegerForKey:@"_tableViewStyle"];
        _rowHeight = [aDecoder decodeDoubleForKey:@"_rowHeight"];
        _sectionHeaderHeight = [aDecoder decodeDoubleForKey:@"_sectionHeaderHeight"];
        _sectionFooterHeight = [aDecoder decodeDoubleForKey:@"_sectionFooterHeight"];
        
        _cachesSubviewsDuringReload = [aDecoder decodeBoolForKey:@"_cachesSubviewsDuringReload"];
        _allowsSelection = [aDecoder decodeBoolForKey:@"_allowsSelection"];
        _allowsMultipleSelection = [aDecoder decodeBoolForKey:@"_allowsMultipleSelection"];
        _reloadsAllDataDuringUpdate = [aDecoder decodeBoolForKey:@"_reloadsAllDataDuringUpdate"];
        _optimizesNumberOfSubviewsDuringUpdate = [aDecoder decodeBoolForKey:@"_optimizesNumberOfSubviewsDuringUpdate"];
        _optimizesUpdateAnimationsForAutolayout = [aDecoder decodeBoolForKey:@"_optimizesUpdateAnimationsForAutolayout"];
        _allowsUserInteractionDuringUpdate = [aDecoder decodeBoolForKey:@"_allowsUserInteractionDuringUpdate"];
        _dragModeEnabled = [aDecoder decodeBoolForKey:@"_dragModeEnabled"];
        _allowsSelectionForDragMode = [aDecoder decodeBoolForKey:@"_allowsSelectionForDragMode"];
        _allowsDraggedCellToFloat = [aDecoder decodeBoolForKey:@"_allowsDraggedCellToFloat"];
        _minimumPressDurationForDrag = [aDecoder decodeDoubleForKey:@"_minimumPressDurationForDrag"];
        
        _registerCellNibsDic = [aDecoder decodeObjectForKey:@"_registerCellNibsDic"];
        _registerReusableViewNibsDic = [aDecoder decodeObjectForKey:@"_registerReusableViewNibsDic"];
        
        [self _initializeData];
        
        self.tableHeaderView = [aDecoder decodeObjectForKey:@"_tableHeaderView"];
        self.tableFooterView = [aDecoder decodeObjectForKey:@"_tableFooterView"];
        self.backgroundView = [aDecoder decodeObjectForKey:@"_backgroundView"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    if (![NSThread isMainThread]) {
        return [self performSelectorOnMainThread:@selector(encodeWithCoder:) withObject:aCoder waitUntilDone:YES];
    }
    
    [self _resetDragModeLongGestureRecognizer];
    
    [aCoder encodeInteger:_style forKey:@"_tableViewStyle"];
    [aCoder encodeDouble:_rowHeight forKey:@"_rowHeight"];
    [aCoder encodeDouble:_sectionHeaderHeight forKey:@"_sectionHeaderHeight"];
    [aCoder encodeDouble:_sectionFooterHeight forKey:@"_sectionFooterHeight"];
    
    [aCoder encodeBool:_cachesSubviewsDuringReload forKey:@"_cachesSubviewsDuringReload"];
    [aCoder encodeBool:_allowsSelection forKey:@"_allowsSelection"];
    [aCoder encodeBool:_allowsMultipleSelection forKey:@"_allowsMultipleSelection"];
    [aCoder encodeBool:_reloadsAllDataDuringUpdate forKey:@"_reloadsAllDataDuringUpdate"];
    [aCoder encodeBool:_optimizesNumberOfSubviewsDuringUpdate forKey:@"_optimizesNumberOfSubviewsDuringUpdate"];
    [aCoder encodeBool:_optimizesUpdateAnimationsForAutolayout forKey:@"_optimizesUpdateAnimationsForAutolayout"];
    [aCoder encodeBool:_allowsUserInteractionDuringUpdate forKey:@"_allowsUserInteractionDuringUpdate"];
    [aCoder encodeBool:_dragModeEnabled forKey:@"_dragModeEnabled"];
    [aCoder encodeBool:_allowsSelectionForDragMode forKey:@"_allowsSelectionForDragMode"];
    [aCoder encodeBool:_allowsDraggedCellToFloat forKey:@"_allowsDraggedCellToFloat"];
    [aCoder encodeDouble:_minimumPressDurationForDrag forKey:@"_minimumPressDurationForDrag"];
    
    [aCoder encodeObject:_registerCellNibsDic forKey:@"_registerCellNibsDic"];
    [aCoder encodeObject:_registerReusableViewNibsDic forKey:@"_registerReusableViewNibsDic"];
    
    [_contentWrapperView removeFromSuperview];
    NSMutableArray *sectionViews = [NSMutableArray arrayWithArray:_displayedSectionViewsDic.allValues];
    for (NSArray *array in _reusableReusableViewsDic.allValues) {
        [sectionViews addObjectsFromArray:array];
    }
    [sectionViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    [_tableHeaderView removeFromSuperview];
    [_tableFooterView removeFromSuperview];
    [_backgroundView removeFromSuperview];
    
    [super encodeWithCoder:aCoder];
    
    [self addSubview:_contentWrapperView];
    for (UIView *sectionView in sectionViews) {
        [self addSubview:sectionView];
    }
    [sectionViews removeAllObjects];
    
    if (_tableHeaderView) {
        [aCoder encodeObject:_tableHeaderView forKey:@"_tableHeaderView"];
        [self addSubview:_tableHeaderView];
    }
    if (_tableFooterView) {
        [aCoder encodeObject:_tableFooterView forKey:@"_tableFooterView"];
        [self addSubview:_tableFooterView];
    }
    if (_backgroundView) {
        [aCoder encodeObject:_backgroundView forKey:@"_backgroundView"];
        [self _layoutBackgroundViewIfNeeded];
    }
}

- (void)_initializeWithoutDecoder {
    self.alwaysBounceVertical = YES;
    self.showsHorizontalScrollIndicator = NO;
    self.backgroundColor = [UIColor whiteColor];
    
    _rowHeight = MPTableViewDefaultCellHeight;
    if (_style == MPTableViewStylePlain) {
        _sectionHeaderHeight = 0;
        _sectionFooterHeight = 0;
    } else {
        _sectionHeaderHeight = 35.0;
        _sectionFooterHeight = 35.0;
    }
    
    _allowsSelection = YES;
    _allowsMultipleSelection = NO;
    _cachesSubviewsDuringReload = YES;
    _reloadsAllDataDuringUpdate = YES;
    _optimizesNumberOfSubviewsDuringUpdate = NO;
    _optimizesUpdateAnimationsForAutolayout = YES;
    _allowsUserInteractionDuringUpdate = YES;
    _dragModeEnabled = NO;
    _minimumPressDurationForDrag = 0.1;
    _allowsSelectionForDragMode = NO;
    _allowsDraggedCellToFloat = NO;
}

- (void)_initializeData {
    _layoutSubviewsLock = YES;
    _reloadDataLock = NO;
    _updateSubviewsLock = NO;
    
    [self addSubview:_contentWrapperView = [[UIView alloc] init]];
    _contentWrapperView.autoresizesSubviews = NO; // @optional
    
    _beginIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
    _endIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
    _contentListPosition = [MPTableViewPosition positionStart:0 toEnd:0];
    _contentOffsetPosition = [MPTableViewPosition positionStart:0 toEnd:0];
    _contentListOffsetPosition = [MPTableViewPosition positionStart:0 toEnd:0];
    
    _numberOfSections = 0;
    _sectionsArray = [[NSMutableArray alloc] init];
    _displayedCellsDic = [[NSMutableDictionary alloc] init];
    _displayedSectionViewsDic = [[NSMutableDictionary alloc] init];
    _reusableCellsDic = [[NSMutableDictionary alloc] init];
    _reusableReusableViewsDic = [[NSMutableDictionary alloc] init];
    
    _selectedIndexPaths = [[NSMutableSet alloc] init];
    _draggedStep = 0;
    
    _reloadDataNeededFlag = NO;
    _layoutSubviewsNeededFlag = NO;
    _supplementSubviewsNeededFlag = NO;
    
    _updateContextStep = 0;
    _updateAnimationStep = 0;
    _updateWillChangeContentOffset = NO;
}

- (void)dealloc {
    [self _clearDataAndCacheSubviewsEnabled:NO];
}

#pragma mark -

- (void)_respondsToDataSource {
    _respond_numberOfSectionsInMPTableView = [_tableViewDataSource respondsToSelector:@selector(numberOfSectionsInMPTableView:)];
    
    _respond_heightForRowAtIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:heightForRowAtIndexPath:)];
    _respond_heightForHeaderInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:heightForHeaderInSection:)];
    _respond_heightForFooterInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:heightForFooterInSection:)];
    
    _respond_estimatedHeightForRowAtIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForRowAtIndexPath:)];
    _respond_estimatedHeightForHeaderInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForHeaderInSection:)];
    _respond_estimatedHeightForFooterInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForFooterInSection:)];
    
    _respond_viewForHeaderInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:viewForHeaderInSection:)];
    _respond_viewForFooterInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:viewForFooterInSection:)];
    
    _respond_canMoveRowAtIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:canMoveRowAtIndexPath:)];
    _respond_targetIndexPathForMoveFromRowAtIndexPathToProposedIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)];
    _respond_rectForCellToMoveRowAtIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:rectForCellToMoveRowAtIndexPath:)];
    _respond_moveRowAtIndexPathToIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:moveRowAtIndexPath:toIndexPath:)];
}

- (void)_respondsToDelegate {
    _respond_willDisplayCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willDisplayCell:forRowAtIndexPath:)];
    _respond_willDisplayHeaderViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willDisplayHeaderView:forSection:)];
    _respond_willDisplayFooterViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willDisplayFooterView:forSection:)];
    
    _respond_didEndDisplayingCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingCell:forRowAtIndexPath:)];
    _respond_didEndDisplayingHeaderViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingHeaderView:forSection:)];
    _respond_didEndDisplayingFooterViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingFooterView:forSection:)];
    
    _respond_willSelectRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willSelectRowAtIndexPath:)];
    _respond_willDeselectRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willDeselectRowAtIndexPath:)];
    _respond_didSelectRowForCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didSelectRowForCell:forRowAtIndexPath:)];
    _respond_didDeselectRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didDeselectRowAtIndexPath:)];
    
    _respond_shouldHighlightRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:shouldHighlightRowAtIndexPath:)];
    _respond_didHighlightRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didHighlightRowAtIndexPath:)];
    _respond_didUnhighlightRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didUnhighlightRowAtIndexPath:)];
    
    _respond_beginToDeleteCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:beginToDeleteCell:forRowAtIndexPath:withProposedPosition:)];
    _respond_beginToDeleteHeaderViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:beginToDeleteHeaderView:forSection:withProposedPosition:)];
    _respond_beginToDeleteFooterViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:beginToDeleteFooterView:forSection:withProposedPosition:)];
    
    _respond_beginToInsertCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:beginToInsertCell:forRowAtIndexPath:withProposedLocation:)];
    _respond_beginToInsertHeaderViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:beginToInsertHeaderView:forSection:withProposedLocation:)];
    _respond_beginToInsertFooterViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:beginToInsertFooterView:forSection:withProposedLocation:)];
    
    _respond_shouldMoveRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:shouldMoveRowAtIndexPath:)];
    _respond_didEndMovingCellFromRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didEndMovingCell:fromRowAtIndexPath:)];
}

- (void)_respondsToPrefetchDataSource {
    _respond_prefetchRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:prefetchRowsAtIndexPaths:)];
    _respond_cancelPrefetchingForRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:cancelPrefetchingForRowsAtIndexPaths:)];
}

#pragma mark - public

- (void)setDataSource:(id<MPTableViewDataSource>)dataSource {
    NSParameterAssert(!_updateSubviewsLock);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(_updateContextStep == 0); // can't change the dataSource inside a -performBatchUpdates function
    if (!dataSource && !_tableViewDataSource) {
        return;
    }
    
    if (dataSource) {
        if (![dataSource respondsToSelector:@selector(MPTableView:cellForRowAtIndexPath:)] || ![dataSource respondsToSelector:@selector(MPTableView:numberOfRowsInSection:)]) {
            NSAssert(NO, @"need @required functions of dataSource");
            return;
        }
    }
    
    _tableViewDataSource = dataSource;
    [self _respondsToDataSource];
    
    if ([self _isEstimatedMode] && !_estimatedCellsDic) {
        _estimatedCellsDic = [[NSMutableDictionary alloc] init];
        _estimatedSectionViewsDic = [[NSMutableDictionary alloc] init];
    }
    
    _layoutSubviewsLock = NO;
    _reloadDataNeededFlag = YES;
    _layoutSubviewsNeededFlag = YES;
    if ([NSThread isMainThread]) {
        [self setNeedsLayout];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsLayout];
        });
    }
}

- (id<MPTableViewDataSource>)dataSource {
    return _tableViewDataSource;
}

- (void)setDelegate:(id<MPTableViewDelegate>)delegate {
    NSParameterAssert(!_updateSubviewsLock);
    NSParameterAssert(!_reloadDataLock);
    if (!delegate && !_tableViewDelegate) {
        return;
    }
    
    [super setDelegate:_tableViewDelegate = delegate];
    [self _respondsToDelegate];
}

- (id<MPTableViewDelegate>)delegate {
    return _tableViewDelegate;
}

- (void)setPrefetchDataSource:(id<MPTableViewDataSourcePrefetching>)prefetchDataSource {
    NSParameterAssert(!_updateSubviewsLock);
    NSParameterAssert(!_reloadDataLock);
    if (!prefetchDataSource && !_prefetchDataSource) {
        return;
    }
    
    _prefetchDataSource = prefetchDataSource;
    [self _respondsToPrefetchDataSource];
    if (_prefetchDataSource) {
        if (!_prefetchIndexPaths) {
            _prefetchIndexPaths = [[NSMutableArray alloc] init];
        }
    } else {
        if (_prefetchIndexPaths) {
            [_prefetchIndexPaths removeAllObjects];
        }
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    [self _layoutBackgroundViewIfNeeded];
}

- (void)setContentSize:(CGSize)contentSize {
    MPSetFrameForViewWithoutAnimation(_contentWrapperView, CGRectMake(0, 0, contentSize.width, contentSize.height));
    [super setContentSize:contentSize];
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    if (UIEdgeInsetsEqualToEdgeInsets([super contentInset], contentInset)) {
        return;
    }
    
    UIEdgeInsets lastContentInset = [self _innerContentInset];
    [super setContentInset:contentInset];
    _lastContentOffsetY = self.contentOffset.y;
    
    if (_reloadDataNeededFlag) {
        return;
    }
    
    contentInset = [self _innerContentInset];
    if (lastContentInset.top == contentInset.top && lastContentInset.bottom == contentInset.bottom) {
        return;
    }
    
    if (_style == MPTableViewStylePlain) {
        _supplementSubviewsNeededFlag = YES;
    }
    [self _layoutSubviewsInternal];
}

- (UIEdgeInsets)_innerContentInset {
#ifdef __IPHONE_11_0
    if (@available(iOS 11.0, *)) {
        return self.adjustedContentInset;
    } else {
        return self.contentInset;
    }
#else
    return self.contentInset;
#endif
}

- (void)setFrame:(CGRect)frame {
    CGRect lastFrame = [super frame];
    if (CGRectEqualToRect(lastFrame, frame)) {
        return;
    }
    
    UIEdgeInsets lastContentInset = [self _innerContentInset];
    [super setFrame:frame];
    [self _layoutBackgroundViewIfNeeded];
    
    if (_reloadDataNeededFlag) {
        return;
    }
    
    frame = [super frame]; // in case there is any value less than 0
    if (lastFrame.size.width != frame.size.width) {
        [self _setSubviewsWidth:frame.size.width];
    }
    
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (lastFrame.size.height == frame.size.height && lastContentInset.top == contentInset.top && lastContentInset.bottom == contentInset.bottom) {
        return;
    }
    
    if (_style == MPTableViewStylePlain) {
        _supplementSubviewsNeededFlag = YES;
    }
    [self _layoutSubviewsInternal];
}

- (void)setBounds:(CGRect)bounds {
    CGRect lastBounds = [super bounds];
    if (CGRectEqualToRect(lastBounds, bounds)) {
        return;
    }
    
    UIEdgeInsets lastContentInset = [self _innerContentInset];
    [super setBounds:bounds];
    [self _layoutBackgroundViewIfNeeded];
    
    if (_reloadDataNeededFlag) {
        return;
    }
    
    bounds = [super bounds];
    if (lastBounds.size.width != bounds.size.width) {
        [self _setSubviewsWidth:bounds.size.width];
    }
    
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (lastBounds.size.height == bounds.size.height && lastContentInset.top == contentInset.top && lastContentInset.bottom == contentInset.bottom) {
        return;
    }
    
    if (_style == MPTableViewStylePlain) {
        _supplementSubviewsNeededFlag = YES;
    }
    [self _layoutSubviewsInternal];
}

- (void)_setSubviewsWidth:(CGFloat)width {
    MPSetWidthForView(_tableHeaderView, width);
    MPSetWidthForView(_tableFooterView, width);
    
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        MPSetWidthForView(cell, width);
    }
    for (UIView *sectionView in _displayedSectionViewsDic.allValues) {
        MPSetWidthForView(sectionView, width);
    }
    
    for (MPTableViewCell *cell in _updateNewCellsDic.allValues) {
        MPSetWidthForView(cell, width);
    }
    for (UIView *sectionView in _updateNewSectionViewsDic.allValues) {
        MPSetWidthForView(sectionView, width);
    }
    
    CGSize contentSize = self.contentSize;
    contentSize.width = width;
    self.contentSize = contentSize;
}

- (void)removeFromSuperview {
    [self _endDraggingCellIfNeededImmediately:YES];
    _dragModeLongGestureRecognizer.enabled = NO; // -dealloc may not be called if the minimumPressDuration is 0 and the navigationController.interactivePopGestureRecognizer is enabled (use it to pop the present view controller).
    [super removeFromSuperview];
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    _dragModeLongGestureRecognizer.enabled = _dragModeEnabled;
}

- (NSInteger)numberOfSections {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    return _numberOfSections;
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (_numberOfSections == 0 || section >= _sectionsArray.count) {
        return NSNotFound;
    } else {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        return sectionPosition.numberOfRows;
    }
}

- (void)setRowHeight:(CGFloat)rowHeight {
    if (rowHeight < 0) {
        NSAssert(NO, @"row height can not be less than 0");
        rowHeight = 0;
    }
    
    _rowHeight = rowHeight;
}

- (void)setSectionHeaderHeight:(CGFloat)sectionHeaderHeight {
    if (sectionHeaderHeight < 0) {
        NSAssert(NO, @"section header height can not be less than 0");
        sectionHeaderHeight = 0;
    }
    
    _sectionHeaderHeight = sectionHeaderHeight;
}

- (void)setSectionFooterHeight:(CGFloat)sectionFooterHeight {
    if (sectionFooterHeight < 0) {
        NSAssert(NO, @"section footer height can not be less than 0");
        sectionFooterHeight = 0;
    }
    
    _sectionFooterHeight = sectionFooterHeight;
}

- (void)_adjustSectionViews:(NSDictionary *)sectionViews withOffset:(CGFloat)offset {
    if (_style == MPTableViewStylePlain) {
        for (NSIndexPath *indexPath in sectionViews.allKeys) {
            MPTableViewSection *section = _sectionsArray[indexPath.section];
            MPTableReusableView *sectionView = [sectionViews objectForKey:indexPath];
            MPSectionViewType type = indexPath.row;
            
            if ([self _needToStickViewInSection:section withType:type]) {
                sectionView.frame = [self _stickingFrameInSection:section withType:type];
            } else if ([self _needToPrepareToStickViewInSection:section withType:type]) {
                sectionView.frame = [self _prepareToStickFrameInSection:section withType:type];
            } else {
                sectionView.frame = [self _sectionViewFrameInSection:section withType:type];
            }
        }
    } else {
        for (UIView *sectionView in sectionViews.allValues) {
            MPMakeViewOffset(sectionView, offset);
        }
    }
}

- (void)_setSubviewsOffset:(CGFloat)offset {
    if (_tableFooterView) {
        MPMakeViewOffset(_tableFooterView, offset);
    }
    
    MPTableViewCell *draggingCell = _dragModeAutoScrollDisplayLink ? _draggingCell : nil;
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        if (cell == draggingCell) {
            continue;
        }
        MPMakeViewOffset(cell, offset);
    }
    for (MPTableViewCell *cell in _updateNewCellsDic.allValues) {
        if (cell == draggingCell) {
            continue;
        }
        MPMakeViewOffset(cell, offset);
    }
    
    [self _adjustSectionViews:_displayedSectionViewsDic withOffset:offset];
    [self _adjustSectionViews:_updateNewSectionViewsDic withOffset:offset];
}

- (void)setTableHeaderView:(UIView *)tableHeaderView {
    NSParameterAssert(tableHeaderView != _tableFooterView || !_tableFooterView);
    NSParameterAssert(tableHeaderView != _backgroundView || !_backgroundView);
    if (_tableHeaderView == tableHeaderView && [_tableHeaderView superview] == self) {
        return;
    }
    
    if ([_tableHeaderView superview] == self) {
        [_tableHeaderView removeFromSuperview];
    }
    _tableHeaderView = tableHeaderView;
    
    CGFloat height = 0;
    if (_tableHeaderView) {
        CGRect frame = _tableHeaderView.frame;
        frame.origin = CGPointZero;
        frame.size.width = self.bounds.size.width;
        MPSetFrameForViewWithoutAnimation(_tableHeaderView, frame);
        [self addSubview:_tableHeaderView];
        height = frame.size.height;
    }
    
    if (_contentListPosition.startPos == height) {
        return;
    }
    
    CGFloat offset = height - _contentListPosition.startPos;
    _contentListPosition.startPos += offset;
    _contentListPosition.endPos += offset;
    
    CGPoint contentOffset = self.contentOffset;
    self.contentSize = CGSizeMake(self.bounds.size.width, _contentListPosition.endPos + _tableFooterView.bounds.size.height);
    if (_reloadDataNeededFlag) {
        return;
    }
    
    [UIView performWithoutAnimation:^{
        [self _setSubviewsOffset:offset];
    }];
    
    if (_style == MPTableViewStylePlain && contentOffset.y != self.contentOffset.y) {
        _supplementSubviewsNeededFlag = YES;
    }
    [self _layoutSubviewsInternal];
}

- (void)setTableFooterView:(UIView *)tableFooterView {
    NSParameterAssert(tableFooterView != _tableHeaderView || !_tableHeaderView);
    NSParameterAssert(tableFooterView != _backgroundView || !_backgroundView);
    if (_tableFooterView == tableFooterView && [_tableFooterView superview] == self) {
        return;
    }
    
    CGFloat lastHeight = _tableFooterView.bounds.size.height;
    if ([_tableFooterView superview] == self) {
        [_tableFooterView removeFromSuperview];
    }
    _tableFooterView = tableFooterView;
    
    CGFloat height = 0;
    if (_tableFooterView) {
        CGRect frame = _tableFooterView.frame;
        frame.origin = CGPointMake(0, _contentListPosition.endPos);
        frame.size.width = self.bounds.size.width;
        MPSetFrameForViewWithoutAnimation(_tableFooterView, frame);
        [self addSubview:_tableFooterView];
        height = frame.size.height;
    }
    
    if (lastHeight == height) {
        return;
    }
    
    CGPoint contentOffset = self.contentOffset;
    self.contentSize = CGSizeMake(self.bounds.size.width, _contentListPosition.endPos + _tableFooterView.bounds.size.height);
    if (_reloadDataNeededFlag || contentOffset.y == self.contentOffset.y) {
        return;
    }
    
    if (_style == MPTableViewStylePlain) {
        _supplementSubviewsNeededFlag = YES;
    }
    [self _layoutSubviewsInternal];
}

- (void)setBackgroundView:(UIView *)backgroundView {
    NSParameterAssert(backgroundView != _tableHeaderView || !_tableHeaderView);
    NSParameterAssert(backgroundView != _tableFooterView || !_tableFooterView);
    if (_backgroundView == backgroundView) {
        return;
    }
    
    [_backgroundView removeFromSuperview];
    _backgroundView = backgroundView;
    
    [self _layoutBackgroundViewIfNeeded];
}

- (void)_layoutBackgroundViewIfNeeded {
    if (!_backgroundView) {
        return;
    }
    
    CGRect frame = self.bounds;
    frame.origin.y = self.contentOffset.y;
    MPSetFrameForViewWithoutAnimation(_backgroundView, frame);
    
    if ([_backgroundView superview] != self) {
        [self addSubview:_backgroundView];
        [self insertSubview:_backgroundView belowSubview:_contentWrapperView];
    }
}

- (MPTableReusableView *)sectionHeaderInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    return [_displayedSectionViewsDic objectForKey:_NSIndexPathInSectionForRow(section, MPSectionHeader)];
}

- (MPTableReusableView *)sectionFooterInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    return [_displayedSectionViewsDic objectForKey:_NSIndexPathInSectionForRow(section, MPSectionFooter)];
}

- (MPTableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return nil;
    }
    
    if (indexPath.section < 0 || indexPath.row < 0) {
        NSAssert(NO, @"indexPath.section and indexPath.row can not be negative");
        return nil;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    return cell;
}

- (NSIndexPath *)indexPathForCell:(MPTableViewCell *)cell {
    if (!cell) {
        return nil;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    for (NSIndexPath *indexPath in _displayedCellsDic.allKeys) {
        MPTableViewCell *_cell = [_displayedCellsDic objectForKey:indexPath];
        if (_cell == cell) {
            return indexPath;
        }
    }
    
    return nil;
}

- (NSArray *)visibleCells {
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    return _displayedCellsDic.allValues;
}

- (NSArray *)visibleCellsInRect:(CGRect)rect {
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    if (rect.origin.x > self.bounds.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _contentListPosition.endPos || CGRectGetMaxY(rect) < _contentListPosition.startPos || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *visibleCells = [[NSMutableArray alloc] init];
    
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        if (CGRectIntersectsRect(rect, cell.frame)) {
            [visibleCells addObject:cell];
        }
    }
    
    return visibleCells;
}

- (NSArray *)indexPathsForVisibleRows {
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    return _displayedCellsDic.allKeys;
}

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect {
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    if (rect.origin.x > self.bounds.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _contentListPosition.endPos || CGRectGetMaxY(rect) < _contentListPosition.startPos || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    
    CGFloat offsetY = rect.origin.y;
    if (offsetY < _contentListPosition.startPos) {
        offsetY = _contentListPosition.startPos;
    }
    NSIndexPathStruct beginIndexPath = [self _indexPathAtContentOffsetY:offsetY - _contentListPosition.startPos];
    offsetY = CGRectGetMaxY(rect);
    if (offsetY > _contentListPosition.endPos) {
        offsetY = _contentListPosition.endPos;
    }
    NSIndexPathStruct endIndexPath = [self _indexPathAtContentOffsetY:offsetY - _contentListPosition.startPos];
    
    for (NSInteger i = beginIndexPath.section; i <= endIndexPath.section; i++) {
        MPTableViewSection *section = _sectionsArray[i];
        NSInteger numberOfRows = section.numberOfRows;
        if (i == beginIndexPath.section) {
            NSInteger j;
            if (MPTV_IS_HEADER(beginIndexPath.row)) {
                j = 0;
            } else if (MPTV_IS_FOOTER(beginIndexPath.row)) {
                j = numberOfRows;
            } else {
                j = beginIndexPath.row;
            }
            if (beginIndexPath.section == endIndexPath.section) {
                if (MPTV_IS_HEADER(endIndexPath.row)) {
                    break;
                } else if (endIndexPath.row < MPSectionFooter) {
                    numberOfRows = endIndexPath.row + 1;
                }
                for (; j < numberOfRows; j++) {
                    [indexPaths addObject:_NSIndexPathInSectionForRow(i, j)];
                }
            } else {
                for (; j < numberOfRows; j++) {
                    [indexPaths addObject:_NSIndexPathInSectionForRow(i, j)];
                }
            }
        } else {
            if (i == endIndexPath.section) {
                if (MPTV_IS_HEADER(endIndexPath.row)) {
                    numberOfRows = 0;
                } else if (endIndexPath.row < MPSectionFooter) {
                    numberOfRows = endIndexPath.row + 1;
                }
            }
            for (NSInteger j = 0; j < numberOfRows; j++) {
                [indexPaths addObject:_NSIndexPathInSectionForRow(i, j)];
            }
        }
    }
    
    return indexPaths;
}

- (NSArray *)indexPathsForRowsInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0 || section >= _sectionsArray.count) {
        return nil;
    }
    
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    if (sectionPosition.numberOfRows == 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < sectionPosition.numberOfRows; i++) {
        [indexPaths addObject:_NSIndexPathInSectionForRow(section, i)];
    }
    
    return indexPaths;
}

- (NSArray *)identifiersForReusableCells {
    return _reusableCellsDic.allKeys;
}

- (NSArray *)identifiersForReusableViews {
    return _reusableReusableViewsDic.allKeys;
}

- (NSUInteger)numberOfReusableCellsWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    NSArray *array = [_reusableCellsDic objectForKey:identifier];
    return array.count;
}

- (NSUInteger)numberOfReusableViewsWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    NSArray *array = [_reusableReusableViewsDic objectForKey:identifier];
    return array.count;
}

- (void)clearReusableCellsInCount:(NSUInteger)count withIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    NSMutableArray *array = [_reusableCellsDic objectForKey:identifier];
    NSParameterAssert(count > 0 && count <= array.count);
    if (array.count > 0) {
        NSRange subRange = NSMakeRange(array.count - count, count);
        NSArray *sub = [array subarrayWithRange:subRange];
        [sub makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [array removeObjectsInRange:subRange];
    }
}

- (void)clearReusableViewsInCount:(NSUInteger)count withIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    NSMutableArray *array = [_reusableReusableViewsDic objectForKey:identifier];
    NSParameterAssert(count > 0 && count <= array.count);
    if (array.count > 0) {
        NSRange subRange = NSMakeRange(array.count - count, count);
        NSArray *sub = [array subarrayWithRange:subRange];
        [sub makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [array removeObjectsInRange:subRange];
    }
}

- (void)clearReusableCellsAndViews {
    [self _clearReusableCells];
    [self _clearReusableSectionViews];
}

- (NSIndexPath *)beginIndexPath {
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSIndexPathStruct beginIndexPath = _beginIndexPath;
    if (MPTV_IS_HEADER(beginIndexPath.row) || MPTV_IS_FOOTER(beginIndexPath.row)) {
        beginIndexPath.row = NSNotFound;
    }
    return _NSIndexPathFromStruct(beginIndexPath);
}

- (NSIndexPath *)endIndexPath {
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSIndexPathStruct endIndexPath = _endIndexPath;
    if (MPTV_IS_HEADER(endIndexPath.row) || MPTV_IS_FOOTER(endIndexPath.row)) {
        endIndexPath.row = NSNotFound;
    }
    return _NSIndexPathFromStruct(endIndexPath);
}

- (CGRect)rectForSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (_numberOfSections == 0 || section >= _sectionsArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    frame.origin = CGPointMake(0, _contentListPosition.startPos + sectionPosition.startPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.endPos - sectionPosition.startPos);
    return frame;
}

- (CGRect)rectForHeaderInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (_numberOfSections == 0 || section >= _sectionsArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    frame.origin = CGPointMake(0, _contentListPosition.startPos + sectionPosition.startPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.headerHeight);
    return frame;
}

- (CGRect)rectForFooterInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (_numberOfSections == 0 || section >= _sectionsArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    frame.origin = CGPointMake(0, _contentListPosition.startPos + sectionPosition.startPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.footerHeight);
    return frame;
}

- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return CGRectNull;
    }
    
    if (indexPath.section < 0 || indexPath.row < 0) {
        NSAssert(NO, @"indexPath.section and indexPath.row can not be negative");
        return CGRectNull;
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (_numberOfSections == 0 || indexPath.section >= _sectionsArray.count) {
        return CGRectNull;
    }
    
    MPTableViewSection *section = _sectionsArray[indexPath.section];
    if (indexPath.row >= section.numberOfRows) {
        return CGRectNull;
    }
    
    return [self _cellFrameAtIndexPath:indexPath];
}

- (NSInteger)indexForSectionAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (_numberOfSections == 0 || point.y < _contentListPosition.startPos || point.y > _contentListPosition.endPos) {
        return NSNotFound;
    } else {
        return [self _sectionAtContentOffsetY:point.y - _contentListPosition.startPos];
    }
}

- (NSInteger)indexForSectionHeaderAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    NSInteger section = [self indexForSectionAtPoint:point];
    if (section != NSNotFound) {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        if (sectionPosition.headerHeight == 0 || sectionPosition.startPos + sectionPosition.headerHeight < point.y - _contentListPosition.startPos) {
            section = NSNotFound;
        }
    }
    
    return section;
}

- (NSInteger)indexForSectionFooterAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    NSInteger section = [self indexForSectionAtPoint:point];
    if (section != NSNotFound) {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        if (sectionPosition.footerHeight == 0 || sectionPosition.endPos - sectionPosition.footerHeight > point.y - _contentListPosition.startPos) {
            section = NSNotFound;
        }
    }
    
    return section;
}

- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (_numberOfSections == 0 || point.y < _contentListPosition.startPos || point.y > _contentListPosition.endPos) {
        return nil;
    }
    
    CGFloat offsetY = point.y;
    if (offsetY < _contentListPosition.startPos) {
        offsetY = _contentListPosition.startPos;
    } else if (offsetY > _contentListPosition.endPos) {
        offsetY = _contentListPosition.endPos;
    }
    
    CGFloat contentOffsetY = offsetY - _contentListPosition.startPos;
    NSInteger section = [self _sectionAtContentOffsetY:contentOffsetY];
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    if (sectionPosition.numberOfRows == 0) {
        return nil;
    }
    NSInteger row = [sectionPosition rowAtContentOffsetY:contentOffsetY];
    if (MPTV_IS_HEADER(row) || MPTV_IS_FOOTER(row)) {
        return nil;
    } else {
        return _NSIndexPathInSectionForRow(section, row);
    }
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (!indexPath) {
        return;
    }
    
    if (indexPath.section < 0 || indexPath.row < 0) {
        NSAssert(NO, @"indexPath.section and indexPath.row can not be negative");
        return;
    }
    
    if (_layoutSubviewsLock) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(indexPath.section < _sectionsArray.count, @"can't scroll to a non-existent section");
    
    MPTableViewSection *section = _sectionsArray[indexPath.section];
    NSAssert(indexPath.row < section.numberOfRows, @"row to scroll is out of bounds");
    
    CGFloat contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            contentOffsetY = [section startPositionAtRow:indexPath.row] - [self _innerContentInset].top;
            if (_respond_viewForHeaderInSection && _style == MPTableViewStylePlain) {
                contentOffsetY -= section.headerHeight;
            }
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat startPos = [section startPositionAtRow:indexPath.row];
            CGFloat endPos = [section endPositionAtRow:indexPath.row];
            contentOffsetY = startPos + (endPos - startPos) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            contentOffsetY = [section endPositionAtRow:indexPath.row] - self.bounds.size.height + [self _innerContentInset].bottom;
            if (_respond_viewForFooterInSection && _style == MPTableViewStylePlain) {
                contentOffsetY += section.footerHeight;
            }
        }
            break;
        default:
            return;
    }
    
    [self _scrollToContentOffsetY:contentOffsetY animated:animated];
}

- (void)_scrollToContentOffsetY:(CGFloat)contentOffsetY animated:(BOOL)animated {
    contentOffsetY += _contentListPosition.startPos;
    CGFloat contentEndPositionY = _contentListPosition.endPos + _tableFooterView.bounds.size.height;
    UIEdgeInsets contentInset = [self _innerContentInset];
    CGFloat contentOffsetMaxY = contentEndPositionY + contentInset.bottom - self.bounds.size.height;
    CGFloat contentOffsetMinY = -contentInset.top;
    
    if (contentOffsetY > contentOffsetMaxY) {
        contentOffsetY = contentOffsetMaxY;
    }
    if (contentOffsetY < contentOffsetMinY) {
        contentOffsetY = contentOffsetMinY;
    }
    
    [self setContentOffset:CGPointMake(0, contentOffsetY) animated:animated];
}

- (void)scrollToHeaderInSection:(NSInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_layoutSubviewsLock) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(section < _sectionsArray.count, @"can't scroll to a non-existent section");
    
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    
    CGFloat contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            contentOffsetY = sectionPosition.startPos - [self _innerContentInset].top;
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat startPos = sectionPosition.startPos;
            CGFloat endPos = sectionPosition.startPos + sectionPosition.headerHeight;
            contentOffsetY = startPos + (endPos - startPos) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            contentOffsetY = sectionPosition.startPos + sectionPosition.headerHeight - self.bounds.size.height + [self _innerContentInset].bottom;
        }
            break;
        default:
            return;
    }
    
    [self _scrollToContentOffsetY:contentOffsetY animated:animated];
}

- (void)scrollToFooterInSection:(NSInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (section < 0) {
        NSAssert(NO, @"section can not be negative");
        section = 0;
    }
    
    if (_layoutSubviewsLock) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(section < _sectionsArray.count, @"can't scroll to a non-existent section");
    
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    
    CGFloat contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            contentOffsetY = sectionPosition.endPos - sectionPosition.footerHeight - [self _innerContentInset].top;
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat startPos = sectionPosition.endPos - sectionPosition.footerHeight;
            CGFloat endPos = sectionPosition.endPos;
            contentOffsetY = startPos + (endPos - startPos) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            contentOffsetY = sectionPosition.endPos - self.bounds.size.height + [self _innerContentInset].bottom;
        }
            break;
        default:
            return;
    }
    
    [self _scrollToContentOffsetY:contentOffsetY animated:animated];
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection {
    if (_updateSubviewsLock) {
        return;
    }
    
    if (_allowsMultipleSelection == allowsMultipleSelection) {
        return;
    }
    
    if (!allowsMultipleSelection) {
        if (_selectedIndexPaths.count > 0) {
            _updateSubviewsLock = YES;
            for (NSIndexPath *indexPath in _selectedIndexPaths) { // not need to be _selectedIndexPaths.allObjects
                [self _deselectRowAtIndexPath:indexPath animated:NO needToRemove:NO needToSetAnimated:YES]; // the cells should call -setSelected:animated:
            }
            [_selectedIndexPaths removeAllObjects];
            _updateSubviewsLock = NO;
        }
    } else {
        _allowsSelection = YES;
    }
    
    _allowsMultipleSelection = allowsMultipleSelection;
}

- (NSIndexPath *)indexPathForSelectedRow {
    return [_selectedIndexPaths anyObject];
}

- (NSArray *)indexPathsForSelectedRows {
    return [_selectedIndexPaths allObjects];
}

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition {
    if (!indexPath) {
        return;
    }
    
    if (indexPath.section < 0 || indexPath.row < 0) {
        NSAssert(NO, @"indexPath.section and indexPath.row can not be negative");
        return;
    }
    
    if (_layoutSubviewsLock || _updateSubviewsLock) {
        return;
    }
    
    if (_layoutSubviewsNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_respond_willSelectRowAtIndexPath) {
        _updateSubviewsLock = YES;
        indexPath = [_tableViewDelegate MPTableView:self willSelectRowAtIndexPath:indexPath];
        _updateSubviewsLock = NO;
        if (!indexPath) {
            return;
        }
        
        if (indexPath.section < 0 || indexPath.row < 0) {
            NSAssert(NO, @"indexPath.section and indexPath.row can not be negative");
            return;
        }
    }
    
    if (indexPath.section >= _sectionsArray.count) {
        return;
    } else {
        MPTableViewSection *section = _sectionsArray[indexPath.section];
        if (indexPath.row >= section.numberOfRows) {
            return;
        }
    }
    
    if ([_selectedIndexPaths containsObject:indexPath]) {
        return;
    }
    
    if (!_allowsMultipleSelection && _selectedIndexPaths.count > 0) {
        _updateSubviewsLock = YES;
        for (NSIndexPath *indexPath in _selectedIndexPaths.allObjects) {
            [self _deselectRowAtIndexPath:indexPath animated:NO needToRemove:YES needToSetAnimated:NO]; // the cells should call -setSelected:
        }
        _updateSubviewsLock = NO;
    }
    
    [_selectedIndexPaths addObject:indexPath];
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    if (cell) {
        [cell setSelected:YES animated:animated];
    }
    [self scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
    
    if (_respond_didSelectRowForCellForRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self didSelectRowForCell:cell forRowAtIndexPath:indexPath];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (_layoutSubviewsLock) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone || _selectedIndexPaths.count == 0) {
        return;
    }
    
    NSIndexPath *nearestSelectedIndexPath = _NSIndexPathInSectionForRow(NSIntegerMax, NSIntegerMax);
    for (NSIndexPath *indexPath in _selectedIndexPaths) {
        if ([indexPath compare:nearestSelectedIndexPath] == NSOrderedAscending) {
            nearestSelectedIndexPath = indexPath;
        }
    }
    if (nearestSelectedIndexPath.section < NSIntegerMax && nearestSelectedIndexPath.row < NSIntegerMax) {
        [self scrollToRowAtIndexPath:nearestSelectedIndexPath atScrollPosition:scrollPosition animated:animated];
    }
}

- (void)_deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated needToRemove:(BOOL)needToRemove needToSetAnimated:(BOOL)needToSetAnimated {
    if (!indexPath) {
        return;
    }
    
    BOOL selected = YES;
    if (needToRemove) {
        if (_respond_willDeselectRowAtIndexPath) {
            selected = [_selectedIndexPaths containsObject:indexPath];
            
            NSIndexPath *newIndexPath = [_tableViewDelegate MPTableView:self willDeselectRowAtIndexPath:indexPath];
            if (!newIndexPath) {
                return;
            }
            
            if (newIndexPath.section < 0 || newIndexPath.row < 0) {
                NSAssert(NO, @"newIndexPath.section and newIndexPath.row can not be negative");
                return;
            }
            
            if (newIndexPath.section >= _sectionsArray.count) {
                return;
            } else {
                MPTableViewSection *section = _sectionsArray[newIndexPath.section];
                if (newIndexPath.row >= section.numberOfRows) {
                    return;
                }
            }
            
            if (![newIndexPath isEqual:indexPath]) {
                selected = [_selectedIndexPaths containsObject:indexPath = newIndexPath];
            }
        }
        
        [_selectedIndexPaths removeObject:indexPath];
    }
    
    if (!selected) {
        return;
    }
    
    MPTableViewCell *selectedCell = [_displayedCellsDic objectForKey:indexPath];
    if (selectedCell) {
        if (needToSetAnimated) {
            [selectedCell setSelected:NO animated:animated];
        } else {
            [selectedCell setSelected:NO];
        }
    }
    
    if (_respond_didDeselectRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self didDeselectRowAtIndexPath:indexPath];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    if (!indexPath) {
        return;
    }
    
    if (indexPath.section < 0 || indexPath.row < 0) {
        NSAssert(NO, @"indexPath.section and indexPath.row can not be negative");
        return;
    }
    
    if (_layoutSubviewsLock || _updateSubviewsLock) {
        return;
    }
    
    if (![_selectedIndexPaths containsObject:indexPath]) {
        return;
    }
    
    _updateSubviewsLock = YES;
    [self _deselectRowAtIndexPath:indexPath animated:animated needToRemove:YES needToSetAnimated:YES];
    _updateSubviewsLock = NO;
}

- (BOOL)isUpdating {
    return _updateAnimationStep != 0;
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (sections.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (_updateContextStep == 0) {
        [self _prepareToDeleteSections:sections withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        sections = [sections copy];
        void (^transactionBlock)(void) = ^{
            [self _prepareToDeleteSections:sections withRowAnimation:animation];
        };
        [updateManager.transactions addObject:transactionBlock];
    }
}

- (void)_prepareToDeleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= _numberOfSections) {
            MPTV_EXCEPTION(@"delete section is out of bounds");
        }
        
        if (![updateManager addDeleteSection:idx withAnimation:animation]) {
            MPTV_EXCEPTION(@"check duplicate update indexPaths");
        }
    }];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (sections.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (_updateContextStep == 0) {
        [self _prepareToInsertSections:sections withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        sections = [sections copy];
        void (^transactionBlock)(void) = ^{
            [self _prepareToInsertSections:sections withRowAnimation:animation];
        };
        [updateManager.transactions addObject:transactionBlock];
    }
}

- (void)_prepareToInsertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    NSInteger numberOfSections;
    if (_respond_numberOfSectionsInMPTableView) {
        _updateSubviewsLock = YES;
        numberOfSections = [_tableViewDataSource numberOfSectionsInMPTableView:self];
        if (numberOfSections < 0) {
            NSAssert(NO, @"the number of sections can not be negative");
            numberOfSections = 0;
        }
        _updateSubviewsLock = NO;
    } else {
        numberOfSections = _numberOfSections;
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= numberOfSections) {
            MPTV_EXCEPTION(@"insert section is out of bounds");
        }
        
        if (![updateManager addInsertSection:idx withAnimation:animation]) {
            MPTV_EXCEPTION(@"check duplicate update indexPaths");
        }
    }];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (sections.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (_updateContextStep == 0) {
        [self _prepareToReloadSections:sections withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        sections = [sections copy];
        void (^transactionBlock)(void) = ^{
            [self _prepareToReloadSections:sections withRowAnimation:animation];
        };
        [updateManager.transactions addObject:transactionBlock];
    }
}

- (void)_prepareToReloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= _numberOfSections) {
            MPTV_EXCEPTION(@"reload section is out of bounds");
        }
        
        if (![updateManager addReloadSection:idx withAnimation:animation]) {
            MPTV_EXCEPTION(@"check duplicate update indexPaths");
        }
    }];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (_updateContextStep == 0) {
        [self _prepareToMoveSection:section toSection:newSection];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        void (^transactionBlock)(void) = ^{
            [self _prepareToMoveSection:section toSection:newSection];
        };
        [updateManager.transactions addObject:transactionBlock];
    }
}

- (void)_prepareToMoveSection:(NSInteger)section toSection:(NSInteger)newSection {
    if (section < 0 || newSection < 0) {
        MPTV_EXCEPTION(@"section and newSection can not be negative");
    }
    
    if (section >= _numberOfSections) {
        MPTV_EXCEPTION(@"move section is out of bounds");
    }
    
    NSInteger numberOfSections;
    if (_respond_numberOfSectionsInMPTableView) {
        _updateSubviewsLock = YES;
        numberOfSections = [_tableViewDataSource numberOfSectionsInMPTableView:self];
        if (numberOfSections < 0) {
            NSAssert(NO, @"the number of sections can not be negative");
            numberOfSections = 0;
        }
        _updateSubviewsLock = NO;
    } else {
        numberOfSections = _numberOfSections;
    }
    
    if (newSection >= numberOfSections) {
        MPTV_EXCEPTION(@"new section to move is out of bounds");
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (![updateManager addMoveOutSection:section]) {
        MPTV_EXCEPTION(@"check duplicate update indexPaths");
    }
    
    if (![updateManager addMoveInSection:newSection fromLastSection:section]) {
        MPTV_EXCEPTION(@"check duplicate update indexPaths");
    }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (indexPaths.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (_updateContextStep == 0) {
        [self _prepareToDeleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        indexPaths = [indexPaths copy];
        void (^transactionBlock)(void) = ^{
            [self _prepareToDeleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        };
        [updateManager.transactions addObject:transactionBlock];
    }
}

- (void)_prepareToDeleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section < 0 || indexPath.row < 0) {
            MPTV_EXCEPTION(@"indexPath.section and indexPath.row can not be negative");
        }
        
        if (indexPath.section >= _numberOfSections) {
            MPTV_EXCEPTION(@"delete section is out of bounds");
        }
        
        MPTableViewSection *section = _sectionsArray[indexPath.section];
        if (indexPath.row >= section.numberOfRows) {
            MPTV_EXCEPTION(@"delete row is out of bounds");
        }
        
        if (![updateManager addDeleteIndexPath:indexPath withAnimation:animation]) {
            MPTV_EXCEPTION(@"check duplicate update indexPaths");
        }
    }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (indexPaths.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (_updateContextStep == 0) {
        [self _prepareToInsertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        indexPaths = [indexPaths copy];
        void (^transactionBlock)(void) = ^{
            [self _prepareToInsertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        };
        [updateManager.transactions addObject:transactionBlock];
    }
}

- (void)_prepareToInsertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section < 0 || indexPath.row < 0) {
            MPTV_EXCEPTION(@"indexPath.section and indexPath.row can not be negative");
        }
        
        if (indexPath.section >= _numberOfSections) {
            MPTV_EXCEPTION(@"insert section is out of bounds");
        }
        
        if (![updateManager addInsertIndexPath:indexPath withAnimation:animation]) {
            MPTV_EXCEPTION(@"check duplicate update indexPaths");
        }
    }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (indexPaths.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (_updateContextStep == 0) {
        [self _prepareToReloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        indexPaths = [indexPaths copy];
        void (^transactionBlock)(void) = ^{
            [self _prepareToReloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        };
        [updateManager.transactions addObject:transactionBlock];
    }
}

- (void)_prepareToReloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section < 0 || indexPath.row < 0) {
            MPTV_EXCEPTION(@"indexPath.section and indexPath.row can not be negative");
        }
        
        if (indexPath.section >= _numberOfSections) {
            MPTV_EXCEPTION(@"reload section is out of bounds");
        }
        
        MPTableViewSection *section = _sectionsArray[indexPath.section];
        if (indexPath.row >= section.numberOfRows) {
            MPTV_EXCEPTION(@"reload row is out of bounds");
        }
        
        if (![updateManager addReloadIndexPath:indexPath withAnimation:animation]) {
            MPTV_EXCEPTION(@"check duplicate update indexPaths");
        }
    }
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    if (!indexPath || !newIndexPath) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (_updateContextStep == 0) {
        [self _prepareToMoveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        void (^transactionBlock)(void) = ^{
            [self _prepareToMoveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
        };
        [updateManager.transactions addObject:transactionBlock];
    }
}

- (void)_prepareToMoveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    if (indexPath.section < 0 || indexPath.row < 0) {
        MPTV_EXCEPTION(@"indexPath.section and indexPath.row can not be negative");
    }
    
    if (newIndexPath.section < 0 || newIndexPath.row < 0) {
        MPTV_EXCEPTION(@"newIndexPath.section and newIndexPath.row can not be negative");
    }
    
    if (indexPath.section >= _numberOfSections) {
        MPTV_EXCEPTION(@"move section is out of bounds");
    }
    
    MPTableViewSection *section = _sectionsArray[indexPath.section];
    if (indexPath.row >= section.numberOfRows) {
        MPTV_EXCEPTION(@"move row is out of bounds");
    }
    
    if (newIndexPath.section >= _numberOfSections) {
        MPTV_EXCEPTION(@"new indexPath to move is out of bounds");
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (![updateManager addMoveOutIndexPath:indexPath]) {
        MPTV_EXCEPTION(@"check duplicate update indexPaths");
    }
    
    if (![updateManager addMoveInIndexPath:newIndexPath withLastIndexPath:indexPath withLastFrame:[self _cellFrameAtIndexPath:indexPath]]) {
        MPTV_EXCEPTION(@"check duplicate update indexPaths");
    }
}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
    [self performBatchUpdates:updates duration:MPTableViewDefaultAnimationDuration delay:0 completion:completion];
}

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(void (^)(BOOL))completion {
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    
    if (_updateSubviewsLock || _draggingIndexPath) {
        return;
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    _updateContextStep++;
    MPTableViewUpdateManager *updateManager;
    if (_updateContextStep > 1) {
        updateManager = [self _pushUpdateManagerToStack];
    } else {
        updateManager = [self _getUpdateManagerFromStack];
    }
    
    if (updates) {
        updates();
    }
    
    for (void (^transaction)(void) in updateManager.transactions) {
        transaction();
    }
    
    [self _updateUsingManager:updateManager duration:duration delay:delay completion:completion];
    [self _popUpdateManagerForStack];
    _updateContextStep--;
}

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options completion:(void (^)(BOOL))completion {
    if (!_tableViewDataSource) {
        NSAssert(NO, @"need a data source");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_reloadDataLock, @"unable to start the update while reloading data");
    NSParameterAssert(!_updateSubviewsLock);
    NSAssert(dampingRatio > MPTableViewInvalidFloatValue, @"invalid dampingRatio");
    NSAssert(velocity > MPTableViewInvalidFloatValue, @"invalid velocity");
    
    if (_updateSubviewsLock || _draggingIndexPath) {
        return;
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    _updateContextStep++;
    MPTableViewUpdateManager *updateManager;
    if (_updateContextStep > 1) {
        updateManager = [self _pushUpdateManagerToStack];
    } else {
        updateManager = [self _getUpdateManagerFromStack];
    }
    
    if (updates) {
        updates();
    }
    
    for (void (^transaction)(void) in updateManager.transactions) {
        transaction();
    }
    
    [self _updateUsingManager:updateManager duration:duration delay:delay options:options usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity completion:completion];
    [self _popUpdateManagerForStack];
    _updateContextStep--;
}

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    
    MPTableViewCell *reusableCell;
    NSMutableArray *queue = [_reusableCellsDic objectForKey:identifier];
    if (queue.count > 0) {
        reusableCell = [queue lastObject];
        [queue removeLastObject];
        reusableCell.hidden = NO;
    } else {
        reusableCell = nil;
    }
    
    if (!reusableCell && _registerCellClassesDic) {
        Class cellClass = [_registerCellClassesDic objectForKey:identifier];
        if (cellClass) {
            reusableCell = [[cellClass alloc] initWithReuseIdentifier:identifier];
        } else {
            reusableCell = nil;
        }
    }
    
    if (!reusableCell && _registerCellNibsDic) {
        UINib *nib = [_registerCellNibsDic objectForKey:identifier];
        if (nib) {
            reusableCell = [nib instantiateWithOwner:self options:nil][0];
            NSParameterAssert([reusableCell isKindOfClass:[MPTableViewCell class]]);
            NSAssert(!reusableCell.reuseIdentifier || [reusableCell.reuseIdentifier isEqualToString:identifier], @"cell reuse indentifier in nib does not match the identifier used to register the nib");
            
            reusableCell.reuseIdentifier = identifier;
        } else {
            reusableCell = nil;
        }
    }
    
    [reusableCell prepareForReuse];
    
    return reusableCell;
}

- (id)dequeueReusableViewWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    
    MPTableReusableView *reusableView;
    NSMutableArray *queue = [_reusableReusableViewsDic objectForKey:identifier];
    if (queue.count > 0) {
        reusableView = [queue lastObject];
        [queue removeLastObject];
        reusableView.hidden = NO;
    } else {
        reusableView = nil;
    }
    
    if (!reusableView && _registerReusableViewClassesDic) {
        Class reusableViewClass = [_registerReusableViewClassesDic objectForKey:identifier];
        if (reusableViewClass) {
            reusableView = [[reusableViewClass alloc] initWithReuseIdentifier:identifier];
        } else {
            reusableView = nil;
        }
    }
    
    if (!reusableView && _registerReusableViewNibsDic) {
        UINib *nib = [_registerReusableViewNibsDic objectForKey:identifier];
        if (nib) {
            reusableView = [nib instantiateWithOwner:self options:nil][0];
            NSParameterAssert([reusableView isKindOfClass:[MPTableReusableView class]]);
            NSAssert(!reusableView.reuseIdentifier || [reusableView.reuseIdentifier isEqualToString:identifier], @"reusable view reuse indentifier in nib does not match the identifier used to register the nib");
            
            reusableView.reuseIdentifier = identifier;
        } else {
            reusableView = nil;
        }
    }
    
    [reusableView prepareForReuse];
    
    return reusableView;
}

- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier {
    NSParameterAssert([cellClass isSubclassOfClass:[MPTableViewCell class]]);
    
    if (!_registerCellClassesDic) {
        _registerCellClassesDic = [[NSMutableDictionary alloc] init];
    }
    [_registerCellClassesDic setObject:cellClass forKey:identifier];
}

- (void)registerClass:(Class)reusableViewClass forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert([reusableViewClass isSubclassOfClass:[MPTableReusableView class]]);
    
    if (!_registerReusableViewClassesDic) {
        _registerReusableViewClassesDic = [[NSMutableDictionary alloc] init];
    }
    [_registerReusableViewClassesDic setObject:reusableViewClass forKey:identifier];
}

- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count > 0);
    
    if (!_registerCellNibsDic) {
        _registerCellNibsDic = [[NSMutableDictionary alloc] init];
    }
    [_registerCellNibsDic setObject:nib forKey:identifier];
}

- (void)registerNib:(UINib *)nib forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count > 0);
    
    if (!_registerReusableViewNibsDic) {
        _registerReusableViewNibsDic = [[NSMutableDictionary alloc] init];
    }
    [_registerReusableViewNibsDic setObject:nib forKey:identifier];
}

#pragma mark - update

- (MPTableViewUpdateManager *)_pushUpdateManagerToStack {
    if (!_updateManagersStack) {
        _updateManagersStack = [[NSMutableArray alloc] init];
        _updateDeletedCellsDic = [[NSMutableDictionary alloc] init];
        _updateDeletedSectionViewsDic = [[NSMutableDictionary alloc] init];
        _updateNewCellsDic = [[NSMutableDictionary alloc] init];
        _updateNewSectionViewsDic = [[NSMutableDictionary alloc] init];
        _updateAnimationBlocks = [[NSMutableArray alloc] init];
        
        _updateAnimatedIndexPaths = [[NSMutableSet alloc] init];
        _updateAnimatedNewIndexPaths = [[NSMutableSet alloc] init];
        
        _updateExchangedSelectedIndexPaths = [[NSMutableSet alloc] init];
        _updateExecutionActions = [[NSMutableArray alloc] init];
    }
    
    MPTableViewUpdateManager *updateManager = [MPTableViewUpdateManager managerForTableView:self andSectionsArray:_sectionsArray];
    [_updateManagersStack addObject:updateManager];
    
    return updateManager;
}

- (MPTableViewUpdateManager *)_getUpdateManagerFromStack {
    MPTableViewUpdateManager *updateManager = [_updateManagersStack lastObject];
    if (!updateManager) {
        updateManager = [self _pushUpdateManagerToStack];
    }
    
    return updateManager;
}

- (void)_popUpdateManagerForStack {
    if (_updateManagersStack.count > 1) { // at least one to be reused
        [_updateManagersStack removeLastObject];
    }
}

- (void)_updateUsingManager:(MPTableViewUpdateManager *)updateManager duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(void (^)(BOOL finished))completion {
    [self _updateUsingManager:updateManager duration:duration delay:delay options:0 usingSpringWithDamping:MPTableViewInvalidFloatValue initialSpringVelocity:MPTableViewInvalidFloatValue completion:completion];
}

- (void)_updateUsingManager:(MPTableViewUpdateManager *)updateManager duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity completion:(void (^)(BOOL finished))completion {
    if (_layoutSubviewsNeededFlag || _reloadDataNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (!_tableViewDataSource) {
        return [updateManager reset];
    }
    
    _supplementSubviewsNeededFlag = NO;
    _updateSubviewsLock = YES; // when _updateSubviewsLock is YES, unable to start a new update transaction.
    _updateAnimationStep++;
    
    BOOL needToCheck = ![self _hasDraggingCell];
    if (needToCheck) {
        updateManager.lastCount = _numberOfSections;
        if (_respond_numberOfSectionsInMPTableView) {
            NSInteger numberOfSections = [_tableViewDataSource numberOfSectionsInMPTableView:self];
            if (numberOfSections < 0) {
                NSAssert(NO, @"the number of sections can not be negative");
                numberOfSections = 0;
            }
            
            if ([updateManager hasUpdateNodes]) {
                _numberOfSections = numberOfSections;
            } else if (numberOfSections != _numberOfSections) {
                MPTV_EXCEPTION(@"check the number of sections from data source");
            }
        }
        updateManager.newCount = _numberOfSections;
    }
    if (![updateManager prepareToUpdateThenNeedToCheck:needToCheck]) {
        MPTV_EXCEPTION(@"check the number of sections after insert or delete");
    }
    _updateInsertedLocationY = _updateDeletedPositionY = 0;
    CGFloat offset = [updateManager update];
    [updateManager reset];
    
    if (_numberOfSections > 0) {
        _contentListPosition.endPos += offset;
    } else {
        _contentListPosition.endPos = _contentListPosition.startPos;
    }
    
    if (_contentListPosition.startPos >= _contentListPosition.endPos) {
        _beginIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
        _endIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
    } else {
        _beginIndexPath = [self _indexPathAtContentOffsetStartPosition];
        _endIndexPath = [self _indexPathAtContentOffsetEndPosition];
    }
    
    if (offset != 0 && !_draggingIndexPath) {
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.startPos < -contentInset.top) {
            _updateWillChangeContentOffset = YES;
            
            CGFloat boundsHeight = self.bounds.size.height;
            _contentOffsetPosition.startPos = -contentInset.top;
            _contentOffsetPosition.endPos = _contentOffsetPosition.startPos + boundsHeight;
            
            _contentListOffsetPosition.startPos = _contentOffsetPosition.startPos - _contentListPosition.startPos;
            _contentListOffsetPosition.endPos = _contentOffsetPosition.endPos - _contentListPosition.startPos;
        } else if (_contentOffsetPosition.startPos > -contentInset.top) {
            CGFloat contentEndPositionY = _contentListPosition.endPos + _tableFooterView.bounds.size.height;
            if (contentEndPositionY + contentInset.bottom < _contentOffsetPosition.endPos) {
                _updateWillChangeContentOffset = YES;
                
                CGFloat boundsHeight = self.bounds.size.height;
                _contentOffsetPosition.endPos = contentEndPositionY + contentInset.bottom;
                _contentOffsetPosition.startPos = _contentOffsetPosition.endPos - boundsHeight;
                
                if (_contentOffsetPosition.startPos < -contentInset.top) {
                    _contentOffsetPosition.startPos = -contentInset.top;
                    _contentOffsetPosition.endPos = _contentOffsetPosition.startPos + boundsHeight;
                }
                
                _contentListOffsetPosition.startPos = _contentOffsetPosition.startPos - _contentListPosition.startPos;
                _contentListOffsetPosition.endPos = _contentOffsetPosition.endPos - _contentListPosition.startPos;
            }
        }
    }
    
    for (void (^action)(void) in _updateExecutionActions) {
        action();
    }
    [_updateExecutionActions removeAllObjects];
    
    [_displayedCellsDic addEntriesFromDictionary:_updateNewCellsDic];
    [_updateNewCellsDic removeAllObjects];
    [_displayedSectionViewsDic addEntriesFromDictionary:_updateNewSectionViewsDic];
    [_updateNewSectionViewsDic removeAllObjects];
    
    if (!_draggingIndexPath) {
        [_updateAnimatedIndexPaths setSet:_updateAnimatedNewIndexPaths];
        [_updateAnimatedNewIndexPaths removeAllObjects];
    }
    
    [_selectedIndexPaths unionSet:_updateExchangedSelectedIndexPaths];
    [_updateExchangedSelectedIndexPaths removeAllObjects];
    
    if (_estimatedCellsDic.count > 0) {
        for (MPTableViewCell *cell in _estimatedCellsDic.allValues) {
            [self _cacheCell:cell];
        }
        [_estimatedCellsDic removeAllObjects];
    }
    
    if (_estimatedSectionViewsDic.count > 0) {
        for (MPTableReusableView *view in _estimatedSectionViewsDic.allValues) {
            [self _cacheSectionView:view];
        }
        [_estimatedSectionViewsDic removeAllObjects];
    }
    
    if (_contentListPosition.startPos >= _contentListPosition.endPos) {
        [self _cancelPrefetchingIfNeeded];
    } else {
        if (_updateWillChangeContentOffset) {
            NSIndexPathStruct newBeginIndexPath = [self _indexPathAtContentOffsetStartPosition];
            NSIndexPathStruct newEndIndexPath = [self _indexPathAtContentOffsetEndPosition];
            
            if ([self _isEstimatedMode]) {
                CGFloat newOffset = [self _estimatedGetOffsetAfterLayoutSubviewsFromFirstIndexPath:newBeginIndexPath];
                if (newOffset != 0) {
                    MPTV_EXCEPTION(@"A critical bug, please contact the author");
                }
                _beginIndexPath = newBeginIndexPath;
                _endIndexPath = newEndIndexPath;
            } else {
                [self _layoutSubviewsBetweenBeginIndexPath:newBeginIndexPath andEndIndexPath:newEndIndexPath];
            }
        }
        
        [self _prefetchIndexPathsIfNeeded];
    }
    
    NSArray *updateAnimationBlocks = _updateAnimationBlocks;
    _updateAnimationBlocks = [[NSMutableArray alloc] init];
    
    NSDictionary *deletedCellsDic = nil;
    if (_updateDeletedCellsDic.count > 0) {
        deletedCellsDic = [NSDictionary dictionaryWithDictionary:_updateDeletedCellsDic];
        [_updateDeletedCellsDic removeAllObjects];
    }
    NSDictionary *deletedSectionViewsDic = nil;
    if (_updateDeletedSectionViewsDic.count > 0) {
        deletedSectionViewsDic = [NSDictionary dictionaryWithDictionary:_updateDeletedSectionViewsDic];
        [_updateDeletedSectionViewsDic removeAllObjects];
    }
    
    void (^animations)(void) = ^{
        for (void (^animationBlock)(void) in updateAnimationBlocks) {
            animationBlock();
        }
        
        if (offset != 0) {
            MPMakeViewOffset(_tableFooterView, offset);
            CGSize contentSize = CGSizeMake(self.bounds.size.width, _contentListPosition.endPos + _tableFooterView.bounds.size.height);
            self.contentSize = contentSize;
            
            if (_updateWillChangeContentOffset) {
                CGPoint contentOffset = self.contentOffset;
                contentOffset.y = _contentOffsetPosition.startPos;
                self.contentOffset = contentOffset;
            }
        }
    };
    
    void (^animationsCompletion)(BOOL finished) = ^(BOOL finished) {
        [self _updateAnimationCompletionWithDeletedCells:deletedCellsDic andDeletedSectionViews:deletedSectionViewsDic];
        if (completion) {
            completion(finished);
        }
    };
    
    if (_optimizesUpdateAnimationsForAutolayout) {
        options |= UIViewAnimationOptionLayoutSubviews;
    }
    
    if (_allowsUserInteractionDuringUpdate && !_draggingIndexPath) {
        options |= UIViewAnimationOptionAllowUserInteraction;
    }
    
    if (dampingRatio == MPTableViewInvalidFloatValue) {
        [UIView animateWithDuration:duration delay:delay options:options animations:animations completion:animationsCompletion];
    } else {
        [UIView animateWithDuration:duration delay:delay usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity options:options animations:animations completion:animationsCompletion];
    }
    
    _updateWillChangeContentOffset = NO;
    _updateSubviewsLock = NO;
}

- (void)_updateAnimationCompletionWithDeletedCells:(NSDictionary *)deletedCellsDic andDeletedSectionViews:(NSDictionary *)deletedSectionViewsDic {
    _updateSubviewsLock = YES;
    _updateAnimationStep--;
    
    if (_respond_didEndDisplayingCellForRowAtIndexPath) {
        for (NSIndexPath *indexPath in deletedCellsDic.allKeys) {
            MPTableViewCell *cell = [deletedCellsDic objectForKey:indexPath];
            [cell removeFromSuperview];
            
            [_tableViewDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
        }
    } else {
        [deletedCellsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    if (_respond_didEndDisplayingHeaderViewForSection || _respond_didEndDisplayingFooterViewForSection) {
        for (NSIndexPath *indexPath in deletedSectionViewsDic.allKeys) {
            MPTableReusableView *sectionView = [deletedSectionViewsDic objectForKey:indexPath];
            [sectionView removeFromSuperview];
            
            MPSectionViewType type = indexPath.row;
            [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section withType:type];
        }
    } else {
        [deletedSectionViewsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    if (_updateAnimationStep == 0 && !_layoutSubviewsNeededFlag && !_reloadDataNeededFlag) {
        if (!_draggingIndexPath) {
            [_updateAnimatedIndexPaths removeAllObjects];
        }
        
        NSIndexPathStruct beginIndexPathStruct;
        NSIndexPathStruct endIndexPathStruct;
        [self _setContentOffsetPositions];
        if (_contentListPosition.startPos >= _contentListPosition.endPos) {
            _beginIndexPath = beginIndexPathStruct = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
            _endIndexPath = endIndexPathStruct = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
        } else {
            beginIndexPathStruct = [self _indexPathAtContentOffsetStartPosition];
            endIndexPathStruct = [self _indexPathAtContentOffsetEndPosition];
        }
        
        if (!_NSIndexPathStructEqualToStruct(beginIndexPathStruct, _beginIndexPath) || !_NSIndexPathStructEqualToStruct(endIndexPathStruct, _endIndexPath)) { // needs to layout subviews
            if ([self _isEstimatedMode]) {
                [self _estimatedLayoutSubviewsBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
            } else { // may not be necessary
                [self _normalLayoutSubviewsBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
            }
        } else {
            [self _clipCellsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
            [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
        }
    }
    
    _updateSubviewsLock = NO;
}

- (NSMutableArray *)_updateExecutionActions {
    return _updateExecutionActions;
}

- (CGFloat)_updateGetDeletedPositionY { // not used
    return _updateDeletedPositionY;
}

- (void)_updateSetDeletedPositionY:(CGFloat)deletedPositionY {
    _updateDeletedPositionY = deletedPositionY;
}

- (CGFloat)_updateGetInsertedLocationY {
    return _updateInsertedLocationY;
}

- (void)_updateSetInsertedLocationY:(CGFloat)insertedLocationY {
    _updateInsertedLocationY = insertedLocationY;
}

- (BOOL)_updateNeedToDisplayInPositionStart:(CGFloat)start toEnd:(CGFloat)end withOffset:(CGFloat)offset {
    if (_optimizesNumberOfSubviewsDuringUpdate && !_draggingIndexPath) {
        return MPTV_START_POS(start) <= _contentOffsetPosition.endPos && MPTV_END_POS(end) >= _contentOffsetPosition.startPos;
    }
    
    if (offset > 0) {
        CGFloat lastStart = start - offset;
        return MPTV_START_POS(lastStart) <= _contentOffsetPosition.endPos && MPTV_END_POS(end) >= _contentOffsetPosition.startPos;
    } else if (offset < 0) {
        CGFloat lastEnd = end - offset;
        return MPTV_START_POS(start) <= _contentOffsetPosition.endPos && MPTV_END_POS(lastEnd) >= _contentOffsetPosition.startPos;
    } else {
        return MPTV_START_POS(start) <= _contentOffsetPosition.endPos && MPTV_END_POS(end) >= _contentOffsetPosition.startPos;
    }
}

- (BOOL)_updateNeedToDisplayForSection:(MPTableViewSection *)section withUpdateType:(MPTableViewUpdateType)type withOffset:(CGFloat)offset {
    if (MPTV_IS_STABLE_UPDATE_TYPE(type)) { // offset should be 0 if this is an insertion
        if ([self _updateNeedToDisplayInPositionStart:section.startPos + _contentListPosition.startPos toEnd:section.endPos + _contentListPosition.startPos withOffset:offset]) {
            return YES;
        } else {
            return NO;
        }
    } else if (MPTV_IS_UNSTABLE_UPDATE_TYPE(type)) { // a reload is split into a deletion and an insertion
        if ([self _hasDisplayedInSection:section]) {
            return YES;
        } else {
            return [self _updateHasHumbleCellsInLastSection:section.section];
        }
    } else { // adjust
        if (_draggingIndexPath) {
            if ([self _isEstimatedMode]) {
                return YES;
            }
        } else {
            if (_reloadsAllDataDuringUpdate) {
                return YES;
            }
        }
        
        if (section.updatePart) {
            return [self _updateNecessaryToAdjustSection:section withOffset:offset];
        } else {
            if ([self _hasDisplayedInSection:section] || [self _updateNeedToDisplayInPositionStart:section.startPos + offset + _contentListPosition.startPos toEnd:section.endPos + offset + _contentListPosition.startPos withOffset:offset]) {
                return YES;
            } else {
                return NO;
            }
        }
    }
}

- (BOOL)_updateHasHumbleCellsInLastSection:(NSInteger)lastSection {
    for (NSIndexPath *indexPath in _selectedIndexPaths) {
        if (indexPath.section == lastSection) {
            return YES;
        }
    }
    
    for (NSIndexPath *indexPath in _updateAnimatedIndexPaths) {
        if (indexPath.section == lastSection) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)_updateNecessaryToAdjustSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    return section.section <= _endIndexPath.section || MPTV_START_POS(section.startPos + offset) <= _contentListOffsetPosition.endPos;
}

- (BOOL)_updateNeedToAdjustHumbleCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow {
    NSIndexPath *lastIndexPath = nil;
    if (lastSection != section || lastRow != row) {
        lastIndexPath = _NSIndexPathInSectionForRow(lastSection, lastRow);
        if ([_selectedIndexPaths containsObject:lastIndexPath]) {
            [_selectedIndexPaths removeObject:lastIndexPath];
            NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
            [_updateExchangedSelectedIndexPaths addObject:indexPath];
        }
    }
    
    if (_updateAnimatedIndexPaths.count > 0) {
        lastIndexPath = lastIndexPath ? : _NSIndexPathInSectionForRow(lastSection, lastRow);
        return [_updateAnimatedIndexPaths containsObject:lastIndexPath];
    } else {
        return NO;
    }
}

- (BOOL)_updateHasHumbleSectionViewInLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type {
    if (_updateAnimatedIndexPaths.count > 0) {
        NSIndexPath *lastIndexPath = _NSIndexPathInSectionForRow(lastSection, type);
        return [_updateAnimatedIndexPaths containsObject:lastIndexPath];
    } else {
        return NO;
    }
}

- (MPTableViewSection *)_updateBuildSection:(NSInteger)section {
    MPTableViewSection *sectionPosition = [MPTableViewSection section];
    sectionPosition.section = section;
    
    CGFloat offset = 0;
    if (_sectionsArray.count > 0 && section > 0) { // verified
        MPTableViewSection *frontSection = _sectionsArray[section - 1];
        offset = frontSection.endPos;
    }
    
    [self _buildSection:sectionPosition withOffset:offset];
    
    return sectionPosition;
}

- (void)_updateAnimationBlockSetFrame:(CGRect)frame forSubview:(UIView *)subview {
    if (CGRectEqualToRect(subview.frame, frame)) {
        return;
    }
    
    void (^animationBlock)(void) = ^{
        subview.frame = frame;
    };
    [_updateAnimationBlocks addObject:animationBlock];
}

#pragma mark - update cell

- (CGFloat)_updateGetInsertCellHeightInSection:(NSInteger)section atRow:(NSInteger)row {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    CGFloat height;
    
    if (_respond_estimatedHeightForRowAtIndexPath) { // verified
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        CGFloat startPos = [sectionPosition startPositionAtRow:row];
        
        CGRect frame;
        frame.origin = CGPointMake(0, startPos);
        frame.size.width = self.bounds.size.width;
        height = frame.size.height = [_tableViewDataSource MPTableView:self estimatedHeightForRowAtIndexPath:indexPath];
        if (_reloadsAllDataDuringUpdate || MPTV_ON_SCREEN(frame)) { // needs to load height
            if (_respond_heightForRowAtIndexPath) {
                height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
            } else {
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                height = frame.size.height = MPGetViewHeightAfterLayout(cell, frame.size.width);
                
                if (MPTV_OFF_SCREEN(frame)) {
                    [self _cacheCell:cell];
                } else {
                    [_estimatedCellsDic setObject:cell forKey:indexPath];
                }
            }
        }
    } else if (_respond_heightForRowAtIndexPath) {
        height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else {
        height = _rowHeight;
    }
    
    if (height < 0) {
        NSAssert(NO, @"cell height can not be less than 0");
        height = 0;
    }
    
    return height;
}

- (CGFloat)_updateGetMoveInCellDifferInSection:(NSInteger)section atRow:(NSInteger)row withLastIndexPath:(NSIndexPath *)lastIndexPath withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    if (_respond_estimatedHeightForRowAtIndexPath && !_reloadsAllDataDuringUpdate) {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (![self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
            return 0;
        }
    }
    
    CGFloat height;
    if (_respond_heightForRowAtIndexPath) {
        height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respond_estimatedHeightForRowAtIndexPath) {
        if ([_displayedCellsDic objectForKey:lastIndexPath]) {
            height = lastHeight;
        } else {
            MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            CGRect frame = [self _cellFrameAtIndexPath:indexPath];
            height = MPGetViewHeightAfterLayout(cell, frame.size.width);
            
            CGFloat lastHeight = frame.size.height;
            frame.size.height = height;
            if ((lastHeight > 0 || frame.size.height > 0) && [self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
                [_estimatedCellsDic setObject:cell forKey:indexPath];
            } else {
                [self _cacheCell:cell];
            }
        }
    } else {
        height = _rowHeight;
    }
    
    if (height < 0) {
        NSAssert(NO, @"cell height can not be less than 0");
        height = 0;
    }
    
    return height - lastHeight;
}

- (CGFloat)_updateGetAdjustCellDifferInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withOffset:(CGFloat)offset needToLoadHeight:(BOOL *)needToLoadHeight {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    
    if (_draggingIndexPath) { // only in estimated mode
        NSIndexPath *lastIndexPath = _NSIndexPathInSectionForRow(lastSection, lastRow);
        if ([_displayedCellsDic objectForKey:lastIndexPath]) {
            return 0;
        }
        
        if (MPTV_START_POS(frame.origin.y) > _contentOffsetPosition.endPos) { // verified
            *needToLoadHeight = NO;
            
            return 0;
        }
    } else {
        if (!_reloadsAllDataDuringUpdate && ![self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:offset]) {
            if (MPTV_START_POS(frame.origin.y) > _contentOffsetPosition.endPos) {
                *needToLoadHeight = NO;
            }
            
            return 0;
        }
    }
    
    CGFloat lastHeight = frame.size.height;
    if (_respond_heightForRowAtIndexPath) {
        frame.size.height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respond_estimatedHeightForRowAtIndexPath) {
        NSIndexPath *lastIndexPath = _NSIndexPathInSectionForRow(lastSection, lastRow);
        if ([_displayedCellsDic objectForKey:lastIndexPath]) {
            frame.size.height = lastHeight;
        } else {
            MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            frame.size.height = MPGetViewHeightAfterLayout(cell, frame.size.width);
            
            if ((lastHeight > 0 || frame.size.height > 0) && [self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:offset]) {
                [_estimatedCellsDic setObject:cell forKey:indexPath];
            } else {
                [self _cacheCell:cell];
            }
        }
    } else {
        frame.size.height = _rowHeight;
    }
    
    if (frame.size.height < 0) {
        NSAssert(NO, @"cell height can not be less than 0");
        frame.size.height = 0;
    }
    
    return frame.size.height - lastHeight;
}

- (CGFloat)_updateGetRebuildCellDifferInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance needToLoadHeight:(BOOL *)needToLoadHeight { // the distance should be 0 if this is for an insertion
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    if (lastSection != section) { // movement
        if (!_respond_heightForRowAtIndexPath && [_displayedCellsDic objectForKey:_NSIndexPathInSectionForRow(lastSection, row)]) {
            return 0;
        }
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (_respond_estimatedHeightForRowAtIndexPath && !_reloadsAllDataDuringUpdate && ![self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
        if (MPTV_START_POS(frame.origin.y) > _contentOffsetPosition.endPos) {
            *needToLoadHeight = NO;
        }
        
        return 0;
    }
    
    CGFloat lastHeight = frame.size.height;
    if (_respond_heightForRowAtIndexPath) {
        frame.size.height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respond_estimatedHeightForRowAtIndexPath) {
        MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        frame.size.height = MPGetViewHeightAfterLayout(cell, frame.size.width);
        
        if ((lastHeight > 0 || frame.size.height > 0) && [self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
            [_estimatedCellsDic setObject:cell forKey:indexPath];
        } else {
            [self _cacheCell:cell];
        }
    } else {
        frame.size.height = _rowHeight;
    }
    
    if (frame.size.height < 0) {
        NSAssert(NO, @"cell height can not be less than 0");
        frame.size.height = 0;
    }
    
    return frame.size.height - lastHeight;
}

- (void)_updateDeleteCellInSection:(NSInteger)lastSection atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(lastSection, row);
    
    if ([_selectedIndexPaths containsObject:indexPath]) {
        [_selectedIndexPaths removeObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    if (!cell) {
        return;
    }
    
    CGFloat deletedPositionY = _updateDeletedPositionY + _contentListPosition.startPos;
    if (animation == MPTableViewRowAnimationCustom) {
        NSAssert(_respond_beginToDeleteCellForRowAtIndexPath, @"need - (void)MPTableView:(MPTableView *)tableView beginToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withProposedPosition:(CGPoint)proposedPosition");
        if (_respond_beginToDeleteCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self beginToDeleteCell:cell forRowAtIndexPath:indexPath withProposedPosition:CGPointMake(0, deletedPositionY)];
        } else {
            [cell removeFromSuperview];
        }
    } else {
        if (animation == MPTableViewRowAnimationNone) {
            [cell removeFromSuperview];
        } else {
            if (animation == MPTableViewRowAnimationTop) {
                [_contentWrapperView sendSubviewToBack:cell];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [_contentWrapperView bringSubviewToFront:cell];
            }
            
            void (^animationBlock)(void) = ^{
                MPMakeViewDisappearWithAnimation(cell, deletedPositionY, animation, sectionPosition);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_updateDeletedCellsDic setObject:cell forKey:indexPath];
        }
    }
    
    [_displayedCellsDic removeObjectForKey:indexPath];
    [_updateAnimatedIndexPaths removeObject:indexPath];
}

- (void)_updateInsertCellToSection:(NSInteger)section atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition atInsertedLocationY:(CGFloat)insertedLocationY {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (MPTV_OFF_SCREEN(frame)) {
        return;
    }
    
    MPTableViewCell *cell = nil;
    if (_respond_estimatedHeightForRowAtIndexPath && !_respond_heightForRowAtIndexPath) {
        cell = [_estimatedCellsDic objectForKey:indexPath];
    }
    
    if (!cell) {
        cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
    } else {
        [_estimatedCellsDic removeObjectForKey:indexPath];
    }
    
    [_updateAnimatedNewIndexPaths addObject:indexPath];
    [_updateNewCellsDic setObject:cell forKey:indexPath];
    [self _addToSuperviewIfNecessaryForCell:cell];
    MPSetFrameForViewWithoutAnimation(cell, frame);
    
    if (_respond_willDisplayCellForRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    
    insertedLocationY += _contentListPosition.startPos;
    if (animation == MPTableViewRowAnimationCustom) {
        NSAssert(_respond_beginToInsertCellForRowAtIndexPath, @"need - (void)MPTableView:(MPTableView *)tableView beginToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withProposedLocation:(CGPoint)proposedLocation");
        if (_respond_beginToInsertCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self beginToInsertCell:cell forRowAtIndexPath:indexPath withProposedLocation:CGPointMake(0, insertedLocationY)];
        }
    } else {
        if (animation != MPTableViewRowAnimationNone) {
            if (animation == MPTableViewRowAnimationTop) {
                [_contentWrapperView sendSubviewToBack:cell];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [_contentWrapperView bringSubviewToFront:cell];
            }
            
            CGFloat alpha = cell.alpha;
            [UIView performWithoutAnimation:^{
                MPMakeViewDisappearWithAnimation(cell, insertedLocationY, animation, sectionPosition);
            }];
            
            void (^animationBlock)(void) = ^{
                MPMakeViewAppearWithAnimation(cell, frame, alpha, animation);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
        }
    }
}

- (void)_updateMoveCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    NSIndexPath *lastIndexPath = _NSIndexPathInSectionForRow(lastSection, lastRow);
    
    if ([_selectedIndexPaths containsObject:lastIndexPath]) {
        [_selectedIndexPaths removeObject:lastIndexPath];
        [_updateExchangedSelectedIndexPaths addObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:lastIndexPath];
    if (cell) {
        [_displayedCellsDic removeObjectForKey:lastIndexPath];
        if (!_draggingIndexPath) {
            [_updateAnimatedIndexPaths removeObject:lastIndexPath];
        }
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    
    if (cell) {
        [_updateNewCellsDic setObject:cell forKey:indexPath];
        [_contentWrapperView bringSubviewToFront:cell];
        if (!_draggingIndexPath) {
            [self _updateAnimationBlockSetFrame:frame forSubview:cell];
            [_updateAnimatedNewIndexPaths addObject:indexPath];
        }
    } else {
        if ((lastHeight <= 0 && frame.size.height <= 0) || ![self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
            return;
        }
        
        if (_respond_estimatedHeightForRowAtIndexPath && !_respond_heightForRowAtIndexPath) {
            cell = [_estimatedCellsDic objectForKey:indexPath];
        }
        
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        } else {
            [_estimatedCellsDic removeObjectForKey:indexPath];
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.size.height = lastHeight;
        frame.origin.y -= distance;
        MPSetFrameForViewWithoutAnimation(cell, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        [self _updateAnimationBlockSetFrame:frame forSubview:cell];
        
        [_updateNewCellsDic setObject:cell forKey:indexPath];
        [self _addToSuperviewIfNecessaryForCell:cell];
        [_contentWrapperView bringSubviewToFront:cell];
        if (!_draggingIndexPath) {
            [_updateAnimatedNewIndexPaths addObject:indexPath];
        }
        
        if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
            [cell setSelected:YES animated:NO];
        }
        
        if (_respond_willDisplayCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
    }
}

- (void)_updateAdjustCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    NSIndexPath *lastIndexPath = _NSIndexPathInSectionForRow(lastSection, lastRow);
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:lastIndexPath];
    
    if (cell) {
        if (!_draggingIndexPath) {
            [_updateAnimatedIndexPaths removeObject:lastIndexPath];
        }
        if (section != lastSection || row != lastRow) {
            [_displayedCellsDic removeObjectForKey:lastIndexPath];
            [_updateNewCellsDic setObject:cell forKey:indexPath];
        }
        
        [_contentWrapperView sendSubviewToBack:cell];
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        [self _updateAnimationBlockSetFrame:frame forSubview:cell];
        if (!_draggingIndexPath) {
            [_updateAnimatedNewIndexPaths addObject:indexPath];
        }
    } else {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if ((lastHeight <= 0 && frame.size.height <= 0) || ![self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:offset]) {
            return;
        }
        
        if (_respond_estimatedHeightForRowAtIndexPath && !_respond_heightForRowAtIndexPath) {
            cell = [_estimatedCellsDic objectForKey:indexPath];
        }
        
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        } else {
            [_estimatedCellsDic removeObjectForKey:indexPath];
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.origin.y -= offset;
        frame.size.height = lastHeight;
        MPSetFrameForViewWithoutAnimation(cell, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        [self _updateAnimationBlockSetFrame:frame forSubview:cell];
        
        [_updateNewCellsDic setObject:cell forKey:indexPath];
        [self _addToSuperviewIfNecessaryForCell:cell];
        [_contentWrapperView sendSubviewToBack:cell];
        if (!_draggingIndexPath) {
            [_updateAnimatedNewIndexPaths addObject:indexPath];
        }
        
        if (section == lastSection && row == lastRow) {
            if ([_selectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES animated:NO];
            }
        } else {
            if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES animated:NO];
            }
        }
        
        if (_respond_willDisplayCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
    }
}

#pragma mark - update section view

- (BOOL)_needToDisplaySectionViewInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type withOffset:(CGFloat)offset { // ignores the situation that height is 0
    CGFloat start, end;
    if (MPTV_IS_HEADER(type)) {
        start = section.startPos + _contentListPosition.startPos;
        end = section.startPos + section.headerHeight + _contentListPosition.startPos;
    } else {
        start = section.endPos - section.footerHeight + _contentListPosition.startPos;
        end = section.endPos + _contentListPosition.startPos;
    }
    
    if ([self _updateNeedToDisplayInPositionStart:start toEnd:end withOffset:offset]) {
        return YES;
    }
    
    if (_style == MPTableViewStylePlain && ([self _needToStickViewInSection:section withType:type] || [self _needToPrepareToStickViewInSection:section withType:type])) {
        return YES;
    }
    
    return NO;
}

- (CGFloat)_getHeaderHeightAfterLayoutInSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    CGFloat height;
    
    MPTableReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:section.section withType:MPSectionHeader];
    if (sectionView) {
        height = MPGetViewHeightAfterLayout(sectionView, self.bounds.size.width);
        
        CGFloat lastHeight = section.headerHeight;
        section.headerHeight = height;
        section.endPos += height - lastHeight;
        
        if ((lastHeight > 0 || height > 0) && [self _needToDisplaySectionViewInSection:section withType:MPSectionHeader withOffset:offset]) {
            NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section.section, MPSectionHeader);
            [_estimatedSectionViewsDic setObject:sectionView forKey:indexPath];
        } else {
            [self _cacheSectionView:sectionView];
        }
        
        section.headerHeight = lastHeight;
        section.endPos -= height - lastHeight;
    } else {
        height = section.headerHeight;
    }
    
    return height;
}

- (CGFloat)_getFooterHeightAfterLayoutInSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    CGFloat height;
    
    MPTableReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:section.section withType:MPSectionFooter];
    if (sectionView) {
        height = MPGetViewHeightAfterLayout(sectionView, self.bounds.size.width);
        
        CGFloat lastHeight = section.footerHeight;
        section.footerHeight = height;
        section.endPos += height - lastHeight;
        
        if ((lastHeight > 0 || height > 0) && [self _needToDisplaySectionViewInSection:section withType:MPSectionFooter withOffset:offset]) {
            NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section.section, MPSectionFooter);
            [_estimatedSectionViewsDic setObject:sectionView forKey:indexPath];
        } else {
            [self _cacheSectionView:sectionView];
        }
        
        section.footerHeight = lastHeight;
        section.endPos -= height - lastHeight;
    } else {
        height = section.footerHeight;
    }
    
    return height;
}

- (CGFloat)_updateGetHeaderHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion {
    if (_draggingIndexPath) { // only in estimated mode
        if ([_displayedSectionViewsDic objectForKey:_NSIndexPathInSectionForRow(lastSection, MPSectionHeader)]) {
            return MPTableViewInvalidFloatValue;
        }
    } else {
        if (!_reloadsAllDataDuringUpdate && _style != MPTableViewStylePlain && ![self _needToDisplaySectionViewInSection:section withType:MPSectionHeader withOffset:offset]) {
            return MPTableViewInvalidFloatValue;
        }
    }
    
    CGFloat height;
    if (_respond_heightForHeaderInSection) {
        height = [_tableViewDataSource MPTableView:self heightForHeaderInSection:section.section];
    } else if (_respond_estimatedHeightForHeaderInSection) {
        if (!isInsertion && [_displayedSectionViewsDic objectForKey:_NSIndexPathInSectionForRow(lastSection, MPSectionHeader)]) {
            return MPTableViewInvalidFloatValue;
        }
        
        height = [self _getHeaderHeightAfterLayoutInSection:section withOffset:offset];
    } else {
        height = _sectionHeaderHeight;
    }
    
    if (height < 0) {
        NSAssert(NO, @"section header height can not be less than 0");
        height = 0;
    }
    
    return height;
}

- (CGFloat)_updateGetFooterHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion {
    if (_draggingIndexPath) { // only in estimated mode
        if ([_displayedSectionViewsDic objectForKey:_NSIndexPathInSectionForRow(lastSection, MPSectionFooter)]) {
            return MPTableViewInvalidFloatValue;
        }
    } else {
        if (!_reloadsAllDataDuringUpdate && _style != MPTableViewStylePlain && ![self _needToDisplaySectionViewInSection:section withType:MPSectionFooter withOffset:offset]) {
            return MPTableViewInvalidFloatValue;
        }
    }
    
    CGFloat height;
    if (_respond_heightForFooterInSection) {
        height = [_tableViewDataSource MPTableView:self heightForFooterInSection:section.section];
    } else if (_respond_estimatedHeightForFooterInSection) {
        if (!isInsertion && [_displayedSectionViewsDic objectForKey:_NSIndexPathInSectionForRow(lastSection, MPSectionFooter)]) {
            return MPTableViewInvalidFloatValue;
        }
        
        height = [self _getFooterHeightAfterLayoutInSection:section withOffset:offset];
    } else {
        height = _sectionFooterHeight;
    }
    
    if (height < 0) {
        NSAssert(NO, @"section footer height can not be less than 0");
        height = 0;
    }
    
    return height;
}

- (void)_updateDeleteSectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (!sectionView) {
        return;
    }
    
    CGFloat deletedPositionY = _updateDeletedPositionY + _contentListPosition.startPos;
    if (animation == MPTableViewRowAnimationCustom) {
        if (MPTV_IS_HEADER(type)) {
            NSAssert(_respond_beginToDeleteHeaderViewForSection, @"need - (void)MPTableView:(MPTableView *)tableView beginToDeleteHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section withProposedPosition:(CGPoint)proposedPosition");
            if (_respond_beginToDeleteHeaderViewForSection) {
                [_tableViewDelegate MPTableView:self beginToDeleteHeaderView:sectionView forSection:section withProposedPosition:CGPointMake(0, deletedPositionY)];
            } else {
                [sectionView removeFromSuperview];
            }
        } else {
            NSAssert(_respond_beginToDeleteFooterViewForSection, @"need - (void)MPTableView:(MPTableView *)tableView beginToDeleteFooterView:(MPTableReusableView *)view forSection:(NSInteger)section withProposedPosition:(CGPoint)proposedPosition");
            if (_respond_beginToDeleteFooterViewForSection) {
                [_tableViewDelegate MPTableView:self beginToDeleteFooterView:sectionView forSection:section withProposedPosition:CGPointMake(0, deletedPositionY)];
            } else {
                [sectionView removeFromSuperview];
            }
        }
    } else {
        if (animation == MPTableViewRowAnimationNone) {
            [sectionView removeFromSuperview];
        } else {
            if (animation == MPTableViewRowAnimationTop) {
                [self insertSubview:sectionView aboveSubview:_contentWrapperView];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [self bringSubviewToFront:sectionView];
            }
            
            void (^animationBlock)(void) = ^{
                MPMakeViewDisappearWithAnimation(sectionView, deletedPositionY, animation, deleteSection);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_updateDeletedSectionViewsDic setObject:sectionView forKey:indexPath];
        }
    }
    
    [_displayedSectionViewsDic removeObjectForKey:indexPath];
    [_updateAnimatedIndexPaths removeObject:indexPath];
}

- (void)_updateInsertSectionViewToSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection atInsertedLocationY:(CGFloat)insertedLocationY {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    
    CGRect frame;
    if (_style == MPTableViewStylePlain) {
        if ([self _needToStickViewInSection:insertSection withType:type]) {
            frame = [self _stickingFrameInSection:insertSection withType:type];
        } else if ([self _needToPrepareToStickViewInSection:insertSection withType:type]) {
            frame = [self _prepareToStickFrameInSection:insertSection withType:type];
        } else {
            frame = [self _sectionViewFrameInSection:insertSection withType:type];
        }
    } else {
        frame = [self _sectionViewFrameInSection:insertSection withType:type];
    }
    
    if (MPTV_OFF_SCREEN(frame)) {
        return;
    }
    
    MPTableReusableView *sectionView = nil;
    if (MPTV_IS_HEADER(type) && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
        sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
    } else if (MPTV_IS_FOOTER(type) && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
        sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
    }
    
    if (!sectionView) {
        sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:type];
    } else {
        [_estimatedSectionViewsDic removeObjectForKey:indexPath];
    }
    
    if (!sectionView) {
        return;
    }
    
    [_updateAnimatedNewIndexPaths addObject:indexPath];
    [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
    [self _addToSuperviewIfNecessaryForSectionView:sectionView];
    MPSetFrameForViewWithoutAnimation(sectionView, frame);
    [self _willDisplaySectionView:sectionView forSection:indexPath.section withType:type];
    
    insertedLocationY += _contentListPosition.startPos;
    if (animation == MPTableViewRowAnimationCustom) {
        if (MPTV_IS_HEADER(type)) {
            NSAssert(_respond_beginToInsertHeaderViewForSection, @"need - (void)MPTableView:(MPTableView *)tableView beginToInsertHeaderView:(MPTableReusableView *)view forSection:(NSInteger)section withProposedLocation:(CGPoint)proposedLocation");
            if (_respond_beginToInsertHeaderViewForSection) {
                [_tableViewDelegate MPTableView:self beginToInsertHeaderView:sectionView forSection:section withProposedLocation:CGPointMake(0, insertedLocationY)];
            }
        } else {
            NSAssert(_respond_beginToInsertFooterViewForSection, @"need - (void)MPTableView:(MPTableView *)tableView beginToInsertFooterView:(MPTableReusableView *)view forSection:(NSInteger)section withProposedLocation:(CGPoint)proposedLocation");
            if (_respond_beginToInsertFooterViewForSection) {
                [_tableViewDelegate MPTableView:self beginToInsertFooterView:sectionView forSection:section withProposedLocation:CGPointMake(0, insertedLocationY)];
            }
        }
    } else {
        if (animation != MPTableViewRowAnimationNone) {
            if (animation == MPTableViewRowAnimationTop) {
                [self insertSubview:sectionView aboveSubview:_contentWrapperView];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [self bringSubviewToFront:sectionView];
            }
            
            CGFloat alpha = sectionView.alpha;
            [UIView performWithoutAnimation:^{
                MPMakeViewDisappearWithAnimation(sectionView, insertedLocationY, animation, insertSection);
            }];
            
            void (^animationBlock)(void) = ^{
                MPMakeViewAppearWithAnimation(sectionView, frame, alpha, animation);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
        }
    }
}

- (void)_updateMoveSectionViewToSection:(NSInteger)section fromLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    NSIndexPath *lastIndexPath = _NSIndexPathInSectionForRow(lastSection, type);
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:lastIndexPath];
    if (sectionView) {
        [_displayedSectionViewsDic removeObjectForKey:lastIndexPath];
        if (!_draggingIndexPath) {
            [_updateAnimatedIndexPaths removeObject:lastIndexPath];
        }
    }
    
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    CGRect frame = [self _sectionViewFrameInSection:sectionPosition withType:type]; // verified
    CGFloat lastOriginY = frame.origin.y;
    if (_style == MPTableViewStylePlain) {
        if ([self _needToStickViewInSection:sectionPosition withType:type]) {
            frame = [self _stickingFrameInSection:sectionPosition withType:type];
        } else if ([self _needToPrepareToStickViewInSection:sectionPosition withType:type]) {
            frame = [self _prepareToStickFrameInSection:sectionPosition withType:type];
        }
    }
    
    if (sectionView) {
        [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
        [self bringSubviewToFront:sectionView];
        [self _updateAnimationBlockSetFrame:frame forSubview:sectionView];
        [_updateAnimatedNewIndexPaths addObject:indexPath];
    } else {
        if ((lastHeight <= 0 && frame.size.height <= 0) || ![self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
            return;
        }
        
        if (MPTV_IS_HEADER(type) && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:type];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.origin.y = lastOriginY - distance;
        frame.size.height = lastHeight;
        MPSetFrameForViewWithoutAnimation(sectionView, frame);
        frame.size.height = height;
        frame.origin.y = originY;
        [self _updateAnimationBlockSetFrame:frame forSubview:sectionView];
        
        [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
        [self _addToSuperviewIfNecessaryForSectionView:sectionView];
        [self bringSubviewToFront:sectionView];
        [_updateAnimatedNewIndexPaths addObject:indexPath];
        [self _willDisplaySectionView:sectionView forSection:indexPath.section withType:type];
    }
}

- (void)_updateAdjustSectionViewToSection:(NSInteger)section fromLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)offset {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    NSIndexPath *lastIndexPath = _NSIndexPathInSectionForRow(lastSection, type);
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:lastIndexPath];
    
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    CGRect frame;
    if (_style == MPTableViewStylePlain) {
        if ([self _needToStickViewInSection:sectionPosition withType:type]) {
            frame = [self _stickingFrameInSection:sectionPosition withType:type];
        } else if ([self _needToPrepareToStickViewInSection:sectionPosition withType:type]) {
            frame = [self _prepareToStickFrameInSection:sectionPosition withType:type];
        } else {
            frame = [self _sectionViewFrameInSection:sectionPosition withType:type];
        }
    } else {
        frame = [self _sectionViewFrameInSection:sectionPosition withType:type];
    }
    
    if (sectionView) {
        if (!_draggingIndexPath) {
            [_updateAnimatedIndexPaths removeObject:lastIndexPath];
        }
        if (lastSection != section) {
            [_displayedSectionViewsDic removeObjectForKey:lastIndexPath];
            [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
        }
        
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
        [self _updateAnimationBlockSetFrame:frame forSubview:sectionView];
        if (!_draggingIndexPath) {
            [_updateAnimatedNewIndexPaths addObject:indexPath];
        }
    } else {
        if ((lastHeight <= 0 && frame.size.height <= 0) || ![self _updateNeedToDisplayInPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:offset]) {
            return;
        }
        
        if (MPTV_IS_HEADER(type) && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:type];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.origin.y -= offset;
        frame.size.height = lastHeight;
        MPSetFrameForViewWithoutAnimation(sectionView, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        [self _updateAnimationBlockSetFrame:frame forSubview:sectionView];
        
        [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
        [self _addToSuperviewIfNecessaryForSectionView:sectionView];
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
        if (!_draggingIndexPath) {
            [_updateAnimatedNewIndexPaths addObject:indexPath];
        }
        [self _willDisplaySectionView:sectionView forSection:indexPath.section withType:type];
    }
}

#pragma mark - estimated layout

- (BOOL)_isEstimatedMode {
    return _respond_estimatedHeightForRowAtIndexPath || _respond_estimatedHeightForHeaderInSection || _respond_estimatedHeightForFooterInSection;
}

- (BOOL)_needToEstimateHeightForRow {
    return _respond_estimatedHeightForRowAtIndexPath;
}

- (BOOL)_needToEstimateHeightForHeader {
    return _respond_estimatedHeightForHeaderInSection;
}

- (BOOL)_needToEstimateHeightForFooter {
    return _respond_estimatedHeightForFooterInSection;
}

- (BOOL)_hasDisplayedInSection:(MPTableViewSection *)section {
    return section.section >= _beginIndexPath.section && section.section <= _endIndexPath.section;
}

- (BOOL)_estimatedNeedToDisplayForSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    if ([self isUpdating] && _updateAnimatedIndexPaths.count > 0) {
        for (NSIndexPath *indexPath in _updateAnimatedIndexPaths) {
            if (indexPath.section == section.section) {
                return YES;
            }
        }
    }
    
    if (_draggingIndexPath && _draggingIndexPath.section == section.section) {
        return YES;
    }
    
    return [self _hasDisplayedInSection:section] || (MPTV_START_POS(section.startPos + offset) <= _contentListOffsetPosition.endPos && MPTV_END_POS(section.endPos + offset) >= _contentListOffsetPosition.startPos);
}

- (void)_estimatedLayoutSubviewsFromFirstIndexPath:(NSIndexPathStruct)firstIndexPath {
    CGFloat offset = [self _estimatedGetOffsetAfterLayoutSubviewsFromFirstIndexPath:firstIndexPath];
    
    _contentListPosition.endPos += offset;
    if (_contentListPosition.startPos >= _contentListPosition.endPos) {
        _beginIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
        _endIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
    } else {
        _beginIndexPath = [self _indexPathAtContentOffsetStartPosition];
        _endIndexPath = [self _indexPathAtContentOffsetEndPosition];
    }
    
    if (_estimatedCellsDic.count > 0) {
        for (MPTableViewCell *cell in _estimatedCellsDic.allValues) {
            [self _cacheCell:cell];
        }
        [_estimatedCellsDic removeAllObjects];
    }
    if (_estimatedSectionViewsDic.count > 0) {
        for (MPTableReusableView *view in _estimatedSectionViewsDic.allValues) {
            [self _cacheSectionView:view];
        }
        [_estimatedSectionViewsDic removeAllObjects];
    }
    
    [self _clipCellsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    
    if (offset != 0) {
        [UIView performWithoutAnimation:^{
            MPMakeViewOffset(_tableFooterView, offset);
        }];
        
        CGSize contentSize = CGSizeMake(self.bounds.size.width, _contentListPosition.endPos + _tableFooterView.bounds.size.height);
        self.contentSize = contentSize;
        
        BOOL needToChangeContentOffset = NO;
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.startPos < -contentInset.top) {
            needToChangeContentOffset = YES;
        } else if (_contentOffsetPosition.startPos > -contentInset.top) {
            if (contentSize.height + contentInset.bottom < _contentOffsetPosition.endPos) {
                needToChangeContentOffset = YES;
            }
        }
        
        if (needToChangeContentOffset) {
            // Change an UIScrollView's content size when it is bouncing will make -layoutSubviews can not be called in the next runloop. This situation is possibly caused by an UIKit bug.
            CFRunLoopRef runLoop = CFRunLoopGetCurrent();
            CFStringRef runLoopMode = kCFRunLoopCommonModes;
            CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, false, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
                [self _layoutSubviewsInternal];
            });
            CFRunLoopAddObserver(runLoop, observer, runLoopMode);
            CFRelease(observer);
        }
    }
}

- (CGFloat)_estimatedGetOffsetAfterLayoutSubviewsFromFirstIndexPath:(NSIndexPathStruct)firstIndexPath {
    CGFloat offset = 0;
    
    BOOL isOptimizable = ![self isUpdating] && ![self _hasDraggingCell];
    for (NSInteger i = firstIndexPath.section; i < _numberOfSections; i++) {
        MPTableViewSection *section = _sectionsArray[i];
        
        BOOL needToDisplay = [self _estimatedNeedToDisplayForSection:section withOffset:offset];
        if (!needToDisplay && offset == 0) {
            if (isOptimizable) {
                break;
            } else {
                continue;
            }
        }
        NSInteger firstRow = 0;
        if (i == firstIndexPath.section) {
            MPSectionViewType type = firstIndexPath.row;
            if (MPTV_IS_HEADER(type)) {
                firstRow = 0;
            } else if (MPTV_IS_FOOTER(type)) {
                firstRow = section.numberOfRows;
            } else {
                firstRow = firstIndexPath.row;
            }
        }
        
        offset = [section estimateForTableView:self atFirstRow:firstRow withOffset:offset needToDisplay:needToDisplay];
    }
    
    return offset;
}

- (CGFloat)_estimatedGetHeaderHeightInSection:(MPTableViewSection *)section {
    if (_updateWillChangeContentOffset) {
        return MPTableViewInvalidFloatValue;
    }
    
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section.section, MPSectionHeader);
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (sectionView) {
        return MPTableViewInvalidFloatValue;
    }
    
    if ([self _needToDisplaySectionViewInSection:section withType:MPSectionHeader withOffset:0]) {
        CGFloat height;
        if (_respond_heightForHeaderInSection) {
            height = [_tableViewDataSource MPTableView:self heightForHeaderInSection:section.section];
        } else {
            height = [self _getHeaderHeightAfterLayoutInSection:section withOffset:0];
        }
        
        if (height < 0) {
            NSAssert(NO, @"section header height can not be less than 0");
            height = 0;
        }
        
        return height;
    } else {
        return MPTableViewInvalidFloatValue;
    }
}

- (CGFloat)_estimatedGetFooterHeightInSection:(MPTableViewSection *)section {
    if (_updateWillChangeContentOffset) {
        return MPTableViewInvalidFloatValue;
    }
    
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section.section, MPSectionFooter);
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (sectionView) {
        return MPTableViewInvalidFloatValue;
    }
    
    if ([self _needToDisplaySectionViewInSection:section withType:MPSectionFooter withOffset:0]) {
        CGFloat height;
        if (_respond_heightForFooterInSection) {
            height = [_tableViewDataSource MPTableView:self heightForFooterInSection:section.section];
        } else {
            height = [self _getFooterHeightAfterLayoutInSection:section withOffset:0];
        }
        
        if (height < 0) {
            NSAssert(NO, @"section footer height can not be less than 0");
            height = 0;
        }
        
        return height;
    } else {
        return MPTableViewInvalidFloatValue;
    }
}

- (CGFloat)_estimatedDisplayCellInSection:(NSInteger)section atRow:(NSInteger)row withOffset:(CGFloat)offset needToLoadHeight:(BOOL *)needToLoadHeight {
    CGFloat differ = 0;
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    if (cell) {
        MPTableViewCell *draggingCell = _dragModeAutoScrollDisplayLink ? _draggingCell : nil;
        if (offset != 0 && cell != draggingCell) {
            CGRect frame = cell.frame;
            frame.origin.y += offset;
            MPSetFrameForViewWithoutAnimation(cell, frame);
        }
    } else {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (MPTV_OFF_SCREEN(frame)) {
            BOOL outOfDragged = !_draggingIndexPath || indexPath.section != _draggingIndexPath.section || MPTV_ROW_MORE(indexPath.row, _draggingIndexPath.row);
            if (outOfDragged && MPTV_START_POS(frame.origin.y) > _contentOffsetPosition.endPos && _updateAnimatedIndexPaths.count == 0) { // verified
                *needToLoadHeight = NO;
            }
            
            return 0;
        } else {
            if (_respond_estimatedHeightForRowAtIndexPath && !_updateWillChangeContentOffset) {
                CGFloat lastHeight = frame.size.height;
                if (_respond_heightForRowAtIndexPath) {
                    frame.size.height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
                } else {
                    cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                    frame.size.height = MPGetViewHeightAfterLayout(cell, frame.size.width);
                    if (MPTV_OFF_SCREEN(frame)) {
                        [self _cacheCell:cell];
                    }
                }
                
                if (frame.size.height < 0) {
                    NSAssert(NO, @"cell height can not be less than 0");
                    frame.size.height = 0;
                }
                differ = frame.size.height - lastHeight;
                
                if (MPTV_OFF_SCREEN(frame)) {
                    return differ;
                }
            }
            
            if (!cell) {
                cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            }
            
            [self _addToSuperviewIfNecessaryForCell:cell];
            if ([self isUpdating] || _draggingIndexPath) {
                [_contentWrapperView sendSubviewToBack:cell];
            }
            MPSetFrameForViewWithoutAnimation(cell, frame);
            [_displayedCellsDic setObject:cell forKey:indexPath];
            
            if ([_selectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES animated:NO];
            }
            
            if (_respond_willDisplayCellForRowAtIndexPath) {
                [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
            }
        }
    }
    
    return differ;
}

- (void)_estimatedDisplaySectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (sectionView) {
        return;
    }
    
    BOOL needToStick = NO;
    BOOL needToPrepareToStick = NO;
    
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    if (_style == MPTableViewStylePlain) {
        if ([self _needToStickViewInSection:sectionPosition withType:type]) {
            needToStick = YES;
        } else if ([self _needToPrepareToStickViewInSection:sectionPosition withType:type]) {
            needToPrepareToStick = YES;
        }
    }
    
    CGRect frame = [self _sectionViewFrameInSection:sectionPosition withType:type];
    if (MPTV_OFF_SCREEN(frame) && !needToStick && !needToPrepareToStick) {
        return;
    } else {
        if (MPTV_IS_HEADER(type) && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:type];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        if (_updateWillChangeContentOffset) {
            if (needToStick) {
                frame = [self _stickingFrameInSection:sectionPosition withType:type];
            } else if (needToPrepareToStick) {
                frame = [self _prepareToStickFrameInSection:sectionPosition withType:type];
            }
        }
        
        [self _displaySectionView:sectionView atIndexPath:indexPath withFrame:frame];
    }
}

#pragma mark - reload

- (void)reloadData {
    NSParameterAssert([NSThread isMainThread]);
    if (_layoutSubviewsLock || _updateSubviewsLock) {
        return;
    }
    
    [self _clearDataAndCacheSubviewsEnabled:_cachesSubviewsDuringReload];
    
    CGFloat height = 0;
    if (_tableViewDataSource) {
        _reloadDataLock = YES;
        height = [self _buildSectionsArray:_sectionsArray];
        _numberOfSections = _sectionsArray.count;
        _reloadDataLock = NO;
        
        _layoutSubviewsLock = NO;
        _layoutSubviewsNeededFlag = YES;
        if (!_reloadDataNeededFlag) {
            [self setNeedsLayout];
        }
    } else {
        _layoutSubviewsNeededFlag = NO;
    }
    _reloadDataNeededFlag = NO;
    
    [self _setContentSizeWithContentHeight:height];
}

- (void)reloadDataAsyncWithQueue:(dispatch_queue_t)queue completion:(void (^)(BOOL finished))completion {
    NSParameterAssert(!_reloadDataLock);
    if (_layoutSubviewsLock || _updateSubviewsLock) {
        return;
    }
    
    if (!_tableViewDataSource) {
        return [self reloadData];
    }
    
    _reloadDataNeededFlag = NO;
    _reloadDataLock = YES;
    dispatch_async(queue ? : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *sectionsArray = [[NSMutableArray alloc] init];
        CGFloat height = [self _buildSectionsArray:sectionsArray];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_reloadDataLock) {
                if (completion) {
                    completion(NO);
                }
                return;
            }
            
            _reloadDataLock = NO;
            [self _clearDataAndCacheSubviewsEnabled:_cachesSubviewsDuringReload];
            
            _sectionsArray = sectionsArray;
            _numberOfSections = sectionsArray.count;
            if (_updateManagersStack.count > 0) {
                MPTableViewUpdateManager *updateManager = [_updateManagersStack lastObject]; // there can only be one update manager in this situation
                updateManager.sectionsArray = sectionsArray;
            }
            
            _layoutSubviewsLock = NO;
            [self _setContentSizeWithContentHeight:height];
            if (height != MPTableViewInvalidFloatValue) {
                [self _layoutSubviewsInternal];
            }
            if (completion) {
                completion(YES);
            }
        });
    });
}

- (CGFloat)_buildSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    // header
    section.startPos = offset;
    CGFloat height = 0;
    
    if (_respond_estimatedHeightForHeaderInSection) {
        height = [_tableViewDataSource MPTableView:self estimatedHeightForHeaderInSection:section.section];
    } else if (_respond_heightForHeaderInSection) {
        height = [_tableViewDataSource MPTableView:self heightForHeaderInSection:section.section];
    } else {
        height = _sectionHeaderHeight;
    }
    MPTV_CHECK_DATASOURCE;
    
    if (height < 0) {
        NSAssert(NO, @"section header height can not be less than 0");
        height = 0;
    }
    
    section.headerHeight = height;
    offset += height;
    
    if (_tableViewDataSource) {
        NSInteger numberOfRows = [_tableViewDataSource MPTableView:self numberOfRowsInSection:section.section];
        MPTV_CHECK_DATASOURCE;
        if (numberOfRows < 0) {
            NSAssert(NO, @"the number of rows in section can not be negative");
            numberOfRows = 0;
        }
        
        [section addRowPosition:section.startPos + section.headerHeight];
        for (NSInteger i = 0; i < numberOfRows; i++) {
            if (_respond_estimatedHeightForRowAtIndexPath) {
                height = [_tableViewDataSource MPTableView:self estimatedHeightForRowAtIndexPath:_NSIndexPathInSectionForRow(section.section, i)];
            } else if (_respond_heightForRowAtIndexPath) {
                height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:_NSIndexPathInSectionForRow(section.section, i)];
            } else {
                height = _rowHeight;
            }
            MPTV_CHECK_DATASOURCE;
            
            if (height < 0) {
                NSAssert(NO, @"cell height can not be less than 0");
                height = 0;
            }
            
            [section addRowPosition:offset += height];
        }
        section.numberOfRows = numberOfRows;
    }
    // footer
    if (_respond_estimatedHeightForFooterInSection) {
        height = [_tableViewDataSource MPTableView:self estimatedHeightForFooterInSection:section.section];
    } else if (_respond_heightForFooterInSection) {
        height = [_tableViewDataSource MPTableView:self heightForFooterInSection:section.section];
    } else {
        height = _sectionFooterHeight;
    }
    MPTV_CHECK_DATASOURCE;
    
    if (height < 0) {
        NSAssert(NO, @"section footer height can not be less than 0");
        height = 0;
    }
    
    section.footerHeight = height;
    offset += height;
    
    section.endPos = offset;
    return offset;
}

- (CGFloat)_buildSectionsArray:(NSMutableArray *)sectionsArray {
    CGFloat offset = 0;
    
    const NSUInteger sectionCount = sectionsArray.count;
    NSInteger numberOfSections;
    MPTV_CHECK_DATASOURCE;
    if (_respond_numberOfSectionsInMPTableView) {
        numberOfSections = [_tableViewDataSource numberOfSectionsInMPTableView:self];
        MPTV_CHECK_DATASOURCE;
        if (numberOfSections < 0) {
            NSAssert(NO, @"the number of sections can not be negative");
            numberOfSections = 0;
        }
    } else {
        numberOfSections = 1;
    }
    
    if (sectionCount > numberOfSections) {
        [sectionsArray removeObjectsInRange:NSMakeRange(numberOfSections, sectionCount - numberOfSections)];
    }
    for (NSInteger i = 0; i < numberOfSections; i++) {
        MPTableViewSection *section;
        if (i >= sectionCount) {
            section = [MPTableViewSection section];
        } else {
            section = sectionsArray[i];
            [section reset];
        }
        section.section = i;
        
        offset = [self _buildSection:section withOffset:offset];
        if (offset == MPTableViewInvalidFloatValue) {
            [sectionsArray removeAllObjects];
            break;
        }
        if (i >= sectionCount) {
            [sectionsArray addObject:section];
        }
    }
    
    return offset;
}

- (void)_setContentSizeWithContentHeight:(CGFloat)contentHeight {
    if (contentHeight < 0) {
        contentHeight = 0;
    }
    
    if (_tableHeaderView) {
        _contentListPosition.startPos = _tableHeaderView.bounds.size.height;
    }
    
    CGFloat contentSizeHeight = _contentListPosition.endPos = _contentListPosition.startPos + contentHeight;
    if (_tableFooterView) {
        CGRect frame = _tableFooterView.frame;
        frame.origin.y = _contentListPosition.endPos;
        MPSetFrameForViewWithoutAnimation(_tableFooterView, frame);
        
        contentSizeHeight += frame.size.height;
    }
    
    self.contentSize = CGSizeMake(self.bounds.size.width, contentSizeHeight);
}

- (void)_clearDataAndCacheSubviewsEnabled:(BOOL)cacheSubviewEnabled {
    _layoutSubviewsLock = YES;
    _numberOfSections = 0;
    
    [self _resetDragModeLongGestureRecognizer];
    
    _beginIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
    _endIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
    _supplementSubviewsNeededFlag = NO;
    _contentListPosition.endPos = _contentListPosition.startPos;
    [self _setContentOffsetPositions];
    [self _cancelPrefetchingIfNeeded];
    
    _updateSubviewsLock = YES;
    if (_selectedIndexPaths.count > 0) {
        for (NSIndexPath *indexPath in _selectedIndexPaths) {
            [self _deselectRowAtIndexPath:indexPath animated:NO needToRemove:NO needToSetAnimated:YES];
        }
        [_selectedIndexPaths removeAllObjects];
    }
    [self _unhighlightCellIfNeeded];
    
    if (cacheSubviewEnabled && ![self isUpdating]) {
        [self _cacheDisplayedCells];
        [self _cacheDisplayedSectionViews];
    } else {
        [self _clearReusableCells];
        [self _clearReusableSectionViews];
        
        [self _clearDisplayedCells];
        [self _clearDisplayedSectionViews];
    }
    
    [_updateAnimatedIndexPaths removeAllObjects];
    _updateSubviewsLock = NO;
}

- (void)_resetDragModeLongGestureRecognizer {
    [self _endDraggingCellIfNeededImmediately:YES];
    
    _dragModeLongGestureRecognizer.enabled = NO; // cancel interaction
    _dragModeLongGestureRecognizer.enabled = _dragModeEnabled;
}

- (void)_cacheDisplayedCells {
    NSArray *indexPaths = [_displayedCellsDic.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *indexPathA, NSIndexPath *indexPathB) {
        return [indexPathB compare:indexPathA]; // reverse
    }];
    
    for (NSIndexPath *indexPath in indexPaths) {
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
        [self _cacheCell:cell];
        if (_respond_didEndDisplayingCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
        }
    }
    
    [_displayedCellsDic removeAllObjects];
}

- (void)_cacheDisplayedSectionViews {
    NSArray *indexPaths = [_displayedSectionViewsDic.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *indexPathA, NSIndexPath *indexPathB) {
        return [indexPathB compare:indexPathA];
    }];
    
    for (NSIndexPath *indexPath in indexPaths) {
        MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
        [self _cacheSectionView:sectionView];
        
        MPSectionViewType type = indexPath.row;
        [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section withType:type];
    }
    
    [_displayedSectionViewsDic removeAllObjects];
}

- (void)_clearDisplayedCells {
    NSArray *indexPaths = _displayedCellsDic.allKeys;
    for (NSIndexPath *indexPath in indexPaths) {
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
        [cell removeFromSuperview];
        if (_respond_didEndDisplayingCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
        }
    }
    
    [_displayedCellsDic removeAllObjects];
}

- (void)_clearDisplayedSectionViews {
    NSArray *indexPaths = _displayedSectionViewsDic.allKeys;
    for (NSIndexPath *indexPath in indexPaths) {
        MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
        [sectionView removeFromSuperview];
        
        MPSectionViewType type = indexPath.row;
        [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section withType:type];
    }
    
    [_displayedSectionViewsDic removeAllObjects];
}

- (void)_clearReusableCells {
    for (NSMutableArray *queue in _reusableCellsDic.allValues) {
        [queue makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [queue removeAllObjects];
    }
}

- (void)_clearReusableSectionViews {
    for (NSMutableArray *queue in _reusableReusableViewsDic.allValues) {
        [queue makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [queue removeAllObjects];
    }
}

#pragma mark - layout

- (void)layoutSubviews {
    [super layoutSubviews];
    [self _layoutSubviewsInternal];
}

- (void)_layoutSubviewsInternal {
    NSParameterAssert([NSThread isMainThread]);
    if (_updateSubviewsLock || _layoutSubviewsLock) {
        return;
    }
    
    _layoutSubviewsNeededFlag = NO;
    if (!_tableViewDataSource) {
        [self _respondsToDataSource];
        _reloadDataNeededFlag = NO;
        return [self _clearDataAndCacheSubviewsEnabled:_cachesSubviewsDuringReload];
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
        _layoutSubviewsNeededFlag = NO;
    }
    
    [self _setContentOffsetPositions];
    if (_contentListPosition.startPos >= _contentListPosition.endPos) {
        return;
    }
    
    _updateSubviewsLock = YES;
    [self _layoutSubviewsIfNeeded];
    [self _prefetchIndexPathsIfNeeded];
    _updateSubviewsLock = NO;
}

- (void)_setContentOffsetPositions {
    _contentOffsetPosition.startPos = self.contentOffset.y;
    _contentOffsetPosition.endPos = self.contentOffset.y + self.bounds.size.height;
    
    _contentListOffsetPosition.startPos = _contentOffsetPosition.startPos - _contentListPosition.startPos;
    _contentListOffsetPosition.endPos = _contentOffsetPosition.endPos - _contentListPosition.startPos;
}

- (void)_layoutSubviewsIfNeeded {
    NSIndexPathStruct beginIndexPathStruct = [self _indexPathAtContentOffsetStartPosition];
    NSIndexPathStruct endIndexPathStruct = [self _indexPathAtContentOffsetEndPosition];
    
    if ([self _isEstimatedMode]) { // estimated layout
        if (_supplementSubviewsNeededFlag) {
            [self _estimatedLayoutSubviewsFromFirstIndexPath:beginIndexPathStruct];
            if (_NSIndexPathStructCompareStruct(_beginIndexPath, beginIndexPathStruct) != NSOrderedAscending) {
                _supplementSubviewsNeededFlag = NO;
            }
            return;
        }
        
        if (!_NSIndexPathStructEqualToStruct(_beginIndexPath, beginIndexPathStruct) || !_NSIndexPathStructEqualToStruct(_endIndexPath, endIndexPathStruct)) {
            [self _estimatedLayoutSubviewsBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
        } else if (_style == MPTableViewStylePlain) {
            [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
        }
    } else { // normal layout
        if (_supplementSubviewsNeededFlag || !_NSIndexPathStructEqualToStruct(_beginIndexPath, beginIndexPathStruct) || !_NSIndexPathStructEqualToStruct(_endIndexPath, endIndexPathStruct)) {
            [self _normalLayoutSubviewsBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
            _supplementSubviewsNeededFlag = NO;
        } else if (_style == MPTableViewStylePlain) {
            [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
        }
    }
}

- (void)_estimatedLayoutSubviewsBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    if (_NSIndexPathStructCompareStruct(beginIndexPathStruct, _beginIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(beginIndexPathStruct, _endIndexPath) == NSOrderedDescending) {
        NSIndexPathStruct estimatedFirstIndexPath = beginIndexPathStruct;
        
        [self _estimatedLayoutSubviewsFromFirstIndexPath:estimatedFirstIndexPath];
        if (_NSIndexPathStructCompareStruct(_beginIndexPath, beginIndexPathStruct) == NSOrderedAscending) {
            _supplementSubviewsNeededFlag = YES;
        }
    } else if (_NSIndexPathStructCompareStruct(endIndexPathStruct, _endIndexPath) == NSOrderedDescending) {
        NSIndexPathStruct estimatedFirstIndexPath;
        if (MPTV_IS_FOOTER(_endIndexPath.row)) {
            estimatedFirstIndexPath = _NSIndexPathMakeStruct(_endIndexPath.section + 1, MPSectionHeader);
        } else if (MPTV_IS_HEADER(_endIndexPath.row)) {
            estimatedFirstIndexPath = _NSIndexPathMakeStruct(_endIndexPath.section, 0);
        } else {
            estimatedFirstIndexPath = _NSIndexPathMakeStruct(_endIndexPath.section, _endIndexPath.row + 1);
        }
        
        [self _estimatedLayoutSubviewsFromFirstIndexPath:estimatedFirstIndexPath];
    } else {
        [self _clipCellsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
        [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
        
        _beginIndexPath = beginIndexPathStruct;
        _endIndexPath = endIndexPathStruct;
    }
}

- (void)_normalLayoutSubviewsBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    [self _clipCellsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
    [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
    
    [self _layoutSubviewsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
}

- (void)_layoutSubviewsBetweenBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    BOOL hasStickedHeader = NO;
    BOOL hasStickedFooter = NO;
    BOOL isPlain = (_style == MPTableViewStylePlain);
    
    for (NSInteger i = beginIndexPathStruct.section; i <= endIndexPathStruct.section; i++) {
        MPTableViewSection *section = _sectionsArray[i];
        
        BOOL needToDisplayHeader = section.headerHeight > 0;
        BOOL needToDisplayFooter = section.footerHeight > 0;
        NSInteger beginCellRow, endCellRow;
        if (i == beginIndexPathStruct.section) {
            if (MPTV_IS_HEADER(beginIndexPathStruct.row)) {
                beginCellRow = 0;
            } else if (MPTV_IS_FOOTER(beginIndexPathStruct.row)) {
                beginCellRow = NSIntegerMax;
                needToDisplayHeader = NO;
            } else {
                beginCellRow = beginIndexPathStruct.row;
                needToDisplayHeader = NO;
            }
        } else {
            beginCellRow = 0;
        }
        
        if (i == endIndexPathStruct.section) {
            if (MPTV_IS_FOOTER(endIndexPathStruct.row)) {
                endCellRow = section.numberOfRows - 1;
            } else if (MPTV_IS_HEADER(endIndexPathStruct.row)) {
                endCellRow = NSIntegerMin;
                needToDisplayFooter = NO;
            } else {
                endCellRow = endIndexPathStruct.row;
                needToDisplayFooter = NO;
            }
        } else {
            endCellRow = section.numberOfRows - 1;
        }
        
        if (isPlain) {
            if (!hasStickedHeader && [self _needToStickViewInSection:section withType:MPSectionHeader]) {
                hasStickedHeader = YES;
                [self _displaySectionViewToStickIfNeededInSection:section withType:MPSectionHeader];
            } else if ([self _needToPrepareToStickViewInSection:section withType:MPSectionHeader]) {
                [self _displaySectionViewToPrepareToStickIfNeededInSection:section withType:MPSectionHeader];
            } else if (needToDisplayHeader) {
                [self _displaySectionViewIfNeededInSection:section withType:MPSectionHeader];
            }
            
            if (!hasStickedFooter && [self _needToStickViewInSection:section withType:MPSectionFooter]) {
                hasStickedFooter = YES;
                [self _displaySectionViewToStickIfNeededInSection:section withType:MPSectionFooter];
            } else if ([self _needToPrepareToStickViewInSection:section withType:MPSectionFooter]) {
                [self _displaySectionViewToPrepareToStickIfNeededInSection:section withType:MPSectionFooter];
            } else if (needToDisplayFooter) {
                [self _displaySectionViewIfNeededInSection:section withType:MPSectionFooter];
            }
        } else {
            if (needToDisplayHeader) {
                [self _displaySectionViewIfNeededInSection:section withType:MPSectionHeader];
            }
            if (needToDisplayFooter) {
                [self _displaySectionViewIfNeededInSection:section withType:MPSectionFooter];
            }
        }
        
        for (NSInteger j = beginCellRow; j <= endCellRow; j++) {
            NSIndexPathStruct indexPathStruct = {i, j};
            if (_supplementSubviewsNeededFlag || _NSIndexPathStructCompareStruct(indexPathStruct, _beginIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(indexPathStruct, _endIndexPath) == NSOrderedDescending) {
                NSIndexPath *indexPath = _NSIndexPathFromStruct(indexPathStruct);
                
                if ((_supplementSubviewsNeededFlag || isUpdating || _draggingIndexPath) && [_displayedCellsDic objectForKey:indexPath]) {
                    continue;
                }
                
                CGRect frame = [self _cellFrameAtIndexPath:indexPath];
                if (frame.size.height <= 0) {
                    continue;
                }
                
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                [self _addToSuperviewIfNecessaryForCell:cell];
                if (isUpdating || _draggingIndexPath) {
                    [_contentWrapperView sendSubviewToBack:cell];
                }
                MPSetFrameForViewWithoutAnimation(cell, frame);
                [_displayedCellsDic setObject:cell forKey:indexPath];
                
                if ([_selectedIndexPaths containsObject:indexPath]) {
                    [cell setSelected:YES animated:NO];
                }
                
                if (_respond_willDisplayCellForRowAtIndexPath) {
                    [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
                }
            }
        }
    }
    
    _beginIndexPath = beginIndexPathStruct;
    _endIndexPath = endIndexPathStruct;
}

- (NSInteger)_sectionAtContentOffsetY:(CGFloat)contentOffsetY {
    NSUInteger count = _sectionsArray.count;
    NSInteger start = 0;
    NSInteger end = count - 1; // the count will never be greater than NSIntegerMax
    NSInteger middle = 0;
    while (start <= end) {
        middle = (start + end) / 2;
        MPTableViewSection *section = _sectionsArray[middle];
        if (section.endPos < contentOffsetY) {
            start = middle + 1;
        } else if (section.startPos > contentOffsetY) {
            end = middle - 1;
        } else {
            return middle;
        }
    }
    
    return middle; // floating-point precision
}

- (NSIndexPathStruct)_indexPathAtContentOffsetY:(CGFloat)contentOffsetY {
    NSInteger section = [self _sectionAtContentOffsetY:contentOffsetY];
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    NSInteger row = [sectionPosition rowAtContentOffsetY:contentOffsetY];
    
    return _NSIndexPathMakeStruct(section, row);
}

- (NSIndexPathStruct)_indexPathAtContentOffsetStartPosition {
    CGFloat contentOffsetY = _contentListOffsetPosition.startPos;
    if (contentOffsetY > _contentListPosition.endPos - _contentListPosition.startPos) {
        return _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
    }
    
    if (contentOffsetY < 0) {
        if (_contentListOffsetPosition.endPos < 0) {
            return _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
        } else {
            contentOffsetY = 0;
        }
    }
    
    return [self _indexPathAtContentOffsetY:contentOffsetY];
}

- (NSIndexPathStruct)_indexPathAtContentOffsetEndPosition {
    CGFloat contentOffsetY = _contentListOffsetPosition.endPos;
    if (contentOffsetY > _contentListPosition.endPos - _contentListPosition.startPos) {
        if (_contentListOffsetPosition.startPos > _contentListPosition.endPos - _contentListPosition.startPos) {
            return _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
        } else {
            contentOffsetY = _contentListPosition.endPos - _contentListPosition.startPos;
        }
    }
    
    if (contentOffsetY < 0) {
        return _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
    }
    
    return [self _indexPathAtContentOffsetY:contentOffsetY];
}

- (MPTableViewCell *)_getCellFromDataSourceAtIndexPath:(NSIndexPath *)indexPath {
    MPTableViewCell *cell;
    
    if ([UIView areAnimationsEnabled]) {
        [UIView setAnimationsEnabled:NO];
        
        cell = [_tableViewDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
        
        [UIView setAnimationsEnabled:YES];
    } else {
        cell = [_tableViewDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
    }
    
    if (!cell) {
        MPTV_EXCEPTION(@"cell must not be nil");
    }
    
    return cell;
}

- (CGRect)_cellFrameAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return CGRectZero;
    }
    
    MPTableViewSection *section = _sectionsArray[indexPath.section];
    if (indexPath.row >= section.numberOfRows) {
        return CGRectZero;
    }
    
    CGFloat startPos = [section startPositionAtRow:indexPath.row];
    CGFloat endPos = [section endPositionAtRow:indexPath.row];
    
    CGRect frame;
    frame.origin.x = 0;
    frame.origin.y = startPos + _contentListPosition.startPos;
    frame.size.width = self.bounds.size.width;
    frame.size.height = endPos - startPos;
    if (frame.size.height < 0) { // floating-point precision
        frame.size.height = 0;
    }
    
    return frame;
}

- (MPTableReusableView *)_getSectionViewFromDataSourceInSection:(NSInteger)section withType:(MPSectionViewType)type {
    MPTableReusableView *sectionView = nil;
    
    if ([UIView areAnimationsEnabled]) {
        [UIView setAnimationsEnabled:NO];
        
        if (MPTV_IS_HEADER(type)) {
            if (_respond_viewForHeaderInSection) {
                sectionView = [_tableViewDataSource MPTableView:self viewForHeaderInSection:section];
            }
        } else {
            if (_respond_viewForFooterInSection) {
                sectionView = [_tableViewDataSource MPTableView:self viewForFooterInSection:section];
            }
        }
        
        [UIView setAnimationsEnabled:YES];
    } else {
        if (MPTV_IS_HEADER(type)) {
            if (_respond_viewForHeaderInSection) {
                sectionView = [_tableViewDataSource MPTableView:self viewForHeaderInSection:section];
            }
        } else {
            if (_respond_viewForFooterInSection) {
                sectionView = [_tableViewDataSource MPTableView:self viewForFooterInSection:section];
            }
        }
    }
    
    NSParameterAssert(![[sectionView class] isKindOfClass:[MPTableViewCell class]]);
    return sectionView;
}

- (CGRect)_sectionViewFrameInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    CGRect frame;
    
    frame.origin.x = 0;
    frame.size.width = self.bounds.size.width;
    if (MPTV_IS_HEADER(type)) {
        frame.origin.y = section.startPos + _contentListPosition.startPos;
        frame.size.height = section.headerHeight;
    } else {
        frame.origin.y = section.endPos - section.footerHeight + _contentListPosition.startPos;
        frame.size.height = section.footerHeight;
    }
    
    return frame;
}

- (BOOL)_needToStickViewInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    if (MPTV_IS_HEADER(type)) {
        if (section.headerHeight <= 0) {
            return NO;
        }
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if ((contentInset.top < 0 && -contentInset.top > section.headerHeight) || _contentOffsetPosition.startPos + contentInset.top >= _contentOffsetPosition.endPos) {
            return NO;
        }
        
        CGFloat contentStart = _contentListOffsetPosition.startPos + contentInset.top;
        if (section.startPos <= contentStart && section.endPos - section.footerHeight - section.headerHeight >= contentStart) {
            return YES;
        } else {
            return NO;
        }
    } else {
        if (section.footerHeight <= 0) {
            return NO;
        }
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if ((contentInset.bottom < 0 && -contentInset.bottom > section.footerHeight) || _contentOffsetPosition.endPos - contentInset.bottom <= _contentOffsetPosition.startPos) {
            return NO;
        }
        
        CGFloat contentEnd = _contentListOffsetPosition.endPos - contentInset.bottom;
        if (section.endPos >= contentEnd && section.startPos + section.headerHeight + section.footerHeight <= contentEnd) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (CGRect)_stickingFrameInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    CGRect frame;
    frame.origin.x = 0;
    frame.size.width = self.bounds.size.width;
    
    if (MPTV_IS_HEADER(type)) {
        frame.size.height = section.headerHeight;
        
        frame.origin.y = _contentListOffsetPosition.startPos + [self _innerContentInset].top;
        if (frame.origin.y > section.endPos - section.footerHeight - frame.size.height) {
            frame.origin.y = section.endPos - section.footerHeight - frame.size.height;
        }
        if (frame.origin.y < section.startPos) {
            frame.origin.y = section.startPos;
        }
    } else {
        frame.size.height = section.footerHeight;
        
        frame.origin.y = _contentListOffsetPosition.endPos - frame.size.height - [self _innerContentInset].bottom;
        if (frame.origin.y > section.endPos - frame.size.height) {
            frame.origin.y = section.endPos - frame.size.height;
        }
        if (frame.origin.y < section.startPos + section.headerHeight) {
            frame.origin.y = section.startPos + section.headerHeight;
        }
    }
    
    frame.origin.y += _contentListPosition.startPos;
    
    return frame;
}

- (BOOL)_needToPrepareToStickViewInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    if (MPTV_IS_HEADER(type)) {
        if (section.headerHeight <= 0) {
            return NO;
        }
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.startPos + contentInset.top >= _contentOffsetPosition.endPos) {
            return NO;
        }
        
        CGFloat contentStart = _contentListOffsetPosition.startPos + contentInset.top;
        if (section.endPos - section.footerHeight - section.headerHeight < contentStart && section.endPos - section.footerHeight >= _contentListOffsetPosition.startPos) {
            return YES;
        } else {
            return NO;
        }
    } else {
        if (section.footerHeight <= 0) {
            return NO;
        }
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.endPos - contentInset.bottom <= _contentOffsetPosition.startPos) {
            return NO;
        }
        
        CGFloat contentEnd = _contentListOffsetPosition.endPos - contentInset.bottom;
        if (section.startPos + section.headerHeight + section.footerHeight > contentEnd && section.startPos + section.headerHeight <= _contentListOffsetPosition.endPos) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (CGRect)_prepareToStickFrameInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    CGRect frame;
    
    frame.origin.x = 0;
    frame.size.width = self.bounds.size.width;
    if (MPTV_IS_HEADER(type)) {
        frame.origin.y = section.endPos - section.footerHeight - section.headerHeight + _contentListPosition.startPos;
        frame.size.height = section.headerHeight;
    } else {
        frame.origin.y = section.startPos + section.headerHeight + _contentListPosition.startPos;
        frame.size.height = section.footerHeight;
    }
    
    return frame;
}

- (MPTableReusableView *)_getSectionViewIfNeededAtIndexPath:(NSIndexPathStruct)indexPath {
    if (_style == MPTableViewStylePlain || [self isUpdating]) {
        if (![_displayedSectionViewsDic objectForKey:_NSIndexPathFromStruct(indexPath)]) {
            MPTableReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:indexPath.row];
            return sectionView;
        }
    } else {
        if (_NSIndexPathStructCompareStruct(indexPath, _beginIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(indexPath, _endIndexPath) == NSOrderedDescending) {
            MPTableReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:indexPath.row];
            return sectionView;
        }
    }
    
    return nil;
}

- (void)_displaySectionViewToStickIfNeededInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    NSIndexPathStruct indexPath = _NSIndexPathMakeStruct(section.section, type);
    MPTableReusableView *sectionView = [self _getSectionViewIfNeededAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _stickingFrameInSection:section withType:type];
        [self _displaySectionView:sectionView atIndexPath:_NSIndexPathFromStruct(indexPath) withFrame:frame];
    }
}

- (void)_displaySectionViewToPrepareToStickIfNeededInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    NSIndexPathStruct indexPath = _NSIndexPathMakeStruct(section.section, type);
    MPTableReusableView *sectionView = [self _getSectionViewIfNeededAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _prepareToStickFrameInSection:section withType:type];
        [self _displaySectionView:sectionView atIndexPath:_NSIndexPathFromStruct(indexPath) withFrame:frame];
    }
}

// has checked the height
- (void)_displaySectionViewIfNeededInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    NSIndexPathStruct indexPath = _NSIndexPathMakeStruct(section.section, type);
    MPTableReusableView *sectionView = [self _getSectionViewIfNeededAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _sectionViewFrameInSection:section withType:type];
        [self _displaySectionView:sectionView atIndexPath:_NSIndexPathFromStruct(indexPath) withFrame:frame];
    }
}

- (void)_displaySectionView:(MPTableReusableView *)sectionView atIndexPath:(NSIndexPath *)indexPath withFrame:(CGRect)frame {
    [self _addToSuperviewIfNecessaryForSectionView:sectionView];
    if ([self isUpdating]) {
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
    }
    MPSetFrameForViewWithoutAnimation(sectionView, frame);
    [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    
    MPSectionViewType type = indexPath.row;
    [self _willDisplaySectionView:sectionView forSection:indexPath.section withType:type];
}

- (void)_willDisplaySectionView:(MPTableReusableView *)sectionView forSection:(NSInteger)section withType:(MPSectionViewType)type {
    if (MPTV_IS_HEADER(type) && _respond_willDisplayHeaderViewForSection) {
        [_tableViewDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:section];
    }
    if (MPTV_IS_FOOTER(type) && _respond_willDisplayFooterViewForSection) {
        [_tableViewDelegate MPTableView:self willDisplayFooterView:sectionView forSection:section];
    }
}

- (void)_didEndDisplayingSectionView:(MPTableReusableView *)sectionView forSection:(NSInteger)section withType:(MPSectionViewType)type {
    if (MPTV_IS_HEADER(type) && _respond_didEndDisplayingHeaderViewForSection) {
        [_tableViewDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:section];
    }
    if (MPTV_IS_FOOTER(type) && _respond_didEndDisplayingFooterViewForSection) {
        [_tableViewDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:section];
    }
}

- (void)_addToSuperviewIfNecessaryForCell:(MPTableViewCell *)cell {
    if ([cell superview] != _contentWrapperView) {
        [_contentWrapperView addSubview:cell];
    }
}

- (void)_addToSuperviewIfNecessaryForSectionView:(MPTableReusableView *)sectionView {
    if ([sectionView superview] != self) {
        [self addSubview:sectionView];
    }
}

- (void)_cacheCell:(MPTableViewCell *)cell {
    if ([cell reuseIdentifier]) {
        [cell prepareForRecycle];
        
        NSMutableArray *queue = [_reusableCellsDic objectForKey:cell.reuseIdentifier];
        if (!queue) {
            queue = [[NSMutableArray alloc] init];
            [_reusableCellsDic setObject:queue forKey:cell.reuseIdentifier];
        }
        [queue addObject:cell];
        cell.hidden = YES;
    } else {
        [cell removeFromSuperview];
    }
    
    [cell setHighlighted:NO animated:NO];
    [cell setSelected:NO animated:NO];
}

- (void)_clipCellsBetweenBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    
    NSArray *indexPaths = _displayedCellsDic.allKeys;
    for (NSIndexPath *indexPath in indexPaths) {
        if (_NSIndexPathCompareStruct(indexPath, beginIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, endIndexPathStruct) == NSOrderedDescending) {
            if (_draggingIndexPath) {
                if ([indexPath compare:_draggingIndexPath] == NSOrderedSame) {
                    continue;
                }
            } else if (isUpdating && [_updateAnimatedIndexPaths containsObject:indexPath]) {
                continue;
            }
            
            MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
            
            [self _cacheCell:cell];
            [_displayedCellsDic removeObjectForKey:indexPath];
            
            if (_respond_didEndDisplayingCellForRowAtIndexPath) {
                [_tableViewDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
            }
        }
    }
}

- (void)_cacheSectionView:(MPTableReusableView *)sectionView {
    if ([sectionView reuseIdentifier]) {
        [sectionView prepareForRecycle];
        
        NSMutableArray *queue = [_reusableReusableViewsDic objectForKey:sectionView.reuseIdentifier];
        if (!queue) {
            queue = [[NSMutableArray alloc] init];
            [_reusableReusableViewsDic setObject:queue forKey:sectionView.reuseIdentifier];
        }
        [queue addObject:sectionView];
        sectionView.hidden = YES;
    } else {
        [sectionView removeFromSuperview];
    }
}

- (void)_clipAndAdjustSectionViewsBetweenBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    BOOL isPlain = (_style == MPTableViewStylePlain);
    BOOL isEstimatedMode = [self _isEstimatedMode];
    
    NSArray *indexPaths = _displayedSectionViewsDic.allKeys;
    for (NSIndexPath *indexPath in indexPaths) {
        MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
        MPSectionViewType type = indexPath.row;
        
        if (isPlain) {
            MPTableViewSection *section = _sectionsArray[indexPath.section];
            if ([self _needToStickViewInSection:section withType:type]) {
                CGRect frame = [self _stickingFrameInSection:section withType:type];
                MPSetFrameForViewWithoutAnimation(sectionView, frame);
            } else if ([self _needToPrepareToStickViewInSection:section withType:type]) {
                CGRect frame = [self _prepareToStickFrameInSection:section withType:type];
                MPSetFrameForViewWithoutAnimation(sectionView, frame);
            } else if (_NSIndexPathCompareStruct(indexPath, beginIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, endIndexPathStruct) == NSOrderedDescending) {
                if (isUpdating && !_draggingIndexPath && [_updateAnimatedIndexPaths containsObject:indexPath]) {
                    CGRect frame = [self _sectionViewFrameInSection:section withType:type];
                    MPSetFrameForViewWithoutAnimation(sectionView, frame);
                } else {
                    [self _cacheSectionView:sectionView];
                    [_displayedSectionViewsDic removeObjectForKey:indexPath];
                    
                    [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section withType:type];
                }
            } else { // if there are two or more headers prepare to stick, and then we have changed the contentOffset (not animated), these headers may need to be reset.
                CGRect frame = [self _sectionViewFrameInSection:section withType:type];
                MPSetFrameForViewWithoutAnimation(sectionView, frame);
            }
        } else {
            if (_NSIndexPathCompareStruct(indexPath, beginIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, endIndexPathStruct) == NSOrderedDescending) {
                [self _cacheSectionView:sectionView];
                [_displayedSectionViewsDic removeObjectForKey:indexPath];
                
                [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section withType:type];
            } else if (isEstimatedMode) {
                MPTableViewSection *section = _sectionsArray[indexPath.section];
                CGRect frame = [self _sectionViewFrameInSection:section withType:type];
                MPSetFrameForViewWithoutAnimation(sectionView, frame);
            }
        }
    }
}

#pragma mark - prefetch

const NSInteger MPPrefetchCount = 10; // fixed
const NSInteger MPPrefetchDetectLength = 15; // fixed

- (NSIndexPathStruct)_prefetchBeginIndexPath {
    NSIndexPathStruct indexPathStruct = _beginIndexPath;
    if (MPTV_IS_HEADER(indexPathStruct.row)) {
        indexPathStruct.row = NSIntegerMin;
    } else if (MPTV_IS_FOOTER(indexPathStruct.row)) {
        MPTableViewSection *section = _sectionsArray[indexPathStruct.section];
        if (section.numberOfRows) {
            indexPathStruct.row = section.numberOfRows;
        } else {
            indexPathStruct.row = NSIntegerMin;
        }
    }
    
    return indexPathStruct;
}

- (NSIndexPathStruct)_prefetchEndIndexPath {
    NSIndexPathStruct indexPathStruct = _endIndexPath;
    if (MPTV_IS_HEADER(indexPathStruct.row)) {
        MPTableViewSection *section = _sectionsArray[indexPathStruct.section];
        if (section.numberOfRows) {
            indexPathStruct.row = -1;
        } else {
            indexPathStruct.row = NSIntegerMax;
        }
    } else if (MPTV_IS_FOOTER(indexPathStruct.row)) {
        indexPathStruct.row = NSIntegerMax;
    }
    
    return indexPathStruct;
}

- (void)_prefetchIndexPathsIfNeeded {
    if (!_prefetchDataSource || _numberOfSections == 0 || _beginIndexPath.section == NSIntegerMax || _endIndexPath.section == NSIntegerMin) {
        return;
    }
    
    BOOL isScrollingUp = _contentOffsetPosition.startPos < _lastContentOffsetY;
    NSMutableArray *prefetchUpIndexPaths = [[NSMutableArray alloc] init];
    NSMutableArray *prefetchDownIndexPaths = [[NSMutableArray alloc] init];
    
    NSIndexPathStruct prefetchBeginIndexPath = [self _prefetchBeginIndexPath];
    for (NSInteger i = 0; i < MPPrefetchDetectLength; i++) {
        if (prefetchBeginIndexPath.row > 0) {
            prefetchBeginIndexPath.row--;
        } else {
            while (prefetchBeginIndexPath.section > 0) {
                MPTableViewSection *section = _sectionsArray[--prefetchBeginIndexPath.section];
                if (section.numberOfRows > 0) {
                    prefetchBeginIndexPath.row = section.numberOfRows - 1;
                    goto _prefetch_up;
                }
            }
            break;
        }
        
    _prefetch_up:
        if (isScrollingUp && i < MPPrefetchCount) {
            NSIndexPath *indexPath = _NSIndexPathFromStruct(prefetchBeginIndexPath);
            if (![_prefetchIndexPaths containsObject:indexPath]) {
                [prefetchUpIndexPaths addObject:indexPath];
            }
        }
    }
    
    NSIndexPathStruct prefetchEndIndexPath = [self _prefetchEndIndexPath];
    for (NSInteger i = 0; i < MPPrefetchDetectLength; i++) {
        MPTableViewSection *section = _sectionsArray[prefetchEndIndexPath.section];
        if (prefetchEndIndexPath.row < section.numberOfRows - 1) { // here can't be: prefetchEndIndexPath.row + 1 < section.numberOfRows, the prefetchEndIndexPath.row may be NSIntegerMax.
            prefetchEndIndexPath.row++;
        } else {
            while (prefetchEndIndexPath.section < _numberOfSections - 1) {
                section = _sectionsArray[++prefetchEndIndexPath.section];
                if (section.numberOfRows > 0) {
                    prefetchEndIndexPath.row = 0;
                    goto _prefetch_down;
                }
            }
            break;
        }
        
    _prefetch_down:
        if (!isScrollingUp && i < MPPrefetchCount) {
            NSIndexPath *indexPath = _NSIndexPathFromStruct(prefetchEndIndexPath);
            if (![_prefetchIndexPaths containsObject:indexPath]) {
                [prefetchDownIndexPaths addObject:indexPath];
            }
        }
    }
    
    if (prefetchUpIndexPaths.count > 0 || prefetchDownIndexPaths.count > 0) {
        [prefetchUpIndexPaths addObjectsFromArray:prefetchDownIndexPaths]; // verified
        [_prefetchIndexPaths addObjectsFromArray:prefetchUpIndexPaths];
        
        [_prefetchDataSource MPTableView:self prefetchRowsAtIndexPaths:prefetchUpIndexPaths];
    }
    
    NSMutableArray *discardIndexPaths = [[NSMutableArray alloc] init];
    NSMutableArray *cancelPrefetchIndexPaths = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in _prefetchIndexPaths) {
        if (_NSIndexPathCompareStruct(indexPath, _beginIndexPath) != NSOrderedAscending && _NSIndexPathCompareStruct(indexPath, _endIndexPath) != NSOrderedDescending) {
            [discardIndexPaths addObject:indexPath];
        } else if (_NSIndexPathCompareStruct(indexPath, prefetchBeginIndexPath) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, prefetchEndIndexPath) == NSOrderedDescending) {
            [cancelPrefetchIndexPaths addObject:indexPath];
        } else {
            MPTableViewSection *section = _sectionsArray[indexPath.section];
            if (indexPath.row >= section.numberOfRows) { // after update
                [cancelPrefetchIndexPaths addObject:indexPath];
            }
        }
    }
    
    [_prefetchIndexPaths removeObjectsInArray:discardIndexPaths];
    [_prefetchIndexPaths removeObjectsInArray:cancelPrefetchIndexPaths];
    
    if (_respond_cancelPrefetchingForRowsAtIndexPaths && cancelPrefetchIndexPaths.count > 0) {
        [_prefetchDataSource MPTableView:self cancelPrefetchingForRowsAtIndexPaths:cancelPrefetchIndexPaths];
    }
    
    _lastContentOffsetY = _contentOffsetPosition.startPos;
}

- (void)_cancelPrefetchingIfNeeded {
    if (_respond_cancelPrefetchingForRowsAtIndexPaths && _prefetchIndexPaths.count > 0) {
        NSArray *cancelPrefetchIndexPaths = [_prefetchIndexPaths copy];
        [_prefetchDataSource MPTableView:self cancelPrefetchingForRowsAtIndexPaths:cancelPrefetchIndexPaths];
    }
    [_prefetchIndexPaths removeAllObjects];
    _lastContentOffsetY = _contentOffsetPosition.startPos;
}

#pragma mark - select

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    _updateSubviewsLock = YES;
    [self _willSelectCellIfNeededWithTouches:touches];
    _updateSubviewsLock = NO;
}

- (void)_willSelectCellIfNeededWithTouches:(NSSet *)touches {
    if (_highlightedIndexPath || _draggingIndexPath) {
        return;
    }
    
    if ([self isDecelerating] || [self isDragging] || _contentListPosition.startPos >= _contentListPosition.endPos) {
        return;
    }
    
    UITouch *touch = touches.anyObject;
    CGPoint location = [touch locationInView:self];
    CGFloat locationY = location.y;
    if (!_allowsSelection || locationY < _contentListPosition.startPos || locationY > _contentListPosition.endPos) {
        return;
    }
    
    NSIndexPathStruct touchedIndexPathStruct = [self _indexPathAtContentOffsetY:locationY - _contentListPosition.startPos];
    if (MPTV_IS_HEADER(touchedIndexPathStruct.row) || MPTV_IS_FOOTER(touchedIndexPathStruct.row)) {
        return;
    }
    
    NSIndexPath *touchedIndexPath = _NSIndexPathFromStruct(touchedIndexPathStruct);
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:touchedIndexPath];
    if (!cell) {
        return;
    }
    
    if (_dragModeEnabled) {
        if (_allowsSelectionForDragMode) {
            // If the rect for start dragging the cell is not specified, and the allowsSelectionForDragMode is YES, then the cell can be selected.
            if (_respond_rectForCellToMoveRowAtIndexPath && [self _rectForCell:cell toMoveRowAtIndexPath:touchedIndexPath availableAtLocation:location]) {
                return;
            }
        } else {
            return;
        }
    }
    
    if (_respond_shouldHighlightRowAtIndexPath && ![_tableViewDelegate MPTableView:self shouldHighlightRowAtIndexPath:touchedIndexPath]) {
        return;
    }
    
    _highlightedIndexPath = touchedIndexPath;
    
    if (![cell isHighlighted]) {
        [cell setHighlighted:YES];
    }
    
    if (_respond_didHighlightRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self didHighlightRowAtIndexPath:touchedIndexPath];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    _updateSubviewsLock = YES;
    [self _unhighlightCellIfNeeded];
    _updateSubviewsLock = NO;
}

- (void)_unhighlightCellIfNeeded {
    if (!_highlightedIndexPath) {
        return;
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
    
    if ([cell isHighlighted]) {
        if (_layoutSubviewsLock) { // when table view is clearing
            [cell setHighlighted:NO animated:NO];
        } else {
            [cell setHighlighted:NO];
        }
    }
    
    NSIndexPath *highlightedIndexPath = _highlightedIndexPath;
    _highlightedIndexPath = nil;
    if (_respond_didUnhighlightRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self didUnhighlightRowAtIndexPath:highlightedIndexPath];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    _updateSubviewsLock = YES;
    [self _didSelectCellWithTouches:touches];
    _updateSubviewsLock = NO;
}

- (void)_didSelectCellWithTouches:(NSSet *)touches {
    if (!_highlightedIndexPath || !_allowsSelection) {
        return;
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
    if (!cell) {
        _highlightedIndexPath = nil;
        return;
    }
    
    NSIndexPath *selectedIndexPath = _highlightedIndexPath;
    if (_respond_willSelectRowAtIndexPath) {
        NSIndexPath *indexPath = [_tableViewDelegate MPTableView:self willSelectRowAtIndexPath:selectedIndexPath];
        if (!indexPath) {
            return [self _unhighlightCellIfNeeded];
        }
        
        if (indexPath.section < 0 || indexPath.row < 0) {
            NSAssert(NO, @"indexPath.section and indexPath.row can not be negative");
            return [self _unhighlightCellIfNeeded];
        }
        
        if (indexPath.section >= _sectionsArray.count) {
            return [self _unhighlightCellIfNeeded];
        } else {
            MPTableViewSection *section = _sectionsArray[indexPath.section];
            if (indexPath.row >= section.numberOfRows) {
                return [self _unhighlightCellIfNeeded];
            }
        }
        
        if (![indexPath isEqual:selectedIndexPath]) {
            cell = [_displayedCellsDic objectForKey:selectedIndexPath = indexPath];
        }
    }
    
    if (_allowsMultipleSelection && [_selectedIndexPaths containsObject:selectedIndexPath]) {
        [self _deselectRowAtIndexPath:selectedIndexPath animated:NO needToRemove:YES needToSetAnimated:NO];
        [self _unhighlightCellIfNeeded];
    } else {
        BOOL needToNotify = YES;
        if (!_allowsMultipleSelection && _selectedIndexPaths.count > 0) {
            for (NSIndexPath *indexPath in _selectedIndexPaths.allObjects) {
                if ([indexPath isEqual:selectedIndexPath]) {
                    needToNotify = NO;
                    continue;
                }
                [self _deselectRowAtIndexPath:indexPath animated:NO needToRemove:YES needToSetAnimated:NO];
            }
        }
        
        [_selectedIndexPaths addObject:selectedIndexPath];
        [cell setSelected:YES];
        [self _unhighlightCellIfNeeded];
        
        if (_respond_didSelectRowForCellForRowAtIndexPath) {
            _updateSubviewsLock = NO;
            [_tableViewDelegate MPTableView:self didSelectRowForCell:cell forRowAtIndexPath:selectedIndexPath];
        }
        if (needToNotify) {
            [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    
    _updateSubviewsLock = YES;
    [self _unhighlightCellIfNeeded];
    _updateSubviewsLock = NO;
}

#pragma mark - drag

- (NSIndexPath *)indexPathForDraggingRow {
    return _draggingIndexPath;
}

- (BOOL)_hasDraggingCell {
    return _draggingCell ? YES : NO;
}

- (void)setDragModeEnabled:(BOOL)dragModeEnabled {
    if (_dragModeEnabled == dragModeEnabled) {
        return;
    }
    
    if (!dragModeEnabled) {
        [self _endDraggingCellIfNeededImmediately:NO];
    }
    
    [self _setupDragModeLongGestureRecognizerIfNeeded];
    _dragModeLongGestureRecognizer.enabled = dragModeEnabled;
    
    _dragModeEnabled = dragModeEnabled;
}

- (void)_setupDragModeLongGestureRecognizerIfNeeded {
    if (_dragModeLongGestureRecognizer) {
        return;
    }
    
    _dragModeLongGestureRecognizer = [[MPTableViewLongGestureRecognizer alloc] initWithTarget:self action:@selector(_dragModePanGestureRecognizerAction:)];
    _dragModeLongGestureRecognizer.tableView = self;
    _dragModeLongGestureRecognizer.minimumPressDuration = _minimumPressDurationForDrag;
    [_contentWrapperView addGestureRecognizer:_dragModeLongGestureRecognizer];
}

- (void)setMinimumPressDurationForDrag:(CFTimeInterval)minimumPressDurationForDrag {
    [self _setupDragModeLongGestureRecognizerIfNeeded];
    _dragModeLongGestureRecognizer.minimumPressDuration = _minimumPressDurationForDrag = minimumPressDurationForDrag;
}

- (BOOL)_mp_gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([self isUpdating]) {
        return NO;
    }
    
    CGPoint location = [gestureRecognizer locationInView:_contentWrapperView];
    _updateSubviewsLock = YES;
    [self _startDraggingCellAtLocation:location];
    _updateSubviewsLock = NO;
    
    return _dragModeAutoScrollDisplayLink ? YES : NO; // _draggingIndexPath or _draggingCell may come from the last drag
}

- (void)_dragModePanGestureRecognizerAction:(UIPanGestureRecognizer *)panGestureRecognizer {
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            
        }
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint location = [panGestureRecognizer locationInView:_contentWrapperView];
            [self _dragCellToLocation:location];
        }
            break;
        case UIGestureRecognizerStateEnded: {
            [self _endDraggingCellIfNeededImmediately:NO];
        }
            break;
        case UIGestureRecognizerStateCancelled: {
            [self _endDraggingCellIfNeededImmediately:NO];
        }
            break;
        case UIGestureRecognizerStateFailed: {
            [self _endDraggingCellIfNeededImmediately:NO];
        }
            break;
        default:
            [self _endDraggingCellIfNeededImmediately:NO];
            break;
    }
}

- (void)_startDraggingCellAtLocation:(CGPoint)location {
    [self _endDraggingCellIfNeededImmediately:NO];
    
    CGFloat locationY = location.y;
    if (locationY < _contentListPosition.startPos || locationY > _contentListPosition.endPos) {
        return;
    }
    
    NSIndexPathStruct touchedIndexPathStruct = [self _indexPathAtContentOffsetY:locationY - _contentListPosition.startPos];
    if (MPTV_IS_HEADER(touchedIndexPathStruct.row) || MPTV_IS_FOOTER(touchedIndexPathStruct.row)) {
        return;
    }
    
    NSIndexPath *touchedIndexPath = _NSIndexPathFromStruct(touchedIndexPathStruct);
    if ([touchedIndexPath isEqual:_draggingIndexPath]) {
        return;
    }
    
    if (_respond_canMoveRowAtIndexPath && ![_tableViewDataSource MPTableView:self canMoveRowAtIndexPath:touchedIndexPath]) {
        return;
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:touchedIndexPath];
    if (!cell) {
        return;
    }
    
    if (_respond_rectForCellToMoveRowAtIndexPath && ![self _rectForCell:cell toMoveRowAtIndexPath:touchedIndexPath availableAtLocation:location]) {
        return;
    }
    
    _draggingCell = cell;
    _draggingSourceIndexPath = _draggingIndexPath = touchedIndexPath;
    _dragModeMinuendPoint = MPPointsSubtraction(location, _draggingCell.center);
    _draggedStep++;
    
    [_contentWrapperView bringSubviewToFront:_draggingCell];
    
    [self _setupDragModeAutoScrollDisplayLink];
    
    if (_respond_shouldMoveRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self shouldMoveRowAtIndexPath:touchedIndexPath];
    }
}

- (BOOL)_rectForCell:(MPTableViewCell *)cell toMoveRowAtIndexPath:(NSIndexPath *)indexPath availableAtLocation:(CGPoint)location {
    CGRect touchabledFrame = [_tableViewDataSource MPTableView:self rectForCellToMoveRowAtIndexPath:indexPath];
    
    return CGRectContainsPoint(touchabledFrame, [cell convertPoint:location fromView:_contentWrapperView]);
}

- (void)_setupDragModeAutoScrollDisplayLink {
    if (!_dragModeAutoScrollDisplayLink) {
        _dragModeAutoScrollDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_dragModeAutoScrollOnBoundsAction)];
        [_dragModeAutoScrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    [self _dragModeAutoScrollOnBoundsIfNeeded];
}

- (void)_dragCellToLocation:(CGPoint)location {
    [self _setDraggedCellCenter:MPPointsSubtraction(location, _dragModeMinuendPoint)];
    [self _dragModeAutoScrollOnBoundsIfNeeded];
    [self _layoutSubviewsInternal];
    
    location = _draggingCell.center;
    [self _dragAndMoveCellToLocationY:location.y];
}

- (void)_setDraggedCellCenter:(CGPoint)center {
    if (!_allowsDraggedCellToFloat) {
        center.x = self.bounds.size.width / 2;
        if (center.y < _contentListPosition.startPos) {
            center.y = _contentListPosition.startPos;
        }
        if (center.y > _contentListPosition.endPos) {
            center.y = _contentListPosition.endPos;
        }
    }
    
    [UIView performWithoutAnimation:^{
        _draggingCell.center = center;
    }];
}

- (void)_dragModeAutoScrollOnBoundsAction {
    CGPoint newPoint = self.contentOffset;
    newPoint.y += _dragModeAutoScrollRate;
    
    if (_dragModeAutoScrollRate < 0) {
        CGFloat contentOffsetMinY = -[self _innerContentInset].top;
        if (newPoint.y < contentOffsetMinY) {
            newPoint.y = contentOffsetMinY;
            _dragModeAutoScrollDisplayLink.paused = YES;
        }
    } else if (_dragModeAutoScrollRate > 0) {
        CGFloat contentEndPositionY = _contentListPosition.endPos + _tableFooterView.bounds.size.height;
        CGFloat contentOffsetMaxY = contentEndPositionY + [self _innerContentInset].bottom - self.bounds.size.height;
        if (newPoint.y > contentOffsetMaxY) {
            newPoint.y = contentOffsetMaxY;
            _dragModeAutoScrollDisplayLink.paused = YES;
        }
    }
    
    self.contentOffset = newPoint;
    
    newPoint.x = _draggingCell.center.x;
    newPoint.y -= _dragModeDifferFromBounds;
    [self _setDraggedCellCenter:newPoint];
    
    [self _layoutSubviewsInternal];
    [self _dragAndMoveCellToLocationY:newPoint.y];
}

- (void)_dragModeAutoScrollOnBoundsIfNeeded {
    _dragModeAutoScrollRate = 0;
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (_draggingCell.frame.origin.y < _contentOffsetPosition.startPos + contentInset.top) {
        if (_contentOffsetPosition.startPos > -contentInset.top) {
            _dragModeAutoScrollRate = _draggingCell.frame.origin.y - _contentOffsetPosition.startPos - contentInset.top;
            _dragModeAutoScrollRate /= 7;
        }
    } else if (CGRectGetMaxY(_draggingCell.frame) > _contentOffsetPosition.endPos - contentInset.bottom) {
        CGFloat contentEndPositionY = _contentListPosition.endPos + _tableFooterView.bounds.size.height;
        if (_contentOffsetPosition.endPos < contentEndPositionY + contentInset.bottom) {
            _dragModeAutoScrollRate = CGRectGetMaxY(_draggingCell.frame) - _contentOffsetPosition.endPos + contentInset.bottom;
            _dragModeAutoScrollRate /= 7;
        }
    }
    
    _dragModeDifferFromBounds = _contentOffsetPosition.startPos - _draggingCell.center.y;
    _dragModeAutoScrollDisplayLink.paused = (_dragModeAutoScrollRate == 0);
}

- (void)_dragAndMoveCellToLocationY:(CGFloat)locationY {
    if (locationY < _contentListPosition.startPos || locationY > _contentListPosition.endPos) {
        return;
    }
    
    if (locationY < _contentOffsetPosition.startPos) {
        locationY = _contentOffsetPosition.startPos;
    } else if (locationY > _contentOffsetPosition.endPos) {
        locationY = _contentOffsetPosition.endPos;
    }
    
    NSIndexPathStruct newIndexPathStruct = [self _indexPathAtContentOffsetY:locationY - _contentListPosition.startPos];
    if (MPTV_IS_HEADER(newIndexPathStruct.row)) {
        if (newIndexPathStruct.section == _draggingIndexPath.section) {
            return;
        }
        
        newIndexPathStruct.row = 0;
    } else if (MPTV_IS_FOOTER(newIndexPathStruct.row)) {
        if (newIndexPathStruct.section == _draggingIndexPath.section) {
            return;
        }
        
        MPTableViewSection *section = _sectionsArray[newIndexPathStruct.section];
        newIndexPathStruct.row = section.numberOfRows;
    } else {
        MPTableViewSection *section = _sectionsArray[newIndexPathStruct.section];
        CGFloat startPos = [section startPositionAtRow:newIndexPathStruct.row];
        CGFloat endPos = [section endPositionAtRow:newIndexPathStruct.row];
        CGFloat targetCenterY = startPos + (endPos - startPos) / 2 + _contentListPosition.startPos;
        
        CGRect frame = [self _cellFrameAtIndexPath:_draggingIndexPath];
        CGFloat centerY = _draggingCell.center.y;
        CGFloat minY = centerY - frame.size.height / 2;
        CGFloat maxY = centerY + frame.size.height / 2;
        if (targetCenterY < minY || targetCenterY > maxY) { // the dragged cell must move across the center.y of the target cell
            return;
        }
    }
    
    if (_NSIndexPathCompareStruct(_draggingIndexPath, newIndexPathStruct) == NSOrderedSame) {
        return;
    }
    
    NSIndexPath *newIndexPath = _NSIndexPathFromStruct(newIndexPathStruct);
    if (_respond_targetIndexPathForMoveFromRowAtIndexPathToProposedIndexPath) {
        _updateSubviewsLock = YES;
        newIndexPath = [_tableViewDataSource MPTableView:self targetIndexPathForMoveFromRowAtIndexPath:_draggingSourceIndexPath toProposedIndexPath:newIndexPath];
        _updateSubviewsLock = NO;
        if (!newIndexPath) {
            return;
        }
        
        if (newIndexPath.section < 0 || newIndexPath.row < 0) {
            NSAssert(NO, @"newIndexPath.section and newIndexPath.row can not be negative");
            return;
        }
        
        if (newIndexPath.section >= _sectionsArray.count) {
            return;
        } else {
            MPTableViewSection *section = _sectionsArray[newIndexPath.section];
            if (newIndexPath.row > section.numberOfRows) {
                return;
            }
        }
        
        if ([newIndexPath isEqual:_draggingIndexPath]) {
            return;
        }
    }
    
    if (newIndexPath.row == NSIntegerMax) {
        MPTV_EXCEPTION(@"max number of rows in a section is NSIntegerMax");
    }
    
    _updateSubviewsLock = YES;
    [self _clipCellsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    _updateSubviewsLock = NO;
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    updateManager.dragFromSection = _draggingIndexPath.section;
    updateManager.dragToSection = newIndexPath.section;
    [updateManager addMoveOutIndexPath:_draggingIndexPath];
    [updateManager addMoveInIndexPath:newIndexPath withLastIndexPath:_draggingIndexPath withLastFrame:[self _cellFrameAtIndexPath:_draggingIndexPath]];
    _draggingIndexPath = newIndexPath;
    
    NSIndexPathStruct beginIndexPath = _beginIndexPath;
    NSIndexPathStruct endIndexPath = _endIndexPath;
    [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    if (_NSIndexPathStructCompareStruct(_beginIndexPath, beginIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(_endIndexPath, endIndexPath) == NSOrderedDescending) {
        _supplementSubviewsNeededFlag = YES;
    }
}

- (void)_endDraggingCellIfNeededImmediately:(BOOL)immediately {
    /*
     for a situation like:
     tableView.dragModeEnabled = NO;
     [tableView reloadData];
     */
    if (!_dragModeAutoScrollDisplayLink) {
        if (immediately) {
            if (!_draggingCell) {
                return;
            }
        } else {
            return;
        }
    }
    
    NSIndexPath *draggingSourceIndexPath = _draggingSourceIndexPath;
    MPTableViewCell *draggingCell = _draggingCell;
    NSUInteger draggedStep = _draggedStep;
    
    if (_dragModeAutoScrollDisplayLink) {
        [_dragModeAutoScrollDisplayLink invalidate];
        _dragModeAutoScrollDisplayLink = nil;
        
        if (_respond_moveRowAtIndexPathToIndexPath) {
            _updateSubviewsLock = YES;
            [_tableViewDataSource MPTableView:self moveRowAtIndexPath:draggingSourceIndexPath toIndexPath:_draggingIndexPath];
            _updateSubviewsLock = NO;
        }
    }
    
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (!_draggingCell) {
            return;
        }
        
        if (draggedStep == _draggedStep) {
            _draggingSourceIndexPath = _draggingIndexPath = nil;
            _draggingCell = nil;
        }
        
        _updateSubviewsLock = YES;
        
        if (_respond_didEndMovingCellFromRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self didEndMovingCell:draggingCell fromRowAtIndexPath:draggingSourceIndexPath];
        }
        
        if (!immediately) {
            [self _clipCellsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
        }
        
        _updateSubviewsLock = NO;
    };
    
    CGRect frame = [self _cellFrameAtIndexPath:_draggingIndexPath];
    if (immediately) {
        MPSetFrameForViewWithoutAnimation(_draggingCell, frame);
        completion(NO);
    } else {
        [UIView animateWithDuration:MPTableViewDefaultAnimationDuration animations:^{
            _draggingCell.frame = frame;
        } completion:completion];
    }
}

@end
