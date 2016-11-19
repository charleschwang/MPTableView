//
//  MPTableView.m
//  mushu
//
//  Created by Charles on 15/6/19.
//  Copyright (c) 2015年 PBA. All rights reserved.
//

#import "MPTableView.h"
#import "MPTableViewSection.h"

//
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
//
//NS_INLINE BOOL
//_outofRange(NSUInteger target, NSRange range) {
//    return (target < range.location || target > range.location + range.length - 1) || range.length < 1;
//}

MPIndexPathStruct MPIndexPathStructMake(NSInteger section, NSInteger row) {
    MPIndexPathStruct indexPath;
    indexPath.section = section;
    indexPath.row = row;
    return indexPath;
}

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

@implementation MPIndexPath (MPTableView)

+ (MPIndexPath *)indexPathForRow:(NSInteger)row inSection:(NSInteger)section {
    NSInteger indexes[2] = {section, row};
    MPIndexPath *indexPath = [MPIndexPath indexPathWithIndexes:indexes length:2];
    return indexPath;
}

- (NSInteger)section {
    NSParameterAssert(_length == 2);

    return _indexes[0];
}

- (NSInteger)row {
    NSParameterAssert(_length == 2);

    return _indexes[1];
}

- (void)setSection:(NSInteger)section {
    _indexes[0] = section;
}

- (void)setRow:(NSInteger)row {
    _indexes[1] = row;
}

- (MPIndexPathStruct)structIndexPath {
    MPIndexPathStruct result;
    result.section = self.section;
    result.row = self.row;
    return result;
}

- (NSComparisonResult)compareIndexPathAt:(MPIndexPathStruct)indexPath {
    return MPCompareIndexPath([self structIndexPath], indexPath);
}

- (NSComparisonResult)compareRowSection:(MPIndexPath *)indexPath {
    return MPCompareIndexPath([self structIndexPath], [indexPath structIndexPath]);
}

+ (MPIndexPath *)indexPathFromStruct:(MPIndexPathStruct)indexPath {
    return [MPIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
}

@end

#pragma mark -

@interface MPTableReusableView (MPTableReusableView_internal)

@property (nonatomic, copy, readwrite) NSString *identifier;

@end

#pragma mark -

static MPTableViewRowAnimation
MPTableViewGetRandomRowAnimation() {
    u_int32_t random = arc4random() % 7;
    return (MPTableViewRowAnimation)random;
}

static CGRect
MPTableViewDisappearViewFrameWithRowAnimation(UIView *view, CGFloat top, MPTableViewRowAnimation animation, MPTableViewPosition *sectionPosition) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (view.opaque == NO) {
                view.hidden = YES;
                return frame;
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
                frame.origin.y = top + (sectionPosition.endPos - sectionPosition.beginPos) / 2;
            } else {
                frame.origin.y = top;
            }
            frame.size.height = 0;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = bounds.size.height / 2;
            bounds.size.height = 0;
            view.bounds = bounds;
            
            view.alpha = 0;
        }
            break;
        case MPTableViewRowAnimationNone: {
            view.hidden = YES;
            return frame;
        }
            break;
            
        default:
            break;
    }
    
    return frame;
}

static void
MPTableViewDisplayViewFrameWithRowAnimation(UIView *view, CGRect originFrame, MPTableViewRowAnimation animation, MPTableViewPosition *sectionPosition) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (view.opaque == NO) {
                view.hidden = NO;
                return;
            } else {
                frame.origin.y = originFrame.origin.y;
                view.alpha = 1;
            }
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin = originFrame.origin;
            view.alpha = 1;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin = originFrame.origin;
            view.alpha = 1;
        }
            break;
        case MPTableViewRowAnimationTop: {
            frame.origin.y = originFrame.origin.y;
            frame.size.height = originFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationBottom: {
            frame.origin.y = originFrame.origin.y;
            frame.size.height = originFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            view.bounds = bounds;
        }
            break;
        case MPTableViewRowAnimationMiddle: {
            frame.origin.y = originFrame.origin.y;
            frame.size.height = originFrame.size.height;
            
            CGRect bounds = view.bounds;
            bounds.origin.y = 0;
            bounds.size.height = originFrame.size.height;
            view.bounds = bounds;
            
            view.alpha = 1;
        }
            break;
        case MPTableViewRowAnimationNone: {
            view.hidden = NO;
            return;
        }
            break;
            
        default:
            break;
    }
    
    view.frame = frame;
}

NSString *const MPTableViewSelectionDidChangeNotification = @"MPTableViewSelectionDidChangeNotification";

#define MPTableView_ReloadAsync_Exception if (!_mpDataSource) { \
    return MPTableViewMaxSize; \
}

#define MPTableView_Offscreen (frame.size.height <= 0 || frame.origin.y > _contentOffset.endPos || CGRectGetMaxY(frame) < _contentOffset.beginPos)
#define MPTableView_Onscreen (frame.size.height > 0 && frame.origin.y <= _contentOffset.endPos && CGRectGetMaxY(frame) >= _contentOffset.beginPos)

const CGFloat MPTableViewDefaultAnimationDuration = 0.3f;

@implementation MPTableView {
    UIView *_contentWrapperView;
    MPTableViewPosition *_contentDrawArea; //
    MPTableViewPosition *_contentOffset;
    MPTableViewPosition *_currDrawArea;
    
    MPIndexPathStruct _beginIndexPath, _endIndexPath;
    
    NSMutableSet *_selectedIndexPaths;
    MPIndexPath *_highlightedIndexPath;
    
    BOOL _layoutSubviewsLock;
    
    BOOL _needPreparationDetected;
    NSInteger _currSuspendHeaderSection, _currSuspendFooterSection; //
    
    NSUInteger _numberOfSections;
    
    NSMutableDictionary *_displayedCellsDic, *_displayedSectionViewsDic; //
    NSMutableArray *_sectionsAreaList;
    NSMutableDictionary *_reusableCellsDic, *_registerCellsClassDic, *_registerCellsNibDic; //
    NSMutableDictionary *_reusableReusableViewsDic, *_registerReusableViewsClassDic, *_registerReusableViewsNibDic;
    
    __weak id <MPTableViewDelegate> _mpDelegate;
    __weak id <MPTableViewDataSource> _mpDataSource;
    
    //
    MPTableViewEstimatedManager *_estimatedUpdateManager;
    NSMutableDictionary *_estimatedCellsDic, *_estimatedSectionViewsDic;
    
    //
    MPTableViewUpdateManager *_updateManager;
    BOOL _updateDataPreparing;
    NSUInteger _updateAnimationStep;
    
    CGFloat _updateInsertOriginTopPosition, _updateDeleteOriginTopPosition; //
    
    NSMutableDictionary *_insertCellsDic, *_insertSectionViewsDic;
    NSInteger _lastSuspendHeaderSection, _lastSuspendFooterSection;
    
    NSMutableDictionary *_deleteCellsDic, *_deleteSectionViewsDic;
    
    NSMutableArray *_updateAnimationBlocks, *_updateWillCacheCells, *_updateWillCacheSectionViews;
    NSMutableSet *_updateExchangedSelectedIndexPaths;
    
    //
    BOOL _moveModeEnabled, _scrollEnabledRecord;
    CGPoint _movingMinuendPoint;
    CGFloat _movingScrollFate, _movingDistanceToOffset;
    MPIndexPath *_movingIndexPath, *_sourceIndexPath;
    MPTableViewCell *_movingDraggedCell;
    CADisplayLink *_movingScrollDisplayLink;
    
    //
    MPTableViewScrollDirection _previousScrollDirection;
    CGFloat _previousContentOffset;
    NSMutableArray *_prefetchIndexPaths;
    
    //
    BOOL
    _respond_numberOfSectionsInMPTableView,
    
    _respond_heightForIndexPath,
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
    
    _respond_willSelectCellAtIndexPath,
    _respond_willDeselectRowAtIndexPath,
    _respond_didSelectCellAtIndexPath,
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
    
    _respond_shouldMoveRowAtIndexPath;
    
    BOOL
    _respond_prefetchRowsAtIndexPaths,
    _respond_cancelPrefetchingForRowsAtIndexPaths,
    _respond_didScrollAndLayoutUpdatedWithDirectionWithPreviousDirection;
}

@dynamic delegate;

#pragma mark -

- (instancetype)initWithFrame:(CGRect)frame style:(MPTableViewStyle)style {
    if (self = [super initWithFrame:frame]) {
        _style = style;
        [self _initializeData];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame style:MPTableViewStylePlain];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        if ([aDecoder containsValueForKey:@"_tableViewStyle"]) {
            _style = [aDecoder decodeIntegerForKey:@"_tableViewStyle"];
        } else {
            _style = MPTableViewStylePlain;
        }
        _registerCellsNibDic = [aDecoder decodeObjectForKey:@"_registerCellsNibDic"];
        _registerReusableViewsNibDic = [aDecoder decodeObjectForKey:@"_registerReusableViewsNibDic"];
        
        [self _initializeData];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    _cachesReloadEnabled = NO;
    [self _clear];
    [_sectionsAreaList removeAllObjects];
    
    [_tableHeaderView removeFromSuperview];
    [_tableFooterView removeFromSuperview];
    [_contentWrapperView removeFromSuperview];
    [_backgroundView removeFromSuperview];
    [super setContentSize:CGSizeZero];
    
    [aCoder encodeInteger:_style forKey:@"_tableViewStyle"];
    [aCoder encodeObject:_registerCellsNibDic forKey:@"_registerCellsNibDic"];
    [aCoder encodeObject:_registerReusableViewsNibDic forKey:@"_registerReusableViewsNibDic"];
    
    [super encodeWithCoder:aCoder];
}

- (void)_initializeData {
    self.alwaysBounceVertical = YES;
    self.showsHorizontalScrollIndicator = NO;
    self.backgroundColor = [UIColor whiteColor];
    
    [self _lockLayoutSubviews];
    [self addSubview:_contentWrapperView = [[UIView alloc] init]];
    [self sendSubviewToBack:_contentWrapperView];
    _contentWrapperView.autoresizesSubviews = NO; // @optional
    
    _numberOfSections = 1;
    
    _rowHeight = MPTableViewDefaultCellHeight;
    if (self.style == MPTableViewStylePlain) {
        _sectionHeaderHeight = 0;
        _sectionFooterHeight = 0;
    } else {
        _sectionHeaderHeight = 35.;
        _sectionFooterHeight = 35.;
    }
    
    _allowsSelection = YES;
    
    [self _resetContentIndexPaths];
    _contentDrawArea = [MPTableViewPosition positionWithBegin:0 toEnd:0];
    _contentOffset = [MPTableViewPosition positionWithBegin:0 toEnd:0];
    _currDrawArea = [MPTableViewPosition positionWithBegin:0 toEnd:0];
    
    _cachesReloadEnabled = YES;
    _updateForceReload = NO;
    _moveModeEnabled = NO;
    _scrollEnabledRecord = [super isScrollEnabled];
    _allowsSelectionDuringMoving = NO;
    _allowDragOutBounds = NO;
    
    _reusableCellsDic = [NSMutableDictionary dictionary];
    _reusableReusableViewsDic = [NSMutableDictionary dictionary];
    _displayedCellsDic = [NSMutableDictionary dictionary];
    _displayedSectionViewsDic = [NSMutableDictionary dictionary];
    
    _sectionsAreaList = [NSMutableArray array];
    
    _selectedIndexPaths = [NSMutableSet set];
    
    _updateManager = [MPTableViewUpdateManager managerWithDelegate:self andSections:_sectionsAreaList];
    _estimatedUpdateManager = [[MPTableViewEstimatedManager alloc] init];
    _estimatedUpdateManager.sections = _sectionsAreaList;
    _estimatedUpdateManager.delegate = self;
    
    _estimatedCellsDic = [NSMutableDictionary dictionary];
    _estimatedSectionViewsDic = [NSMutableDictionary dictionary];
    
    _updateAnimationStep = 0;
    _updateDataPreparing = NO;
    _rowAnimationDelay = 0;
    _rowAnimationDuration = MPTableViewDefaultAnimationDuration; // Unless it's necessary, don't change the value.
    _rowAnimationOptions = UIViewAnimationOptionLayoutSubviews;
    
    _deleteCellsDic = [NSMutableDictionary dictionary];
    _deleteSectionViewsDic = [NSMutableDictionary dictionary];
    _insertCellsDic = [NSMutableDictionary dictionary];
    _insertSectionViewsDic = [NSMutableDictionary dictionary];
    _updateAnimationBlocks = [NSMutableArray array];
    _updateWillCacheCells = [NSMutableArray array];
    _updateWillCacheSectionViews = [NSMutableArray array];
    _updateExchangedSelectedIndexPaths = [NSMutableSet set];
    
    _prefetchIndexPaths = [NSMutableArray array];
}

- (void)dealloc {
    _cachesReloadEnabled = NO;
    [self _clear];
    [_sectionsAreaList removeAllObjects];
}

#pragma mark -

- (void)_respondsToDataSource {
    _respond_numberOfSectionsInMPTableView = [_mpDataSource respondsToSelector:@selector(numberOfSectionsInMPTableView:)];
    if (!_respond_numberOfSectionsInMPTableView) {
        _numberOfSections = 1;
    }
    
    _respond_heightForIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForIndexPath:)];
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
    
    _respond_willSelectCellAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willSelectCell:atIndexPath:)];
    _respond_willDeselectRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willDeselectRowAtIndexPath:)];
    _respond_didSelectCellAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didSelectCell:atIndexPath:)];
    _respond_didDeselectRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didDeselectRowAtIndexPath:)];
    _respond_shouldHighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:shouldHighlightRowAtIndexPath:)];
    _respond_didHighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didHighlightRowAtIndexPath:)];
    _respond_didUnhighlightRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:didUnhighlightRowAtIndexPath:)];
    
    _respond_beginToInsertCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertCell:forRowAtIndexPath:withAnimationPathPosition:)];
    _respond_beginToInsertHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertHeaderView:forSection:withAnimationPathPosition:)];
    _respond_beginToInsertFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToInsertFooterView:forSection:withAnimationPathPosition:)];
    
    _respond_beginToDeleteCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteCell:forRowAtIndexPath:withAnimationPathPosition:)];
    _respond_beginToDeleteHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteHeaderView:forSection:withAnimationPathPosition:)];
    _respond_beginToDeleteFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:beginToDeleteFooterView:forSection:withAnimationPathPosition:)];
    
    _respond_shouldMoveRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:shouldMoveRowAtIndexPath:)];
}

- (void)_respondsToPrefetchDataSource {
    _respond_prefetchRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:prefetchRowsAtIndexPaths:)];
    _respond_cancelPrefetchingForRowsAtIndexPaths = [_prefetchDataSource respondsToSelector:@selector(MPTableView:cancelPrefetchingForRowsAtIndexPaths:)];
    _respond_didScrollAndLayoutUpdatedWithDirectionWithPreviousDirection = [_prefetchDataSource respondsToSelector:@selector(MPTableView:didScrollAndLayoutUpdatedWithDirection:withPreviousDirection:)];
}

#pragma mark -public-

- (void)setDataSource:(id<MPTableViewDataSource>)dataSource {
    if (![dataSource respondsToSelector:@selector(MPTableView:cellForRowAtIndexPath:)] || ![dataSource respondsToSelector:@selector(MPTableView:numberOfRowsInSection:)]) {
        NSAssert(NO, @"dataSource @required");
        return;
    }
    
    _mpDataSource = dataSource;
    [self _respondsToDataSource];
    [self reloadData];
}

- (id<MPTableViewDataSource>)dataSource {
    return _mpDataSource;
}

- (void)setDelegate:(id<MPTableViewDelegate>)delegate {
    _mpDelegate = delegate;
    
    [super setDelegate:delegate];
    [self _respondsToDelegate];
}

- (id<MPTableViewDelegate>)delegate {
    return _mpDelegate;
}

- (void)setPrefetchDataSource:(id<MPTableViewDataSourcePrefetching>)prefetchDataSource {
    _prefetchDataSource = prefetchDataSource;
    [self _respondsToPrefetchDataSource];
}

