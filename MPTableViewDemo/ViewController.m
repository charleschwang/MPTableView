//
//  ViewController.m
//  MPTableViewDemo
//
//  Created by apple on 16/3/25.
//  Copyright © 2016年 SMT. All rights reserved.
//

#import "ViewController.h"

#import "MPTableView.h"
#import "MyDemoCell.h"
#import "MySectionView.h"

@interface ViewController () <MPTableViewDataSource, MPTableViewDelegate, MPTableViewDataSourcePrefetching>

@property (nonatomic, strong) MPTableView *tableView;
@property (nonatomic, assign) NSInteger sectionsCount;
@property (nonatomic, assign) NSInteger cellsCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"MPTableView";
    
    self.tableView = [[MPTableView alloc] initWithFrame:(CGRect){0, 0, self.view.frame.size.width, self.view.frame.size.height} style:MPTableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.prefetchDataSource = self;
    
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    [self.tableView registerClass:[MyDemoCell class] forCellReuseIdentifier:@"MyDemoCell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"MySectionView" bundle:nil] forReusableViewReuseIdentifier:@"MySectionView"];
    
    self.cellsCount = 6;
    self.sectionsCount = 6;
    self.tableView.sectionFooterHeight = 30;
    
    self.tableView.dragModeEnabled = YES;
    self.tableView.allowsSelectionForDragMode = YES;
    self.tableView.dragCellFloating = YES;
    
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 114, 114)];
    header.backgroundColor = [UIColor darkGrayColor];
    header.font = [UIFont systemFontOfSize:20];
    header.textAlignment = NSTextAlignmentCenter;
    header.text = @"Header";
    self.tableView.tableHeaderView = header;
    
    [self setupSubviews];
}

#pragma mark -

- (void)setupSubviews {
    UIButton *toolsBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, 200, 70, 40)];
    toolsBtn.backgroundColor = [UIColor darkGrayColor];
    [toolsBtn setTitle:@"Menu" forState:UIControlStateNormal];
    [toolsBtn addTarget:self action:@selector(showMenuAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:toolsBtn];
}

- (void)showMenuAction:(UIButton *)sender {
    [self becomeFirstResponder];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setMenuItems:@[[[UIMenuItem alloc] initWithTitle:@"insert" action:@selector(tableViewInsert)],
                                   [[UIMenuItem alloc] initWithTitle:@"delete" action:@selector(tableViewDelete)],
                                   [[UIMenuItem alloc] initWithTitle:@"update" action:@selector(tableViewUpdate)],
                                   [[UIMenuItem alloc] initWithTitle:@"async reloadData" action:@selector(tableViewReload)]]];
    [menuController setTargetRect:CGRectMake(0, 0, 0, 0) inView:sender];
    [menuController setMenuVisible:YES animated:YES];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)tableViewDelete {
    if (self.sectionsCount == 0) {
        NSLog(@"we need at least 1 section");
        return;
    }
    
    for (NSInteger i = 1, rows = [self.tableView numberOfRowsInSection:0]; i < self.tableView.numberOfSections; i++) {
        if (rows != [self.tableView numberOfRowsInSection:i]) {
            NSLog(@"need the same number of rows in every section");
            return;
        }
    }
    
    --self.sectionsCount;
    if (self.sectionsCount % 2) { // custom animation
        // set the default animation duration of cells equals to those customizations
        [self.tableView performBatchUpdates:^{
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationCustom];
        } duration:1.5 delay:0 completion:nil];
    } else { // built-in animation
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationLeft];
    }
}

- (void)tableViewInsert {
    for (NSInteger i = 1, rows = [self.tableView numberOfRowsInSection:0]; i < self.tableView.numberOfSections; i++) {
        if (rows != [self.tableView numberOfRowsInSection:i]) {
            NSLog(@"need the same number of rows in every section");
            return;
        }
    }
    
    ++self.sectionsCount;
    if (self.sectionsCount % 2) { // custom animation
        [self.tableView performBatchUpdates:^{
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationCustom];
        } duration:1.5 delay:0 completion:nil];
    } else { // built-in animation
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationLeft];
    }
}

