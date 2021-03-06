//
//  MPTableView.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"
#import "MPTableViewSection.h"

//static NSRange
//MPSubtractionRange(NSRange subtrahend, NSRange minuend) {
//    if (subtrahend.length == minuend.length) {
//        return NSMakeRange(0, 0);
//    } else if (minuend.length == 0) {
//        return subtrahend;
//    } else {
//        return NSMakeRange((subtrahend.location == minuend.location) ? NSMaxRange(minuend) - 1: subtrahend.location, subtrahend.length - minuend.length + 1);
//    }
//}

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
    NSUInteger indexes[2] = {(NSUInteger)indexPathStruct.section, (NSUInteger)indexPathStruct.row};
    return [[NSIndexPath alloc] initWithIndexes:indexes length:2];
}

NS_INLINE BOOL
_NSIndexPathStructEqu(NSIndexPathStruct indexPath1, NSIndexPathStruct indexPath2) {
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

@interface MPTableView (MPTableView_PanPrivate)

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
        self.minimumPressDuration = 0.1;
        self.delegate = self;
    }
    
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return [self.tableView _mp_gestureRecognizerShouldBegin:gestureRecognizer];
}

@end

#pragma mark -

@interface MPTableReusableView (MPTableReusableView_internal)

@property (nonatomic, copy, readwrite) NSString *reuseIdentifier;

@end

#pragma mark -

static MPTableViewRowAnimation
MPTableViewGetRandomRowAnimation() {
    u_int32_t random = arc4random() % 7;
    return (MPTableViewRowAnimation)random;
}

static void
MPTableViewSubviewDisappearWithRowAnimation(UIView *view, CGFloat top, MPTableViewRowAnimation animation, MPTableViewPosition *sectionPosition) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (view.opaque == NO) {
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
MPTableViewSubviewDisplayWithRowAnimation(UIView *view, CGRect lastFrame, MPTableViewRowAnimation animation) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (view.opaque == NO) {
                view.hidden = NO;
                return;
            } else {
                frame.origin.y = lastFrame.origin.y;
                view.alpha = 1;
            }
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin = lastFrame.origin;
            view.alpha = 1;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin = lastFrame.origin;
            view.alpha = 1;
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
            
            view.alpha = 1;
        }
            break;
            
        default:
            break;
    }
    
    view.frame = frame;
}

NSString *const MPTableViewSelectionDidChangeNotification = @"MPTableViewSelectionDidChangeNotification";

#define MPTV_CHECK_DATASOURCE if (!_mpDataSource) { \
return -1; \
}

#define MPTV_OFF_SCREEN (frame.size.height <= 0 || frame.origin.y > _contentOffsetPosition.endPos || CGRectGetMaxY(frame) < _contentOffsetPosition.startPos)
#define MPTV_ON_SCREEN (frame.size.height > 0 && frame.origin.y <= _contentOffsetPosition.endPos && CGRectGetMaxY(frame) >= _contentOffsetPosition.startPos)

const NSTimeInterval MPTableViewDefaultAnimationDuration = 0.3;

@implementation MPTableView {
    UIView *_contentWrapperView;
    MPTableViewPosition *_contentListPosition; // the position between tableView's header and footer
    MPTableViewPosition *_contentOffsetPosition;
    MPTableViewPosition *_contentListOffsetPosition; // the position of contentOffset minus the _contentListPosition.startPos
    
    NSIndexPathStruct _beginIndexPath, _endIndexPath;
    
    NSMutableSet *_selectedIndexPaths;
    NSIndexPath *_highlightedIndexPath;
    
    BOOL
    _layoutSubviewsLock,
    _reloadDataLock, // will be YES when reloading data (if asserted it, you should not call that function in a data source function).
    _updateSubviewsLock; // will be YES when invoked -layoutSubviews or starting a new update transaction
    
    NSUInteger _suspendingHeaderSection, _suspendingFooterSection;
    
    NSUInteger _numberOfSections;
    
    NSMutableDictionary *_displayedCellsDic, *_displayedSectionViewsDic;
    NSMutableArray *_sectionsArray;
    NSMutableDictionary *_reusableCellsDic, *_registerCellClassesDic, *_registerCellNibsDic;
    NSMutableDictionary *_reusableReusableViewsDic, *_registerReusableViewClassesDic, *_registerReusableViewNibsDic;
    
    __weak id <MPTableViewDelegate> _mpDelegate;
    __weak id <MPTableViewDataSource> _mpDataSource;
    BOOL _reloadDataNeededFlag; // change the dataSource will set it to YES
    BOOL _reloadDataLayoutNeededFlag;
    
    MPTableViewEstimatedManager *_estimatedManager;
    NSMutableDictionary *_estimatedCellsDic, *_estimatedSectionViewsDic;
    
    // update
    NSMutableArray *_updateManagersStack;
    NSInteger _updateContextStep;
    
    NSUInteger _updateAnimationStep;
    
    CGFloat _updateLastInsertionOriginY, _updateLastDeletionOriginY;
    
    NSMutableDictionary *_updateNewCellsDic, *_updateNewSectionViewsDic;
    
    NSMutableDictionary *_updateDeletedCellsDic, *_updateDeletedSectionViewsDic;
    
    NSMutableArray *_updateAnimationBlocks;
    NSMutableSet *_updateAnimatedOffscreenIndexPaths, *_updateAnimatedNewOffscreenIndexPaths;
    NSMutableSet *_updateExchangedSelectedIndexPaths;
    
    BOOL _updateContentOffsetChanged;
    NSMutableArray *_updateExecutionActions;
    
    // drag mode
    BOOL _dragModeEnabled;
    CGPoint _dragModeMinuendPoint;
    CGFloat _dragModeScrollRate, _dragModeOffsetDistance;
    MPTableViewLongGestureRecognizer *_dragModeLongGestureRecognizer;
    NSIndexPath *_draggedIndexPath, *_draggedSourceIndexPath;
    MPTableViewCell *_dragModeDragCell;
    CADisplayLink *_dragModeAutoScrollDisplayLink;
    
    // prefetch
    CGFloat _previousContentOffsetY;
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
    _respond_canMoveRowToIndexPath,
    
    _respond_rectForCellToMoveRowAtIndexPath,
    
    _respond_moveRowAtIndexPathToIndexPath;
    
    BOOL
    _respond_willDisplayCellForRowAtIndexPath,
    _respond_willDisplayFooterViewForSection,
    _respond_willDisplayHeaderViewForSection,
    _respond_didEndDisplayingCellForRowAtIndexPath,
    _respond_didEndDisplayingFooterViewForSection,
    _respond_didEndDisplayingHeaderViewForSection,
    
    _respond_willSelectRowAtIndexPath,
    _respond_willDeselectRowAtIndexPath,
    _respond_didSelectRowForCellAtIndexPath,
    _respond_didDeselectRowAtIndexPath,
    
    _respond_shouldHighlightRowAtIndexPath,
    _respond_didHighlightRowAtIndexPath,
    _respond_didUnhighlightRowAtIndexPath,
    
    _respond_beginToInsertCellForRowAtIndexPath,
    _respond_beginToDeleteCellForRowAtIndexPath,
    
    _respond_beginToInsertHeaderViewForSection,
    _respond_beginToInsertFooterViewForSection,
    _respond_beginToDeleteHeaderViewForSection,
    _respond_beginToDeleteFooterViewForSection,
    
    _respond_shouldMoveRowAtIndexPath,
    _respond_didEndMoveRowAtIndexPathToIndexPath;
    
    BOOL
    _respond_prefetchRowsAtIndexPaths,
    _respond_cancelPrefetchingForRowsAtIndexPaths;
}

@dynamic delegate;

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
        _cachesReloadEnabled = [aDecoder decodeBoolForKey:@"_cachesReloadEnabled"];
        _allowsSelection = [aDecoder decodeBoolForKey:@"_allowsSelection"];
        _allowsMultipleSelection = [aDecoder decodeBoolForKey:@"_allowsMultipleSelection"];
        _updateForceReload = [aDecoder decodeBoolForKey:@"_updateForceReload"];
        _updateOptimizeViews = [aDecoder decodeBoolForKey:@"_updateOptimizeViews"];
        _updateLayoutSubviewsOptionEnabled = [aDecoder decodeBoolForKey:@"_updateLayoutSubviewsOptionEnabled"];
        _updateAllowUserInteraction = [aDecoder decodeBoolForKey:@"_updateAllowUserInteraction"];
        _dragModeEnabled = [aDecoder decodeBoolForKey:@"_dragModeEnabled"];
        _allowsSelectionForDragMode = [aDecoder decodeBoolForKey:@"_allowsSelectionForDragMode"];
        _dragCellFloating = [aDecoder decodeBoolForKey:@"_dragCellFloating"];
        
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
    
    [self _endDragCellIfNeededImmediately:NO];
    
    [aCoder encodeInteger:_style forKey:@"_tableViewStyle"];
    [aCoder encodeDouble:_rowHeight forKey:@"_rowHeight"];
    [aCoder encodeDouble:_sectionHeaderHeight forKey:@"_sectionHeaderHeight"];
    [aCoder encodeDouble:_sectionFooterHeight forKey:@"_sectionFooterHeight"];
    [aCoder encodeBool:_cachesReloadEnabled forKey:@"_cachesReloadEnabled"];
    [aCoder encodeBool:_allowsSelection forKey:@"_allowsSelection"];
    [aCoder encodeBool:_allowsMultipleSelection forKey:@"_allowsMultipleSelection"];
    [aCoder encodeBool:_updateForceReload forKey:@"_updateForceReload"];
    [aCoder encodeBool:_updateOptimizeViews forKey:@"_updateOptimizeViews"];
    [aCoder encodeBool:_updateLayoutSubviewsOptionEnabled forKey:@"_updateLayoutSubviewsOptionEnabled"];
    [aCoder encodeBool:_updateAllowUserInteraction forKey:@"_updateAllowUserInteraction"];
    [aCoder encodeBool:_dragModeEnabled forKey:@"_dragModeEnabled"];
    [aCoder encodeBool:_allowsSelectionForDragMode forKey:@"_allowsSelectionForDragMode"];
    [aCoder encodeBool:_dragCellFloating forKey:@"_dragCellFloating"];
    
    [aCoder encodeObject:_registerCellNibsDic forKey:@"_registerCellNibsDic"];
    [aCoder encodeObject:_registerReusableViewNibsDic forKey:@"_registerReusableViewNibsDic"];
    
    [_tableHeaderView removeFromSuperview];
    [_tableFooterView removeFromSuperview];
    [_contentWrapperView removeFromSuperview];
    [_backgroundView removeFromSuperview];
    
    NSMutableArray *sectionViews = [NSMutableArray arrayWithArray:_displayedSectionViewsDic.allValues];
    for (NSArray *array in _reusableReusableViewsDic.allValues) {
        [sectionViews addObjectsFromArray:array];
    }
    [sectionViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    [super encodeWithCoder:aCoder];
    
    [self addSubview:_contentWrapperView];
    [self sendSubviewToBack:_contentWrapperView];
    
    for (UIView *sectionView in sectionViews) {
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
    }
    [sectionViews removeAllObjects];
    
    if (_tableHeaderView) {
        [aCoder encodeObject:_tableHeaderView forKey:@"_tableHeaderView"];
        [self insertSubview:_tableHeaderView aboveSubview:_contentWrapperView];
    }
    if (_tableFooterView) {
        [aCoder encodeObject:_tableFooterView forKey:@"_tableFooterView"];
        [self insertSubview:_tableFooterView aboveSubview:_contentWrapperView];
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
        _sectionHeaderHeight = 35.;
        _sectionFooterHeight = 35.;
    }
    
    _allowsSelection = YES;
    _allowsMultipleSelection = NO;
    _cachesReloadEnabled = YES;
    _updateForceReload = YES;
    _updateOptimizeViews = NO;
    _updateLayoutSubviewsOptionEnabled = YES;
    _updateAllowUserInteraction = YES;
    _dragModeEnabled = NO;
    _minimumPressDurationForDrag = 0.1;
    _allowsSelectionForDragMode = NO;
    _dragCellFloating = NO;
}

- (void)_initializeData {
    _layoutSubviewsLock = YES;
    _reloadDataLock = NO;
    
    [self addSubview:_contentWrapperView = [[UIView alloc] init]];
    [self sendSubviewToBack:_contentWrapperView];
    _contentWrapperView.autoresizesSubviews = NO; // @optional
    _numberOfSections = 1;
    
    [self _resetContentIndexPaths];
    _contentListPosition = [MPTableViewPosition positionStart:0 toEnd:0];
    _contentOffsetPosition = [MPTableViewPosition positionStart:0 toEnd:0];
    _contentListOffsetPosition = [MPTableViewPosition positionStart:0 toEnd:0];
    
    _displayedCellsDic = [[NSMutableDictionary alloc] init];
    _displayedSectionViewsDic = [[NSMutableDictionary alloc] init];
    _reusableCellsDic = [[NSMutableDictionary alloc] init];
    _reusableReusableViewsDic = [[NSMutableDictionary alloc] init];
    
    _sectionsArray = [[NSMutableArray alloc] init];
    
    _selectedIndexPaths = [[NSMutableSet alloc] init];
    
    _reloadDataNeededFlag = NO;
    _reloadDataLayoutNeededFlag = NO;
    
    _updateContextStep = 0;
    _updateAnimationStep = 0;
    _updateSubviewsLock = NO;
    _updateContentOffsetChanged = NO;
}

- (void)_resetContentIndexPaths {
    _suspendingFooterSection = _suspendingHeaderSection = NSNotFound;
    
    _beginIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
    _endIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
    
    _highlightedIndexPath = nil;
}

- (void)dealloc {
    _cachesReloadEnabled = NO;
    [self _clear];
    [_sectionsArray removeAllObjects];
}

#pragma mark -

- (void)_respondsToDataSource {
    _respond_numberOfSectionsInMPTableView = [_mpDataSource respondsToSelector:@selector(numberOfSectionsInMPTableView:)];
    if (!_respond_numberOfSectionsInMPTableView && _mpDataSource) {
        _numberOfSections = 1;
    }
    
    _respond_heightForRowAtIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForRowAtIndexPath:)];
    _respond_heightForHeaderInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForHeaderInSection:)];
    _respond_heightForFooterInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForFooterInSection:)];
    
    _respond_estimatedHeightForRowAtIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForRowAtIndexPath:)];
    _respond_estimatedHeightForHeaderInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForHeaderInSection:)];
    _respond_estimatedHeightForFooterInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:estimatedHeightForFooterInSection:)];
    
    _respond_viewForHeaderInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:viewForHeaderInSection:)];
    _respond_viewForFooterInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:viewForFooterInSection:)];
    
    _respond_canMoveRowAtIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:canMoveRowAtIndexPath:)];
    _respond_canMoveRowToIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:canMoveRowToIndexPath:)];
    _respond_rectForCellToMoveRowAtIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:rectForCellToMoveRowAtIndexPath:)];
    _respond_moveRowAtIndexPathToIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:moveRowAtIndexPath:toIndexPath:)];
}

- (void)_respondsToDelegate {
    _respond_willDisplayCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willDisplayCell:forRowAtIndexPath:)];
    _respond_willDisplayFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:willDisplayFooterView:forSection:)];
    _respond_willDisplayHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:willDisplayHeaderView:forSection:)];
    
    _respond_didEndDisplayingCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingCell:forRowAtIndexPath:)];
    _respond_didEndDisplayingFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingFooterView:forSection:)];
    _respond_didEndDisplayingHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:didEndDisplayingHeaderView:forSection:)];
    
    _respond_willSelectRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willSelectRowAtIndexPath:)];
    _respond_willDeselectRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willDeselectRowAtIndexPath:)];
    _respond_didSelectRowForCellAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didSelectRowForCell:atIndexPath:)];
    _respond_didDeselectRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didDeselectRowAtIndexPath:)];
    _respond_shouldHighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:shouldHighlightRowAtIndexPath:)];
    _respond_didHighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didHighlightRowAtIndexPath:)];
    _respond_didUnhighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didUnhighlightRowAtIndexPath:)];
    
    _respond_beginToInsertCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertCell:forRowAtIndexPath:withLastInsertionOriginY:)];
    _respond_beginToInsertHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertHeaderView:forSection:withLastInsertionOriginY:)];
    _respond_beginToInsertFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertFooterView:forSection:withLastInsertionOriginY:)];
    
    _respond_beginToDeleteCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteCell:forRowAtIndexPath:withLastDeletionOriginY:)];
    _respond_beginToDeleteHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteHeaderView:forSection:withLastDeletionOriginY:)];
    _respond_beginToDeleteFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteFooterView:forSection:withLastDeletionOriginY:)];
    
    _respond_shouldMoveRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:shouldMoveRowAtIndexPath:)];
    _respond_didEndMoveRowAtIndexPathToIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didEndMoveRowAtIndexPath:toIndexPath:)];
}

- (void)_respondsToPrefetchDataSource {
    _respond_prefetchRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:prefetchRowsAtIndexPaths:)];
    _respond_cancelPrefetchingForRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:cancelPrefetchingForRowsAtIndexPaths:)];
}

#pragma mark - public

- (void)setDataSource:(id<MPTableViewDataSource>)dataSource {
    NSParameterAssert(!_updateSubviewsLock);
    NSParameterAssert(!_reloadDataLock);
    if (!dataSource && !_mpDataSource) {
        return;
    }
    
    if (dataSource) {
        if (![dataSource respondsToSelector:@selector(MPTableView:cellForRowAtIndexPath:)] || ![dataSource respondsToSelector:@selector(MPTableView:numberOfRowsInSection:)]) {
            NSAssert(NO, @"need @required functions of dataSource");
            return;
        }
    }
    
    _mpDataSource = dataSource;
    [self _respondsToDataSource];
    
    _layoutSubviewsLock = NO;
    _reloadDataNeededFlag = YES;
    _reloadDataLayoutNeededFlag = YES;
    [self setNeedsLayout];
}

- (id<MPTableViewDataSource>)dataSource {
    return _mpDataSource;
}

- (void)setDelegate:(id<MPTableViewDelegate>)delegate {
    NSParameterAssert(!_updateSubviewsLock);
    NSParameterAssert(!_reloadDataLock);
    if (!delegate && !_mpDelegate) {
        return;
    }
    
    [super setDelegate:_mpDelegate = delegate];
    [self _respondsToDelegate];
}

- (id<MPTableViewDelegate>)delegate {
    return _mpDelegate;
}

