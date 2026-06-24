#import <AudioToolbox/AudioToolbox.h>
#import "AXNView.h"
#import "AXNAppCell.h"
#import "AXNManager.h"

@implementation AXNView

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    self.badgesEnabled = YES;
    self.badgesShowBackground = YES;
    self.showingLatestRequest = NO;
    self.list = [NSMutableArray new];
    
    self.swipeUpAction = 0;
    self.swipeDownAction = 0;
    self.swipeLeftAction = 0;
    self.swipeRightAction = 0;

    self.collectionViewLayout = [[UICollectionViewFlowLayout alloc] init];
    self.collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    self.collectionView = [[UICollectionView alloc] initWithFrame:frame collectionViewLayout:self.collectionViewLayout];
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.backgroundColor = [UIColor clearColor];
    [self.collectionView registerClass:[AXNAppCell class] forCellWithReuseIdentifier:@"AppCell"];

    [self addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    self.panGesture.delegate = self;
    [self addGestureRecognizer:self.panGesture];

    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [gesture velocityInView:self];
        CGFloat verticalThreshold = 50;
        CGFloat horizontalThreshold = 50;
        
        BOOL isVertical = fabs(velocity.y) > fabs(velocity.x);
        
        if (isVertical) {
            if (velocity.y < -verticalThreshold) {
                [self performSwipeAction:self.swipeUpAction];
            } else if (velocity.y > verticalThreshold) {
                [self performSwipeAction:self.swipeDownAction];
            }
        } else {
            if (velocity.x < -horizontalThreshold) {
                [self performSwipeAction:self.swipeLeftAction];
            } else if (velocity.x > horizontalThreshold) {
                [self performSwipeAction:self.swipeRightAction];
            }
        }
    }
}

- (void)performSwipeAction:(NSInteger)action {
    switch (action) {
        case 1:
            [self clearAllNotifications];
            break;
        case 2:
            [self dismissNotificationCenter];
            break;
        case 3:
            [self clearSelectedAppNotifications];
            break;
        case 4:
            [self toggleNotificationHistory];
            break;
    }
}

- (void)clearAllNotifications {
    if (self.hapticFeedback) AudioServicesPlaySystemSound(1520);
    [[AXNManager sharedInstance] clearAll];
    [self refresh];
}

- (void)dismissNotificationCenter {
    if (self.hapticFeedback) AudioServicesPlaySystemSound(1519);
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(dismissNotificationCenter)]) {
        [app performSelector:@selector(dismissNotificationCenter)];
    }
}

- (void)clearSelectedAppNotifications {
    if (self.selectedBundleIdentifier && self.hapticFeedback) {
        AudioServicesPlaySystemSound(1520);
        [[AXNManager sharedInstance] clearAll:self.selectedBundleIdentifier];
        [self refresh];
    }
}

- (void)toggleNotificationHistory {
    if (self.hapticFeedback) AudioServicesPlaySystemSound(1519);
    [[AXNManager sharedInstance] revealNotificationHistory:![[AXNManager sharedInstance].view showingLatestRequest]];
}

