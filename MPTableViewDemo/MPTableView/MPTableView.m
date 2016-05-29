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

typedef struct struct_MPIndexPath {
    NSInteger section, row;
} MPIndexPathStruct;

static MPIndexPathStruct
indexPathStruct(NSInteger section, NSInteger row) {
    MPIndexPathStruct result;
    result.section = section;
    result.row = row;
    return result;
}

NS_INLINE BOOL
MPEqualIndexPaths(MPIndexPathStruct indexPath1, MPIndexPathStruct indexPath2) {
    return indexPath1.section == indexPath2.section && indexPath2.row == indexPath1.row;
}

static NSComparisonResult
MPCompareIndexPath(MPIndexPathStruct first, MPIndexPathStruct second) {
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

+ (MPIndexPath *)indexPathFromStruct:(MPIndexPathStruct)indexPath {
    return [MPIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
}

- (NSComparisonResult)compare:(MPIndexPath *)indexPath {
    NSParameterAssert(self && indexPath);
    return MPCompareIndexPath([self structIndexPath], [indexPath structIndexPath]);
}

@end

#pragma mark -
@interface MPTableReusableView (MPTableReusableView_internal)

@property (nonatomic, copy, readwrite) NSString *identifier;

@end

#pragma mark -

static MPTableViewRowAnimation
MPTableViewGetRandomRowAnimation() {
    unsigned int random = arc4random() % 7;
    return (MPTableViewRowAnimation)random;
}

static CGRect
MPTableViewDisappearViewFrameWithRowAnimation(UIView *view, MPTableViewRowAnimation animation, MPTableViewPosition *sectionPosition, CGFloat contentBeginPos) {
    CGRect frame = view.frame;
    switch (animation) {
        case MPTableViewRowAnimationFade: {
            if (view.opaque == NO) {
                view.hidden = YES;
                return frame;
            }
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin.x = frame.size.width;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin.x = -frame.size.width;
        }
            break;
        case MPTableViewRowAnimationTop: {
            if (sectionPosition) {
                frame.origin.y = sectionPosition.beginPos + contentBeginPos;
            } else {
                frame.origin.y += frame.size.height;
            }
            frame.size.height = 0;
        }
            break;
        case MPTableViewRowAnimationBottom: {
            if (sectionPosition) {
                frame.origin.y = sectionPosition.endPos + contentBeginPos;
            }
            frame.size.height = 0;
        }
            break;
        case MPTableViewRowAnimationMiddle: {
            if (sectionPosition) {
                frame.origin.y = sectionPosition.beginPos + (sectionPosition.endPos - sectionPosition.beginPos) / 2 + contentBeginPos;
            } else {
                frame.origin.y += frame.size.height / 2;
            }
            frame.size.height = 0;
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
    view.alpha = 0;
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
            }
        }
            break;
        case MPTableViewRowAnimationRight: {
            frame.origin.x = 0;
        }
            break;
        case MPTableViewRowAnimationLeft: {
            frame.origin.x = 0;
        }
            break;
        case MPTableViewRowAnimationTop: {
            if (sectionPosition) {
                frame.origin.y = originFrame.origin.y;
            } else {
                frame.origin.y -= originFrame.size.height;
            }
            frame.size.height = originFrame.size.height;
        }
            break;
        case MPTableViewRowAnimationBottom: {
            if (sectionPosition) {
                frame.origin.y = originFrame.origin.y;
            }
            frame.size.height = originFrame.size.height;
        }
            break;
        case MPTableViewRowAnimationMiddle: {
            if (sectionPosition) {
                frame.origin.y = originFrame.origin.y;
            } else {
                frame.origin.y -= originFrame.size.height / 2;
            }
            frame.size.height = originFrame.size.height;
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
    view.alpha = 1;
    view.frame = frame;
}

NSString *const MPTableViewSelectionDidChangeNotification = @"MPTableViewSelectionDidChangeNotification";

const CGFloat MPTableViewRowAnimationDuration = 0.3; // Unless it's necessary, don't change the value.

#define _ReloadDataAsync_Exception_Value -7883507
#define _ReloadDataAsync_Exception_ if (!_mpDataSource) { \
    return _ReloadDataAsync_Exception_Value; \
}

@interface MPTableView ()<MPTableViewUpdateDelegate>

@end

@implementation MPTableView {
    UIView *_contentWrapperView;
    MPTableViewPosition *_contentDrawArea; //
    MPTableViewPosition *_currDrawArea; //
    
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
    MPTableViewUpdateManager *_updateManager;
    
    NSMutableDictionary *_insertCellsDic;
    NSMutableDictionary *_insertSectionViewsDic;
    NSInteger _lastSuspendHeaderSection, _lastSuspendFooterSection;
    
    NSMutableArray *_deleteViewsList;
    
    NSMutableArray *_updateAnimationBlocks;
    NSMutableSet *_updateExchangedSelectedIndexPaths;
    //
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
    
    _respond_willInsertCellForRowAtIndexPath,
    _respond_willDeleteCellForRowAtIndexPath,
    _respond_willInsertHeaderViewForSection,
    _respond_willInsertFooterViewForSection,
    _respond_willDeleteHeaderViewForSection,
    _respond_willDeleteFooterViewForSection;
    
    BOOL
    _respond_heightForIndexPath,
    
    _respond_numberOfSectionsInMPTableView,
    
    _respond_heightForHeaderInSection,
    _respond_heightForFooterInSection,
    _respond_viewForHeaderInSection,
    _respond_viewForFooterInSection;
}
@dynamic delegate, dataSource;

#define MPTableViewContentBegin (_currDrawArea.beginPos + _contentDrawArea.beginPos)
#define MPTableViewContentEnd (_currDrawArea.endPos + _contentDrawArea.beginPos)

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
        _style = MPTableViewStylePlain;
        _registerCellsNibDic = [aDecoder decodeObjectForKey:@"_registerCellsNibDic"];
        _registerReusableViewsNibDic = [aDecoder decodeObjectForKey:@"_registerReusableViewsNibDic"];
        [self _initializeData];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    _enableCachesReload = NO;
    [self _clear];
    [_sectionsAreaList removeAllObjects];
    
    [_tableHeaderView removeFromSuperview];
    [_tableFooterView removeFromSuperview];
    [_contentWrapperView removeFromSuperview];
    [_backgroundView removeFromSuperview];
    [super setContentSize:CGSizeZero];
    
    [aCoder encodeObject:_registerCellsNibDic forKey:@"_registerCellsNibDic"];
    [aCoder encodeObject:_registerReusableViewsNibDic forKey:@"_registerReusableViewsNibDic"];
    
    [super encodeWithCoder:aCoder];
}

- (void)_initializeData {
    self.alwaysBounceVertical = YES;
    self.showsHorizontalScrollIndicator = NO;
    self.backgroundColor = [UIColor whiteColor];
    
    [self _lockLayoutSubviews];
    [self addSubview:_contentWrapperView = [UIView new]];
    [self sendSubviewToBack:_contentWrapperView];
    _contentWrapperView.autoresizesSubviews = NO; // @optional
    
    _numberOfSections = 1;
    
    _rowHeight = MPTableViewDefaultCellHeight;
    _sectionHeaderHeight = 35.;
    _sectionFooterHeight = 35.;
    
    _allowsSelection = YES;
    
    [self _resetContentIndexPaths];
    _contentDrawArea = [MPTableViewPosition positionWithBegin:0 toEnd:0];
    _currDrawArea = [MPTableViewPosition positionWithBegin:0 toEnd:0];
    
    _enableCachesReload = NO;
    
    _reusableCellsDic = [NSMutableDictionary dictionary];
    _reusableReusableViewsDic = [NSMutableDictionary dictionary];
    _displayedCellsDic = [NSMutableDictionary dictionary];
    _displayedSectionViewsDic = [NSMutableDictionary dictionary];
    
    _sectionsAreaList = [NSMutableArray array];
    
    _selectedIndexPaths = [NSMutableSet set];
    
    _updateManager = [MPTableViewUpdateManager managerWithDelegate:self andSections:_sectionsAreaList];
    
    _deleteViewsList = [NSMutableArray array];
    _insertCellsDic = [NSMutableDictionary dictionary];
    _insertSectionViewsDic = [NSMutableDictionary dictionary];
    _updateAnimationBlocks = [NSMutableArray array];
    _updateExchangedSelectedIndexPaths = [NSMutableSet set];
}

- (void)dealloc {
    _enableCachesReload = NO;
    [self _clear];
    [_sectionsAreaList removeAllObjects];
}

#pragma mark -
- (void)_respondsToDataSource {
    _respond_heightForIndexPath = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForIndexPath:)];
    
    _respond_numberOfSectionsInMPTableView = [_mpDataSource respondsToSelector:@selector(numberOfSectionsInMPTableView:)];
    if (!_respond_numberOfSectionsInMPTableView) {
        _numberOfSections = 1;
    }
    
    _respond_heightForHeaderInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForHeaderInSection:)];
    _respond_heightForFooterInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:heightForFooterInSection:)];
    _respond_viewForHeaderInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:viewForHeaderInSection:)];
    _respond_viewForFooterInSection = [_mpDataSource respondsToSelector:@selector(MPTableView:viewForFooterInSection:)];
    if (_respond_heightForHeaderInSection) {
        _sectionHeaderHeight = 0;
    }
    if (_respond_heightForFooterInSection) {
        _sectionFooterHeight = 0;
    }
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
    
    _respond_willInsertCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willInsertCell:forRowAtIndexPath:)];
    _respond_willDeleteCellForRowAtIndexPath = [_mpDelegate respondsToSelector:@selector(MPTableView:willDeleteCell:forRowAtIndexPath:)];
    _respond_willInsertHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:willInsertHeaderView:forSection:)];
    _respond_willInsertFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:willInsertFooterView:forSection:)];
    _respond_willDeleteHeaderViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:willDeleteHeaderView:forSection:)];
    _respond_willDeleteFooterViewForSection = [_mpDelegate respondsToSelector:@selector(MPTableView:willDeleteFooterView:forSection:)];
}

