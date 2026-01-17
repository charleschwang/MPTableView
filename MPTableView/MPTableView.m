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
_NSIndexPathStructFromIndexPath(NSIndexPath *indexPath) {
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
    return _NSIndexPathStructCompareStruct(_NSIndexPathStructFromIndexPath(indexPath), indexPathStruct);
}

#pragma mark -

@interface MPTableView (UIGestureRecognizer)

- (BOOL)_shouldBeginDragGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;

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
    return [self.tableView _shouldBeginDragGestureRecognizer:gestureRecognizer];
}

@end

#pragma mark -

@interface MPTableViewReusableView (MPTableView)

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

NS_INLINE void
MPSetWidthForView(UIView *view, CGFloat width) {
    CGRect frame = view.frame;
    if (frame.size.width != width) {
        frame.size.width = width;
        view.frame = frame;
    }
}

NS_INLINE void
MPOffsetView(UIView *view, CGFloat offset) {
    CGRect frame = view.frame;
    frame.origin.y += offset;
    view.frame = frame;
}

static CGFloat
MPReusableViewHeightAfterLayoutWithFittingWidth(MPTableViewReusableView *reusableView, CGFloat width) {
    CGRect frame = reusableView.frame;
    frame.size.width = width;
    
    if ([UIView areAnimationsEnabled]) {
        [UIView setAnimationsEnabled:NO];
        
        frame.size.height = [reusableView heightAfterLayoutWithFittingWidth:width];
        reusableView.frame = frame;
        
        [UIView setAnimationsEnabled:YES];
    } else {
        frame.size.height = [reusableView heightAfterLayoutWithFittingWidth:width];
        reusableView.frame = frame;
    }
    
    return frame.size.height;
}

static MPTableViewRowAnimation
MPGetRandomAnimation() {
    u_int32_t random = arc4random() % MPTableViewRowAnimationRandom;
    return (MPTableViewRowAnimation)random;
}

static void
MPMakeViewDisappearWithAnimation(UIView *view, CGFloat top, MPTableViewRowAnimation animation, MPTableViewPosition *sectionPosition) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            frame.origin.y = top;
            view.alpha = 0;
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
                frame.origin.y = top + (sectionPosition.end - sectionPosition.start) / 2;
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
MPMakeViewAppearWithAnimation(UIView *view, CGRect previousFrame, CGFloat alpha, MPTableViewRowAnimation animation) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            frame.origin.y = previousFrame.origin.y;
            view.alpha = alpha;
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin = previousFrame.origin;
            view.alpha = alpha;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin = previousFrame.origin;
            view.alpha = alpha;
        }
            break;
        case MPTableViewRowAnimationTop: {
            frame.origin.y = previousFrame.origin.y;
            frame.size.height = previousFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationBottom: {
            frame.origin.y = previousFrame.origin.y;
            frame.size.height = previousFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationMiddle: {
            frame.origin.y = previousFrame.origin.y;
            frame.size.height = previousFrame.size.height;
            
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
MPPointSubtraction(CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x - point2.x, point1.y - point2.y);
}

//NS_INLINE CGPoint
//MPPointAddition(CGPoint point1, CGPoint point2) {
//    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
//}

NSString *const MPTableViewSelectionDidChangeNotification = @"MPTableViewSelectionDidChangeNotification";

static const NSTimeInterval MPTableViewDefaultAnimationDuration = 0.3;

#pragma mark -

@implementation MPTableView {
    UIView *_contentWrapperView;
    MPTableViewPosition *_listContentPosition; // list range in content coords (excludes tableHeader/Footer)
    MPTableViewPosition *_contentOffsetPosition; // visible range in content coords (current viewport)
    MPTableViewPosition *_listMappedContentOffsetPosition; // _contentOffsetPosition in list coords (minus _listContentPosition.start)
    
    NSIndexPathStruct _firstVisibleIndexPath, _lastVisibleIndexPath;
    
    NSMutableSet *_selectedIndexPaths;
    NSIndexPath *_highlightedIndexPath;
    
    BOOL
    _isInitializationPending,
    _isReloadingData,
    _isLayoutUpdateBlocked, // when set to YES, layout- and update-related functions cannot be executed.
    _isAdjustingPositions;
    
    NSInteger _numberOfSections;
    NSMutableArray *_sectionArray;
    NSMutableDictionary *_displayedCellDict, *_displayedSectionViewDict;
    NSMutableDictionary *_reusableCellArrayDict, *_registeredCellClassDict, *_registeredCellNibDict;
    NSMutableDictionary *_reusableViewArrayDict, *_registeredReusableViewClassDict, *_registeredReusableViewNibDict;
    
    __weak id <MPTableViewDelegate> _tableViewDelegate;
    __weak id <MPTableViewDataSource> _tableViewDataSource;
    
    BOOL
    _reloadDataRequiredFlag, // set to YES when the data source changes
    _layoutSubviewsRequiredFlag,
    _supplementSubviewsRequiredFlag;
    
    NSMutableDictionary *_fittedCellDict, *_fittedSectionViewDict;
    
    // update
    NSMutableArray *_updateManagerStack;
    NSInteger _updateContextDepth;
    
    NSInteger _activeUpdateAnimationCount;
    
    CGFloat _proposedInsertedLocationY, _proposedDeletedPositionY;
    
    NSMutableDictionary *_updatePendingCellDict, *_updatePendingSectionViewDict;
    
    NSMutableDictionary *_updatePendingRemovalCellDict, *_updatePendingRemovalSectionViewDict;
    
    NSMutableArray *_updateAnimationBlocks;
    NSMutableSet *_updateAnimatingIndexPaths, *_updatePendingAnimatingIndexPaths;
    NSMutableSet *_updatePendingSelectedIndexPaths;
    
    BOOL _willChangeContentOffsetDuringUpdate;
    NSMutableArray *_updateExecutionActions;
    
    // drag mode
    CGPoint _dragReferencePoint;
    CGFloat _dragAutoScrollRate, _dragAutoScrollDelta;
    MPTableViewLongGestureRecognizer *_dragLongGestureRecognizer;
    NSIndexPath *_draggingIndexPath, *_draggingSourceIndexPath;
    MPTableViewCell *_draggingCell;
    NSUInteger _draggingGeneration;
    CADisplayLink *_dragAutoScrollDisplayLink;
    
    // prefetch
    CGFloat _lastContentOffsetY;
    NSMutableArray *_prefetchIndexPaths;
    
    // protocols
    BOOL
    _respondsTo_numberOfSectionsInMPTableView,
    
    _respondsTo_heightForRowAtIndexPath,
    _respondsTo_heightForHeaderInSection,
    _respondsTo_heightForFooterInSection,
    
    _respondsTo_estimatedHeightForRowAtIndexPath,
    _respondsTo_estimatedHeightForHeaderInSection,
    _respondsTo_estimatedHeightForFooterInSection,
    
    _respondsTo_viewForHeaderInSection,
    _respondsTo_viewForFooterInSection,
    
    _respondsTo_canMoveRowAtIndexPath,
    _respondsTo_targetIndexPathForMoveFromRowAtIndexPathToProposedIndexPath,
    _respondsTo_rectForCellToMoveRowAtIndexPath,
    _respondsTo_moveRowAtIndexPathToIndexPath;
    
    BOOL
    _respondsTo_willDisplayCellForRowAtIndexPath,
    _respondsTo_willDisplayHeaderViewForSection,
    _respondsTo_willDisplayFooterViewForSection,
    _respondsTo_didEndDisplayingCellForRowAtIndexPath,
    _respondsTo_didEndDisplayingHeaderViewForSection,
    _respondsTo_didEndDisplayingFooterViewForSection,
    
    _respondsTo_willSelectRowAtIndexPath,
    _respondsTo_willDeselectRowAtIndexPath,
    _respondsTo_didSelectCellForRowAtIndexPath,
    _respondsTo_didDeselectRowAtIndexPath,
    
    _respondsTo_shouldHighlightRowAtIndexPath,
    _respondsTo_didHighlightRowAtIndexPath,
    _respondsTo_didUnhighlightRowAtIndexPath,
    
    _respondsTo_startToDeleteCellForRowAtIndexPath,
    _respondsTo_startToDeleteHeaderViewForSection,
    _respondsTo_startToDeleteFooterViewForSection,
    
    _respondsTo_startToInsertCellForRowAtIndexPath,
    _respondsTo_startToInsertHeaderViewForSection,
    _respondsTo_startToInsertFooterViewForSection,
    
    _respondsTo_shouldMoveRowAtIndexPath,
    _respondsTo_didEndMovingCellFromRowAtIndexPath;
    
    BOOL
    _respondsTo_prefetchRowsAtIndexPaths,
    _respondsTo_cancelPrefetchingForRowsAtIndexPaths;
}

@dynamic delegate;

#define MPTV_CHECK_DATASOURCE do { \
if (!_tableViewDataSource) { \
return MPTableViewSentinelFloatValue; \
} \
} while (0)

#define MPTV_POS_EPS_START(_pos_) ((_pos_) - 0.1)
#define MPTV_POS_EPS_END(_pos_) ((_pos_) + 0.1)
#define MPTV_OFFSCREEN(_frame_) ((_frame_).size.height <= 0 || MPTV_POS_EPS_START((_frame_).origin.y) > _contentOffsetPosition.end || MPTV_POS_EPS_END(CGRectGetMaxY(_frame_)) < _contentOffsetPosition.start)
#define MPTV_ONSCREEN(_frame_) ((_frame_).size.height > 0 && MPTV_POS_EPS_START((_frame_).origin.y) <= _contentOffsetPosition.end && MPTV_POS_EPS_END(CGRectGetMaxY(_frame_)) >= _contentOffsetPosition.start)

#pragma mark -

- (instancetype)initWithFrame:(CGRect)frame style:(MPTableViewStyle)style {
    if (self = [super initWithFrame:frame]) {
        _style = style;
        [self _setupWithoutDecoder];
        [self _setupComponents];
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
        
        _allowsCachingSubviewsDuringReload = [aDecoder decodeBoolForKey:@"_allowsCachingSubviewsDuringReload"];
        _allowsSelection = [aDecoder decodeBoolForKey:@"_allowsSelection"];
        _allowsMultipleSelection = [aDecoder decodeBoolForKey:@"_allowsMultipleSelection"];
        _shouldReloadAllDataDuringUpdate = [aDecoder decodeBoolForKey:@"_shouldReloadAllDataDuringUpdate"];
        _allowsOptimizingNumberOfSubviewsDuringUpdate = [aDecoder decodeBoolForKey:@"_allowsOptimizingNumberOfSubviewsDuringUpdate"];
        _shouldOptimizeUpdateAnimationsForAutoLayout = [aDecoder decodeBoolForKey:@"_shouldOptimizeUpdateAnimationsForAutoLayout"];
        _allowsUserInteractionDuringUpdate = [aDecoder decodeBoolForKey:@"_allowsUserInteractionDuringUpdate"];
        _dragModeEnabled = [aDecoder decodeBoolForKey:@"_dragModeEnabled"];
        _allowsSelectionInDragMode = [aDecoder decodeBoolForKey:@"_allowsSelectionInDragMode"];
        _allowsDraggedCellToFloat = [aDecoder decodeBoolForKey:@"_allowsDraggedCellToFloat"];
        _minimumPressDurationToBeginDrag = [aDecoder decodeDoubleForKey:@"_minimumPressDurationToBeginDrag"];
        
        _registeredCellNibDict = [aDecoder decodeObjectForKey:@"_registeredCellNibDict"];
        _registeredReusableViewNibDict = [aDecoder decodeObjectForKey:@"_registeredReusableViewNibDict"];
        
        [self _setupComponents];
        
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
    
    [self _resetDragLongGestureRecognizer];
    
    [aCoder encodeInteger:_style forKey:@"_tableViewStyle"];
    [aCoder encodeDouble:_rowHeight forKey:@"_rowHeight"];
    [aCoder encodeDouble:_sectionHeaderHeight forKey:@"_sectionHeaderHeight"];
    [aCoder encodeDouble:_sectionFooterHeight forKey:@"_sectionFooterHeight"];
    
    [aCoder encodeBool:_allowsCachingSubviewsDuringReload forKey:@"_allowsCachingSubviewsDuringReload"];
    [aCoder encodeBool:_allowsSelection forKey:@"_allowsSelection"];
    [aCoder encodeBool:_allowsMultipleSelection forKey:@"_allowsMultipleSelection"];
    [aCoder encodeBool:_shouldReloadAllDataDuringUpdate forKey:@"_shouldReloadAllDataDuringUpdate"];
    [aCoder encodeBool:_allowsOptimizingNumberOfSubviewsDuringUpdate forKey:@"_allowsOptimizingNumberOfSubviewsDuringUpdate"];
    [aCoder encodeBool:_shouldOptimizeUpdateAnimationsForAutoLayout forKey:@"_shouldOptimizeUpdateAnimationsForAutoLayout"];
    [aCoder encodeBool:_allowsUserInteractionDuringUpdate forKey:@"_allowsUserInteractionDuringUpdate"];
    [aCoder encodeBool:_dragModeEnabled forKey:@"_dragModeEnabled"];
    [aCoder encodeBool:_allowsSelectionInDragMode forKey:@"_allowsSelectionInDragMode"];
    [aCoder encodeBool:_allowsDraggedCellToFloat forKey:@"_allowsDraggedCellToFloat"];
    [aCoder encodeDouble:_minimumPressDurationToBeginDrag forKey:@"_minimumPressDurationToBeginDrag"];
    
    [aCoder encodeObject:_registeredCellNibDict forKey:@"_registeredCellNibDict"];
    [aCoder encodeObject:_registeredReusableViewNibDict forKey:@"_registeredReusableViewNibDict"];
    
    [_contentWrapperView removeFromSuperview];
    NSMutableArray *sectionViews = [NSMutableArray arrayWithArray:_displayedSectionViewDict.allValues];
    for (NSArray *array in _reusableViewArrayDict.allValues) {
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

- (void)_setupWithoutDecoder {
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
    _allowsCachingSubviewsDuringReload = YES;
    _shouldReloadAllDataDuringUpdate = YES;
    _allowsOptimizingNumberOfSubviewsDuringUpdate = NO;
    _shouldOptimizeUpdateAnimationsForAutoLayout = YES;
    _allowsUserInteractionDuringUpdate = YES;
    _dragModeEnabled = NO;
    _minimumPressDurationToBeginDrag = 0.1;
    _allowsSelectionInDragMode = NO;
    _allowsDraggedCellToFloat = NO;
}

- (void)_setupComponents {
    _isInitializationPending = YES;
    _isReloadingData = NO;
    _isLayoutUpdateBlocked = NO;
    _isAdjustingPositions = NO;
    
    [self addSubview:_contentWrapperView = [[UIView alloc] init]];
    _contentWrapperView.autoresizesSubviews = NO; // @optional
    
    _firstVisibleIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPTableViewSectionFooter);
    _lastVisibleIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPTableViewSectionHeader);
    _listContentPosition = [MPTableViewPosition positionWithStart:0 end:0];
    _contentOffsetPosition = [MPTableViewPosition positionWithStart:0 end:0];
    _listMappedContentOffsetPosition = [MPTableViewPosition positionWithStart:0 end:0];
    
    _numberOfSections = 0;
    _sectionArray = [[NSMutableArray alloc] init];
    _displayedCellDict = [[NSMutableDictionary alloc] init];
    _displayedSectionViewDict = [[NSMutableDictionary alloc] init];
    _reusableCellArrayDict = [[NSMutableDictionary alloc] init];
    _reusableViewArrayDict = [[NSMutableDictionary alloc] init];
    
    _selectedIndexPaths = [[NSMutableSet alloc] init];
    _draggingGeneration = 0;
    
    _reloadDataRequiredFlag = NO;
    _layoutSubviewsRequiredFlag = NO;
    _supplementSubviewsRequiredFlag = NO;
    
    _updateContextDepth = 0;
    _activeUpdateAnimationCount = 0;
    _willChangeContentOffsetDuringUpdate = NO;
}

- (void)dealloc {
    [self _clearDataWithCacheSubviewsEnabled:NO];
}

#pragma mark -

- (void)_respondsToDataSource {
    _respondsTo_numberOfSectionsInMPTableView = [_tableViewDataSource respondsToSelector:@selector(numberOfSectionsInMPTableView:)];
    
    _respondsTo_heightForRowAtIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:heightForRowAtIndexPath:)];
    _respondsTo_heightForHeaderInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:heightForHeaderInSection:)];
    _respondsTo_heightForFooterInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:heightForFooterInSection:)];
    
    _respondsTo_estimatedHeightForRowAtIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForRowAtIndexPath:)];
    _respondsTo_estimatedHeightForHeaderInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForHeaderInSection:)];
    _respondsTo_estimatedHeightForFooterInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForFooterInSection:)];
    
    _respondsTo_viewForHeaderInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:viewForHeaderInSection:)];
    _respondsTo_viewForFooterInSection = [_tableViewDataSource respondsToSelector:@selector(MPTableView:viewForFooterInSection:)];
    
    _respondsTo_canMoveRowAtIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:canMoveRowAtIndexPath:)];
    _respondsTo_targetIndexPathForMoveFromRowAtIndexPathToProposedIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)];
    _respondsTo_rectForCellToMoveRowAtIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:rectForCellToMoveRowAtIndexPath:)];
    _respondsTo_moveRowAtIndexPathToIndexPath = [_tableViewDataSource respondsToSelector:@selector(MPTableView:moveRowAtIndexPath:toIndexPath:)];
}

- (void)_respondsToDelegate {
    _respondsTo_willDisplayCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willDisplayCell:forRowAtIndexPath:)];
    _respondsTo_willDisplayHeaderViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willDisplayHeaderView:forSection:)];
    _respondsTo_willDisplayFooterViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willDisplayFooterView:forSection:)];
    
    _respondsTo_didEndDisplayingCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingCell:forRowAtIndexPath:)];
    _respondsTo_didEndDisplayingHeaderViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingHeaderView:forSection:)];
    _respondsTo_didEndDisplayingFooterViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingFooterView:forSection:)];
    
    _respondsTo_willSelectRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willSelectRowAtIndexPath:)];
    _respondsTo_willDeselectRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:willDeselectRowAtIndexPath:)];
    _respondsTo_didSelectCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didSelectCell:forRowAtIndexPath:)];
    _respondsTo_didDeselectRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didDeselectRowAtIndexPath:)];
    
    _respondsTo_shouldHighlightRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:shouldHighlightRowAtIndexPath:)];
    _respondsTo_didHighlightRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didHighlightRowAtIndexPath:)];
    _respondsTo_didUnhighlightRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didUnhighlightRowAtIndexPath:)];
    
    _respondsTo_startToDeleteCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:startToDeleteCell:forRowAtIndexPath:withProposedPosition:)];
    _respondsTo_startToDeleteHeaderViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:startToDeleteHeaderView:forSection:withProposedPosition:)];
    _respondsTo_startToDeleteFooterViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:startToDeleteFooterView:forSection:withProposedPosition:)];
    
    _respondsTo_startToInsertCellForRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:startToInsertCell:forRowAtIndexPath:withProposedLocation:)];
    _respondsTo_startToInsertHeaderViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:startToInsertHeaderView:forSection:withProposedLocation:)];
    _respondsTo_startToInsertFooterViewForSection = [_tableViewDelegate respondsToSelector:@selector(MPTableView:startToInsertFooterView:forSection:withProposedLocation:)];
    
    _respondsTo_shouldMoveRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:shouldMoveRowAtIndexPath:)];
    _respondsTo_didEndMovingCellFromRowAtIndexPath = [_tableViewDelegate respondsToSelector:@selector(MPTableView:didEndMovingCell:fromRowAtIndexPath:)];
}

- (void)_respondsToPrefetchDataSource {
    _respondsTo_prefetchRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:prefetchRowsAtIndexPaths:)];
    _respondsTo_cancelPrefetchingForRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:cancelPrefetchingForRowsAtIndexPaths:)];
}

#pragma mark -