- (void)viewDidLayoutSubviews {
  [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)setSpacing:(CGFloat)spacing {
    _spacing = spacing;
    self.collectionViewLayout.minimumLineSpacing = spacing;
    self.collectionViewLayout.minimumInteritemSpacing = spacing;
}

- (void)setAlignment:(NSInteger)alignment {
    if (alignment == _alignment) return;

    _alignment = alignment;
    if (_alignment > 2 || _alignment < 0) _alignment = 1;

    self.collectionView.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    if (alignment == 0) self.collectionView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    else if (alignment == 2) self.collectionView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

    [self.collectionView setNeedsLayout];
    [self.collectionView layoutIfNeeded];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (section == 0) return [self.list count];
    else return 0;
}

- (void)reset {
    if (self.showByDefault == 3) return;
    if (self.showByDefault == 2 && [self.list count] > 0 && [self.list[0][@"bundleIdentifier"] isEqualToString:self.selectedBundleIdentifier]) return;

    self.showingLatestRequest = NO;
    self.selectedBundleIdentifier = nil;
    if(self.showByDefault != 1) [[AXNManager sharedInstance] hideAllNotificationRequests];

    switch (self.showByDefault) {
        case 1:
            if ([AXNManager sharedInstance].latestRequest) {
                [[AXNManager sharedInstance] showNotificationRequest:[AXNManager sharedInstance].latestRequest];
                [[AXNManager sharedInstance] hideAllNotificationRequestsExcept:[AXNManager sharedInstance].latestRequest];
                self.showingLatestRequest = YES;
            } else [[AXNManager sharedInstance] hideAllNotificationRequests];
            break;
        case 2:
            if ([self.list count] > 0) {
                [self collectionView:self.collectionView didSelectItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            }
            return;
    }

    [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
    [[AXNManager sharedInstance] revealNotificationHistory:false];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AXNAppCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AppCell" forIndexPath:indexPath] ?: [[AXNAppCell alloc] initWithFrame:CGRectMake(0,0,64,64)];
    NSDictionary *dict = self.list[indexPath.row];
    cell.iconStyle = self.iconStyle;
    cell.darkMode = self.darkMode;
    cell.badgesShowBackground = self.badgesShowBackground;
    cell.bundleIdentifier = dict[@"bundleIdentifier"];
    cell.notificationCount = [dict[@"notificationCount"] intValue];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = self.selectionStyle;
    cell.addBlur = self.addBlur;
    cell.selected = [self.selectedBundleIdentifier isEqualToString:cell.bundleIdentifier];
    cell.style = self.style;

    if (cell.selected) {
        [collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    }

    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.hapticFeedback) AudioServicesPlaySystemSound(1519);
    AXNAppCell *cell = (AXNAppCell *)[collectionView cellForItemAtIndexPath:indexPath];
    if (cell.selected) {
        self.selectedBundleIdentifier = nil;
        [collectionView deselectItemAtIndexPath:indexPath animated:NO];
        [self collectionView:collectionView didDeselectItemAtIndexPath:indexPath];
        return NO;
    } else {
        return YES;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    AXNAppCell *cell = (AXNAppCell *)[collectionView cellForItemAtIndexPath:indexPath];

    if (![self.selectedBundleIdentifier isEqualToString:cell.bundleIdentifier]) {
        [[AXNManager sharedInstance] hideAllNotificationRequests];
    }
    self.selectedBundleIdentifier = cell.bundleIdentifier;

    [[AXNManager sharedInstance] showNotificationRequestsForBundleIdentifier:cell.bundleIdentifier];
    self.showingLatestRequest = NO;

    [[NSClassFromString(@"SBIdleTimerGlobalCoordinator") sharedInstance] resetIdleTimer];
    [[AXNManager sharedInstance] revealNotificationHistory:YES];

    if (self.collectionViewLayout.scrollDirection == UICollectionViewScrollDirectionVertical) {
        if([[AXNManager sharedInstance].clvc respondsToSelector:@selector(collectionView)]) [[[AXNManager sharedInstance].clvc collectionView] _scrollToTopIfPossible:YES];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    [[AXNManager sharedInstance] hideAllNotificationRequests];
    self.showingLatestRequest = NO;

    [[AXNManager sharedInstance] revealNotificationHistory:NO];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.badgesEnabled) {
        switch (self.style) {
            case 1: return CGSizeMake(64, 64);
            case 2: return CGSizeMake(48, 48);
            case 3: return CGSizeMake(40, 64);
            case 4: return CGSizeMake(60, 30);
            case 5: return CGSizeMake(60, 36);
            default: return CGSizeMake(64, 90);
        }
    } else if (!self.badgesEnabled) {
        switch (self.style) {
            case 1: return CGSizeMake(64, 64);
            case 2: return CGSizeMake(48, 48);
            case 3: return CGSizeMake(41, 41);
            case 4: return CGSizeMake(60, 30);
            case 5: return CGSizeMake(60, 36);
            default: return CGSizeMake(64, 6);
        }
    }
    return CGSizeMake(0, 0);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    if (self.alignment != 1) return UIEdgeInsetsMake(0, 0, 0, 0);

    CGFloat spacing = [(UICollectionViewFlowLayout *)collectionViewLayout minimumLineSpacing];
    CGFloat width = 64;
    CGFloat viewWidth = self.bounds.size.width;

    if (self.style == 2) width = 48;
    else if (self.style == 3) width = 40;

    if (self.collectionViewLayout.scrollDirection == UICollectionViewScrollDirectionVertical) {
        width = 90;
        if (self.style == 1 || self.style == 3) width = 64;
        else if (self.style == 2) width = 48;

        viewWidth = self.bounds.size.height;
    }

    NSInteger count = [self collectionView:collectionView numberOfItemsInSection:section];
    CGFloat totalCellWidth = width * count;
    CGFloat totalSpacingWidth = spacing * (count - 1);
    if (totalSpacingWidth < 0) totalSpacingWidth = 0;

    CGFloat leftInset = (viewWidth - (totalCellWidth + totalSpacingWidth)) / 2;
    if (leftInset < 0) {
        return [(UICollectionViewFlowLayout *)collectionViewLayout sectionInset];
    }
    CGFloat rightInset = leftInset;

    if (self.collectionViewLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal) {
        return UIEdgeInsetsMake(0, leftInset, 0, rightInset);
    } else {
        return UIEdgeInsetsMake(leftInset, 0, rightInset, 0);
    }
}

- (void)refresh {
    [self.list removeAllObjects];
    NSArray *sortedKeys = @[];

    switch (self.sortingMode) {
        case 1:
            sortedKeys = [[[AXNManager sharedInstance].notificationRequests allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                NSInteger first = [[AXNManager sharedInstance] countForBundleIdentifier:a];
                NSInteger second = [[AXNManager sharedInstance] countForBundleIdentifier:b];
                if (first < second) return (NSComparisonResult)NSOrderedDescending;
                if (first > second) return (NSComparisonResult)NSOrderedAscending;
                return (NSComparisonResult)NSOrderedSame;
            }];
            break;
        case 2:
            sortedKeys = [[[AXNManager sharedInstance].notificationRequests allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                NSString *first = [[AXNManager sharedInstance].names objectForKey:a];
                NSString *second = [[AXNManager sharedInstance].names objectForKey:b];
                return [first compare:second];
            }];
            break;
        default:
            sortedKeys = [[[AXNManager sharedInstance].notificationRequests allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                NSDate *first = [[AXNManager sharedInstance].timestamps objectForKey:a];
                NSDate *second = [[AXNManager sharedInstance].timestamps objectForKey:b];
                return [second compare:first] == NSOrderedDescending;
            }];
    }

    for (NSString *key in sortedKeys) {
        NSInteger count = [[AXNManager sharedInstance] countForBundleIdentifier:key];
        if (count == 0) continue;
        [self.list addObject:@{
            @"bundleIdentifier": key,
            @"notificationCount": @(count)
        }];
    }

    [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
    [[AXNManager sharedInstance].sbclvc _setListHasContent:([self.list count] > 0)];
}

-(void)setContentHost:(id)arg1 {}
-(void)setSizeToMimic:(CGSize)arg1 {}
-(void)_layoutContentHost {}
-(CGSize)sizeToMimic { return self.frame.size; }
-(id)contentHost { return nil; }
-(void)_updateSizeToMimic {}
-(unsigned long long)_optionsForMainOverlay { return 0; }

@end