#pragma mark -public-
- (NSUInteger)numberOfRowsInSection:(NSInteger)sectionIndex {
    if (sectionIndex >= _numberOfSections) {
        return NSNotFound;
    } else {
        MPTableViewSection *section = _sectionsAreaList[sectionIndex];
        return section.numberOfRows;
    }
}

- (void)setDelegate:(id<MPTableViewDelegate>)delegate {
    _mpDelegate = delegate;
    [super setDelegate:delegate];
    [self _respondsToDelegate];
}

- (id<MPTableViewDelegate>)delegate {
    return _mpDelegate;
}

- (void)setDataSource:(id<MPTableViewDataSource>)dataSource {
    _mpDataSource = dataSource;
    BOOL atRequired = [_mpDataSource respondsToSelector:@selector(MPTableView:cellForRowAtIndexPath:)] && [_mpDataSource respondsToSelector:@selector(MPTableView:numberOfRowsInSection:)];
    NSAssert(atRequired == YES, @"dataSource @required");
    [self _respondsToDataSource];
    [self reloadData];
}

- (id<MPTableViewDataSource>)dataSource {
    return _mpDataSource;
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled {
    if ([self _isLayoutSubviewsLock] && userInteractionEnabled) {
        return;
    }
    [super setUserInteractionEnabled:userInteractionEnabled];
}

- (void)setContentSize:(CGSize)contentSize {
    [super setContentSize:contentSize];
    if (!CGSizeEqualToSize(contentSize, _contentWrapperView.frame.size)) {
        _contentWrapperView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
    if (self.backgroundView && !CGSizeEqualToSize(contentSize, self.backgroundView.frame.size)) {
        self.backgroundView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
    }
}

NS_INLINE void
_MP_SetViewWidth(UIView *view, CGFloat width) {
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
        
        if (![_updateManager isUpdating]) {
            [self _unlockLayoutSubviews];
        }
    }
    [super setFrame:frame];
}

- (NSUInteger)numberOfSections {
    return _numberOfSections;
}

- (void)setRowHeight:(CGFloat)rowHeight {
    if (!_respond_heightForIndexPath && rowHeight >= 0) {
        _rowHeight = (rowHeight);
    }
}

- (void)setSectionHeaderHeight:(CGFloat)sectionHeaderHeight {
    if (!_respond_heightForHeaderInSection && sectionHeaderHeight >= 0) {
        _sectionHeaderHeight = (sectionHeaderHeight);
    }
}

- (void)setSectionFooterHeight:(CGFloat)sectionFooterHeight {
    if (!_respond_heightForFooterInSection && sectionFooterHeight >= 0) {
        _sectionFooterHeight = (sectionFooterHeight);
    }
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
    _needPreparationDetected = self.style == MPTableViewStylePlain && (contentInset.top != 0 || contentInset.bottom != 0);
    [super setContentInset:contentInset];
}

- (MPTableViewCell *)cellForRowAtIndexPath:(MPIndexPath *)indexPath {
    NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
    MPTableViewCell *result = nil;
    result = [_displayedCellsDic objectForKey:indexPath];
    return result;
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
//    NSMutableArray *indexPaths = [NSMutableArray array];
//    for (MPIndexPath *indexPath in _displayedCellsDic.allKeys) {
//        [indexPaths addObject:[indexPath copy]];
//    }
    return _displayedCellsDic.allKeys;
}

- (MPIndexPath *)beginIndexPath {
    MPIndexPath *indexPath = [MPIndexPath indexPathFromStruct:_beginIndexPath];
    if (indexPath.row == MPSectionTypeHeader) {
        indexPath.row = 0;
    }
    if (indexPath.row == MPSectionTypeFooter) {
        indexPath.row = NSNotFound;
        while (indexPath.section < _numberOfSections) {
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
        while (indexPath.section > 0) {
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
        indexPath.row = section.numberOfRows - 1;
    }
    return indexPath;
}

- (CGRect)rectForSection:(NSInteger)section {
    NSParameterAssert(section > 0 && section < _numberOfSections);
    
    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.frame.size.width, sectionObj.endPos - sectionObj.beginPos);
    return frame;
}

- (CGRect)rectForHeaderInSection:(NSInteger)section {
    NSParameterAssert(section > 0 && section < _numberOfSections);
    
    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.frame.size.width, sectionObj.headerHeight);
    return frame;
}

- (CGRect)rectForFooterInSection:(NSInteger)section {
    NSParameterAssert(section > 0 && section < _numberOfSections);

    CGRect frame;
    MPTableViewSection *sectionObj = _sectionsAreaList[section];
    frame.origin = CGPointMake(0, _contentDrawArea.beginPos + sectionObj.beginPos);
    frame.size = CGSizeMake(self.frame.size.width, sectionObj.footerHeight);
    return frame;
}

- (CGRect)rectForRowAtIndexPath:(MPIndexPath *)indexPath {
    NSParameterAssert(indexPath.section > 0 && indexPath.section < _numberOfSections);
    
    MPTableViewSection *section = _sectionsAreaList[indexPath.section];
    NSParameterAssert(indexPath.row > 0 && indexPath.section < section.numberOfRows);
    
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
    NSAssert(indexPath.section < _numberOfSections, @"an non-existent section");
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
    _allowsMultipleSelection = allowsMultipleSelection;
    if (_allowsMultipleSelection) {
        _allowsSelection = YES;
    }
}

- (MPIndexPath *)indexPathForSelectedRow {
    return _selectedIndexPaths.anyObject;
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
        [cell setSelected:YES];
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
        if ([indexPath compare:nearestSelectedIndexPath] == NSOrderedAscending) {
            nearestSelectedIndexPath = indexPath;
        }
    }
    [self scrollToRowAtIndexPath:nearestSelectedIndexPath atScrollPosition:scrollPosition animated:animated];
}