- (void)setDataSource:(id<MPTableViewDataSource>)dataSource {
    NSParameterAssert(!_isLayoutUpdateBlocked);
    NSParameterAssert(!_isReloadingData);
    NSParameterAssert(_updateContextDepth == 0); // the data source must not be changed inside a -performBatchUpdates call
    if (!dataSource && !_tableViewDataSource) {
        return;
    }
    
    if (dataSource) {
        if (![dataSource respondsToSelector:@selector(MPTableView:cellForRowAtIndexPath:)] || ![dataSource respondsToSelector:@selector(MPTableView:numberOfRowsInSection:)]) {
            NSAssert(NO, @"dataSource does not implement required methods");
            return;
        }
    }
    
    _tableViewDataSource = dataSource;
    [self _respondsToDataSource];
    
    if ([self _isEstimatedMode] && !_fittedCellDict) {
        _fittedCellDict = [[NSMutableDictionary alloc] init];
        _fittedSectionViewDict = [[NSMutableDictionary alloc] init];
    }
    
    _isInitializationPending = NO;
    _reloadDataRequiredFlag = YES;
    _layoutSubviewsRequiredFlag = YES;
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
    NSParameterAssert(!_isLayoutUpdateBlocked);
    NSParameterAssert(!_isReloadingData);
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
    NSParameterAssert(!_isLayoutUpdateBlocked);
    NSParameterAssert(!_isReloadingData);
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
    
    UIEdgeInsets previousContentInset = [self _innerContentInset];
    [super setContentInset:contentInset];
    _lastContentOffsetY = self.contentOffset.y;
    
    if (_reloadDataRequiredFlag) {
        return;
    }
    
    contentInset = [self _innerContentInset];
    if (previousContentInset.top == contentInset.top && previousContentInset.bottom == contentInset.bottom) {
        return;
    }
    
    if (_style == MPTableViewStylePlain) {
        _supplementSubviewsRequiredFlag = YES;
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
    CGRect previousFrame = [super frame];
    if (CGRectEqualToRect(previousFrame, frame)) {
        return;
    }
    
    UIEdgeInsets previousContentInset = [self _innerContentInset];
    [super setFrame:frame];
    [self _layoutBackgroundViewIfNeeded];
    
    if (_reloadDataRequiredFlag) {
        return;
    }
    
    frame = [super frame]; // to guard against values less than 0
    if (previousFrame.size.width != frame.size.width) {
        [self _resizeSubviewsToWidth:frame.size.width];
    }
    
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (previousFrame.size.height == frame.size.height && previousContentInset.top == contentInset.top && previousContentInset.bottom == contentInset.bottom) {
        return;
    }
    
    if (_style == MPTableViewStylePlain) {
        _supplementSubviewsRequiredFlag = YES;
    }
    [self _layoutSubviewsInternal];
}

- (void)setBounds:(CGRect)bounds {
    CGRect previousBounds = [super bounds];
    if (CGRectEqualToRect(previousBounds, bounds)) {
        return;
    }
    
    UIEdgeInsets previousContentInset = [self _innerContentInset];
    [super setBounds:bounds];
    [self _layoutBackgroundViewIfNeeded];
    
    if (_reloadDataRequiredFlag) {
        return;
    }
    
    bounds = [super bounds];
    if (previousBounds.size.width != bounds.size.width) {
        [self _resizeSubviewsToWidth:bounds.size.width];
    }
    
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (previousBounds.size.height == bounds.size.height && previousContentInset.top == contentInset.top && previousContentInset.bottom == contentInset.bottom) {
        return;
    }
    
    if (_style == MPTableViewStylePlain) {
        _supplementSubviewsRequiredFlag = YES;
    }
    [self _layoutSubviewsInternal];
}

- (void)_resizeSubviewsToWidth:(CGFloat)width {
    MPSetWidthForView(_tableHeaderView, width);
    MPSetWidthForView(_tableFooterView, width);
    
    for (MPTableViewCell *cell in _displayedCellDict.allValues) {
        MPSetWidthForView(cell, width);
    }
    for (UIView *sectionView in _displayedSectionViewDict.allValues) {
        MPSetWidthForView(sectionView, width);
    }
    
    for (MPTableViewCell *cell in _updatePendingCellDict.allValues) {
        MPSetWidthForView(cell, width);
    }
    for (UIView *sectionView in _updatePendingSectionViewDict.allValues) {
        MPSetWidthForView(sectionView, width);
    }
    
    CGSize contentSize = self.contentSize;
    contentSize.width = width;
    self.contentSize = contentSize;
}

- (void)removeFromSuperview {
    [self _endDraggingCellIfNeededImmediately:YES];
    _dragLongGestureRecognizer.enabled = NO; // -dealloc may not be called when minimumPressDuration is 0 and navigationController.interactivePopGestureRecognizer is enabled (use it to pop the present view controller).
    [super removeFromSuperview];
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    _dragLongGestureRecognizer.enabled = _dragModeEnabled;
}

- (NSInteger)numberOfSections {
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    return _numberOfSections;
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    if (_numberOfSections == 0 || section >= _sectionArray.count) {
        return NSNotFound;
    } else {
        MPTableViewSection *sectionPosition = _sectionArray[section];
        return sectionPosition.numberOfRows;
    }
}

- (void)setRowHeight:(CGFloat)rowHeight {
    if (rowHeight < 0) {
        NSAssert(NO, @"row height must not be negative");
        rowHeight = 0;
    }
    
    _rowHeight = rowHeight;
}

- (void)setSectionHeaderHeight:(CGFloat)sectionHeaderHeight {
    if (sectionHeaderHeight < 0) {
        NSAssert(NO, @"section header height must not be negative");
        sectionHeaderHeight = 0;
    }
    
    _sectionHeaderHeight = sectionHeaderHeight;
}

- (void)setSectionFooterHeight:(CGFloat)sectionFooterHeight {
    if (sectionFooterHeight < 0) {
        NSAssert(NO, @"section footer height must not be negative");
        sectionFooterHeight = 0;
    }
    
    _sectionFooterHeight = sectionFooterHeight;
}

- (void)_relayoutSectionViews:(NSDictionary *)sectionViews byOffset:(CGFloat)offset {
    if (_style == MPTableViewStylePlain) {
        [sectionViews enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, MPTableViewReusableView *sectionView, BOOL *stop) {
            MPTableViewSection *section = _sectionArray[indexPath.section];
            MPTableViewSectionViewType type = indexPath.row;
            if ([self _needsStickViewAtSection:section viewType:type]) {
                sectionView.frame = [self _stickingFrameAtSection:section viewType:type];
            } else if ([self _needsPrepareStickViewAtSection:section viewType:type]) {
                sectionView.frame = [self _prepareFrameForStickViewAtSection:section viewType:type];
            } else {
                sectionView.frame = [self _sectionViewFrameAtSection:section viewType:type];
            }
        }];
    } else {
        for (UIView *sectionView in sectionViews.allValues) {
            MPOffsetView(sectionView, offset);
        }
    }
}

- (void)_relayoutSubviewsByOffset:(CGFloat)offset {
    if (_tableFooterView) {
        MPOffsetView(_tableFooterView, offset);
    }
    
    MPTableViewCell *draggingCell = _dragAutoScrollDisplayLink ? _draggingCell : nil;
    for (MPTableViewCell *cell in _displayedCellDict.allValues) {
        if (cell == draggingCell) {
            continue;
        }
        MPOffsetView(cell, offset);
    }
    for (MPTableViewCell *cell in _updatePendingCellDict.allValues) {
        if (cell == draggingCell) {
            continue;
        }
        MPOffsetView(cell, offset);
    }
    
    [self _relayoutSectionViews:_displayedSectionViewDict byOffset:offset];
    [self _relayoutSectionViews:_updatePendingSectionViewDict byOffset:offset];
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
    
    if (_listContentPosition.start == height) {
        return;
    }
    
    CGFloat offset = height - _listContentPosition.start;
    _listContentPosition.start += offset;
    _listContentPosition.end += offset;
    
    CGPoint contentOffset = self.contentOffset;
    self.contentSize = CGSizeMake(self.bounds.size.width, _listContentPosition.end + _tableFooterView.bounds.size.height);
    if (_reloadDataRequiredFlag) {
        return;
    }
    
    [UIView performWithoutAnimation:^{
        [self _relayoutSubviewsByOffset:offset];
    }];
    
    if (_style == MPTableViewStylePlain && contentOffset.y != self.contentOffset.y) {
        _supplementSubviewsRequiredFlag = YES;
    }
    [self _layoutSubviewsInternal];
}

- (void)setTableFooterView:(UIView *)tableFooterView {
    NSParameterAssert(tableFooterView != _tableHeaderView || !_tableHeaderView);
    NSParameterAssert(tableFooterView != _backgroundView || !_backgroundView);
    if (_tableFooterView == tableFooterView && [_tableFooterView superview] == self) {
        return;
    }
    
    CGFloat previousHeight = _tableFooterView.bounds.size.height;
    if ([_tableFooterView superview] == self) {
        [_tableFooterView removeFromSuperview];
    }
    _tableFooterView = tableFooterView;
    
    CGFloat height = 0;
    if (_tableFooterView) {
        CGRect frame = _tableFooterView.frame;
        frame.origin = CGPointMake(0, _listContentPosition.end);
        frame.size.width = self.bounds.size.width;
        MPSetFrameForViewWithoutAnimation(_tableFooterView, frame);
        [self addSubview:_tableFooterView];
        height = frame.size.height;
    }
    
    if (previousHeight == height) {
        return;
    }
    
    CGPoint contentOffset = self.contentOffset;
    self.contentSize = CGSizeMake(self.bounds.size.width, _listContentPosition.end + _tableFooterView.bounds.size.height);
    if (_reloadDataRequiredFlag || contentOffset.y == self.contentOffset.y) {
        return;
    }
    
    if (_style == MPTableViewStylePlain) {
        _supplementSubviewsRequiredFlag = YES;
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

- (MPTableViewReusableView *)sectionHeaderInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    return [_displayedSectionViewDict objectForKey:_NSIndexPathInSectionForRow(section, MPTableViewSectionHeader)];
}

- (MPTableViewReusableView *)sectionFooterInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    return [_displayedSectionViewDict objectForKey:_NSIndexPathInSectionForRow(section, MPTableViewSectionFooter)];
}

- (MPTableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return nil;
    }
    
    if (indexPath.section < 0 || indexPath.row < 0) {
        NSAssert(NO, @"indexPath.section and indexPath.row must not be negative");
        return nil;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    MPTableViewCell *cell = [_displayedCellDict objectForKey:indexPath];
    return cell;
}

- (NSIndexPath *)indexPathForCell:(MPTableViewCell *)cell {
    if (!cell) {
        return nil;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    for (NSIndexPath *indexPath in _displayedCellDict.allKeys) {
        MPTableViewCell *_cell = [_displayedCellDict objectForKey:indexPath];
        if (_cell == cell) {
            return indexPath;
        }
    }
    
    return nil;
}

- (NSArray *)visibleCells {
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    return _displayedCellDict.allValues;
}

- (NSArray *)visibleCellsInRect:(CGRect)rect {
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    if (rect.origin.x > self.bounds.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _listContentPosition.end || CGRectGetMaxY(rect) < _listContentPosition.start || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *visibleCells = [[NSMutableArray alloc] init];
    for (MPTableViewCell *cell in _displayedCellDict.allValues) {
        if (CGRectIntersectsRect(rect, cell.frame)) {
            [visibleCells addObject:cell];
        }
    }
    
    return visibleCells;
}

- (NSArray *)indexPathsForVisibleRows {
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    return _displayedCellDict.allKeys;
}

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect {
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0) {
        return nil;
    }
    
    if (rect.origin.x > self.bounds.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _listContentPosition.end || CGRectGetMaxY(rect) < _listContentPosition.start || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    
    CGFloat edgeY = rect.origin.y;
    if (edgeY < _listContentPosition.start) {
        edgeY = _listContentPosition.start;
    }
    NSIndexPathStruct firstVisibleIndexPath = [self _indexPathForContentOffsetY:edgeY - _listContentPosition.start];
    edgeY = CGRectGetMaxY(rect);
    if (edgeY > _listContentPosition.end) {
        edgeY = _listContentPosition.end;
    }
    NSIndexPathStruct lastVisibleIndexPath = [self _indexPathForContentOffsetY:edgeY - _listContentPosition.start];
    
    for (NSInteger i = firstVisibleIndexPath.section; i <= lastVisibleIndexPath.section; i++) {
        MPTableViewSection *section = _sectionArray[i];
        NSInteger numberOfRows = section.numberOfRows;
        if (i == firstVisibleIndexPath.section) {
            NSInteger j;
            if (MPTV_IS_HEADER(firstVisibleIndexPath.row)) {
                j = 0;
            } else if (MPTV_IS_FOOTER(firstVisibleIndexPath.row)) {
                j = numberOfRows;
            } else {
                j = firstVisibleIndexPath.row;
            }
            if (firstVisibleIndexPath.section == lastVisibleIndexPath.section) {
                if (MPTV_IS_HEADER(lastVisibleIndexPath.row)) {
                    break;
                } else if (lastVisibleIndexPath.row < MPTableViewSectionFooter) {
                    numberOfRows = lastVisibleIndexPath.row + 1;
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
            if (i == lastVisibleIndexPath.section) {
                if (MPTV_IS_HEADER(lastVisibleIndexPath.row)) {
                    numberOfRows = 0;
                } else if (lastVisibleIndexPath.row < MPTableViewSectionFooter) {
                    numberOfRows = lastVisibleIndexPath.row + 1;
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
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0 || section >= _sectionArray.count) {
        return nil;
    }
    
    MPTableViewSection *sectionPosition = _sectionArray[section];
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
    return _reusableCellArrayDict.allKeys;
}

- (NSArray *)identifiersForReusableViews {
    return _reusableViewArrayDict.allKeys;
}

- (NSUInteger)numberOfReusableCellsWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    NSArray *array = [_reusableCellArrayDict objectForKey:identifier];
    return array.count;
}

- (NSUInteger)numberOfReusableViewsWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    NSArray *array = [_reusableViewArrayDict objectForKey:identifier];
    return array.count;
}

- (void)discardReusableCellsWithIdentifier:(NSString *)identifier count:(NSUInteger)count {
    NSParameterAssert(identifier);
    NSMutableArray *array = [_reusableCellArrayDict objectForKey:identifier];
    NSParameterAssert(count > 0 && count <= array.count);
    if (array.count > 0) {
        NSRange subRange = NSMakeRange(array.count - count, count);
        NSArray *sub = [array subarrayWithRange:subRange];
        [sub makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [array removeObjectsInRange:subRange];
    }
}

- (void)discardReusableViewsWithIdentifier:(NSString *)identifier count:(NSUInteger)count {
    NSParameterAssert(identifier);
    NSMutableArray *array = [_reusableViewArrayDict objectForKey:identifier];
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

- (NSIndexPath *)firstVisibleIndexPath {
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSIndexPathStruct firstVisibleIndexPath = _firstVisibleIndexPath;
    if (MPTV_IS_HEADER(firstVisibleIndexPath.row) || MPTV_IS_FOOTER(firstVisibleIndexPath.row)) {
        firstVisibleIndexPath.row = NSNotFound;
    }
    return _NSIndexPathFromStruct(firstVisibleIndexPath);
}

- (NSIndexPath *)lastVisibleIndexPath {
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSIndexPathStruct lastVisibleIndexPath = _lastVisibleIndexPath;
    if (MPTV_IS_HEADER(lastVisibleIndexPath.row) || MPTV_IS_FOOTER(lastVisibleIndexPath.row)) {
        lastVisibleIndexPath.row = NSNotFound;
    }
    return _NSIndexPathFromStruct(lastVisibleIndexPath);
}

- (CGRect)rectForSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0 || section >= _sectionArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionArray[section];
    frame.origin = CGPointMake(0, _listContentPosition.start + sectionPosition.start);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.end - sectionPosition.start);
    return frame;
}

- (CGRect)rectForHeaderInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0 || section >= _sectionArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionArray[section];
    frame.origin = CGPointMake(0, _listContentPosition.start + sectionPosition.start);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.headerHeight);
    return frame;
}

- (CGRect)rectForFooterInSection:(NSInteger)section {
    if (section < 0) {
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0 || section >= _sectionArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionArray[section];
    frame.origin = CGPointMake(0, _listContentPosition.start + sectionPosition.start);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.footerHeight);
    return frame;
}

- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return CGRectNull;
    }
    
    if (indexPath.section < 0 || indexPath.row < 0) {
        NSAssert(NO, @"indexPath.section and indexPath.row must not be negative");
        return CGRectNull;
    }
    
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0 || indexPath.section >= _sectionArray.count) {
        return CGRectNull;
    }
    
    MPTableViewSection *section = _sectionArray[indexPath.section];
    if (indexPath.row >= section.numberOfRows) {
        return CGRectNull;
    }
    
    return [self _cellFrameAtIndexPath:indexPath];
}

- (NSInteger)indexForSectionAtPoint:(CGPoint)point {
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0 || point.y < _listContentPosition.start || point.y > _listContentPosition.end) {
        return NSNotFound;
    } else {
        return [self _sectionForContentOffsetY:point.y - _listContentPosition.start];
    }
}

- (NSInteger)indexForSectionHeaderAtPoint:(CGPoint)point {
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    NSInteger section = [self indexForSectionAtPoint:point];
    if (section != NSNotFound) {
        MPTableViewSection *sectionPosition = _sectionArray[section];
        if (sectionPosition.headerHeight == 0 || sectionPosition.start + sectionPosition.headerHeight < point.y - _listContentPosition.start) {
            section = NSNotFound;
        }
    }
    
    return section;
}

- (NSInteger)indexForSectionFooterAtPoint:(CGPoint)point {
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    NSInteger section = [self indexForSectionAtPoint:point];
    if (section != NSNotFound) {
        MPTableViewSection *sectionPosition = _sectionArray[section];
        if (sectionPosition.footerHeight == 0 || sectionPosition.end - sectionPosition.footerHeight > point.y - _listContentPosition.start) {
            section = NSNotFound;
        }
    }
    
    return section;
}

- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point {
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    NSAssert(!_isAdjustingPositions, @"table view is adjusting subview positions so unable to seek the right position");
    
    if (_numberOfSections == 0 || point.y < _listContentPosition.start || point.y > _listContentPosition.end) {
        return nil;
    }
    
    CGFloat originY = point.y;
    if (originY < _listContentPosition.start) {
        originY = _listContentPosition.start;
    } else if (originY > _listContentPosition.end) {
        originY = _listContentPosition.end;
    }
    
    CGFloat contentOffsetY = originY - _listContentPosition.start;
    NSInteger section = [self _sectionForContentOffsetY:contentOffsetY];
    MPTableViewSection *sectionPosition = _sectionArray[section];
    if (sectionPosition.numberOfRows == 0) {
        return nil;
    }
    NSInteger row = [sectionPosition rowForContentOffsetY:contentOffsetY];
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
        NSAssert(NO, @"indexPath.section and indexPath.row must not be negative");
        return;
    }
    
    if (_isInitializationPending) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(indexPath.section < _sectionArray.count, @"section index is out of bounds");
    
    MPTableViewSection *section = _sectionArray[indexPath.section];
    NSAssert(indexPath.row < section.numberOfRows, @"row index is out of bounds");
    
    CGFloat contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            contentOffsetY = [section startPositionAtRow:indexPath.row] - [self _innerContentInset].top;
            if (_respondsTo_viewForHeaderInSection && _style == MPTableViewStylePlain) {
                contentOffsetY -= section.headerHeight;
            }
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat startPosition = [section startPositionAtRow:indexPath.row];
            CGFloat endPosition = [section endPositionAtRow:indexPath.row];
            contentOffsetY = startPosition + (endPosition - startPosition) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            contentOffsetY = [section endPositionAtRow:indexPath.row] - self.bounds.size.height + [self _innerContentInset].bottom;
            if (_respondsTo_viewForFooterInSection && _style == MPTableViewStylePlain) {
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
    contentOffsetY += _listContentPosition.start;
    CGFloat contentEndPositionY = _listContentPosition.end + _tableFooterView.bounds.size.height;
    UIEdgeInsets contentInset = [self _innerContentInset];
    CGFloat maxContentOffsetY = contentEndPositionY + contentInset.bottom - self.bounds.size.height;
    CGFloat minContentOffsetY = -contentInset.top;
    
    if (contentOffsetY > maxContentOffsetY) {
        contentOffsetY = maxContentOffsetY;
    }
    if (contentOffsetY < minContentOffsetY) {
        contentOffsetY = minContentOffsetY;
    }
    
    [self setContentOffset:CGPointMake(0, contentOffsetY) animated:animated];
}

- (void)scrollToHeaderInSection:(NSInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (section < 0) {
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_isInitializationPending) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(section < _sectionArray.count, @"section index is out of bounds");
    
    MPTableViewSection *sectionPosition = _sectionArray[section];
    
    CGFloat contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            contentOffsetY = sectionPosition.start - [self _innerContentInset].top;
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat startPosition = sectionPosition.start;
            CGFloat endPosition = sectionPosition.start + sectionPosition.headerHeight;
            contentOffsetY = startPosition + (endPosition - startPosition) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            contentOffsetY = sectionPosition.start + sectionPosition.headerHeight - self.bounds.size.height + [self _innerContentInset].bottom;
        }
            break;
        default:
            return;
    }
    
    [self _scrollToContentOffsetY:contentOffsetY animated:animated];
}