- (void)setPrefetchDataSource:(id<MPTableViewDataSourcePrefetching>)prefetchDataSource {
    NSParameterAssert(!_updateSubviewsLock);
    NSParameterAssert(!_reloadDataLock);
    if (!prefetchDataSource && !_prefetchDataSource) {
        return;
    }
    
    _prefetchDataSource = prefetchDataSource;
    [self _respondsToPrefetchDataSource];
    if (_prefetchDataSource && !_prefetchIndexPaths) {
        _prefetchIndexPaths = [[NSMutableArray alloc] init];
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    [self _layoutBackgroundViewIfNeeded];
}

- (void)setContentSize:(CGSize)contentSize {
    if (!CGSizeEqualToSize(contentSize, _contentWrapperView.frame.size)) {
        _contentWrapperView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    
    [super setContentSize:contentSize];
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    NSParameterAssert(!_reloadDataLock);
    
    if (UIEdgeInsetsEqualToEdgeInsets([super contentInset], contentInset)) {
        return;
    }
    
    [super setContentInset:contentInset];
    _previousContentOffsetY = self.contentOffset.y;
    
    if (_reloadDataNeededFlag || _updateSubviewsLock) {
        return;
    }
    
    NSIndexPathStruct beginIndexPath = _beginIndexPath;
    NSIndexPathStruct endIndexPath = _endIndexPath;
    [self layoutSubviews];
    if (_NSIndexPathStructEqu(_beginIndexPath, beginIndexPath) && _NSIndexPathStructEqu(_endIndexPath, endIndexPath)) {
        _updateSubviewsLock = YES;
        if ([self _isEstimatedMode]) { // may need to create some section headers or footers
            [self _estimatedLayoutSubviewsAtFirstIndexPath:beginIndexPath];
        } else {
            if (_style == MPTableViewStylePlain) {
                [self _clipSectionViewsBetweenBeginIndexPath:beginIndexPath andEndIndexPath:endIndexPath];
            }
        }
        _updateSubviewsLock = NO;
    }
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

NS_INLINE CGRect
MPSetViewWidth(UIView *view, CGFloat width) {
    CGRect frame = view.frame;
    if (frame.size.width != width) {
        frame.size.width = width;
        view.frame = frame;
    }
    return frame;
}

- (void)setFrame:(CGRect)frame {
    CGRect selfFrame = [super frame];
    if (CGRectEqualToRect(selfFrame, frame)) {
        return;
    }
    
    [super setFrame:frame];
    [self _layoutBackgroundViewIfNeeded];
    
    if (_reloadDataNeededFlag) {
        return;
    }
    
    if (selfFrame.size.width != frame.size.width) {
        [self _setSubviewsWidth:frame.size.width];
    }
    
    if (!CGSizeEqualToSize(selfFrame.size, frame.size)) {
        [self layoutSubviews];
    }
}

- (void)setBounds:(CGRect)bounds {
    CGRect selfBounds = [super bounds];
    if (CGRectEqualToRect(selfBounds, bounds)) {
        return;
    }
    
    [super setBounds:bounds];
    [self _layoutBackgroundViewIfNeeded];
    
    if (_reloadDataNeededFlag) {
        return;
    }
    
    if (selfBounds.size.width != bounds.size.width) {
        [self _setSubviewsWidth:bounds.size.width];
    }
    
    if (!CGSizeEqualToSize(selfBounds.size, bounds.size)) {
        [self layoutSubviews];
    }
}

- (void)_setSubviewsWidth:(CGFloat)width {
    MPSetViewWidth(self.tableHeaderView, width);
    MPSetViewWidth(self.tableFooterView, width);
    
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        MPSetViewWidth(cell, width);
    }
    for (UIView *sectionView in _displayedSectionViewsDic.allValues) {
        MPSetViewWidth(sectionView, width);
    }
    
    for (MPTableViewCell *cell in _updateNewCellsDic.allValues) {
        MPSetViewWidth(cell, width);
    }
    for (UIView *sectionView in _updateNewSectionViewsDic.allValues) {
        MPSetViewWidth(sectionView, width);
    }
    
    CGSize contentSize = self.contentSize;
    contentSize.width = width;
    self.contentSize = contentSize;
}

- (NSUInteger)numberOfSections {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    return _numberOfSections;
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (section >= _sectionsArray.count) {
        return NSNotFound;
    } else {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        return sectionPosition.numberOfRows;
    }
}

- (void)setRowHeight:(CGFloat)rowHeight {
    NSParameterAssert(rowHeight >= 0);
    _rowHeight = rowHeight;
}

- (void)setSectionHeaderHeight:(CGFloat)sectionHeaderHeight {
    NSParameterAssert(sectionHeaderHeight >= 0);
    _sectionHeaderHeight = sectionHeaderHeight;
}

- (void)setSectionFooterHeight:(CGFloat)sectionFooterHeight {
    NSParameterAssert(sectionFooterHeight >= 0);
    _sectionFooterHeight = sectionFooterHeight;
}

NS_INLINE void
MPSetViewOffset(UIView *view, CGFloat offset) {
    CGRect frame = view.frame;
    frame.origin.y += offset;
    view.frame = frame;
}

- (void)_setSectionViews:(NSDictionary *)sectionViews offset:(CGFloat)offset {
    if (_style == MPTableViewStylePlain) {
        NSArray *indexPaths = _displayedSectionViewsDic.allKeys;
        for (NSIndexPath *indexPath in indexPaths) {
            MPTableViewSection *section = _sectionsArray[indexPath.section];
            MPTableReusableView *sectionView = [sectionViews objectForKey:indexPath];
            MPSectionViewType type = indexPath.row;
            
            if ([self _needToSuspendViewInSection:section withType:type]) {
                [self _setSuspendingSection:indexPath.section withType:type];
                sectionView.frame = [self _suspendingFrameInSection:section withType:type];
            } else if ([self _needToPrepareToSuspendViewInSection:section withType:type]) {
                sectionView.frame = [self _prepareToSuspendFrameInSection:section withType:type];
            } else {
                MPSetViewOffset(sectionView, offset);
            }
        }
    } else {
        for (UIView *sectionView in sectionViews.allValues) {
            MPSetViewOffset(sectionView, offset);
        }
    }
}

- (void)_setSubviewsOffset:(CGFloat)offset {
    if (_style == MPTableViewStylePlain) {
        [self _setContentOffsetPositions];
    }
    
    if (self.tableFooterView) {
        MPSetViewOffset(self.tableFooterView, offset);
    }
    
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        MPSetViewOffset(cell, offset);
    }
    [self _setSectionViews:_displayedSectionViewsDic offset:offset];
    
    for (MPTableViewCell *cell in _updateNewCellsDic.allValues) {
        MPSetViewOffset(cell, offset);
    }
    [self _setSectionViews:_updateNewSectionViewsDic offset:offset];
}

- (void)setTableHeaderView:(UIView *)tableHeaderView {
    NSParameterAssert(tableHeaderView != self.tableFooterView || !self.tableFooterView);
    NSParameterAssert(tableHeaderView != self.backgroundView || !self.backgroundView);
    if (_tableHeaderView == tableHeaderView && [_tableHeaderView superview] == self) {
        return;
    }
    
    if ([_tableHeaderView superview] == self) {
        [_tableHeaderView removeFromSuperview];
    }
    _tableHeaderView = tableHeaderView;
    
    CGRect frame;
    if (_tableHeaderView) {
        frame = _tableHeaderView.frame;
        frame.origin = CGPointZero;
        frame.size.width = self.bounds.size.width;
        MPSetViewFrameWithoutAnimation(_tableHeaderView, frame);
        [self insertSubview:_tableHeaderView aboveSubview:_contentWrapperView];
    } else {
        frame = CGRectZero;
    }
    
    if (_contentListPosition.startPos == frame.size.height) {
        return;
    }
    
    CGFloat offset = frame.size.height - _contentListPosition.startPos;
    _contentListPosition.startPos += offset;
    _contentListPosition.endPos += offset;
    
    [self setContentSize:CGSizeMake(self.bounds.size.width, _contentListPosition.endPos + self.tableFooterView.bounds.size.height)];
    if (_reloadDataNeededFlag) {
        return;
    }
    [self _setSubviewsOffset:offset];
    
    if (_updateSubviewsLock) {
        return;
    }
    [self _layoutSubviewsInternal];
}

- (void)setTableFooterView:(UIView *)tableFooterView {
    NSParameterAssert(tableFooterView != self.tableHeaderView || !self.tableHeaderView);
    NSParameterAssert(tableFooterView != self.backgroundView || !self.backgroundView);
    if (_tableFooterView == tableFooterView && [_tableFooterView superview] == self) {
        return;
    }
    
    if ([_tableFooterView superview] == self) {
        [_tableFooterView removeFromSuperview];
    }
    _tableFooterView = tableFooterView;
    
    CGRect frame;
    if (_tableFooterView) {
        frame = _tableFooterView.frame;
        frame.origin = CGPointMake(0, _contentListPosition.endPos);
        frame.size.width = self.bounds.size.width;
        MPSetViewFrameWithoutAnimation(_tableFooterView, frame);
        [self insertSubview:_tableFooterView aboveSubview:_contentWrapperView];
    } else {
        frame = CGRectZero;
    }
    
    CGPoint contentOffset = self.contentOffset;
    [self setContentSize:CGSizeMake(self.bounds.size.width, _contentListPosition.endPos + frame.size.height)];
    if (CGPointEqualToPoint(contentOffset, self.contentOffset) || _reloadDataNeededFlag || _updateSubviewsLock) {
        return;
    }
    [self _layoutSubviewsInternal];
}

- (void)setBackgroundView:(UIView *)backgroundView {
    NSParameterAssert(backgroundView != self.tableHeaderView || !self.tableHeaderView);
    NSParameterAssert(backgroundView != self.tableFooterView || !self.tableFooterView);
    if (_backgroundView == backgroundView) {
        return;
    }
    
    [_backgroundView removeFromSuperview];
    _backgroundView = backgroundView;
    
    [self _layoutBackgroundViewIfNeeded];
}

static void
MPSetViewFrameWithoutAnimation(UIView *view, CGRect frame) {
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

- (void)_layoutBackgroundViewIfNeeded {
    if (!_backgroundView) {
        return;
    }
    
    CGRect frame = self.bounds;
    frame.origin.y = self.contentOffset.y;
    MPSetViewFrameWithoutAnimation(_backgroundView, frame);
    
    if ([_backgroundView superview] != self) {
        [self insertSubview:_backgroundView belowSubview:_contentWrapperView];
    }
}

- (MPTableReusableView *)sectionHeaderInSection:(NSUInteger)section {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    return [_displayedSectionViewsDic objectForKey:_NSIndexPathPrivateForRowSection(MPSectionHeader, section)];
}

- (MPTableReusableView *)sectionFooterInSection:(NSUInteger)section {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    return [_displayedSectionViewsDic objectForKey:_NSIndexPathPrivateForRowSection(MPSectionFooter, section)];
}

- (MPTableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return nil;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    return cell;
}

- (NSIndexPath *)indexPathForCell:(MPTableViewCell *)cell {
    if (!cell) {
        return nil;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
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
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    return _displayedCellsDic.allValues;
}

- (NSArray *)indexPathsForVisibleRows {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    return _displayedCellsDic.allKeys;
}

- (NSArray *)visibleCellsInRect:(CGRect)rect {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
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

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    if (rect.origin.x > self.bounds.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _contentListPosition.endPos || CGRectGetMaxY(rect) < _contentListPosition.startPos || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    
    CGFloat offsetY = rect.origin.y;
    if (offsetY < _contentListPosition.startPos) {
        offsetY = _contentListPosition.startPos;
    }
    NSIndexPath *beginIndexPath = _NSIndexPathFromStruct([self _indexPathAtContentOffsetY:offsetY - _contentListPosition.startPos]);
    offsetY = CGRectGetMaxY(rect);
    if (offsetY > _contentListPosition.endPos) {
        offsetY = _contentListPosition.endPos;
    }
    NSIndexPath *endIndexPath = _NSIndexPathFromStruct([self _indexPathAtContentOffsetY:offsetY - _contentListPosition.startPos]);
    
    for (NSInteger i = beginIndexPath.section; i <= endIndexPath.section; i++) {
        NSUInteger numberOfRows = [self numberOfRowsInSection:i];
        if (i == beginIndexPath.section) {
            NSInteger j = MPTV_IS_HEADER(beginIndexPath.row) ? 0 : beginIndexPath.row;
            if (beginIndexPath.section == endIndexPath.section) {
                if (MPTV_IS_HEADER(endIndexPath.row)) {
                    break;
                } else if (endIndexPath.row < MPSectionFooter) {
                    numberOfRows = endIndexPath.row + 1;
                }
                for (; j < numberOfRows; j++) {
                    [indexPaths addObject:_NSIndexPathPrivateForRowSection(j, i)];
                }
            } else {
                for (; j < numberOfRows; j++) {
                    [indexPaths addObject:_NSIndexPathPrivateForRowSection(j, i)];
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
                [indexPaths addObject:_NSIndexPathPrivateForRowSection(j, i)];
            }
        }
    }
    
    return indexPaths;
}

- (NSArray *)indexPathsForRowsInSection:(NSUInteger)section {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    if (section >= _sectionsArray.count) {
        return nil;
    }
    
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    if (sectionPosition.numberOfRows == 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < sectionPosition.numberOfRows; i++) {
        [indexPaths addObject:_NSIndexPathPrivateForRowSection(i, section)];
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
    NSParameterAssert(count && count <= array.count);
    if (array.count) {
        NSRange subRange = NSMakeRange(array.count - count, count);
        NSArray *sub = [array subarrayWithRange:subRange];
        [sub makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [array removeObjectsInRange:subRange];
    }
}

- (void)clearReusableViewsInCount:(NSUInteger)count withIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    NSMutableArray *array = [_reusableReusableViewsDic objectForKey:identifier];
    NSParameterAssert(count && count <= array.count);
    if (array.count) {
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
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    NSIndexPathStruct beginIndexPath = _beginIndexPath;
    if (MPTV_IS_HEADER(beginIndexPath.row) || MPTV_IS_FOOTER(beginIndexPath.row)) {
        beginIndexPath.row = NSNotFound;
    }
    return _NSIndexPathFromStruct(beginIndexPath);
}

- (NSIndexPath *)endIndexPath {
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    NSIndexPathStruct endIndexPath = _endIndexPath;
    if (MPTV_IS_HEADER(endIndexPath.row) || MPTV_IS_FOOTER(endIndexPath.row)) {
        endIndexPath.row = NSNotFound;
    }
    return _NSIndexPathFromStruct(endIndexPath);
}

- (CGRect)rectForSection:(NSUInteger)section {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (section >= _sectionsArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    frame.origin = CGPointMake(0, _contentListPosition.startPos + sectionPosition.startPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.endPos - sectionPosition.startPos);
    return frame;
}

- (CGRect)rectForHeaderInSection:(NSUInteger)section {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (section >= _sectionsArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    frame.origin = CGPointMake(0, _contentListPosition.startPos + sectionPosition.startPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.headerHeight);
    return frame;
}

- (CGRect)rectForFooterInSection:(NSUInteger)section {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (section >= _sectionsArray.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    frame.origin = CGPointMake(0, _contentListPosition.startPos + sectionPosition.startPos);
    frame.size = CGSizeMake(self.bounds.size.width, sectionPosition.footerHeight);
    return frame;
}

- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (indexPath.section >= _sectionsArray.count) {
        return CGRectNull;
    }
    
    MPTableViewSection *section = _sectionsArray[indexPath.section];
    if (indexPath.row >= section.numberOfRows) {
        return CGRectNull;
    }
    
    return [self _cellFrameAtIndexPath:indexPath];
}

- (NSUInteger)indexForSectionAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (point.y < _contentListPosition.startPos || point.y > _contentListPosition.endPos) {
        return NSNotFound;
    } else {
        return [self _sectionAtContentOffsetY:point.y - _contentListPosition.startPos];
    }
}

- (NSUInteger)indexForSectionHeaderAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    NSUInteger section = [self indexForSectionAtPoint:point];
    if (section != NSNotFound) {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        if (!sectionPosition.headerHeight || sectionPosition.startPos + sectionPosition.headerHeight < point.y - _contentListPosition.startPos) {
            section = NSNotFound;
        }
    }
    
    return section;
}

- (NSUInteger)indexForSectionFooterAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    NSUInteger section = [self indexForSectionAtPoint:point];
    if (section != NSNotFound) {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        if (!sectionPosition.footerHeight || sectionPosition.endPos - sectionPosition.footerHeight > point.y - _contentListPosition.startPos) {
            section = NSNotFound;
        }
    }
    
    return section;
}

- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point {
    if (_reloadDataNeededFlag) {
        [self reloadData];
    }
    
    if (point.y < _contentListPosition.startPos || point.y > _contentListPosition.endPos) {
        return nil;
    }
    
    CGFloat offsetY = point.y;
    if (offsetY < _contentListPosition.startPos) {
        offsetY = _contentListPosition.startPos;
    } else if (offsetY > _contentListPosition.endPos) {
        offsetY = _contentListPosition.endPos;
    }
    NSIndexPath *indexPath = _NSIndexPathFromStruct([self _indexPathAtContentOffsetY:offsetY - _contentListPosition.startPos]);
    if (MPTV_IS_HEADER(indexPath.row) || MPTV_IS_FOOTER(indexPath.row)) {
        return nil;
    } else {
        return indexPath;
    }
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (_reloadDataLock) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    NSAssert(indexPath.section < _sectionsArray.count, @"can't scroll to a non-existent section");
    
    MPTableViewSection *section = _sectionsArray[indexPath.section];
    NSAssert(indexPath.row < section.numberOfRows, @"row to scroll is overflowed");
    
    CGFloat contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            contentOffsetY = [section positionStartAtRow:indexPath.row] - [self _innerContentInset].top;
            if (_respond_viewForHeaderInSection && _style == MPTableViewStylePlain) {
                contentOffsetY -= section.headerHeight;
            }
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat startPos = [section positionStartAtRow:indexPath.row];
            CGFloat endPos = [section positionEndAtRow:indexPath.row];
            contentOffsetY = startPos + (endPos - startPos) / 2 - self.bounds.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            contentOffsetY = [section positionEndAtRow:indexPath.row] - self.bounds.size.height + [self _innerContentInset].bottom;
            if (_respond_viewForFooterInSection && _style == MPTableViewStylePlain) {
                contentOffsetY += section.footerHeight;
            }
        }
            break;
        default:
            return;
    }
    
    [self _setUsableContentOffsetY:contentOffsetY animated:animated];
}

- (void)_setUsableContentOffsetY:(CGFloat)contentOffsetY animated:(BOOL)animated {
    contentOffsetY += _contentListPosition.startPos;
    
    if (contentOffsetY + self.bounds.size.height > self.contentSize.height + [self _innerContentInset].bottom) {
        contentOffsetY = self.contentSize.height + [self _innerContentInset].bottom - self.bounds.size.height;
    }
    if (contentOffsetY < -[self _innerContentInset].top) {
        contentOffsetY = -[self _innerContentInset].top;
    }
    
    [self setContentOffset:CGPointMake(0, contentOffsetY) animated:animated];
}

- (void)scrollToHeaderInSection:(NSUInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (_reloadDataLock) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
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
    
    [self _setUsableContentOffsetY:contentOffsetY animated:animated];
}

- (void)scrollToFooterInSection:(NSUInteger)section atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (_reloadDataLock) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
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
    
    [self _setUsableContentOffsetY:contentOffsetY animated:animated];
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection {
    if (_updateSubviewsLock) {
        return;
    }
    
    if (_allowsMultipleSelection == allowsMultipleSelection) {
        return;
    }
    
    _updateSubviewsLock = YES;
    
    if (!allowsMultipleSelection) {
        for (NSIndexPath *indexPath in _selectedIndexPaths) {
            [self _deselectRowAtIndexPath:indexPath animated:NO selectedIndexPathRemoved:NO];
        }
        [_selectedIndexPaths removeAllObjects];
    } else {
        _allowsSelection = YES;
    }
    
    _allowsMultipleSelection = allowsMultipleSelection;
    _updateSubviewsLock = NO;
}

- (NSIndexPath *)indexPathForSelectedRow {
    return [_selectedIndexPaths anyObject];
}

- (NSArray *)indexPathsForSelectedRows {
    return [_selectedIndexPaths allObjects];
}

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition {
    if (_reloadDataLock || _updateSubviewsLock) {
        return;
    }
    
    if (_reloadDataLayoutNeededFlag) {
        [self layoutSubviews];
    }
    
    _updateSubviewsLock = YES;
    if (_respond_willSelectRowAtIndexPath) {
        indexPath = [_mpDelegate MPTableView:self willSelectRowAtIndexPath:indexPath];
        if (!indexPath) {
            return;
        }
    }
    
    if (indexPath.section >= _numberOfSections) {
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
    
    if (!_allowsMultipleSelection) {
        for (NSIndexPath *indexPath in _selectedIndexPaths.allObjects) {
            [self _deselectRowAtIndexPath:indexPath animated:NO selectedIndexPathRemoved:YES];
        }
    }
    
    [_selectedIndexPaths addObject:indexPath];
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    if (cell) {
        [cell setSelected:YES animated:animated];
    }
    [self scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
    
    if (_respond_didSelectRowForCellAtIndexPath) {
        [_mpDelegate MPTableView:self didSelectRowForCell:cell atIndexPath:indexPath];
    }
    
    _updateSubviewsLock = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (_reloadDataLock) {
        return;
    }
    
    if (scrollPosition == MPTableViewScrollPositionNone || !_selectedIndexPaths.count) {
        return;
    }
    
    NSIndexPath *nearestSelectedIndexPath = _NSIndexPathPrivateForRowSection(NSIntegerMax, NSIntegerMax);
    for (NSIndexPath *indexPath in _selectedIndexPaths) {
        if ([indexPath compare:nearestSelectedIndexPath] == NSOrderedAscending) {
            nearestSelectedIndexPath = indexPath;
        }
    }
    if (nearestSelectedIndexPath.section < NSIntegerMax && nearestSelectedIndexPath.row < NSIntegerMax) {
        [self scrollToRowAtIndexPath:nearestSelectedIndexPath atScrollPosition:scrollPosition animated:animated];
    }
}

- (void)_deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated selectedIndexPathRemoved:(BOOL)removed {
    if (!indexPath) {
        return;
    }
    
    MPTableViewCell *selectedCell = [_displayedCellsDic objectForKey:indexPath];
    if (removed) {
        if (_respond_willDeselectRowAtIndexPath) {
            NSIndexPath *newIndexPath = [_mpDelegate MPTableView:self willDeselectRowAtIndexPath:indexPath];
            if (!newIndexPath) {
                return;
            }
            if (![newIndexPath isEqual:indexPath]) {
                selectedCell = [_displayedCellsDic objectForKey:indexPath = newIndexPath];
            }
        }
        
        [_selectedIndexPaths removeObject:indexPath];
    }
    if (selectedCell) {
        [selectedCell setSelected:NO animated:animated];
    }
    
    if (_respond_didDeselectRowAtIndexPath) {
        [_mpDelegate MPTableView:self didDeselectRowAtIndexPath:indexPath];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    if (_reloadDataLock || _updateSubviewsLock) {
        return;
    }
    
    if (![_selectedIndexPaths containsObject:indexPath]) {
        return;
    }
    
    _updateSubviewsLock = YES;
    [self _deselectRowAtIndexPath:indexPath animated:animated selectedIndexPathRemoved:YES];
    _updateSubviewsLock = NO;
}

- (BOOL)isUpdating {
    return _updateAnimationStep != 0;
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(!_updateSubviewsLock);
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= _numberOfSections) {
            MPTV_UPDATE_EXCEPTION(@"delete section is overflowed")
        }
        if (![updateManager addDeleteSection:idx withAnimation:animation]) {
            MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
        }
    }];
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    }
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(!_updateSubviewsLock);
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    NSUInteger numberOfSections;
    if (_respond_numberOfSectionsInMPTableView) {
        _updateSubviewsLock = YES;
        numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
        _updateSubviewsLock = NO;
    } else {
        numberOfSections = _numberOfSections;
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= numberOfSections) {
            MPTV_UPDATE_EXCEPTION(@"insert section is overflowed")
        }
        if (![updateManager addInsertSection:idx withAnimation:animation]) {
            MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
        }
    }];
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    }
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(!_updateSubviewsLock);
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx >= _numberOfSections) {
            MPTV_UPDATE_EXCEPTION(@"reload section is overflowed")
        }
        if (![updateManager addReloadSection:idx withAnimation:animation]) {
            MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
        }
    }];
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    }
}