- (void)tableViewUpdate {
    if (self.sectionsCount < 6) {
        NSLog(@"this update needs at least 6 sections");
        return;
    }
    
    if (self.cellsCount < 6) {
        NSLog(@"this update needs at least 6 rows in every section");
        return;
    }
    
    for (NSInteger i = 1, rows = [self.tableView numberOfRowsInSection:0]; i < self.tableView.numberOfSections; i++) {
        if (rows != [self.tableView numberOfRowsInSection:i]) {
            NSLog(@"need the same number of rows in every section");
            return;
        }
    }
    
    // step 1, delete section 0 and insert a section at 1.
    [self.tableView performBatchUpdates:^{
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationRandom];
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:MPTableViewRowAnimationRandom];
    } duration:1.5 delay:0 completion:nil];
    
    // step 2, start after step 1 is finished.
    [self.tableView performBatchUpdates:^{
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:MPTableViewRowAnimationRandom];
        [self.tableView moveSection:3 toSection:4];
    } duration:1.5 delay:1.5 completion:nil];
    
    // these animations start together with step 1, but their duration is 3 seconds.
    [self.tableView performBatchUpdates:^{
        [self.tableView deleteRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:0 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
        [self.tableView insertRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:1 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
        [self.tableView reloadRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:2 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
        [self.tableView moveRowAtIndexPath:[MPIndexPath indexPathForRow:3 inSection:5] toIndexPath:[MPIndexPath indexPathForRow:4 inSection:5]];
    } duration:3 delay:0 completion:^(BOOL finished) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"An update group is completed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }];
}

- (void)tableViewReload {
    self.cellsCount = 150;
    self.sectionsCount = 150;
    self.tableView.updateForceReload = NO;
    [self.tableView reloadDataAsyncWithCompletion:^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Data reload is completed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(tableViewUpdate) || action == @selector(tableViewDelete) || action == @selector(tableViewInsert) || action == @selector(tableViewReload)) {
        return YES;
    }
    return NO;
}

#pragma mark - dataSource

- (NSUInteger)numberOfSectionsInMPTableView:(MPTableView *)tableView {
    return self.sectionsCount;
}

- (CGFloat)MPTableView:(MPTableView *)tableView heightForHeaderInSection:(NSUInteger)section {
    return 20;
}

- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForHeaderInSection:(NSUInteger)section {
    MySectionView *sectionView = [tableView dequeueReusableViewWithIdentifier:@"MySectionView"];
    sectionView.label_title.text = [NSString stringWithFormat:@"section:%zd", section];
    return sectionView;
}

- (MPTableReusableView *)MPTableView:(MPTableView *)tableView viewForFooterInSection:(NSUInteger)section {
    MySectionView *sectionView = [tableView dequeueReusableViewWithIdentifier:@"MySectionView"];
    sectionView.label_title.text = [NSString stringWithFormat:@"...end...%zd", section];
    return sectionView;
}

- (NSUInteger)MPTableView:(MPTableView *)tableView numberOfRowsInSection:(NSUInteger)section {
    return self.cellsCount;
}

- (CGFloat)MPTableView:(MPTableView *)tableView heightForRowAtIndexPath:(MPIndexPath *)indexPath {
    // useless calculation, for simulating real project condition.
    CGSize labelSize = [@"Goliath online. Acknowledged HQ." boundingRectWithSize:CGSizeMake(375, 20) options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:15]} context:nil].size;
    labelSize.height = [@"Battlecruiser operational. Receiving transmission. Good day, commander." boundingRectWithSize:CGSizeMake(375, 20) options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:15]} context:nil].size.height;
    
    NSInteger temp = arc4random() % 30;
    
    return MPTableViewDefaultCellHeight + (temp - labelSize.height);
}

- (MPTableViewCell *)MPTableView:(MPTableView *)tableView cellForRowAtIndexPath:(MPIndexPath *)indexPath {
    MyDemoCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([MyDemoCell class])];
    cell.label_title.text = [NSString stringWithFormat:@"two one cell: %zd", indexPath.row];
    return cell;
}

- (CGRect)MPTableView:(MPTableView *)tableView rectForCellToMoveRowAtIndexPath:(MPIndexPath *)indexPath {
    MyDemoCell *cell = (MyDemoCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    return [cell rectForDrag];
}

#pragma mark - delegate

- (void)MPTableView:(MPTableView *)tableView willDisplayCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath {
    if ([indexPath compare:tableView.beginIndexPath] != NSOrderedDescending || [tableView isUpdating]) {
        return;
    }
    
    cell.transform = CGAffineTransformMakeScale(1.5, 1.5);
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        cell.transform = CGAffineTransformMakeScale(1.0, 1.0);
    } completion:nil];
}

- (void)MPTableView:(MPTableView *)tableView didSelectRowForCell:(MPTableViewCell *)cell atIndexPath:(MPIndexPath *)indexPath {
    [tableView scrollToHeaderInSection:indexPath.section atScrollPosition:MPTableViewScrollPositionTop animated:YES];
}