- (void)_deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated {
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
    if (_respond_didDeselectRowAtIndexPath) {
        [_mpDelegate MPTableView:self didDeselectRowAtIndexPath:indexPath];
    }
    [_selectedIndexPaths removeObject:indexPath];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MPTableViewSelectionDidChangeNotification object:self];
}

- (void)deselectRowAtIndexPath:(MPIndexPath *)indexPath animated:(BOOL)animated {
    if (![_selectedIndexPaths containsObject:indexPath]) {
        return;
    }
    [self _deselectRowAtIndexPath:indexPath animated:animated];
}

- (BOOL)isUpdating {
    return [_updateManager isUpdating];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSAssert(![_updateManager isUpdating], @"updating error");
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSAssert(idx < _numberOfSections, @"delete section overflow");
        NSAssert([_updateManager addDeleteSection:idx withAnimation:animation], @"check duplicate indexPaths");
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
    NSAssert(![_updateManager isUpdating], @"updating error");
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    NSUInteger count = [_mpDataSource numberOfSectionsInMPTableView:self];
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSAssert(idx < count, @"insert section overflow");
        NSAssert([_updateManager addInsertSection:idx withAnimation:animation], @"check duplicate indexPaths");
    }];
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSAssert(![_updateManager isUpdating], @"updating error");
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSAssert(idx < _numberOfSections, @"reload section overflow");
        NSAssert([_updateManager addReloadSection:idx withAnimation:animation], @"check duplicate indexPaths");
    }];
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)moveSection:(NSUInteger)section toSection:(NSUInteger)newSection {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert(section != newSection);
    NSAssert(![_updateManager isUpdating], @"updating error");
    
    NSAssert(section < _numberOfSections, @"move out section overflow");
    NSAssert(newSection < [_mpDataSource numberOfSectionsInMPTableView:self], @"move in section overflow");
    
    NSAssert([_updateManager addMoveOutSection:section], @"check duplicate indexPaths");
    
    NSAssert([_updateManager addMoveInSection:newSection withOriginIndex:section], @"check duplicate indexPaths");
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSAssert(![_updateManager isUpdating], @"updating error");
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        NSAssert(indexPath.section < _numberOfSections, @"delete section overflow");
        NSAssert(indexPath.row < [self numberOfRowsInSection:indexPath.section], @"delete row overflow");
        NSAssert([_updateManager addDeleteIndexPath:indexPath withAnimation:animation], @"check duplicate indexPaths");
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
    NSAssert(![_updateManager isUpdating], @"updating error");
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    NSUInteger count = [_mpDataSource numberOfSectionsInMPTableView:self];
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        NSAssert(indexPath.section < count, @"insert section overflow");
        NSAssert([_updateManager addInsertIndexPath:indexPath withAnimation:animation], @"check duplicate indexPaths");
    }
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(MPTableViewRowAnimation)animation {
    NSParameterAssert(_mpDataSource);
    NSAssert(![_updateManager isUpdating], @"updating error");
    if (animation == MPTableViewRowAnimationRandom) {
        animation = MPTableViewGetRandomRowAnimation();
    }
    
    for (MPIndexPath *indexPath in indexPaths) {
        NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
        NSAssert(indexPath.section < _numberOfSections, @"reload section overflow");
        NSAssert(indexPath.row < [self numberOfRowsInSection:indexPath.section], @"reload row overflow");
        NSAssert([_updateManager addReloadIndexPath:indexPath withAnimation:animation], @"check duplicate indexPaths");
    }
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)moveRowAtIndexPath:(MPIndexPath *)indexPath toIndexPath:(MPIndexPath *)newIndexPath {
    NSParameterAssert(_mpDataSource);
    NSParameterAssert([indexPath compare:newIndexPath] != NSOrderedSame);
    NSAssert(![_updateManager isUpdating], @"updating error");
    
    NSParameterAssert(indexPath.row >= 0 && indexPath.section >= 0);
    NSParameterAssert(newIndexPath.row >= 0 && newIndexPath.section >= 0);
    
    NSAssert(indexPath.section < _numberOfSections, @"move out section overflow");
    NSAssert(indexPath.row < [self numberOfRowsInSection:indexPath.section], @"move out row overflow");
    NSAssert(newIndexPath.section < [_mpDataSource numberOfSectionsInMPTableView:self], @"move in section overflow");
    
    NSAssert([_updateManager addMoveOutIndexPath:indexPath], @"check duplicate indexPaths");

    NSAssert([_updateManager addMoveInIndexPath:newIndexPath withHeight:[self _cellFrameAtIndexPath:indexPath].size.height withOriginIndexPath:indexPath], @"check duplicate indexPaths");
    
    if (![self _isLayoutSubviewsLock]) {
        [self _startUpdateAnimation];
    }
}

- (void)beginUpdates {
    NSParameterAssert(_mpDataSource);
    NSAssert(![_updateManager isUpdating], @"updating error");
    [self _lockLayoutSubviews];
}

- (void)endUpdates {
    [self _startUpdateAnimation];
}

- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    MPTableViewCell *reusableCell;
    NSMutableSet *queue = [_reusableCellsDic objectForKey:identifier];
    if (queue.count) {
        reusableCell = [queue anyObject];
        [queue removeObject:reusableCell];
        reusableCell.hidden = NO;
    } else {
        reusableCell = nil;
    }
    
    if (!reusableCell && _registerCellsClassDic) {
        Class cellClass = [_registerCellsClassDic objectForKey:identifier];
        if (cellClass) {
            reusableCell = [[cellClass alloc]initWithReuseIdentifier:identifier];
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
    
    return reusableCell;
}

- (id)dequeueReusableViewWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    MPTableReusableView *reusableView;
    NSMutableSet *queue = [_reusableReusableViewsDic objectForKey:identifier];
    if (queue.count) {
        reusableView = [queue anyObject];
        [queue removeObject:reusableView];
        reusableView.hidden = NO;
    } else {
        reusableView = nil;
    }
    
    if (!reusableView && _registerReusableViewsClassDic) {
        Class reusableViewClass = [_registerReusableViewsClassDic objectForKey:identifier];
        if (reusableViewClass) {
            reusableView = [[reusableViewClass alloc]initWithReuseIdentifier:identifier];
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
    _lastSuspendFooterSection = _lastSuspendHeaderSection = NSNotFound;
    _updateManager.originCount = _numberOfSections;
    _updateManager.newCount = _numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
    
    NSAssert([_updateManager formatNodesStable], @"check for update sections");
    
    self.userInteractionEnabled = NO;
    [self _lockLayoutSubviews];
    
    CGFloat offset = [_updateManager startUpdate];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:MPTableViewRowAnimationDuration];
    [UIView setAnimationDidStopSelector:@selector(_updateAnimationCompletion)];
    
    for (void(^animationBlock)() in _updateAnimationBlocks) {
        animationBlock();
    }
    
    CGRect frame = self.tableFooterView.frame;
    frame.origin.y += offset;
    self.tableFooterView.frame = frame;
    [UIView commitAnimations];
}

- (void)_updateAnimationCompletion {
    [_updateAnimationBlocks removeAllObjects];
    [_deleteViewsList makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_deleteViewsList removeAllObjects];
    
    [_displayedCellsDic addEntriesFromDictionary:_insertCellsDic];
    [_insertCellsDic removeAllObjects];
    [_displayedSectionViewsDic addEntriesFromDictionary:_insertSectionViewsDic];
    [_insertSectionViewsDic removeAllObjects];
    [_selectedIndexPaths unionSet:_updateExchangedSelectedIndexPaths];
    [_updateExchangedSelectedIndexPaths removeAllObjects];
    
    if (_numberOfSections) {
        MPTableViewSection *lastSection = _sectionsAreaList.lastObject;
        _contentDrawArea.endPos = lastSection.endPos + _contentDrawArea.beginPos;/* _footerView may be nil */
    } else {
        _contentDrawArea.endPos = _contentDrawArea.beginPos;
    }

    [self setContentSize:CGSizeMake(self.frame.size.width, _contentDrawArea.endPos + self.tableFooterView.frame.size.height)];
    
    if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        _beginIndexPath = indexPathStruct(NSIntegerMax, MPSectionTypeFooter);
        _endIndexPath = indexPathStruct(NSIntegerMin, MPSectionTypeHeader);
    } else {
        _beginIndexPath = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
        _endIndexPath = [self _indexPathAtContentOffset:_currDrawArea.endPos];
    }
    [self _clipCellsBetween:_beginIndexPath and:_endIndexPath];
    [self _clipSectionViewsBetween:_beginIndexPath and:_endIndexPath];
    
    [_updateManager resetManager];
    [self _unlockLayoutSubviews];
    self.userInteractionEnabled = YES;
    [self _getDisplayingArea];
    [self _updateDisplayingArea];
}

// optimized
- (void)_updateSetInsertView:(UIView *)view startFrame:(CGRect)frame withOffset:(CGFloat)offset { // on the edge of _currArea
    frame.origin.y -= offset;
    if (frame.origin.y > MPTableViewContentEnd) { //
        frame.origin.y = MPTableViewContentEnd + 1;
    }
    if (CGRectGetMaxY(frame) < MPTableViewContentBegin) {
        frame.origin.y = MPTableViewContentBegin - frame.size.height - 1;
    }
    view.frame = frame;
}

- (void)_updateOffsetView:(UIView *)view toOriginY:(CGFloat)originY {
    CGRect frame = view.frame;
    frame.origin.y = originY;
    if (frame.origin.y > MPTableViewContentEnd) {
        frame.origin.y = MPTableViewContentEnd + 1;
    }
    if (CGRectGetMaxY(frame) < MPTableViewContentBegin) {
        frame.origin.y = MPTableViewContentBegin - frame.size.height - 1;
    }
    view.frame = frame;
}

- (BOOL)updateNeedToAnimateSection:(MPTableViewSection *)section updateType:(MPTableViewUpdateType)type andOffset:(CGFloat)offset {
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

#define MPTableViewUpdateOutOfDisplayArea (frame.origin.y > MPTableViewContentEnd || CGRectGetMaxY(frame) < MPTableViewContentBegin)

#pragma mark -cell update

- (CGFloat)updateSection:(NSInteger)section cellHeightAtIndex:(NSInteger)index {
    CGFloat cellHeight;
    if (_respond_heightForIndexPath) {
        cellHeight = ([_mpDataSource MPTableView:self heightForIndexPath:[MPIndexPath indexPathForRow:index inSection:section]]);
        NSAssert(cellHeight >= 0, @"cell height");
    } else {
        cellHeight = MPTableViewDefaultCellHeight;
    }
    
    return cellHeight;
}

- (void)updateSection:(NSInteger)originSection deleteCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:originSection];
    
    if ([indexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
        return ;
    }
    
    MPTableViewCell *cell = [_displayedCellsDic objectForKey:indexPath];
    
    if (_respond_willDeleteCellForRowAtIndexPath) {
        [_mpDelegate MPTableView:self willDeleteCell:cell forRowAtIndexPath:indexPath];
    }
    if (_respond_didEndDisplayingCellForRowAtIndexPath) {
        [_mpDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
    }
    
    void (^animationBlock)() = ^{
        CGRect optimizeFrame = MPTableViewDisappearViewFrameWithRowAnimation(cell, animation, sectionPosition, _contentDrawArea.beginPos);
        if (sectionPosition) {
            if (optimizeFrame.origin.y > MPTableViewContentEnd) {
                optimizeFrame.origin.y = MPTableViewContentEnd + 1;
            }
            if (optimizeFrame.origin.y < MPTableViewContentBegin) { // only in section animation, top、bottom、middle, cell's height should be 0
                optimizeFrame.origin.y = MPTableViewContentBegin - 1;
            }
        }
        cell.frame = optimizeFrame;
    };
    
    [_updateAnimationBlocks addObject:animationBlock];
    [_deleteViewsList addObject:cell];
    [_displayedCellsDic removeObjectForKey:indexPath];
}

- (void)updateSection:(NSInteger)section insertCellAtIndex:(NSInteger)index withAnimation:(MPTableViewRowAnimation)animation isSectionAnimation:(MPTableViewSection *)sectionPosition {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:index inSection:section];
    
    CGRect frame = [self _cellFrameAtIndexPath:indexPath];
    if (MPTableViewUpdateOutOfDisplayArea) { //
        return ;
    } else {
        MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
        
        [cell setSelected:[_selectedIndexPaths containsObject:indexPath]];
        
        cell.frame = frame;
        CGRect optimizeFrame = MPTableViewDisappearViewFrameWithRowAnimation(cell, animation, sectionPosition, _contentDrawArea.beginPos);
        if (sectionPosition) {
            if (optimizeFrame.origin.y > MPTableViewContentEnd && CGRectGetMaxY(frame) <= MPTableViewContentEnd/* except for the last one, which is in edge of display area */) {
                optimizeFrame.origin.y = MPTableViewContentEnd + 1;
            }
            if (optimizeFrame.origin.y < MPTableViewContentBegin && frame.origin.y >= MPTableViewContentBegin) {
                optimizeFrame.origin.y = MPTableViewContentBegin - 1;
            }
        }
        cell.frame = optimizeFrame;
        
        if (_respond_willInsertCellForRowAtIndexPath) {
            [_mpDelegate MPTableView:self willInsertCell:cell forRowAtIndexPath:indexPath];
        }
        
        void (^animationBlock)() = ^{
            [self _addCellToWrapperViewIfNeeded:cell];
            MPTableViewDisplayViewFrameWithRowAnimation(cell, frame, animation, sectionPosition);
        };
        [_updateAnimationBlocks addObject:animationBlock];
        [_insertCellsDic setObject:cell forKey:indexPath];
    }
}