- (void)setContentSize:(CGSize)contentSize {
    if (!CGSizeEqualToSize(contentSize, _contentWrapperView.frame.size)) {
        _contentWrapperView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    if (self.backgroundView && !CGSizeEqualToSize(contentSize, self.backgroundView.frame.size)) {
        self.backgroundView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    
    [super setContentSize:contentSize];
}

NS_INLINE void _MP_SetViewWidth(UIView *view, CGFloat width) {
    CGRect frame = view.frame;
    frame.size.width = width;
    view.frame = frame;
}

- (void)setFrame:(CGRect)frame {
    if ([super frame].size.width != frame.size.width) {
        [self _lockLayoutSubviews];
        
        _MP_SetViewWidth(self.tableHeaderView, frame.size.width);
        _MP_SetViewWidth(self.tableFooterView, frame.size.height);

        for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
            _MP_SetViewWidth(cell, frame.size.width);
        }
        for (UIView *sectionView in _displayedSectionViewsDic.allValues) {
            _MP_SetViewWidth(sectionView, frame.size.width);
        }
        
        for (MPTableViewCell *cell in _insertCellsDic.allValues) {
            _MP_SetViewWidth(cell, frame.size.width);
        }
        for (UIView *sectionView in _insertSectionViewsDic.allValues) {
            _MP_SetViewWidth(sectionView, frame.size.width);
        }
        
        CGSize contentSize = self.contentSize;
        contentSize.width = frame.size.width;
        self.contentSize = contentSize;

        [self _unlockLayoutSubviews];
    }
    [super setFrame:frame];
}

- (NSUInteger)numberOfSections {
    return _numberOfSections;
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)sectionIndex {
    if (sectionIndex >= _sectionsAreaList.count) {
        return NSNotFound;
    } else {
        MPTableViewSection *section = _sectionsAreaList[sectionIndex];
        return section.numberOfRows;
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

- (void)setTableHeaderView:(UIView *)tableHeaderView {
    [_tableHeaderView removeFromSuperview];
    
    if (!tableHeaderView) {
        return;
    }
    
    CGRect frame = tableHeaderView.frame;
    frame.origin = CGPointZero;
    frame.size.width = self.frame.size.width;
    tableHeaderView.frame = frame;
    [self addSubview:_tableHeaderView = tableHeaderView];
    
    if (_contentDrawArea.beginPos == frame.size.height) {
        return;
    }
    CGFloat contentHeight = _contentDrawArea.endPos - _contentDrawArea.beginPos;
    _contentDrawArea.beginPos = frame.size.height;
    _contentDrawArea.endPos = _contentDrawArea.beginPos + contentHeight;
    
    [self setContentSize:CGSizeMake(self.frame.size.width, _contentDrawArea.endPos + self.tableFooterView.frame.size.height)];
    
    if (contentHeight > 0) {
        [self _resetContentIndexPaths];
        [self _cacheDisplayingCells];
        [self _cacheDisplayingSectionViews];
        [self _getDisplayingArea];
        [self _updateDisplayingArea];
    }
}

- (void)setTableFooterView:(UIView *)tableFooterView {
    [_tableFooterView removeFromSuperview];
    
    if (!tableFooterView) {
        return;
    }
    
    CGRect frame = tableFooterView.frame;
    frame.origin = CGPointMake(0, _contentDrawArea.endPos);
    frame.size.width = self.frame.size.width;
    tableFooterView.frame = frame;
    [self addSubview:_tableFooterView = tableFooterView];
    
    [self setContentSize:CGSizeMake(self.frame.size.width, _contentDrawArea.endPos + frame.size.height)];
}

- (void)setBackgroundView:(UIView *)backgroundView {
    CGRect frame = backgroundView.frame;
    frame.origin = CGPointZero;
    frame.size = self.contentSize;
    backgroundView.frame = frame;
    
    [self insertSubview:_backgroundView = backgroundView belowSubview:_contentWrapperView];
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    _needPreparationDetected = (self.style == MPTableViewStylePlain) && (contentInset.top != 0 || contentInset.bottom != 0);
    [super setContentInset:contentInset];
}

- (MPTableViewCell *)cellForRowAtIndexPath:(MPIndexPath *)indexPath {
    NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
    
    MPTableViewCell *result = nil;
    result = [_displayedCellsDic objectForKey:indexPath];
    return result;
}

- (MPTableReusableView *)sectionHeaderInSection:(NSUInteger)section {
    return [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:section]];
}

- (MPTableReusableView *)sectionFooterInSection:(NSUInteger)section {
    return [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:section]];
}

- (MPIndexPath *)indexPathForCell:(MPTableViewCell *)cell {
    __block MPIndexPath *result = nil;
    [_displayedCellsDic enumerateKeysAndObjectsUsingBlock:^(MPIndexPath *indexPath, MPTableViewCell *_cell, BOOL *stop) {
        if (_cell == cell) {
            result = [indexPath copy];
            *stop = YES;
        }
    }];
    return result;
}

- (NSArray *)visibleCells {
    return _displayedCellsDic.allValues;
}

- (NSArray *)indexPathsForVisibleRows {
    return _displayedCellsDic.allKeys;
}

- (NSArray *)visibleCellsInRect:(CGRect)rect {
    if (rect.origin.x > self.frame.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _contentDrawArea.endPos || CGRectGetMaxY(rect) < _contentDrawArea.beginPos || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *visibleCells = [NSMutableArray array];
    
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        if (CGRectIntersectsRect(rect, cell.frame)) {
            [visibleCells addObject:cell];
        }
    }
    
    return visibleCells;
}

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect {
    if (rect.origin.x > self.frame.size.width || CGRectGetMaxX(rect) < 0 || rect.origin.y > _contentDrawArea.endPos || CGRectGetMaxY(rect) < _contentDrawArea.beginPos || rect.size.width <= 0 || rect.size.height <= 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    MPIndexPath *beginIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:rect.origin.y - _contentDrawArea.beginPos]];
    MPIndexPath *endIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:CGRectGetMaxY(rect) - _contentDrawArea.beginPos]];
    
    for (NSInteger i = beginIndexPath.section; i <= endIndexPath.section; i++) {
        NSUInteger numberOfRows = [self numberOfRowsInSection:i];
        if (i == beginIndexPath.section) {
            NSInteger j = (beginIndexPath.row == MPSectionTypeHeader) ? 0 : beginIndexPath.row;
            if (beginIndexPath.section == endIndexPath.section) {
                if (endIndexPath.row == MPSectionTypeHeader) {
                    break;
                } else if (endIndexPath.row < MPSectionTypeFooter) {
                    numberOfRows = endIndexPath.row + 1;
                }
                for (; j < numberOfRows; j++) {
                    [indexPaths addObject:[MPIndexPath indexPathForRow:j inSection:i]];
                }
            } else {
                for (; j < numberOfRows; j++) {
                    [indexPaths addObject:[MPIndexPath indexPathForRow:j inSection:i]];
                }
            }
        } else {
            if (i == endIndexPath.section) {
                if (endIndexPath.row == MPSectionTypeHeader) {
                    numberOfRows = 0;
                } else if (endIndexPath.row < MPSectionTypeFooter) {
                    numberOfRows = endIndexPath.row + 1;
                }
            }
            for (NSInteger j = 0; j < numberOfRows; j++) {
                [indexPaths addObject:[MPIndexPath indexPathForRow:j inSection:i]];
            }
        }
    }
    
    return indexPaths;
}

- (NSArray *)indexPathsForRowsInSection:(NSUInteger)section {
    if (section >= _sectionsAreaList.count) {
        return nil;
    }
    
    MPTableViewSection *section_ = _sectionsAreaList[section];
    if (section_.numberOfRows == 0) {
        return nil;
    }
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (NSInteger i = 0; i < section_.numberOfRows; i++) {
        [indexPaths addObject:[MPIndexPath indexPathForRow:i inSection:section]];
    }
    
    return indexPaths;
}

- (MPIndexPath *)beginIndexPath {
    MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:_beginIndexPath];
    
    if (indexPath.row == MPSectionTypeHeader) {
        MPTableViewSection *section = _sectionsAreaList[indexPath.section];
        indexPath.row = section.numberOfRows ? 0 : NSNotFound;
    }
    
    if (indexPath.row == MPSectionTypeFooter) {
        indexPath.row = NSNotFound;
        while (indexPath.section + 1 < _endIndexPath.section) {
            indexPath.section++;
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if (section.numberOfRows > 0) {
                indexPath.row = 0;
                break;
            }
        }
    }
    
    return indexPath;
}

- (MPIndexPath *)endIndexPath {
    MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:_endIndexPath];
    
    if (indexPath.row == MPSectionTypeHeader) {
        indexPath.row = NSNotFound;
        while (indexPath.section > _beginIndexPath.section) {
            indexPath.section--;
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if (section.numberOfRows > 0) {
                indexPath.row = section.numberOfRows - 1;
                break;
            }
        }
    }
    
    if (indexPath.row == MPSectionTypeFooter) {
        MPTableViewSection *section = _sectionsAreaList[indexPath.section];
        indexPath.row = section.numberOfRows ? section.numberOfRows - 1 : NSNotFound;
    }
    
    return indexPath;
}

- (MPIndexPathStruct)__beginIndexPath {
    return _beginIndexPath;
}
- (MPIndexPathStruct)__endIndexPath {
    return _endIndexPath;
}

- (CGRect)rectForSection:(NSUInteger)section {
    if (section >= _sectionsAreaList.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.frame.size.width, sectionObj.endPos - sectionObj.beginPos);
    return frame;
}

- (CGRect)rectForHeaderInSection:(NSUInteger)section {
    if (section >= _sectionsAreaList.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.frame.size.width, sectionObj.headerHeight);
    return frame;
}

- (CGRect)rectForFooterInSection:(NSUInteger)section {
    if (section >= _sectionsAreaList.count) {
        return CGRectNull;
    }
    
    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.frame.size.width, sectionObj.footerHeight);
    return frame;
}

- (CGRect)rectForRowAtIndexPath:(MPIndexPath *)indexPath {
    if (indexPath.section < 0 || indexPath.section >= _sectionsAreaList.count) {
        return CGRectNull;
    }
    
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    if (indexPath.row < 0 || indexPath.row >= section.numberOfRows) {
        return CGRectNull;
    }
    
    return [self _cellFrameAtIndexPath:indexPath];;
}

- (MPIndexPath *)indexPathForRowAtPoint:(CGPoint)point {
    if (point.y < _contentDrawArea.beginPos || point.y > _contentDrawArea.endPos) {
        return nil;
    } else {
        MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:(point.y - _contentDrawArea.beginPos)]];
        if (indexPath.row == MPSectionTypeHeader || indexPath.row == MPSectionTypeFooter) {
            return nil;
        } else {
            return indexPath;
        }
    }
}

- (NSUInteger)indexForSectionAtPoint:(CGPoint)point {
    if (point.y < _contentDrawArea.beginPos || point.y > _contentDrawArea.endPos) {
        return NSNotFound;
    } else {
        return [self _sectionIndexAtContentOffset:point.y - _contentDrawArea.beginPos];
    }
}

- (void)scrollToRowAtIndexPath:(MPIndexPath *)indexPath atScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (scrollPosition == MPTableViewScrollPositionNone) {
        return;
    }
    NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
    NSAssert(indexPath.section < _sectionsAreaList.count, @"an non-existent section");
    
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    NSAssert(indexPath.row < section.numberOfRows, @"row overflow");
    
    CGFloat _contentOffsetY = 0;
    switch (scrollPosition) {
        case MPTableViewScrollPositionTop: {
            _contentOffsetY = [section rowPositionBeginAt:indexPath.row] - self.contentInset.top;
            if (_respond_viewForHeaderInSection && self.style == MPTableViewStylePlain) {
                _contentOffsetY -= section.headerHeight;
            }
        }
            break;
        case MPTableViewScrollPositionMiddle: {
            CGFloat cellBeginPos = [section rowPositionBeginAt:indexPath.row];
            CGFloat cellEndPos = [section rowPositionEndAt:indexPath.row];
            _contentOffsetY = cellBeginPos + (cellEndPos - cellBeginPos) / 2 - self.frame.size.height / 2;
        }
            break;
        case MPTableViewScrollPositionBottom: {
            _contentOffsetY = [section rowPositionEndAt:indexPath.row] - self.frame.size.height + self.contentInset.bottom;
            if (_respond_viewForFooterInSection && self.style == MPTableViewStylePlain) {
                _contentOffsetY += section.footerHeight;
            }
        }
            break;
        default:
            return;
    }
    
    _contentOffsetY += _contentDrawArea.beginPos;
    if (_contentOffsetY + self.frame.size.height > self.contentSize.height) {
        _contentOffsetY = self.contentSize.height - self.frame.size.height;
    }
    if (_contentOffsetY < 0) {
        _contentOffsetY = 0;
    }
    
    [self setContentOffset:CGPointMake(0, _contentOffsetY) animated:animated];
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection {
    if (_allowsMultipleSelection == allowsMultipleSelection) {
        return;
    }
    for (MPIndexPath *indexPath in _selectedIndexPaths) {
        [self _deselectRowAtIndexPath:indexPath animated:NO selectedIndexPathRemove:NO];
    }
    [_selectedIndexPaths removeAllObjects];
    
    _allowsMultipleSelection = allowsMultipleSelection;
    if (_allowsMultipleSelection) {
        _allowsSelection = YES;
    }
}

- (MPIndexPath *)indexPathForSelectedRow {
    return [_selectedIndexPaths anyObject];
}

- (NSArray *)indexPathsForSelectedRows {
    return [_selectedIndexPaths allObjects];
}

- (void)selectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(MPTableViewScrollPosition)scrollPosition {
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    if (_respond_willSelectCellAtIndexPath) {
        MPIndexPath *newIndexPath = [_mpDelegate MPTableView:self willSelectCell:cell atIndexPath:indexPath];
        if (!newIndexPath) {
            return;
        }
        if (![indexPath isEqual:newIndexPath]) {
            cell = [_displayedCellsDic objectForKey:indexPath = [newIndexPath copy]];
        }
    }
    [_selectedIndexPaths addObject:indexPath];

    if (cell) {
        [cell setSelected:YES animated:animated];
    }
    
    [self scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
    
    if (_respond_didSelectCellAtIndexPath) {
        [_mpDelegate MPTableView:self didSelectCell:cell atIndexPath:indexPath];
    }
}

- (void)scrollToNearestSelectedRowAtScrollPosition:(MPTableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (scrollPosition == MPTableViewScrollPositionNone || !_selectedIndexPaths.count) {
        return;
    }
    
    MPIndexPath *nearestSelectedIndexPath = [MPIndexPath indexPathForRow:NSNotFound inSection:NSNotFound];
    for (MPIndexPath *indexPath in _selectedIndexPaths) {
        if ([indexPath compareRowSection:nearestSelectedIndexPath] == NSOrderedAscending) {
            nearestSelectedIndexPath = indexPath;
        }
    }
    if (nearestSelectedIndexPath.section < NSNotFound && nearestSelectedIndexPath.row < NSNotFound) {
        [self scrollToRowAtIndexPath:nearestSelectedIndexPath atScrollPosition:scrollPosition animated:animated];
    }
}

- (void)_deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated selectedIndexPathRemove:(BOOL)remove {
    if (!indexPath) {
        return;
    }
    
    MPTableViewCell *selectedCell = [_displayedCellsDic objectForKey:indexPath];
    if (_respond_willDeselectRowAtIndexPath) {
        MPIndexPath *newIndexPath = [_mpDelegate MPTableView:self willDeselectRowAtIndexPath:indexPath];
        if (!newIndexPath) {
            return;
        }
        if (![newIndexPath isEqual:indexPath]) {
            selectedCell = [_displayedCellsDic objectForKey:indexPath = [newIndexPath copy]];
        }
    }
    if (selectedCell) {
        [selectedCell setSelected:NO animated:animated];
    }
    
    if (remove) {
        [_selectedIndexPaths removeObject:indexPath];
    }
    
    if (_respond_didDeselectRowAtIndexPath) {
        [_mpDelegate MPTableView:self didDeselectRowAtIndexPath:indexPath];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated {
    if (![_selectedIndexPaths containsObject:indexPath]) {
        return;
    }
    [self _deselectRowAtIndexPath:indexPath animated:animated selectedIndexPathRemove:YES];
}

- (BOOL)isUpdating {
    return _updateAnimationStep != 0;
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSAssert(idx < _numberOfSections, @"delete section overflow");
        if (![_updateManager addDeleteSection:idx withAnimation:animation]) {
            NSAssert(NO, @"check duplicate indexPaths");
        }
        
        for (MPIndexPath *selectedIndexPath in _selectedIndexPaths.allObjects) {
            if (selectedIndexPath.section == idx) {
                [_selectedIndexPaths removeObject:selectedIndexPath];
            }
        }
    }];
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    NSUInteger count;
    if (_respond_numberOfSectionsInMPTableView) {
        count = [_mpDataSource numberOfSectionsInMPTableView:self];
    } else {
        count = _numberOfSections;
    }
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSAssert(idx < count, @"insert section overflow");
        if (![_updateManager addInsertSection:idx withAnimation:animation]) {
            NSAssert(NO, @"check duplicate indexPaths");
        }
    }];
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSAssert(idx < _numberOfSections, @"reload section overflow");
        if (![_updateManager addReloadSection:idx withAnimation:animation]) {
            NSAssert(NO, @"check duplicate indexPaths");
        }
    }];
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)moveSection:(NSUInteger)section toSection:(NSUInteger)newSection {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    NSParameterAssert(section != newSection);
    NSAssert(section < _numberOfSections, @"move out section overflow");
    
    NSUInteger count;
    if (_respond_numberOfSectionsInMPTableView) {
        count = [_mpDataSource numberOfSectionsInMPTableView:self];
    } else {
        count = _numberOfSections;
    }
    
    NSAssert(newSection < count, @"move in section overflow");
    
    if (![_updateManager addMoveOutSection:section]) {
        NSAssert(NO, @"check duplicate indexPaths");
    }
    
    if (![_updateManager addMoveInSection:newSection withOriginIndex:section]) {
        NSAssert(NO, @"check duplicate indexPaths");
    }
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        NSAssert(indexPath.section < _numberOfSections, @"delete section overflow");
        NSAssert(indexPath.row < [self numberOfRowsInSection:indexPath.section], @"delete row overflow");
        
        if (![_updateManager addDeleteIndexPath:indexPath withAnimation:animation]) {
            NSAssert(NO, @"check duplicate indexPaths");
        }
        
        if ([_selectedIndexPaths containsObject:indexPath]) {
            [_selectedIndexPaths removeObject:indexPath];
        }
    }
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    NSUInteger count;
    if (_respond_numberOfSectionsInMPTableView) {
        count = [_mpDataSource numberOfSectionsInMPTableView:self];
    } else {
        count = _numberOfSections;
    }
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        NSAssert(indexPath.section < count, @"insert section overflow");
        if (![_updateManager addInsertIndexPath:indexPath withAnimation:animation]) {
            NSAssert(NO, @"check duplicate indexPaths");
        }
    }
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        NSAssert(indexPath.section < _numberOfSections, @"reload section overflow");
        NSAssert(indexPath.row < [self numberOfRowsInSection:indexPath.section], @"reload row overflow");
        
        if (![_updateManager addReloadIndexPath:indexPath withAnimation:animation]) {
            NSAssert(NO, @"check duplicate indexPaths");
        }
    }
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)moveRowAtIndexPath:(MPIndexPath *)indexPath toIndexPath:(MPIndexPath *)newIndexPath {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    
    NSParameterAssert([indexPath compareRowSection:newIndexPath] != NSOrderedSame);
    
    NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
    NSParameterAssert(newIndexPath.row >= 0 && newIndexPath.section >= 0);
    
    NSAssert(indexPath.section < _numberOfSections, @"move out section overflow");
    NSAssert(indexPath.row < [self numberOfRowsInSection:indexPath.section], @"move out row overflow");
    
    NSUInteger count;
    if (_respond_numberOfSectionsInMPTableView) {
        count = [_mpDataSource numberOfSectionsInMPTableView:self];
    } else {
        count = _numberOfSections;
    }
    
    NSAssert(newIndexPath.section < count, @"move in section overflow");
    
    if (![_updateManager addMoveOutIndexPath:indexPath]) {
        NSAssert(NO, @"check duplicate indexPaths");
    }
    
    if (![_updateManager addMoveInIndexPath:newIndexPath withFrame:[self _cellFrameAtIndexPath:indexPath] withOriginIndexPath:indexPath]) {
        NSAssert(NO, @"check duplicate indexPaths");
    }
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (BOOL)isUpdateForceReload {
    return _updateForceReload;
}

- (void)beginUpdates {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    [self _lockLayoutSubviews];
}

- (void)endUpdates {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(_movingIndexPath == nil);
    
    if (_updateDataPreparing || _movingIndexPath) {
        return;
    }
    [self _startUpdateAnimation];
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
    
    if (!reusableCell && _registerCellsClassDic) {
        Class cellClass = [_registerCellsClassDic objectForKey:identifier];
        if (cellClass) {
            reusableCell = [[cellClass alloc] initWithReuseIdentifier:identifier];
        } else {
            reusableCell = nil;
        }
    }
    
    if (!reusableCell && _registerCellsNibDic) {
        UINib *nib = [_registerCellsNibDic objectForKey:identifier];
        if (nib) {
            reusableCell = [nib instantiateWithOwner:self options:nil].firstObject;
            NSParameterAssert([reusableCell isKindOfClass:[MPTableViewCell class]]);
            reusableCell.identifier = identifier;
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
    
    if (!reusableView && _registerReusableViewsClassDic) {
        Class reusableViewClass = [_registerReusableViewsClassDic objectForKey:identifier];
        if (reusableViewClass) {
            reusableView = [[reusableViewClass alloc] initWithReuseIdentifier:identifier];
        } else {
            reusableView = nil;
        }
    }
    
    if (!reusableView && _registerReusableViewsNibDic) {
        UINib *nib = [_registerReusableViewsNibDic objectForKey:identifier];
        if (nib) {
            reusableView = [nib instantiateWithOwner:self options:nil].firstObject;
            NSParameterAssert([reusableView isKindOfClass:[MPTableReusableView class]]);
            reusableView.identifier = identifier;
        } else {
            reusableView = nil;
        }
    }
    
    [reusableView prepareForReuse];
    
    return reusableView;
}

- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier {
    NSParameterAssert([cellClass isSubclassOfClass:[MPTableViewCell class]]);
    
    if (!_registerCellsClassDic) {
        _registerCellsClassDic = [NSMutableDictionary dictionary];
    }
    [_registerCellsClassDic setObject:cellClass forKey:identifier];
}

- (void)registerClass:(Class)reusableViewClass forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert([reusableViewClass isSubclassOfClass:[MPTableReusableView class]]);
    
    if (!_registerReusableViewsClassDic) {
        _registerReusableViewsClassDic = [NSMutableDictionary dictionary];
    }
    [_registerReusableViewsClassDic setObject:reusableViewClass forKey:identifier];
}

- (void)registerNib:(UINib *)nib forCellReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count);
    
    if (!_registerCellsNibDic) {
        _registerCellsNibDic = [NSMutableDictionary dictionary];
    }
    [_registerCellsNibDic setObject:nib forKey:identifier];
}