- (void)scrollToFooterInSection:(NSInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (section < 0) {
        NSAssert(NO, @"section must not be negative");
        section = 0;
    }
    
    if (_isInitializationPending) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    NSAssert(section < _sectionArray.count, @"section index is out of bounds");
    
    MPTableViewSection *sectionPosition = _sectionArray[section];
    
    CGFloat contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            contentOffsetY = sectionPosition.end - sectionPosition.footerHeight - [self _innerContentInset].top;
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat startPosition = sectionPosition.end - sectionPosition.footerHeight;
            CGFloat endPosition = sectionPosition.end;
            contentOffsetY = startPosition + (endPosition - startPosition) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            contentOffsetY = sectionPosition.end - self.bounds.size.height + [self _innerContentInset].bottom;
        }
            break;
        default:
            return;
    }
    
    [self _scrollToContentOffsetY:contentOffsetY animated:animated];
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection {
    if (_isLayoutUpdateBlocked) {
        return;
    }
    
    if (_allowsMultipleSelection == allowsMultipleSelection) {
        return;
    }
    
    if (!allowsMultipleSelection) {
        if (_selectedIndexPaths.count > 0) {
            _isLayoutUpdateBlocked = YES;
            for (NSIndexPath *indexPath in _selectedIndexPaths) { // safe to iterate the set directly, no mutation happens here other code paths use -allObjects because the set may be mutated.
                [self _deselectRowAtIndexPath:indexPath animated:NO shouldRemove:NO shouldSetAnimated:YES]; // shouldSetAnimated:YES ensures the cell uses -setSelected:animated: (not -setSelected:)
            }
            [_selectedIndexPaths removeAllObjects];
            _isLayoutUpdateBlocked = NO;
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
        NSAssert(NO, @"indexPath.section and indexPath.row must not be negative");
        return;
    }
    
    if (_isInitializationPending || _isLayoutUpdateBlocked) {
        return;
    }
    
    if (_layoutSubviewsRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (_respondsTo_willSelectRowAtIndexPath) {
        _isLayoutUpdateBlocked = YES;
        indexPath = [_tableViewDelegate MPTableView:self willSelectRowAtIndexPath:indexPath];
        _isLayoutUpdateBlocked = NO;
        if (!indexPath) {
            return;
        }
        
        if (indexPath.section < 0 || indexPath.row < 0) {
            NSAssert(NO, @"indexPath.section and indexPath.row must not be negative");
            return;
        }
    }
    
    if (indexPath.section >= _sectionArray.count) {
        return;
    } else {
        MPTableViewSection *section = _sectionArray[indexPath.section];
        if (indexPath.row >= section.numberOfRows) {
            return;
        }
    }
    
    if ([_selectedIndexPaths containsObject:indexPath]) {
        return;
    }
    
    if (!_allowsMultipleSelection && _selectedIndexPaths.count > 0) {
        _isLayoutUpdateBlocked = YES;
        for (NSIndexPath *indexPath in _selectedIndexPaths.allObjects) {
            [self _deselectRowAtIndexPath:indexPath animated:NO shouldRemove:YES shouldSetAnimated:NO];
        }
        _isLayoutUpdateBlocked = NO;
    }
    
    [_selectedIndexPaths addObject:indexPath];
    MPTableViewCell *cell = [_displayedCellDict objectForKey:indexPath];
    if (cell) {
        [cell setSelected:YES animated:animated];
    }
    [self scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
    
    if (_respondsTo_didSelectCellForRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self didSelectCell:cell forRowAtIndexPath:indexPath];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (_isInitializationPending) {
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

- (void)_deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated shouldRemove:(BOOL)shouldRemove shouldSetAnimated:(BOOL)shouldSetAnimated {
    if (!indexPath) {
        return;
    }
    
    BOOL selected = YES;
    if (shouldRemove) {
        if (_respondsTo_willDeselectRowAtIndexPath) {
            selected = [_selectedIndexPaths containsObject:indexPath];
            
            NSIndexPath *newIndexPath = [_tableViewDelegate MPTableView:self willDeselectRowAtIndexPath:indexPath];
            if (!newIndexPath) {
                return;
            }
            
            if (newIndexPath.section < 0 || newIndexPath.row < 0) {
                NSAssert(NO, @"newIndexPath.section and newIndexPath.row must not be negative");
                return;
            }
            
            if (newIndexPath.section >= _sectionArray.count) {
                return;
            } else {
                MPTableViewSection *section = _sectionArray[newIndexPath.section];
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
    
    MPTableViewCell *selectedCell = [_displayedCellDict objectForKey:indexPath];
    if (selectedCell) {
        if (shouldSetAnimated) {
            [selectedCell setSelected:NO animated:animated];
        } else {
            [selectedCell setSelected:NO];
        }
    }
    
    if (_respondsTo_didDeselectRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self didDeselectRowAtIndexPath:indexPath];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    if (!indexPath) {
        return;
    }
    
    if (indexPath.section < 0 || indexPath.row < 0) {
        NSAssert(NO, @"indexPath.section and indexPath.row must not be negative");
        return;
    }
    
    if (_isInitializationPending || _isLayoutUpdateBlocked) {
        return;
    }
    
    if (![_selectedIndexPaths containsObject:indexPath]) {
        return;
    }
    
    _isLayoutUpdateBlocked = YES;
    [self _deselectRowAtIndexPath:indexPath animated:animated shouldRemove:YES shouldSetAnimated:YES];
    _isLayoutUpdateBlocked = NO;
}

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    
    MPTableViewCell *reusableCell;
    NSMutableArray *queue = [_reusableCellArrayDict objectForKey:identifier];
    if (queue.count > 0) {
        reusableCell = [queue lastObject];
        [queue removeLastObject];
        reusableCell.hidden = NO;
    } else {
        reusableCell = nil;
    }
    
    if (!reusableCell && _registeredCellClassDict) {
        Class cellClass = [_registeredCellClassDict objectForKey:identifier];
        if (cellClass) {
            reusableCell = [[cellClass alloc] initWithReuseIdentifier:identifier];
        } else {
            reusableCell = nil;
        }
    }
    
    if (!reusableCell && _registeredCellNibDict) {
        UINib *nib = [_registeredCellNibDict objectForKey:identifier];
        if (nib) {
            reusableCell = [nib instantiateWithOwner:self options:nil][0];
            NSParameterAssert([reusableCell isKindOfClass:[MPTableViewCell class]]);
            NSAssert(!reusableCell.reuseIdentifier || [reusableCell.reuseIdentifier isEqualToString:identifier], @"cell reuseIdentifier in nib does not match the identifier used to register the nib");
            
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
    
    MPTableViewReusableView *reusableView;
    NSMutableArray *queue = [_reusableViewArrayDict objectForKey:identifier];
    if (queue.count > 0) {
        reusableView = [queue lastObject];
        [queue removeLastObject];
        reusableView.hidden = NO;
    } else {
        reusableView = nil;
    }
    
    if (!reusableView && _registeredReusableViewClassDict) {
        Class reusableViewClass = [_registeredReusableViewClassDict objectForKey:identifier];
        if (reusableViewClass) {
            reusableView = [[reusableViewClass alloc] initWithReuseIdentifier:identifier];
        } else {
            reusableView = nil;
        }
    }
    
    if (!reusableView && _registeredReusableViewNibDict) {
        UINib *nib = [_registeredReusableViewNibDict objectForKey:identifier];
        if (nib) {
            reusableView = [nib instantiateWithOwner:self options:nil][0];
            NSParameterAssert([reusableView isKindOfClass:[MPTableViewReusableView class]]);
            NSAssert(!reusableView.reuseIdentifier || [reusableView.reuseIdentifier isEqualToString:identifier], @"reusableView reuseIdentifier in nib does not match the identifier used to register the nib");
            
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
    
    if (!_registeredCellClassDict) {
        _registeredCellClassDict = [[NSMutableDictionary alloc] init];
    }
    [_registeredCellClassDict setObject:cellClass forKey:identifier];
}

- (void)registerClass:(Class)reusableViewClass forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert([reusableViewClass isSubclassOfClass:[MPTableViewReusableView class]]);
    
    if (!_registeredReusableViewClassDict) {
        _registeredReusableViewClassDict = [[NSMutableDictionary alloc] init];
    }
    [_registeredReusableViewClassDict setObject:reusableViewClass forKey:identifier];
}

- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count > 0);
    
    if (!_registeredCellNibDict) {
        _registeredCellNibDict = [[NSMutableDictionary alloc] init];
    }
    [_registeredCellNibDict setObject:nib forKey:identifier];
}

- (void)registerNib:(UINib *)nib forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count > 0);
    
    if (!_registeredReusableViewNibDict) {
        _registeredReusableViewNibDict = [[NSMutableDictionary alloc] init];
    }
    [_registeredReusableViewNibDict setObject:nib forKey:identifier];
}

#pragma mark - update

- (BOOL)isUpdating {
    return _activeUpdateAnimationCount != 0;
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (sections.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (_updateContextDepth == 0) {
        [self _prepareForDeleteSections:sections withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        sections = [sections copy];
        void (^operationBlock)(void) = ^{
            [self _prepareForDeleteSections:sections withRowAnimation:animation];
        };
        [updateManager.transactions addObject:operationBlock];
    }
}

- (void)_prepareForDeleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= _numberOfSections) {
            MPTV_THROW_EXCEPTION(@"delete section index is out of bounds");
        }
        
        if (![updateManager addDeleteSection:idx withAnimation:animation]) {
            MPTV_THROW_EXCEPTION(@"duplicate update conflict");
        }
    }];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (sections.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (_updateContextDepth == 0) {
        [self _prepareForInsertSections:sections withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        sections = [sections copy];
        void (^operationBlock)(void) = ^{
            [self _prepareForInsertSections:sections withRowAnimation:animation];
        };
        [updateManager.transactions addObject:operationBlock];
    }
}

- (void)_prepareForInsertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    NSInteger numberOfSections;
    if (_respondsTo_numberOfSectionsInMPTableView) {
        _isLayoutUpdateBlocked = YES;
        numberOfSections = [_tableViewDataSource numberOfSectionsInMPTableView:self];
        if (numberOfSections < 0) {
            NSAssert(NO, @"the number of sections must not be negative");
            numberOfSections = 0;
        }
        _isLayoutUpdateBlocked = NO;
    } else {
        numberOfSections = _numberOfSections;
    }
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= numberOfSections) {
            MPTV_THROW_EXCEPTION(@"insert section index is out of bounds");
        }
        
        if (![updateManager addInsertSection:idx withAnimation:animation]) {
            MPTV_THROW_EXCEPTION(@"duplicate update conflict");
        }
    }];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (sections.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (_updateContextDepth == 0) {
        [self _prepareForReloadSections:sections withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        sections = [sections copy];
        void (^operationBlock)(void) = ^{
            [self _prepareForReloadSections:sections withRowAnimation:animation];
        };
        [updateManager.transactions addObject:operationBlock];
    }
}

- (void)_prepareForReloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= _numberOfSections) {
            MPTV_THROW_EXCEPTION(@"reload section index is out of bounds");
        }
        
        if (![updateManager addReloadSection:idx withAnimation:animation]) {
            MPTV_THROW_EXCEPTION(@"duplicate update conflict");
        }
    }];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (_updateContextDepth == 0) {
        [self _prepareForMoveSection:section toSection:newSection];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        void (^operationBlock)(void) = ^{
            [self _prepareForMoveSection:section toSection:newSection];
        };
        [updateManager.transactions addObject:operationBlock];
    }
}

- (void)_prepareForMoveSection:(NSInteger)section toSection:(NSInteger)newSection {
    if (section < 0 || newSection < 0) {
        MPTV_THROW_EXCEPTION(@"section and newSection must not be negative");
    }
    
    if (section >= _numberOfSections) {
        MPTV_THROW_EXCEPTION(@"move section index is out of bounds");
    }
    
    NSInteger numberOfSections;
    if (_respondsTo_numberOfSectionsInMPTableView) {
        _isLayoutUpdateBlocked = YES;
        numberOfSections = [_tableViewDataSource numberOfSectionsInMPTableView:self];
        if (numberOfSections < 0) {
            NSAssert(NO, @"the number of sections must not be negative");
            numberOfSections = 0;
        }
        _isLayoutUpdateBlocked = NO;
    } else {
        numberOfSections = _numberOfSections;
    }
    
    if (newSection >= numberOfSections) {
        MPTV_THROW_EXCEPTION(@"new move section index is out of bounds");
    }
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (![updateManager addMoveOutSection:section]) {
        MPTV_THROW_EXCEPTION(@"duplicate update conflict");
    }
    
    if (![updateManager addMoveInSection:newSection previousSection:section]) {
        MPTV_THROW_EXCEPTION(@"duplicate update conflict");
    }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (indexPaths.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (_updateContextDepth == 0) {
        [self _prepareForDeleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        indexPaths = [indexPaths copy];
        void (^operationBlock)(void) = ^{
            [self _prepareForDeleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        };
        [updateManager.transactions addObject:operationBlock];
    }
}

- (void)_prepareForDeleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section < 0 || indexPath.row < 0) {
            MPTV_THROW_EXCEPTION(@"indexPath.section and indexPath.row must not be negative");
        }
        
        if (indexPath.section >= _numberOfSections) {
            MPTV_THROW_EXCEPTION(@"delete section index is out of bounds");
        }
        
        MPTableViewSection *section = _sectionArray[indexPath.section];
        if (indexPath.row >= section.numberOfRows) {
            MPTV_THROW_EXCEPTION(@"delete row index is out of bounds");
        }
        
        if (![updateManager addDeleteIndexPath:indexPath withAnimation:animation]) {
            MPTV_THROW_EXCEPTION(@"duplicate update conflict");
        }
    }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (indexPaths.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (_updateContextDepth == 0) {
        [self _prepareForInsertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        indexPaths = [indexPaths copy];
        void (^operationBlock)(void) = ^{
            [self _prepareForInsertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        };
        [updateManager.transactions addObject:operationBlock];
    }
}

- (void)_prepareForInsertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section < 0 || indexPath.row < 0) {
            MPTV_THROW_EXCEPTION(@"indexPath.section and indexPath.row must not be negative");
        }
        
        if (indexPath.section >= _numberOfSections) {
            MPTV_THROW_EXCEPTION(@"insert section index is out of bounds");
        }
        
        if (![updateManager addInsertIndexPath:indexPath withAnimation:animation]) {
            MPTV_THROW_EXCEPTION(@"duplicate update conflict");
        }
    }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (indexPaths.count == 0) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (_updateContextDepth == 0) {
        [self _prepareForReloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        indexPaths = [indexPaths copy];
        void (^operationBlock)(void) = ^{
            [self _prepareForReloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        };
        [updateManager.transactions addObject:operationBlock];
    }
}

- (void)_prepareForReloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPGetRandomAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section < 0 || indexPath.row < 0) {
            MPTV_THROW_EXCEPTION(@"indexPath.section and indexPath.row must not be negative");
        }
        
        if (indexPath.section >= _numberOfSections) {
            MPTV_THROW_EXCEPTION(@"reload section index is out of bounds");
        }
        
        MPTableViewSection *section = _sectionArray[indexPath.section];
        if (indexPath.row >= section.numberOfRows) {
            MPTV_THROW_EXCEPTION(@"reload row index is out of bounds");
        }
        
        if (![updateManager addReloadIndexPath:indexPath withAnimation:animation]) {
            MPTV_THROW_EXCEPTION(@"duplicate update conflict");
        }
    }
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    if (!indexPath || !newIndexPath) {
        return;
    }
    
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (_updateContextDepth == 0) {
        [self _prepareForMoveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
        [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    } else {
        void (^operationBlock)(void) = ^{
            [self _prepareForMoveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
        };
        [updateManager.transactions addObject:operationBlock];
    }
}

- (void)_prepareForMoveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    if (indexPath.section < 0 || indexPath.row < 0) {
        MPTV_THROW_EXCEPTION(@"indexPath.section and indexPath.row must not be negative");
    }
    
    if (newIndexPath.section < 0 || newIndexPath.row < 0) {
        MPTV_THROW_EXCEPTION(@"newIndexPath.section and newIndexPath.row must not be negative");
    }
    
    if (indexPath.section >= _numberOfSections) {
        MPTV_THROW_EXCEPTION(@"move section index is out of bounds");
    }
    
    MPTableViewSection *section = _sectionArray[indexPath.section];
    if (indexPath.row >= section.numberOfRows) {
        MPTV_THROW_EXCEPTION(@"move row index is out of bounds");
    }
    
    if (newIndexPath.section >= _numberOfSections) {
        MPTV_THROW_EXCEPTION(@"new move indexPath is out of bounds");
    }
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    if (![updateManager addMoveOutIndexPath:indexPath]) {
        MPTV_THROW_EXCEPTION(@"duplicate update conflict");
    }
    
    if (![updateManager addMoveInIndexPath:newIndexPath previousIndexPath:indexPath previousFrame:[self _cellFrameAtIndexPath:indexPath]]) {
        MPTV_THROW_EXCEPTION(@"duplicate update conflict");
    }
}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
    [self performBatchUpdates:updates duration:MPTableViewDefaultAnimationDuration delay:0 completion:completion];
}

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(void (^)(BOOL))completion {
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    
    if (_isLayoutUpdateBlocked || _draggingIndexPath) {
        return;
    }
    
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    _updateContextDepth++;
    MPTableViewUpdateManager *updateManager;
    if (_updateContextDepth > 1) {
        updateManager = [self _pushUpdateManagerToStack];
    } else {
        updateManager = [self _currentUpdateManager];
    }
    
    if (updates) {
        updates();
    }
    
    for (void (^operation)(void) in updateManager.transactions) {
        operation();
    }
    
    [self _updateUsingManager:updateManager duration:duration delay:delay completion:completion];
    [self _popUpdateManagerFromStack];
    _updateContextDepth--;
}

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options completion:(void (^)(BOOL))completion {
    if (!_tableViewDataSource) {
        NSAssert(NO, @"dataSource is required");
        return;
    }
    NSParameterAssert(![self _hasDraggingCell]);
    NSAssert(!_isReloadingData, @"starting update is not allowed during data reload");
    NSParameterAssert(!_isLayoutUpdateBlocked);
    NSAssert(dampingRatio > MPTableViewSentinelFloatValue, @"invalid dampingRatio");
    NSAssert(velocity > MPTableViewSentinelFloatValue, @"invalid velocity");
    
    if (_isLayoutUpdateBlocked || _draggingIndexPath) {
        return;
    }
    
    if (_reloadDataRequiredFlag) {
        [self reloadData];
    }
    
    _updateContextDepth++;
    MPTableViewUpdateManager *updateManager;
    if (_updateContextDepth > 1) {
        updateManager = [self _pushUpdateManagerToStack];
    } else {
        updateManager = [self _currentUpdateManager];
    }
    
    if (updates) {
        updates();
    }
    
    for (void (^operation)(void) in updateManager.transactions) {
        operation();
    }
    
    [self _updateUsingManager:updateManager duration:duration delay:delay options:options usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity completion:completion];
    [self _popUpdateManagerFromStack];
    _updateContextDepth--;
}

- (MPTableViewUpdateManager *)_pushUpdateManagerToStack {
    if (!_updateManagerStack) {
        _updateManagerStack = [[NSMutableArray alloc] init];
        _updatePendingRemovalCellDict = [[NSMutableDictionary alloc] init];
        _updatePendingRemovalSectionViewDict = [[NSMutableDictionary alloc] init];
        _updatePendingCellDict = [[NSMutableDictionary alloc] init];
        _updatePendingSectionViewDict = [[NSMutableDictionary alloc] init];
        _updateAnimationBlocks = [[NSMutableArray alloc] init];
        
        _updateAnimatingIndexPaths = [[NSMutableSet alloc] init];
        _updatePendingAnimatingIndexPaths = [[NSMutableSet alloc] init];
        
        _updatePendingSelectedIndexPaths = [[NSMutableSet alloc] init];
        _updateExecutionActions = [[NSMutableArray alloc] init];
    }
    
    MPTableViewUpdateManager *updateManager = [MPTableViewUpdateManager managerForTableView:self sectionArray:_sectionArray];
    [_updateManagerStack addObject:updateManager];
    
    return updateManager;
}

- (MPTableViewUpdateManager *)_currentUpdateManager {
    MPTableViewUpdateManager *updateManager = [_updateManagerStack lastObject];
    if (!updateManager) {
        updateManager = [self _pushUpdateManagerToStack];
    }
    
    return updateManager;
}

- (void)_popUpdateManagerFromStack {
    if (_updateManagerStack.count > 1) { // keep at least one manager for reuse
        [_updateManagerStack removeLastObject];
    }
}

- (void)_updateUsingManager:(MPTableViewUpdateManager *)updateManager duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(void (^)(BOOL finished))completion {
    [self _updateUsingManager:updateManager duration:duration delay:delay options:0 usingSpringWithDamping:MPTableViewSentinelFloatValue initialSpringVelocity:MPTableViewSentinelFloatValue completion:completion];
}

- (void)_updateUsingManager:(MPTableViewUpdateManager *)updateManager duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity completion:(void (^)(BOOL finished))completion {
    if (_layoutSubviewsRequiredFlag || _reloadDataRequiredFlag) {
        [self _layoutSubviewsInternal];
    }
    
    if (!_tableViewDataSource) {
        return [updateManager reset];
    }
    
    _supplementSubviewsRequiredFlag = NO;
    _isLayoutUpdateBlocked = YES;
    _activeUpdateAnimationCount++;
    
    BOOL needsCheck = ![self _hasDraggingCell];
    if (needsCheck) {
        updateManager.previousCount = _numberOfSections;
        if (_respondsTo_numberOfSectionsInMPTableView) {
            NSInteger numberOfSections = [_tableViewDataSource numberOfSectionsInMPTableView:self];
            if (numberOfSections < 0) {
                NSAssert(NO, @"the number of sections must not be negative");
                numberOfSections = 0;
            }
            
            if ([updateManager hasUpdateNodes]) {
                _numberOfSections = numberOfSections;
            } else if (numberOfSections != _numberOfSections) {
                MPTV_THROW_EXCEPTION(@"number of sections from dataSource mismatch");
            }
        }
        updateManager.newCount = _numberOfSections;
    }
    if (![updateManager prepareForUpdateWithCheck:needsCheck]) {
        MPTV_THROW_EXCEPTION(@"number of sections from dataSource mismatch");
    }
    _proposedInsertedLocationY = _proposedDeletedPositionY = 0;
    _isAdjustingPositions = YES;
    CGFloat offset = [updateManager update];
    [updateManager reset];
    _isAdjustingPositions = NO;
    
    if (_numberOfSections > 0) {
        _listContentPosition.end += offset;
    } else {
        _listContentPosition.end = _listContentPosition.start;
    }
    
    if (_listContentPosition.start >= _listContentPosition.end) {
        _firstVisibleIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPTableViewSectionFooter);
        _lastVisibleIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPTableViewSectionHeader);
    } else {
        _firstVisibleIndexPath = [self _indexPathAtEffectiveStartPosition];
        _lastVisibleIndexPath = [self _indexPathAtEffectiveEndPosition];
    }
    
    if (offset != 0 && !_draggingIndexPath) {
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.start < -contentInset.top) {
            _willChangeContentOffsetDuringUpdate = YES;
            
            CGFloat boundsHeight = self.bounds.size.height;
            _contentOffsetPosition.start = -contentInset.top;
            _contentOffsetPosition.end = _contentOffsetPosition.start + boundsHeight;
            
            _listMappedContentOffsetPosition.start = _contentOffsetPosition.start - _listContentPosition.start;
            _listMappedContentOffsetPosition.end = _contentOffsetPosition.end - _listContentPosition.start;
        } else if (_contentOffsetPosition.start > -contentInset.top) {
            CGFloat contentEndPositionY = _listContentPosition.end + _tableFooterView.bounds.size.height;
            if (contentEndPositionY + contentInset.bottom < _contentOffsetPosition.end) {
                _willChangeContentOffsetDuringUpdate = YES;
                
                CGFloat boundsHeight = self.bounds.size.height;
                _contentOffsetPosition.end = contentEndPositionY + contentInset.bottom;
                _contentOffsetPosition.start = _contentOffsetPosition.end - boundsHeight;
                
                if (_contentOffsetPosition.start < -contentInset.top) {
                    _contentOffsetPosition.start = -contentInset.top;
                    _contentOffsetPosition.end = _contentOffsetPosition.start + boundsHeight;
                }
                
                _listMappedContentOffsetPosition.start = _contentOffsetPosition.start - _listContentPosition.start;
                _listMappedContentOffsetPosition.end = _contentOffsetPosition.end - _listContentPosition.start;
            }
        }
    }
    
    for (void (^action)(void) in _updateExecutionActions) {
        action();
    }
    [_updateExecutionActions removeAllObjects];
    
    [_displayedCellDict addEntriesFromDictionary:_updatePendingCellDict];
    [_updatePendingCellDict removeAllObjects];
    [_displayedSectionViewDict addEntriesFromDictionary:_updatePendingSectionViewDict];
    [_updatePendingSectionViewDict removeAllObjects];
    
    if (!_draggingIndexPath) {
        [_updateAnimatingIndexPaths setSet:_updatePendingAnimatingIndexPaths];
        [_updatePendingAnimatingIndexPaths removeAllObjects];
    }
    
    [_selectedIndexPaths unionSet:_updatePendingSelectedIndexPaths];
    [_updatePendingSelectedIndexPaths removeAllObjects];
    
    if (_fittedCellDict.count > 0) {
        for (MPTableViewCell *cell in _fittedCellDict.allValues) {
            [self _cacheCell:cell];
        }
        [_fittedCellDict removeAllObjects];
    }
    
    if (_fittedSectionViewDict.count > 0) {
        for (MPTableViewReusableView *view in _fittedSectionViewDict.allValues) {
            [self _cacheSectionView:view];
        }
        [_fittedSectionViewDict removeAllObjects];
    }
    
    if (_listContentPosition.start >= _listContentPosition.end) {
        [self _cancelPrefetchingIfNeeded];
    } else {
        if (_willChangeContentOffsetDuringUpdate) {
            NSIndexPathStruct startIndexPath = [self _indexPathAtEffectiveStartPosition];
            NSIndexPathStruct endIndexPath = [self _indexPathAtEffectiveEndPosition];
            
            if ([self _isEstimatedMode]) {
                CGFloat newOffset = [self _layoutSubviewsDuringEstimateFromFirstIndexPath:startIndexPath];
                if (newOffset != 0) {
                    MPTV_THROW_EXCEPTION(@"unexpected non-zero offset");
                }
                _firstVisibleIndexPath = startIndexPath;
                _lastVisibleIndexPath = endIndexPath;
            } else {
                [self _layoutSubviewsFromIndexPath:startIndexPath toIndexPath:endIndexPath];
            }
        }
        
        [self _prefetchIndexPathsIfNeeded];
    }
    
    NSArray *updateAnimationBlocks = _updateAnimationBlocks;
    _updateAnimationBlocks = [[NSMutableArray alloc] init];
    
    NSDictionary *removedCellDict = nil;
    if (_updatePendingRemovalCellDict.count > 0) {
        removedCellDict = _updatePendingRemovalCellDict;
        _updatePendingRemovalCellDict = [[NSMutableDictionary alloc] init];
    }
    NSDictionary *removedSectionViewDict = nil;
    if (_updatePendingRemovalSectionViewDict.count > 0) {
        removedSectionViewDict = _updatePendingRemovalSectionViewDict;
        _updatePendingRemovalSectionViewDict = [[NSMutableDictionary alloc] init];
    }
    
    void (^animations)(void) = ^{
        for (void (^animationBlock)(void) in updateAnimationBlocks) {
            animationBlock();
        }
        
        if (offset != 0) {
            MPOffsetView(_tableFooterView, offset);
            CGSize contentSize = CGSizeMake(self.bounds.size.width, _listContentPosition.end + _tableFooterView.bounds.size.height);
            self.contentSize = contentSize;
            
            if (_willChangeContentOffsetDuringUpdate) {
                CGPoint contentOffset = self.contentOffset;
                contentOffset.y = _contentOffsetPosition.start;
                self.contentOffset = contentOffset;
            }
        }
    };
    
    void (^animationsCompletion)(BOOL finished) = ^(BOOL finished) {
        [self _finalizeUpdateWithRemovedCells:removedCellDict removedSectionViews:removedSectionViewDict];
        if (completion) {
            completion(finished);
        }
    };
    
    if (_shouldOptimizeUpdateAnimationsForAutoLayout) {
        options |= UIViewAnimationOptionLayoutSubviews;
    }
    
    if (_allowsUserInteractionDuringUpdate && !_draggingIndexPath) {
        options |= UIViewAnimationOptionAllowUserInteraction;
    }
    
    if (dampingRatio == MPTableViewSentinelFloatValue) {
        [UIView animateWithDuration:duration delay:delay options:options animations:animations completion:animationsCompletion];
    } else {
        [UIView animateWithDuration:duration delay:delay usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity options:options animations:animations completion:animationsCompletion];
    }
    // safe when duration is 0
    _willChangeContentOffsetDuringUpdate = NO;
    _isLayoutUpdateBlocked = NO;
}