- (void)updateSection:(NSInteger)section moveInCellAtIndex:(NSInteger)index fromOriginIndexPath:(MPIndexPath *)originIndexPath {
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
    if (MPTableViewUpdateOutOfDisplayArea) {
        if (cell) {
            frame = cell.frame;
            if ([indexPath compare:originIndexPath] == NSOrderedAscending) { //
                frame.origin.y = MPTableViewContentBegin - frame.size.height - 1;
            } else {
                frame.origin.y = MPTableViewContentEnd + 1;
            }
            
            if (_respond_didEndDisplayingCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
            }
            
            void (^animationBlock)() = ^{
                cell.frame = frame;
            };
            [_updateAnimationBlocks addObject:animationBlock];
            [_deleteViewsList addObject:cell];
        }
    } else {
        CGFloat currOriginY = frame.origin.y;
        if (!cell) {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            if ([indexPath compare:originIndexPath] == NSOrderedAscending) { //
                frame.origin.y = MPTableViewContentEnd + 1;
            } else {
                frame.origin.y = MPTableViewContentBegin - frame.size.height - 1;
            }
            if (_respond_willInsertCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self willInsertCell:cell forRowAtIndexPath:indexPath];
            }
            cell.frame = frame;
            if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES];
            }
        }
        
        void (^animationBlock)() = ^{
            [self _addCellToWrapperViewIfNeeded:cell];
            [_contentWrapperView bringSubviewToFront:cell];
            [self _updateOffsetView:cell toOriginY:currOriginY];
        };
        [_updateAnimationBlocks addObject:animationBlock];
        [_insertCellsDic setObject:cell forKey:indexPath];
    }
}

- (void)updateSection:(NSInteger)section originSection:(NSInteger)originSection exchangeCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withOffset:(CGFloat)cellOffset {
    
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:originIndex inSection:originSection];
    
    BOOL indexPathChanged = NO;
    if (originIndex != currIndex || section != originSection) {
        indexPathChanged = YES;
    }

    MPTableViewCell *cell;
    CGFloat originY;
    if ([indexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
        indexPath.row = currIndex;
        indexPath.section = section;
        CGRect frame = [self _cellFrameAtIndexPath:indexPath];
        if (MPTableViewUpdateOutOfDisplayArea) {
            return ;
        } else {
            cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
            if (_respond_willInsertCellForRowAtIndexPath) {
                [_mpDelegate MPTableView:self willInsertCell:cell forRowAtIndexPath:indexPath];
            }
            
            if ([_updateExchangedSelectedIndexPaths containsObject:indexPath]) {
                [cell setSelected:YES];
            }
            
            originY = frame.origin.y;
            [self _updateSetInsertView:cell startFrame:frame withOffset:cellOffset];
            [_insertCellsDic setObject:cell forKey:indexPath];
        }
    } else {
        cell = [_displayedCellsDic objectForKey:indexPath];
        originY = cell.frame.origin.y + cellOffset;
        if (indexPathChanged) {
            [_displayedCellsDic removeObjectForKey:indexPath];
            indexPath.row = currIndex;
            indexPath.section = section;
            [_insertCellsDic setObject:cell forKey:indexPath];
        }
    }
    
    void (^animationBlock)() = ^{
        [self _addCellToWrapperViewIfNeeded:cell];
        [self _updateOffsetView:cell toOriginY:originY];
    };
    [_updateAnimationBlocks addObject:animationBlock];
}