- (void)registerNib:(UINib *)nib forReusableViewReuseIdentifier:(NSString *)identifier {
    NSParameterAssert(nib && identifier && [nib instantiateWithOwner:self options:nil].count);
    
    if (!_registerReusableViewsNibDic) {
        _registerReusableViewsNibDic = [NSMutableDictionary dictionary];
    }
    [_registerReusableViewsNibDic setObject:nib forKey:identifier];
}

#pragma mark -update-

- (void)_startUpdateAnimation {
    [self _lockLayoutSubviews];
    _updateDataPreparing = YES;
    
    _lastSuspendFooterSection = _lastSuspendHeaderSection = NSNotFound;
    
    if (_respond_numberOfSectionsInMPTableView) {
        _numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
    }
    _updateManager.newCount = _numberOfSections;
    
    _updateInsertOriginTopPosition = _updateDeleteOriginTopPosition = _contentDrawArea.beginPos;
    
    if (![_updateManager formatNodesStable:[self __isContentMoving]]) {
        @throw @"check for update sections";
    }
    
    _updateAnimationStep++;
    
    CGFloat offset = [_updateManager startUpdate];
    [_updateManager resetManager];
    
    [_displayedCellsDic addEntriesFromDictionary:_insertCellsDic];
    [_insertCellsDic removeAllObjects];
    [_displayedSectionViewsDic addEntriesFromDictionary:_insertSectionViewsDic];
    [_insertSectionViewsDic removeAllObjects];
    
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
    
    if (_numberOfSections) {
        _contentDrawArea.endPos += offset;
    } else {
        _contentDrawArea.endPos = _contentDrawArea.beginPos;
    }
    
    MPIndexPathStruct beginIndexPath, endIndexPath; // ...
    CGFloat changedContentOffset;
    
    if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        beginIndexPath = _beginIndexPath = MPIndexPathStructMake(NSIntegerMax, MPSectionTypeFooter);
        endIndexPath = _endIndexPath = MPIndexPathStructMake(NSIntegerMin, MPSectionTypeHeader);
        changedContentOffset = 0;
    } else {
        _beginIndexPath = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
        _endIndexPath = [self _indexPathAtContentOffset:_currDrawArea.endPos];
        
        if (self.contentSize.height + self.contentInset.bottom + offset < _contentOffset.endPos) { // when scrolling to the bottom, it needs to change content offset
            changedContentOffset = _contentOffset.beginPos;
            
            _contentOffset.endPos = self.contentSize.height + self.contentInset.bottom + offset;
            _contentOffset.beginPos = _contentOffset.endPos - self.frame.size.height;
            
            if (_contentOffset.beginPos < -self.contentInset.top) {
                _contentOffset.beginPos = -self.contentInset.top;
                _contentOffset.endPos = _contentOffset.beginPos + self.frame.size.height;
            }
            
            _currDrawArea.beginPos = _contentOffset.beginPos - _contentDrawArea.beginPos;
            _currDrawArea.endPos = _contentOffset.endPos - _contentDrawArea.beginPos;
            
            beginIndexPath = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
            endIndexPath = [self _indexPathAtContentOffset:_currDrawArea.endPos];
        } else {
            if (_movingIndexPath) {
                if ([_movingIndexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending) {
                    _beginIndexPath = [_movingIndexPath structIndexPath];
                }
                if ([_movingIndexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
                    _endIndexPath = [_movingIndexPath structIndexPath];
                }
            }
            
            beginIndexPath = _beginIndexPath;
            endIndexPath = _endIndexPath;
            changedContentOffset = 0;
            
            [self _layoutUpdatedNoticeIfNeeded];
            [self _prefetchDataIfNeeded];
        }
    }
    
    // clip...
    for (MPIndexPath *indexPath in _displayedCellsDic.allKeys) {
        if ([indexPath compareIndexPathAt:beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:endIndexPath] == NSOrderedDescending) {
            if (_movingIndexPath && [_movingIndexPath compareRowSection:indexPath] == NSOrderedSame) {
                continue;
            }
            
            MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
            [_updateWillCacheCells addObject:cell];
            [_displayedCellsDic removeObjectForKey:indexPath];
        }
    }
    
    for (MPIndexPath *indexPath in _displayedSectionViewsDic.allKeys) {
        MPTableViewSection *section = nil;
        
        if (self.style == MPTableViewStylePlain) {
            section = _sectionsAreaList[indexPath.section];
            
            if (changedContentOffset != 0 && indexPath.row == MPSectionTypeHeader && [self _needSuspendingSection:section withType:indexPath.row]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                
                [self _contentOffsetChangedResetInsertSectionView:sectionView inSection:section withType:indexPath.row inChangedContentOffset:changedContentOffset];
                
                if ([sectionView isHidden]) { // animationNone
                    [self _suspendingSectionHeader:sectionView inArea:section];
                } else {
                    void (^animationBlock)(void) = ^{
                        [self _suspendingSectionHeader:sectionView inArea:section];
                    };
                    [_updateAnimationBlocks addObject:animationBlock];
                }
                continue;
            } else {
                if ([self _isSuspendingAtIndexPath:indexPath]) {
                    if (changedContentOffset != 0 && indexPath.row == MPSectionTypeHeader) {
                        _currSuspendHeaderSection = NSNotFound;
                    } else {
                        continue;
                    }
                }
            }
        }
        
        if (_needPreparationDetected && [self _needPrepareToSuspendViewAt:section withType:indexPath.row]) {
            if (changedContentOffset != 0 && indexPath.row == MPSectionTypeHeader) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                
                [self _contentOffsetChangedResetInsertSectionView:sectionView inSection:section withType:indexPath.row inChangedContentOffset:changedContentOffset];
                
                if ([sectionView isHidden]) { // animationNone
                    [self _prepareToSuspendView:sectionView atSection:section withType:indexPath.row];
                } else {
                    void (^animationBlock)(void) = ^{
                        [self _prepareToSuspendView:sectionView atSection:section withType:indexPath.row];
                    };
                    [_updateAnimationBlocks addObject:animationBlock];
                }
            }
            continue;
        }
        
        if ([indexPath compareIndexPathAt:beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:endIndexPath] == NSOrderedDescending) {
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            [_updateWillCacheSectionViews addObject:sectionView];
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
        } else {
            if (changedContentOffset != 0) { // all reset
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                
                [self _contentOffsetChangedResetInsertSectionView:sectionView inSection:section withType:indexPath.row inChangedContentOffset:changedContentOffset];
                [self _contentOffsetChangedResetSectionView:sectionView inSection:section withType:indexPath.row];
            }
        }
    }
    
    if (changedContentOffset != 0 && ![self __isEstimatedMode]) {
        if (self.style == MPTableViewStylePlain) {
            if (_currSuspendHeaderSection == NSNotFound && _contentOffset.beginPos - self.contentInset.top >= _contentDrawArea.beginPos) {
                [self _suspendSectionHeaderIfNeededAt:beginIndexPath];
            }
            // ...no need footer
        }
        [self _updateDisplayingBegin:beginIndexPath and:endIndexPath isUpdating:YES];
    }
    
    CGSize contentSize = CGSizeMake(self.frame.size.width, _contentDrawArea.endPos + self.tableFooterView.frame.size.height);
    if (!CGSizeEqualToSize(contentSize, _contentWrapperView.frame.size)) {
        _contentWrapperView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    if (self.backgroundView && !CGSizeEqualToSize(contentSize, self.backgroundView.frame.size)) {
        self.backgroundView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    
    NSArray *updateAnimationBlocks = _updateAnimationBlocks;
    _updateAnimationBlocks = [NSMutableArray array];
    
    NSArray *updateWillCacheCells = nil;
    if (_updateWillCacheCells.count) {
        updateWillCacheCells = [NSArray arrayWithArray:_updateWillCacheCells];
        [_updateWillCacheCells removeAllObjects];
    }
    NSArray *updateWillCacheSectionViews = nil;
    if (_updateWillCacheSectionViews.count) {
        updateWillCacheSectionViews = [NSArray arrayWithArray:_updateWillCacheSectionViews];
        [_updateWillCacheSectionViews removeAllObjects];
    }
    
    NSDictionary *deleteCellsDic = nil;
    if (_deleteCellsDic.count) {
        deleteCellsDic = [NSDictionary dictionaryWithDictionary:_deleteCellsDic];
        [_deleteCellsDic removeAllObjects];
    }
    NSDictionary *deleteSectionViewsDic = nil;
    if (_deleteSectionViewsDic.count) {
        deleteSectionViewsDic = [NSDictionary dictionaryWithDictionary:_deleteSectionViewsDic];
        [_deleteSectionViewsDic removeAllObjects];
    }
    
    NSTimeInterval duration = _movingIndexPath ? MPTableViewDefaultAnimationDuration : self.rowAnimationDuration;
    [UIView animateWithDuration:duration delay:self.rowAnimationDelay options:self.rowAnimationOptions animations:^{
        if (offset != 0 && self.tableFooterView) {
            CGRect frame = self.tableFooterView.frame;
            frame.origin.y += offset;
            self.tableFooterView.frame = frame;
        }
        
        for (void (^animationBlock)(void) in updateAnimationBlocks) {
            animationBlock();
        }
        
        [super setContentSize:contentSize];
    } completion:^(BOOL finished) {
        _updateAnimationStep--;
        
        for (MPTableViewCell *cell in updateWillCacheCells) {
            [self _cacheCell:cell];
        }
        
        for (MPTableReusableView *sectionView in updateWillCacheSectionViews) {
            [self _cacheSectionView:sectionView];
        }
        
        if (_respond_didEndDisplayingCellForRowAtIndexPath) {
            for (MPIndexPath *indexPath in deleteCellsDic.allKeys) {
                MPTableViewCell *cell = [deleteCellsDic objectForKey:indexPath];
                [cell removeFromSuperview];
                
                [_mpDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
            }
        } else {
            [deleteCellsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
        }
        
        if (_respond_didEndDisplayingHeaderViewForSection || _respond_didEndDisplayingFooterViewForSection) {
            for (MPIndexPath *indexPath in deleteSectionViewsDic.allKeys) {
                MPTableReusableView *sectionView = [deleteSectionViewsDic objectForKey:indexPath];
                [sectionView removeFromSuperview];
                
                if (indexPath.row == MPSectionTypeHeader && _respond_didEndDisplayingHeaderViewForSection) {
                    [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
                }
                if (indexPath.row == MPSectionTypeFooter && _respond_didEndDisplayingFooterViewForSection) {
                    [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
                }
            }
        } else {
            [deleteSectionViewsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
        }
    }];
    
    _updateDataPreparing = NO;
    [self _unlockLayoutSubviews];
}

- (void)_contentOffsetChangedResetSectionView:(MPTableReusableView *)sectionView inSection:(MPTableViewSection *)section withType:(MPSectionType)type {
    if ([sectionView isHidden]) {
        return;
    }
    
    if (type == MPSectionTypeHeader) {
        [_updateAnimationBlocks addObject:^{
            CGRect frame = sectionView.frame;
            frame.origin.y = section.beginPos + _contentDrawArea.beginPos;
            sectionView.frame = frame;
        }];
    } else {
        [_updateAnimationBlocks addObject:^{
            CGRect frame = sectionView.frame;
            frame.origin.y = section.endPos - section.footerHeight + _contentDrawArea.beginPos;
            sectionView.frame = frame;
        }];
    }
}

- (void)_contentOffsetChangedResetInsertSectionView:(MPTableReusableView *)sectionView inSection:(MPTableViewSection *)section withType:(MPSectionType)type inChangedContentOffset:(CGFloat)changedContentOffset {
    CGRect frame = sectionView.frame;
    
    if (CGRectGetMaxY(frame) > changedContentOffset) {
        return;
    }
    
    frame.origin.y = _contentOffset.beginPos - frame.size.height - 1;
    sectionView.frame = frame;
}

- (CGFloat)_updateGetOptimizedYWithFrame:(CGRect)frame toTargetY:(CGFloat)targetY {
    CGFloat distance = targetY - frame.origin.y;
    
    if (fabs(distance) > self.frame.size.height + frame.size.height) {
        if (distance > 0) {
            return frame.origin.y + self.frame.size.height + frame.size.height + 1;
        } else {
            return frame.origin.y - self.frame.size.height - frame.size.height - 1;
        }
    } else {
        return targetY;
    }
}

- (BOOL)__updateNeedToAnimateSection:(MPTableViewSection *)section updateType:(MPTableViewUpdateType)type andOffset:(CGFloat)offset {
    if (MPTableViewUpdateTypeStable(type)) {
        if (section.beginPos > _currDrawArea.endPos || section.endPos < _currDrawArea.beginPos) {
            return NO;
        } else {
            return YES;
        }
    } else if (MPTableViewUpdateTypeUnstable(type)) { // reload is split into a deletion and an insertion
        if (section.section < _beginIndexPath.section || section.section > _endIndexPath.section) {
            return NO;
        } else {
            return YES;
        }
    } else { // adjust
        if ([self isUpdating] && [self isUpdateForceReload] && !_movingIndexPath) {
            return YES;
        }
        
        if (section.updatePart) {
            if (section.section > _endIndexPath.section && section.beginPos + offset > _currDrawArea.endPos) {
                return NO;
            } else {
                return YES;
            }
        } else {
            if ((section.section < _beginIndexPath.section || section.section > _endIndexPath.section) && (section.beginPos + offset > _currDrawArea.endPos || section.endPos + offset < _currDrawArea.beginPos)) {
                return NO;
            } else {
                return YES;
            }
        }
    }
}

#pragma mark -cell update delegate

- (CGFloat)__updateInsertCellHeightAtIndexPath:(MPIndexPath *)indexPath {
    CGFloat cellHeight;
    if (_respond_estimatedHeightForRowAtIndexPath) {
        MPTableViewSection *section = _sectionsAreaList[indexPath.section];
        CGFloat beginPos = [section rowPositionBeginAt:indexPath.row] + _contentDrawArea.beginPos;
        cellHeight = [_mpDataSource MPTableView:self estimatedHeightForRowAtIndexPath:indexPath];
        CGRect frame = CGRectMake(0, beginPos, self.frame.size.width, cellHeight);
        
        if (MPTableView_Onscreen) {
            if (_respond_heightForIndexPath) {
                cellHeight = ([_mpDataSource MPTableView:self heightForIndexPath:indexPath]);
            } else {
                MPTableViewCell *cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
                if (!cell) {
                    @throw @"cell must not be null";
                }
                
                cell.frame = frame;
                [cell layoutIfNeeded];
                cellHeight = frame.size.height = [cell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
                
                if (MPTableView_Offscreen) {
                    [self _cacheCell:cell];
                } else {
                    [_estimatedCellsDic setObject:cell forKey:indexPath];
                }
            }
        }
    } else if (_respond_heightForIndexPath) {
        cellHeight = ([_mpDataSource MPTableView:self heightForIndexPath:indexPath]);
    } else {
        cellHeight = self.rowHeight;
    }
    
    if (cellHeight < 0 || cellHeight > MPTableViewMaxSize) {
        @throw @"cell height";
    }
    
    return cellHeight;
}

- (CGFloat)__rebuildCellAtSection:(NSInteger)section fromOriginSection:(NSInteger)originSection atIndex:(NSInteger)index {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:section];
    if (originSection != section) {
        indexPath.section = originSection;
        if ([_displayedCellsDic objectForKey:indexPath]) {
            return 0;
        } else {
            indexPath.section = section;
        }
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    
    if ([self __isEstimatedMode] && MPTableView_Offscreen) {
        return frame.origin.y > _contentOffset.endPos ? MPTableViewMaxSize : 0;
    } else {
        CGFloat cellHeight = frame.size.height;
        
        if (_respond_heightForIndexPath) {
            frame.size.height = ([_mpDataSource MPTableView:self heightForIndexPath:indexPath]);
        } else if (_respond_estimatedHeightForRowAtIndexPath) {
            MPTableViewCell *cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
            if (!cell) {
                @throw @"cell must not be null";
            }
            
            cell.frame = frame;
            [cell layoutIfNeeded];
            frame.size.height = [cell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
            
            if (MPTableView_Offscreen) {
                [self _cacheCell:cell];
            } else {
                [_estimatedCellsDic setObject:cell forKey:indexPath];
            }
        }
        
        return frame.size.height - cellHeight;
    }
}

- (void)__updateSection:(NSInteger)originSection deleteCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:originSection];
    
    if ([indexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
        return ;
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    CGFloat updateDeleteOriginTopPosition = _updateDeleteOriginTopPosition;
    
    if (animation == MPTableViewRowAnimationCustom) {
        if (_respond_beginToDeleteCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self beginToDeleteCell:cell forRowAtIndexPath:indexPath withAnimationPathPosition:updateDeleteOriginTopPosition];
        }
    } else {
        if (animation == MPTableViewRowAnimationNone) {
            [self _cacheCell:cell];
        } else {
            if (animation == MPTableViewRowAnimationTop) {
                [_contentWrapperView sendSubviewToBack:cell];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [_contentWrapperView bringSubviewToFront:cell];
            }
            
            void (^animationBlock)(void) = ^{
                CGRect targetFrame = MPTableViewDisappearViewFrameWithRowAnimation(cell, updateDeleteOriginTopPosition, animation, sectionPosition);
                
                targetFrame.origin.y = [self _updateGetOptimizedYWithFrame:cell.frame toTargetY:targetFrame.origin.y];
                    
                cell.frame = targetFrame;
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_deleteCellsDic setObject:cell forKey:indexPath];
        }
    }
    
    [_displayedCellsDic removeObjectForKey:indexPath];
}

- (void)__updateSection:(NSInteger)section insertCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:section];
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (MPTableView_Offscreen) { //
        return ;
    } else {
        MPTableViewCell *cell = nil;
        if (_respond_estimatedHeightForRowAtIndexPath && !_respond_heightForIndexPath) {
            cell = [_estimatedCellsDic objectForKey:indexPath];
        }
        
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        } else {
            [_estimatedCellsDic removeObjectForKey:indexPath];
        }
        
        [cell setSelected:[_selectedIndexPaths containsObject:indexPath]];
        
        cell.frame = frame;
        
        if (_respond_willDisplayCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
        
        [self _addCellToWrapperViewIfNeeded:cell];
        
        CGFloat updateInsertOriginTopPosition = _updateInsertOriginTopPosition;
        if (animation == MPTableViewRowAnimationCustom) {
            if (_respond_beginToInsertCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self beginToInsertCell:cell forRowAtIndexPath:indexPath withAnimationPathPosition:updateInsertOriginTopPosition];
            }
        } else {
            if (animation != MPTableViewRowAnimationNone) {
                if (animation == MPTableViewRowAnimationTop) {
                    [_contentWrapperView sendSubviewToBack:cell];
                }
                if (animation == MPTableViewRowAnimationBottom) {
                    [_contentWrapperView bringSubviewToFront:cell];
                }
                
                CGRect targetFrame = MPTableViewDisappearViewFrameWithRowAnimation(cell, updateInsertOriginTopPosition, animation, sectionPosition);
                
                targetFrame.origin.y = [self _updateGetOptimizedYWithFrame:cell.frame toTargetY:targetFrame.origin.y];
                
                cell.frame = targetFrame;
                
                void (^animationBlock)(void) = ^{
                    MPTableViewDisplayViewFrameWithRowAnimation(cell, frame, animation, sectionPosition);
                };
                
                [_updateAnimationBlocks addObject:animationBlock];
            }
        }
        
        [_insertCellsDic setObject:cell forKey:indexPath];
    }
}

- (CGFloat)__updateSection:(NSInteger)section moveInCellAtIndex:(NSInteger)index fromOriginIndexPath:(MPIndexPath *)originIndexPath withDistance:(CGFloat)distance {
    CGFloat newOffset = 0;
    
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:section];
    
    if ([_selectedIndexPaths containsObject:originIndexPath]) {
        [_selectedIndexPaths removeObject:originIndexPath];
        [_updateExchangedSelectedIndexPaths addObject:indexPath];
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:originIndexPath];
    if (cell) {
        [_displayedCellsDic removeObjectForKey:originIndexPath];
    }
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    MPTableViewSection *currSection = _sectionsAreaList[section];
    
    if (cell) {
        [_insertCellsDic setObject:cell forKey:indexPath];
        
        if (_movingIndexPath) {
            return 0;
        }
        
        [_contentWrapperView bringSubviewToFront:cell];
        
        if (currSection.updatePart && _respond_heightForIndexPath) {
            CGFloat cellHeight = frame.size.height;
            frame.size.height = [_mpDataSource MPTableView:self heightForIndexPath:indexPath];
            newOffset = frame.size.height - cellHeight;
        }
        
        void (^animationBlock)(void) = ^{
            CGRect cellFrame = cell.frame;
            cellFrame.size.height = frame.size.height;
            cellFrame.origin.y = [self _updateGetOptimizedYWithFrame:cellFrame toTargetY:frame.origin.y];
            
            cell.frame = cellFrame;
        };
        
        [_updateAnimationBlocks addObject:animationBlock];
    } else {
        if (![self isUpdateForceReload] && MPTableView_Offscreen) {
            return 0;
        }
        
        CGFloat currOriginY = frame.origin.y;
        
        if (currSection.updatePart) { // a move-in row, has not been estimated
            CGFloat cellHeight = frame.size.height;
            if (_respond_heightForIndexPath) {
                frame.size.height = [_mpDataSource MPTableView:self heightForIndexPath:indexPath];
            } else if (_respond_estimatedHeightForRowAtIndexPath) {
                cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
                if (!cell) {
                    @throw @"cell must not be null";
                }
                
                cell.frame = frame;
                [cell layoutIfNeeded];
                frame.size.height = [cell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
            }
            newOffset = frame.size.height - cellHeight;
            
            if (MPTableView_Offscreen) {
                if (cell) {
                    [self _cacheCell:cell];
                }
                return newOffset;
            }
        } else {  // from a move-in section, cell height estimated
            if (MPTableView_Offscreen) {
                return 0;
            }
            if (_respond_estimatedHeightForRowAtIndexPath && !_respond_heightForIndexPath) {
                cell = [_estimatedCellsDic objectForKey:indexPath];
                if (cell) {
                    [_estimatedCellsDic removeObjectForKey:indexPath];
                }
            }
        }
        
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        }
        
        frame.origin.y = [self _updateGetOptimizedYWithFrame:frame toTargetY:frame.origin.y - distance];
        if (MPTableView_Onscreen) {
            if (distance < 0) {
                frame.origin.y = _contentOffset.endPos + 1;
            } else {
                frame.origin.y = _contentOffset.beginPos - frame.size.height - 1;
            }
        }
        
        cell.frame = frame;
        
        if (_respond_willDisplayCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
        }
        
        [self _addCellToWrapperViewIfNeeded:cell];
        [_contentWrapperView bringSubviewToFront:cell];
        
        if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
            [cell setSelected:YES];
        }
        
        [_insertCellsDic setObject:cell forKey:indexPath];
        
        void (^animationBlock)(void) = ^{
            CGRect frame = cell.frame;
            frame.origin.y = currOriginY;
            cell.frame = frame;
        };
        
        [_updateAnimationBlocks addObject:animationBlock];
    }
    
    return newOffset;
}

- (CGFloat)__updateSection:(NSInteger)section originSection:(NSInteger)originSection adjustCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withOffset:(CGFloat)cellOffset {
    
    CGFloat newOffset = 0;
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:originIndex inSection:originSection];
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    CGRect frame;
    
    if (!cell) {
        indexPath.row = currIndex;
        indexPath.section = section;
        frame = [self _cellFrameAtIndexPath:indexPath];
        if (![self isUpdateForceReload] && MPTableView_Offscreen) {
            return 0;
        } else {
            if (!_movingIndexPath) {
                CGFloat cellHeight = frame.size.height;
                if (_respond_heightForIndexPath) {
                    frame.size.height = [_mpDataSource MPTableView:self heightForIndexPath:indexPath];
                } else if (_respond_estimatedHeightForRowAtIndexPath) {
                    cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
                    if (!cell) {
                        @throw @"cell must not be null";
                    }
                    
                    cell.frame = frame;
                    [cell layoutIfNeeded];
                    frame.size.height = [cell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
                }
                newOffset = frame.size.height - cellHeight;
                
                if (MPTableView_Offscreen) {
                    if (cell) {
                        [self _cacheCell:cell];
                    }
                    return newOffset;
                }
            }
            
            if (!cell) {
                cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            }
            
            CGFloat originY = frame.origin.y;
            frame.origin.y = [self _updateGetOptimizedYWithFrame:frame toTargetY:frame.origin.y - cellOffset];
            cell.frame = frame;
            frame.origin.y = originY;
            
            if (_respond_willDisplayCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
            }
            
            [self _addCellToWrapperViewIfNeeded:cell];
            [_insertCellsDic setObject:cell forKey:indexPath];
            if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES];
            }
        }
    } else {
        if (originIndex != currIndex || section != originSection) {
            [_displayedCellsDic removeObjectForKey:indexPath];
            indexPath.row = currIndex;
            indexPath.section = section;
            [_insertCellsDic setObject:cell forKey:indexPath];
        }
        
        frame = cell.frame;
        frame.origin.y = [self _updateGetOptimizedYWithFrame:frame toTargetY:frame.origin.y + cellOffset];
        if (_respond_heightForIndexPath && !_movingIndexPath) {
            CGFloat cellHeight = frame.size.height;
            indexPath.row = currIndex;
            indexPath.section = section;
            frame.size.height = [_mpDataSource MPTableView:self heightForIndexPath:indexPath];
            newOffset = frame.size.height - cellHeight;
        }
    }
    
    _updateInsertOriginTopPosition = CGRectGetMaxY(cell.frame);
    _updateDeleteOriginTopPosition = CGRectGetMaxY(frame);
    
    void (^animationBlock)(void) = ^{
        cell.frame = frame;
    };
    [_updateAnimationBlocks addObject:animationBlock];
    
    return newOffset;
}

- (void)__updateSection:(NSInteger)section originSection:(NSInteger)originSection adjustCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex {
    if (section == originSection && originIndex == currIndex) {
        return;
    }
    
    for (const MPIndexPath *indexPath in _selectedIndexPaths) {
        if (indexPath.section == originSection && indexPath.row == originIndex) {
            [_selectedIndexPaths removeObject:indexPath];
            [_updateExchangedSelectedIndexPaths addObject:[MPIndexPath indexPathForRow:currIndex inSection:section]];
            break;
        }
    }
}

#pragma mark -sectionView update delegate

- (MPTableViewSection *)__updateGetSectionAt:(NSInteger)sectionIndex {
    MPTableViewSection *section = [MPTableViewSection section];
    section.section = sectionIndex;
    
    CGFloat offset = 0;
    if (_sectionsAreaList.count && sectionIndex > 0) {
        MPTableViewSection *preSection = _sectionsAreaList[sectionIndex - 1];
        offset = preSection.endPos;
    }
    [self _initializeSection:section withOffset:offset];
    
    return section;
}

- (CGFloat)__rebuildHeaderHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection isInsertion:(BOOL)insertion {
    if (_movingIndexPath) {
        return -1;
    }
    
    if ([self isUpdating]) {
        if (!insertion && !_respond_heightForHeaderInSection && [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:originSection]]) {
            return -1;
        }
    } else {
        if ([_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:originSection]]) {
            return -1;
        }
    }
    
    // estimated : insert / move in, no estimated : move in
    
    if (([self isUpdating] && [self isUpdateForceReload] && ![self __isEstimatedMode]) || (section.beginPos + section.headerHeight >= _currDrawArea.beginPos && section.beginPos <= _currDrawArea.endPos) || (self.style == MPTableViewStylePlain && [self _needSuspendingSection:section withType:MPSectionTypeHeader]) || [self _needPrepareToSuspendViewAt:section withType:MPSectionTypeHeader]) {
        if (_respond_heightForHeaderInSection) {
            return [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
        } else if (_respond_estimatedHeightForHeaderInSection) {
            MPTableReusableView *sectionView = [_mpDataSource MPTableView:self viewForHeaderInSection:section.section];
            if (sectionView) {
                MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:section.section];
                [_estimatedSectionViewsDic setObject:sectionView forKey:indexPath];
                CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
                
                sectionView.frame = frame;
                [sectionView layoutIfNeeded];
                CGFloat height = [sectionView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
                return height;
            }
        }
    }
    
    return -1;
}