- (void)_finalizeUpdateWithRemovedCells:(NSDictionary *)removedCellDict removedSectionViews:(NSDictionary *)removedSectionViewDict {
    _isLayoutUpdateBlocked = YES;
    _activeUpdateAnimationCount--;
    
    if (_respondsTo_didEndDisplayingCellForRowAtIndexPath) {
        [removedCellDict enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, MPTableViewCell *cell, BOOL *stop) {
            [cell removeFromSuperview];
            [_tableViewDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
        }];
    } else {
        [removedCellDict.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    if (_respondsTo_didEndDisplayingHeaderViewForSection || _respondsTo_didEndDisplayingFooterViewForSection) {
        [removedSectionViewDict enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, MPTableViewReusableView *sectionView, BOOL *stop) {
            [sectionView removeFromSuperview];
            MPTableViewSectionViewType type = indexPath.row;
            [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section viewType:type];
        }];
    } else {
        [removedSectionViewDict.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    if (_activeUpdateAnimationCount == 0 && !_layoutSubviewsRequiredFlag && !_reloadDataRequiredFlag) {
        if (!_draggingIndexPath) {
            [_updateAnimatingIndexPaths removeAllObjects];
        }
        
        NSIndexPathStruct firstVisibleIndexPathStruct;
        NSIndexPathStruct lastVisibleIndexPathStruct;
        [self _setContentOffsetPositions];
        if (_listContentPosition.start >= _listContentPosition.end) {
            _firstVisibleIndexPath = firstVisibleIndexPathStruct = _NSIndexPathMakeStruct(NSIntegerMax, MPTableViewSectionFooter);
            _lastVisibleIndexPath = lastVisibleIndexPathStruct = _NSIndexPathMakeStruct(NSIntegerMin, MPTableViewSectionHeader);
        } else {
            firstVisibleIndexPathStruct = [self _indexPathAtEffectiveStartPosition];
            lastVisibleIndexPathStruct = [self _indexPathAtEffectiveEndPosition];
        }
        
        if (!_NSIndexPathStructEqualToStruct(firstVisibleIndexPathStruct, _firstVisibleIndexPath) || !_NSIndexPathStructEqualToStruct(lastVisibleIndexPathStruct, _lastVisibleIndexPath)) { // content offset has changed, but layoutSubviews has not been called yet.
            if ([self _isEstimatedMode]) {
                [self _prepareLayoutDuringEstimateFromIndexPath:firstVisibleIndexPathStruct toIndexPath:lastVisibleIndexPathStruct];
            } else {
                _supplementSubviewsRequiredFlag = YES;
                [self _applyLayoutFromIndexPath:firstVisibleIndexPathStruct toIndexPath:lastVisibleIndexPathStruct];
                _supplementSubviewsRequiredFlag = NO;
            }
        } else {
            [self _cacheCellsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
            [self _cacheAndAdjustSectionViewsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
        }
    }
    
    _isLayoutUpdateBlocked = NO;
}

- (NSMutableArray *)_updateExecutionActions {
    return _updateExecutionActions;
}

- (CGFloat)_getProposedDeletedPositionY {
    return _proposedDeletedPositionY;
}

- (void)_setProposedDeletedPositionY:(CGFloat)proposedDeletedPositionY {
    _proposedDeletedPositionY = proposedDeletedPositionY; // position value after applying the offset
}

- (CGFloat)_getProposedInsertedLocationY {
    return _proposedInsertedLocationY;
}

- (void)_setProposedInsertedLocationY:(CGFloat)proposedInsertedLocationY {
    _proposedInsertedLocationY = proposedInsertedLocationY; // position value before applying the offset
}

- (BOOL)_needsDisplayInRangeFromStartPosition:(CGFloat)startPosition toEndPosition:(CGFloat)endPosition withOffset:(CGFloat)offset {
    if (_allowsOptimizingNumberOfSubviewsDuringUpdate && !_draggingIndexPath) {
        return MPTV_POS_EPS_START(startPosition) <= _contentOffsetPosition.end && MPTV_POS_EPS_END(endPosition) >= _contentOffsetPosition.start;
    }
    
    if (offset > 0) {
        CGFloat previousStartPosition = startPosition - offset;
        return MPTV_POS_EPS_START(previousStartPosition) <= _contentOffsetPosition.end && MPTV_POS_EPS_END(endPosition) >= _contentOffsetPosition.start;
    } else if (offset < 0) {
        CGFloat previousEndPosition = endPosition - offset;
        return MPTV_POS_EPS_START(startPosition) <= _contentOffsetPosition.end && MPTV_POS_EPS_END(previousEndPosition) >= _contentOffsetPosition.start;
    } else {
        return MPTV_POS_EPS_START(startPosition) <= _contentOffsetPosition.end && MPTV_POS_EPS_END(endPosition) >= _contentOffsetPosition.start;
    }
}

- (BOOL)_needsDisplayAtSection:(MPTableViewSection *)section withUpdateType:(MPTableViewUpdateType)type withOffset:(CGFloat)offset {
    if (MPTV_IS_STABLE_UPDATE_TYPE(type)) { // offset must be 0 for insertion
        if ([self _needsDisplayInRangeFromStartPosition:section.start + _listContentPosition.start toEndPosition:section.end + _listContentPosition.start withOffset:offset]) {
            return YES;
        } else {
            return NO;
        }
    } else if (MPTV_IS_UNSTABLE_UPDATE_TYPE(type)) { // reload is implemented as a deletion followed by an insertion
        if ([self _hasDisplayedViewAtSection:section]) {
            return YES;
        } else {
            return [self _hasRelevantCellsInPreviousSection:section.section];
        }
    } else { // relayout
        if (_draggingIndexPath) {
            if ([self _isEstimatedMode]) {
                return YES;
            }
        } else {
            if (_shouldReloadAllDataDuringUpdate) {
                return YES;
            }
        }
        
        if (section.updatePart) {
            return [self _needsDisplayAtSection:section forRelayoutWithOffset:offset];
        } else {
            if ([self _hasDisplayedViewAtSection:section] || [self _needsDisplayInRangeFromStartPosition:section.start + offset + _listContentPosition.start toEndPosition:section.end + offset + _listContentPosition.start withOffset:offset]) {
                return YES;
            } else {
                return NO;
            }
        }
    }
}

- (BOOL)_hasRelevantCellsInPreviousSection:(NSInteger)previousSection {
    for (NSIndexPath *indexPath in _selectedIndexPaths) {
        if (indexPath.section == previousSection) {
            return YES;
        }
    }
    
    for (NSIndexPath *indexPath in _updateAnimatingIndexPaths) {
        if (indexPath.section == previousSection) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)_needsDisplayAtSection:(MPTableViewSection *)section forRelayoutWithOffset:(CGFloat)offset {
    return section.section <= _lastVisibleIndexPath.section || MPTV_POS_EPS_START(section.start + offset) <= _listMappedContentOffsetPosition.end;
}

- (BOOL)_needsRelayoutRelevantCellInSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow {
    NSIndexPath *previousIndexPath = nil;
    if (previousSection != section || previousRow != row) {
        previousIndexPath = _NSIndexPathInSectionForRow(previousSection, previousRow);
        if ([_selectedIndexPaths containsObject:previousIndexPath]) {
            [_selectedIndexPaths removeObject:previousIndexPath];
            NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
            [_updatePendingSelectedIndexPaths addObject:indexPath];
        }
    }
    
    if (_updateAnimatingIndexPaths.count > 0) {
        previousIndexPath = previousIndexPath ? : _NSIndexPathInSectionForRow(previousSection, previousRow);
        return [_updateAnimatingIndexPaths containsObject:previousIndexPath];
    } else {
        return NO;
    }
}

- (BOOL)_hasAnimatingSectionViewInPreviousSection:(NSInteger)previousSection viewType:(MPTableViewSectionViewType)type {
    if (_updateAnimatingIndexPaths.count > 0) {
        NSIndexPath *previousIndexPath = _NSIndexPathInSectionForRow(previousSection, type);
        return [_updateAnimatingIndexPaths containsObject:previousIndexPath];
    } else {
        return NO;
    }
}

- (MPTableViewSection *)_buildSectionForIndex:(NSInteger)sectionIndex {
    MPTableViewSection *section = [MPTableViewSection section];
    section.section = sectionIndex;
    
    CGFloat offset = 0;
    if (_sectionArray.count > 0 && sectionIndex > 0) { // verified
        MPTableViewSection *frontSection = _sectionArray[sectionIndex - 1];
        offset = frontSection.end;
    }
    
    [self _buildSection:section withOffset:offset];
    
    return section;
}

- (void)_addAnimationBlockForSubview:(UIView *)subview setFrame:(CGRect)frame {
    if (CGRectEqualToRect(subview.frame, frame)) {
        return;
    }
    
    void (^animationBlock)(void) = ^{
        subview.frame = frame;
    };
    [_updateAnimationBlocks addObject:animationBlock];
}

#pragma mark - update cell

- (CGFloat)_cellHeightForInsertionInSection:(NSInteger)section row:(NSInteger)row {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    CGFloat height;
    
    if (_respondsTo_estimatedHeightForRowAtIndexPath) { // verified
        MPTableViewSection *sectionPosition = _sectionArray[section];
        CGFloat startPosition = [sectionPosition startPositionAtRow:row];
        
        CGRect frame;
        frame.origin = CGPointMake(0, startPosition);
        frame.size.width = self.bounds.size.width;
        height = frame.size.height = [_tableViewDataSource MPTableView:self estimatedHeightForRowAtIndexPath:indexPath];
        if (_shouldReloadAllDataDuringUpdate || MPTV_ONSCREEN(frame)) { // height needs to be loaded
            if (_respondsTo_heightForRowAtIndexPath) {
                height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
            } else {
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                height = frame.size.height = MPReusableViewHeightAfterLayoutWithFittingWidth(cell, frame.size.width);
                
                if (MPTV_OFFSCREEN(frame)) {
                    [self _cacheCell:cell];
                } else {
                    [_fittedCellDict setObject:cell forKey:indexPath];
                }
            }
        }
    } else if (_respondsTo_heightForRowAtIndexPath) {
        height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else {
        height = _rowHeight;
    }
    
    if (height < 0) {
        NSAssert(NO, @"cell height must not be negative");
        height = 0;
    }
    
    return height;
}

- (CGFloat)_cellHeightDeltaForMoveInToSection:(NSInteger)section row:(NSInteger)row fromPreviousIndexPath:(NSIndexPath *)previousIndexPath previousHeight:(CGFloat)previousHeight withShift:(CGFloat)shift {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    if (_respondsTo_estimatedHeightForRowAtIndexPath && !_shouldReloadAllDataDuringUpdate) {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (![self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:shift]) {
            return 0;
        }
    }
    
    CGFloat height;
    if (_respondsTo_heightForRowAtIndexPath) {
        height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respondsTo_estimatedHeightForRowAtIndexPath) {
        if ([_displayedCellDict objectForKey:previousIndexPath]) {
            height = previousHeight;
        } else {
            MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            CGRect frame = [self _cellFrameAtIndexPath:indexPath];
            height = MPReusableViewHeightAfterLayoutWithFittingWidth(cell, frame.size.width);
            
            CGFloat previousHeight = frame.size.height;
            frame.size.height = height;
            if ((previousHeight > 0 || frame.size.height > 0) && [self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:shift]) {
                [_fittedCellDict setObject:cell forKey:indexPath];
            } else {
                [self _cacheCell:cell];
            }
        }
    } else {
        height = _rowHeight;
    }
    
    if (height < 0) {
        NSAssert(NO, @"cell height must not be negative");
        height = 0;
    }
    
    return height - previousHeight;
}

- (CGFloat)_cellHeightDeltaForRelayoutInSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow withOffset:(CGFloat)offset shouldLoadHeight:(BOOL *)shouldLoadHeight {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    
    if (_draggingIndexPath) { // only in estimated mode
        NSIndexPath *previousIndexPath = _NSIndexPathInSectionForRow(previousSection, previousRow);
        if ([_displayedCellDict objectForKey:previousIndexPath]) {
            return 0;
        }
        
        if (MPTV_POS_EPS_START(frame.origin.y) > _contentOffsetPosition.end) { // verified
            *shouldLoadHeight = NO;
            
            return 0;
        }
    } else {
        if (!_shouldReloadAllDataDuringUpdate && ![self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:offset]) {
            if (MPTV_POS_EPS_START(frame.origin.y) > _contentOffsetPosition.end) {
                *shouldLoadHeight = NO;
            }
            
            return 0;
        }
    }
    
    CGFloat previousHeight = frame.size.height;
    if (_respondsTo_heightForRowAtIndexPath) {
        frame.size.height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respondsTo_estimatedHeightForRowAtIndexPath) {
        NSIndexPath *previousIndexPath = _NSIndexPathInSectionForRow(previousSection, previousRow);
        if ([_displayedCellDict objectForKey:previousIndexPath]) {
            frame.size.height = previousHeight;
        } else {
            MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            frame.size.height = MPReusableViewHeightAfterLayoutWithFittingWidth(cell, frame.size.width);
            
            if ((previousHeight > 0 || frame.size.height > 0) && [self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:offset]) {
                [_fittedCellDict setObject:cell forKey:indexPath];
            } else {
                [self _cacheCell:cell];
            }
        }
    } else {
        frame.size.height = _rowHeight;
    }
    
    if (frame.size.height < 0) {
        NSAssert(NO, @"cell height must not be negative");
        frame.size.height = 0;
    }
    
    return frame.size.height - previousHeight;
}

- (CGFloat)_cellHeightDeltaForCalculatedCellInSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection withShift:(CGFloat)shift shouldLoadHeight:(BOOL *)shouldLoadHeight { // for insertion, shift is 0.
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    if (previousSection != section) { // movement
        if (!_respondsTo_heightForRowAtIndexPath && [_displayedCellDict objectForKey:_NSIndexPathInSectionForRow(previousSection, row)]) {
            return 0;
        }
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (_respondsTo_estimatedHeightForRowAtIndexPath && !_shouldReloadAllDataDuringUpdate && ![self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:shift]) {
        if (MPTV_POS_EPS_START(frame.origin.y) > _contentOffsetPosition.end) {
            *shouldLoadHeight = NO;
        }
        
        return 0;
    }
    
    CGFloat previousHeight = frame.size.height;
    if (_respondsTo_heightForRowAtIndexPath) {
        frame.size.height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respondsTo_estimatedHeightForRowAtIndexPath) {
        MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        frame.size.height = MPReusableViewHeightAfterLayoutWithFittingWidth(cell, frame.size.width);
        
        if ((previousHeight > 0 || frame.size.height > 0) && [self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:shift]) {
            [_fittedCellDict setObject:cell forKey:indexPath];
        } else {
            [self _cacheCell:cell];
        }
    } else {
        frame.size.height = _rowHeight;
    }
    
    if (frame.size.height < 0) {
        NSAssert(NO, @"cell height must not be negative");
        frame.size.height = 0;
    }
    
    return frame.size.height - previousHeight;
}

- (void)_deleteCellInSection:(NSInteger)previousSection row:(NSInteger)row animation:(MPTableViewRowAnimation)animation sectionPosition:(MPTableViewSection *)sectionPosition {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(previousSection, row);
    
    if ([_selectedIndexPaths containsObject:indexPath]) {
        [_selectedIndexPaths removeObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellDict objectForKey:indexPath];
    if (!cell) {
        return;
    }
    
    CGFloat proposedDeletedPositionY = [self _getProposedDeletedPositionY] + _listContentPosition.start;
    if (animation == MPTableViewRowAnimationCustom) {
        NSAssert(_respondsTo_startToDeleteCellForRowAtIndexPath, @"delegate does not implement - (void)MPTableView:(MPTableView *)tableView startToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withProposedPosition:(CGPoint)proposedPosition");
        if (_respondsTo_startToDeleteCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self startToDeleteCell:cell forRowAtIndexPath:indexPath withProposedPosition:CGPointMake(0, proposedDeletedPositionY)];
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
                MPMakeViewDisappearWithAnimation(cell, proposedDeletedPositionY, animation, sectionPosition);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_updatePendingRemovalCellDict setObject:cell forKey:indexPath];
        }
    }
    
    [_displayedCellDict removeObjectForKey:indexPath];
    [_updateAnimatingIndexPaths removeObject:indexPath];
}

- (void)_insertCellInSection:(NSInteger)section row:(NSInteger)row animation:(MPTableViewRowAnimation)animation sectionPosition:(MPTableViewSection *)sectionPosition proposedInsertedLocationY:(CGFloat)proposedInsertedLocationY {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (MPTV_OFFSCREEN(frame)) {
        return;
    }
    
    MPTableViewCell *cell = nil;
    if (_respondsTo_estimatedHeightForRowAtIndexPath && !_respondsTo_heightForRowAtIndexPath) {
        cell = [_fittedCellDict objectForKey:indexPath];
    }
    
    if (!cell) {
        cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
    } else {
        [_fittedCellDict removeObjectForKey:indexPath];
    }
    
    [_updatePendingAnimatingIndexPaths addObject:indexPath];
    [_updatePendingCellDict setObject:cell forKey:indexPath];
    [self _addToSuperviewIfNeededForCell:cell];
    MPSetFrameForViewWithoutAnimation(cell, frame);
    
    if (_respondsTo_willDisplayCellForRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    
    proposedInsertedLocationY += _listContentPosition.start;
    if (animation == MPTableViewRowAnimationCustom) {
        NSAssert(_respondsTo_startToInsertCellForRowAtIndexPath, @"delegate does not implement - (void)MPTableView:(MPTableView *)tableView startToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withProposedLocation:(CGPoint)proposedLocation");
        if (_respondsTo_startToInsertCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self startToInsertCell:cell forRowAtIndexPath:indexPath withProposedLocation:CGPointMake(0, proposedInsertedLocationY)];
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
                MPMakeViewDisappearWithAnimation(cell, proposedInsertedLocationY, animation, sectionPosition);
            }];
            
            void (^animationBlock)(void) = ^{
                MPMakeViewAppearWithAnimation(cell, frame, alpha, animation);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
        }
    }
}

- (void)_moveCellToSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow previousHeight:(CGFloat)previousHeight withShift:(CGFloat)shift {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    NSIndexPath *previousIndexPath = _NSIndexPathInSectionForRow(previousSection, previousRow);
    
    if ([_selectedIndexPaths containsObject:previousIndexPath]) {
        [_selectedIndexPaths removeObject:previousIndexPath];
        [_updatePendingSelectedIndexPaths addObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellDict objectForKey:previousIndexPath];
    if (cell) {
        [_displayedCellDict removeObjectForKey:previousIndexPath];
        if (!_draggingIndexPath) {
            [_updateAnimatingIndexPaths removeObject:previousIndexPath];
        }
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    
    if (cell) {
        [_updatePendingCellDict setObject:cell forKey:indexPath];
        [_contentWrapperView bringSubviewToFront:cell];
        if (!_draggingIndexPath) {
            [self _addAnimationBlockForSubview:cell setFrame:frame];
            [_updatePendingAnimatingIndexPaths addObject:indexPath];
        }
    } else {
        if ((previousHeight <= 0 && frame.size.height <= 0) || ![self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:shift]) {
            return;
        }
        
        if (_respondsTo_estimatedHeightForRowAtIndexPath && !_respondsTo_heightForRowAtIndexPath) {
            cell = [_fittedCellDict objectForKey:indexPath];
        }
        
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        } else {
            [_fittedCellDict removeObjectForKey:indexPath];
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.size.height = previousHeight;
        frame.origin.y -= shift;
        MPSetFrameForViewWithoutAnimation(cell, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        [self _addAnimationBlockForSubview:cell setFrame:frame];
        
        [_updatePendingCellDict setObject:cell forKey:indexPath];
        [self _addToSuperviewIfNeededForCell:cell];
        [_contentWrapperView bringSubviewToFront:cell];
        if (!_draggingIndexPath) {
            [_updatePendingAnimatingIndexPaths addObject:indexPath];
        }
        
        if ([_updatePendingSelectedIndexPaths containsObject:indexPath]) {
            [cell setSelected:YES animated:NO];
        }
        
        if (_respondsTo_willDisplayCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
    }
}

- (void)_relayoutCellToSection:(NSInteger)section row:(NSInteger)row previousSection:(NSInteger)previousSection previousRow:(NSInteger)previousRow previousHeight:(CGFloat)previousHeight withOffset:(CGFloat)offset {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    NSIndexPath *previousIndexPath = _NSIndexPathInSectionForRow(previousSection, previousRow);
    MPTableViewCell *cell = [_displayedCellDict objectForKey:previousIndexPath];
    
    if (cell) {
        if (!_draggingIndexPath) {
            [_updateAnimatingIndexPaths removeObject:previousIndexPath];
        }
        if (section != previousSection || row != previousRow) {
            [_displayedCellDict removeObjectForKey:previousIndexPath];
            [_updatePendingCellDict setObject:cell forKey:indexPath];
        }
        
        [_contentWrapperView sendSubviewToBack:cell];
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        [self _addAnimationBlockForSubview:cell setFrame:frame];
        if (!_draggingIndexPath) {
            [_updatePendingAnimatingIndexPaths addObject:indexPath];
        }
    } else {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if ((previousHeight <= 0 && frame.size.height <= 0) || ![self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:offset]) {
            return;
        }
        
        if (_respondsTo_estimatedHeightForRowAtIndexPath && !_respondsTo_heightForRowAtIndexPath) {
            cell = [_fittedCellDict objectForKey:indexPath];
        }
        
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        } else {
            [_fittedCellDict removeObjectForKey:indexPath];
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.origin.y -= offset;
        frame.size.height = previousHeight;
        MPSetFrameForViewWithoutAnimation(cell, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        [self _addAnimationBlockForSubview:cell setFrame:frame];
        
        [_updatePendingCellDict setObject:cell forKey:indexPath];
        [self _addToSuperviewIfNeededForCell:cell];
        [_contentWrapperView sendSubviewToBack:cell];
        if (!_draggingIndexPath) {
            [_updatePendingAnimatingIndexPaths addObject:indexPath];
        }
        
        if (section == previousSection && row == previousRow) {
            if ([_selectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES animated:NO];
            }
        } else {
            if ([_updatePendingSelectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES animated:NO];
            }
        }
        
        if (_respondsTo_willDisplayCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
    }
}

#pragma mark - update sectionView

- (BOOL)_needsDisplaySectionViewAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type withOffset:(CGFloat)offset { // ignores the case where the height is 0
    CGFloat start, end;
    if (MPTV_IS_HEADER(type)) {
        start = section.start + _listContentPosition.start;
        end = section.start + section.headerHeight + _listContentPosition.start;
    } else {
        start = section.end - section.footerHeight + _listContentPosition.start;
        end = section.end + _listContentPosition.start;
    }
    
    if ([self _needsDisplayInRangeFromStartPosition:start toEndPosition:end withOffset:offset]) {
        return YES;
    }
    
    if (_style == MPTableViewStylePlain && ([self _needsStickViewAtSection:section viewType:type] || [self _needsPrepareStickViewAtSection:section viewType:type])) {
        return YES;
    }
    
    return NO;
}

- (CGFloat)_headerHeightAfterLayoutAtSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    CGFloat height;
    
    MPTableViewReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:section.section viewType:MPTableViewSectionHeader];
    if (sectionView) {
        height = MPReusableViewHeightAfterLayoutWithFittingWidth(sectionView, self.bounds.size.width);
        
        CGFloat previousHeight = section.headerHeight;
        section.headerHeight = height;
        section.end += height - previousHeight;
        
        if ((previousHeight > 0 || height > 0) && [self _needsDisplaySectionViewAtSection:section viewType:MPTableViewSectionHeader withOffset:offset]) {
            NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section.section, MPTableViewSectionHeader);
            [_fittedSectionViewDict setObject:sectionView forKey:indexPath];
        } else {
            [self _cacheSectionView:sectionView];
        }
        
        section.headerHeight = previousHeight;
        section.end -= height - previousHeight;
    } else {
        height = section.headerHeight;
    }
    
    return height;
}

- (CGFloat)_footerHeightAfterLayoutAtSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    CGFloat height;
    
    MPTableViewReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:section.section viewType:MPTableViewSectionFooter];
    if (sectionView) {
        height = MPReusableViewHeightAfterLayoutWithFittingWidth(sectionView, self.bounds.size.width);
        
        CGFloat previousHeight = section.footerHeight;
        section.footerHeight = height;
        section.end += height - previousHeight;
        
        if ((previousHeight > 0 || height > 0) && [self _needsDisplaySectionViewAtSection:section viewType:MPTableViewSectionFooter withOffset:offset]) {
            NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section.section, MPTableViewSectionFooter);
            [_fittedSectionViewDict setObject:sectionView forKey:indexPath];
        } else {
            [self _cacheSectionView:sectionView];
        }
        
        section.footerHeight = previousHeight;
        section.end -= height - previousHeight;
    } else {
        height = section.footerHeight;
    }
    
    return height;
}

- (CGFloat)_computedHeaderHeightAtSection:(MPTableViewSection *)section fromPreviousSection:(NSInteger)previousSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion {
    if (_draggingIndexPath) { // only in estimated mode
        if ([_displayedSectionViewDict objectForKey:_NSIndexPathInSectionForRow(previousSection, MPTableViewSectionHeader)]) {
            return MPTableViewSentinelFloatValue;
        }
    } else {
        if (!_shouldReloadAllDataDuringUpdate && _style != MPTableViewStylePlain && ![self _needsDisplaySectionViewAtSection:section viewType:MPTableViewSectionHeader withOffset:offset]) {
            return MPTableViewSentinelFloatValue;
        }
    }
    
    CGFloat height;
    if (_respondsTo_heightForHeaderInSection) {
        height = [_tableViewDataSource MPTableView:self heightForHeaderInSection:section.section];
    } else if (_respondsTo_estimatedHeightForHeaderInSection) {
        if (!isInsertion && [_displayedSectionViewDict objectForKey:_NSIndexPathInSectionForRow(previousSection, MPTableViewSectionHeader)]) {
            return MPTableViewSentinelFloatValue;
        }
        
        height = [self _headerHeightAfterLayoutAtSection:section withOffset:offset];
    } else {
        height = _sectionHeaderHeight;
    }
    
    if (height < 0) {
        NSAssert(NO, @"section header height must not be negative");
        height = 0;
    }
    
    return height;
}

- (CGFloat)_computedFooterHeightAtSection:(MPTableViewSection *)section fromPreviousSection:(NSInteger)previousSection withOffset:(CGFloat)offset isInsertion:(BOOL)isInsertion {
    if (_draggingIndexPath) { // only in estimated mode
        if ([_displayedSectionViewDict objectForKey:_NSIndexPathInSectionForRow(previousSection, MPTableViewSectionFooter)]) {
            return MPTableViewSentinelFloatValue;
        }
    } else {
        if (!_shouldReloadAllDataDuringUpdate && _style != MPTableViewStylePlain && ![self _needsDisplaySectionViewAtSection:section viewType:MPTableViewSectionFooter withOffset:offset]) {
            return MPTableViewSentinelFloatValue;
        }
    }
    
    CGFloat height;
    if (_respondsTo_heightForFooterInSection) {
        height = [_tableViewDataSource MPTableView:self heightForFooterInSection:section.section];
    } else if (_respondsTo_estimatedHeightForFooterInSection) {
        if (!isInsertion && [_displayedSectionViewDict objectForKey:_NSIndexPathInSectionForRow(previousSection, MPTableViewSectionFooter)]) {
            return MPTableViewSentinelFloatValue;
        }
        
        height = [self _footerHeightAfterLayoutAtSection:section withOffset:offset];
    } else {
        height = _sectionFooterHeight;
    }
    
    if (height < 0) {
        NSAssert(NO, @"section footer height must not be negative");
        height = 0;
    }
    
    return height;
}

- (void)_deleteSectionViewInSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type animation:(MPTableViewRowAnimation)animation deletedSection:(MPTableViewSection *)deletedSection {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    
    MPTableViewReusableView *sectionView = [_displayedSectionViewDict objectForKey:indexPath];
    if (!sectionView) {
        return;
    }
    
    CGFloat proposedDeletedPositionY = [self _getProposedDeletedPositionY] + _listContentPosition.start;
    if (animation == MPTableViewRowAnimationCustom) {
        if (MPTV_IS_HEADER(type)) {
            NSAssert(_respondsTo_startToDeleteHeaderViewForSection, @"delegate does not implement - (void)MPTableView:(MPTableView *)tableView startToDeleteHeaderView:(MPTableViewReusableView *)view forSection:(NSInteger)section withProposedPosition:(CGPoint)proposedPosition");
            if (_respondsTo_startToDeleteHeaderViewForSection) {
                [_tableViewDelegate MPTableView:self startToDeleteHeaderView:sectionView forSection:section withProposedPosition:CGPointMake(0, proposedDeletedPositionY)];
            } else {
                [sectionView removeFromSuperview];
            }
        } else {
            NSAssert(_respondsTo_startToDeleteFooterViewForSection, @"delegate does not implement - (void)MPTableView:(MPTableView *)tableView startToDeleteFooterView:(MPTableViewReusableView *)view forSection:(NSInteger)section withProposedPosition:(CGPoint)proposedPosition");
            if (_respondsTo_startToDeleteFooterViewForSection) {
                [_tableViewDelegate MPTableView:self startToDeleteFooterView:sectionView forSection:section withProposedPosition:CGPointMake(0, proposedDeletedPositionY)];
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
                MPMakeViewDisappearWithAnimation(sectionView, proposedDeletedPositionY, animation, deletedSection);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_updatePendingRemovalSectionViewDict setObject:sectionView forKey:indexPath];
        }
    }
    
    [_displayedSectionViewDict removeObjectForKey:indexPath];
    [_updateAnimatingIndexPaths removeObject:indexPath];
}

- (void)_insertSectionViewInSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type animation:(MPTableViewRowAnimation)animation insertedSection:(MPTableViewSection *)insertedSection proposedInsertedLocationY:(CGFloat)proposedInsertedLocationY {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    
    CGRect frame;
    if (_style == MPTableViewStylePlain) {
        if ([self _needsStickViewAtSection:insertedSection viewType:type]) {
            frame = [self _stickingFrameAtSection:insertedSection viewType:type];
        } else if ([self _needsPrepareStickViewAtSection:insertedSection viewType:type]) {
            frame = [self _prepareFrameForStickViewAtSection:insertedSection viewType:type];
        } else {
            frame = [self _sectionViewFrameAtSection:insertedSection viewType:type];
        }
    } else {
        frame = [self _sectionViewFrameAtSection:insertedSection viewType:type];
    }
    
    if (MPTV_OFFSCREEN(frame)) {
        return;
    }
    
    MPTableViewReusableView *sectionView = nil;
    if (MPTV_IS_HEADER(type) && _respondsTo_estimatedHeightForHeaderInSection && !_respondsTo_heightForHeaderInSection) {
        sectionView = [_fittedSectionViewDict objectForKey:indexPath];
    } else if (MPTV_IS_FOOTER(type) && _respondsTo_estimatedHeightForFooterInSection && !_respondsTo_heightForFooterInSection) {
        sectionView = [_fittedSectionViewDict objectForKey:indexPath];
    }
    
    if (!sectionView) {
        sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section viewType:type];
    } else {
        [_fittedSectionViewDict removeObjectForKey:indexPath];
    }
    
    if (!sectionView) {
        return;
    }
    
    [_updatePendingAnimatingIndexPaths addObject:indexPath];
    [_updatePendingSectionViewDict setObject:sectionView forKey:indexPath];
    [self _addToSuperviewIfNeededForSectionView:sectionView];
    MPSetFrameForViewWithoutAnimation(sectionView, frame);
    [self _willDisplaySectionView:sectionView forSection:indexPath.section viewType:type];
    
    proposedInsertedLocationY += _listContentPosition.start;
    if (animation == MPTableViewRowAnimationCustom) {
        if (MPTV_IS_HEADER(type)) {
            NSAssert(_respondsTo_startToInsertHeaderViewForSection, @"delegate does not implement - (void)MPTableView:(MPTableView *)tableView startToInsertHeaderView:(MPTableViewReusableView *)view forSection:(NSInteger)section withProposedLocation:(CGPoint)proposedLocation");
            if (_respondsTo_startToInsertHeaderViewForSection) {
                [_tableViewDelegate MPTableView:self startToInsertHeaderView:sectionView forSection:section withProposedLocation:CGPointMake(0, proposedInsertedLocationY)];
            }
        } else {
            NSAssert(_respondsTo_startToInsertFooterViewForSection, @"delegate does not implement - (void)MPTableView:(MPTableView *)tableView startToInsertFooterView:(MPTableViewReusableView *)view forSection:(NSInteger)section withProposedLocation:(CGPoint)proposedLocation");
            if (_respondsTo_startToInsertFooterViewForSection) {
                [_tableViewDelegate MPTableView:self startToInsertFooterView:sectionView forSection:section withProposedLocation:CGPointMake(0, proposedInsertedLocationY)];
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
                MPMakeViewDisappearWithAnimation(sectionView, proposedInsertedLocationY, animation, insertedSection);
            }];
            
            void (^animationBlock)(void) = ^{
                MPMakeViewAppearWithAnimation(sectionView, frame, alpha, animation);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
        }
    }
}

- (void)_moveSectionViewToSection:(NSInteger)section previousSection:(NSInteger)previousSection viewType:(MPTableViewSectionViewType)type previousHeight:(CGFloat)previousHeight withShift:(CGFloat)shift {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    NSIndexPath *previousIndexPath = _NSIndexPathInSectionForRow(previousSection, type);
    
    MPTableViewReusableView *sectionView = [_displayedSectionViewDict objectForKey:previousIndexPath];
    if (sectionView) {
        [_displayedSectionViewDict removeObjectForKey:previousIndexPath];
        if (!_draggingIndexPath) {
            [_updateAnimatingIndexPaths removeObject:previousIndexPath];
        }
    }
    
    MPTableViewSection *sectionPosition = _sectionArray[section];
    CGRect frame = [self _sectionViewFrameAtSection:sectionPosition viewType:type]; // verified
    CGFloat previousOriginY = frame.origin.y;
    if (_style == MPTableViewStylePlain) {
        if ([self _needsStickViewAtSection:sectionPosition viewType:type]) {
            frame = [self _stickingFrameAtSection:sectionPosition viewType:type];
        } else if ([self _needsPrepareStickViewAtSection:sectionPosition viewType:type]) {
            frame = [self _prepareFrameForStickViewAtSection:sectionPosition viewType:type];
        }
    }
    
    if (sectionView) {
        [_updatePendingSectionViewDict setObject:sectionView forKey:indexPath];
        [self bringSubviewToFront:sectionView];
        [self _addAnimationBlockForSubview:sectionView setFrame:frame];
        [_updatePendingAnimatingIndexPaths addObject:indexPath];
    } else {
        if ((previousHeight <= 0 && frame.size.height <= 0) || ![self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:shift]) {
            return;
        }
        
        if (MPTV_IS_HEADER(type) && _respondsTo_estimatedHeightForHeaderInSection && !_respondsTo_heightForHeaderInSection) {
            sectionView = [_fittedSectionViewDict objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respondsTo_estimatedHeightForFooterInSection && !_respondsTo_heightForFooterInSection) {
            sectionView = [_fittedSectionViewDict objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section viewType:type];
        } else {
            [_fittedSectionViewDict removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.origin.y = previousOriginY - shift;
        frame.size.height = previousHeight;
        MPSetFrameForViewWithoutAnimation(sectionView, frame);
        frame.size.height = height;
        frame.origin.y = originY;
        [self _addAnimationBlockForSubview:sectionView setFrame:frame];
        
        [_updatePendingSectionViewDict setObject:sectionView forKey:indexPath];
        [self _addToSuperviewIfNeededForSectionView:sectionView];
        [self bringSubviewToFront:sectionView];
        [_updatePendingAnimatingIndexPaths addObject:indexPath];
        [self _willDisplaySectionView:sectionView forSection:indexPath.section viewType:type];
    }
}

- (void)_relayoutSectionViewToSection:(NSInteger)section previousSection:(NSInteger)previousSection viewType:(MPTableViewSectionViewType)type previousHeight:(CGFloat)previousHeight withOffset:(CGFloat)offset {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    NSIndexPath *previousIndexPath = _NSIndexPathInSectionForRow(previousSection, type);
    MPTableViewReusableView *sectionView = [_displayedSectionViewDict objectForKey:previousIndexPath];
    
    MPTableViewSection *sectionPosition = _sectionArray[section];
    CGRect frame;
    if (_style == MPTableViewStylePlain) {
        if ([self _needsStickViewAtSection:sectionPosition viewType:type]) {
            frame = [self _stickingFrameAtSection:sectionPosition viewType:type];
        } else if ([self _needsPrepareStickViewAtSection:sectionPosition viewType:type]) {
            frame = [self _prepareFrameForStickViewAtSection:sectionPosition viewType:type];
        } else {
            frame = [self _sectionViewFrameAtSection:sectionPosition viewType:type];
        }
    } else {
        frame = [self _sectionViewFrameAtSection:sectionPosition viewType:type];
    }
    
    if (sectionView) {
        if (!_draggingIndexPath) {
            [_updateAnimatingIndexPaths removeObject:previousIndexPath];
        }
        if (previousSection != section) {
            [_displayedSectionViewDict removeObjectForKey:previousIndexPath];
            [_updatePendingSectionViewDict setObject:sectionView forKey:indexPath];
        }
        
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
        [self _addAnimationBlockForSubview:sectionView setFrame:frame];
        if (!_draggingIndexPath) {
            [_updatePendingAnimatingIndexPaths addObject:indexPath];
        }
    } else {
        if ((previousHeight <= 0 && frame.size.height <= 0) || ![self _needsDisplayInRangeFromStartPosition:frame.origin.y toEndPosition:CGRectGetMaxY(frame) withOffset:offset]) {
            return;
        }
        
        if (MPTV_IS_HEADER(type) && _respondsTo_estimatedHeightForHeaderInSection && !_respondsTo_heightForHeaderInSection) {
            sectionView = [_fittedSectionViewDict objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respondsTo_estimatedHeightForFooterInSection && !_respondsTo_heightForFooterInSection) {
            sectionView = [_fittedSectionViewDict objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section viewType:type];
        } else {
            [_fittedSectionViewDict removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.origin.y -= offset;
        frame.size.height = previousHeight;
        MPSetFrameForViewWithoutAnimation(sectionView, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        [self _addAnimationBlockForSubview:sectionView setFrame:frame];
        
        [_updatePendingSectionViewDict setObject:sectionView forKey:indexPath];
        [self _addToSuperviewIfNeededForSectionView:sectionView];
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
        if (!_draggingIndexPath) {
            [_updatePendingAnimatingIndexPaths addObject:indexPath];
        }
        [self _willDisplaySectionView:sectionView forSection:indexPath.section viewType:type];
    }
}

#pragma mark - estimated mode layout

- (BOOL)_isEstimatedMode {
    return _respondsTo_estimatedHeightForRowAtIndexPath || _respondsTo_estimatedHeightForHeaderInSection || _respondsTo_estimatedHeightForFooterInSection;
}

- (BOOL)_needsEstimateHeightForRow {
    return _respondsTo_estimatedHeightForRowAtIndexPath;
}

- (BOOL)_needsEstimateHeightForHeader {
    return _respondsTo_estimatedHeightForHeaderInSection;
}

- (BOOL)_needsEstimateHeightForFooter {
    return _respondsTo_estimatedHeightForFooterInSection;
}

- (BOOL)_hasDisplayedViewAtSection:(MPTableViewSection *)section {
    return section.section >= _firstVisibleIndexPath.section && section.section <= _lastVisibleIndexPath.section;
}

- (BOOL)_needsDisplayDuringEstimateAtSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    if ([self isUpdating] && _updateAnimatingIndexPaths.count > 0) {
        for (NSIndexPath *indexPath in _updateAnimatingIndexPaths) {
            if (indexPath.section == section.section) {
                return YES;
            }
        }
    }
    
    if (_draggingIndexPath && _draggingIndexPath.section == section.section) {
        return YES;
    }
    
    return [self _hasDisplayedViewAtSection:section] || (MPTV_POS_EPS_START(section.start + offset) <= _listMappedContentOffsetPosition.end && MPTV_POS_EPS_END(section.end + offset) >= _listMappedContentOffsetPosition.start);
}

- (void)_applyEstimatedLayoutFromFirstIndexPath:(NSIndexPathStruct)firstIndexPath {
    CGFloat offset = [self _layoutSubviewsDuringEstimateFromFirstIndexPath:firstIndexPath];
    
    _listContentPosition.end += offset;
    if (_listContentPosition.start >= _listContentPosition.end) {
        _firstVisibleIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPTableViewSectionFooter);
        _lastVisibleIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPTableViewSectionHeader);
    } else {
        _firstVisibleIndexPath = [self _indexPathAtEffectiveStartPosition];
        _lastVisibleIndexPath = [self _indexPathAtEffectiveEndPosition];
    }
    
    if (_fittedCellDict.count > 0) {
        for (MPTableViewCell *cell in _fittedCellDict.allValues) {
            [self _cacheCell:cell];
        }
        [_fittedCellDict removeAllObjects];
    }
    if (_fittedSectionViewDict.count > 0) {
        for (MPTableViewReusableView *view in _fittedSectionViewDict.allValues) {
            [self _cacheSectionView:view];
        }
        [_fittedSectionViewDict removeAllObjects];
    }
    
    [self _cacheCellsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
    [self _cacheAndAdjustSectionViewsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
    
    if (offset != 0) {
        [UIView performWithoutAnimation:^{
            MPOffsetView(_tableFooterView, offset);
        }];
        
        CGSize contentSize = CGSizeMake(self.bounds.size.width, _listContentPosition.end + _tableFooterView.bounds.size.height);
        self.contentSize = contentSize;
        
        BOOL willChangeContentOffset = NO;
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.start < -contentInset.top) {
            willChangeContentOffset = YES;
        } else if (_contentOffsetPosition.start > -contentInset.top) {
            if (contentSize.height + contentInset.bottom < _contentOffsetPosition.end) {
                willChangeContentOffset = YES;
            }
        }
        
        if (willChangeContentOffset) {
            // Changing a UIScrollView's contentSize while it is bouncing may prevent -layoutSubviews from being called in the next run loop. This is possibly a UIKit bug.
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

- (CGFloat)_layoutSubviewsDuringEstimateFromFirstIndexPath:(NSIndexPathStruct)firstIndexPath {
    CGFloat offset = 0;
    _isAdjustingPositions = YES;
    
    BOOL isOptimizable = ![self isUpdating] && ![self _hasDraggingCell];
    for (NSInteger i = firstIndexPath.section; i < _numberOfSections; i++) {
        MPTableViewSection *section = _sectionArray[i];
        
        BOOL needsDisplay = [self _needsDisplayDuringEstimateAtSection:section withOffset:offset];
        if (!needsDisplay && offset == 0) {
            if (isOptimizable) {
                break;
            } else {
                continue;
            }
        }
        NSInteger firstRow = 0;
        if (i == firstIndexPath.section) {
            MPTableViewSectionViewType type = firstIndexPath.row;
            if (MPTV_IS_HEADER(type)) {
                firstRow = 0;
            } else if (MPTV_IS_FOOTER(type)) {
                firstRow = section.numberOfRows;
            } else {
                firstRow = firstIndexPath.row;
            }
        }
        
        offset = [section applyHeightsDuringEstimateForTableView:self fromFirstRow:firstRow withOffset:offset needsDisplay:needsDisplay];
    }
    
    _isAdjustingPositions = NO;
    return offset;
}

- (CGFloat)_computedHeaderHeightDuringEstimateAtSection:(MPTableViewSection *)section {
    if (_willChangeContentOffsetDuringUpdate) {
        return MPTableViewSentinelFloatValue;
    }
    
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section.section, MPTableViewSectionHeader);
    MPTableViewReusableView *sectionView = [_displayedSectionViewDict objectForKey:indexPath];
    if (sectionView) {
        return MPTableViewSentinelFloatValue;
    }
    
    if ([self _needsDisplaySectionViewAtSection:section viewType:MPTableViewSectionHeader withOffset:0]) {
        CGFloat height;
        if (_respondsTo_heightForHeaderInSection) {
            height = [_tableViewDataSource MPTableView:self heightForHeaderInSection:section.section];
        } else {
            height = [self _headerHeightAfterLayoutAtSection:section withOffset:0];
        }
        
        if (height < 0) {
            NSAssert(NO, @"section header height must not be negative");
            height = 0;
        }
        
        return height;
    } else {
        return MPTableViewSentinelFloatValue;
    }
}

- (CGFloat)_computedFooterHeightDuringEstimateAtSection:(MPTableViewSection *)section {
    if (_willChangeContentOffsetDuringUpdate) {
        return MPTableViewSentinelFloatValue;
    }
    
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section.section, MPTableViewSectionFooter);
    MPTableViewReusableView *sectionView = [_displayedSectionViewDict objectForKey:indexPath];
    if (sectionView) {
        return MPTableViewSentinelFloatValue;
    }
    
    if ([self _needsDisplaySectionViewAtSection:section viewType:MPTableViewSectionFooter withOffset:0]) {
        CGFloat height;
        if (_respondsTo_heightForFooterInSection) {
            height = [_tableViewDataSource MPTableView:self heightForFooterInSection:section.section];
        } else {
            height = [self _footerHeightAfterLayoutAtSection:section withOffset:0];
        }
        
        if (height < 0) {
            NSAssert(NO, @"section footer height must not be negative");
            height = 0;
        }
        
        return height;
    } else {
        return MPTableViewSentinelFloatValue;
    }
}

- (CGFloat)_displayCellDuringEstimateInSection:(NSInteger)section row:(NSInteger)row withOffset:(CGFloat)offset shouldLoadHeight:(BOOL *)shouldLoadHeight {
    CGFloat delta = 0;
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, row);
    MPTableViewCell *cell = [_displayedCellDict objectForKey:indexPath];
    
    if (cell) {
        MPTableViewCell *draggingCell = _dragAutoScrollDisplayLink ? _draggingCell : nil;
        if (offset != 0 && cell != draggingCell) {
            CGRect frame = cell.frame;
            frame.origin.y += offset;
            MPSetFrameForViewWithoutAnimation(cell, frame);
        }
    } else {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (MPTV_OFFSCREEN(frame)) {
            BOOL isVisibleRangeWithoutDragging = !_draggingIndexPath || indexPath.section != _draggingIndexPath.section || MPTV_ROW_MORE(indexPath.row, _draggingIndexPath.row);
            if (isVisibleRangeWithoutDragging && MPTV_POS_EPS_START(frame.origin.y) > _contentOffsetPosition.end && _updateAnimatingIndexPaths.count == 0) { // verified
                *shouldLoadHeight = NO;
            }
            
            return 0;
        } else {
            if (_respondsTo_estimatedHeightForRowAtIndexPath && !_willChangeContentOffsetDuringUpdate) {
                CGFloat previousHeight = frame.size.height;
                if (_respondsTo_heightForRowAtIndexPath) {
                    frame.size.height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
                } else {
                    cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                    frame.size.height = MPReusableViewHeightAfterLayoutWithFittingWidth(cell, frame.size.width);
                    if (MPTV_OFFSCREEN(frame)) {
                        [self _cacheCell:cell];
                    }
                }
                
                if (frame.size.height < 0) {
                    NSAssert(NO, @"cell height must not be negative");
                    frame.size.height = 0;
                }
                delta = frame.size.height - previousHeight;
                
                if (MPTV_OFFSCREEN(frame)) {
                    return delta;
                }
            }
            
            if (!cell) {
                cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            }
            
            [self _addToSuperviewIfNeededForCell:cell];
            if ([self isUpdating] || _draggingIndexPath) {
                [_contentWrapperView sendSubviewToBack:cell];
            }
            MPSetFrameForViewWithoutAnimation(cell, frame);
            [_displayedCellDict setObject:cell forKey:indexPath];
            
            if ([_selectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES animated:NO];
            }
            
            if (_respondsTo_willDisplayCellForRowAtIndexPath) {
                [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
            }
        }
    }
    
    return delta;
}

- (void)_displaySectionViewDuringEstimateInSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type {
    NSIndexPath *indexPath = _NSIndexPathInSectionForRow(section, type);
    MPTableViewReusableView *sectionView = [_displayedSectionViewDict objectForKey:indexPath];
    if (sectionView) {
        return;
    }
    
    BOOL needsToBecomeSticky = NO;
    BOOL needsStickyPreparation = NO;
    
    MPTableViewSection *sectionPosition = _sectionArray[section];
    if (_style == MPTableViewStylePlain) {
        if ([self _needsStickViewAtSection:sectionPosition viewType:type]) {
            needsToBecomeSticky = YES;
        } else if ([self _needsPrepareStickViewAtSection:sectionPosition viewType:type]) {
            needsStickyPreparation = YES;
        }
    }
    
    CGRect frame = [self _sectionViewFrameAtSection:sectionPosition viewType:type];
    if (MPTV_OFFSCREEN(frame) && !needsToBecomeSticky && !needsStickyPreparation) {
        return;
    } else {
        if (MPTV_IS_HEADER(type) && _respondsTo_estimatedHeightForHeaderInSection && !_respondsTo_heightForHeaderInSection) {
            sectionView = [_fittedSectionViewDict objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respondsTo_estimatedHeightForFooterInSection && !_respondsTo_heightForFooterInSection) {
            sectionView = [_fittedSectionViewDict objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section viewType:type];
        } else {
            [_fittedSectionViewDict removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        if (_willChangeContentOffsetDuringUpdate) {
            if (needsToBecomeSticky) {
                frame = [self _stickingFrameAtSection:sectionPosition viewType:type];
            } else if (needsStickyPreparation) {
                frame = [self _prepareFrameForStickViewAtSection:sectionPosition viewType:type];
            }
        }
        
        [self _displaySectionView:sectionView atIndexPath:indexPath withFrame:frame];
    }
}

#pragma mark - reload

- (void)reloadData {
    NSParameterAssert([NSThread isMainThread]);
    if (_isInitializationPending || _isLayoutUpdateBlocked) {
        return;
    }
    
    [self _clearDataWithCacheSubviewsEnabled:_allowsCachingSubviewsDuringReload];
    
    CGFloat height = 0;
    if (_tableViewDataSource) {
        _isReloadingData = YES;
        height = [self _buildSectionArray:_sectionArray];
        _numberOfSections = _sectionArray.count;
        _isReloadingData = NO;
        
        _isInitializationPending = NO;
        _layoutSubviewsRequiredFlag = YES;
        if (!_reloadDataRequiredFlag) {
            [self setNeedsLayout];
        }
    } else {
        _layoutSubviewsRequiredFlag = NO;
    }
    _reloadDataRequiredFlag = NO;
    
    [self _setContentSizeWithContentHeight:height];
}

- (void)reloadDataAsynchronouslyWithQueue:(dispatch_queue_t)queue completion:(void (^)(BOOL finished))completion {
    NSParameterAssert(!_isReloadingData);
    if (_isInitializationPending || _isLayoutUpdateBlocked) {
        return;
    }
    
    if (!_tableViewDataSource) {
        return [self reloadData];
    }
    
    _reloadDataRequiredFlag = NO;
    _isReloadingData = YES;
    dispatch_async(queue ? : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *sectionArray = [[NSMutableArray alloc] init];
        CGFloat height = [self _buildSectionArray:sectionArray];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_isReloadingData) {
                if (completion) {
                    completion(NO);
                }
                return;
            }
            
            _isReloadingData = NO;
            [self _clearDataWithCacheSubviewsEnabled:_allowsCachingSubviewsDuringReload];
            
            _sectionArray = sectionArray;
            _numberOfSections = sectionArray.count;
            if (_updateManagerStack.count > 0) {
                MPTableViewUpdateManager *updateManager = [_updateManagerStack lastObject]; // there can only be one update manager in this case
                updateManager.sectionArray = sectionArray;
            }
            
            _isInitializationPending = NO;
            [self _setContentSizeWithContentHeight:height];
            if (height != MPTableViewSentinelFloatValue) {
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
    section.start = offset;
    CGFloat height = 0;
    
    if (_respondsTo_estimatedHeightForHeaderInSection) {
        height = [_tableViewDataSource MPTableView:self estimatedHeightForHeaderInSection:section.section];
    } else if (_respondsTo_heightForHeaderInSection) {
        height = [_tableViewDataSource MPTableView:self heightForHeaderInSection:section.section];
    } else {
        height = _sectionHeaderHeight;
    }
    MPTV_CHECK_DATASOURCE;
    
    if (height < 0) {
        NSAssert(NO, @"section header height must not be negative");
        height = 0;
    }
    
    section.headerHeight = height;
    offset += height;
    
    if (_tableViewDataSource) {
        NSInteger numberOfRows = [_tableViewDataSource MPTableView:self numberOfRowsInSection:section.section];
        MPTV_CHECK_DATASOURCE;
        if (numberOfRows < 0) {
            NSAssert(NO, @"the number of rows must not be negative");
            numberOfRows = 0;
        }
        
        [section addRowPosition:section.start + section.headerHeight];
        for (NSInteger i = 0; i < numberOfRows; i++) {
            if (_respondsTo_estimatedHeightForRowAtIndexPath) {
                height = [_tableViewDataSource MPTableView:self estimatedHeightForRowAtIndexPath:_NSIndexPathInSectionForRow(section.section, i)];
            } else if (_respondsTo_heightForRowAtIndexPath) {
                height = [_tableViewDataSource MPTableView:self heightForRowAtIndexPath:_NSIndexPathInSectionForRow(section.section, i)];
            } else {
                height = _rowHeight;
            }
            MPTV_CHECK_DATASOURCE;
            
            if (height < 0) {
                NSAssert(NO, @"cell height must not be negative");
                height = 0;
            }
            
            [section addRowPosition:offset += height];
        }
        section.numberOfRows = numberOfRows;
    }
    // footer
    if (_respondsTo_estimatedHeightForFooterInSection) {
        height = [_tableViewDataSource MPTableView:self estimatedHeightForFooterInSection:section.section];
    } else if (_respondsTo_heightForFooterInSection) {
        height = [_tableViewDataSource MPTableView:self heightForFooterInSection:section.section];
    } else {
        height = _sectionFooterHeight;
    }
    MPTV_CHECK_DATASOURCE;
    
    if (height < 0) {
        NSAssert(NO, @"section footer height must not be negative");
        height = 0;
    }
    
    section.footerHeight = height;
    offset += height;
    
    section.end = offset;
    return offset;
}

- (CGFloat)_buildSectionArray:(NSMutableArray *)sectionArray {
    CGFloat offset = 0;
    
    const NSUInteger sectionCount = sectionArray.count;
    NSInteger numberOfSections;
    MPTV_CHECK_DATASOURCE;
    if (_respondsTo_numberOfSectionsInMPTableView) {
        numberOfSections = [_tableViewDataSource numberOfSectionsInMPTableView:self];
        MPTV_CHECK_DATASOURCE;
        if (numberOfSections < 0) {
            NSAssert(NO, @"the number of sections must not be negative");
            numberOfSections = 0;
        }
    } else {
        numberOfSections = 1;
    }
    
    if (sectionCount > numberOfSections) {
        [sectionArray removeObjectsInRange:NSMakeRange(numberOfSections, sectionCount - numberOfSections)];
    }
    for (NSInteger i = 0; i < numberOfSections; i++) {
        MPTableViewSection *section;
        if (i >= sectionCount) {
            section = [MPTableViewSection section];
        } else {
            section = sectionArray[i];
            [section reset];
        }
        section.section = i;
        
        offset = [self _buildSection:section withOffset:offset];
        if (offset == MPTableViewSentinelFloatValue) {
            [sectionArray removeAllObjects];
            break;
        }
        if (i >= sectionCount) {
            [sectionArray addObject:section];
        }
    }
    
    return offset;
}

- (void)_setContentSizeWithContentHeight:(CGFloat)contentHeight {
    if (contentHeight < 0) {
        contentHeight = 0;
    }
    
    if (_tableHeaderView) {
        _listContentPosition.start = _tableHeaderView.bounds.size.height;
    }
    
    CGFloat contentSizeHeight = _listContentPosition.end = _listContentPosition.start + contentHeight;
    if (_tableFooterView) {
        CGRect frame = _tableFooterView.frame;
        frame.origin.y = _listContentPosition.end;
        MPSetFrameForViewWithoutAnimation(_tableFooterView, frame);
        
        contentSizeHeight += frame.size.height;
    }
    
    self.contentSize = CGSizeMake(self.bounds.size.width, contentSizeHeight);
}

- (void)_clearDataWithCacheSubviewsEnabled:(BOOL)cacheSubviewEnabled {
    _isInitializationPending = YES;
    _numberOfSections = 0;
    
    [self _resetDragLongGestureRecognizer];
    
    _firstVisibleIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPTableViewSectionFooter);
    _lastVisibleIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPTableViewSectionHeader);
    _supplementSubviewsRequiredFlag = NO;
    _listContentPosition.end = _listContentPosition.start;
    [self _setContentOffsetPositions];
    [self _cancelPrefetchingIfNeeded];
    
    _isLayoutUpdateBlocked = YES;
    if (_selectedIndexPaths.count > 0) {
        for (NSIndexPath *indexPath in _selectedIndexPaths) {
            [self _deselectRowAtIndexPath:indexPath animated:NO shouldRemove:NO shouldSetAnimated:YES];
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
    
    [_updateAnimatingIndexPaths removeAllObjects];
    _isLayoutUpdateBlocked = NO;
}

- (void)_resetDragLongGestureRecognizer {
    [self _endDraggingCellIfNeededImmediately:YES];
    
    _dragLongGestureRecognizer.enabled = NO; // disable gesture recognizer
    _dragLongGestureRecognizer.enabled = _dragModeEnabled;
}

- (void)_cacheDisplayedCells {
    NSArray *indexPaths = [_displayedCellDict.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *indexPathA, NSIndexPath *indexPathB) {
        return [indexPathB compare:indexPathA]; // reverse
    }];
    
    for (NSIndexPath *indexPath in indexPaths) {
        MPTableViewCell *cell = [_displayedCellDict objectForKey:indexPath];
        [self _cacheCell:cell];
        if (_respondsTo_didEndDisplayingCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
        }
    }
    
    [_displayedCellDict removeAllObjects];
}

- (void)_cacheDisplayedSectionViews {
    NSArray *indexPaths = [_displayedSectionViewDict.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *indexPathA, NSIndexPath *indexPathB) {
        return [indexPathB compare:indexPathA];
    }];
    
    for (NSIndexPath *indexPath in indexPaths) {
        MPTableViewReusableView *sectionView = [_displayedSectionViewDict objectForKey:indexPath];
        [self _cacheSectionView:sectionView];
        
        MPTableViewSectionViewType type = indexPath.row;
        [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section viewType:type];
    }
    
    [_displayedSectionViewDict removeAllObjects];
}

- (void)_clearDisplayedCells {
    [_displayedCellDict enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, MPTableViewCell *cell, BOOL *stop) {
        [cell removeFromSuperview];
        if (_respondsTo_didEndDisplayingCellForRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
        }
    }];
    
    [_displayedCellDict removeAllObjects];
}

- (void)_clearDisplayedSectionViews {
    [_displayedSectionViewDict enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, MPTableViewReusableView *sectionView, BOOL *stop) {
        [sectionView removeFromSuperview];
        
        MPTableViewSectionViewType type = indexPath.row;
        [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section viewType:type];
    }];
    
    [_displayedSectionViewDict removeAllObjects];
}

- (void)_clearReusableCells {
    for (NSMutableArray *array in _reusableCellArrayDict.allValues) {
        [array makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [array removeAllObjects];
    }
}

- (void)_clearReusableSectionViews {
    for (NSMutableArray *array in _reusableViewArrayDict.allValues) {
        [array makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [array removeAllObjects];
    }
}

#pragma mark - layout

- (void)layoutSubviews {
    [super layoutSubviews];
    [self _layoutSubviewsInternal];
}

- (void)_layoutSubviewsInternal {
    NSParameterAssert([NSThread isMainThread]);
    if (_isLayoutUpdateBlocked || _isInitializationPending) {
        return;
    }
    
    _layoutSubviewsRequiredFlag = NO;
    if (!_tableViewDataSource) {
        [self _respondsToDataSource];
        _reloadDataRequiredFlag = NO;
        return [self _clearDataWithCacheSubviewsEnabled:_allowsCachingSubviewsDuringReload];
    }
    
    if (_reloadDataRequiredFlag) {
        [self reloadData];
        _layoutSubviewsRequiredFlag = NO;
    }
    
    [self _setContentOffsetPositions];
    if (_listContentPosition.start >= _listContentPosition.end) {
        return;
    }
    
    _isLayoutUpdateBlocked = YES;
    [self _layoutSubviewsIfNeeded];
    [self _prefetchIndexPathsIfNeeded];
    _isLayoutUpdateBlocked = NO;
}

- (void)_setContentOffsetPositions {
    _contentOffsetPosition.start = self.contentOffset.y;
    _contentOffsetPosition.end = self.contentOffset.y + self.bounds.size.height;
    
    _listMappedContentOffsetPosition.start = _contentOffsetPosition.start - _listContentPosition.start;
    _listMappedContentOffsetPosition.end = _contentOffsetPosition.end - _listContentPosition.start;
}

- (void)_layoutSubviewsIfNeeded {
    NSIndexPathStruct firstVisibleIndexPathStruct = [self _indexPathAtEffectiveStartPosition];
    NSIndexPathStruct lastVisibleIndexPathStruct = [self _indexPathAtEffectiveEndPosition];
    
    if ([self _isEstimatedMode]) { // estimated layout
        if (_supplementSubviewsRequiredFlag) {
            [self _applyEstimatedLayoutFromFirstIndexPath:firstVisibleIndexPathStruct];
            if (_NSIndexPathStructCompareStruct(_firstVisibleIndexPath, firstVisibleIndexPathStruct) != NSOrderedAscending) {
                _supplementSubviewsRequiredFlag = NO;
            }
            return;
        }
        
        if (!_NSIndexPathStructEqualToStruct(_firstVisibleIndexPath, firstVisibleIndexPathStruct) || !_NSIndexPathStructEqualToStruct(_lastVisibleIndexPath, lastVisibleIndexPathStruct)) {
            [self _prepareLayoutDuringEstimateFromIndexPath:firstVisibleIndexPathStruct toIndexPath:lastVisibleIndexPathStruct];
        } else if (_style == MPTableViewStylePlain) {
            [self _cacheAndAdjustSectionViewsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
        }
    } else { // normal layout
        if (_supplementSubviewsRequiredFlag || !_NSIndexPathStructEqualToStruct(_firstVisibleIndexPath, firstVisibleIndexPathStruct) || !_NSIndexPathStructEqualToStruct(_lastVisibleIndexPath, lastVisibleIndexPathStruct)) {
            [self _applyLayoutFromIndexPath:firstVisibleIndexPathStruct toIndexPath:lastVisibleIndexPathStruct];
            _supplementSubviewsRequiredFlag = NO;
        } else if (_style == MPTableViewStylePlain) {
            [self _cacheAndAdjustSectionViewsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
        }
    }
}

- (void)_prepareLayoutDuringEstimateFromIndexPath:(NSIndexPathStruct)startIndexPathStruct toIndexPath:(NSIndexPathStruct)lastVisibleIndexPathStruct {
    if (_NSIndexPathStructCompareStruct(startIndexPathStruct, _firstVisibleIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(startIndexPathStruct, _lastVisibleIndexPath) == NSOrderedDescending) {
        NSIndexPathStruct estimatedFirstIndexPath = startIndexPathStruct;
        
        [self _applyEstimatedLayoutFromFirstIndexPath:estimatedFirstIndexPath];
        if (_NSIndexPathStructCompareStruct(_firstVisibleIndexPath, startIndexPathStruct) == NSOrderedAscending) {
            _supplementSubviewsRequiredFlag = YES;
        }
    } else if (_NSIndexPathStructCompareStruct(lastVisibleIndexPathStruct, _lastVisibleIndexPath) == NSOrderedDescending) {
        NSIndexPathStruct estimatedFirstIndexPath;
        if (MPTV_IS_FOOTER(_lastVisibleIndexPath.row)) {
            estimatedFirstIndexPath = _NSIndexPathMakeStruct(_lastVisibleIndexPath.section + 1, MPTableViewSectionHeader);
        } else if (MPTV_IS_HEADER(_lastVisibleIndexPath.row)) {
            estimatedFirstIndexPath = _NSIndexPathMakeStruct(_lastVisibleIndexPath.section, 0);
        } else {
            estimatedFirstIndexPath = _NSIndexPathMakeStruct(_lastVisibleIndexPath.section, _lastVisibleIndexPath.row + 1);
        }
        
        [self _applyEstimatedLayoutFromFirstIndexPath:estimatedFirstIndexPath];
    } else {
        [self _cacheCellsOutsideStartIndexPath:startIndexPathStruct toEndIndexPath:lastVisibleIndexPathStruct];
        [self _cacheAndAdjustSectionViewsOutsideStartIndexPath:startIndexPathStruct toEndIndexPath:lastVisibleIndexPathStruct];
        
        _firstVisibleIndexPath = startIndexPathStruct;
        _lastVisibleIndexPath = lastVisibleIndexPathStruct;
    }
}

- (void)_applyLayoutFromIndexPath:(NSIndexPathStruct)firstVisibleIndexPathStruct toIndexPath:(NSIndexPathStruct)lastVisibleIndexPathStruct {
    [self _cacheCellsOutsideStartIndexPath:firstVisibleIndexPathStruct toEndIndexPath:lastVisibleIndexPathStruct];
    [self _cacheAndAdjustSectionViewsOutsideStartIndexPath:firstVisibleIndexPathStruct toEndIndexPath:lastVisibleIndexPathStruct];
    
    [self _layoutSubviewsFromIndexPath:firstVisibleIndexPathStruct toIndexPath:lastVisibleIndexPathStruct];
}

- (void)_layoutSubviewsFromIndexPath:(NSIndexPathStruct)firstVisibleIndexPathStruct toIndexPath:(NSIndexPathStruct)lastVisibleIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    BOOL hasStuckHeader = NO;
    BOOL hasStuckFooter = NO;
    BOOL isPlainStyle = (_style == MPTableViewStylePlain);
    
    for (NSInteger i = firstVisibleIndexPathStruct.section; i <= lastVisibleIndexPathStruct.section; i++) {
        MPTableViewSection *section = _sectionArray[i];
        
        BOOL needsDisplayHeader = section.headerHeight > 0;
        BOOL needsDisplayFooter = section.footerHeight > 0;
        NSInteger startCellRow, endCellRow;
        if (i == firstVisibleIndexPathStruct.section) {
            if (MPTV_IS_HEADER(firstVisibleIndexPathStruct.row)) {
                startCellRow = 0;
            } else if (MPTV_IS_FOOTER(firstVisibleIndexPathStruct.row)) {
                startCellRow = NSIntegerMax;
                needsDisplayHeader = NO;
            } else {
                startCellRow = firstVisibleIndexPathStruct.row;
                needsDisplayHeader = NO;
            }
        } else {
            startCellRow = 0;
        }
        
        if (i == lastVisibleIndexPathStruct.section) {
            if (MPTV_IS_FOOTER(lastVisibleIndexPathStruct.row)) {
                endCellRow = section.numberOfRows - 1;
            } else if (MPTV_IS_HEADER(lastVisibleIndexPathStruct.row)) {
                endCellRow = NSIntegerMin;
                needsDisplayFooter = NO;
            } else {
                endCellRow = lastVisibleIndexPathStruct.row;
                needsDisplayFooter = NO;
            }
        } else {
            endCellRow = section.numberOfRows - 1;
        }
        
        if (isPlainStyle) {
            if (!hasStuckHeader && [self _needsStickViewAtSection:section viewType:MPTableViewSectionHeader]) {
                hasStuckHeader = YES;
                [self _displaySectionViewForStickIfNeededAtSection:section viewType:MPTableViewSectionHeader];
            } else if ([self _needsPrepareStickViewAtSection:section viewType:MPTableViewSectionHeader]) {
                [self _displaySectionViewForPrepareStickIfNeededAtSection:section viewType:MPTableViewSectionHeader];
            } else if (needsDisplayHeader) {
                [self _displaySectionViewIfNeededAtSection:section viewType:MPTableViewSectionHeader];
            }
            
            if (!hasStuckFooter && [self _needsStickViewAtSection:section viewType:MPTableViewSectionFooter]) {
                hasStuckFooter = YES;
                [self _displaySectionViewForStickIfNeededAtSection:section viewType:MPTableViewSectionFooter];
            } else if ([self _needsPrepareStickViewAtSection:section viewType:MPTableViewSectionFooter]) {
                [self _displaySectionViewForPrepareStickIfNeededAtSection:section viewType:MPTableViewSectionFooter];
            } else if (needsDisplayFooter) {
                [self _displaySectionViewIfNeededAtSection:section viewType:MPTableViewSectionFooter];
            }
        } else {
            if (needsDisplayHeader) {
                [self _displaySectionViewIfNeededAtSection:section viewType:MPTableViewSectionHeader];
            }
            if (needsDisplayFooter) {
                [self _displaySectionViewIfNeededAtSection:section viewType:MPTableViewSectionFooter];
            }
        }
        
        for (NSInteger j = startCellRow; j <= endCellRow; j++) {
            NSIndexPathStruct indexPathStruct = {i, j};
            if (_supplementSubviewsRequiredFlag || _NSIndexPathStructCompareStruct(indexPathStruct, _firstVisibleIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(indexPathStruct, _lastVisibleIndexPath) == NSOrderedDescending) {
                NSIndexPath *indexPath = _NSIndexPathFromStruct(indexPathStruct);
                
                if ((_supplementSubviewsRequiredFlag || isUpdating || _draggingIndexPath) && [_displayedCellDict objectForKey:indexPath]) {
                    continue;
                }
                
                CGRect frame = [self _cellFrameAtIndexPath:indexPath];
                if (frame.size.height <= 0) {
                    continue;
                }
                
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                [self _addToSuperviewIfNeededForCell:cell];
                if (isUpdating || _draggingIndexPath) {
                    [_contentWrapperView sendSubviewToBack:cell];
                }
                MPSetFrameForViewWithoutAnimation(cell, frame);
                [_displayedCellDict setObject:cell forKey:indexPath];
                
                if ([_selectedIndexPaths containsObject:indexPath]) {
                    [cell setSelected:YES animated:NO];
                }
                
                if (_respondsTo_willDisplayCellForRowAtIndexPath) {
                    [_tableViewDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
                }
            }
        }
    }
    
    _firstVisibleIndexPath = firstVisibleIndexPathStruct;
    _lastVisibleIndexPath = lastVisibleIndexPathStruct;
}

- (NSInteger)_sectionForContentOffsetY:(CGFloat)contentOffsetY {
    NSUInteger count = _sectionArray.count;
    NSInteger low = 0;
    NSInteger high = count - 1; // count is guaranteed to be <= NSIntegerMax
    NSInteger mid = 0;
    while (low <= high) {
        mid = (low + high) / 2;
        MPTableViewSection *section = _sectionArray[mid];
        if (section.end < contentOffsetY) {
            low = mid + 1;
        } else if (section.start > contentOffsetY) {
            high = mid - 1;
        } else {
            return mid;
        }
    }
    
    return mid; // may have floating-point precision issues
}

- (NSIndexPathStruct)_indexPathForContentOffsetY:(CGFloat)contentOffsetY {
    NSInteger section = [self _sectionForContentOffsetY:contentOffsetY];
    MPTableViewSection *sectionPosition = _sectionArray[section];
    NSInteger row = [sectionPosition rowForContentOffsetY:contentOffsetY];
    
    return _NSIndexPathMakeStruct(section, row);
}

- (NSIndexPathStruct)_indexPathAtEffectiveStartPosition {
    CGFloat contentOffsetY = _listMappedContentOffsetPosition.start;
    if (contentOffsetY > _listContentPosition.end - _listContentPosition.start) {
        return _NSIndexPathMakeStruct(NSIntegerMax, MPTableViewSectionFooter);
    }
    
    if (contentOffsetY < 0) {
        if (_listMappedContentOffsetPosition.end < 0) {
            return _NSIndexPathMakeStruct(NSIntegerMax, MPTableViewSectionFooter);
        } else {
            contentOffsetY = 0;
        }
    }
    
    return [self _indexPathForContentOffsetY:contentOffsetY];
}

- (NSIndexPathStruct)_indexPathAtEffectiveEndPosition {
    CGFloat contentOffsetY = _listMappedContentOffsetPosition.end;
    if (contentOffsetY > _listContentPosition.end - _listContentPosition.start) {
        if (_listMappedContentOffsetPosition.start > _listContentPosition.end - _listContentPosition.start) {
            return _NSIndexPathMakeStruct(NSIntegerMin, MPTableViewSectionHeader);
        } else {
            contentOffsetY = _listContentPosition.end - _listContentPosition.start;
        }
    }
    
    if (contentOffsetY < 0) {
        return _NSIndexPathMakeStruct(NSIntegerMin, MPTableViewSectionHeader);
    }
    
    return [self _indexPathForContentOffsetY:contentOffsetY];
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
        MPTV_THROW_EXCEPTION(@"cell is nil");
    }
    
    return cell;
}

- (CGRect)_cellFrameAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return CGRectZero;
    }
    
    MPTableViewSection *section = _sectionArray[indexPath.section];
    if (indexPath.row >= section.numberOfRows) {
        return CGRectZero;
    }
    
    CGFloat startPosition = [section startPositionAtRow:indexPath.row];
    CGFloat endPosition = [section endPositionAtRow:indexPath.row];
    
    CGRect frame;
    frame.origin.x = 0;
    frame.origin.y = startPosition + _listContentPosition.start;
    frame.size.width = self.bounds.size.width;
    frame.size.height = endPosition - startPosition;
    if (frame.size.height < 0) { // may have floating-point precision issues
        frame.size.height = 0;
    }
    
    return frame;
}

- (MPTableViewReusableView *)_getSectionViewFromDataSourceInSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type {
    MPTableViewReusableView *sectionView = nil;
    
    if ([UIView areAnimationsEnabled]) {
        [UIView setAnimationsEnabled:NO];
        
        if (MPTV_IS_HEADER(type)) {
            if (_respondsTo_viewForHeaderInSection) {
                sectionView = [_tableViewDataSource MPTableView:self viewForHeaderInSection:section];
            }
        } else {
            if (_respondsTo_viewForFooterInSection) {
                sectionView = [_tableViewDataSource MPTableView:self viewForFooterInSection:section];
            }
        }
        
        [UIView setAnimationsEnabled:YES];
    } else {
        if (MPTV_IS_HEADER(type)) {
            if (_respondsTo_viewForHeaderInSection) {
                sectionView = [_tableViewDataSource MPTableView:self viewForHeaderInSection:section];
            }
        } else {
            if (_respondsTo_viewForFooterInSection) {
                sectionView = [_tableViewDataSource MPTableView:self viewForFooterInSection:section];
            }
        }
    }
    
    NSParameterAssert(![[sectionView class] isKindOfClass:[MPTableViewCell class]]);
    return sectionView;
}

- (CGRect)_sectionViewFrameAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type {
    CGRect frame;
    
    frame.origin.x = 0;
    frame.size.width = self.bounds.size.width;
    if (MPTV_IS_HEADER(type)) {
        frame.origin.y = section.start + _listContentPosition.start;
        frame.size.height = section.headerHeight;
    } else {
        frame.origin.y = section.end - section.footerHeight + _listContentPosition.start;
        frame.size.height = section.footerHeight;
    }
    
    return frame;
}

- (BOOL)_needsStickViewAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type {
    if (MPTV_IS_HEADER(type)) {
        if (section.headerHeight <= 0) {
            return NO;
        }
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if ((contentInset.top < 0 && -contentInset.top > section.headerHeight) || _contentOffsetPosition.start + contentInset.top >= _contentOffsetPosition.end) {
            return NO;
        }
        
        CGFloat contentStart = _listMappedContentOffsetPosition.start + contentInset.top;
        if (section.start <= contentStart && section.end - section.footerHeight - section.headerHeight >= contentStart) {
            return YES;
        } else {
            return NO;
        }
    } else {
        if (section.footerHeight <= 0) {
            return NO;
        }
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if ((contentInset.bottom < 0 && -contentInset.bottom > section.footerHeight) || _contentOffsetPosition.end - contentInset.bottom <= _contentOffsetPosition.start) {
            return NO;
        }
        
        CGFloat contentEnd = _listMappedContentOffsetPosition.end - contentInset.bottom;
        if (section.end >= contentEnd && section.start + section.headerHeight + section.footerHeight <= contentEnd) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (CGRect)_stickingFrameAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type {
    CGRect frame;
    frame.origin.x = 0;
    frame.size.width = self.bounds.size.width;
    
    if (MPTV_IS_HEADER(type)) {
        frame.size.height = section.headerHeight;
        
        frame.origin.y = _listMappedContentOffsetPosition.start + [self _innerContentInset].top;
        if (frame.origin.y > section.end - section.footerHeight - frame.size.height) {
            frame.origin.y = section.end - section.footerHeight - frame.size.height;
        }
        if (frame.origin.y < section.start) {
            frame.origin.y = section.start;
        }
    } else {
        frame.size.height = section.footerHeight;
        
        frame.origin.y = _listMappedContentOffsetPosition.end - frame.size.height - [self _innerContentInset].bottom;
        if (frame.origin.y > section.end - frame.size.height) {
            frame.origin.y = section.end - frame.size.height;
        }
        if (frame.origin.y < section.start + section.headerHeight) {
            frame.origin.y = section.start + section.headerHeight;
        }
    }
    
    frame.origin.y += _listContentPosition.start;
    
    return frame;
}

- (BOOL)_needsPrepareStickViewAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type {
    if (MPTV_IS_HEADER(type)) {
        if (section.headerHeight <= 0) {
            return NO;
        }
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.start + contentInset.top >= _contentOffsetPosition.end) {
            return NO;
        }
        
        CGFloat contentStart = _listMappedContentOffsetPosition.start + contentInset.top;
        if (section.end - section.footerHeight - section.headerHeight < contentStart && section.end - section.footerHeight >= _listMappedContentOffsetPosition.start) {
            return YES;
        } else {
            return NO;
        }
    } else {
        if (section.footerHeight <= 0) {
            return NO;
        }
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.end - contentInset.bottom <= _contentOffsetPosition.start) {
            return NO;
        }
        
        CGFloat contentEnd = _listMappedContentOffsetPosition.end - contentInset.bottom;
        if (section.start + section.headerHeight + section.footerHeight > contentEnd && section.start + section.headerHeight <= _listMappedContentOffsetPosition.end) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (CGRect)_prepareFrameForStickViewAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type {
    CGRect frame;
    
    frame.origin.x = 0;
    frame.size.width = self.bounds.size.width;
    if (MPTV_IS_HEADER(type)) {
        frame.origin.y = section.end - section.footerHeight - section.headerHeight + _listContentPosition.start;
        frame.size.height = section.headerHeight;
    } else {
        frame.origin.y = section.start + section.headerHeight + _listContentPosition.start;
        frame.size.height = section.footerHeight;
    }
    
    return frame;
}

- (MPTableViewReusableView *)_getSectionViewIfNeededAtIndexPath:(NSIndexPathStruct)indexPath {
    if (_style == MPTableViewStylePlain || [self isUpdating]) {
        if (![_displayedSectionViewDict objectForKey:_NSIndexPathFromStruct(indexPath)]) {
            MPTableViewReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section viewType:indexPath.row];
            return sectionView;
        }
    } else {
        if (_NSIndexPathStructCompareStruct(indexPath, _firstVisibleIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(indexPath, _lastVisibleIndexPath) == NSOrderedDescending) {
            MPTableViewReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section viewType:indexPath.row];
            return sectionView;
        }
    }
    
    return nil;
}

- (void)_displaySectionViewForStickIfNeededAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type {
    NSIndexPathStruct indexPath = _NSIndexPathMakeStruct(section.section, type);
    MPTableViewReusableView *sectionView = [self _getSectionViewIfNeededAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _stickingFrameAtSection:section viewType:type];
        [self _displaySectionView:sectionView atIndexPath:_NSIndexPathFromStruct(indexPath) withFrame:frame];
    }
}

- (void)_displaySectionViewForPrepareStickIfNeededAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type {
    NSIndexPathStruct indexPath = _NSIndexPathMakeStruct(section.section, type);
    MPTableViewReusableView *sectionView = [self _getSectionViewIfNeededAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _prepareFrameForStickViewAtSection:section viewType:type];
        [self _displaySectionView:sectionView atIndexPath:_NSIndexPathFromStruct(indexPath) withFrame:frame];
    }
}

// height has been checked
- (void)_displaySectionViewIfNeededAtSection:(MPTableViewSection *)section viewType:(MPTableViewSectionViewType)type {
    NSIndexPathStruct indexPath = _NSIndexPathMakeStruct(section.section, type);
    MPTableViewReusableView *sectionView = [self _getSectionViewIfNeededAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _sectionViewFrameAtSection:section viewType:type];
        [self _displaySectionView:sectionView atIndexPath:_NSIndexPathFromStruct(indexPath) withFrame:frame];
    }
}

- (void)_displaySectionView:(MPTableViewReusableView *)sectionView atIndexPath:(NSIndexPath *)indexPath withFrame:(CGRect)frame {
    [self _addToSuperviewIfNeededForSectionView:sectionView];
    if ([self isUpdating]) {
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
    }
    MPSetFrameForViewWithoutAnimation(sectionView, frame);
    [_displayedSectionViewDict setObject:sectionView forKey:indexPath];
    
    MPTableViewSectionViewType type = indexPath.row;
    [self _willDisplaySectionView:sectionView forSection:indexPath.section viewType:type];
}

- (void)_willDisplaySectionView:(MPTableViewReusableView *)sectionView forSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type {
    if (MPTV_IS_HEADER(type) && _respondsTo_willDisplayHeaderViewForSection) {
        [_tableViewDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:section];
    }
    if (MPTV_IS_FOOTER(type) && _respondsTo_willDisplayFooterViewForSection) {
        [_tableViewDelegate MPTableView:self willDisplayFooterView:sectionView forSection:section];
    }
}

- (void)_didEndDisplayingSectionView:(MPTableViewReusableView *)sectionView forSection:(NSInteger)section viewType:(MPTableViewSectionViewType)type {
    if (MPTV_IS_HEADER(type) && _respondsTo_didEndDisplayingHeaderViewForSection) {
        [_tableViewDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:section];
    }
    if (MPTV_IS_FOOTER(type) && _respondsTo_didEndDisplayingFooterViewForSection) {
        [_tableViewDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:section];
    }
}

- (void)_addToSuperviewIfNeededForCell:(MPTableViewCell *)cell {
    if ([cell superview] != _contentWrapperView) {
        [_contentWrapperView addSubview:cell];
    }
}

- (void)_addToSuperviewIfNeededForSectionView:(MPTableViewReusableView *)sectionView {
    if ([sectionView superview] != self) {
        [self addSubview:sectionView];
    }
}

- (void)_cacheCell:(MPTableViewCell *)cell {
    if (cell.reuseIdentifier) {
        [cell prepareForRecycle];
        
        NSMutableArray *queue = [_reusableCellArrayDict objectForKey:cell.reuseIdentifier];
        if (!queue) {
            queue = [[NSMutableArray alloc] init];
            [_reusableCellArrayDict setObject:queue forKey:cell.reuseIdentifier];
        }
        [queue addObject:cell];
        cell.hidden = YES;
    } else {
        [cell removeFromSuperview];
    }
    
    [cell setHighlighted:NO animated:NO];
    [cell setSelected:NO animated:NO];
}

- (void)_cacheCellsOutsideStartIndexPath:(NSIndexPathStruct)firstVisibleIndexPathStruct toEndIndexPath:(NSIndexPathStruct)lastVisibleIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    
    NSArray *indexPaths = _displayedCellDict.allKeys;
    for (NSIndexPath *indexPath in indexPaths) {
        if (_NSIndexPathCompareStruct(indexPath, firstVisibleIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, lastVisibleIndexPathStruct) == NSOrderedDescending) {
            if (_draggingIndexPath) {
                if ([indexPath compare:_draggingIndexPath] == NSOrderedSame) {
                    continue;
                }
            } else if (isUpdating && [_updateAnimatingIndexPaths containsObject:indexPath]) {
                continue;
            }
            
            MPTableViewCell *cell = [_displayedCellDict objectForKey:indexPath];
            
            [self _cacheCell:cell];
            [_displayedCellDict removeObjectForKey:indexPath];
            
            if (_respondsTo_didEndDisplayingCellForRowAtIndexPath) {
                [_tableViewDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
            }
        }
    }
}

- (void)_cacheSectionView:(MPTableViewReusableView *)sectionView {
    if (sectionView.reuseIdentifier) {
        [sectionView prepareForRecycle];
        
        NSMutableArray *queue = [_reusableViewArrayDict objectForKey:sectionView.reuseIdentifier];
        if (!queue) {
            queue = [[NSMutableArray alloc] init];
            [_reusableViewArrayDict setObject:queue forKey:sectionView.reuseIdentifier];
        }
        [queue addObject:sectionView];
        sectionView.hidden = YES;
    } else {
        [sectionView removeFromSuperview];
    }
}

- (void)_cacheAndAdjustSectionViewsOutsideStartIndexPath:(NSIndexPathStruct)firstVisibleIndexPathStruct toEndIndexPath:(NSIndexPathStruct)lastVisibleIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    BOOL isPlain = (_style == MPTableViewStylePlain);
    BOOL isEstimatedMode = [self _isEstimatedMode];
    
    NSArray *indexPaths = _displayedSectionViewDict.allKeys;
    for (NSIndexPath *indexPath in indexPaths) {
        MPTableViewReusableView *sectionView = [_displayedSectionViewDict objectForKey:indexPath];
        MPTableViewSectionViewType type = indexPath.row;
        
        if (isPlain) {
            MPTableViewSection *section = _sectionArray[indexPath.section];
            if ([self _needsStickViewAtSection:section viewType:type]) {
                CGRect frame = [self _stickingFrameAtSection:section viewType:type];
                MPSetFrameForViewWithoutAnimation(sectionView, frame);
            } else if ([self _needsPrepareStickViewAtSection:section viewType:type]) {
                CGRect frame = [self _prepareFrameForStickViewAtSection:section viewType:type];
                MPSetFrameForViewWithoutAnimation(sectionView, frame);
            } else {
                BOOL isOutsideRange = _NSIndexPathCompareStruct(indexPath, firstVisibleIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, lastVisibleIndexPathStruct) == NSOrderedDescending;
                if (isOutsideRange && (!isUpdating || _draggingIndexPath || ![_updateAnimatingIndexPaths containsObject:indexPath])) {
                    [self _cacheSectionView:sectionView];
                    [_displayedSectionViewDict removeObjectForKey:indexPath];
                    
                    [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section viewType:type];
                } else {
                    CGRect frame = [self _sectionViewFrameAtSection:section viewType:type];
                    MPSetFrameForViewWithoutAnimation(sectionView, frame);
                }
            }
        } else {
            BOOL isOutsideRange = _NSIndexPathCompareStruct(indexPath, firstVisibleIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, lastVisibleIndexPathStruct) == NSOrderedDescending;
            if (isOutsideRange && (!isUpdating || _draggingIndexPath || ![_updateAnimatingIndexPaths containsObject:indexPath])) {
                [self _cacheSectionView:sectionView];
                [_displayedSectionViewDict removeObjectForKey:indexPath];
                
                [self _didEndDisplayingSectionView:sectionView forSection:indexPath.section viewType:type];
            } else {
                if (isEstimatedMode) {
                    MPTableViewSection *section = _sectionArray[indexPath.section];
                    CGRect frame = [self _sectionViewFrameAtSection:section viewType:type];
                    MPSetFrameForViewWithoutAnimation(sectionView, frame);
                }
            }
        }
    }
}

#pragma mark - prefetch

static const NSInteger MPPrefetchBatchCount = 10;
static const NSInteger MPPrefetchDetectCount = 15;

- (NSIndexPathStruct)_prefetchStartIndexPath {
    NSIndexPathStruct indexPathStruct = _firstVisibleIndexPath;
    if (MPTV_IS_HEADER(indexPathStruct.row)) {
        indexPathStruct.row = NSIntegerMin;
    } else if (MPTV_IS_FOOTER(indexPathStruct.row)) {
        MPTableViewSection *section = _sectionArray[indexPathStruct.section];
        if (section.numberOfRows) {
            indexPathStruct.row = section.numberOfRows;
        } else {
            indexPathStruct.row = NSIntegerMin;
        }
    }
    
    return indexPathStruct;
}

- (NSIndexPathStruct)_prefetchEndIndexPath {
    NSIndexPathStruct indexPathStruct = _lastVisibleIndexPath;
    if (MPTV_IS_HEADER(indexPathStruct.row)) {
        MPTableViewSection *section = _sectionArray[indexPathStruct.section];
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
    if (!_prefetchDataSource || _numberOfSections == 0 || _firstVisibleIndexPath.section == NSIntegerMax || _lastVisibleIndexPath.section == NSIntegerMin) {
        return;
    }
    
    BOOL isScrollingUp = _contentOffsetPosition.start < _lastContentOffsetY;
    NSMutableArray *prefetchUpIndexPaths = [[NSMutableArray alloc] init];
    NSMutableArray *prefetchDownIndexPaths = [[NSMutableArray alloc] init];
    
    NSIndexPathStruct prefetchStartIndexPath = [self _prefetchStartIndexPath];
    for (NSInteger i = 0; i < MPPrefetchDetectCount; i++) {
        if (prefetchStartIndexPath.row > 0) {
            prefetchStartIndexPath.row--;
        } else {
            while (prefetchStartIndexPath.section > 0) {
                MPTableViewSection *section = _sectionArray[--prefetchStartIndexPath.section];
                if (section.numberOfRows > 0) {
                    prefetchStartIndexPath.row = section.numberOfRows - 1;
                    goto _prefetch_scrolling_up;
                }
            }
            break;
        }
        
    _prefetch_scrolling_up:
        if (isScrollingUp && i < MPPrefetchBatchCount) {
            NSIndexPath *indexPath = _NSIndexPathFromStruct(prefetchStartIndexPath);
            if (![_prefetchIndexPaths containsObject:indexPath]) {
                [prefetchUpIndexPaths addObject:indexPath];
            }
        }
    }
    
    NSIndexPathStruct prefetchEndIndexPath = [self _prefetchEndIndexPath];
    for (NSInteger i = 0; i < MPPrefetchDetectCount; i++) {
        MPTableViewSection *section = _sectionArray[prefetchEndIndexPath.section];
        if (prefetchEndIndexPath.row < section.numberOfRows - 1) { // cannot use prefetchEndIndexPath.row + 1 < section.numberOfRows, prefetchEndIndexPath.row may be NSIntegerMax.
            prefetchEndIndexPath.row++;
        } else {
            while (prefetchEndIndexPath.section < _numberOfSections - 1) {
                section = _sectionArray[++prefetchEndIndexPath.section];
                if (section.numberOfRows > 0) {
                    prefetchEndIndexPath.row = 0;
                    goto _prefetch_scrolling_down;
                }
            }
            break;
        }
        
    _prefetch_scrolling_down:
        if (!isScrollingUp && i < MPPrefetchBatchCount) {
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
    
    NSMutableArray *alreadyVisibleIndexPaths = [[NSMutableArray alloc] init];
    NSMutableArray *cancelPrefetchIndexPaths = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in _prefetchIndexPaths) {
        if (_NSIndexPathCompareStruct(indexPath, _firstVisibleIndexPath) != NSOrderedAscending && _NSIndexPathCompareStruct(indexPath, _lastVisibleIndexPath) != NSOrderedDescending) {
            [alreadyVisibleIndexPaths addObject:indexPath];
        } else if (_NSIndexPathCompareStruct(indexPath, prefetchStartIndexPath) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, prefetchEndIndexPath) == NSOrderedDescending) {
            [cancelPrefetchIndexPaths addObject:indexPath];
        } else {
            MPTableViewSection *section = _sectionArray[indexPath.section];
            if (indexPath.row >= section.numberOfRows) { // only happens after update
                [cancelPrefetchIndexPaths addObject:indexPath];
            }
        }
    }
    
    [_prefetchIndexPaths removeObjectsInArray:alreadyVisibleIndexPaths];
    [_prefetchIndexPaths removeObjectsInArray:cancelPrefetchIndexPaths];
    
    if (_respondsTo_cancelPrefetchingForRowsAtIndexPaths && cancelPrefetchIndexPaths.count > 0) {
        [_prefetchDataSource MPTableView:self cancelPrefetchingForRowsAtIndexPaths:cancelPrefetchIndexPaths];
    }
    
    _lastContentOffsetY = _contentOffsetPosition.start;
}

- (void)_cancelPrefetchingIfNeeded {
    if (_respondsTo_cancelPrefetchingForRowsAtIndexPaths && _prefetchIndexPaths.count > 0) {
        NSArray *cancelPrefetchIndexPaths = [_prefetchIndexPaths copy];
        [_prefetchDataSource MPTableView:self cancelPrefetchingForRowsAtIndexPaths:cancelPrefetchIndexPaths];
    }
    [_prefetchIndexPaths removeAllObjects];
    _lastContentOffsetY = _contentOffsetPosition.start;
}

#pragma mark - select

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    _isLayoutUpdateBlocked = YES;
    [self _willSelectCellIfNeededWithTouches:touches];
    _isLayoutUpdateBlocked = NO;
}

- (void)_willSelectCellIfNeededWithTouches:(NSSet *)touches {
    if (_highlightedIndexPath || _draggingIndexPath) {
        return;
    }
    
    if ([self isDecelerating] || [self isDragging] || _listContentPosition.start >= _listContentPosition.end) {
        return;
    }
    
    UITouch *touch = touches.anyObject;
    CGPoint location = [touch locationInView:self];
    CGFloat locationY = location.y;
    if (!_allowsSelection || locationY < _listContentPosition.start || locationY > _listContentPosition.end) {
        return;
    }
    
    NSIndexPathStruct touchedIndexPathStruct = [self _indexPathForContentOffsetY:locationY - _listContentPosition.start];
    if (MPTV_IS_HEADER(touchedIndexPathStruct.row) || MPTV_IS_FOOTER(touchedIndexPathStruct.row)) {
        return;
    }
    
    NSIndexPath *touchedIndexPath = _NSIndexPathFromStruct(touchedIndexPathStruct);
    MPTableViewCell *cell = [_displayedCellDict objectForKey:touchedIndexPath];
    if (!cell) {
        return;
    }
    
    if (_dragModeEnabled) {
        if (_allowsSelectionInDragMode) {
            // If a rect specified for starting a drag and allowsSelectionInDragMode is enabled, the cell can't be selected.
            if (_respondsTo_rectForCellToMoveRowAtIndexPath && [self _canTriggerDragInRectForCell:cell atIndexPath:touchedIndexPath location:location]) {
                return;
            }
        } else {
            return;
        }
    }
    
    if (_respondsTo_shouldHighlightRowAtIndexPath && ![_tableViewDelegate MPTableView:self shouldHighlightRowAtIndexPath:touchedIndexPath]) {
        return;
    }
    
    _highlightedIndexPath = touchedIndexPath;
    
    if (![cell isHighlighted]) {
        [cell setHighlighted:YES];
    }
    
    if (_respondsTo_didHighlightRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self didHighlightRowAtIndexPath:touchedIndexPath];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    _isLayoutUpdateBlocked = YES;
    [self _unhighlightCellIfNeeded];
    _isLayoutUpdateBlocked = NO;
}

- (void)_unhighlightCellIfNeeded {
    if (!_highlightedIndexPath) {
        return;
    }
    
    MPTableViewCell *cell = [_displayedCellDict objectForKey:_highlightedIndexPath];
    
    if ([cell isHighlighted]) {
        if (_isInitializationPending) { // during table view clearing
            [cell setHighlighted:NO animated:NO];
        } else {
            [cell setHighlighted:NO];
        }
    }
    
    NSIndexPath *highlightedIndexPath = _highlightedIndexPath;
    _highlightedIndexPath = nil;
    if (_respondsTo_didUnhighlightRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self didUnhighlightRowAtIndexPath:highlightedIndexPath];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    _isLayoutUpdateBlocked = YES;
    [self _didSelectCellWithTouches:touches];
    _isLayoutUpdateBlocked = NO;
}

- (void)_didSelectCellWithTouches:(NSSet *)touches {
    if (!_highlightedIndexPath || !_allowsSelection) {
        return;
    }
    
    MPTableViewCell *cell = [_displayedCellDict objectForKey:_highlightedIndexPath];
    if (!cell) {
        _highlightedIndexPath = nil;
        return;
    }
    
    NSIndexPath *selectedIndexPath = _highlightedIndexPath;
    if (_respondsTo_willSelectRowAtIndexPath) {
        NSIndexPath *indexPath = [_tableViewDelegate MPTableView:self willSelectRowAtIndexPath:selectedIndexPath];
        if (!indexPath) {
            return [self _unhighlightCellIfNeeded];
        }
        
        if (indexPath.section < 0 || indexPath.row < 0) {
            NSAssert(NO, @"indexPath.section and indexPath.row must not be negative");
            return [self _unhighlightCellIfNeeded];
        }
        
        if (indexPath.section >= _sectionArray.count) {
            return [self _unhighlightCellIfNeeded];
        } else {
            MPTableViewSection *section = _sectionArray[indexPath.section];
            if (indexPath.row >= section.numberOfRows) {
                return [self _unhighlightCellIfNeeded];
            }
        }
        
        if (![indexPath isEqual:selectedIndexPath]) {
            cell = [_displayedCellDict objectForKey:selectedIndexPath = indexPath];
        }
    }
    
    if (_allowsMultipleSelection && [_selectedIndexPaths containsObject:selectedIndexPath]) {
        [self _deselectRowAtIndexPath:selectedIndexPath animated:NO shouldRemove:YES shouldSetAnimated:NO];
        [self _unhighlightCellIfNeeded];
    } else {
        BOOL shouldNotify = YES;
        if (!_allowsMultipleSelection && _selectedIndexPaths.count > 0) {
            for (NSIndexPath *indexPath in _selectedIndexPaths.allObjects) {
                if ([indexPath isEqual:selectedIndexPath]) {
                    shouldNotify = NO;
                    continue;
                }
                [self _deselectRowAtIndexPath:indexPath animated:NO shouldRemove:YES shouldSetAnimated:NO];
            }
        }
        
        [_selectedIndexPaths addObject:selectedIndexPath];
        [cell setSelected:YES];
        [self _unhighlightCellIfNeeded];
        
        if (_respondsTo_didSelectCellForRowAtIndexPath) {
            _isLayoutUpdateBlocked = NO;
            [_tableViewDelegate MPTableView:self didSelectCell:cell forRowAtIndexPath:selectedIndexPath];
        }
        if (shouldNotify) {
            [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    
    _isLayoutUpdateBlocked = YES;
    [self _unhighlightCellIfNeeded];
    _isLayoutUpdateBlocked = NO;
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
    
    [self _ensureDragGestureRecognizer];
    _dragLongGestureRecognizer.enabled = dragModeEnabled;
    
    _dragModeEnabled = dragModeEnabled;
}

- (void)_ensureDragGestureRecognizer {
    if (_dragLongGestureRecognizer) {
        return;
    }
    
    _dragLongGestureRecognizer = [[MPTableViewLongGestureRecognizer alloc] initWithTarget:self action:@selector(_dragGestureRecognizerAction:)];
    _dragLongGestureRecognizer.tableView = self;
    _dragLongGestureRecognizer.minimumPressDuration = _minimumPressDurationToBeginDrag;
    [_contentWrapperView addGestureRecognizer:_dragLongGestureRecognizer];
}

- (void)setMinimumPressDurationForDrag:(CFTimeInterval)minimumPressDurationToBeginDrag {
    [self _ensureDragGestureRecognizer];
    _dragLongGestureRecognizer.minimumPressDuration = _minimumPressDurationToBeginDrag = minimumPressDurationToBeginDrag;
}

- (BOOL)_shouldBeginDragGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    if ([self isUpdating]) {
        return NO;
    }
    
    CGPoint location = [gestureRecognizer locationInView:_contentWrapperView];
    _isLayoutUpdateBlocked = YES;
    [self _beginDraggingCellAtLocation:location];
    _isLayoutUpdateBlocked = NO;
    
    return _dragAutoScrollDisplayLink ? YES : NO; // _draggingIndexPath or _draggingCell may be from a previous drag
}

- (void)_dragGestureRecognizerAction:(UIGestureRecognizer *)gestureRecognizer {
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            
        }
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint location = [gestureRecognizer locationInView:_contentWrapperView];
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

- (void)_beginDraggingCellAtLocation:(CGPoint)location {
    [self _endDraggingCellIfNeededImmediately:NO];
    
    CGFloat locationY = location.y;
    if (locationY < _listContentPosition.start || locationY > _listContentPosition.end) {
        return;
    }
    
    NSIndexPathStruct touchedIndexPathStruct = [self _indexPathForContentOffsetY:locationY - _listContentPosition.start];
    if (MPTV_IS_HEADER(touchedIndexPathStruct.row) || MPTV_IS_FOOTER(touchedIndexPathStruct.row)) {
        return;
    }
    
    NSIndexPath *touchedIndexPath = _NSIndexPathFromStruct(touchedIndexPathStruct);
    if ([touchedIndexPath isEqual:_draggingIndexPath]) {
        return;
    }
    
    if (_respondsTo_canMoveRowAtIndexPath && ![_tableViewDataSource MPTableView:self canMoveRowAtIndexPath:touchedIndexPath]) {
        return;
    }
    
    MPTableViewCell *cell = [_displayedCellDict objectForKey:touchedIndexPath];
    if (!cell) {
        return;
    }
    
    if (_respondsTo_rectForCellToMoveRowAtIndexPath && ![self _canTriggerDragInRectForCell:cell atIndexPath:touchedIndexPath location:location]) {
        return;
    }
    
    _draggingCell = cell;
    _draggingSourceIndexPath = _draggingIndexPath = touchedIndexPath;
    _dragReferencePoint = MPPointSubtraction(location, _draggingCell.center);
    _draggingGeneration++;
    
    [_contentWrapperView bringSubviewToFront:_draggingCell];
    
    [self _ensureDragAutoScrollDisplayLink];
    
    if (_respondsTo_shouldMoveRowAtIndexPath) {
        [_tableViewDelegate MPTableView:self shouldMoveRowAtIndexPath:touchedIndexPath];
    }
}

- (BOOL)_canTriggerDragInRectForCell:(MPTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath location:(CGPoint)location {
    CGRect touchabledFrame = [_tableViewDataSource MPTableView:self rectForCellToMoveRowAtIndexPath:indexPath];
    
    return CGRectContainsPoint(touchabledFrame, [cell convertPoint:location fromView:_contentWrapperView]);
}

- (void)_ensureDragAutoScrollDisplayLink {
    if (!_dragAutoScrollDisplayLink) {
        _dragAutoScrollDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_dragAutoScrollAction)];
        [_dragAutoScrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    [self _dragAutoScrollIfNeeded];
}

- (void)_dragCellToLocation:(CGPoint)location {
    [self _setDraggedCellCenter:MPPointSubtraction(location, _dragReferencePoint)];
    [self _dragAutoScrollIfNeeded];
    [self _layoutSubviewsInternal];
    
    location = _draggingCell.center;
    [self _dragTriggerMoveAtLocationY:location.y];
}

- (void)_setDraggedCellCenter:(CGPoint)center {
    if (!_allowsDraggedCellToFloat) {
        center.x = self.bounds.size.width / 2;
        if (center.y < _listContentPosition.start) {
            center.y = _listContentPosition.start;
        }
        if (center.y > _listContentPosition.end) {
            center.y = _listContentPosition.end;
        }
    }
    
    [UIView performWithoutAnimation:^{
        _draggingCell.center = center;
    }];
}

- (void)_dragAutoScrollAction {
    CGPoint newPoint = self.contentOffset;
    newPoint.y += _dragAutoScrollRate;
    
    if (_dragAutoScrollRate < 0) {
        CGFloat minContentOffsetY = -[self _innerContentInset].top;
        if (newPoint.y < minContentOffsetY) {
            newPoint.y = minContentOffsetY;
            _dragAutoScrollDisplayLink.paused = YES;
        }
    } else if (_dragAutoScrollRate > 0) {
        CGFloat contentEndPositionY = _listContentPosition.end + _tableFooterView.bounds.size.height;
        CGFloat maxContentOffsetY = contentEndPositionY + [self _innerContentInset].bottom - self.bounds.size.height;
        if (newPoint.y > maxContentOffsetY) {
            newPoint.y = maxContentOffsetY;
            _dragAutoScrollDisplayLink.paused = YES;
        }
    }
    
    self.contentOffset = newPoint;
    
    newPoint.x = _draggingCell.center.x;
    newPoint.y -= _dragAutoScrollDelta;
    [self _setDraggedCellCenter:newPoint];
    
    [self _layoutSubviewsInternal];
    [self _dragTriggerMoveAtLocationY:newPoint.y];
}

- (void)_dragAutoScrollIfNeeded {
    _dragAutoScrollRate = 0;
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (_draggingCell.frame.origin.y < _contentOffsetPosition.start + contentInset.top) {
        if (_contentOffsetPosition.start > -contentInset.top) {
            _dragAutoScrollRate = _draggingCell.frame.origin.y - _contentOffsetPosition.start - contentInset.top;
            _dragAutoScrollRate /= 7;
        }
    } else if (CGRectGetMaxY(_draggingCell.frame) > _contentOffsetPosition.end - contentInset.bottom) {
        CGFloat contentEndPositionY = _listContentPosition.end + _tableFooterView.bounds.size.height;
        if (_contentOffsetPosition.end < contentEndPositionY + contentInset.bottom) {
            _dragAutoScrollRate = CGRectGetMaxY(_draggingCell.frame) - _contentOffsetPosition.end + contentInset.bottom;
            _dragAutoScrollRate /= 7;
        }
    }
    
    _dragAutoScrollDelta = _contentOffsetPosition.start - _draggingCell.center.y;
    _dragAutoScrollDisplayLink.paused = (_dragAutoScrollRate == 0);
}

- (void)_dragTriggerMoveAtLocationY:(CGFloat)locationY {
    if (locationY < _listContentPosition.start || locationY > _listContentPosition.end) {
        return;
    }
    
    if (locationY < _contentOffsetPosition.start) {
        locationY = _contentOffsetPosition.start;
    } else if (locationY > _contentOffsetPosition.end) {
        locationY = _contentOffsetPosition.end;
    }
    
    NSIndexPathStruct newIndexPathStruct = [self _indexPathForContentOffsetY:locationY - _listContentPosition.start];
    if (MPTV_IS_HEADER(newIndexPathStruct.row)) {
        if (newIndexPathStruct.section == _draggingIndexPath.section) {
            return;
        }
        
        newIndexPathStruct.row = 0;
    } else if (MPTV_IS_FOOTER(newIndexPathStruct.row)) {
        if (newIndexPathStruct.section == _draggingIndexPath.section) {
            return;
        }
        
        MPTableViewSection *section = _sectionArray[newIndexPathStruct.section];
        newIndexPathStruct.row = section.numberOfRows;
    } else {
        MPTableViewSection *section = _sectionArray[newIndexPathStruct.section];
        CGFloat startPosition = [section startPositionAtRow:newIndexPathStruct.row];
        CGFloat endPosition = [section endPositionAtRow:newIndexPathStruct.row];
        CGFloat targetCenterY = startPosition + (endPosition - startPosition) / 2 + _listContentPosition.start;
        
        CGRect frame = [self _cellFrameAtIndexPath:_draggingIndexPath];
        CGFloat centerY = _draggingCell.center.y;
        CGFloat minY = centerY - frame.size.height / 2;
        CGFloat maxY = centerY + frame.size.height / 2;
        if (targetCenterY < minY || targetCenterY > maxY) { // dragged cell must cross target cell center.y
            return;
        }
    }
    
    if (_NSIndexPathCompareStruct(_draggingIndexPath, newIndexPathStruct) == NSOrderedSame) {
        return;
    }
    
    NSIndexPath *newIndexPath = _NSIndexPathFromStruct(newIndexPathStruct);
    if (_respondsTo_targetIndexPathForMoveFromRowAtIndexPathToProposedIndexPath) {
        _isLayoutUpdateBlocked = YES;
        newIndexPath = [_tableViewDataSource MPTableView:self targetIndexPathForMoveFromRowAtIndexPath:_draggingSourceIndexPath toProposedIndexPath:newIndexPath];
        _isLayoutUpdateBlocked = NO;
        if (!newIndexPath) {
            return;
        }
        
        if (newIndexPath.section < 0 || newIndexPath.row < 0) {
            NSAssert(NO, @"newIndexPath.section and newIndexPath.row must not be negative");
            return;
        }
        
        if (newIndexPath.section >= _sectionArray.count) {
            return;
        } else {
            MPTableViewSection *section = _sectionArray[newIndexPath.section];
            if (newIndexPath.row > section.numberOfRows) {
                return;
            }
        }
        
        if ([newIndexPath isEqual:_draggingIndexPath]) {
            return;
        }
    }
    
    // NSIntegerMax is used as a sentinel value and must not be a valid row index
    if (newIndexPath.row == NSIntegerMax) {
        MPTV_THROW_EXCEPTION(@"row index is NSIntegerMax");
    }
    
    _isLayoutUpdateBlocked = YES;
    [self _cacheCellsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
    [self _cacheAndAdjustSectionViewsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
    _isLayoutUpdateBlocked = NO;
    
    MPTableViewUpdateManager *updateManager = [self _currentUpdateManager];
    updateManager.dragSourceSection = _draggingIndexPath.section;
    updateManager.dragDestinationSection = newIndexPath.section;
    [updateManager addMoveOutIndexPath:_draggingIndexPath];
    [updateManager addMoveInIndexPath:newIndexPath previousIndexPath:_draggingIndexPath previousFrame:[self _cellFrameAtIndexPath:_draggingIndexPath]];
    _draggingIndexPath = newIndexPath;
    
    NSIndexPathStruct firstVisibleIndexPath = _firstVisibleIndexPath;
    NSIndexPathStruct lastVisibleIndexPath = _lastVisibleIndexPath;
    [self _updateUsingManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    if (_NSIndexPathStructCompareStruct(_firstVisibleIndexPath, firstVisibleIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(_lastVisibleIndexPath, lastVisibleIndexPath) == NSOrderedDescending) {
        _supplementSubviewsRequiredFlag = YES;
    }
}

- (void)_endDraggingCellIfNeededImmediately:(BOOL)immediately {
    /*
     for a situation like:
     tableView.dragModeEnabled = NO;
     [tableView reloadData];
     */
    if (!_dragAutoScrollDisplayLink) {
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
    NSUInteger draggingGeneration = _draggingGeneration;
    
    if (_dragAutoScrollDisplayLink) {
        [_dragAutoScrollDisplayLink invalidate];
        _dragAutoScrollDisplayLink = nil;
        
        if (_respondsTo_moveRowAtIndexPathToIndexPath) {
            _isLayoutUpdateBlocked = YES;
            [_tableViewDataSource MPTableView:self moveRowAtIndexPath:draggingSourceIndexPath toIndexPath:_draggingIndexPath];
            _isLayoutUpdateBlocked = NO;
        }
    }
    
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (!_draggingCell) {
            return;
        }
        
        if (draggingGeneration == _draggingGeneration) {
            _draggingSourceIndexPath = _draggingIndexPath = nil;
            _draggingCell = nil;
        }
        
        _isLayoutUpdateBlocked = YES;
        
        if (_respondsTo_didEndMovingCellFromRowAtIndexPath) {
            [_tableViewDelegate MPTableView:self didEndMovingCell:draggingCell fromRowAtIndexPath:draggingSourceIndexPath];
        }
        
        if (!immediately) {
            [self _cacheCellsOutsideStartIndexPath:_firstVisibleIndexPath toEndIndexPath:_lastVisibleIndexPath];
        }
        
        _isLayoutUpdateBlocked = NO;
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