- (void)updateSection:(NSInteger)section originSection:(NSInteger)originSection exchangeCellAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex {
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

#pragma mark -sectionView

- (MPTableViewSection *)updateMakeSectionAt:(NSInteger)sectionIndex {
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

- (BOOL)_needSuspendingSection:(MPTableViewSection *)section withType:(MPSectionType)type {
    if (type == MPSectionTypeHeader) {
        CGFloat beginPos = _currDrawArea.beginPos + self.contentInset.top;
        if (section.beginPos <= beginPos && section.endPos >= beginPos) {
            if (_lastSuspendHeaderSection == NSNotFound) {
                _lastSuspendHeaderSection = _currSuspendHeaderSection;
            }
            _currSuspendHeaderSection = section.section;
            return YES;
        } else {
            return NO;
        }
    } else {
        if (section.beginPos <= _currDrawArea.endPos - self.contentInset.bottom && section.endPos >= _currDrawArea.endPos - self.contentInset.bottom) {
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
// ...
- (void)_updateOptimizeSectionView:(UIView *)sectionView withType:(MPSectionType)type inSection:(MPTableViewSection *)section {
    CGFloat originY;
    if (type == MPSectionTypeHeader) {
        if (section.beginPos < _currDrawArea.beginPos) {
            originY = _currDrawArea.beginPos - sectionView.frame.size.height - 1;
        } else {
            originY = section.beginPos;
        }
    } else {
        if (section.endPos > _currDrawArea.endPos) {
            originY = _currDrawArea.endPos + 1;
        } else {
            originY = section.endPos - section.footerHeight;
        }
    }
    
    if (sectionView) {
        CGRect frame = sectionView.frame;
        frame.origin.y = originY + _contentDrawArea.beginPos;
        sectionView.frame = frame;
    }
}

- (void)updateDeleteSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withDeleteSection:(MPTableViewSection *)deleteSection {
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
    
    if (type == MPSectionTypeHeader) {
        if (_respond_willDeleteHeaderViewForSection) {
            [_mpDelegate MPTableView:self willDeleteHeaderView:sectionView forSection:index];
        }
        if (_respond_didEndDisplayingHeaderViewForSection) {
            [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:index];
        }
    } else {
        if (_respond_willDeleteFooterViewForSection) {
            [_mpDelegate MPTableView:self willDeleteFooterView:sectionView forSection:index];
        }
        if (_respond_didEndDisplayingFooterViewForSection) {
            [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:index];
        }
    }
    
    void (^animationBlock)() = ^{
        CGRect optimizeFrame = MPTableViewDisappearViewFrameWithRowAnimation(sectionView, animation, deleteSection, _contentDrawArea.beginPos);
        if (optimizeFrame.origin.y > MPTableViewContentEnd) {
            optimizeFrame.origin.y = MPTableViewContentEnd + 1;
        }
        if (optimizeFrame.origin.y < MPTableViewContentBegin) {
            optimizeFrame.origin.y = MPTableViewContentBegin - 1;
        }
        sectionView.frame = optimizeFrame;
    };
    [_updateAnimationBlocks addObject:animationBlock];
    [_deleteViewsList addObject:sectionView];
    [_displayedSectionViewsDic removeObjectForKey:indexPath];
}

- (void)updateInsertSectionViewAtIndex:(NSInteger)index withType:(MPSectionType)type withAnimation:(MPTableViewRowAnimation)animation withInsertSection:(MPTableViewSection *)insertSection {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
    
    BOOL isDisplayingDefault = !MPTableViewUpdateOutOfDisplayArea;
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
        MPTableReusableView *sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
        if (!sectionView) {
            return;
        }
        sectionView.frame = frame;
        CGRect optimizeFrame = MPTableViewDisappearViewFrameWithRowAnimation(sectionView, animation, insertSection, _contentDrawArea.beginPos);
        if (optimizeFrame.origin.y > MPTableViewContentEnd && CGRectGetMaxY(frame) <= MPTableViewContentEnd/* except for the last one, which in edge of display area */) {
            optimizeFrame.origin.y = MPTableViewContentEnd + 1;
        }
        if (optimizeFrame.origin.y < MPTableViewContentBegin && frame.origin.y >= MPTableViewContentBegin) {
            optimizeFrame.origin.y = MPTableViewContentBegin - 1;
        }
        sectionView.frame = optimizeFrame;
        
        if (type == MPSectionTypeHeader) {
            if (_respond_willInsertHeaderViewForSection) {
                [_mpDelegate MPTableView:self willInsertHeaderView:sectionView forSection:index];
            }
        } else {
            if (_respond_willInsertFooterViewForSection) {
                [_mpDelegate MPTableView:self willInsertFooterView:sectionView forSection:index];
            }
        }
        
        void (^animationBlock)() = ^{
            [self _addSectionViewToWrapperViewIfNeeded:sectionView];
            MPTableViewDisplayViewFrameWithRowAnimation(sectionView, frame, animation, insertSection);
            if (isSuspending) {
                if (type == MPSectionTypeHeader) {
                    [self _suspendingSectionHeader:sectionView inArea:insertSection];
                } else {
                    [self _suspendingSectionFooter:sectionView inArea:insertSection];
                }
            } else if (isPrepareToSuspend) {
                sectionView.frame = [self _prepareToSuspendViewFrameAt:insertSection withType:type];
            }
        };
        [_updateAnimationBlocks addObject:animationBlock];
        [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
    }
}

- (void)updateMoveInSectionViewAtIndex:(NSInteger)index fromOriginIndex:(NSInteger)originIndex withType:(MPSectionType)type {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:index];
    MPIndexPath *originIndexPath = [MPIndexPath indexPathForRow:type inSection:originIndex];
    
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:originIndexPath];
    if (sectionView) {
        [_displayedSectionViewsDic removeObjectForKey:originIndexPath];
    }
    
    CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
    BOOL isDisplayingDefault = !MPTableViewUpdateOutOfDisplayArea;
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
    
    if (!isDisplayingDefault && !isSuspending && !isPrepareToSuspend) {
        if (sectionView) { // view will be moving out of the display area
            frame = sectionView.frame;
            if ([indexPath compare:originIndexPath] == NSOrderedAscending) { //
                frame.origin.y = MPTableViewContentBegin - frame.size.height - 1;
            } else {
                frame.origin.y = MPTableViewContentEnd + 1;
            }
            
            if (type == MPSectionTypeHeader && _respond_didEndDisplayingHeaderViewForSection) {
                [_mpDelegate MPTableView:self didEndDisplayingHeaderView:sectionView forSection:originIndex];
            }
            if (type == MPSectionTypeFooter && _respond_didEndDisplayingFooterViewForSection) {
                [_mpDelegate MPTableView:self didEndDisplayingFooterView:sectionView forSection:originIndex];
            }
            
            void (^animationBlock)() = ^{
                sectionView.frame = frame;
            };
            [_updateAnimationBlocks addObject:animationBlock];
            [_deleteViewsList addObject:sectionView];
        }
    } else {
        CGFloat currOriginY = frame.origin.y;
        if (!sectionView) { // view will be moving to the display area
            sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
            if (!sectionView) {
                return;
            }
            if ([indexPath compare:originIndexPath] == NSOrderedAscending) { //
                frame.origin.y = MPTableViewContentEnd + 1;
            } else {
                frame.origin.y = MPTableViewContentBegin - frame.size.height - 1;
            }
            sectionView.frame = frame;
        }
        
        void (^animationBlock)() = ^{
            [self _addSectionViewToWrapperViewIfNeeded:sectionView];
            [self bringSubviewToFront:sectionView];
            if (isDisplayingDefault) {
                [self _updateOffsetView:sectionView toOriginY:currOriginY];
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
                sectionView.frame = [self _prepareToSuspendViewFrameAt:_sectionsAreaList[index] withType:type];
            }
        };
        [_updateAnimationBlocks addObject:animationBlock];
        [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
    }
}

- (void)updateExchangeSectionViewAtIndex:(NSInteger)originIndex toIndex:(NSInteger)currIndex withType:(MPSectionType)type withSectionOffset:(CGFloat)sectionOffset {
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
    
    CGFloat originY;
    if (!sectionView) {
        indexPath.section = currIndex;
        CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
        if (MPTableViewUpdateOutOfDisplayArea && !isSuspending && !isPrepareToSuspend) {
            return ;
        } else {
            sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
            if (!sectionView) {
                return;
            }
            originY = frame.origin.y;
            [self _updateSetInsertView:sectionView startFrame:frame withOffset:sectionOffset];
            [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
        }
    } else {
        originY = sectionView.frame.origin.y + sectionOffset;
        if (self.style == MPTableViewStylePlain && !isSuspending && !isPrepareToSuspend) { // displaying
            MPTableViewSection *section = _sectionsAreaList[currIndex];
            if (type == MPSectionTypeHeader && originY != section.beginPos + _contentDrawArea.beginPos) { // need to reset
                originY = section.beginPos + _contentDrawArea.beginPos;
            }
            if (type == MPSectionTypeFooter && originY != section.endPos - section.footerHeight + _contentDrawArea.beginPos) { // need to reset
                originY = section.endPos - section.footerHeight + _contentDrawArea.beginPos;
            }
        }
        if (originIndex != currIndex) {
            [_displayedSectionViewsDic removeObjectForKey:indexPath];
            indexPath.section = currIndex;
            [_insertSectionViewsDic setObject:sectionView forKey:indexPath];
        }
    }
    void (^animationBlock)() = ^{
        [self _addSectionViewToWrapperViewIfNeeded:sectionView];
        if (isSuspending) {
            if (type == MPSectionTypeHeader) {
                [self _suspendingSectionHeader:sectionView inArea:_sectionsAreaList[currIndex]];
            } else
                if (type == MPSectionTypeFooter) {
                    [self _suspendingSectionFooter:sectionView inArea:_sectionsAreaList[currIndex]];
                }
        } else if (isPrepareToSuspend) {
            sectionView.frame = [self _prepareToSuspendViewFrameAt:_sectionsAreaList[currIndex] withType:type];
        } else {
            [self _updateOffsetView:sectionView toOriginY:originY];
            
            // another option, but it is not tested
            
//            BOOL needReset;
//            if (type == MPSectionTypeHeader) {
//                needReset = currIndex == _lastSuspendHeaderSection || currIndex == _lastPrepareHeaderSection;
//            } else {
//                needReset = currIndex == _lastSuspendFooterSection || currIndex == _lastPrepareFooterSection;
//            }
//            if (needReset) {
//                [self _updateResetSectionView:sectionView withType:type inSection:_sectionsAreaList[currIndex]];
//            } else {
//                [self _updateOffsetView:sectionView toOriginY:originY];
//            }
        }
    };
    [_updateAnimationBlocks addObject:animationBlock];
}

#pragma mark --reload
//
- (void)_clear {
    _contentDrawArea.beginPos = _contentDrawArea.endPos = 0;
    _currDrawArea.beginPos = _currDrawArea.endPos = 0;

    [_selectedIndexPaths removeAllObjects];

    [self _resetContentIndexPaths];
    
    if (self.enableCachesReload) {
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
    
    _beginIndexPath = indexPathStruct(NSIntegerMax, MPSectionTypeFooter);
    _endIndexPath = indexPathStruct(NSIntegerMin, MPSectionTypeHeader);
    
    _highlightedIndexPath = nil;
}

- (void)_cacheDisplayingCells {
    for (MPTableViewCell *cell in _displayedCellsDic.allValues) {
        [self _cacheCell:cell];
    }
    [_displayedCellsDic removeAllObjects];
}

- (void)_cacheDisplayingSectionViews {
    for (MPTableReusableView *sectionView in _displayedSectionViewsDic.allValues) {
        [self _cacheSectionView:sectionView];
    }
    [_displayedSectionViewsDic removeAllObjects];
}

- (void)_clearDisplayingCells {
    [_displayedCellsDic.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_displayedCellsDic removeAllObjects];
}

- (void)clearReusableCells {
    for (NSMutableSet *queue in _reusableCellsDic.allValues) {
        [queue makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [queue removeAllObjects];
    }
    [_reusableCellsDic removeAllObjects];
}

- (void)clearReusableSectionViews {
    for (NSMutableSet *queue in _reusableReusableViewsDic.allValues) {
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
    if ([_updateManager isUpdating]) {
        return dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MPTableViewRowAnimationDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadData];
        });
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

- (void)reloadDataAsyncWithCompleter:(void (^)())completer {
    if (!_mpDataSource) {
        return;
    }
    if ([_updateManager isUpdating]) {
        return dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MPTableViewRowAnimationDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadDataAsyncWithCompleter:completer];
        });
    }
    [self _lockLayoutSubviews];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *newSections = [NSMutableArray array];
        CGFloat height = [self _initializeViewsPositionWithNewSections:newSections];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _clear];
            _updateManager.sections = _sectionsAreaList = newSections;
            [self _unlockLayoutSubviews];
            if (height != _ReloadDataAsync_Exception_Value && [self superview]) {
                [self _setVerticalContentHeight:height];
                [self _getDisplayingArea];
                [self _updateDisplayingArea];
            }
            if (completer) {
                completer();
            }
        });
    });
}