- (CGFloat)__force_rebuildHeaderHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection {
    if (_movingIndexPath) {
        return -1;
    }
    
    if (!_respond_heightForHeaderInSection && [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:originSection]]) {
        return -1;
    }
    
    if (_respond_heightForHeaderInSection) {
        return [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
    } else if (_respond_estimatedHeightForHeaderInSection) {
        MPTableReusableView *sectionView = [_mpDataSource MPTableView:self viewForHeaderInSection:section.section];
        if (sectionView) {
            MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:section.section];
            [_estimatedSectionViewsDic setObject:sectionView forKey:indexPath];
            CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
            
            sectionView.frame = frame;
            [sectionView layoutIfNeeded];
            CGFloat height = [sectionView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
            return height;
        }
    }
    
    return -1;
}

- (CGFloat)__rebuildFooterHeightInSection:(MPTableViewSection *)section fromOriginSection:(NSInteger)originSection isInsertion:(BOOL)insertion {
    if (_movingIndexPath) {
        return -1;
    }
    
    if ([self isUpdating]) {
        if (!insertion && !_respond_heightForFooterInSection && [_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:originSection]]) {
            return -1;
        }
    } else {
        if ([_displayedSectionViewsDic objectForKey:[MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:originSection]]) {
            return -1;
        }
    }
    
    if (([self isUpdating] && [self isUpdateForceReload] && ![self __isEstimatedMode]) || (section.endPos >= _currDrawArea.beginPos && section.endPos - section.footerHeight <= _currDrawArea.endPos) || (self.style == MPTableViewStylePlain && [self _needSuspendingSection:section withType:MPSectionTypeFooter]) || [self _needPrepareToSuspendViewAt:section withType:MPSectionTypeFooter]) {
        if (_respond_heightForFooterInSection) {
            return [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
        } else if (_respond_estimatedHeightForFooterInSection) {
            MPTableReusableView *sectionView = [_mpDataSource MPTableView:self viewForFooterInSection:section.section];
            if (sectionView) {
                MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:section.section];
                [_estimatedSectionViewsDic setObject:sectionView forKey:indexPath];
                CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
                
                sectionView.frame = frame;
                [sectionView layoutIfNeeded];
                CGFloat height = [sectionView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
                return height;
            }
        }
    }
    
    return -1;
}

- (BOOL)_needSuspendingSection:(MPTableViewSection *)section withType:(MPSectionType)type {
    if (type == MPSectionTypeHeader) {
        CGFloat beginPos = _currDrawArea.beginPos + self.contentInset.top;
        if (section.headerHeight && section.beginPos <= beginPos && section.endPos >= beginPos) {
            if (_lastSuspendHeaderSection == NSNotFound) {
                _lastSuspendHeaderSection = _currSuspendHeaderSection;
            }
            _currSuspendHeaderSection = section.section;
            return YES;
        } else {
            return NO;
        }
    } else {
        CGFloat endPos = _currDrawArea.endPos - self.contentInset.bottom;
        if (section.footerHeight && section.beginPos <= endPos && section.endPos >= endPos) {
            if (_lastSuspendFooterSection == NSNotFound) {
                _lastSuspendFooterSection = _currSuspendFooterSection;
            }
            _currSuspendFooterSection = section.section;
            return YES;
        } else {
            return NO;
        }
    }
}

//// deprecated
//- (void)_updateOptimizeSectionView:(UIView *)sectionView withType:(MPSectionType)type inSection:(MPTableViewSection *)section {
//    CGFloat originY;
//    
//    if (type == MPSectionTypeHeader) {
//        if (section.beginPos < _currDrawArea.beginPos) {
//            originY = _currDrawArea.beginPos - sectionView.frame.size.height - 1;
//        } else {
//            originY = section.beginPos;
//        }
//    } else {
//        if (section.endPos > _currDrawArea.endPos) {
//            originY = _currDrawArea.endPos + 1;
//        } else {
//            originY = section.endPos - section.footerHeight;
//        }
//    }
//    
//    if (sectionView) {
//        CGRect frame = sectionView.frame;
//        frame.origin.y = originY + _contentDrawArea.beginPos;
//        sectionView.frame = frame;
//    }
//}

