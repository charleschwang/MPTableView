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
@property (nonatomic, assign) NSInteger sectionCount;
@property (nonatomic, assign) NSInteger cellCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"title";
    
    self.tableView = [[MPTableView alloc] initWithFrame:(CGRect){0, 0, self.view.frame.size.width, self.view.frame.size.height} style:MPTableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.prefetchDataSource = self;
    
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    [self.tableView registerClass:[MyDemoCell class] forCellReuseIdentifier:@"MyDemoCell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"MySectionView" bundle:nil] forReusableViewReuseIdentifier:@"MySectionView"];
    
    self.cellCount = 6;
    self.sectionCount = 6;
    self.tableView.sectionFooterHeight = 30;
    
    self.tableView.moveModeEnabled = YES;
    self.tableView.allowsSelectionDuringMoving = YES;
    self.tableView.allowsDragCellOut = YES;
    
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
    --self.sectionCount;
    // set the default animation duration of cells equals to those customizations
    [self.tableView performBatchUpdates:^{
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationCustom];
    } duration:1.5 delay:0 options:UIViewAnimationOptionCurveEaseOut completion:nil];
}

- (void)tableViewInsert {
    ++self.sectionCount;
    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationCustom];
}

- (void)tableViewUpdate {
    if (self.sectionCount < 6) {
        return;
    }
    [self.tableView performBatchUpdates:^{
        // step 1, delete section 0 and insert a section at 1
        [self.tableView performBatchUpdates:^{
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationRandom];
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:MPTableViewRowAnimationRandom];
        } duration:1.5 delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
        
        // step 2, start after step 1 is finished
        [self.tableView performBatchUpdates:^{
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:MPTableViewRowAnimationRandom];
            [self.tableView moveSection:3 toSection:4];
        } duration:1.5 delay:1.5 options:UIViewAnimationOptionCurveEaseInOut completion:nil];
        
        // start together with step 1, but these animations duration is 3
        [self.tableView deleteRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:0 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
        [self.tableView insertRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:1 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
        [self.tableView reloadRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:2 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
        [self.tableView moveRowAtIndexPath:[MPIndexPath indexPathForRow:3 inSection:5] toIndexPath:[MPIndexPath indexPathForRow:4 inSection:5]];
    } duration:3 delay:0 options:UIViewAnimationOptionCurveEaseInOut completion:^(BOOL finished) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"一组updates完成" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    }];
}

- (void)tableViewReload {
    self.cellCount = 150;
    self.sectionCount = 150;
    [self.tableView reloadDataAsyncWithCompletion:^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"加载完毕" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
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
    return self.sectionCount;
}

- (CGFloat)MPTableView:(MPTableView *)tableView estimatedHeightForHeaderInSection:(NSUInteger)section {
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
    return self.cellCount;
}

- (CGFloat)MPTableView:(MPTableView *)tableView heightForIndexPath:(MPIndexPath *)indexPath {
    // useless calculation,
    CGSize labelSize = [@"Goliath online. Acknowledged HQ." boundingRectWithSize:CGSizeMake(tableView.frame.size.width, 20) options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:15]} context:nil].size;
    labelSize = [@"Battlecruiser operational. Receiving transmission. Good day, commander." boundingRectWithSize:CGSizeMake(tableView.frame.size.width, 20) options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:15]} context:nil].size;
    
    NSInteger temp = arc4random() % 20;
    
    return MPTableViewDefaultCellHeight + (temp - 10);
}

- (MPTableViewCell *)MPTableView:(MPTableView *)tableView cellForRowAtIndexPath:(MPIndexPath *)indexPath {
    MyDemoCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([MyDemoCell class])];
    cell.label_title.text = [NSString stringWithFormat:@"two one cell: %zd", indexPath.row];
    return cell;
}

- (CGRect)MPTableView:(MPTableView *)tableView rectForCellToMoveRowAtIndexPath:(MPIndexPath *)indexPath {
    MyDemoCell *cell = (MyDemoCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    return [cell rectForMoving];
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

- (void)MPTableView:(MPTableView *)tableView didSelectCell:(MPTableViewCell *)cell atIndexPath:(MPIndexPath *)indexPath {
    [tableView scrollToHeaderAtSection:indexPath.section atScrollPosition:MPTableViewScrollPositionTop animated:YES];
}

// like Teambition
// start moving
- (void)MPTableView:(MPTableView *)tableView shouldMoveRowAtIndexPath:(MPIndexPath *)sourceIndexPath {
    MPTableViewCell *cell = [tableView cellForRowAtIndexPath:sourceIndexPath];
    cell.layer.shadowColor = [UIColor blackColor].CGColor;
    cell.layer.shadowOpacity = 0.8;
    cell.layer.shadowRadius = 10;
    
    [UIView animateWithDuration:0.25 animations:^{
        cell.transform = CGAffineTransformMakeRotation(M_PI / 180 * 8);
    }];
}

// stop dragging
- (void)MPTableView:(MPTableView *)tableView moveRowAtIndexPath:(MPIndexPath *)sourceIndexPath toIndexPath:(MPIndexPath *)destinationIndexPath {
    MPTableViewCell *cell = [tableView cellForRowAtIndexPath:destinationIndexPath];
    
    [UIView animateWithDuration:0.25 animations:^{
        cell.transform = CGAffineTransformMakeRotation(0);
        // if the tableview frame be changed when we are dragging this cell, the way that only reset this cell's transform still will make some layout problems, and we have to set a correct frame for it.
        cell.frame = [tableView rectForRowAtIndexPath:destinationIndexPath];
    }];
}

// cell is in position
- (void)MPTableView:(MPTableView *)tableView didEndMoveRowAtIndexPath:(MPIndexPath *)sourceIndexPath toIndexPath:(MPIndexPath *)destinationIndexPath {
    MPTableViewCell *cell = [tableView cellForRowAtIndexPath:destinationIndexPath];
    cell.layer.shadowColor = [UIColor clearColor].CGColor;
    cell.layer.shadowOpacity = 1;
    cell.layer.shadowRadius = 0;
}

#pragma mark - table view update custom

//...delete

void _deleteAnimation(UIView *view) {
    [UIView animateWithDuration:1.5 animations:^{
        view.transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(-view.frame.size.width, view.frame.size.height), 0.5 * M_PI);
        view.alpha = 0;
    } completion:^(BOOL finished) {
        [view removeFromSuperview];
    }];
}

- (void)MPTableView:(MPTableView *)tableView beginToDeleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition {
    _deleteAnimation(cell);
}

- (void)MPTableView:(MPTableView *)tableView beginToDeleteHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition {
    _deleteAnimation(view);
}

- (void)MPTableView:(MPTableView *)tableView beginToDeleteFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition {
    _deleteAnimation(view);
}

// ...insert
void _insertAnimation(UIView *view) {
    view.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    [UIView animateWithDuration:1.5 animations:^{
        view.transform = CGAffineTransformMakeScale(1.0, 1.0);
    }];
}

- (void)MPTableView:(MPTableView *)tableView beginToInsertCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition {
    _insertAnimation(cell);
}

- (void)MPTableView:(MPTableView *)tableView beginToInsertHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition {
    _insertAnimation(view);
}

- (void)MPTableView:(MPTableView *)tableView beginToInsertFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition {
    _insertAnimation(view);
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