- (void)moveSection:(NSUInteger)section toSection:(NSUInteger)newSection {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(!_updateSubviewsLock);
    
    if (section == newSection) {
        MPTV_UPDATE_EXCEPTION(@"move section can not be equal to the new section")
    }
    if (section >= _numberOfSections) {
        MPTV_UPDATE_EXCEPTION(@"move section is overflowed")
    }
    
    NSUInteger numberOfSections;
    if (_respond_numberOfSectionsInMPTableView) {
        _updateSubviewsLock = YES;
        numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
        _updateSubviewsLock = NO;
    } else {
        numberOfSections = _numberOfSections;
    }
    
    if (newSection >= numberOfSections) {
        MPTV_UPDATE_EXCEPTION(@"new section to move is overflowed")
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (![updateManager addMoveOutSection:section]) {
        MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
    }
    
    if (![updateManager addMoveInSection:newSection withLastSection:section]) {
        MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
    }
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(!_updateSubviewsLock);
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section >= _numberOfSections) {
            MPTV_UPDATE_EXCEPTION(@"delete section is overflowed")
        }
        if (indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
            MPTV_UPDATE_EXCEPTION(@"delete row is overflowed")
        }
        
        if (![updateManager addDeleteIndexPath:indexPath withAnimation:animation]) {
            MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
        }
    }
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(!_updateSubviewsLock);
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    NSUInteger numberOfSections;
    if (_respond_numberOfSectionsInMPTableView) {
        _updateSubviewsLock = YES;
        numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
        _updateSubviewsLock = NO;
    } else {
        numberOfSections = _numberOfSections;
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section >= numberOfSections) {
            MPTV_UPDATE_EXCEPTION(@"insert section is overflowed")
        }
        if (![updateManager addInsertIndexPath:indexPath withAnimation:animation]) {
            MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
        }
    }
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(!_updateSubviewsLock);
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.section >= _numberOfSections) {
            MPTV_UPDATE_EXCEPTION(@"reload section is overflowed")
        }
        if (indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
            MPTV_UPDATE_EXCEPTION(@"reload row is overflowed")
        }
        
        if (![updateManager addReloadIndexPath:indexPath withAnimation:animation]) {
            MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
        }
    }
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    }
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    NSParameterAssert(!_updateSubviewsLock);
    
    if ([indexPath compare:newIndexPath] == NSOrderedSame) {
        MPTV_UPDATE_EXCEPTION(@"move indexPath can not be equal to the new indexPath")
    }
    
    if (indexPath.section >= _numberOfSections) {
        MPTV_UPDATE_EXCEPTION(@"move section is overflowed")
    }
    if (indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
        MPTV_UPDATE_EXCEPTION(@"move row is overflowed")
    }
    
    NSUInteger numberOfSections;
    if (_respond_numberOfSectionsInMPTableView) {
        _updateSubviewsLock = YES;
        numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
        _updateSubviewsLock = NO;
    } else {
        numberOfSections = _numberOfSections;
    }
    
    if (newIndexPath.section >= numberOfSections) {
        MPTV_UPDATE_EXCEPTION(@"new indexPath to move is overflowed")
    }
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    if (![updateManager addMoveOutIndexPath:indexPath]) {
        MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
    }
    
    if (![updateManager addMoveInIndexPath:newIndexPath withFrame:[self _cellFrameAtIndexPath:indexPath] withLastIndexPath:indexPath]) {
        MPTV_UPDATE_EXCEPTION(@"check duplicate update indexPaths")
    }
    
    if (_updateContextStep == 0) {
        [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
    }
}

- (BOOL)isUpdateForceReload {
    return _updateForceReload;
}

- (BOOL)isUpdateOptimizeViews {
    return _updateOptimizeViews;
}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
    [self performBatchUpdates:updates duration:MPTableViewDefaultAnimationDuration delay:0 completion:completion];
}

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(void (^)(BOOL))completion {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    
    if (_updateSubviewsLock || _draggedIndexPath) {
        return;
    }
    
    if (_reloadDataNeededFlag) {
        [self layoutSubviews];
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
    
    [self _startUpdateAnimationWithUpdateManager:updateManager duration:duration delay:delay completion:completion];
    [self _popUpdateManagerForStack];
    _updateContextStep--;
}

- (void)performBatchUpdates:(void (^)(void))updates duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options completion:(void (^)(BOOL))completion {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(![self _hasDragCell]);
    NSParameterAssert(!_reloadDataLock);
    
    if (_updateSubviewsLock || _draggedIndexPath) {
        return;
    }
    
    if (_reloadDataNeededFlag) {
        [self layoutSubviews];
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
    
    [self _startUpdateAnimationWithUpdateManager:updateManager duration:duration delay:delay options:options usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity completion:completion];
    [self _popUpdateManagerForStack];
    _updateContextStep--;
}

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    
    MPTableViewCell *reusableCell;
    NSMutableArray *queue = [_reusableCellsDic objectForKey:identifier];
    if (queue.count) {
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
    if (queue.count) {
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
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count);
    
    if (!_registerCellNibsDic) {
        _registerCellNibsDic = [[NSMutableDictionary alloc] init];
    }
    [_registerCellNibsDic setObject:nib forKey:identifier];
}

- (void)registerNib:(UINib *)nib forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count);
    
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
        
        _updateAnimatedOffscreenIndexPaths = [[NSMutableSet alloc] init];
        _updateAnimatedNewOffscreenIndexPaths = [[NSMutableSet alloc] init];
        
        _updateExchangedSelectedIndexPaths = [[NSMutableSet alloc] init];
        
        _updateExecutionActions = [[NSMutableArray alloc] init];
    }
    
    MPTableViewUpdateManager *updateManager = [MPTableViewUpdateManager managerForTableView:self andSections:_sectionsArray];
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

- (NSMutableArray *)_updateExecutionActions {
    return _updateExecutionActions;
}

- (MPTableViewEstimatedManager *)_estimatedManager {
    if (!_estimatedManager) {
        _estimatedManager = [[MPTableViewEstimatedManager alloc] init];
        _estimatedCellsDic = [[NSMutableDictionary alloc] init];
        _estimatedSectionViewsDic = [[NSMutableDictionary alloc] init];
    }
    
    return _estimatedManager;
}

- (NSIndexPathStruct)_beginIndexPath { // include section header or footer
    return _beginIndexPath;
}

- (NSIndexPathStruct)_endIndexPath {
    return _endIndexPath;
}

- (CGFloat)_updateLastDeletionOriginY {
    return _updateLastDeletionOriginY;
}

- (void)_setUpdateLastDeletionOriginY:(CGFloat)updateLastDeletionOriginY {
    _updateLastDeletionOriginY = updateLastDeletionOriginY;
}

- (CGFloat)_updateLastInsertionOriginY {
    return _updateLastInsertionOriginY;
}

- (void)_setUpdateLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY {
    _updateLastInsertionOriginY = updateLastInsertionOriginY;
}

- (void)_startUpdateAnimationWithUpdateManager:(MPTableViewUpdateManager *)updateManager duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay completion:(void (^)(BOOL finished))completion {
    [self _startUpdateAnimationWithUpdateManager:updateManager duration:duration delay:delay options:UIViewAnimationOptionCurveEaseInOut usingSpringWithDamping:MPTV_MAXSIZE initialSpringVelocity:MPTV_MAXSIZE completion:completion];
}

- (void)_startUpdateAnimationWithUpdateManager:(MPTableViewUpdateManager *)updateManager duration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity completion:(void (^)(BOOL finished))completion {
    if (_reloadDataLayoutNeededFlag || _reloadDataNeededFlag) {
        [self _layoutSubviewsInternal];
    }
    
    _updateSubviewsLock = YES; // when _updateSubviewsLock is YES, unable to start a new update transaction.
    _updateAnimationStep++;
    
    if (![self _hasDragCell]) {
        if (_respond_numberOfSectionsInMPTableView) {
            NSUInteger numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
            if ([updateManager hasUpdateNodes]) {
                NSAssert(numberOfSections <= MPTV_MAXCOUNT, @"the number of sections is too many");
                _numberOfSections = numberOfSections;
            } else if (numberOfSections != _numberOfSections) {
                MPTV_UPDATE_EXCEPTION(@"check the number of sections from data source")
            }
        }
        updateManager.newCount = _numberOfSections;
    }
    
    if (![updateManager prepareAndIgnoreCheck:[self _hasDragCell]]) {
        MPTV_UPDATE_EXCEPTION(@"check the number of sections after insert or delete")
    }
    
    _updateLastInsertionOriginY = _updateLastDeletionOriginY = 0;
    _suspendingHeaderSection = _suspendingFooterSection = NSNotFound;
    CGFloat offset = [updateManager startUpdate];
    [updateManager reset];
    
    if (_numberOfSections) {
        _contentListPosition.endPos += offset;
    } else {
        _contentListPosition.endPos = _contentListPosition.startPos;
    }
    
    if (_contentListPosition.startPos >= _contentListPosition.endPos) {
        _beginIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
        _endIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
    } else {
        _beginIndexPath = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.startPos];
        _endIndexPath = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.endPos];
        
        UIEdgeInsets contentInset = [self _innerContentInset];
        if (_contentOffsetPosition.startPos > -contentInset.top && (self.contentSize.height + contentInset.bottom + offset < _contentOffsetPosition.endPos)) { // when scrolling to the bottom, the contentOffset needs to be changed.
            _updateContentOffsetChanged = YES;
            
            _contentOffsetPosition.endPos = self.contentSize.height + contentInset.bottom + offset;
            _contentOffsetPosition.startPos = _contentOffsetPosition.endPos - self.bounds.size.height;
            
            if (_contentOffsetPosition.startPos < -contentInset.top) {
                _contentOffsetPosition.startPos = -contentInset.top;
                _contentOffsetPosition.endPos = _contentOffsetPosition.startPos + self.bounds.size.height;
            }
            
            _contentListOffsetPosition.startPos = _contentOffsetPosition.startPos - _contentListPosition.startPos;
            _contentListOffsetPosition.endPos = _contentOffsetPosition.endPos - _contentListPosition.startPos;
        } else {
            if (_draggedIndexPath) {
                if (_NSIndexPathCompareStruct(_draggedIndexPath, _beginIndexPath) == NSOrderedAscending) {
                    _beginIndexPath = _NSIndexPathGetStruct(_draggedIndexPath);
                }
                if (_NSIndexPathCompareStruct(_draggedIndexPath, _endIndexPath) == NSOrderedDescending) {
                    _endIndexPath = _NSIndexPathGetStruct(_draggedIndexPath);
                }
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
    
    if (!_draggedIndexPath) {
        [_updateAnimatedOffscreenIndexPaths setSet:_updateAnimatedNewOffscreenIndexPaths];
        [_updateAnimatedNewOffscreenIndexPaths removeAllObjects];
    }
    
    [_selectedIndexPaths unionSet:_updateExchangedSelectedIndexPaths];
    [_updateExchangedSelectedIndexPaths removeAllObjects];
    
    if (_estimatedCellsDic.count) {
        for (MPTableViewCell *cell in _estimatedCellsDic.allValues) {
            [self _cacheCell:cell];
        }
        [_estimatedCellsDic removeAllObjects];
    }
    
    if (_estimatedSectionViewsDic.count) {
        for (MPTableReusableView *view in _estimatedSectionViewsDic.allValues) {
            [self _cacheSectionView:view];
        }
        [_estimatedSectionViewsDic removeAllObjects];
    }
    
    if (_updateContentOffsetChanged) {
        NSIndexPathStruct newBeginIndexPath = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.startPos];
        NSIndexPathStruct newEndIndexPath = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.endPos];
        
        if ([self _isEstimatedMode]) {
            CGFloat newOffset = [[self _estimatedManager] startEstimateForTableView:self atFirstIndexPath:newBeginIndexPath andSections:_sectionsArray];
            if (newOffset != 0) {
                MPTV_EXCEPTION(@"A critical bug, please contact the author");
            }
            _beginIndexPath = newBeginIndexPath;
            _endIndexPath = newEndIndexPath;
        } else {
            if (_style == MPTableViewStylePlain) {
                if (_suspendingHeaderSection == NSNotFound) {
                    [self _suspendSectionHeaderIfNeededInSection:newBeginIndexPath.section];
                }
                // no need the footer
            }
            [self _layoutSubviewsBetweenBeginIndexPath:newBeginIndexPath andEndIndexPath:newEndIndexPath];
        }
    }
    [self _prefetchIndexPathsIfNeeded];
    
    CGSize contentSize = CGSizeMake(self.bounds.size.width, _contentListPosition.endPos + self.tableFooterView.bounds.size.height);
    if (!CGSizeEqualToSize(contentSize, _contentWrapperView.frame.size)) {
        _contentWrapperView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    
    _updateContentOffsetChanged = NO;
    _updateSubviewsLock = NO;
    
    NSArray *updateAnimationBlocks = _updateAnimationBlocks;
    _updateAnimationBlocks = [[NSMutableArray alloc] init];
    
    NSDictionary *deleteCellsDic = nil;
    if (_updateDeletedCellsDic.count) {
        deleteCellsDic = [NSDictionary dictionaryWithDictionary:_updateDeletedCellsDic];
        [_updateDeletedCellsDic removeAllObjects];
    }
    NSDictionary *deleteSectionViewsDic = nil;
    if (_updateDeletedSectionViewsDic.count) {
        deleteSectionViewsDic = [NSDictionary dictionaryWithDictionary:_updateDeletedSectionViewsDic];
        [_updateDeletedSectionViewsDic removeAllObjects];
    }
    
    void (^animations)(void) = ^{
        MPSetViewOffset(self.tableFooterView, offset);
        
        for (void (^animationBlock)(void) in updateAnimationBlocks) {
            animationBlock();
        }
        
        [super setContentSize:contentSize];
    };
    
    void (^animationCompletion)(BOOL finished) = ^(BOOL finished) {
        [self _updateAnimationCompletionWithDeleteCells:deleteCellsDic andDeleteSectionViews:deleteSectionViewsDic];
        if (completion) {
            completion(finished);
        }
    };
    
    if (self.updateLayoutSubviewsOptionEnabled) {
        options |= UIViewAnimationOptionLayoutSubviews;
    }
    
    if (self.updateAllowUserInteraction) {
        options |= UIViewAnimationOptionAllowUserInteraction;
    }
    
    if (dampingRatio == MPTV_MAXSIZE) {
        [UIView animateWithDuration:duration delay:delay options:options animations:animations completion:animationCompletion];
    } else {
        [UIView animateWithDuration:duration delay:delay usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity options:options animations:animations completion:animationCompletion];
    }
}