- (void)__updateDeleteSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    
    if (self.style == MPTableViewStylePlain) {
        if (type == MPSectionTypeHeader) {
            if (_lastSuspendHeaderSection == NSNotFound && _currSuspendHeaderSection == index) {
                _lastSuspendHeaderSection = _currSuspendHeaderSection;
                _currSuspendHeaderSection = NSNotFound;
            }
        } else {
            if (_lastSuspendFooterSection == NSNotFound && _currSuspendFooterSection == index) {
                _lastSuspendFooterSection = _currSuspendFooterSection;
                _currSuspendFooterSection = NSNotFound;
            }
        }
    }
    
    if (!sectionView) {
        return;
    }
    
    CGFloat updateDeleteOriginTopPosition = _updateDeleteOriginTopPosition;
    
    if (animation == MPTableViewRowAnimationCustom) {
        if (type == MPSectionTypeHeader) {
            if (_respond_beginToDeleteHeaderViewForSection) {
                [_mpDelegate MPTableView:self beginToDeleteHeaderView:sectionView forSection:index withAnimationPathPosition:updateDeleteOriginTopPosition];
            }
        } else {
            if (_respond_beginToDeleteFooterViewForSection) {
                [_mpDelegate MPTableView:self beginToDeleteFooterView:sectionView forSection:index withAnimationPathPosition:updateDeleteOriginTopPosition];
            }
        }
    } else {
        if (animation == MPTableViewRowAnimationNone) {
            [self _cacheSectionView:sectionView];
        } else {
            if (animation == MPTableViewRowAnimationTop) {
                [self insertSubview:sectionView aboveSubview:_contentWrapperView];
            }
            if (animation == MPTableViewRowAnimationBottom) {
                [self bringSubviewToFront:sectionView];
            }
            
            void (^animationBlock)(void) = ^{
                CGRect targetFrame = MPTableViewDisappearViewFrameWithRowAnimation(sectionView, updateDeleteOriginTopPosition, animation, deleteSection);
                
                if (animation != MPTableViewRowAnimationNone) {
                    targetFrame.origin.y = [self _updateGetOptimizedYWithFrame:sectionView.frame toTargetY:targetFrame.origin.y];
                    
                    sectionView.frame = targetFrame;
                }
            };
            
            [_updateAnimationBlocks addObject:animationBlock];
            [_deleteSectionViewsDic setObject:sectionView forKey:indexPath];
        }
    }
    
    [_displayedSectionViewsDic removeObjectForKey:indexPath];
}