- (CGFloat)_initializeSection:(MPTableViewSection *)section withOffset:(CGFloat)step {
    // header
    section.beginPos = step;
    if (_respond_viewForHeaderInSection || self.style == MPTableViewStyleGrouped) {
        CGFloat height;
        if (_respond_heightForHeaderInSection) {
            _ReloadDataAsync_Exception_
            height = [_mpDataSource MPTableView:self heightForHeaderInSection:section.section];
        } else {
            height = self.sectionHeaderHeight;
        }
        NSAssert(height >= 0, @"section header height");
        section.headerHeight = height;
        step += height;
    }
    if (_mpDataSource) {
        NSUInteger rowsInSection = [_mpDataSource MPTableView:self numberOfRowsInSection:section.section];
        section.numberOfRows = rowsInSection;
        for (NSInteger j = 0; j < rowsInSection; j++) {
            MPIndexPath *indexPath = [MPIndexPath indexPathForRow:j inSection:section.section];
            CGFloat cellHeight;
            if (_respond_heightForIndexPath) {
                _ReloadDataAsync_Exception_
                cellHeight = [_mpDataSource MPTableView:self heightForIndexPath:indexPath];
            } else {
                cellHeight = self.rowHeight;
            }
            NSAssert(cellHeight >= 0, @"cell height");
            [section addRowWithPosition:step += cellHeight];
        }
    }
    // footer
    if (_respond_viewForFooterInSection || self.style == MPTableViewStyleGrouped) {
        CGFloat height;
        if (_respond_heightForFooterInSection) {
            _ReloadDataAsync_Exception_
            height = [_mpDataSource MPTableView:self heightForFooterInSection:section.section];
        } else {
            height = self.sectionFooterHeight;
        }
        NSAssert(height >= 0, @"section footer height");
        section.footerHeight = height;
        step += height;
    }
    section.endPos = step;
    return step;
}

