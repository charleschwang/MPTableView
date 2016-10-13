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
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    [self.tableView registerClass:[MyDemoCell class] forCellReuseIdentifier:@"MyDemoCell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"MySectionView" bundle:nil] forReusableViewReuseIdentifier:@"MySectionView"];
    
    self.cellCount = 6;
    self.sectionCount = 6;
    self.tableView.sectionFooterHeight = 30; // set the property before set a dataSource
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.prefetchDataSource = self;
    
    self.tableView.moveModeEnabled = YES;
    self.tableView.allowsSelectionDuringMoving = YES;
    self.tableView.allowDragOutBounds = YES;
    
    UILabel *header = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 114, 114)];
    header.backgroundColor = [UIColor darkGrayColor];
    header.font = [UIFont systemFontOfSize:20];
    header.textAlignment = NSTextAlignmentCenter;
    header.text = @"Header";
    self.tableView.tableHeaderView = header;
    
    [self setupSubviews];
}

#pragma mark -

- (void)setupSubviews {
    UIButton *toolsBtn = [[UIButton alloc]initWithFrame:CGRectMake(20, 200, 70, 40)];
    toolsBtn.backgroundColor = [UIColor darkGrayColor];
    [toolsBtn setTitle:@"Menu" forState:UIControlStateNormal];
    [toolsBtn addTarget:self action:@selector(showMenuAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:toolsBtn];
}

- (void)showMenuAction:(UIButton *)sender {
    [self becomeFirstResponder];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setMenuItems:@[[[UIMenuItem alloc]initWithTitle:@"insert" action:@selector(tableViewInsert)],
                                   [[UIMenuItem alloc]initWithTitle:@"delete" action:@selector(tableViewDelete)],
                                   [[UIMenuItem alloc]initWithTitle:@"update" action:@selector(tableViewUpdate)],
                                   [[UIMenuItem alloc]initWithTitle:@"async reloadData" action:@selector(tableViewReload)]]];
    [menuController setTargetRect:CGRectMake(0, 0, 0, 0) inView:sender];
    [menuController setMenuVisible:YES animated:YES];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)tableViewDelete {
    --self.sectionCount;
    self.tableView.rowAnimationDuration = 1.5;
    [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationCustom];
    self.tableView.rowAnimationDuration = 0.25;
}

- (void)tableViewInsert {
    ++self.sectionCount;
    self.tableView.rowAnimationDuration = 1.5;
    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationCustom];
    self.tableView.rowAnimationDuration = 0.25;
}

- (void)tableViewUpdate {
    if (self.sectionCount < 6) {
        return;
    }
    [self.tableView beginUpdates];
    
    [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:MPTableViewRowAnimationRandom];
    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:MPTableViewRowAnimationRandom];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:MPTableViewRowAnimationRandom];
    [self.tableView moveSection:3 toSection:4];
    
    [self.tableView deleteRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:0 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
    [self.tableView insertRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:1 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
    [self.tableView reloadRowsAtIndexPaths:@[[MPIndexPath indexPathForRow:2 inSection:5]] withRowAnimation:MPTableViewRowAnimationRandom];
    [self.tableView moveRowAtIndexPath:[MPIndexPath indexPathForRow:3 inSection:5] toIndexPath:[MPIndexPath indexPathForRow:4 inSection:5]];
    
    [self.tableView endUpdates];
}

- (void)tableViewReload {
    self.cellCount = 150;
    self.sectionCount = 150;
    self.tableView.cachesReloadEnabled = YES;
    [self.tableView reloadDataAsyncWithCompletion:^{
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"提示" message:@"加载完毕" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    }];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(tableViewUpdate) || action == @selector(tableViewDelete) || action == @selector(tableViewInsert) || action == @selector(tableViewReload)) {
        return YES;
    }
    return NO;
}

#pragma mark -dataSource

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

#pragma mark -delegate

- (void)MPTableView:(MPTableView *)tableView willDisplayCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath {
    if ([indexPath compare:tableView.beginIndexPath] != NSOrderedDescending || [tableView isUpdating]) {
        return;
    }
    
    cell.transform = CGAffineTransformMakeScale(1.5, 1.5);
    [UIView animateWithDuration:0.5 animations:^{
        cell.transform = CGAffineTransformMakeScale(1.0, 1.0);
    }];
}

- (void)MPTableView:(MPTableView *)tableView didSelectCell:(MPTableViewCell *)cell atIndexPath:(MPIndexPath *)indexPath {
    // ...
}

#pragma mark -custom table view update

//...delete

void _deleteAnimation(UIView *view) {
    [UIView animateWithDuration:1.5 animations:^{
        view.transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(-view.frame.size.width, view.frame.size.height), 0.5 * M_PI);
        view.alpha = 0;
    } completion:^(BOOL finished) {
        [view removeFromSuperview];
    }];
}

- (void)MPTableView:(MPTableView *)tableView deleteCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition {
    _deleteAnimation(cell);
}

- (void)MPTableView:(MPTableView *)tableView deleteHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition {
    _deleteAnimation(view);
}

- (void)MPTableView:(MPTableView *)tableView deleteFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition {
    _deleteAnimation(view);
}

// ...insert
void _insertAnimation(UIView *view) {
    view.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    [UIView animateWithDuration:1.5 animations:^{
        view.transform = CGAffineTransformMakeScale(1.0, 1.0);
    }];
}

- (void)MPTableView:(MPTableView *)tableView insertCell:(MPTableViewCell *)cell forRowAtIndexPath:(MPIndexPath *)indexPath withAnimationPathPosition:(CGFloat)pathPosition {
    _insertAnimation(cell);
}

- (void)MPTableView:(MPTableView *)tableView insertHeaderView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition {
    _insertAnimation(view);
}

- (void)MPTableView:(MPTableView *)tableView insertFooterView:(MPTableReusableView *)view forSection:(NSUInteger)section withAnimationPathPosition:(CGFloat)pathPosition {
    _insertAnimation(view);
}

#pragma mark -prefetchDataSource
- (void)MPTableView:(MPTableView *)tableView prefetchRowsAtIndexPaths:(NSArray *)indexPaths {
    //NSLog(@"prefetch %@", indexPaths);
}

- (void)MPTableView:(MPTableView *)tableView cancelPrefetchingForRowsAtIndexPaths:(NSArray *)indexPaths {
    //NSLog(@"cancel prefetching %@", indexPaths);
}

- (void)MPTableView:(MPTableView *)tableView didScrollAndLayoutUpdatedWithDirection:(MPTableViewScrollDirection)direction withPreviousDirection:(MPTableViewScrollDirection)previousDirection {
    //NSLog(@"%@, %@", tableView.beginIndexPath, tableView.endIndexPath);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