- (void)__updateInsertSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
    
    BOOL isDisplayingDefault = MPTableView_Onscreen;
    BOOL isSuspending = NO;
    BOOL isPrepareToSuspend = NO;
    
    if (self.style == MPTableViewStylePlain) {
        if ([self _needSuspendingSection:insertSection withType:type]) {
            isSuspending = YES;
            isDisplayingDefault = NO;
        } else if ([self _needPrepareToSuspendViewAt:insertSection withType:type]) {
            isPrepareToSuspend = YES;
            isDisplayingDefault = NO;
        }
    }
    
    if (!isDisplayingDefault && !isSuspending && !isPrepareToSuspend) { //
        return ;
    } else {
        MPTableReusableView *sectionView = nil;
        if (type == MPSectionTypeHeader && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (type == MPSectionTypeFooter && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        sectionView.frame = frame;
        
        if (type == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSectionViewToWrapperViewIfNeeded:sectionView];
        
        CGFloat updateInsertOriginTopPosition = _updateInsertOriginTopPosition;
        if (animation == MPTableViewRowAnimationCustom) {
            if (isSuspending) {
                if (type == MPSectionTypeHeader) {
                    [self _suspendingSectionHeader:sectionView inArea:insertSection];
                } else {
                    [self _suspendingSectionFooter:sectionView inArea:insertSection];
                }
            } else if (isPrepareToSuspend) {
                [self _prepareToSuspendView:sectionView atSection:insertSection withType:type];
            }
            
            if (type == MPSectionTypeHeader) {
                if (_respond_beginToInsertHeaderViewForSection) {
                    [_mpDelegate MPTableView:self beginToInsertHeaderView:sectionView forSection:index withAnimationPathPosition:updateInsertOriginTopPosition];
                }
            } else {
                if (_respond_beginToInsertFooterViewForSection) {
                    [_mpDelegate MPTableView:self beginToInsertFooterView:sectionView forSection:index withAnimationPathPosition:updateInsertOriginTopPosition];
                }
            }
        } else {
            if (animation == MPTableViewRowAnimationNone) {
                if (isSuspending) {
                    if (type == MPSectionTypeHeader) {
                        [self _suspendingSectionHeader:sectionView inArea:insertSection];
                    } else {
                        [self _suspendingSectionFooter:sectionView inArea:insertSection];
                    }
                } else if (isPrepareToSuspend) {
                    [self _prepareToSuspendView:sectionView atSection:insertSection withType:type];
                }
            } else {
                if (animation == MPTableViewRowAnimationTop) {
                    [self insertSubview:sectionView aboveSubview:_contentWrapperView];
                }
                if (animation == MPTableViewRowAnimationBottom) {
                    [self bringSubviewToFront:sectionView];
                }
                
                CGRect targetFrame = MPTableViewDisappearViewFrameWithRowAnimation(sectionView, updateInsertOriginTopPosition, animation, insertSection);
                
                targetFrame.origin.y = [self _updateGetOptimizedYWithFrame:sectionView.frame toTargetY:targetFrame.origin.y];
                
                sectionView.frame = targetFrame;
                
                void (^animationBlock)(void) = ^{
                    MPTableViewDisplayViewFrameWithRowAnimation(sectionView, frame, animation, insertSection);
                    
                    if (isSuspending) {
                        if (type == MPSectionTypeHeader) {
                            [self _suspendingSectionHeader:sectionView inArea:insertSection];
                        } else {
                            [self _suspendingSectionFooter:sectionView inArea:insertSection];
                        }
                    } else if (isPrepareToSuspend) {
                        [self _prepareToSuspendView:sectionView atSection:insertSection withType:type];
                    }
                };
                
                [_updateAnimationBlocks addObject:animationBlock];
            }
        }
        
        [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
    }
}

- (void)__updateMoveInSectionViewAtIndex:(NSInteger)index fromOriginIndex:(NSInteger)originIndex withType:(MPSectionType)type withDistance:(CGFloat)distance {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    MPIndexPath *originIndexPath = [MPIndexPath indexPathForRow:type inSection:originIndex];
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:originIndexPath];
    if (sectionView) {
        [_displayedSectionViewsDic removeObjectForKey:originIndexPath];
    }
    
    CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
    BOOL isDisplayingDefault = MPTableView_Onscreen;
    BOOL isSuspending = NO;
    BOOL isPrepareToSuspend = NO;
    
    if (self.style == MPTableViewStylePlain) {
        MPTableViewSection *section = _sectionsAreaList[index];
        if ([self _needSuspendingSection:section withType:type]) {
            isSuspending = YES;
            isDisplayingDefault = NO;
        } else {
            if (type == MPSectionTypeHeader) {
                if (_lastSuspendHeaderSection == NSNotFound && _currSuspendHeaderSection == originIndex) {
                    _lastSuspendHeaderSection = _currSuspendHeaderSection;
                    _currSuspendHeaderSection = NSNotFound;
                }
            } else {
                if (_lastSuspendFooterSection == NSNotFound && _currSuspendFooterSection == originIndex) {
                    _lastSuspendFooterSection = _currSuspendFooterSection;
                    _currSuspendFooterSection = NSNotFound;
                }
            }
            
            if ([self _needPrepareToSuspendViewAt:section withType:type]) {
                isPrepareToSuspend = YES;
                isDisplayingDefault = NO;
            }
        }
    }
    
    if (sectionView) {
        [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
        
        [self bringSubviewToFront:sectionView];
        
        CGRect newFrame = sectionView.frame;
        newFrame.size.height = frame.size.height;
        frame.origin.y = [self _updateGetOptimizedYWithFrame:newFrame toTargetY:frame.origin.y];
    } else {
        if (!isDisplayingDefault && !isSuspending && !isPrepareToSuspend) {
            return;
        }
        
        if (type == MPSectionTypeHeader && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (type == MPSectionTypeFooter && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        CGFloat currOriginY = frame.origin.y;
        frame.origin.y = [self _updateGetOptimizedYWithFrame:frame toTargetY:frame.origin.y - distance];
        if (MPTableView_Onscreen) {
            if (distance < 0) {
                frame.origin.y = _contentOffset.endPos + 1;
            } else {
                frame.origin.y = _contentOffset.beginPos - frame.size.height - 1;
            }
        }
        
        sectionView.frame = frame;
        frame.origin.y = currOriginY;
        
        if (type == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSectionViewToWrapperViewIfNeeded:sectionView];
        [self bringSubviewToFront:sectionView];
        
        [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
    }
    
    void (^animationBlock)(void) = ^{
        if (isDisplayingDefault) {
            sectionView.frame = frame;
        } else if (isSuspending) {
            if (self.style == MPTableViewStylePlain) {
                if (type == MPSectionTypeHeader) {
                    [self _suspendingSectionHeader:sectionView inArea:_sectionsAreaList[index]];
                }
                if (type == MPSectionTypeFooter) {
                    [self _suspendingSectionFooter:sectionView inArea:_sectionsAreaList[index]];
                }
            }
        } else {
            [self _prepareToSuspendView:sectionView atSection:_sectionsAreaList[index] withType:type];
        }
    };
    
    [_updateAnimationBlocks addObject:animationBlock];
}

- (void)__updateAdjustSectionViewAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withType:(MPSectionType)type withSectionOffset:(CGFloat)sectionOffset {
    
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:originIndex];
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    
    BOOL isSuspending = NO;
    BOOL isPrepareToSuspend = NO;
    
    if (self.style == MPTableViewStylePlain) {
        MPTableViewSection *section = _sectionsAreaList[currIndex];
        if ([self _needSuspendingSection:section withType:type]) {
            isSuspending = YES;
        } else {
            if (type == MPSectionTypeHeader) {
                if (_lastSuspendHeaderSection == NSNotFound && _currSuspendHeaderSection == originIndex) {
                    _lastSuspendHeaderSection = _currSuspendHeaderSection;
                    _currSuspendHeaderSection = NSNotFound;
                }
            } else {
                if (_lastSuspendFooterSection == NSNotFound && _currSuspendFooterSection == originIndex) {
                    _lastSuspendFooterSection = _currSuspendFooterSection;
                    _currSuspendFooterSection = NSNotFound;
                }
            }
            
            if ([self _needPrepareToSuspendViewAt:section withType:type]) {
                isPrepareToSuspend = YES;
            }
        }
    }
    
    CGRect frame;
    
    if (!sectionView) {
        indexPath.section = currIndex;
        frame = [self _sectionViewFrameAtIndexPath:indexPath];
        if (MPTableView_Offscreen && !isSuspending && !isPrepareToSuspend) {
            return ;
        } else {
            if (type == MPSectionTypeHeader && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
                sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
            } else if (type == MPSectionTypeFooter && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
                sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
            }
            
            if (!sectionView) {
                sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
            } else {
                [_estimatedSectionViewsDic removeObjectForKey:indexPath];
            }
            
            if (!sectionView) {
                return;
            }
            
            CGFloat originY = frame.origin.y;
            frame.origin.y = [self _updateGetOptimizedYWithFrame:frame toTargetY:frame.origin.y - sectionOffset];
            
            if (MPTableView_Onscreen) {
                if (sectionOffset < 0) {
                    frame.origin.y = _contentOffset.endPos + 1;
                } else {
                    frame.origin.y = _contentOffset.beginPos - frame.size.height - 1;
                }
            }
            
            sectionView.frame = frame;
            frame.origin.y = originY;
            
            if (type == MPSectionTypeHeader) {
                if (_respond_willDisplayHeaderViewForSection) {
                    [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
                }
            } else {
                if (_respond_willDisplayFooterViewForSection) {
                    [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
                }
            }
            
            [self _addSectionViewToWrapperViewIfNeeded:sectionView];
            [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
        }
    } else {
        if (originIndex != currIndex) {
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            indexPath.section = currIndex;
            [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
        }
        
        frame = sectionView.frame;
        frame.size.height = [self _sectionViewFrameAtIndexPath:indexPath].size.height;
        CGFloat originY = frame.origin.y + sectionOffset;
        
        if (self.style == MPTableViewStylePlain && !isSuspending && !isPrepareToSuspend) { // displaying
            MPTableViewSection *section = _sectionsAreaList[currIndex];
            if (type == MPSectionTypeHeader && originY != section.beginPos + _contentDrawArea.beginPos) { // need to reset
                originY = section.beginPos + _contentDrawArea.beginPos;
            }
            if (type == MPSectionTypeFooter && originY != section.endPos - section.footerHeight + _contentDrawArea.beginPos) { // need to reset
                originY = section.endPos - section.footerHeight + _contentDrawArea.beginPos;
            }
        }
        
        frame.origin.y = [self _updateGetOptimizedYWithFrame:frame toTargetY:originY];
    }
    
    
    CGFloat newTopPosition = CGRectGetMaxY(sectionView.frame);
    if (newTopPosition > _updateInsertOriginTopPosition) {
        _updateInsertOriginTopPosition = newTopPosition;
    }
    
    newTopPosition = CGRectGetMaxY(frame);
    if (newTopPosition > _updateDeleteOriginTopPosition) {
        _updateDeleteOriginTopPosition = newTopPosition;
    }
    
    void (^animationBlock)(void) = ^{
        if (isSuspending) {
            if (type == MPSectionTypeHeader) {
                [self _suspendingSectionHeader:sectionView inArea:_sectionsAreaList[currIndex]];
            } else {
                [self _suspendingSectionFooter:sectionView inArea:_sectionsAreaList[currIndex]];
            }
        } else if (isPrepareToSuspend) {
            [self _prepareToSuspendView:sectionView atSection:_sectionsAreaList[currIndex] withType:type];
        } else {
            sectionView.frame = frame;
        }
    };
    
    [_updateAnimationBlocks addObject:animationBlock];
}

#pragma mark --estimated layout

- (BOOL)__isEstimatedMode {
    return _respond_estimatedHeightForRowAtIndexPath || _respond_estimatedHeightForHeaderInSection || _respond_estimatedHeightForFooterInSection;
}

- (void)_startEstimatedUpdateAtFirstIndexPath:(MPIndexPathStruct)firstIndexPath {
    _lastSuspendFooterSection = _lastSuspendHeaderSection = NSNotFound;
    
    CGFloat offset = [_estimatedUpdateManager startUpdate:firstIndexPath];
    
    _contentDrawArea.endPos += offset;
    
    if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        _beginIndexPath = MPIndexPathStructMake(NSIntegerMax, MPSectionTypeFooter);
        _endIndexPath = MPIndexPathStructMake(NSIntegerMin, MPSectionTypeHeader);
    } else {
        _beginIndexPath = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
        _endIndexPath = [self _indexPathAtContentOffset:_currDrawArea.endPos];
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
    
    // clip...
    [self _clipCellsBetween:_beginIndexPath and:_endIndexPath];
    
    [self _adjustEstimatedSectionViewsBetween:_beginIndexPath and:_endIndexPath];
    
    if (offset != 0 && self.tableFooterView) {
        CGRect frame = self.tableFooterView.frame;
        frame.origin.y += offset;
        self.tableFooterView.frame = frame;
    }
    
    CGSize contentSize = CGSizeMake(self.frame.size.width, _contentDrawArea.endPos + self.tableFooterView.frame.size.height);
    if (!CGSizeEqualToSize(self.contentSize, contentSize)) {
        [self setContentSize:contentSize];
        
        // Change a scrollview's content size when it is bouncing will make -layoutSubviews not be called in the next runloop. This situation is possibly an UIKit bug.
        if (_contentOffset.beginPos < -self.contentInset.top || _contentOffset.beginPos > self.contentSize.height - self.frame.size.height + self.contentInset.bottom) {
            CFRunLoopRef runLoop = CFRunLoopGetCurrent();
            CFStringRef runLoopMode = kCFRunLoopCommonModes;
            CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, false, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
                [self layoutSubviews];
                CFRunLoopRemoveObserver(runLoop, observer, runLoopMode);
            });
            CFRunLoopAddObserver(runLoop, observer, runLoopMode);
        }
    }
}

- (CGFloat)__estimateSectionView:(MPSectionType)type inSection:(MPTableViewSection *)section {
    if (type == MPSectionTypeHeader) {
        if (_respond_estimatedHeightForHeaderInSection) {
            return [self __rebuildHeaderHeightInSection:section fromOriginSection:section.section isInsertion:NO];
        } else {
            return -1;
        }
    } else {
        if (_respond_estimatedHeightForFooterInSection) {
            return [self __rebuildFooterHeightInSection:section fromOriginSection:section.section isInsertion:NO];
        } else {
            return -1;
        }
    }
}

- (CGFloat)__estimateAdjustCellAtSection:(NSInteger)originSection atIndex:(NSInteger)originIndex withOffset:(CGFloat)cellOffset {
    CGFloat newOffset = 0;
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:originIndex inSection:originSection];
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    if (!cell) {
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (MPTableView_Offscreen) {
            return frame.origin.y > _contentOffset.endPos ? MPTableViewMaxSize : 0;
        } else {
            if (_respond_estimatedHeightForRowAtIndexPath) {
                CGFloat cellHeight = frame.size.height;
                if (_respond_heightForIndexPath) {
                    frame.size.height = [_mpDataSource MPTableView:self heightForIndexPath:indexPath];
                    cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                } else {
                    cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
                    if (!cell) {
                        @throw @"cell must not be null";
                    }
                    
                    cell.frame = frame;
                    [cell layoutIfNeeded];
                    frame.size.height = [cell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
                    
                    if (MPTableView_Offscreen) {
                        [self _cacheCell:cell];
                        return frame.size.height - cellHeight;
                    }
                }
                newOffset = frame.size.height - cellHeight;
            } else {
                cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            }
            
            cell.frame = frame;
            
            if (_respond_willDisplayCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
            }
            
            if ([_selectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES];
            }
            
            [self _addCellToWrapperViewIfNeeded:cell];
            [_displayedCellsDic setObject:cell forKey:indexPath];
        }
    } else {
        if (cellOffset != 0) {
            CGRect frame = cell.frame;
            frame.origin.y += cellOffset;
            cell.frame = frame;
        }
    }
    
    return newOffset;
}

- (void)__estimateAdjustSectionViewAtSection:(NSInteger)index withType:(MPSectionType)type {
    
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (sectionView) {
        return;
    }
    
    BOOL isSuspending = NO;
    BOOL isPrepareToSuspend = NO;
    
    if (self.style == MPTableViewStylePlain) {
        MPTableViewSection *section = _sectionsAreaList[index];
        if ([self _needSuspendingSection:section withType:type]) {
            isSuspending = YES;
        } else {
            if ([self _needPrepareToSuspendViewAt:section withType:type]) {
                isPrepareToSuspend = YES;
            }
        }
    }
    
    CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
    if (MPTableView_Offscreen && !isSuspending && !isPrepareToSuspend) {
        return;
    } else {
        if (type == MPSectionTypeHeader && _respond_estimatedHeightForHeaderInSection && !_respond_heightForHeaderInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        } else if (type == MPSectionTypeFooter && _respond_estimatedHeightForFooterInSection && !_respond_heightForFooterInSection) {
            sectionView = [_estimatedSectionViewsDic objectForKey:indexPath];
        }
        
        if (!sectionView) {
            sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
        } else {
            [_estimatedSectionViewsDic removeObjectForKey:indexPath];
        }
        
        if (!sectionView) {
            return;
        }
        
        sectionView.frame = frame;
        
        if (type == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSectionViewToWrapperViewIfNeeded:sectionView];
        
        [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    }
}

#pragma mark --reload

- (BOOL)isCachesReloadEnabled {
    return _cachesReloadEnabled;
}
//
- (void)_clear {
    _contentDrawArea.beginPos = _contentDrawArea.endPos = 0;
    _currDrawArea.beginPos = _currDrawArea.endPos = 0;
    _contentOffset.beginPos = _contentOffset.endPos = 0;

    [_selectedIndexPaths removeAllObjects];
    [_prefetchIndexPaths removeAllObjects];

    [self _resetContentIndexPaths];
    
    [self _endMovingCellIfNeeded];
    
    if ([self isCachesReloadEnabled]) {
        [self _cacheDisplayingCells];
        [self _cacheDisplayingSectionViews];
    } else {
        [self clearReusableCells];
        [self clearReusableSectionViews];
        
        [self _clearDisplayingCells];
        [self _clearDisplayingSectionViews];
    }
}

- (void)_resetContentIndexPaths {
    _currSuspendFooterSection = _currSuspendHeaderSection = NSNotFound;
    
    _beginIndexPath = MPIndexPathStructMake(NSIntegerMax, MPSectionTypeFooter);
    _endIndexPath = MPIndexPathStructMake(NSIntegerMin, MPSectionTypeHeader);
    
    _highlightedIndexPath = nil;
}

- (void)_cacheDisplayingCells {
    NSArray *indexPaths = [_displayedCellsDic.allKeys sortedArrayUsingComparator:^NSComparisonResult(MPIndexPath *obj1, MPIndexPath *obj2) {
        return [obj2 compare:obj1];
    }];
    
    for (MPIndexPath *indexPath in indexPaths) {
        [self _cacheCell:[_displayedCellsDic objectForKey:indexPath]];
    }
    
    [_displayedCellsDic removeAllObjects];
}

- (void)_cacheDisplayingSectionViews {
    NSArray *indexPaths = [_displayedSectionViewsDic.allKeys sortedArrayUsingComparator:^NSComparisonResult(MPIndexPath *obj1, MPIndexPath *obj2) {
        return [obj2 compareRowSection:obj1];
    }];
    
    for (MPIndexPath *indexPath in indexPaths) {
        [self _cacheSectionView:[_displayedSectionViewsDic objectForKey:indexPath]];
    }
    
    [_displayedSectionViewsDic removeAllObjects];
}

- (void)_clearDisplayingCells {
    [_displayedCellsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_displayedCellsDic removeAllObjects];
}

- (void)clearReusableCells {
    for (NSMutableArray *queue in _reusableCellsDic.allValues) {
        [queue makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [queue removeAllObjects];
    }
    [_reusableCellsDic removeAllObjects];
}

- (void)clearReusableSectionViews {
    for (NSMutableArray *queue in _reusableReusableViewsDic.allValues) {
        [queue makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [queue removeAllObjects];
    }
    [_reusableReusableViewsDic removeAllObjects];
}

- (void)_clearDisplayingSectionViews {
    [_displayedSectionViewsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_displayedSectionViewsDic removeAllObjects];
}

- (void)reloadData {
    if (!_mpDataSource) {
        return;
    }
    
    if ([NSRunLoop currentRunLoop] != [NSRunLoop mainRunLoop]) {
        return [self performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    }
    [self _lockLayoutSubviews];
    [self _clear];
    CGFloat height = [self _initializeViewsPositionWithNewSections:nil];
    [self _setVerticalContentHeight:height];
    [self _unlockLayoutSubviews];
    [self _getDisplayingArea];
    if (_numberOfSections) {
        [self _updateDisplayingArea];
    }
}

- (void)reloadDataAsyncWithCompletion:(void (^)(void))completion {
    if (!_mpDataSource) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newSections = [NSMutableArray array];
        CGFloat height = [self _initializeViewsPositionWithNewSections:newSections];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _lockLayoutSubviews];
            [self _clear];
            _estimatedUpdateManager.sections = _updateManager.sections = _sectionsAreaList = newSections;
            [self _unlockLayoutSubviews];
            if (height != MPTableViewMaxSize && [self superview]) {
                [self _setVerticalContentHeight:height];
                [self _getDisplayingArea];
                [self _updateDisplayingArea];
            }
            if (completion) {
                completion();
            }
        });
    });
}

- (CGFloat)_initializeSection:(MPTableViewSection *)section withOffset:(CGFloat)step {
    // header
    section.beginPos = step;
    CGFloat height = 0;
    
    if (_respond_estimatedHeightForHeaderInSection) {
        MPTableView_ReloadAsync_Exception
        height = [_mpDataSource MPTableView:self estimatedHeightForHeaderInSection:section.section];
    } else {
        if (_respond_heightForHeaderInSection) {
            MPTableView_ReloadAsync_Exception
            height = [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
        } else {
            height = self.sectionHeaderHeight;
        }
    }
    
    if (height < 0 || height >= MPTableViewMaxSize) {
        @throw @"section header height";
    }
    
    section.headerHeight = height;
    step += height;
    
    if (_mpDataSource) {
        NSUInteger rowsInSection = [_mpDataSource MPTableView:self numberOfRowsInSection:section.section];
        section.numberOfRows = rowsInSection;
        for (NSInteger j = 0; j < rowsInSection; j++) {
            CGFloat cellHeight;
            if (_respond_estimatedHeightForRowAtIndexPath) {
                MPTableView_ReloadAsync_Exception
                cellHeight = [_mpDataSource MPTableView:self estimatedHeightForRowAtIndexPath:[MPIndexPath indexPathForRow:j inSection:section.section]];
            } else {
                if (_respond_heightForIndexPath) {
                    MPTableView_ReloadAsync_Exception
                    cellHeight = [_mpDataSource MPTableView:self heightForIndexPath:[MPIndexPath indexPathForRow:j inSection:section.section]];
                } else {
                    cellHeight = self.rowHeight;
                }
            }
            
            if (cellHeight < 0 || cellHeight >= MPTableViewMaxSize) {
                @throw @"cell height";
            }
            
            [section addRowWithPosition:step += cellHeight];
        }
    }
    // footer
    height = 0;
    if (_respond_estimatedHeightForFooterInSection) {
        MPTableView_ReloadAsync_Exception
        height = [_mpDataSource MPTableView:self estimatedHeightForFooterInSection:section.section];
    } else {
        if (_respond_heightForFooterInSection) {
            MPTableView_ReloadAsync_Exception
            height = [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
        } else {
            height = self.sectionFooterHeight;
        }
    }
    
    if (height < 0 || height >= MPTableViewMaxSize) {
        @throw @"section header height";
    }
    
    section.footerHeight = height;
    step += height;
    
    section.endPos = step;
    return step;
}

- (CGFloat)_initializeViewsPositionWithNewSections:(NSMutableArray *)newSections {
    CGFloat step = 0;
    const NSUInteger sectionsCount = _sectionsAreaList.count;
    MPTableView_ReloadAsync_Exception
    if (_respond_numberOfSectionsInMPTableView) {
        _numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
        NSAssert(_numberOfSections < MPTableViewMaxCount, @"too many sections");
    }
    
    if (sectionsCount > _numberOfSections && !newSections) {
        [_sectionsAreaList removeObjectsInRange:NSMakeRange(_numberOfSections, sectionsCount - _numberOfSections)];
    }
    for (NSInteger i = 0; i < _numberOfSections; i++) {
        MPTableViewSection *section;
        if (i < sectionsCount && !newSections) {
            section = _sectionsAreaList[i];
            [section resetSection];
        } else {
            section = [MPTableViewSection section];
        }
        section.section = i;
        
        step = [self _initializeSection:section withOffset:step];
        if (step == MPTableViewMaxSize) {
            [newSections removeAllObjects];
            break;
        }
        if (i >= sectionsCount && !newSections) {
            [_sectionsAreaList addObject:section];
        }
        if (newSections) {
            [newSections addObject:section];
        }
    }
    return step;
}
// header、footer、contentSize
- (void)_setVerticalContentHeight:(CGFloat)height {
    CGFloat contentSizeHeight = 0;
    if (self.tableHeaderView) {
        contentSizeHeight = _contentDrawArea.beginPos = (self.tableHeaderView.frame.size.height);
    }
    contentSizeHeight = _contentDrawArea.endPos = _contentDrawArea.beginPos + height;
    if (self.tableFooterView) {
        CGRect frame = self.tableFooterView.frame;
        frame.origin.y = _contentDrawArea.endPos;
        self.tableFooterView.frame = frame;
        
        contentSizeHeight += frame.size.height;
    }
    [self setContentSize:CGSizeMake(self.frame.size.width, contentSizeHeight)];
}

#pragma mark -layoutSubviews

- (BOOL)_isLayoutSubviewsLock {
    return _layoutSubviewsLock;
}

- (void)_lockLayoutSubviews {
    _layoutSubviewsLock = YES;
}

- (void)_unlockLayoutSubviews {
    _layoutSubviewsLock = NO;
}

- (void)_getDisplayingArea {
    _contentOffset.beginPos = self.contentOffset.y;
    _contentOffset.endPos = self.contentOffset.y + self.frame.size.height;
    
    _currDrawArea.beginPos = _contentOffset.beginPos - _contentDrawArea.beginPos;
    _currDrawArea.endPos = _contentOffset.endPos - _contentDrawArea.beginPos;    
}

- (NSInteger)_sectionIndexAtContentOffset:(CGFloat)target {
    NSInteger __count = _sectionsAreaList.count;
    NSInteger __start = 0;
    NSInteger __end = __count - 1;
    NSInteger __middle = 0;
    while (__start <= __end) {
        __middle = (__start + __end) / 2;
        MPTableViewSection *section = _sectionsAreaList[__middle];
        if (section.endPos < target) {
            __start = __middle + 1;
        } else if (section.beginPos > target) {
            __end = __middle - 1;
        } else {
            return __middle;
        }
    }
    return __count - 1; // floating-point precision, target > _sectionsAreaList.lastObject.endPos
}

- (MPIndexPathStruct)_indexPathAtContentOffset:(CGFloat)target {
    if (target > _contentDrawArea.endPos - _contentDrawArea.beginPos) {
        target = _contentDrawArea.endPos - _contentDrawArea.beginPos;
    }
    if (target < 0) {
        target = 0;
    }
    
    NSInteger sectionIndex = [self _sectionIndexAtContentOffset:target];
    MPTableViewSection *section = _sectionsAreaList[sectionIndex];
    NSInteger row = [section rowAtContentOffset:target];
    return MPIndexPathStructMake(sectionIndex, row);
}

- (void)_addCellToWrapperViewIfNeeded:(MPTableViewCell *)cell {
    if (![cell superview] || cell.superview != _contentWrapperView) {
        if (_movingDraggedCell) {
            [_contentWrapperView insertSubview:cell belowSubview:_movingDraggedCell];
        } else {
            [_contentWrapperView addSubview:cell];
        }
    }
}

- (void)_addSectionViewToWrapperViewIfNeeded:(MPTableReusableView *)sectionView {
    if (![sectionView superview] || sectionView.superview != self) {
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
    }
}

- (void)_cacheCell:(MPTableViewCell *)cell {
    if ([cell identifier]) {
        [cell prepareForRecovery];
        
        NSMutableArray *queue = [_reusableCellsDic objectForKey:cell.identifier];
        if (!queue) {
            queue = [NSMutableArray array];
            [_reusableCellsDic setObject:queue forKey:cell.identifier];
        }
        [queue addObject:cell];
        cell.hidden = YES;
        [cell setSelected:NO];
    } else {
        [cell removeFromSuperview];
    }
}

- (void)_clipCellsBetween:(MPIndexPathStruct)beginIndexPathStruct and:(MPIndexPathStruct)endIndexPathStruct {
    NSArray *indexPaths = _displayedCellsDic.allKeys;
    for (MPIndexPath *indexPath in indexPaths) {
        if ([indexPath compareIndexPathAt:beginIndexPathStruct] == NSOrderedAscending || [indexPath compareIndexPathAt:endIndexPathStruct] == NSOrderedDescending) {
            if (_movingIndexPath && [indexPath compareRowSection:_movingIndexPath] == NSOrderedSame) {
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
    if ([sectionView identifier]) {
        [sectionView prepareForRecovery];
        
        NSMutableArray *queue = [_reusableReusableViewsDic objectForKey:sectionView.identifier];
        if (!queue) {
            queue = [NSMutableArray array];
            [_reusableReusableViewsDic setObject:queue forKey:sectionView.identifier];
        }
        sectionView.hidden = YES;
        [queue addObject:sectionView];
    } else {
        [sectionView removeFromSuperview];
    }
}

- (BOOL)_isSuspendingAtIndexPath:(MPIndexPath *)indexPath {
    if (indexPath.row == MPSectionTypeHeader) {
        return indexPath.section == _currSuspendHeaderSection;
    } else {
        return indexPath.section == _currSuspendFooterSection;
    }
}

- (void)_clipSectionViewsBetween:(MPIndexPathStruct)beginIndexPathStruct and:(MPIndexPathStruct)endIndexPathStruct {
    NSArray *indexPaths = _displayedSectionViewsDic.allKeys;
    
    for (MPIndexPath *indexPath in indexPaths) {
        if ([self _isSuspendingAtIndexPath:indexPath]) {
            continue;
        }

        if (_needPreparationDetected) {
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if ([self _needPrepareToSuspendViewAt:section withType:indexPath.row]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                [self _prepareToSuspendView:sectionView atSection:section withType:indexPath.row];
                continue;
            } else {
                if ([indexPath compareIndexPathAt:beginIndexPathStruct] != NSOrderedAscending && [indexPath compareIndexPathAt:endIndexPathStruct] != NSOrderedDescending) {
                    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                    CGRect frame = sectionView.frame;
                    frame.origin.y -= _contentDrawArea.beginPos;
                    if (indexPath.row == MPSectionTypeHeader) {
                        if (frame.origin.y != section.beginPos) {
                            frame.origin.y = section.beginPos + _contentDrawArea.beginPos;
                            sectionView.frame = frame;
                        }
                    } else {
                        if (frame.origin.y != section.endPos - section.footerHeight) {
                            frame.origin.y = section.endPos - section.footerHeight + _contentDrawArea.beginPos;
                            sectionView.frame = frame;
                        }
                    }
                    continue;
                }
            }
        }
        if ([indexPath compareIndexPathAt:beginIndexPathStruct] == NSOrderedAscending || [indexPath compareIndexPathAt:endIndexPathStruct] == NSOrderedDescending) {
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            [self _cacheSectionView:sectionView];
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            if (_respond_didEndDisplayingHeaderViewForSection && indexPath.row == MPSectionTypeHeader) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
            }
            if (_respond_didEndDisplayingFooterViewForSection && indexPath.row == MPSectionTypeFooter) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
            }
        }
    }
}

- (void)_adjustEstimatedSectionViewsBetween:(MPIndexPathStruct)beginIndexPathStruct and:(MPIndexPathStruct)endIndexPathStruct {
    NSArray *indexPaths = _displayedSectionViewsDic.allKeys;
    
    for (MPIndexPath *indexPath in indexPaths) {
        if (self.style == MPTableViewStylePlain) {
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if ([self _needSuspendingSection:section withType:indexPath.row]) {
                if (indexPath.row == MPSectionTypeHeader) {
                    [self _suspendingSectionHeader:[_displayedSectionViewsDic objectForKey:indexPath] inArea:section];
                } else if (indexPath.row == MPSectionTypeFooter) {
                    [self _suspendingSectionFooter:[_displayedSectionViewsDic objectForKey:indexPath] inArea:section];
                }
                
                continue;
            }
        }
        
        if (_needPreparationDetected) {
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            if ([self _needPrepareToSuspendViewAt:section withType:indexPath.row]) {
                MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
                [self _prepareToSuspendView:sectionView atSection:section withType:indexPath.row];
                continue;
            }
        }
        
        if ([indexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            [self _cacheSectionView:sectionView];
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            
            if (_respond_didEndDisplayingHeaderViewForSection && indexPath.row == MPSectionTypeHeader) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:indexPath.section];
            }
            if (_respond_didEndDisplayingFooterViewForSection && indexPath.row == MPSectionTypeFooter) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:indexPath.section];
            }
        } else {
            MPTableViewSection *section = _sectionsAreaList[indexPath.section];
            MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
            CGRect frame = sectionView.frame;
            frame.origin.y -= _contentDrawArea.beginPos;
            if (indexPath.row == MPSectionTypeHeader) {
                if (frame.origin.y != section.beginPos) {
                    frame.origin.y = section.beginPos + _contentDrawArea.beginPos;
                    sectionView.frame = frame;
                }
            } else {
                if (frame.origin.y != section.endPos - section.footerHeight) {
                    frame.origin.y = section.endPos - section.footerHeight + _contentDrawArea.beginPos;
                    sectionView.frame = frame;
                }
            }
        }
    }
}

- (void)_updateDisplayingArea {
    if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        return;
    }
    
    MPIndexPathStruct beginIndexPathStruct = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
    MPIndexPathStruct endIndexPathStruct = [self _indexPathAtContentOffset:_currDrawArea.endPos];
    
    if ([self __isEstimatedMode]) { // estimated update
        [self _lockLayoutSubviews];
        _updateDataPreparing = YES;
        
        if (!MPEqualIndexPaths(_beginIndexPath, beginIndexPathStruct) || !MPEqualIndexPaths(_endIndexPath, endIndexPathStruct)) {
            MPIndexPathStruct estimatedFirstIndexPath;
            
            if (MPCompareIndexPath(beginIndexPathStruct, _beginIndexPath) == NSOrderedAscending) {
                estimatedFirstIndexPath = beginIndexPathStruct;
                
                [self _startEstimatedUpdateAtFirstIndexPath:estimatedFirstIndexPath];
            } else if (MPCompareIndexPath(endIndexPathStruct, _endIndexPath) == NSOrderedDescending) {
                if (_endIndexPath.row == MPSectionTypeFooter) {
                    estimatedFirstIndexPath = MPIndexPathStructMake(_endIndexPath.section + 1, MPSectionTypeHeader);
                } else if (_endIndexPath.row == MPSectionTypeHeader) {
                    estimatedFirstIndexPath = MPIndexPathStructMake(_endIndexPath.section, 0);
                } else {
                    estimatedFirstIndexPath = MPIndexPathStructMake(_endIndexPath.section, _endIndexPath.row + 1);
                }
                
                [self _startEstimatedUpdateAtFirstIndexPath:estimatedFirstIndexPath];
            } else {
                [self _clipCellsBetween:beginIndexPathStruct and:endIndexPathStruct];
                [self _adjustEstimatedSectionViewsBetween:beginIndexPathStruct and:endIndexPathStruct];
                
                _beginIndexPath = beginIndexPathStruct;
                _endIndexPath = endIndexPathStruct;
            }
            
            [self _layoutUpdatedNoticeIfNeeded];
        } else if (self.style == MPTableViewStylePlain) {
            [self _adjustEstimatedSectionViewsBetween:beginIndexPathStruct and:endIndexPathStruct];
        }
        
        _updateDataPreparing = NO;
        [self _unlockLayoutSubviews];
    } else { // normal update
        [self _lockLayoutSubviews];
        _updateDataPreparing = YES;
        
        if (self.style == MPTableViewStylePlain) {
            [self _suspendSectionHeaderIfNeededAt:beginIndexPathStruct];
            [self _suspendSectionFooterIfNeededAt:endIndexPathStruct];
        }
        
        if (!MPEqualIndexPaths(_beginIndexPath, beginIndexPathStruct) || !MPEqualIndexPaths(_endIndexPath, endIndexPathStruct)) {
            [self _clipCellsBetween:beginIndexPathStruct and:endIndexPathStruct];
            [self _clipSectionViewsBetween:beginIndexPathStruct and:endIndexPathStruct];
            
            [self _updateDisplayingBegin:beginIndexPathStruct and:endIndexPathStruct isUpdating:NO];
            [self _layoutUpdatedNoticeIfNeeded];
        }
        
        _updateDataPreparing = NO;
        [self _unlockLayoutSubviews];
    }
}

- (void)_updateDisplayingBegin:(MPIndexPathStruct)beginIndexPathStruct and:(MPIndexPathStruct)endIndexPathStruct isUpdating:(BOOL)enable {
    for (NSInteger i = beginIndexPathStruct.section; i <= endIndexPathStruct.section; i++) {
        MPTableViewSection *section = _sectionsAreaList[i];
        
        NSInteger startCellIndex = 0, endCellIndex = section.numberOfRows;
        BOOL needSectionHeader = YES, needSectionFooter = YES;
        
        if (i == beginIndexPathStruct.section) {
            if (beginIndexPathStruct.row == MPSectionTypeFooter) {
                startCellIndex = NSNotFound;
                needSectionHeader = NO;
            } else {
                if (beginIndexPathStruct.section != _currSuspendHeaderSection && [self _needPrepareToSuspendViewAt:section withType:MPSectionTypeHeader]) {
                    [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeHeader isUpdating:enable];
                }
            }
            if (beginIndexPathStruct.row == MPSectionTypeHeader) {
                startCellIndex = 0;
            } else {
                startCellIndex = beginIndexPathStruct.row;
                needSectionHeader = NO;
            }
        }
        
        if (i == endIndexPathStruct.section) {
            if (endIndexPathStruct.row == MPSectionTypeHeader) {
                endCellIndex = NSNotFound;
                needSectionFooter = NO;
            } else {
                if (endIndexPathStruct.section != _currSuspendFooterSection && [self _needPrepareToSuspendViewAt:section withType:MPSectionTypeFooter]) {
                    [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeFooter isUpdating:enable];
                }
            }
            if (endIndexPathStruct.row == MPSectionTypeFooter) {
                endCellIndex = section.numberOfRows;
            } else {
                endCellIndex = endIndexPathStruct.row + 1;
                needSectionFooter = NO;
            }
        }
        
        if (needSectionHeader && section.headerHeight) {
            if ([self _needPrepareToSuspendViewAt:section withType:MPSectionTypeHeader]) {
                [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeHeader isUpdating:enable];
            } else {
                [self _displayingSectionViewAtIndexPath:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:i]];
            }
        }
        
        if (needSectionFooter && section.footerHeight) {
            if ([self _needPrepareToSuspendViewAt:section withType:MPSectionTypeFooter]) {
                [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeFooter isUpdating:enable];
            } else {
                [self _displayingSectionViewAtIndexPath:[MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:i]];
            }
        }
        
        if (startCellIndex == NSNotFound || endCellIndex == NSNotFound || section.numberOfRows == 0) {
            continue;
        }
        
        for (NSInteger j = startCellIndex; j < endCellIndex; j++) {
            MPIndexPathStruct indexPath_ = {i, j};
            if (MPCompareIndexPath(indexPath_, _beginIndexPath) == NSOrderedAscending || MPCompareIndexPath(indexPath_, _endIndexPath) == NSOrderedDescending) {
                MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:indexPath_];
                
                if (([self isUpdating] || [self __isContentMoving]) && [_displayedCellsDic objectForKey:indexPath]) {
                    continue;
                }
                
                MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                
                if ([_selectedIndexPaths containsObject:indexPath]) {
                    [cell setSelected:YES];
                }
                
                cell.frame = [self _cellFrameAtIndexPath:indexPath];
                
                if (_respond_willDisplayCellForRowAtIndexPath) {
                    [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
                }
                
                [self _addCellToWrapperViewIfNeeded:cell];
                if ([self isUpdating]) {
                    [_contentWrapperView sendSubviewToBack:cell];
                }
                
                [_displayedCellsDic setObject:cell forKey:indexPath];
            }
        }
    }
    
    _beginIndexPath = beginIndexPathStruct;
    _endIndexPath = endIndexPathStruct;
}

- (MPTableViewCell *)_getCellFromDataSourceAtIndexPath:(MPIndexPath *)indexPath {
    MPTableViewCell *cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
    if (!cell) {
        @throw @"cell must not be null";
    }
    
    return cell;
}

- (CGRect)_cellFrameAtIndexPath:(MPIndexPath *)indexPath {
    if (!indexPath) {
        return CGRectZero;
    }
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    CGFloat beginPos = [section rowPositionBeginAt:indexPath.row];
    CGFloat endPos = [section rowPositionEndAt:indexPath.row];
    
    CGRect frame;
    frame.origin.x = 0;
    frame.origin.y = beginPos;
    frame.size.height = endPos - beginPos;
    frame.size.width = self.frame.size.width;
    frame.origin.y += _contentDrawArea.beginPos;
    return frame;
}

- (MPTableReusableView *)_getSectionViewFromDelegateAtIndexPath:(MPIndexPath *)indexPath {
    MPTableReusableView *sectionView = nil;
    if (indexPath.row == MPSectionTypeHeader) {
        if (_respond_viewForHeaderInSection) {
            sectionView = [_mpDataSource MPTableView:self viewForHeaderInSection:indexPath.section];
        }
    } else {
        if (_respond_viewForFooterInSection) {
            sectionView = [_mpDataSource MPTableView:self viewForFooterInSection:indexPath.section];
        }
    }
    
    return sectionView;
}

- (CGRect)_sectionViewFrameAtIndexPath:(MPIndexPath *)indexPath {
    CGRect sectionViewFrame;
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    if (indexPath.row == MPSectionTypeHeader) {
        sectionViewFrame.origin.y = section.beginPos;
        sectionViewFrame.size.height = section.headerHeight;
    } else {
        sectionViewFrame.origin.y = section.endPos - section.footerHeight;
        sectionViewFrame.size.height = section.footerHeight;
    }
    sectionViewFrame.origin.x = 0;
    sectionViewFrame.size.width = self.frame.size.width;
    sectionViewFrame.origin.y += _contentDrawArea.beginPos;
    
    return sectionViewFrame;
}

- (void)_displayingSectionViewAtIndexPath:(MPIndexPath *)indexPath {
    MPTableReusableView *sectionView = nil;
    if (self.style == MPTableViewStylePlain || [self isUpdating]) {
        if (![_displayedSectionViewsDic objectForKey:indexPath]) {
            sectionView = [self _drawSectionViewAtIndexPath:indexPath];
        }
    } else {
        if ([indexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
            sectionView = [self _drawSectionViewAtIndexPath:indexPath];
        }
    }
}

- (MPTableReusableView *)_drawSectionViewAtIndexPath:(MPIndexPath *)indexPath {
    MPTableReusableView *sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
        sectionView.frame = frame;
        
        if (indexPath.row == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSectionViewToWrapperViewIfNeeded:sectionView];
        [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    }
    return sectionView;
}

- (BOOL)_needPrepareToSuspendViewAt:(MPTableViewSection *)section withType:(MPSectionType)type {
    if (!_needPreparationDetected) {
        return NO;
    }
    
    if (type == MPSectionTypeHeader) {
        CGFloat contentBegin = _currDrawArea.beginPos + self.contentInset.top;
        if (section.headerHeight && self.contentInset.top != 0 && section.endPos <= contentBegin && section.endPos - section.footerHeight >= _currDrawArea.beginPos) {
            return YES;
        } else {
            return NO;
        }
    } else {
        CGFloat contentEnd = _currDrawArea.endPos - self.contentInset.bottom;
        if (section.footerHeight && self.contentInset.bottom != 0 && section.beginPos >= contentEnd && section.beginPos + section.headerHeight <= _currDrawArea.endPos) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (void)_prepareToSuspendView:(MPTableReusableView *)sectionView atSection:(MPTableViewSection *)section withType:(MPSectionType)type {
    CGRect frame = CGRectZero;
    frame.size.width = self.frame.size.width;
    if (type == MPSectionTypeHeader) {
        frame.origin.y = section.endPos - section.footerHeight - section.headerHeight + _contentDrawArea.beginPos;
        frame.size.height = section.headerHeight;
    } else {
        frame.origin.y = section.beginPos + section.headerHeight + _contentDrawArea.beginPos;
        frame.size.height = section.footerHeight;
    }
    
    sectionView.frame = frame;
}

- (CGRect)_prepareToSuspendViewFrameAt:(MPTableViewSection *)section withType:(MPSectionType)type {
    if (type == MPSectionTypeHeader) {
        return CGRectMake(0, section.endPos - section.footerHeight - section.headerHeight + _contentDrawArea.beginPos, self.frame.size.width, section.headerHeight);
    } else {
        return CGRectMake(0, section.beginPos + section.headerHeight + _contentDrawArea.beginPos, self.frame.size.width, section.footerHeight);
    }
}

- (void)_makePrepareToSuspendViewInSection:(MPTableViewSection *)section withType:(MPSectionType)type isUpdating:(BOOL)updating {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:section.section];
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    
    if (!sectionView) {
        sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
    } else {
        if (updating) {
            return;
        }
    }
    
    if (sectionView) {
        sectionView.frame = [self _prepareToSuspendViewFrameAt:section withType:type];
        
        if (type == MPSectionTypeHeader) {
            if (_respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        } else {
            if (_respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
        
        [self _addSectionViewToWrapperViewIfNeeded:sectionView];
        [_displayedSectionViewsDic setObject:sectionView forKey:indexPath];
    }
}

- (void)_suspendSectionHeaderIfNeededAt:(MPIndexPathStruct) beginIndexPath {
    MPTableViewSection *section;
    if (self.contentInset.top != 0) {
        CGFloat target = _currDrawArea.beginPos + self.contentInset.top;
        if (target > _contentDrawArea.endPos - _contentDrawArea.beginPos) {
            target = _contentDrawArea.endPos - _contentDrawArea.beginPos;
        }
        if (target < 0) {
            target = 0;
        }
        section = _sectionsAreaList[[self _sectionIndexAtContentOffset:target]];
    } else {
        section = _sectionsAreaList[beginIndexPath.section];
    }
    if (section.headerHeight) {
        BOOL isResetPreSuspend;
        if (self.contentInset.top != 0) {
            isResetPreSuspend = YES;
        } else {
            isResetPreSuspend = beginIndexPath.row != MPSectionTypeFooter;
        }
        if (_currSuspendHeaderSection != section.section && isResetPreSuspend) {
            beginIndexPath.row = MPSectionTypeHeader;
            MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:_currSuspendHeaderSection];
            _currSuspendHeaderSection = section.section;
            UIView *lastSuspendHeader = [_displayedSectionViewsDic objectForKey:indexPath];
            if (lastSuspendHeader) {
                MPTableViewSection *lastSection = _sectionsAreaList[indexPath.section];
                CGRect frame = lastSuspendHeader.frame;
                if ([self _needPrepareToSuspendViewAt:lastSection withType:MPSectionTypeHeader]) { // prepare suspending
                    frame.origin.y = lastSection.endPos - lastSection.footerHeight - lastSection.headerHeight;
                } else {
                    frame.origin.y = lastSection.beginPos;
                }
                frame.origin.y += _contentDrawArea.beginPos;
                lastSuspendHeader.frame = frame;
            }
        } else if (_currSuspendHeaderSection != NSNotFound) {
            section = _sectionsAreaList[_currSuspendHeaderSection];
        } else {
            return;
        }
        
        if (section.endPos - section.footerHeight < _currDrawArea.beginPos) {
            return;
        }
        
        MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:_currSuspendHeaderSection];
        UIView *suspendHeader = [_displayedSectionViewsDic objectForKey:indexPath];
        if (!suspendHeader) {
            suspendHeader = [self _drawSectionViewAtIndexPath:indexPath];
        }
        
        [self _suspendingSectionHeader:suspendHeader inArea:section];
    }
}

- (void)_suspendingSectionHeader:(UIView *)suspendHeader inArea:(MPTableViewSection *)section {
    if (suspendHeader) {
        CGRect frame = CGRectZero;
        frame.size.width = self.frame.size.width;
        frame.size.height = section.headerHeight;
        
        frame.origin.y = _currDrawArea.beginPos + self.contentInset.top;
        if (CGRectGetMaxY(frame) > section.endPos - section.footerHeight) {
            if (frame.origin.y != section.endPos - section.footerHeight - frame.size.height) {
                frame.origin.y = section.endPos - section.footerHeight - frame.size.height;
            }
        }
        if (frame.origin.y < section.beginPos) {
            if (frame.origin.y != section.beginPos) {
                frame.origin.y = section.beginPos;
            }
        }
        
        frame.origin.y += _contentDrawArea.beginPos;
        suspendHeader.frame = frame;
    }
}

- (void)_suspendSectionFooterIfNeededAt:(MPIndexPathStruct)endIndexPath {
    MPTableViewSection *section = _sectionsAreaList[endIndexPath.section];
    if (self.contentInset.bottom != 0) {
        CGFloat target = _currDrawArea.endPos - self.contentInset.bottom;
        if (target > _contentDrawArea.endPos - _contentDrawArea.beginPos) {
            target = _contentDrawArea.endPos - _contentDrawArea.beginPos;
        }
        section = _sectionsAreaList[[self _sectionIndexAtContentOffset:target]];
    } else {
        section = _sectionsAreaList[endIndexPath.section];
    }
    if (section.footerHeight) {
        BOOL isResetPreSuspend;
        if (self.contentInset.bottom != 0) {
            isResetPreSuspend = YES;
        } else {
            isResetPreSuspend = endIndexPath.row != MPSectionTypeHeader;
        }
        if (_currSuspendFooterSection != section.section && isResetPreSuspend) {
            endIndexPath.row = MPSectionTypeFooter;
            MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:_currSuspendFooterSection];
            _currSuspendFooterSection = section.section;
            UIView *lastSuspendFooter = [_displayedSectionViewsDic objectForKey:indexPath];
            if (lastSuspendFooter) {
                MPTableViewSection *lastSection = _sectionsAreaList[indexPath.section];
                CGRect frame = lastSuspendFooter.frame;
                if ([self _needPrepareToSuspendViewAt:lastSection withType:MPSectionTypeFooter]) {
                    frame.origin.y = lastSection.beginPos + lastSection.headerHeight;
                } else {
                    frame.origin.y = lastSection.endPos - lastSection.footerHeight;
                }
                frame.origin.y += _contentDrawArea.beginPos;
                lastSuspendFooter.frame = frame;
            }
        } else if (_currSuspendFooterSection != NSNotFound) {
            section = _sectionsAreaList[_currSuspendFooterSection];
        } else {
            return;
        }
        if (section.beginPos + section.headerHeight > _currDrawArea.endPos) {
            return;
        }
        
        MPIndexPath *indexPath = [MPIndexPath indexPathForRow:MPSectionTypeFooter inSection:_currSuspendFooterSection];
        UIView *suspendFooter = [_displayedSectionViewsDic objectForKey:indexPath];
        if (!suspendFooter) {
            suspendFooter = [self _drawSectionViewAtIndexPath:indexPath];
        }
        
        [self _suspendingSectionFooter:suspendFooter inArea:section];
    }
}

- (void)_suspendingSectionFooter:(UIView *)suspendFooter inArea:(MPTableViewSection *)section {
    if (suspendFooter) {
        CGRect frame = CGRectZero;
        frame.size.width = self.frame.size.width;
        frame.size.height = section.footerHeight;
        
        frame.origin.y = _currDrawArea.endPos - frame.size.height - self.contentInset.bottom;
        if (frame.origin.y < section.beginPos + section.headerHeight) {
            if (frame.origin.y != section.beginPos + section.headerHeight) {
                frame.origin.y = section.beginPos + section.headerHeight;
            }
        }
        if (CGRectGetMaxY(frame) > section.endPos) {
            if (frame.origin.y != section.endPos - section.footerHeight) {
                frame.origin.y = section.endPos - section.footerHeight;
            }
        }
        
        frame.origin.y += _contentDrawArea.beginPos;
        suspendFooter.frame = frame;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (![self _isLayoutSubviewsLock]) {
        [self _getDisplayingArea];
        [self _updateDisplayingArea];
    }
    
    [self _prefetchDataIfNeeded];
}

#pragma mark -prefetch

- (void)_prefetchDataIfNeeded {
    if (!_prefetchDataSource || !_numberOfSections) {
        return;
    }
    
    MPTableViewScrollDirection scrollDirection;
    MPIndexPath *beginIndexPath = [self beginIndexPath];
    MPIndexPath *endIndexPath = [self endIndexPath];
    
    if (_contentOffset.beginPos < _previousContentOffset) {
        scrollDirection = MPTableViewScrollDirectionUp;
    } else {
        scrollDirection = MPTableViewScrollDirectionDown;
    }
    
    @autoreleasepool {
        NSMutableArray *prefetchUpIndexPaths = [NSMutableArray array];
        NSMutableArray *prefetchDownIndexPaths = [NSMutableArray array];
        
        MPIndexPath *prefetchBeginIndexPath = [beginIndexPath copy];
        for (NSInteger i = 0; i < 15; i++) {
            if (prefetchBeginIndexPath.row > 0) {
                --prefetchBeginIndexPath.row;
            } else {
                while (prefetchBeginIndexPath.section > 0) {
                    MPTableViewSection *section = _sectionsAreaList[--prefetchBeginIndexPath.section];
                    if (section.numberOfRows > 0) {
                        prefetchBeginIndexPath.row = section.numberOfRows - 1;
                        goto ADD_UP_INDEXPATH;
                    }
                }
                break;
            }
            
        ADD_UP_INDEXPATH:
            if (i < 10 && scrollDirection != MPTableViewScrollDirectionDown) {
                MPIndexPath *indexPath = [prefetchBeginIndexPath copy];
                if (![_prefetchIndexPaths containsObject:indexPath]) {
                    [prefetchUpIndexPaths addObject:indexPath];
                }
            }
        }
        
        MPIndexPath *prefetchEndIndexPath = [endIndexPath copy];
        for (NSInteger i = 0; i < 15; i++) {
            MPTableViewSection *section = _sectionsAreaList[prefetchEndIndexPath.section];
            if (prefetchEndIndexPath.row + 1 < section.numberOfRows) {
                ++prefetchEndIndexPath.row;
            } else {
                while (prefetchEndIndexPath.section + 1 < _numberOfSections) {
                    section = _sectionsAreaList[++prefetchEndIndexPath.section];
                    if (section.numberOfRows > 0) {
                        prefetchEndIndexPath.row = 0;
                        goto ADD_DOWN_INDEXPATH;
                    }
                }
                break;
            }
            
        ADD_DOWN_INDEXPATH:
            if (i < 10 && scrollDirection != MPTableViewScrollDirectionUp) {
                MPIndexPath *indexPath = [prefetchEndIndexPath copy];
                if (![_prefetchIndexPaths containsObject:indexPath]) {
                    [prefetchDownIndexPaths addObject:indexPath];
                }
            }
        }
        
        if (prefetchUpIndexPaths.count || prefetchDownIndexPaths.count) {
            
            [prefetchUpIndexPaths addObjectsFromArray:prefetchDownIndexPaths];
            [_prefetchIndexPaths addObjectsFromArray:prefetchUpIndexPaths];
            
            [_prefetchDataSource MPTableView:self prefetchRowsAtIndexPaths:prefetchUpIndexPaths];
        }
        
        NSMutableArray *discardIndexPaths = [NSMutableArray array];
        NSMutableArray *cancelPrefetchIndexPaths = [NSMutableArray array];
        for (MPIndexPath *indexPath in _prefetchIndexPaths) {
            if ([indexPath compareRowSection:beginIndexPath] != NSOrderedAscending && [indexPath compareRowSection:endIndexPath] != NSOrderedDescending) {
                [discardIndexPaths addObject:indexPath];
            } else if ([indexPath compareRowSection:prefetchBeginIndexPath] == NSOrderedAscending || [indexPath compareRowSection:prefetchEndIndexPath] == NSOrderedDescending) {
                [cancelPrefetchIndexPaths addObject:indexPath];
            }
        }
        
        [_prefetchIndexPaths removeObjectsInArray:discardIndexPaths];
        [_prefetchIndexPaths removeObjectsInArray:cancelPrefetchIndexPaths];
        
        if (_respond_cancelPrefetchingForRowsAtIndexPaths && cancelPrefetchIndexPaths.count) {
            [_prefetchDataSource MPTableView:self cancelPrefetchingForRowsAtIndexPaths:cancelPrefetchIndexPaths];
        }
    }
    
    _previousContentOffset = _contentOffset.beginPos;
    _previousScrollDirection = scrollDirection;
}

- (void)_layoutUpdatedNoticeIfNeeded {
    if (!_prefetchDataSource || !_numberOfSections) {
        return;
    }
    
    MPTableViewScrollDirection scrollDirection;
    
    if (_contentOffset.beginPos < _previousContentOffset) {
        scrollDirection = MPTableViewScrollDirectionUp;
    } else {
        scrollDirection = MPTableViewScrollDirectionDown;
    }
    
    if (_respond_didScrollAndLayoutUpdatedWithDirectionWithPreviousDirection) {
        [_prefetchDataSource MPTableView:self didScrollAndLayoutUpdatedWithDirection:scrollDirection withPreviousDirection:_previousScrollDirection];
    }
}

#pragma mark -select & move

NS_INLINE CGPoint MPPointsSubtraction(CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x - point2.x, point1.y - point2.y);
}

//NS_INLINE CGPoint MPPointsAddition(CGPoint point1, CGPoint point2) {
//    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
//}

- (void)setMoveModeEnabled:(BOOL)moveModeEnabled {
    if (_moveModeEnabled && !moveModeEnabled) {
        [self _endMovingCellIfNeeded];
    }
    _moveModeEnabled = moveModeEnabled;
}

- (BOOL)isMoveModeEnabled {
    return _moveModeEnabled;
}

- (MPIndexPath *)movingIndexPath {
    return [_movingIndexPath copy];;
}

- (BOOL)__isContentMoving {
    return _movingIndexPath ? YES : NO;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    if (_movingIndexPath && scrollEnabled) { //
        scrollEnabled = NO;
    }
    [super setScrollEnabled:scrollEnabled];
}

- (MPIndexPath *)_beginMovingCellOnTouch:(UITouch *)touch {
    [self _endMovingCellIfNeeded];
    
    CGPoint touchPoint = [touch locationInView:self];
    CGFloat touchPosition = touchPoint.y;
    if (touchPosition >= _contentDrawArea.beginPos && touchPosition <= _contentDrawArea.endPos) {
        
        MPIndexPath *touchedIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:touchPosition - _contentDrawArea.beginPos]];
        if (touchedIndexPath.row == MPSectionTypeHeader || touchedIndexPath.row == MPSectionTypeFooter) {
            return nil;
        }
        
        if (_respond_canMoveRowAtIndexPath && ![_mpDataSource MPTableView:self canMoveRowAtIndexPath:touchedIndexPath]) {
            return nil;
        }
        
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:touchedIndexPath];
        if (_respond_rectForCellToMoveRowAtIndexPath) {
            CGRect touchEnabledFrame = [_mpDataSource MPTableView:self rectForCellToMoveRowAtIndexPath:touchedIndexPath];
            if (!CGRectContainsPoint(touchEnabledFrame, [cell convertPoint:touchPoint fromView:_contentWrapperView])) {
                return _allowsSelectionDuringMoving ? touchedIndexPath : nil;
            }
        }
        
        _movingDraggedCell = cell;
        _sourceIndexPath = _movingIndexPath = touchedIndexPath;
        _movingMinuendPoint = MPPointsSubtraction(touchPoint, _movingDraggedCell.center);
        
        if (_respond_shouldMoveRowAtIndexPath) {
            [_mpDelegate MPTableView:self shouldMoveRowAtIndexPath:touchedIndexPath];
        }
        
        [_contentWrapperView bringSubviewToFront:_movingDraggedCell];
        _scrollEnabledRecord = [super isScrollEnabled];
        self.scrollEnabled = NO;
        _movingScrollDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_boundsScrollingAction)];
        [_movingScrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [self _boundsScrollingIfNeeded];
        
        return nil;
    } else {
        return nil;
    }
}

- (void)_movingCellOnTouch:(UITouch *)touch {
    CGPoint touchPoint = [touch locationInView:self];
    
    [self _movingCellSetCenter:MPPointsSubtraction(touchPoint, _movingMinuendPoint)];
    
    [self _boundsScrollingIfNeeded];
    
    touchPoint = _movingDraggedCell.center;
    [self _movingCellToUpdateInPosition:touchPoint.y];
}

- (void)_movingCellSetCenter:(CGPoint)center {
    if (!_allowDragOutBounds) {
        center.x = self.frame.size.width / 2;
        if (center.y < _contentDrawArea.beginPos) {
            center.y = _contentDrawArea.beginPos;
        }
        if (center.y > _contentDrawArea.endPos) {
            center.y = _contentDrawArea.endPos;
        }
    }
    
    _movingDraggedCell.center = center;
}

- (void)_boundsScrollingAction {
    CGPoint newPoint = self.contentOffset;
    newPoint.y += _movingScrollFate;
    
    if (_movingScrollFate < 0) {
        if (newPoint.y < -self.contentInset.top) {
            newPoint.y = -self.contentInset.top;
            _movingScrollDisplayLink.paused = YES;
        }
    } else if (_movingScrollFate > 0) {
        if (newPoint.y + self.frame.size.height > self.contentSize.height + self.contentInset.bottom) {
            newPoint.y = self.contentSize.height + self.contentInset.bottom - self.frame.size.height;
            _movingScrollDisplayLink.paused = YES;
        }
    }
    
    self.contentOffset = newPoint;
    
    newPoint.x = _movingDraggedCell.center.x;
    newPoint.y -= _movingDistanceToOffset;
    [self _movingCellSetCenter:newPoint];
    
    [self _getDisplayingArea];
    [self _updateDisplayingArea];
    
    [self _movingCellToUpdateInPosition:newPoint.y];
}

- (void)_boundsScrollingIfNeeded {
    _movingScrollFate = 0;
    if (_movingDraggedCell.frame.origin.y < _contentOffset.beginPos + self.contentInset.top) {
        if (_contentOffset.beginPos > -self.contentInset.top) {
            _movingScrollFate = _movingDraggedCell.frame.origin.y - _contentOffset.beginPos - self.contentInset.top;
        }
    } else if (CGRectGetMaxY(_movingDraggedCell.frame) > _contentOffset.endPos - self.contentInset.bottom) {
        if (_contentOffset.endPos < self.contentSize.height + self.contentInset.bottom) {
            _movingScrollFate = CGRectGetMaxY(_movingDraggedCell.frame) - _contentOffset.endPos + self.contentInset.bottom;
        }
    }
    
    _movingDistanceToOffset = _contentOffset.beginPos - _movingDraggedCell.center.y;
    _movingScrollDisplayLink.paused = !_movingScrollFate;
}

- (void)_movingCellToUpdateInPosition:(CGFloat)position {
    if (position >= _contentDrawArea.beginPos && position <= _contentDrawArea.endPos) {
        if (position < _contentOffset.beginPos) {
            position = _contentOffset.beginPos;
        } else if (position > _contentOffset.endPos) {
            position = _contentOffset.endPos;
        }
        
        MPIndexPathStruct newIndexPath_ = [self _indexPathAtContentOffset:position - _contentDrawArea.beginPos];
        if (newIndexPath_.row == MPSectionTypeHeader) {
            newIndexPath_.row = 0;
        } else if (newIndexPath_.row == MPSectionTypeFooter) {
            if (newIndexPath_.section == _movingIndexPath.section) {
                return;
            }
            newIndexPath_.row = [self numberOfRowsInSection:newIndexPath_.section];
        } else {
            MPTableViewSection *section = _sectionsAreaList[newIndexPath_.section];
            CGFloat beginPos = [section rowPositionBeginAt:newIndexPath_.row];
            CGFloat endPos = [section rowPositionEndAt:newIndexPath_.row];
            CGFloat targetCenter = beginPos + (endPos - beginPos) / 2 + _contentDrawArea.beginPos;
            
            if (targetCenter < _movingDraggedCell.frame.origin.y || targetCenter > CGRectGetMaxY(_movingDraggedCell.frame)) { // must move across target's center.y
                return;
            }
        }
        
        if ([_movingIndexPath compareIndexPathAt:newIndexPath_] == NSOrderedSame) {
            return;
        }
        
        MPIndexPath *newIndexPath = [MPIndexPath indexPathFromStruct:newIndexPath_];
        
        if (_respond_canMoveRowToIndexPath && ![_mpDataSource MPTableView:self canMoveRowToIndexPath:newIndexPath]) {
            return;
        }
        
        _updateManager.moveFromSection = _movingIndexPath.section;
        _updateManager.moveToSection = newIndexPath.section;
        
        [_updateManager addMoveOutIndexPath:_movingIndexPath];
        
        [_updateManager addMoveInIndexPath:newIndexPath withFrame:[self _cellFrameAtIndexPath:_movingIndexPath] withOriginIndexPath:_movingIndexPath];
        
        _movingIndexPath = newIndexPath;
        
        [self _startUpdateAnimation];
    }
}

- (void)_endMovingCellIfNeeded {
    if (!_movingIndexPath) {
        return;
    }
    
    [UIView animateWithDuration:MPTableViewDefaultAnimationDuration animations:^{
        _movingDraggedCell.frame = [self _cellFrameAtIndexPath:_movingIndexPath];
    }];
    
    if (_respond_moveRowAtIndexPathToIndexPath) {
        [_mpDataSource MPTableView:self moveRowAtIndexPath:[_sourceIndexPath copy] toIndexPath:[_movingIndexPath copy]];
    }
    
    _sourceIndexPath = _movingIndexPath = nil;
    _movingDraggedCell = nil;
    self.scrollEnabled = _scrollEnabledRecord;
    
    [_movingScrollDisplayLink invalidate];
    _movingScrollDisplayLink = nil;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    MPIndexPath *touchedIndexPath = nil;
    
    if ([self isMoveModeEnabled] && ![self isUpdating]) {
        touchedIndexPath = [self _beginMovingCellOnTouch:touches.anyObject];
        if (!touchedIndexPath) {
            return;
        }
        self.scrollEnabled = _scrollEnabledRecord;
    }
    
    // row selected
    if ([self isDecelerating] || [self isDragging] || _contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        return;
    }
    
    UITouch *touch = touches.anyObject;
    CGFloat touchPosition = [touch locationInView:self].y;
    if (_allowsSelection && touchPosition >= _contentDrawArea.beginPos && touchPosition <= _contentDrawArea.endPos) {
        
        if (!touchedIndexPath) {
            touchedIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:touchPosition - _contentDrawArea.beginPos]];
        }
        
        if (touchedIndexPath.row == MPSectionTypeHeader || touchedIndexPath.row == MPSectionTypeFooter) {
            return;
        }
        
        if (_respond_shouldHighlightRowAtIndexPath && ![_mpDelegate MPTableView:self shouldHighlightRowAtIndexPath:touchedIndexPath]) {
            return;
        }
        
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath = touchedIndexPath];
        
        if (!cell) {
            return;
        }
        
        if (![cell isHighlighted]) {
            [cell setHighlighted:YES];
        }
        
        if (_respond_didHighlightRowAtIndexPath) {
            [_mpDelegate MPTableView:self didHighlightRowAtIndexPath:touchedIndexPath];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    if (_movingIndexPath) {
        return [self _movingCellOnTouch:touches.anyObject];
    }
    
    if (_highlightedIndexPath) {
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
        
        if ([cell isHighlighted]) {
            [cell setHighlighted:NO];
        }
        
        if (_respond_didUnhighlightRowAtIndexPath) {
            [_mpDelegate MPTableView:self didUnhighlightRowAtIndexPath:[_highlightedIndexPath copy]];
        }
        
        _highlightedIndexPath = nil;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    if (_movingIndexPath) {
        return [self _endMovingCellIfNeeded];
    }
    
    if (_highlightedIndexPath && _allowsSelection) {
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
        if (!cell) {
            return;
        }
        MPTableViewCell *highlightedCell = cell;

        if (_respond_willSelectCellAtIndexPath) {
            MPIndexPath *indexPath = [_mpDelegate MPTableView:self willSelectCell:cell atIndexPath:[_highlightedIndexPath copy]];
            if (!indexPath) {
                goto UNHIGHLIGHT;
            }
            
            if (![_highlightedIndexPath isEqual:indexPath]) {
                cell = [_displayedCellsDic objectForKey:_highlightedIndexPath = [indexPath copy]];
            }
        }
        
        if (_allowsMultipleSelection && [_selectedIndexPaths containsObject:_highlightedIndexPath]) {
            [self _deselectRowAtIndexPath:_highlightedIndexPath animated:NO selectedIndexPathRemove:YES];
        } else {
            if (!_allowsMultipleSelection && ![_selectedIndexPaths containsObject:_highlightedIndexPath]) {
                [self _deselectRowAtIndexPath:_selectedIndexPaths.anyObject animated:NO selectedIndexPathRemove:YES];
            }
            
            [_selectedIndexPaths addObject:_highlightedIndexPath];
            
            [cell setSelected:YES];
            
            if (_respond_didSelectCellAtIndexPath) {
                [_mpDelegate MPTableView:self didSelectCell:cell atIndexPath:[_highlightedIndexPath copy]];
            }
        }
        
    UNHIGHLIGHT:
        if ([highlightedCell isHighlighted]) {
            [highlightedCell setHighlighted:NO];
        }
        
        if (_respond_didUnhighlightRowAtIndexPath) {
            [_mpDelegate MPTableView:self didUnhighlightRowAtIndexPath:[_highlightedIndexPath copy]];
        }
        
        _highlightedIndexPath = nil;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    
    if (_movingIndexPath) {
        return [self _endMovingCellIfNeeded];
    }
    
    if (_highlightedIndexPath) {
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath];
        if ([cell isHighlighted]) {
            [cell setHighlighted:NO];
        }
        
        if (_respond_didUnhighlightRowAtIndexPath) {
            [_mpDelegate MPTableView:self didUnhighlightRowAtIndexPath:[_highlightedIndexPath copy]];
        }
        
        _highlightedIndexPath = nil;
    }
}

@end