- (CGFloat)_initializeViewsPositionWithNewSections:(NSMutableArray *)newSections {
    CGFloat step = 0;
    const NSUInteger sectionsCount = _sectionsAreaList.count;
    _ReloadDataAsync_Exception_
    _numberOfSections = [_mpDataSource numberOfSectionsInMPTableView:self];
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
        if (step == _ReloadDataAsync_Exception_Value) {
            [newSections removeAllObjects];
            break;
        }
        if (i >= sectionsCount) {
            [_sectionsAreaList addObject:section];
        }
        if (newSections) {
            [newSections addObject:section];
        }
    }
    return step;
}
// header、footer、contentSize
- (void)_setVerticalContentHeight:(CGFloat)step {
    CGFloat contentSizeHeight = 0;
    if (self.tableHeaderView) {
        contentSizeHeight = _contentDrawArea.beginPos = (self.tableHeaderView.frame.size.height);
    }
    contentSizeHeight = _contentDrawArea.endPos = _contentDrawArea.beginPos + step;
    if (self.tableFooterView) {
        CGRect frame = self.tableFooterView.frame;
        CGFloat posY = _contentDrawArea.endPos;
        contentSizeHeight += frame.size.height;
        
        if (posY <= _contentDrawArea.endPos) { // 0 cell
            frame.origin.y = _contentDrawArea.endPos;
        } else {
            frame.origin.y = posY;
        }
        self.tableFooterView.frame = frame;
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
    _currDrawArea.beginPos = self.contentOffset.y - _contentDrawArea.beginPos;
    _currDrawArea.endPos = self.contentOffset.y + self.frame.size.height - _contentDrawArea.beginPos;
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
    return indexPathStruct(sectionIndex, row);
}

- (void)_addCellToWrapperViewIfNeeded:(MPTableViewCell *)cell {
    [cell prepareForDisplaying];
    if (![cell superview] || cell.superview != _contentWrapperView) {
        [_contentWrapperView addSubview:cell];
    }
}

- (void)_addSectionViewToWrapperViewIfNeeded:(MPTableReusableView *)sectionView {
    [sectionView prepareForDisplaying];
    if (![sectionView superview] || sectionView.superview != _contentWrapperView) {
        [self insertSubview:sectionView aboveSubview:_contentWrapperView];
    }
}

- (void)_cacheCell:(MPTableViewCell *)cell {
    if (cell.identifier) {
        [cell prepareForReuse];
        
        NSMutableSet *queue = [_reusableCellsDic objectForKey:cell.identifier];
        if (!queue) {
            queue = [NSMutableSet set];
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
    if (sectionView.identifier) {
        NSMutableSet *queue = [_reusableReusableViewsDic objectForKey:sectionView.identifier];
        if (!queue) {
            queue = [NSMutableSet set];
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
                CGRect frame = [self _prepareToSuspendViewFrameAt:section withType:indexPath.row];
                if (frame.origin.y != sectionView.frame.origin.y) {
                    sectionView.frame = frame;
                }
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
                            frame.origin.y = section.endPos + _contentDrawArea.beginPos;
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

- (void)_updateDisplayingArea {
    if (_contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        return;
    }
    [self _lockLayoutSubviews];
    MPIndexPathStruct beginIndexPathStruct = [self _indexPathAtContentOffset:_currDrawArea.beginPos];
    MPIndexPathStruct endIndexPathStruct = [self _indexPathAtContentOffset:_currDrawArea.endPos];
    if (self.style == MPTableViewStylePlain) {
        [self _suspendSectionHeaderIfNeededAt:beginIndexPathStruct];
        [self _suspendSectionFooterIfNeededAt:endIndexPathStruct];
    }
    if (!MPEqualIndexPaths(_beginIndexPath, beginIndexPathStruct) || !MPEqualIndexPaths(_endIndexPath, endIndexPathStruct)) {
        
        [self _clipCellsBetween:beginIndexPathStruct and:endIndexPathStruct];
        [self _clipSectionViewsBetween:beginIndexPathStruct and:endIndexPathStruct];

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
                        [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeHeader];
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
                        [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeFooter];
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
                    [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeHeader];
                } else {
                    [self _displayingSectionViewAtIndexPath:[MPIndexPath indexPathForRow:MPSectionTypeHeader inSection:i]];
                }
            }
            if (needSectionFooter && section.footerHeight) {
                if ([self _needPrepareToSuspendViewAt:section withType:MPSectionTypeFooter]) {
                    [self _makePrepareToSuspendViewInSection:section withType:MPSectionTypeFooter];
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
                    MPTableViewCell *cell = [self _getCellFromDataSourceAtIndexPath:indexPath];
                    if (!cell) {
                        continue;
                    }
                    if ([_selectedIndexPaths containsObject:indexPath]) {
                        [cell setSelected:YES];
                    }
                    cell.frame = [self _cellFrameAtIndexPath:indexPath];
                    [self _addCellToWrapperViewIfNeeded:cell];
                    [_displayedCellsDic setObject:cell forKey:indexPath];
                }
            }
        }
        
        _beginIndexPath = beginIndexPathStruct;
        _endIndexPath = endIndexPathStruct;
    }
    
    [self _unlockLayoutSubviews];
}

- (MPTableViewCell *)_getCellFromDataSourceAtIndexPath:(MPIndexPath *)indexPath {
    MPTableViewCell *cell = [_mpDataSource MPTableView:self cellForRowAtIndexPath:indexPath];
    NSParameterAssert(cell);
    if (_respond_willDisplayCellForRowAtIndexPath) {
        [_mpDelegate MPTableView:self willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    return cell;
}

- (CGRect)_cellFrameAtIndexPath:(MPIndexPath *)indexPath {
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
            if (sectionView && _respond_willDisplayHeaderViewForSection) {
                [_mpDelegate MPTableView:self willDisplayHeaderView:sectionView forSection:indexPath.section];
            }
        }
    } else{
        if (_respond_viewForFooterInSection) {
            sectionView = [_mpDataSource MPTableView:self viewForFooterInSection:indexPath.section];
            if (sectionView && _respond_willDisplayFooterViewForSection) {
                [_mpDelegate MPTableView:self willDisplayFooterView:sectionView forSection:indexPath.section];
            }
        }
    }
    //NSParameterAssert(sectionView);
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
    sectionViewFrame.size.width = _contentWrapperView.frame.size.width;
    sectionViewFrame.origin.y += _contentDrawArea.beginPos;
    return sectionViewFrame;
}

- (void)_displayingSectionViewAtIndexPath:(MPIndexPath *)indexPath {
    MPTableReusableView *sectionView = nil;
    if (self.style == MPTableViewStylePlain) {
        if (![_displayedSectionViewsDic objectForKey:indexPath]) {
            sectionView = [self _drawSctionViewAtIndexPath:indexPath];
        }
    } else {
        if ([indexPath compareIndexPathAt:_beginIndexPath] == NSOrderedAscending || [indexPath compareIndexPathAt:_endIndexPath] == NSOrderedDescending) {
            sectionView = [self _drawSctionViewAtIndexPath:indexPath];
        }
    }
}

- (MPTableReusableView *)_drawSctionViewAtIndexPath:(MPIndexPath *)indexPath {
    MPTableReusableView *sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
    if (sectionView) {
        CGRect frame = [self _sectionViewFrameAtIndexPath:indexPath];
        sectionView.frame = frame;
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
        CGFloat prepareBegin = _currDrawArea.beginPos + self.contentInset.top;
        if (self.contentInset.top != 0 && section.endPos <= prepareBegin && section.endPos - section.footerHeight >= _currDrawArea.beginPos) {
            return YES;
        } else {
            return NO;
        }
    } else {
        CGFloat prepareEnd = _currDrawArea.endPos - self.contentInset.bottom;
        if (self.contentInset.bottom != 0 && section.beginPos >= prepareEnd && section.beginPos + section.headerHeight <= _currDrawArea.endPos) {
            return YES;
        } else {
            return NO;
        }
    }
}

- (CGRect)_prepareToSuspendViewFrameAt:(MPTableViewSection *)section withType:(MPSectionType)type {
    if (type == MPSectionTypeHeader) {
        return CGRectMake(0, section.endPos - section.footerHeight - section.headerHeight + _contentDrawArea.beginPos, _contentWrapperView.frame.size.width, section.headerHeight);
    } else {
        return CGRectMake(0, section.beginPos + section.headerHeight + _contentDrawArea.beginPos, _contentWrapperView.frame.size.width, section.footerHeight);
    }
}

- (void)_makePrepareToSuspendViewInSection:(MPTableViewSection *)section withType:(MPSectionType)type {
    MPIndexPath *indexPath = [MPIndexPath indexPathForRow:type inSection:section.section];
    MPTableReusableView *sectionView = [_displayedSectionViewsDic objectForKey:indexPath];
    if (!sectionView) {
        sectionView = [self _getSectionViewFromDelegateAtIndexPath:indexPath];
    }
    if (sectionView) {
        sectionView.frame = [self _prepareToSuspendViewFrameAt:section withType:type];
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
            suspendHeader = [self _drawSctionViewAtIndexPath:indexPath];
        }
        [self _suspendingSectionHeader:suspendHeader inArea:section];
    }
}

- (void)_suspendingSectionHeader:(UIView *)suspendHeader inArea:(MPTableViewSection *)section {
    if (suspendHeader) {
        CGRect frame = suspendHeader.frame;
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

- (void)_suspendSectionFooterIfNeededAt:(MPIndexPathStruct) endIndexPath {
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
            suspendFooter = [self _drawSctionViewAtIndexPath:indexPath];
        }
        [self _suspendingSectionFooter:suspendFooter inArea:section];
    }
}

- (void)_suspendingSectionFooter:(UIView *)suspendFooter inArea:(MPTableViewSection *)section {
    if (suspendFooter) {
        CGRect frame = suspendFooter.frame;
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
}

#pragma mark -select

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if ([self isDecelerating] || [self isDragging] || _contentDrawArea.beginPos >= _contentDrawArea.endPos) {
        return;
    }
    
    UITouch *touch = touches.anyObject;
    CGFloat touchPosition = [touch locationInView:self].y;
    if (_allowsSelection && touchPosition >= _contentDrawArea.beginPos && touchPosition <= _contentDrawArea.endPos) {
        
        MPIndexPath *highlightedIndexPath = [MPIndexPath indexPathFromStruct:[self _indexPathAtContentOffset:touchPosition - _contentDrawArea.beginPos]];
        if (highlightedIndexPath.row == MPSectionTypeHeader || highlightedIndexPath.row == MPSectionTypeFooter) {
            return;
        }
        
        if (_respond_shouldHighlightRowAtIndexPath && ![_mpDelegate MPTableView:self shouldHighlightRowAtIndexPath:highlightedIndexPath]) {
            return;
        }
        
        MPTableViewCell *cell = [_displayedCellsDic objectForKey:_highlightedIndexPath = highlightedIndexPath];
        if (!cell) {
            return;
        }
        if (![cell isHighlighted]) {
            [cell setHighlighted:YES];
        }
        if (_respond_didHighlightRowAtIndexPath) {
            [_mpDelegate MPTableView:self didHighlightRowAtIndexPath:highlightedIndexPath];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
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
            [self _deselectRowAtIndexPath:_highlightedIndexPath animated:NO];
        } else {
            if (!_allowsMultipleSelection && ![_selectedIndexPaths containsObject:_highlightedIndexPath]) {
                [self _deselectRowAtIndexPath:_selectedIndexPaths.anyObject animated:NO];
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