- (void)_updateAnimationCompletionWithDeleteCells:(NSDictionary *)deleteCellsDic andDeleteSectionViews:(NSDictionary *)deleteSectionViewsDic {
    _updateSubviewsLock = YES;
    _updateAnimationStep--;
    
    if (_respond_didEndDisplayingCellForRowAtIndexPath) {
        for (NSIndexPath *indexPath in deleteCellsDic.allKeys) {
            MPTableViewCell *cell = [deleteCellsDic objectForKey:indexPath];
            [cell removeFromSuperview];
            
            [_mpDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
        }
    } else {
        [deleteCellsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    if (_respond_didEndDisplayingHeaderViewForSection || _respond_didEndDisplayingFooterViewForSection) {
        for (NSIndexPath *indexPath in deleteSectionViewsDic.allKeys) {
            MPTableReusableView *sectionView = [deleteSectionViewsDic objectForKey:indexPath];
            [sectionView removeFromSuperview];
            
            if (MPTV_IS_HEADER(indexPath.row) && _respond_didEndDisplayingHeaderViewForSection) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
            }
            if (MPTV_IS_FOOTER(indexPath.row) && _respond_didEndDisplayingFooterViewForSection) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
            }
        }
    } else {
        [deleteSectionViewsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    if (_updateAnimationStep == 0) {
        if (!_draggedIndexPath) {
            [_updateAnimatedOffscreenIndexPaths removeAllObjects];
        }
        
        [self _setContentOffsetPositions];
        if (_contentListPosition.startPos >= _contentListPosition.endPos) {
            _beginIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
            _endIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
        } else {
            _beginIndexPath = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.startPos];
            _endIndexPath = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.endPos];
        }
        
        [self _clipCellsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
        [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    }
    
    _updateSubviewsLock = NO;
}

- (BOOL)_updateNeedToDisplayFromPositionStart:(CGFloat)start toEnd:(CGFloat)end withOffset:(CGFloat)offset {
    if (start == 0 && end == 0) {
        return NO;
    }
    
    if (_updateOptimizeViews || _draggedIndexPath) {
        return start <= _contentOffsetPosition.endPos && end >= _contentOffsetPosition.startPos;
    }
    
    if (offset > 0) {
        CGFloat newStart = start - offset;
        return newStart <= _contentOffsetPosition.endPos && end >= _contentOffsetPosition.startPos;
    } else if (offset < 0) {
        CGFloat newEnd = end - offset;
        return start <= _contentOffsetPosition.endPos && newEnd >= _contentOffsetPosition.startPos;
    } else {
        return start <= _contentOffsetPosition.endPos && end >= _contentOffsetPosition.startPos;
    }
}

- (BOOL)_updateNeedToDisplaySection:(MPTableViewSection *)section withUpdateType:(MPTableViewUpdateType)type withOffset:(CGFloat)offset {
    if (MPTableViewUpdateTypeStable(type)) { // offset should be 0 if this is an insertion
        if ([self _updateNeedToDisplayFromPositionStart:section.startPos + _contentListPosition.startPos toEnd:section.endPos + _contentListPosition.startPos withOffset:offset]) {
            return YES;
        } else {
            return NO;
        }
    } else if (MPTableViewUpdateTypeUnstable(type)) { // reload is split into a deletion and an insertion
        if ([self _hasDisplayedSection:section]) {
            return YES;
        } else {
            return [self _updateNeedToAdjustCellsFromLastSection:section.section];
        }
    } else { // adjust
        if (_updateForceReload && !_draggedIndexPath) {
            return YES;
        }
        
        if (section.updatePart) {
            return [self _updateNecessaryToAdjustSection:section withOffset:offset];
        } else {
            if ([self _hasDisplayedSection:section] || [self _updateNeedToDisplayFromPositionStart:section.startPos + offset + _contentListPosition.startPos toEnd:section.endPos + offset + _contentListPosition.startPos withOffset:offset]) {
                return YES;
            } else {
                return NO;
            }
        }
    }
}

- (BOOL)_updateNeedToAdjustCellsFromLastSection:(NSInteger)lastSection {
    for (NSIndexPath *indexPath in _selectedIndexPaths) {
        if (indexPath.section == lastSection) {
            return YES;
        }
    }
    
    for (NSIndexPath *indexPath in _updateAnimatedOffscreenIndexPaths) {
        if (indexPath.section == lastSection) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)_updateNecessaryToAdjustSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    return section.section <= _endIndexPath.section || section.startPos + offset <= _contentListOffsetPosition.endPos;
}

- (void)_updateAnimationBlocksSetFrame:(CGRect)frame forSubview:(UIView *)subview {
    if (CGRectEqualToRect(subview.frame, frame)) {
        return;
    }
    
    void (^animationBlock)(void) = ^{
        subview.frame = frame;
    };
    [_updateAnimationBlocks addObject:animationBlock];
}

static CGFloat
MPLayoutSizeForSubview(UIView *view, CGFloat width) {
    [UIView performWithoutAnimation:^{
        CGRect frame = MPSetViewWidth(view, width);
        [view layoutIfNeeded];
        frame.size.height = [view systemLayoutSizeFittingSize:CGSizeMake(width, 0)].height;
        view.frame = frame;
    }];
    
    return view.bounds.size.height;
}

#pragma mark - cell update

- (CGFloat)_updateGetInsertCellHeightAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat cellHeight;
    if (_respond_estimatedHeightForRowAtIndexPath) { // verified
        MPTableViewSection *section = _sectionsArray[indexPath.section];
        CGFloat startPos = [section positionStartAtRow:indexPath.row] + _contentListPosition.startPos;
        cellHeight = [_mpDataSource MPTableView:self estimatedHeightForRowAtIndexPath:indexPath];
        
        CGRect frame = CGRectMake(0, startPos, self.bounds.size.width, cellHeight);
        if (_updateForceReload || MPTV_ON_SCREEN) { // need to load height
            if (_respond_heightForRowAtIndexPath) {
                cellHeight = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
            } else {
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                cellHeight = frame.size.height = MPLayoutSizeForSubview(cell, frame.size.width);
                
                if (MPTV_OFF_SCREEN) {
                    [self _cacheCell:cell];
                } else {
                    [_estimatedCellsDic setObject:cell forKey:indexPath];
                }
            }
        }
    } else if (_respond_heightForRowAtIndexPath) {
        cellHeight = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else {
        cellHeight = self.rowHeight;
    }
    
    if (cellHeight < 0 || cellHeight >= MPTV_MAXSIZE) {
        MPTV_EXCEPTION(@"invalid cell height")
    }
    
    return cellHeight;
}

- (CGFloat)_updateGetMoveInCellOffsetAtIndexPath:(NSIndexPath *)indexPath fromLastIndexPath:(NSIndexPath *)lastIndexPath lastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance {
    if (_respond_estimatedHeightForRowAtIndexPath && !_updateForceReload) {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (![self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
            return 0;
        }
    }
    
    CGFloat cellHeight;
    if (_respond_heightForRowAtIndexPath) {
        cellHeight = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respond_estimatedHeightForRowAtIndexPath) {
        if ([_displayedCellsDic objectForKey:lastIndexPath]) {
            cellHeight = lastHeight;
        } else {
            MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            CGRect frame = [self _cellFrameAtIndexPath:indexPath];
            cellHeight = MPLayoutSizeForSubview(cell, frame.size.width);
            
            frame.size.height = cellHeight;
            if ([self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
                [_estimatedCellsDic setObject:cell forKey:indexPath];
            } else {
                [self _cacheCell:cell];
            }
        }
    } else {
        cellHeight = self.rowHeight;
    }
    
    if (cellHeight < 0 || cellHeight >= MPTV_MAXSIZE) {
        MPTV_EXCEPTION(@"invalid cell height")
    }
    
    return cellHeight - lastHeight;
}

- (CGFloat)_updateGetAdjustCellOffsetAtIndexPath:(NSIndexPath *)indexPath fromLastIndexPath:(NSIndexPath *)lastIndexPath withOffset:(CGFloat)cellOffset {
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (!_updateForceReload && ![self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:cellOffset]) {
        return frame.origin.y > _contentOffsetPosition.endPos ? (MPTV_MAXSIZE + 1) : 0;
    }
    
    CGFloat lastHeight = frame.size.height;
    if (_respond_heightForRowAtIndexPath) {
        frame.size.height = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respond_estimatedHeightForRowAtIndexPath) {
        if ([_displayedCellsDic objectForKey:lastIndexPath]) {
            frame.size.height = lastHeight;
        } else {
            MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            frame.size.height = MPLayoutSizeForSubview(cell, frame.size.width);
            
            if ([self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:cellOffset]) {
                [_estimatedCellsDic setObject:cell forKey:indexPath];
            } else {
                [self _cacheCell:cell];
            }
        }
    } else {
        frame.size.height = self.rowHeight;
    }
    
    if (frame.size.height < 0 || frame.size.height >= MPTV_MAXSIZE) {
        MPTV_EXCEPTION(@"invalid cell height")
    }
    
    return frame.size.height - lastHeight;
}

- (CGFloat)_updateGetRebuildCellOffsetInSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection withDistance:(CGFloat)distance { // distance should be 0 if there is an insertion
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(row, section);
    if (lastSection != section) {
        if (!_respond_heightForRowAtIndexPath && [_displayedCellsDic objectForKey:_NSIndexPathPrivateForRowSection(row, lastSection)]) {
            return 0;
        }
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (_respond_estimatedHeightForRowAtIndexPath && !_updateForceReload && ![self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
        return frame.origin.y > _contentOffsetPosition.endPos ? (MPTV_MAXSIZE + 1) : 0;
    }
    
    CGFloat cellHeight = frame.size.height;
    if (_respond_heightForRowAtIndexPath) {
        frame.size.height = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
    } else if (_respond_estimatedHeightForRowAtIndexPath) {
        MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        frame.size.height = MPLayoutSizeForSubview(cell, frame.size.width);
        
        if ([self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
            [_estimatedCellsDic setObject:cell forKey:indexPath];
        } else {
            [self _cacheCell:cell];
        }
    } else {
        frame.size.height = self.rowHeight;
    }
    
    if (frame.size.height < 0 || frame.size.height >= MPTV_MAXSIZE) {
        MPTV_EXCEPTION(@"invalid cell height")
    }
    
    return frame.size.height - cellHeight;
}

- (void)_updateDeleteCellInSection:(NSInteger)lastSection atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(row, lastSection);
    
    if ([_selectedIndexPaths containsObject:indexPath]) {
        [_selectedIndexPaths removeObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    if (!cell) {
        return;
    }
    
    CGFloat updateLastDeletionOriginY = _updateLastDeletionOriginY + _contentListPosition.startPos;
    if (animation == MPTableViewRowAnimationCustom) {
        NSAssert(_respond_beginToDeleteCellForRowAtIndexPath, @"need - (void)MPTableView:(MPTableView *)tableView beginToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withLastDeletionOriginY:(CGFloat)lastDeletionOriginY");
        if (_respond_beginToDeleteCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self beginToDeleteCell:cell forRowAtIndexPath:indexPath withLastDeletionOriginY:updateLastDeletionOriginY];
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
                MPTableViewSubviewDisappearWithRowAnimation(cell, updateLastDeletionOriginY, animation, sectionPosition);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_updateDeletedCellsDic setObject:cell forKey:indexPath];
        }
    }
    
    [_displayedCellsDic removeObjectForKey:indexPath];
    [_updateAnimatedOffscreenIndexPaths removeObject:indexPath];
}

- (void)_updateInsertCellToSection:(NSInteger)section atRow:(NSInteger)row withAnimation:(MPTableViewRowAnimation)animation inSectionPosition:(MPTableViewSection *)sectionPosition withLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(row, section);
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (MPTV_OFF_SCREEN) {
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
    
    [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
    [_updateNewCellsDic setObject:cell forKey:indexPath];
    [self _addSubviewIfNecessaryFromCell:cell];
    MPSetViewFrameWithoutAnimation(cell, frame);
    
    if (_respond_willDisplayCellForRowAtIndexPath) {
        [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    
    updateLastInsertionOriginY += _contentListPosition.startPos;
    if (animation == MPTableViewRowAnimationCustom) {
        NSAssert(_respond_beginToInsertCellForRowAtIndexPath, @"need - (void)MPTableView:(MPTableView *)tableView beginToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath withLastInsertionOriginY:(CGFloat)lastInsertionOriginY");
        if (_respond_beginToInsertCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self beginToInsertCell:cell forRowAtIndexPath:indexPath withLastInsertionOriginY:updateLastInsertionOriginY];
        }
    } else {
        if (animation != MPTableViewRowAnimationNone) {
            if (animation == MPTableViewRowAnimationTop) {
                [_contentWrapperView sendSubviewToBack:cell];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [_contentWrapperView bringSubviewToFront:cell];
            }
            
            [UIView performWithoutAnimation:^{
                MPTableViewSubviewDisappearWithRowAnimation(cell, updateLastInsertionOriginY, animation, sectionPosition);
            }];
            
            void (^animationBlock)(void) = ^{
                MPTableViewSubviewDisplayWithRowAnimation(cell, frame, animation);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
        }
    }
}

- (void)_updateMoveCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastIndexPath:(NSIndexPath *)lastIndexPath withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(row, section);
    
    if ([_selectedIndexPaths containsObject:lastIndexPath]) {
        [_selectedIndexPaths removeObject:lastIndexPath];
        [_updateExchangedSelectedIndexPaths addObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:lastIndexPath];
    if (cell) {
        [_displayedCellsDic removeObjectForKey:lastIndexPath];
        if (!_draggedIndexPath) {
            [_updateAnimatedOffscreenIndexPaths removeObject:lastIndexPath];
        }
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    
    if (cell) {
        [_updateNewCellsDic setObject:cell forKey:indexPath];
        [_contentWrapperView bringSubviewToFront:cell];
        if (!_draggedIndexPath) {
            [self _updateAnimationBlocksSetFrame:frame forSubview:cell];
            [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
        }
    } else {
        if (frame.size.height <= 0 || ![self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
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
        MPSetViewFrameWithoutAnimation(cell, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        
        [_updateNewCellsDic setObject:cell forKey:indexPath];
        [self _addSubviewIfNecessaryFromCell:cell];
        [_contentWrapperView bringSubviewToFront:cell];
        [self _updateAnimationBlocksSetFrame:frame forSubview:cell];
        if (!_draggedIndexPath) {
            [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
        }
        
        if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
            [cell setSelected:YES];
        }
        
        if (_respond_willDisplayCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
    }
}

- (void)_updateAdjustCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow withLastHeight:(CGFloat)lastHeight withOffset:(CGFloat)cellOffset {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(lastRow, lastSection);
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    if (cell) {
        if (!_draggedIndexPath) {
            [_updateAnimatedOffscreenIndexPaths removeObject:indexPath];
        }
        if (section != lastSection || row != lastRow) {
            [_displayedCellsDic removeObjectForKey:indexPath];
            indexPath = _NSIndexPathPrivateForRowSection(row, section);
            [_updateNewCellsDic setObject:cell forKey:indexPath];
        }
        
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        [self _updateAnimationBlocksSetFrame:frame forSubview:cell];
        if (!_draggedIndexPath) {
            [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
        }
    } else {
        indexPath = _NSIndexPathPrivateForRowSection(row, section);
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (frame.size.height <= 0 || ![self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:cellOffset]) {
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
        frame.origin.y -= cellOffset;
        frame.size.height = lastHeight;
        MPSetViewFrameWithoutAnimation(cell, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        
        [_updateNewCellsDic setObject:cell forKey:indexPath];
        [self _addSubviewIfNecessaryFromCell:cell];
        [self _updateAnimationBlocksSetFrame:frame forSubview:cell];
        if (!_draggedIndexPath) {
            [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
        }
        
        if (section == lastSection && row == lastRow) {
            if ([_selectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES];
            }
        } else {
            if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES];
            }
        }
        
        if (_respond_willDisplayCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
    }
}

- (BOOL)_updateNeedToAdjustCellToSection:(NSInteger)section atRow:(NSInteger)row fromLastSection:(NSInteger)lastSection andLastRow:(NSInteger)lastRow {
    NSIndexPath *indexPath = nil;
    
    if (lastSection != section || lastRow != row) {
        indexPath = _NSIndexPathPrivateForRowSection(lastRow, lastSection);
        if ([_selectedIndexPaths containsObject:indexPath]) {
            [_selectedIndexPaths removeObject:indexPath];
            indexPath = _NSIndexPathPrivateForRowSection(row, section);
            [_updateExchangedSelectedIndexPaths addObject:indexPath];
        }
    }
    
    if (_updateAnimatedOffscreenIndexPaths.count) {
        indexPath = _NSIndexPathPrivateForRowSection(lastRow, lastSection);
        return [_updateAnimatedOffscreenIndexPaths containsObject:indexPath];
    } else {
        return NO;
    }
}

#pragma mark - sectionView update

- (BOOL)_needDisplaySectionViewInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type withOffset:(CGFloat)offset {
    CGFloat start, end;
    if (MPTV_IS_HEADER(type)) {
        start = section.startPos + _contentListPosition.startPos;
        end = section.startPos + section.headerHeight + _contentListPosition.startPos;
    } else {
        start = section.endPos - section.footerHeight + _contentListPosition.startPos;
        end = section.endPos + _contentListPosition.startPos;
    }
    
    if ([self _updateNeedToDisplayFromPositionStart:start toEnd:end withOffset:offset]) {
        return YES;
    }
    
    if (_style == MPTableViewStylePlain && ([self _needToSuspendViewInSection:section withType:type] || [self _needToPrepareToSuspendViewInSection:section withType:type])) {
        return YES;
    }
    
    return NO;
}

- (CGFloat)_layoutSizeForSectionViewInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type withOffset:(CGFloat)offset {
    MPTableReusableView *sectionView = nil;
    CGFloat height = -1;
    
    if (MPTV_IS_HEADER(type)) {
        sectionView = [_mpDataSource MPTableView:self viewForHeaderInSection:section.section];
    } else {
        sectionView = [_mpDataSource MPTableView:self viewForFooterInSection:section.section];
    }
    
    if (sectionView) {
        height = MPLayoutSizeForSubview(sectionView, self.bounds.size.width);
        
        if ([self _needDisplaySectionViewInSection:section withType:type withOffset:offset]) {
            NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(type, section.section);
            [_estimatedSectionViewsDic setObject:sectionView forKey:indexPath];
        } else {
            [self _cacheSectionView:sectionView];
        }
    }
    
    return height;
}

- (MPTableViewSection *)_updateGetSection:(NSInteger)section {
    MPTableViewSection *sectionPosition = [MPTableViewSection section];
    sectionPosition.section = section;
    
    CGFloat offset = 0;
    if (_sectionsArray.count && section > 0) {
        MPTableViewSection *preSection = _sectionsArray[section - 1];
        offset = preSection.endPos;
    }
    
    [self _initializeSection:sectionPosition withOffset:offset];
    
    return sectionPosition;
}

- (CGFloat)_updateGetHeaderHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement {
    if (isMovement && !_respond_heightForHeaderInSection && [_displayedSectionViewsDic objectForKey:_NSIndexPathPrivateForRowSection(MPSectionHeader, lastSection)]) {
        return -1;
    }
    
    if (_style != MPTableViewStylePlain && ![self _needDisplaySectionViewInSection:section withType:MPSectionHeader withOffset:offset]) {
        return -1;
    }
    
    CGFloat height;
    if (_respond_heightForHeaderInSection) {
        height = [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
    } else if (_respond_estimatedHeightForHeaderInSection) {
        height = [self _layoutSizeForSectionViewInSection:section withType:MPSectionHeader withOffset:offset];
    } else {
        height = self.sectionHeaderHeight;
    }
    
    if (height < 0 || height >= MPTV_MAXSIZE) {
        MPTV_EXCEPTION(@"invalid section header height")
    }
    
    return height;
}

- (CGFloat)_updateGetFooterHeightInSection:(MPTableViewSection *)section fromLastSection:(NSInteger)lastSection withOffset:(CGFloat)offset isMovement:(BOOL)isMovement {
    if (isMovement && !_respond_heightForFooterInSection && [_displayedSectionViewsDic objectForKey:_NSIndexPathPrivateForRowSection(MPSectionFooter, lastSection)]) {
        return -1;
    }
    
    if (_style != MPTableViewStylePlain && ![self _needDisplaySectionViewInSection:section withType:MPSectionFooter withOffset:offset]) {
        return -1;
    }
    
    CGFloat height;
    if (_respond_heightForFooterInSection) {
        height = [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
    } else if (_respond_estimatedHeightForFooterInSection) {
        height = [self _layoutSizeForSectionViewInSection:section withType:MPSectionFooter withOffset:offset];
    } else {
        height = self.sectionFooterHeight;
    }
    
    if (height < 0 || height >= MPTV_MAXSIZE) {
        MPTV_EXCEPTION(@"invalid section footer height")
    }
    
    return height;
}

- (void)_updateDeleteSectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(type, section);
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (!sectionView) {
        return;
    }
    
    CGFloat updateLastDeletionOriginY = _updateLastDeletionOriginY + _contentListPosition.startPos;
    if (animation == MPTableViewRowAnimationCustom) {
        if (MPTV_IS_HEADER(type)) {
            NSAssert(_respond_beginToDeleteHeaderViewForSection, @"need - (void)MPTableView:(MPTableView *)tableView beginToDeleteHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastDeletionOriginY:(CGFloat)lastDeletionOriginY");
            if (_respond_beginToDeleteHeaderViewForSection) {
                [_mpDelegate MPTableView:self beginToDeleteHeaderView:sectionView forSection:section withLastDeletionOriginY:updateLastDeletionOriginY];
            } else {
                [sectionView removeFromSuperview];
            }
        } else {
            NSAssert(_respond_beginToDeleteFooterViewForSection, @"need - (void)MPTableView:(MPTableView *)tableView beginToDeleteFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastDeletionOriginY:(CGFloat)lastDeletionOriginY");
            if (_respond_beginToDeleteFooterViewForSection) {
                [_mpDelegate MPTableView:self beginToDeleteFooterView:sectionView forSection:section withLastDeletionOriginY:updateLastDeletionOriginY];
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
                MPTableViewSubviewDisappearWithRowAnimation(sectionView, updateLastDeletionOriginY, animation, deleteSection);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_updateDeletedSectionViewsDic setObject:sectionView forKey:indexPath];
        }
    }
    
    [_displayedSectionViewsDic removeObjectForKey:indexPath];
    [_updateAnimatedOffscreenIndexPaths removeObject:indexPath];
}

- (void)_updateInsertSectionViewToSection:(NSInteger)section withType:(MPSectionViewType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection withLastInsertionOriginY:(CGFloat)updateLastInsertionOriginY {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(type, section);
    
    CGRect frame;
    if (_style == MPTableViewStylePlain) {
        if ([self _needToSuspendViewInSection:insertSection withType:type]) {
            [self _setSuspendingSection:section withType:type];
            
            frame = [self _suspendingFrameInSection:insertSection withType:type];
        } else if ([self _needToPrepareToSuspendViewInSection:insertSection withType:type]) {
            frame = [self _prepareToSuspendFrameInSection:insertSection withType:type];
        } else {
            frame = [self _sectionViewFrameInSection:indexPath.section withType:indexPath.row];
        }
    } else {
        frame = [self _sectionViewFrameInSection:indexPath.section withType:indexPath.row];
    }
    
    if (MPTV_OFF_SCREEN) {
        return;
    }
    MPTableReusableView *sectionView = nil;
    if (MPTV_IS_HEADER(type) && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
        sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
    } else if (MPTV_IS_FOOTER(type) && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
        sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
    }
    
    if (!sectionView) {
        sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:indexPath.row];
    } else {
        [_estimatedSectionViewsDic removeObjectForKey:indexPath];
    }
    
    if (!sectionView) {
        return;
    }
    
    [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
    [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
    [self _addSubviewIfNecessaryFromSectionView:sectionView];
    MPSetViewFrameWithoutAnimation(sectionView, frame);
    
    if (MPTV_IS_HEADER(type)) {
        if (_respond_willDisplayHeaderViewForSection) {
            [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
        }
    } else {
        if (_respond_willDisplayFooterViewForSection) {
            [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
        }
    }
    
    updateLastInsertionOriginY += _contentListPosition.startPos;
    if (animation == MPTableViewRowAnimationCustom) {
        if (MPTV_IS_HEADER(type)) {
            NSAssert(_respond_beginToInsertHeaderViewForSection, @"need - (void)MPTableView:(MPTableView *)tableView beginToInsertHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastInsertionOriginY:(CGFloat)lastInsertionOriginY");
            if (_respond_beginToInsertHeaderViewForSection) {
                [_mpDelegate MPTableView:self beginToInsertHeaderView:sectionView forSection:section withLastInsertionOriginY:updateLastInsertionOriginY];
            }
        } else {
            NSAssert(_respond_beginToInsertFooterViewForSection, @"need - (void)MPTableView:(MPTableView *)tableView beginToInsertFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastInsertionOriginY:(CGFloat)lastInsertionOriginY");
            if (_respond_beginToInsertFooterViewForSection) {
                [_mpDelegate MPTableView:self beginToInsertFooterView:sectionView forSection:section withLastInsertionOriginY:updateLastInsertionOriginY];
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
            
            [UIView performWithoutAnimation:^{
                MPTableViewSubviewDisappearWithRowAnimation(sectionView, updateLastInsertionOriginY, animation, insertSection);
            }];
            
            void (^animationBlock)(void) = ^{
                MPTableViewSubviewDisplayWithRowAnimation(sectionView, frame, animation);
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
        }
    }
}

- (void)_updateMoveSectionViewToSection:(NSInteger)section fromLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withDistance:(CGFloat)distance {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(type, section);
    NSIndexPath *lastIndexPath = _NSIndexPathPrivateForRowSection(type, lastSection);
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:lastIndexPath];
    if (sectionView) {
        [_displayedSectionViewsDic removeObjectForKey:lastIndexPath];
        if (!_draggedIndexPath) {
            [_updateAnimatedOffscreenIndexPaths removeObject:lastIndexPath];
        }
    }
    CGRect frame = [self _sectionViewFrameInSection:indexPath.section withType:indexPath.row];
    CGFloat lastOriginY = frame.origin.y;
    
    if (_style == MPTableViewStylePlain) {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        if ([self _needToSuspendViewInSection:sectionPosition withType:type]) {
            [self _setSuspendingSection:section withType:type];
            
            frame = [self _suspendingFrameInSection:sectionPosition withType:type];
        } else if ([self _needToPrepareToSuspendViewInSection:sectionPosition withType:type]) {
            frame = [self _prepareToSuspendFrameInSection:sectionPosition withType:type];
        }
    }
    
    if (sectionView) {
        [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
        [self bringSubviewToFront:sectionView];
        [self _updateAnimationBlocksSetFrame:frame forSubview:sectionView];
        [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
    } else {
        if (frame.size.height <= 0 || ![self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:distance]) {
            return;
        }
        
        if (MPTV_IS_HEADER(type) && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:indexPath.row];
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
        MPSetViewFrameWithoutAnimation(sectionView, frame);
        frame.size.height = height;
        frame.origin.y = originY;
        
        [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
        [self _addSubviewIfNecessaryFromSectionView:sectionView];
        [self bringSubviewToFront:sectionView];
        [self _updateAnimationBlocksSetFrame:frame forSubview:sectionView];
        [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
        
        if (MPTV_IS_HEADER(type)) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
    }
}

- (void)_updateAdjustSectionViewFromSection:(NSInteger)lastSection toSection:(NSInteger)section withType:(MPSectionViewType)type withLastHeight:(CGFloat)lastHeight withSectionOffset:(CGFloat)sectionOffset {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(type, lastSection);
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    
    indexPath = _NSIndexPathPrivateForRowSection(type, section);
    CGRect frame = [self _sectionViewFrameInSection:indexPath.section withType:indexPath.row];
    
    if (_style == MPTableViewStylePlain) {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        if ([self _needToSuspendViewInSection:sectionPosition withType:type]) {
            [self _setSuspendingSection:section withType:type];
            
            frame = [self _suspendingFrameInSection:sectionPosition withType:type];
        } else if ([self _needToPrepareToSuspendViewInSection:sectionPosition withType:type]) {
            frame = [self _prepareToSuspendFrameInSection:sectionPosition withType:type];
        }
    }
    
    if (sectionView) {
        indexPath = _NSIndexPathPrivateForRowSection(type, lastSection);
        
        if (!_draggedIndexPath) {
            [_updateAnimatedOffscreenIndexPaths removeObject:indexPath];
        }
        if (lastSection != section) {
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            indexPath = _NSIndexPathPrivateForRowSection(type, section);
            [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
        }
        
        [self _updateAnimationBlocksSetFrame:frame forSubview:sectionView];
        if (!_draggedIndexPath) {
            [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
        }
    } else {
        if (frame.size.height <= 0 || ![self _updateNeedToDisplayFromPositionStart:frame.origin.y toEnd:CGRectGetMaxY(frame) withOffset:sectionOffset]) {
            return;
        }
        
        if (MPTV_IS_HEADER(type) && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:indexPath.row];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        CGFloat originY = frame.origin.y;
        CGFloat height = frame.size.height;
        frame.origin.y -= sectionOffset;
        frame.size.height = lastHeight;
        MPSetViewFrameWithoutAnimation(sectionView, frame);
        frame.origin.y = originY;
        frame.size.height = height;
        
        [self _addSubviewIfNecessaryFromSectionView:sectionView];
        [_updateNewSectionViewsDic setObject:sectionView forKey:indexPath];
        [self _updateAnimationBlocksSetFrame:frame forSubview:sectionView];
        if (!_draggedIndexPath) {
            [_updateAnimatedNewOffscreenIndexPaths addObject:indexPath];
        }
        
        if (MPTV_IS_HEADER(type)) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
    }
}

- (BOOL)_updateNeedToAdjustSectionViewInLastSection:(NSInteger)lastSection withType:(MPSectionViewType)type {
    if (_updateAnimatedOffscreenIndexPaths.count) {
        NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(type, lastSection);
        return [_updateAnimatedOffscreenIndexPaths containsObject:indexPath];
    } else {
        return NO;
    }
}

#pragma mark - estimated layout

- (BOOL)_isEstimatedMode {
    return _respond_estimatedHeightForRowAtIndexPath || _respond_estimatedHeightForHeaderInSection || _respond_estimatedHeightForFooterInSection;
}

- (BOOL)_hasEstimatedHeightForRow {
    return _respond_estimatedHeightForRowAtIndexPath;
}

- (BOOL)_hasEstimatedHeightForHeader {
    return _respond_estimatedHeightForHeaderInSection;
}

- (BOOL)_hasEstimatedHeightForFooter {
    return _respond_estimatedHeightForFooterInSection;
}

- (BOOL)_hasDisplayedSection:(MPTableViewSection *)section {
    return section.section >= _beginIndexPath.section && section.section <= _endIndexPath.section;
}

- (BOOL)_estimatedNeedToDisplaySection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    if ([self isUpdating] && _updateAnimatedOffscreenIndexPaths.count) {
        for (NSIndexPath *indexPath in _updateAnimatedOffscreenIndexPaths) {
            if (indexPath.section == section.section) {
                return YES;
            }
        }
    }
    
    return [self _hasDisplayedSection:section] || (section.startPos + offset <= _contentListOffsetPosition.endPos && section.endPos + offset >= _contentListOffsetPosition.startPos);
}

- (void)_estimatedLayoutSubviewsAtFirstIndexPath:(NSIndexPathStruct)firstIndexPath {
    CGFloat offset = [[self _estimatedManager] startEstimateForTableView:self atFirstIndexPath:firstIndexPath andSections:_sectionsArray];
    
    _contentListPosition.endPos += offset;
    
    if (_contentListPosition.startPos >= _contentListPosition.endPos) {
        _beginIndexPath = _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
        _endIndexPath = _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
    } else {
        _beginIndexPath = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.startPos];
        _endIndexPath = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.endPos];
    }
    
    if (_estimatedCellsDic.count) {
        for (MPTableViewCell *cell in _estimatedCellsDic.allValues) {
            [self _cacheCell:cell];
        }
        [_estimatedCellsDic removeAllObjects];
    }
    
    if (_estimatedSectionViewsDic.count) {
        for (MPTableReusableView *view in _estimatedSectionViewsDic.allValues) {
            [self _cacheSectionView:view];
        }
        [_estimatedSectionViewsDic removeAllObjects];
    }
    
    [self _clipCellsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    
    MPSetViewOffset(self.tableFooterView, offset);
    CGSize contentSize = CGSizeMake(self.bounds.size.width, _contentListPosition.endPos + self.tableFooterView.bounds.size.height);
    if (!CGSizeEqualToSize(self.contentSize, contentSize)) {
        [self setContentSize:contentSize];
        
        // Change a scrollview's content size when it is bouncing will make -layoutSubviews can not be called in the next runloop. This situation is possibly caused by an UIKit bug.
        if (_contentOffsetPosition.startPos < -[self _innerContentInset].top || _contentOffsetPosition.startPos > self.contentSize.height - self.bounds.size.height + [self _innerContentInset].bottom) {
            CFRunLoopRef runLoop = CFRunLoopGetCurrent();
            CFStringRef runLoopMode = kCFRunLoopCommonModes;
            CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, false, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
                [self layoutSubviews];
            });
            CFRunLoopAddObserver(runLoop, observer, runLoopMode);
            CFRelease(observer);
        }
    }
}

- (CGFloat)_estimatedGetSectionViewHeightWithType:(MPSectionViewType)type inSection:(MPTableViewSection *)section {
    if (_updateContentOffsetChanged) {
        return -1;
    }
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:_NSIndexPathPrivateForRowSection(type, section.section)];
    if (sectionView) {
        return -1;
    }
    
    if ([self _needDisplaySectionViewInSection:section withType:type withOffset:0]) {
        CGFloat height;
        if (MPTV_IS_HEADER(type)) {
            if (_respond_heightForHeaderInSection) {
                height = [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
            } else {
                height = [self _layoutSizeForSectionViewInSection:section withType:MPSectionHeader withOffset:0];
            }
            
            if (height < 0 || height >= MPTV_MAXSIZE) {
                MPTV_EXCEPTION(@"invalid section header height")
            }
        } else {
            if (_respond_heightForFooterInSection) {
                height = [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
            } else {
                height = [self _layoutSizeForSectionViewInSection:section withType:MPSectionFooter withOffset:0];
            }
            
            if (height < 0 || height >= MPTV_MAXSIZE) {
                MPTV_EXCEPTION(@"invalid section footer height")
            }
        }
        
        return height;
    }
    
    return -1;
}

- (CGFloat)_estimatedDisplayCellInSection:(NSInteger)section atRow:(NSInteger)row withOffset:(CGFloat)cellOffset {
    CGFloat newOffset = 0;
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(row, section);
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    if (cell) {
        if (cellOffset != 0 && cell != _dragModeDragCell) {
            CGRect frame = cell.frame;
            frame.origin.y += cellOffset;
            MPSetViewFrameWithoutAnimation(cell, frame);
        }
    } else {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (MPTV_OFF_SCREEN) {
            if (frame.origin.y > _contentOffsetPosition.endPos) {
                return _updateAnimatedOffscreenIndexPaths.count ? 0 : (MPTV_MAXSIZE + 1); // verified
            } else {
                return 0;
            }
        } else {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            
            if (_respond_estimatedHeightForRowAtIndexPath && !_updateContentOffsetChanged) {
                CGFloat cellHeight = frame.size.height;
                if (_respond_heightForRowAtIndexPath) {
                    frame.size.height = [_mpDataSource MPTableView:self heightForRowAtIndexPath:indexPath];
                } else {
                    frame.size.height = MPLayoutSizeForSubview(cell, frame.size.width);
                    if (MPTV_OFF_SCREEN) {
                        [self _cacheCell:cell];
                        return frame.size.height - cellHeight;
                    }
                }
                
                if (frame.size.height < 0 || frame.size.height >= MPTV_MAXSIZE) {
                    MPTV_EXCEPTION(@"invalid cell height")
                }
                
                newOffset = frame.size.height - cellHeight;
            }
            
            [self _addSubviewIfNecessaryFromCell:cell];
            MPSetViewFrameWithoutAnimation(cell, frame);
            
            if ([_selectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES];
            }
            
            if (_respond_willDisplayCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
            }
            
            [_displayedCellsDic setObject:cell forKey:indexPath];
        }
    }
    
    return newOffset;
}

- (void)_estimatedDisplaySectionViewInSection:(NSInteger)section withType:(MPSectionViewType)type {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(type, section);
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (sectionView) {
        return;
    }
    
    BOOL isSuspending = NO;
    BOOL isPrepareToSuspend = NO;
    
    if (_style == MPTableViewStylePlain) {
        MPTableViewSection *sectionPosition = _sectionsArray[section];
        if ([self _needToSuspendViewInSection:sectionPosition withType:type]) {
            [self _setSuspendingSection:section withType:type];
            isSuspending = YES;
        } else if ([self _needToPrepareToSuspendViewInSection:sectionPosition withType:type]) {
            isPrepareToSuspend = YES;
        }
    }
    
    CGRect frame = [self _sectionViewFrameInSection:indexPath.section withType:indexPath.row];
    if (MPTV_OFF_SCREEN && !isSuspending && !isPrepareToSuspend) {
        return;
    } else {
        if (MPTV_IS_HEADER(type) && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (MPTV_IS_FOOTER(type) && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:indexPath.row];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        if (_updateContentOffsetChanged) {
            if (isSuspending) {
                frame = [self _suspendingFrameInSection:_sectionsArray[indexPath.section] withType:indexPath.row];
            } else if (isPrepareToSuspend) {
                frame = [self _prepareToSuspendFrameInSection:_sectionsArray[indexPath.section] withType:indexPath.row];
            }
        }
        
        [self _addSubviewIfNecessaryFromSectionView:sectionView];
        MPSetViewFrameWithoutAnimation(sectionView, frame);
        
        if (MPTV_IS_HEADER(type)) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    }
}

#pragma mark - reload

- (void)reloadData {
    if (_layoutSubviewsLock || _updateSubviewsLock) {
        return;
    }
    
    NSParameterAssert([NSThread isMainThread]);
    
    [self _clear];
    
    CGFloat offset = 0;
    if (_mpDataSource) {
        offset = [self _initializeSubviewsPositionWithNewSections:nil];
        _layoutSubviewsLock = NO;
    }
    
    if (offset >= 0) {
        [self _setContentHeightUsingContentListHeight:offset];
    }
    
    _reloadDataNeededFlag = NO;
    _reloadDataLayoutNeededFlag = YES;
    [self setNeedsLayout];
}

- (void)reloadDataAsyncWithCompletion:(void (^)(void))completion {
    NSParameterAssert(!_reloadDataLock);
    if (_layoutSubviewsLock || _updateSubviewsLock) {
        return;
    }
    
    if (!_mpDataSource) {
        return [self reloadData];
    }
    
    _reloadDataNeededFlag = NO;
    _reloadDataLock = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newSections = [[NSMutableArray alloc] init];
        CGFloat height = [self _initializeSubviewsPositionWithNewSections:newSections];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _clear];
            
            _sectionsArray = newSections;
            if (_updateManagersStack.count) {
                MPTableViewUpdateManager *updateManager = _updateManagersStack.lastObject; // there can only be one update manager in this situation
                updateManager.sections = newSections;
            }
            
            _layoutSubviewsLock = NO;
            if (height >= 0 && [self superview]) {
                [self _setContentHeightUsingContentListHeight:height];
                [self _setContentOffsetPositions];
                _updateSubviewsLock = YES;
                [self _layoutSubviewsIfNeeded];
                [self _prefetchIndexPathsIfNeeded];
                _updateSubviewsLock = NO;
            }
            if (completion) {
                completion();
            }
        });
    });
}

- (CGFloat)_initializeSection:(MPTableViewSection *)section withOffset:(CGFloat)offset {
    // header
    section.startPos = offset;
    CGFloat height = 0;
    
    if (_respond_estimatedHeightForHeaderInSection) {
        MPTV_CHECK_DATASOURCE
        height = [_mpDataSource MPTableView:self estimatedHeightForHeaderInSection:section.section];
    } else {
        if (_respond_heightForHeaderInSection) {
            MPTV_CHECK_DATASOURCE
            height = [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
        } else {
            height = self.sectionHeaderHeight;
        }
    }
    
    if (height < 0 || height >= MPTV_MAXSIZE) {
        MPTV_EXCEPTION(@"invalid section header height")
    }
    
    section.headerHeight = height;
    offset += height;
    
    if (_mpDataSource) {
        NSUInteger numberOfRows = [_mpDataSource MPTableView:self numberOfRowsInSection:section.section];
        section.numberOfRows = numberOfRows;
        for (NSInteger j = 0; j < numberOfRows; j++) {
            CGFloat cellHeight;
            if (_respond_estimatedHeightForRowAtIndexPath) {
                MPTV_CHECK_DATASOURCE
                cellHeight = [_mpDataSource MPTableView:self estimatedHeightForRowAtIndexPath:_NSIndexPathPrivateForRowSection(j, section.section)];
            } else {
                if (_respond_heightForRowAtIndexPath) {
                    MPTV_CHECK_DATASOURCE
                    cellHeight = [_mpDataSource MPTableView:self heightForRowAtIndexPath:_NSIndexPathPrivateForRowSection(j, section.section)];
                } else {
                    cellHeight = self.rowHeight;
                }
            }
            
            if (cellHeight < 0 || cellHeight >= MPTV_MAXSIZE) {
                MPTV_EXCEPTION(@"invalid cell height")
            }
            
            [section addRowPosition:offset += cellHeight];
        }
    }
    // footer
    if (_respond_estimatedHeightForFooterInSection) {
        MPTV_CHECK_DATASOURCE
        height = [_mpDataSource MPTableView:self estimatedHeightForFooterInSection:section.section];
    } else {
        if (_respond_heightForFooterInSection) {
            MPTV_CHECK_DATASOURCE
            height = [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
        } else {
            height = self.sectionFooterHeight;
        }
    }
    
    if (height < 0 || height >= MPTV_MAXSIZE) {
        MPTV_EXCEPTION(@"invalid section footer height")
    }
    
    section.footerHeight = height;
    offset += height;
    
    section.endPos = offset;
    return offset;
}

- (CGFloat)_initializeSubviewsPositionWithNewSections:(NSMutableArray *)newSections {
    _reloadDataLock = YES;
    
    CGFloat offset = 0;
    const NSUInteger sectionsCount = _sectionsArray.count;
    MPTV_CHECK_DATASOURCE
    if (_respond_numberOfSectionsInMPTableView) {
        _numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
        NSAssert(_numberOfSections <= MPTV_MAXCOUNT, @"the number of sections is too many");
    }
    
    if (sectionsCount > _numberOfSections && !newSections) {
        [_sectionsArray removeObjectsInRange:NSMakeRange(_numberOfSections, sectionsCount - _numberOfSections)];
    }
    for (NSInteger i = 0; i < _numberOfSections; i++) {
        MPTableViewSection *section;
        if (i < sectionsCount && !newSections) {
            section = _sectionsArray[i];
            [section reset];
        } else {
            section = [MPTableViewSection section];
        }
        section.section = i;
        
        offset = [self _initializeSection:section withOffset:offset];
        if (offset < 0) {
            [newSections removeAllObjects];
            break;
        }
        if (i >= sectionsCount && !newSections) {
            [_sectionsArray addObject:section];
        }
        if (newSections) {
            [newSections addObject:section];
        }
    }
    
    _reloadDataLock = NO;
    return offset;
}
// adjust header, footer, contentSize
- (void)_setContentHeightUsingContentListHeight:(CGFloat)contentListHeight {
    if (self.tableHeaderView) {
        _contentListPosition.startPos = self.tableHeaderView.bounds.size.height;
    }
    CGFloat contentSizeHeight = _contentListPosition.endPos = _contentListPosition.startPos + contentListHeight;
    if (self.tableFooterView) {
        CGRect frame = self.tableFooterView.frame;
        frame.origin.y = _contentListPosition.endPos;
        MPSetViewFrameWithoutAnimation(self.tableFooterView, frame);
        
        contentSizeHeight += frame.size.height;
    }
    [self setContentSize:CGSizeMake(self.bounds.size.width, contentSizeHeight)];
}

- (BOOL)isCachesReloadEnabled {
    return _cachesReloadEnabled;
}

- (void)_clear {
    _layoutSubviewsLock = YES;
    
    [self _resetDragModeLongGestureRecognizer];
    
    _contentListPosition.startPos = _contentListPosition.endPos = 0;
    _previousContentOffsetY = self.contentOffset.y;
    
    [_selectedIndexPaths removeAllObjects];
    [_prefetchIndexPaths removeAllObjects];
    
    [self _resetContentIndexPaths];
    
    if (_cachesReloadEnabled) {
        [self _cacheDisplayedCells];
        [self _cacheDisplayedSectionViews];
    } else {
        [self _clearReusableCells];
        [self _clearReusableSectionViews];
        
        [self _clearDisplayedCells];
        [self _clearDisplayingSectionViews];
    }
}

- (void)_resetDragModeLongGestureRecognizer {
    [self _endDragCellIfNeededImmediately:YES];
    
    _dragModeLongGestureRecognizer.enabled = NO; // cancel interaction
    _dragModeLongGestureRecognizer.enabled = _dragModeEnabled;
}

- (void)_cacheDisplayedCells {
    NSArray *indexPaths = [_displayedCellsDic.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *indexPathA, NSIndexPath *indexPathB) {
        return [indexPathB compare:indexPathA]; // reverse
    }];
    
    for (NSIndexPath *indexPath in indexPaths) {
        [self _cacheCell:[_displayedCellsDic objectForKey:indexPath]];
    }
    
    [_displayedCellsDic removeAllObjects];
}

- (void)_cacheDisplayedSectionViews {
    NSArray *indexPaths = [_displayedSectionViewsDic.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *indexPathA, NSIndexPath *indexPathB) {
        return [indexPathB compare:indexPathA];
    }];
    
    for (NSIndexPath *indexPath in indexPaths) {
        [self _cacheSectionView:[_displayedSectionViewsDic objectForKey:indexPath]];
    }
    
    [_displayedSectionViewsDic removeAllObjects];
}

- (void)_clearDisplayedCells {
    [_displayedCellsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_displayedCellsDic removeAllObjects];
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

- (void)_clearDisplayingSectionViews {
    [_displayedSectionViewsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_displayedSectionViewsDic removeAllObjects];
}

#pragma mark - layoutSubviews

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_updateSubviewsLock || _layoutSubviewsLock) {
        return;
    }
    [self _layoutSubviewsInternal];
}

- (void)_layoutSubviewsInternal {
    NSParameterAssert([NSThread isMainThread]);
    
    if (!_mpDataSource) {
        [self _respondsToDataSource];
        return [self _clear];
    }
    
    if (_reloadDataNeededFlag) {
        [self reloadData];
        if (!_numberOfSections) {
            return;
        }
    }
    
    [self _setContentOffsetPositions];
    _updateSubviewsLock = YES;
    [self _layoutSubviewsIfNeeded];
    [self _prefetchIndexPathsIfNeeded];
    _updateSubviewsLock = NO;
    
    _reloadDataLayoutNeededFlag = NO;
}

- (void)_setContentOffsetPositions {
    _contentOffsetPosition.startPos = self.contentOffset.y;
    _contentOffsetPosition.endPos = self.contentOffset.y + self.bounds.size.height;
    
    _contentListOffsetPosition.startPos = _contentOffsetPosition.startPos - _contentListPosition.startPos;
    _contentListOffsetPosition.endPos = _contentOffsetPosition.endPos - _contentListPosition.startPos;
}

- (void)_layoutSubviewsIfNeeded {
    if (_contentListPosition.startPos >= _contentListPosition.endPos) {
        return;
    }
    
    NSIndexPathStruct beginIndexPathStruct = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.startPos];
    NSIndexPathStruct endIndexPathStruct = [self _indexPathAtContentOffsetY:_contentListOffsetPosition.endPos];
    
    if ([self _isEstimatedMode]) { // estimated layout
        if (!_NSIndexPathStructEqu(_beginIndexPath, beginIndexPathStruct) || !_NSIndexPathStructEqu(_endIndexPath, endIndexPathStruct)) {
            NSIndexPathStruct estimatedFirstIndexPath;
            
            if (_NSIndexPathStructCompareStruct(beginIndexPathStruct, _beginIndexPath) == NSOrderedAscending) {
                estimatedFirstIndexPath = beginIndexPathStruct;
                
                [self _estimatedLayoutSubviewsAtFirstIndexPath:estimatedFirstIndexPath];
            } else if (_NSIndexPathStructCompareStruct(endIndexPathStruct, _endIndexPath) == NSOrderedDescending) {
                if (MPTV_IS_FOOTER(_endIndexPath.row)) {
                    estimatedFirstIndexPath = _NSIndexPathMakeStruct(_endIndexPath.section + 1, MPSectionHeader);
                } else if (MPTV_IS_HEADER(_endIndexPath.row)) {
                    estimatedFirstIndexPath = _NSIndexPathMakeStruct(_endIndexPath.section, 0);
                } else {
                    estimatedFirstIndexPath = _NSIndexPathMakeStruct(_endIndexPath.section, _endIndexPath.row + 1);
                }
                
                [self _estimatedLayoutSubviewsAtFirstIndexPath:estimatedFirstIndexPath];
            } else {
                [self _clipCellsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
                [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
                
                _beginIndexPath = beginIndexPathStruct;
                _endIndexPath = endIndexPathStruct;
            }
        } else if (_style == MPTableViewStylePlain) {
            [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
        }
    } else { // normal layout
        if (_style == MPTableViewStylePlain) {
            [self _suspendSectionHeaderIfNeededInSection:beginIndexPathStruct.section];
            [self _suspendSectionFooterIfNeededInSection:endIndexPathStruct.section];
        }
        
        if (!_NSIndexPathStructEqu(_beginIndexPath, beginIndexPathStruct) || !_NSIndexPathStructEqu(_endIndexPath, endIndexPathStruct)) {
            [self _clipCellsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
            [self _clipSectionViewsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
            
            [self _layoutSubviewsBetweenBeginIndexPath:beginIndexPathStruct andEndIndexPath:endIndexPathStruct];
        }
    }
}

- (void)_layoutSubviewsBetweenBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    
    for (NSInteger i = beginIndexPathStruct.section; i <= endIndexPathStruct.section; i++) {
        MPTableViewSection *section = _sectionsArray[i];
        
        NSInteger beginCellRow = 0, endCellRow = section.numberOfRows - 1;
        BOOL needToDisplayHeader = (section.headerHeight > 0) && (i != _suspendingHeaderSection);
        BOOL needToDisplayFooter = (section.footerHeight > 0) && (i != _suspendingFooterSection);
        
        if (i == beginIndexPathStruct.section) {
            if (MPTV_IS_HEADER(beginIndexPathStruct.row)) {
                beginCellRow = 0;
            } else {
                needToDisplayHeader = (needToDisplayHeader && _style == MPTableViewStylePlain && beginIndexPathStruct.row != MPSectionFooter);
                if (needToDisplayHeader && [self _needToPrepareToSuspendViewInSection:section withType:MPSectionHeader]) {
                    [self _displaySectionViewToPrepareToSuspendInSection:section withType:MPSectionHeader];
                }
                needToDisplayHeader = NO;
                beginCellRow = beginIndexPathStruct.row;
            }
        }
        
        if (i == endIndexPathStruct.section) {
            if (MPTV_IS_FOOTER(endIndexPathStruct.row)) {
                endCellRow = section.numberOfRows - 1;
            } else {
                needToDisplayFooter = (needToDisplayFooter && _style == MPTableViewStylePlain && endIndexPathStruct.row != MPSectionHeader);
                if (needToDisplayFooter && [self _needToPrepareToSuspendViewInSection:section withType:MPSectionFooter]) {
                    [self _displaySectionViewToPrepareToSuspendInSection:section withType:MPSectionFooter];
                }
                needToDisplayFooter = NO;
                endCellRow = MPTV_IS_HEADER(endIndexPathStruct.row) ? NSIntegerMin : endIndexPathStruct.row;
            }
        }
        
        if (needToDisplayHeader) {
            if (_style == MPTableViewStylePlain && [self _needToPrepareToSuspendViewInSection:section withType:MPSectionHeader]) {
                [self _displaySectionViewToPrepareToSuspendInSection:section withType:MPSectionHeader];
            } else {
                [self _displaySectionViewIfNeededAtIndexPath:_NSIndexPathPrivateForRowSection(MPSectionHeader, i)];
            }
        }
        
        if (needToDisplayFooter) {
            if (_style == MPTableViewStylePlain && [self _needToPrepareToSuspendViewInSection:section withType:MPSectionFooter]) {
                [self _displaySectionViewToPrepareToSuspendInSection:section withType:MPSectionFooter];
            } else {
                [self _displaySectionViewIfNeededAtIndexPath:_NSIndexPathPrivateForRowSection(MPSectionFooter, i)];
            }
        }
        
        for (NSInteger j = beginCellRow; j <= endCellRow; j++) {
            NSIndexPathStruct indexPathStruct = {i, j};
            if (_NSIndexPathStructCompareStruct(indexPathStruct, _beginIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(indexPathStruct, _endIndexPath) == NSOrderedDescending) {
                NSIndexPath *indexPath = _NSIndexPathFromStruct(indexPathStruct);
                
                if ((isUpdating || _draggedIndexPath) && [_displayedCellsDic objectForKey:indexPath]) {
                    continue;
                }
                
                CGRect frame = [self _cellFrameAtIndexPath:indexPath];
                if (frame.size.height <= 0) {
                    continue;
                }
                
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                [self _addSubviewIfNecessaryFromCell:cell];
                if (isUpdating) {
                    [_contentWrapperView sendSubviewToBack:cell];
                }
                MPSetViewFrameWithoutAnimation(cell, frame);
                
                if ([_selectedIndexPaths containsObject:indexPath]) {
                    [cell setSelected:YES];
                }
                
                if (_respond_willDisplayCellForRowAtIndexPath) {
                    [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
                }
                
                [_displayedCellsDic setObject:cell forKey:indexPath];
            }
        }
    }
    
    _beginIndexPath = beginIndexPathStruct;
    _endIndexPath = endIndexPathStruct;
}

- (NSInteger)_sectionAtContentOffsetY:(CGFloat)contentOffsetY {
    NSInteger count = _sectionsArray.count;
    NSInteger start = 0;
    NSInteger end = count - 1;
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
    if (contentOffsetY > _contentListPosition.endPos - _contentListPosition.startPos) {
        if (_contentListOffsetPosition.startPos == contentOffsetY) {
            return _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
        } else if (_contentListOffsetPosition.startPos > _contentListPosition.endPos - _contentListPosition.startPos) { // contentOffsetY == _contentListOffsetPosition.endPos
            return _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
        } else {
            contentOffsetY = _contentListPosition.endPos - _contentListPosition.startPos; // contentOffsetY == _contentListOffsetPosition.endPos
        }
    }
    
    if (contentOffsetY < 0) {
        if (_contentListOffsetPosition.endPos == contentOffsetY) {
            return _NSIndexPathMakeStruct(NSIntegerMin, MPSectionHeader);
        } else if (_contentListOffsetPosition.endPos < 0) { // contentOffsetY == _contentListOffsetPosition.startPos
            return _NSIndexPathMakeStruct(NSIntegerMax, MPSectionFooter);
        } else { // contentOffsetY == _contentListOffsetPosition.startPos
            contentOffsetY = 0;
        }
    }
    
    NSInteger section = [self _sectionAtContentOffsetY:contentOffsetY];
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    NSInteger row = [sectionPosition rowAtContentOffsetY:contentOffsetY];
    return _NSIndexPathMakeStruct(section, row);
}

- (MPTableViewCell *)_getCellFromDataSourceAtIndexPath:(NSIndexPath *)indexPath {
    MPTableViewCell *cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
    if (!cell) {
        MPTV_EXCEPTION(@"cell must not be nil")
    }
    
    return cell;
}

- (CGRect)_cellFrameAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return CGRectZero;
    }
    MPTableViewSection *section = _sectionsArray[indexPath.section];
    CGFloat startPos = [section positionStartAtRow:indexPath.row];
    CGFloat endPos = [section positionEndAtRow:indexPath.row];
    
    CGRect frame;
    frame.origin.x = 0;
    frame.origin.y = startPos + _contentListPosition.startPos;
    frame.size.height = endPos - startPos;
    frame.size.width = self.bounds.size.width;
    return frame;
}

- (MPTableReusableView *)_getSectionViewFromDataSourceInSection:(NSUInteger)section withType:(MPSectionViewType)type {
    MPTableReusableView *sectionView = nil;
    if (MPTV_IS_HEADER(type)) {
        if (_respond_viewForHeaderInSection) {
            sectionView = [_mpDataSource MPTableView:self viewForHeaderInSection:section];
        }
    } else {
        if (_respond_viewForFooterInSection) {
            sectionView = [_mpDataSource MPTableView:self viewForFooterInSection:section];
        }
    }
    
    return sectionView;
}

- (CGRect)_sectionViewFrameInSection:(NSUInteger)section withType:(MPSectionViewType)type {
    CGRect sectionViewFrame;
    MPTableViewSection *sectionPosition = _sectionsArray[section];
    if (MPTV_IS_HEADER(type)) {
        sectionViewFrame.origin.y = sectionPosition.startPos + _contentListPosition.startPos;
        sectionViewFrame.size.height = sectionPosition.headerHeight;
    } else {
        sectionViewFrame.origin.y = sectionPosition.endPos - sectionPosition.footerHeight + _contentListPosition.startPos;
        sectionViewFrame.size.height = sectionPosition.footerHeight;
    }
    sectionViewFrame.origin.x = 0;
    sectionViewFrame.size.width = self.bounds.size.width;
    
    return sectionViewFrame;
}

- (void)_displaySectionViewIfNeededAtIndexPath:(NSIndexPath *)indexPath {
    if (_style == MPTableViewStylePlain || [self isUpdating]) {
        if (![_displayedSectionViewsDic objectForKey:indexPath]) {
            [self _displaySectionViewAtIndexPath:indexPath];
        }
    } else {
        if (_NSIndexPathCompareStruct(indexPath, _beginIndexPath) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, _endIndexPath) == NSOrderedDescending) {
            [self _displaySectionViewAtIndexPath:indexPath];
        }
    }
}

- (MPTableReusableView *)_displaySectionViewAtIndexPath:(NSIndexPath *)indexPath {
    MPTableReusableView *sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:indexPath.row];
    if (sectionView) {
        [self _addSubviewIfNecessaryFromSectionView:sectionView];
        CGRect frame = [self _sectionViewFrameInSection:indexPath.section withType:indexPath.row];
        MPSetViewFrameWithoutAnimation(sectionView, frame);
        
        if (MPTV_IS_HEADER(indexPath.row)) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    }
    
    return sectionView;
}

- (void)_displaySectionViewToPrepareToSuspendInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(type, section.section);
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    
    if (!sectionView) {
        sectionView = [self _getSectionViewFromDataSourceInSection:indexPath.section withType:indexPath.row];
        if (!sectionView) {
            return;
        }
        
        [self _addSubviewIfNecessaryFromSectionView:sectionView];
        if (MPTV_IS_HEADER(type)) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    }
    
    CGRect frame = [self _prepareToSuspendFrameInSection:section withType:type];
    MPSetViewFrameWithoutAnimation(sectionView, frame);
}

- (void)_addSubviewIfNecessaryFromCell:(MPTableViewCell *)cell {
    if ([cell superview] != _contentWrapperView) {
        if (_dragModeDragCell) {
            [_contentWrapperView insertSubview:cell belowSubview:_dragModeDragCell];
        } else {
            [_contentWrapperView addSubview:cell];
        }
    }
}

- (void)_addSubviewIfNecessaryFromSectionView:(MPTableReusableView *)sectionView {
    if ([sectionView superview] != self) {
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
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
        [cell setHighlighted:NO];
        [cell setSelected:NO];
    } else {
        [cell removeFromSuperview];
    }
}

- (void)_clipCellsBetweenBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    
    for (NSIndexPath *indexPath in _displayedCellsDic.allKeys) {
        if (_NSIndexPathCompareStruct(indexPath, beginIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, endIndexPathStruct) == NSOrderedDescending) {
            if (_draggedIndexPath) {
                if ([indexPath compare:_draggedIndexPath] == NSOrderedSame) {
                    continue;
                }
            } else if (isUpdating && [_updateAnimatedOffscreenIndexPaths containsObject:indexPath]) {
                continue;
            }
            
            MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
            
            [self _cacheCell:cell];
            [_displayedCellsDic removeObjectForKey:indexPath];
            
            if (_respond_didEndDisplayingCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
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
        sectionView.hidden = YES;
        [queue addObject:sectionView];
    } else {
        [sectionView removeFromSuperview];
    }
}

- (void)_clipSectionViewsBetweenBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    BOOL isUpdating = [self isUpdating];
    
    for (NSIndexPath *indexPath in _displayedSectionViewsDic.allKeys) {
        MPSectionViewType type = indexPath.row;
        
        if (_style == MPTableViewStylePlain) {
            if ([self _isSuspendingSection:indexPath.section withType:indexPath.row]) {
                continue;
            }
            
            MPTableViewSection *section = _sectionsArray[indexPath.section];
            if ([self _needToPrepareToSuspendViewInSection:section withType:type]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                CGRect frame = [self _prepareToSuspendFrameInSection:section withType:type];
                MPSetViewFrameWithoutAnimation(sectionView, frame);
                continue;
            } else if (_NSIndexPathCompareStruct(indexPath, beginIndexPathStruct) != NSOrderedAscending && _NSIndexPathCompareStruct(indexPath, endIndexPathStruct) != NSOrderedDescending) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                CGRect frame = sectionView.frame;
                frame.origin.y -= _contentListPosition.startPos;
                if (MPTV_IS_HEADER(type)) { // if there are two or more headers prepare to suspend, and then we have changed the contentOffset (not animated), these headers may need to be reset.
                    if (frame.origin.y != section.startPos) {
                        frame.origin.y = section.startPos + _contentListPosition.startPos;
                        MPSetViewFrameWithoutAnimation(sectionView, frame);
                    }
                } else {
                    if (frame.origin.y != section.endPos - section.footerHeight) {
                        frame.origin.y = section.endPos - section.footerHeight + _contentListPosition.startPos;
                        MPSetViewFrameWithoutAnimation(sectionView, frame);
                    }
                }
                continue;
            }
        }
        if (_NSIndexPathCompareStruct(indexPath, beginIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, endIndexPathStruct) == NSOrderedDescending) {
            if (!_draggedIndexPath && isUpdating && [_updateAnimatedOffscreenIndexPaths containsObject:indexPath]) {
                continue;
            }
            
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            [self _cacheSectionView:sectionView];
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            if (_respond_didEndDisplayingHeaderViewForSection && MPTV_IS_HEADER(type)) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
            }
            if (_respond_didEndDisplayingFooterViewForSection && MPTV_IS_FOOTER(type)) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
            }
        }
    }
}

- (void)_clipAndAdjustSectionViewsBetweenBeginIndexPath:(NSIndexPathStruct)beginIndexPathStruct andEndIndexPath:(NSIndexPathStruct)endIndexPathStruct {
    NSArray *indexPaths = _displayedSectionViewsDic.allKeys;
    BOOL isUpdating = [self isUpdating];
    
    for (NSIndexPath *indexPath in indexPaths) {
        MPSectionViewType type = indexPath.row;
        
        if (_style == MPTableViewStylePlain) {
            MPTableViewSection *section = _sectionsArray[indexPath.section];
            if ([self _needToSuspendViewInSection:section withType:type]) {
                [self _setSuspendingSection:indexPath.section withType:type];
                
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                CGRect frame = [self _suspendingFrameInSection:section withType:type];
                MPSetViewFrameWithoutAnimation(sectionView, frame);
                continue;
            } else if ([self _needToPrepareToSuspendViewInSection:section withType:type]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                CGRect frame = [self _prepareToSuspendFrameInSection:section withType:type];
                MPSetViewFrameWithoutAnimation(sectionView, frame);
                continue;
            }
        }
        
        if (_NSIndexPathCompareStruct(indexPath, beginIndexPathStruct) == NSOrderedAscending || _NSIndexPathCompareStruct(indexPath, endIndexPathStruct) == NSOrderedDescending) {
            if (!_draggedIndexPath && isUpdating && [_updateAnimatedOffscreenIndexPaths containsObject:indexPath]) {
                continue;
            }
            
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            [self _cacheSectionView:sectionView];
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            
            if (_respond_didEndDisplayingHeaderViewForSection && MPTV_IS_HEADER(type)) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
            }
            if (_respond_didEndDisplayingFooterViewForSection && MPTV_IS_FOOTER(type)) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
            }
        } else { // for real-time update (scroll the table view when it is updating)
            MPTableViewSection *section = _sectionsArray[indexPath.section];
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            CGRect frame = sectionView.frame;
            
            frame.origin.y -= _contentListPosition.startPos;
            if (MPTV_IS_HEADER(type)) {
                if (frame.origin.y != section.startPos) {
                    frame.origin.y = section.startPos + _contentListPosition.startPos;
                    MPSetViewFrameWithoutAnimation(sectionView, frame);
                }
            } else {
                if (frame.origin.y != section.endPos - section.footerHeight) {
                    frame.origin.y = section.endPos - section.footerHeight + _contentListPosition.startPos;
                    MPSetViewFrameWithoutAnimation(sectionView, frame);
                }
            }
        }
    }
}

- (BOOL)_isSuspendingSection:(NSUInteger)section withType:(MPSectionViewType)type {
    if (MPTV_IS_HEADER(type)) {
        return section == _suspendingHeaderSection;
    } else {
        return section == _suspendingFooterSection;
    }
}

- (void)_setSuspendingSection:(NSUInteger)section withType:(MPSectionViewType)type {
    if (MPTV_IS_HEADER(type)) {
        _suspendingHeaderSection = section;
    } else {
        _suspendingFooterSection = section;
    }
}

- (BOOL)_needToSuspendViewInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    UIEdgeInsets contentInset = [self _innerContentInset];
    
    if (MPTV_IS_HEADER(type)) {
        if ((contentInset.top < 0 && -contentInset.top > section.headerHeight) || _contentOffsetPosition.startPos + contentInset.top >= _contentOffsetPosition.endPos) {
            return NO;
        }
        
        CGFloat contentStart = _contentListOffsetPosition.startPos + contentInset.top;
        if (section.headerHeight > 0 && section.startPos <= contentStart && section.endPos - section.footerHeight - section.headerHeight >= contentStart) {
            return YES;
        } else {
            return NO;
        }
    } else {
        if ((contentInset.bottom < 0 && -contentInset.bottom > section.footerHeight) || _contentOffsetPosition.endPos - contentInset.bottom <= _contentOffsetPosition.startPos) {
            return NO;
        }
        
        CGFloat contentEnd = _contentListOffsetPosition.endPos - contentInset.bottom;
        if (section.footerHeight > 0 && section.endPos >= contentEnd && section.startPos + section.headerHeight + section.footerHeight <= contentEnd) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (CGRect)_suspendingFrameInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    CGRect frame;
    frame.origin.x = 0;
    frame.size.width = self.bounds.size.width;
    if (MPTV_IS_HEADER(type)) {
        frame.size.height = section.headerHeight;
        
        frame.origin.y = _contentListOffsetPosition.startPos + [self _innerContentInset].top;
        if (CGRectGetMaxY(frame) > section.endPos - section.footerHeight) {
            if (frame.origin.y != section.endPos - section.footerHeight - frame.size.height) {
                frame.origin.y = section.endPos - section.footerHeight - frame.size.height;
            }
        }
        if (frame.origin.y < section.startPos) {
            if (frame.origin.y != section.startPos) {
                frame.origin.y = section.startPos;
            }
        }
    } else {
        frame.size.height = section.footerHeight;
        
        frame.origin.y = _contentListOffsetPosition.endPos - frame.size.height - [self _innerContentInset].bottom;
        if (frame.origin.y < section.startPos + section.headerHeight) {
            if (frame.origin.y != section.startPos + section.headerHeight) {
                frame.origin.y = section.startPos + section.headerHeight;
            }
        }
        if (CGRectGetMaxY(frame) > section.endPos) {
            if (frame.origin.y != section.endPos - section.footerHeight) {
                frame.origin.y = section.endPos - section.footerHeight;
            }
        }
    }
    frame.origin.y += _contentListPosition.startPos;
    
    return frame;
}

- (BOOL)_needToPrepareToSuspendViewInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (MPTV_IS_HEADER(type)) {
        if (_contentOffsetPosition.startPos + contentInset.top >= _contentOffsetPosition.endPos) {
            return NO;
        }
        
        CGFloat contentStart = _contentListOffsetPosition.startPos + contentInset.top;
        if (section.headerHeight > 0 && section.endPos - section.footerHeight - section.headerHeight < contentStart && section.endPos - section.footerHeight >= _contentListOffsetPosition.startPos) {
            return YES;
        } else {
            return NO;
        }
    } else {
        if (_contentOffsetPosition.endPos - contentInset.bottom <= _contentOffsetPosition.startPos) {
            return NO;
        }
        
        CGFloat contentEnd = _contentListOffsetPosition.endPos - contentInset.bottom;
        if (section.footerHeight > 0 && section.startPos + section.headerHeight + section.footerHeight > contentEnd && section.startPos + section.headerHeight <= _contentListOffsetPosition.endPos) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (CGRect)_prepareToSuspendFrameInSection:(MPTableViewSection *)section withType:(MPSectionViewType)type {
    if (MPTV_IS_HEADER(type)) {
        return CGRectMake(0, section.endPos - section.footerHeight - section.headerHeight + _contentListPosition.startPos, self.bounds.size.width, section.headerHeight);
    } else {
        return CGRectMake(0, section.startPos + section.headerHeight + _contentListPosition.startPos, self.bounds.size.width, section.footerHeight);
    }
}

- (void)_resetSectionHeaderPosition {
    if (_suspendingHeaderSection == NSNotFound) {
        return;
    }
    
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(MPSectionHeader, _suspendingHeaderSection);
    UIView *lastSuspendHeader = [_displayedSectionViewsDic objectForKey:indexPath];
    if (lastSuspendHeader) {
        MPTableViewSection *lastSection = _sectionsArray[indexPath.section];
        CGRect frame = lastSuspendHeader.frame;
        if ([self _needToPrepareToSuspendViewInSection:lastSection withType:MPSectionHeader]) {
            frame.origin.y = lastSection.endPos - lastSection.footerHeight - lastSection.headerHeight;
        } else {
            frame.origin.y = lastSection.startPos;
        }
        frame.origin.y += _contentListPosition.startPos;
        MPSetViewFrameWithoutAnimation(lastSuspendHeader, frame);
    }
    _suspendingHeaderSection = NSNotFound;
}

- (void)_suspendSectionHeaderIfNeededInSection:(NSInteger)section {
    if (section < 0 || section >= MPTV_MAXCOUNT) {
        if (_suspendingHeaderSection != NSNotFound) {
            [self _resetSectionHeaderPosition];
        }
        return;
    }
    
    MPTableViewSection *sectionPosition;
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (contentInset.top != 0) {
        CGFloat contentOffsetY = _contentListOffsetPosition.startPos + contentInset.top;
        if (contentOffsetY > _contentListPosition.endPos - _contentListPosition.startPos) {
            contentOffsetY = _contentListPosition.endPos - _contentListPosition.startPos;
        }
        if (contentOffsetY < 0) {
            contentOffsetY = 0;
        }
        sectionPosition = _sectionsArray[[self _sectionAtContentOffsetY:contentOffsetY]];
    } else {
        sectionPosition = _sectionsArray[section];
    }
    
    if ([self _needToSuspendViewInSection:sectionPosition withType:MPSectionHeader]) {
        if (_suspendingHeaderSection != sectionPosition.section) {
            [self _resetSectionHeaderPosition];
            _suspendingHeaderSection = sectionPosition.section;
        }
    } else {
        [self _resetSectionHeaderPosition];
        return;
    }
    
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(MPSectionHeader, _suspendingHeaderSection);
    UIView *suspendingHeader = [_displayedSectionViewsDic objectForKey:indexPath];
    if (!suspendingHeader) {
        suspendingHeader = [self _displaySectionViewAtIndexPath:indexPath];
    }
    
    CGRect frame = [self _suspendingFrameInSection:sectionPosition withType:MPSectionHeader];
    MPSetViewFrameWithoutAnimation(suspendingHeader, frame);
}

- (void)_resetSectionFooterPosition {
    if (_suspendingFooterSection == NSNotFound) {
        return;
    }
    
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(MPSectionFooter, _suspendingFooterSection);
    
    UIView *lastSuspendFooter = [_displayedSectionViewsDic objectForKey:indexPath];
    if (lastSuspendFooter) {
        MPTableViewSection *lastSection = _sectionsArray[indexPath.section];
        CGRect frame = lastSuspendFooter.frame;
        if ([self _needToPrepareToSuspendViewInSection:lastSection withType:MPSectionFooter]) {
            frame.origin.y = lastSection.startPos + lastSection.headerHeight;
        } else {
            frame.origin.y = lastSection.endPos - lastSection.footerHeight;
        }
        frame.origin.y += _contentListPosition.startPos;
        MPSetViewFrameWithoutAnimation(lastSuspendFooter, frame);
    }
    _suspendingFooterSection = NSNotFound;
}

- (void)_suspendSectionFooterIfNeededInSection:(NSInteger)section {
    if (section < 0 || section >= MPTV_MAXCOUNT) {
        if (_suspendingFooterSection != NSNotFound) {
            [self _resetSectionFooterPosition];
        }
        return;
    }
    
    MPTableViewSection *sectionPosition;
    UIEdgeInsets contentInset = [self _innerContentInset];
    if (contentInset.bottom != 0) {
        CGFloat contentOffsetY = _contentListOffsetPosition.endPos - contentInset.bottom;
        if (contentOffsetY > _contentListPosition.endPos - _contentListPosition.startPos) {
            contentOffsetY = _contentListPosition.endPos - _contentListPosition.startPos;
        }
        sectionPosition = _sectionsArray[[self _sectionAtContentOffsetY:contentOffsetY]];
    } else {
        sectionPosition = _sectionsArray[section];
    }
    
    if ([self _needToSuspendViewInSection:sectionPosition withType:MPSectionFooter]) {
        if (_suspendingFooterSection != sectionPosition.section) {
            [self _resetSectionFooterPosition];
            _suspendingFooterSection = sectionPosition.section;
        }
    } else {
        [self _resetSectionFooterPosition];
        return;
    }
    
    NSIndexPath *indexPath = _NSIndexPathPrivateForRowSection(MPSectionFooter, _suspendingFooterSection);
    UIView *suspendingFooter = [_displayedSectionViewsDic objectForKey:indexPath];
    if (!suspendingFooter) {
        suspendingFooter = [self _displaySectionViewAtIndexPath:indexPath];
    }
    
    CGRect frame = [self _suspendingFrameInSection:sectionPosition withType:MPSectionFooter];
    MPSetViewFrameWithoutAnimation(suspendingFooter, frame);
}

#pragma mark - prefetch

const NSUInteger MPPrefetchCount = 10; // fixed
const NSUInteger MPPrefetchDetectLength = 15; // fixed

- (NSIndexPathStruct)_prefetchBeginIndexPath {
    NSIndexPathStruct indexPathStruct = _beginIndexPath;
    if (MPTV_IS_HEADER(indexPathStruct.row)) {
        indexPathStruct.row = -1;
    } else if (MPTV_IS_FOOTER(indexPathStruct.row)) {
        MPTableViewSection *section = _sectionsArray[indexPathStruct.section];
        if (section.numberOfRows) {
            indexPathStruct.row = section.numberOfRows;
        } else {
            indexPathStruct.row = -1;
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
    if (!_prefetchDataSource || !_numberOfSections || _beginIndexPath.section == NSIntegerMax || _endIndexPath.section == NSIntegerMin) {
        return;
    }
    
    BOOL scrollDirectionUp = _contentOffsetPosition.startPos < _previousContentOffsetY;
    @autoreleasepool {
        NSMutableArray *prefetchUpIndexPaths = [[NSMutableArray alloc] init];
        NSMutableArray *prefetchDownIndexPaths = [[NSMutableArray alloc] init];
        
        NSIndexPathStruct prefetchBeginIndexPath = [self _prefetchBeginIndexPath];
        for (NSInteger i = 0; i < MPPrefetchDetectLength; i++) {
            if (prefetchBeginIndexPath.row > 0) {
                --prefetchBeginIndexPath.row;
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
            if (scrollDirectionUp && i < MPPrefetchCount) {
                NSIndexPath *indexPath = _NSIndexPathFromStruct(prefetchBeginIndexPath);
                if (![_prefetchIndexPaths containsObject:indexPath]) {
                    [prefetchUpIndexPaths addObject:indexPath];
                }
            }
        }
        
        NSIndexPathStruct prefetchEndIndexPath = [self _prefetchEndIndexPath];
        NSUInteger numberOfSections = _sectionsArray.count; // necessary
        
        for (NSInteger i = 0; i < MPPrefetchDetectLength; i++) {
            MPTableViewSection *section = _sectionsArray[prefetchEndIndexPath.section];
            if (prefetchEndIndexPath.row + 1 < section.numberOfRows) {
                ++prefetchEndIndexPath.row;
            } else {
                while (prefetchEndIndexPath.section + 1 < numberOfSections) {
                    section = _sectionsArray[++prefetchEndIndexPath.section];
                    if (section.numberOfRows > 0) {
                        prefetchEndIndexPath.row = 0;
                        goto _prefetch_down;
                    }
                }
                break;
            }
            
        _prefetch_down:
            if (!scrollDirectionUp && i < MPPrefetchCount) {
                NSIndexPath *indexPath = _NSIndexPathFromStruct(prefetchEndIndexPath);
                if (![_prefetchIndexPaths containsObject:indexPath]) {
                    [prefetchDownIndexPaths addObject:indexPath];
                }
            }
        }
        
        if (prefetchUpIndexPaths.count || prefetchDownIndexPaths.count) {
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
            }
        }
        
        [_prefetchIndexPaths removeObjectsInArray:discardIndexPaths];
        [_prefetchIndexPaths removeObjectsInArray:cancelPrefetchIndexPaths];
        
        if (_respond_cancelPrefetchingForRowsAtIndexPaths && cancelPrefetchIndexPaths.count) {
            [_prefetchDataSource MPTableView:self cancelPrefetchingForRowsAtIndexPaths:cancelPrefetchIndexPaths];
        }
    }
    
    _previousContentOffsetY = _contentOffsetPosition.startPos;
}

#pragma mark - select

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (_highlightedIndexPath || _draggedIndexPath) {
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
    
    NSIndexPath *touchedIndexPath = _NSIndexPathFromStruct([self _indexPathAtContentOffsetY:locationY - _contentListPosition.startPos]);
    
    if (MPTV_IS_HEADER(touchedIndexPath.row) || MPTV_IS_FOOTER(touchedIndexPath.row)) {
        return;
    }
    
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
    
    if (_respond_shouldHighlightRowAtIndexPath && ![_mpDelegate MPTableView:self shouldHighlightRowAtIndexPath:touchedIndexPath]) {
        return;
    }
    
    _highlightedIndexPath = touchedIndexPath;
    
    if (![cell isHighlighted]) {
        [cell setHighlighted:YES];
    }
    
    if (_respond_didHighlightRowAtIndexPath) {
        [_mpDelegate MPTableView:self didHighlightRowAtIndexPath:touchedIndexPath];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self _unhighlightCellIfNeeded];
}

- (void)_unhighlightCellIfNeeded {
    if (!_highlightedIndexPath) {
        return;
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
    
    if ([cell isHighlighted]) {
        [cell setHighlighted:NO];
    }
    
    if (_respond_didUnhighlightRowAtIndexPath) {
        [_mpDelegate MPTableView:self didUnhighlightRowAtIndexPath:_highlightedIndexPath];
    }
    
    _highlightedIndexPath = nil;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    if (!_highlightedIndexPath || !_allowsSelection) {
        return;
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
    if (!cell) {
        _highlightedIndexPath = nil;
        return;
    }
    MPTableViewCell *highlightedCell = cell;
    BOOL needToNotify = NO;
    
    if (_respond_willSelectRowAtIndexPath) {
        NSIndexPath *indexPath = [_mpDelegate MPTableView:self willSelectRowAtIndexPath:_highlightedIndexPath];
        if (!indexPath) {
            goto _select_unhighlight;
        }
        
        if (![_highlightedIndexPath isEqual:indexPath]) {
            cell = [_displayedCellsDic objectForKey:_highlightedIndexPath = indexPath];
        }
    }
    
    if (_allowsMultipleSelection && [_selectedIndexPaths containsObject:_highlightedIndexPath]) {
        [self _deselectRowAtIndexPath:_highlightedIndexPath animated:NO selectedIndexPathRemoved:YES];
    } else {
        needToNotify = YES;
        if (!_allowsMultipleSelection) {
            for (NSIndexPath *indexPath in _selectedIndexPaths.allObjects) {
                if ([indexPath isEqual:_highlightedIndexPath]) {
                    needToNotify = NO;
                    continue;
                }
                [self _deselectRowAtIndexPath:indexPath animated:NO selectedIndexPathRemoved:YES];
            }
        }
        
        [_selectedIndexPaths addObject:_highlightedIndexPath];
        
        [cell setSelected:YES];
        
        if (_respond_didSelectRowForCellAtIndexPath) {
            [_mpDelegate MPTableView:self didSelectRowForCell:cell atIndexPath:_highlightedIndexPath];
        }
    }
    
_select_unhighlight:
    if ([highlightedCell isHighlighted]) {
        [highlightedCell setHighlighted:NO];
    }
    
    if (_respond_didUnhighlightRowAtIndexPath) {
        [_mpDelegate MPTableView:self didUnhighlightRowAtIndexPath:_highlightedIndexPath];
    }
    _highlightedIndexPath = nil;
    if (needToNotify) {
        [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    
    [self _unhighlightCellIfNeeded];
}

#pragma mark - drag

NS_INLINE CGPoint
MPPointsSubtraction(CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x - point2.x, point1.y - point2.y);
}

//NS_INLINE CGPoint
//MPPointsAddition(CGPoint point1, CGPoint point2) {
//    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
//}

- (NSIndexPath *)indexPathForDragCell {
    return _draggedIndexPath;
}

- (BOOL)_hasDragCell {
    return _dragModeDragCell ? YES : NO;
}

- (BOOL)isDragModeEnabled {
    return _dragModeEnabled;
}

- (void)setDragModeEnabled:(BOOL)dragModeEnabled {
    if (_dragModeEnabled == dragModeEnabled) {
        return;
    }
    
    if (!dragModeEnabled) {
        [self _endDragCellIfNeededImmediately:NO];
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
    [_contentWrapperView addGestureRecognizer:_dragModeLongGestureRecognizer];
}

- (void)setMinimumPressDurationForDrag:(CFTimeInterval)minimumPressDurationForDrag {
    [self _setupDragModeLongGestureRecognizerIfNeeded];
    _dragModeLongGestureRecognizer.minimumPressDuration = _minimumPressDurationForDrag = minimumPressDurationForDrag;
}

- (BOOL)_mp_gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([self isUpdating]) {
        NSAssert(NO, @"can not start dragging a cell when table view is updating");
        return NO;
    }
    
    CGPoint location = [gestureRecognizer locationInView:_contentWrapperView];
    [self _startDraggingCellAtLocation:location];
    
    return _draggedIndexPath ? YES : NO;
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
            [self _endDragCellIfNeededImmediately:NO];
        }
            break;
        case UIGestureRecognizerStateCancelled: {
            [self _endDragCellIfNeededImmediately:NO];
        }
            break;
        case UIGestureRecognizerStateFailed: {
            [self _endDragCellIfNeededImmediately:NO];
        }
            break;
        default:
            [self _endDragCellIfNeededImmediately:NO];
            break;
    }
}

- (void)_startDraggingCellAtLocation:(CGPoint)location {
    [self _endDragCellIfNeededImmediately:NO];
    
    CGFloat locationY = location.y;
    if (locationY < _contentListPosition.startPos || locationY > _contentListPosition.endPos) {
        return;
    }
    
    NSIndexPath *touchedIndexPath = _NSIndexPathFromStruct([self _indexPathAtContentOffsetY:locationY - _contentListPosition.startPos]);
    if (MPTV_IS_HEADER(touchedIndexPath.row) || MPTV_IS_FOOTER(touchedIndexPath.row)) {
        return;
    }
    
    _updateSubviewsLock = YES;
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:touchedIndexPath];
    
    if (_respond_canMoveRowAtIndexPath && ![_mpDataSource MPTableView:self canMoveRowAtIndexPath:touchedIndexPath]) {
        goto _drag_unlock_layout;
    }
    
    if (_respond_rectForCellToMoveRowAtIndexPath && ![self _rectForCell:cell toMoveRowAtIndexPath:touchedIndexPath availableAtLocation:location]) {
        goto _drag_unlock_layout;
    }
    
    _dragModeDragCell = cell;
    _draggedSourceIndexPath = _draggedIndexPath = touchedIndexPath;
    _dragModeMinuendPoint = MPPointsSubtraction(location, _dragModeDragCell.center);
    
    [_contentWrapperView bringSubviewToFront:_dragModeDragCell];
    
    [self _setupDragModeAutoScrollDisplayLinkIfNeeded];
    
    if (_respond_shouldMoveRowAtIndexPath) {
        [_mpDelegate MPTableView:self shouldMoveRowAtIndexPath:touchedIndexPath];
    }
    
_drag_unlock_layout:
    _updateSubviewsLock = NO;
}

- (BOOL)_rectForCell:(MPTableViewCell *)cell toMoveRowAtIndexPath:(NSIndexPath *)indexPath availableAtLocation:(CGPoint)location {
    CGRect touchEnabledFrame = [_mpDataSource MPTableView:self rectForCellToMoveRowAtIndexPath:indexPath];
    
    return CGRectContainsPoint(touchEnabledFrame, [cell convertPoint:location fromView:_contentWrapperView]);
}

- (void)_setupDragModeAutoScrollDisplayLinkIfNeeded {
    if (!_dragModeAutoScrollDisplayLink) {
        _dragModeAutoScrollDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_dragModeBoundsAutoScrollAction)];
        [_dragModeAutoScrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    [self _dragModeBoundsAutoScrollIfNeeded];
}

- (void)_dragCellToLocation:(CGPoint)location {
    [self _setDragCellCenter:MPPointsSubtraction(location, _dragModeMinuendPoint)];
    
    [self _dragModeBoundsAutoScrollIfNeeded];
    
    [self _setContentOffsetPositions];
    _updateSubviewsLock = YES;
    [self _layoutSubviewsIfNeeded];
    [self _prefetchIndexPathsIfNeeded];
    _updateSubviewsLock = NO;
    
    location = _dragModeDragCell.center;
    [self _dragAndMoveCellToLocationY:location.y];
}

- (void)_setDragCellCenter:(CGPoint)center {
    if (!_dragCellFloating) {
        center.x = self.bounds.size.width / 2;
        if (center.y < _contentListPosition.startPos) {
            center.y = _contentListPosition.startPos;
        }
        if (center.y > _contentListPosition.endPos) {
            center.y = _contentListPosition.endPos;
        }
    }
    
    _dragModeDragCell.center = center;
}

- (void)_dragModeBoundsAutoScrollAction {
    CGPoint newPoint = self.contentOffset;
    newPoint.y += _dragModeScrollRate;
    
    if (_dragModeScrollRate < 0) {
        if (newPoint.y < -[self _innerContentInset].top) {
            newPoint.y = -[self _innerContentInset].top;
            _dragModeAutoScrollDisplayLink.paused = YES;
        }
    } else if (_dragModeScrollRate > 0) {
        if (newPoint.y + self.bounds.size.height > self.contentSize.height + [self _innerContentInset].bottom) {
            newPoint.y = self.contentSize.height + [self _innerContentInset].bottom - self.bounds.size.height;
            _dragModeAutoScrollDisplayLink.paused = YES;
        }
    }
    
    self.contentOffset = newPoint;
    
    newPoint.x = _dragModeDragCell.center.x;
    newPoint.y -= _dragModeOffsetDistance;
    [self _setDragCellCenter:newPoint];
    
    [self _setContentOffsetPositions];
    _updateSubviewsLock = YES;
    [self _layoutSubviewsIfNeeded];
    [self _prefetchIndexPathsIfNeeded];
    _updateSubviewsLock = NO;
    
    [self _dragAndMoveCellToLocationY:newPoint.y];
}

- (void)_dragModeBoundsAutoScrollIfNeeded {
    _dragModeScrollRate = 0;
    
    if (_dragModeDragCell.frame.origin.y < _contentOffsetPosition.startPos + [self _innerContentInset].top) {
        if (_contentOffsetPosition.startPos > -[self _innerContentInset].top) {
            _dragModeScrollRate = _dragModeDragCell.frame.origin.y - _contentOffsetPosition.startPos - [self _innerContentInset].top;
            _dragModeScrollRate /= 10;
        }
    } else if (CGRectGetMaxY(_dragModeDragCell.frame) > _contentOffsetPosition.endPos - [self _innerContentInset].bottom) {
        if (_contentOffsetPosition.endPos < self.contentSize.height + [self _innerContentInset].bottom) {
            _dragModeScrollRate = CGRectGetMaxY(_dragModeDragCell.frame) - _contentOffsetPosition.endPos + [self _innerContentInset].bottom;
            _dragModeScrollRate /= 10;
        }
    }
    
    _dragModeOffsetDistance = _contentOffsetPosition.startPos - _dragModeDragCell.center.y;
    _dragModeAutoScrollDisplayLink.paused = !_dragModeScrollRate;
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
        newIndexPathStruct.row = 0;
    } else if (MPTV_IS_FOOTER(newIndexPathStruct.row)) {
        if (newIndexPathStruct.section == _draggedIndexPath.section) {
            return;
        }
        newIndexPathStruct.row = [self numberOfRowsInSection:newIndexPathStruct.section];
    } else {
        MPTableViewSection *section = _sectionsArray[newIndexPathStruct.section];
        CGFloat startPos = [section positionStartAtRow:newIndexPathStruct.row];
        CGFloat endPos = [section positionEndAtRow:newIndexPathStruct.row];
        CGFloat targetCenterY = startPos + (endPos - startPos) / 2 + _contentListPosition.startPos;
        
        if (targetCenterY < _dragModeDragCell.frame.origin.y || targetCenterY > CGRectGetMaxY(_dragModeDragCell.frame)) { // drag cell must move across the center.y of the target cell
            return;
        }
    }
    
    if (_NSIndexPathCompareStruct(_draggedIndexPath, newIndexPathStruct) == NSOrderedSame) {
        return;
    }
    
    if ([self _isEstimatedMode] && (_NSIndexPathStructCompareStruct(newIndexPathStruct, _beginIndexPath) == NSOrderedAscending || _NSIndexPathStructCompareStruct(newIndexPathStruct, _endIndexPath) == NSOrderedDescending)) {
        return; // this cell's height may not has been estimated, or we should make a complete update, but that's too much trouble.
    }
    
    NSIndexPath *newIndexPath = _NSIndexPathFromStruct(newIndexPathStruct);
    
    if (_respond_canMoveRowToIndexPath && ![_mpDataSource MPTableView:self canMoveRowToIndexPath:newIndexPath]) {
        return;
    }
    
    [self _clipCellsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    [self _clipAndAdjustSectionViewsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
    
    MPTableViewUpdateManager *updateManager = [self _getUpdateManagerFromStack];
    updateManager.dragFromSection = _draggedIndexPath.section;
    updateManager.dragToSection = newIndexPath.section;
    [updateManager addMoveOutIndexPath:_draggedIndexPath];
    [updateManager addMoveInIndexPath:newIndexPath withFrame:[self _cellFrameAtIndexPath:_draggedIndexPath] withLastIndexPath:_draggedIndexPath];
    _draggedIndexPath = newIndexPath;
    
    [self _startUpdateAnimationWithUpdateManager:updateManager duration:MPTableViewDefaultAnimationDuration delay:0 completion:nil];
}

- (void)_endDragCellIfNeededImmediately:(BOOL)immediately {
    /*
     for a situation like:
     tableView.dragModeEnabled = NO;
     [tableView reloadData];
     */
    if (!_dragModeAutoScrollDisplayLink) {
        if (immediately) {
            if (!_dragModeDragCell) {
                return;
            }
        } else {
            return;
        }
    }
    
    NSIndexPath *sourceIndexPath = _draggedSourceIndexPath;
    NSIndexPath *indexPathForDragCell = _draggedIndexPath;
    
    if (_dragModeAutoScrollDisplayLink) {
        [_dragModeAutoScrollDisplayLink invalidate];
        _dragModeAutoScrollDisplayLink = nil;
        
        if (_respond_moveRowAtIndexPathToIndexPath) {
            [_mpDataSource MPTableView:self moveRowAtIndexPath:sourceIndexPath toIndexPath:indexPathForDragCell];
        }
    }
    
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (!_dragModeDragCell) {
            return;
        }
        
        if (indexPathForDragCell == _draggedIndexPath) {
            _draggedSourceIndexPath = _draggedIndexPath = nil;
            _dragModeDragCell = nil;
        }
        
        if (_respond_didEndMoveRowAtIndexPathToIndexPath) {
            [_mpDelegate MPTableView:self didEndMoveRowAtIndexPath:sourceIndexPath toIndexPath:indexPathForDragCell];
        }
        
        if (!immediately) {
            [self _clipCellsBetweenBeginIndexPath:_beginIndexPath andEndIndexPath:_endIndexPath];
        }
    };
    
    if (immediately) {
        completion(NO);
    } else {
        [UIView animateWithDuration:MPTableViewDefaultAnimationDuration animations:^{
            CGRect frame = [self _cellFrameAtIndexPath:indexPathForDragCell];
            _dragModeDragCell.center = CGPointMake(frame.size.width / 2, (CGRectGetMaxY(frame) - frame.origin.y) / 2 + frame.origin.y);
        } completion:completion];
    }
}

@end