// like Teambition
// start dragging cell
- (void)MPTableView:(MPTableView *)tableView shouldMoveRowAtIndexPath:(MPIndexPath *)sourceIndexPath {
    MyDemoCell *cell = (MyDemoCell *)[tableView cellForRowAtIndexPath:sourceIndexPath];
    cell.layer.shadowColor = [UIColor blackColor].CGColor;
    cell.layer.shadowOpacity = 0.8;
    cell.layer.shadowRadius = 10;
    cell.btn_movement.highlighted = YES;
    
    [UIView animateWithDuration:0.25 animations:^{
        cell.transform = CGAffineTransformMakeRotation(M_PI / 180 * 8);
    }];
}

// stop dragging cell
- (void)MPTableView:(MPTableView *)tableView moveRowAtIndexPath:(MPIndexPath *)sourceIndexPath toIndexPath:(MPIndexPath *)destinationIndexPath {
    MPTableViewCell *cell = [tableView cellForRowAtIndexPath:destinationIndexPath];
    
    [UIView animateWithDuration:0.25 animations:^{
        cell.transform = CGAffineTransformMakeRotation(0);
        // if the tableView frame be changed when we are dragging this cell, the way that only reset this cell's transform still will make some layout problems, and we have to set a correct frame for it.
        cell.frame = [tableView rectForRowAtIndexPath:destinationIndexPath];
    }];
}

// cell is in position
- (void)MPTableView:(MPTableView *)tableView didEndMoveRowAtIndexPath:(MPIndexPath *)sourceIndexPath toIndexPath:(MPIndexPath *)destinationIndexPath {
    MyDemoCell *cell = (MyDemoCell *)[tableView cellForRowAtIndexPath:destinationIndexPath];
    cell.btn_movement.highlighted = NO;
    
    cell.layer.shadowColor = [UIColor clearColor].CGColor;
    cell.layer.shadowOpacity = 1;
    cell.layer.shadowRadius = 0;
}

#pragma mark - custom update animations

// delete
void _deleteAnimation(UIView *view) {
    [UIView animateWithDuration:1.5 animations:^{
        view.transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(-view.frame.size.width, view.frame.size.height), 0.5 * M_PI);
        view.alpha = 0;
    } completion:^(BOOL finished) {
        [view removeFromSuperview]; // necessary
    }];
}

- (void)MPTableView:(MPTableView *)tableView beginToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withLastDeletionOriginY:(CGFloat)lastDeletionOriginY {
    _deleteAnimation(cell);
}

- (void)MPTableView:(MPTableView *)tableView beginToDeleteHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastDeletionOriginY:(CGFloat)lastDeletionOriginY {
    _deleteAnimation(view);
}

- (void)MPTableView:(MPTableView *)tableView beginToDeleteFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastDeletionOriginY:(CGFloat)lastDeletionOriginY {
    _deleteAnimation(view);
}

// insert
void _insertAnimation(UIView *view, CGFloat lastInsertionOriginY) {
    CGRect frame = view.frame;
    
    view.transform = CGAffineTransformMakeScale(0.1, 0.1);
    CGRect newFrame = view.frame;
    newFrame.origin.y = lastInsertionOriginY;
    view.frame = newFrame;
    
    [UIView animateWithDuration:1.5 animations:^{
        view.transform = CGAffineTransformMakeScale(1.0, 1.0);
        view.frame = frame;
    }];
}

- (void)MPTableView:(MPTableView *)tableView beginToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withLastInsertionOriginY:(CGFloat)lastInsertionOriginY {
    _insertAnimation(cell, lastInsertionOriginY);
}

- (void)MPTableView:(MPTableView *)tableView beginToInsertHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastInsertionOriginY:(CGFloat)lastInsertionOriginY {
    _insertAnimation(view, lastInsertionOriginY);
}

- (void)MPTableView:(MPTableView *)tableView beginToInsertFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withLastInsertionOriginY:(CGFloat)lastInsertionOriginY {
    _insertAnimation(view, lastInsertionOriginY);
}

#pragma mark - prefetchDataSource

- (void)MPTableView:(MPTableView *)tableView prefetchRowsAtIndexPaths:(NSArray *)indexPaths {
    //NSLog(@"prefetch %@", indexPaths);
}

- (void)MPTableView:(MPTableView *)tableView cancelPrefetchingForRowsAtIndexPaths:(NSArray *)indexPaths {
    //NSLog(@"cancel prefetching %@", indexPaths);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
