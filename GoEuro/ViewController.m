//
//  ViewController.m
//  GoEuro
//
//  Created by George Ulyanov on 07/09/2017.
//  Copyright © 2017 George Ulyanov. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "UIView+Frame.h"
#import "Reachability.h"

@interface ImagesManager : NSObject

@property (strong, nonatomic) NSMutableDictionary<NSString *, UIImage *> *images;

+ (ImagesManager *)instance;

- (void)request:(NSString *)name completion:(void(^ _Nonnull)(UIImage *image))completion;

@end

@implementation ImagesManager

- (instancetype)init {
    self = [super init];
    self.images = NSMutableDictionary.dictionary;
    return self;
}

+ (ImagesManager *)instance {
    static ImagesManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[ImagesManager alloc] init];
    });
    return manager;
}

- (void)request:(NSString *)name completion:(void (^)(UIImage *))completion {
    __weak typeof(self) wself = self;
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(wself) sself = wself;
        if (sself) {
            if (sself.images[name]) {
                completion(sself.images[name]);
            } else {
                NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:name]];
                UIImage *bitmap = [[UIImage alloc] initWithData:data];
                if (bitmap) {
                    sself.images[name] = bitmap;
                }
                completion(bitmap);
            }
        }
    });
}

@end

//

@class TravelList;

@protocol TravelListDelegate <NSObject>

@required
- (void)needUpdateTravelList:(TravelList *)travelList completion:(void (^)(void))completion;

@end

@interface TravelList : NSObject <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (weak, nonatomic) id<TravelListDelegate> delegate;

@property (nonatomic) TravelType travelType;

@property (strong, nonatomic) UICollectionViewFlowLayout *layout;
@property (strong, nonatomic) UICollectionView *view;
@property (strong, nonatomic) UILabel *stub;
@property (strong, nonatomic) NSMutableDictionary<NSIndexPath *, UIView *> *content;

@end

@implementation TravelList

- (instancetype)initWithTravelType:(TravelType)type {
    self = [super init];
    self.travelType = type;

    self.layout = [[UICollectionViewFlowLayout alloc] init];
    self.layout.sectionInset = UIEdgeInsetsZero;
    self.layout.minimumLineSpacing = 1;
    self.layout.minimumInteritemSpacing = 1;
    
    self.view = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:self.layout];
    self.view.delegate = self;
    self.view.dataSource = self;
    [self.view registerClass:UICollectionViewCell.class forCellWithReuseIdentifier:@"cell"];
    
    self.stub = [[UILabel alloc] init];
    self.stub.frame = self.view.bounds;
    self.stub.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.stub.text = @"Data is unavailable at the moment.";
    self.stub.font = [UIFont systemFontOfSize:18];
    self.stub.textColor = UIColor.whiteColor;
    self.stub.backgroundColor = UIColor.clearColor;
    self.stub.userInteractionEnabled = NO;
    self.stub.textAlignment = NSTextAlignmentCenter;
    self.stub.contentMode = UIViewContentModeCenter;
    [self.view addSubview:self.stub];

    UIRefreshControl *refreshView = [[UIRefreshControl alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 10)];
    refreshView.backgroundColor = UIColor.clearColor;
    refreshView.tintColor = UIColor.whiteColor;
    [refreshView addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.view.refreshControl = refreshView;

    self.content = NSMutableDictionary.dictionary;
    
    return self;
}

- (void)reloadData {
    [self.content removeAllObjects];
    [self.view reloadData];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
    NSUInteger count = [appDelegate cached:self.travelType].count;
    self.stub.alpha = (count ? 0 : 1);
    return count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = UIColor.whiteColor;
    
    AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
    NSDictionary *travel = [appDelegate cached:self.travelType][indexPath.row];
    
    UIView *content = self.content[indexPath];
    BOOL animate = !content;
    if (!content) {
        content = [[UIView alloc] initWithFrame:cell.bounds];
        content.tag = 'CONT';
        self.content[indexPath] = content;
        
        UIImageView *image = [[UIImageView alloc] init];
        image.tag = 'IMAG';
        image.height = 24;
        [content addSubview:image];
        image.x = 5;
        image.y = 10;
        
        UILabel *time = [[UILabel alloc] init];
        time.tag = 'TIME';
        time.font = [UIFont systemFontOfSize:14 weight:.3];
        time.textColor = UIColor.lightGrayColor;
        [content addSubview:time];
        NSArray<NSString *> *departureTime = [travel[@"departure_time"] componentsSeparatedByString:@":"];
        NSArray<NSString *> *arrivalTime = [travel[@"arrival_time"] componentsSeparatedByString:@":"];
        time.text = [NSString stringWithFormat:@"%02d:%02d - %02d:%02d%@",
                     departureTime[0].intValue, departureTime[1].intValue,
                     arrivalTime[0].intValue, arrivalTime[1].intValue,
                     departureTime[0].intValue > arrivalTime[0].intValue ? @" (+1)" : @""];
        [time sizeToFit];
        time.x = 5;
        time.y = content.height - time.height - 10;
        
        UILabel *arrow = [[UILabel alloc] init];
        arrow.tag = 'ARRO';
        arrow.font = [UIFont systemFontOfSize:18];
        arrow.textColor = UIColor.lightGrayColor;
        [content addSubview:arrow];
        arrow.text = @">";
        [arrow sizeToFit];
        arrow.height = cell.height;
        arrow.x = cell.width - 5 - arrow.width;
        arrow.y = 0;

        UILabel *price = [[UILabel alloc] init];
        price.tag = 'PRIC';
        price.font = [UIFont systemFontOfSize:14 weight:.2];
        price.textColor = UIColor.blackColor;
        [content addSubview:price];
        NSString *composed = [NSString stringWithFormat:@"%@%.2f", @"€", ((NSNumber *)travel[@"price_in_euros"]).floatValue];
        NSRange pos = [composed rangeOfString:@"."];
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:composed];
        [string addAttribute:NSFontAttributeName
                       value:[UIFont systemFontOfSize:18 weight:.2]
                       range:NSMakeRange(0, pos.location)];
        price.attributedText = string;
        [price sizeToFit];
        price.x = arrow.x - 5 - price.width;
        price.y = 10;

        UILabel *lasts = [[UILabel alloc] init];
        lasts.tag = 'LAST';
        lasts.font = [UIFont systemFontOfSize:14];
        lasts.textColor = UIColor.lightGrayColor;
        [content addSubview:lasts];
        NSNumber *stops = travel[@"number_of_stops"];
        int h = arrivalTime[0].intValue - departureTime[0].intValue;
        if (arrivalTime[0].intValue < departureTime[0].intValue) {
            h = 24 - (departureTime[0].intValue - arrivalTime[0].intValue);
        }
        int m = arrivalTime[1].intValue - departureTime[1].intValue;
        if (arrivalTime[1].intValue < departureTime[1].intValue) {
            m = 60 - (departureTime[1].intValue - arrivalTime[1].intValue);
            h -= 1;
        }
        h += (int)(m / 60);
        m -= (60 * (int)(m / 60));
        lasts.text = [NSString stringWithFormat:@"%@  %02d:%02dh",
                      stops.intValue == 0 ? @"Direct" : [NSString stringWithFormat:@"%d stop%@", stops.intValue, stops.intValue > 1 ? @"s" : @""],
                      h, m];
        [lasts sizeToFit];
        lasts.x = arrow.x - 5 - lasts.width;
        lasts.y = content.height - lasts.height - 10;
        
    }
    if (content) {
        UIImageView *image = [content viewWithTag:'IMAG'];
        if (!image.image) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [ImagesManager.instance request:[travel[@"provider_logo"] stringByReplacingOccurrencesOfString:@"{size}" withString:@"63"] completion:^(UIImage *bitmap) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [image setImage:bitmap];
                        if (bitmap) {
                            image.width = bitmap.size.width * (image.height / bitmap.size.height);
                        }
                    });
                }];
            });
        }
    }
    [[cell viewWithTag:'CONT'] removeFromSuperview];
    [cell addSubview:content];
    if (animate) {
        [cell setTransform:CGAffineTransformMakeScale(0, 0)];
        [UIView animateWithDuration:.2 animations:^{
            [cell setTransform:CGAffineTransformMakeScale(1, 1)];
        }];
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(self.view.width, 70);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"Offer details are not yet implemented!" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:action];
    [appDelegate.window.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (IBAction)refresh:(UIRefreshControl *)refresher {
    if (self.delegate) {
        [self.delegate needUpdateTravelList:self completion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [refresher endRefreshing];
            });
        }];
    } else {
        [self reloadData];
    }
}

@end

//

@interface ViewController () <TravelListDelegate>

@property (strong, nonatomic) Reachability *reachability;
@property (nonatomic) NetworkStatus networkStatus;

@property (nonatomic) TravelType travelType;

@property (strong, nonatomic) NSMutableDictionary<NSNumber *, UIButton *> *switches;
@property (strong, nonatomic) UIView *selectorView;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, TravelList *> *lists;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
    
    _reachability = [Reachability reachabilityForInternetConnection];
    _networkStatus = [_reachability currentReachabilityStatus];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityDidChange:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];

    UILabel *direction = [[UILabel alloc] init];
    direction.tag = 'DIRE';
    direction.text = appDelegate.travelDirection;
    direction.textColor = UIColor.whiteColor;
    direction.textAlignment = NSTextAlignmentCenter;
    direction.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:direction];
    [direction sizeToFit];

    UILabel *date = [[UILabel alloc] init];
    date.tag = 'DATE';
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    [f setDateFormat:@"MMM dd"];
    date.text = [f stringFromDate:appDelegate.travelDate];
    date.textColor = UIColor.whiteColor;
    date.textAlignment = NSTextAlignmentCenter;
    date.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:date];
    [date sizeToFit];

    _switches = NSMutableDictionary.dictionary;
    void(^switchFabric)(TravelType, NSString *) = ^(TravelType type, NSString *title){
        UIButton *view = [UIButton buttonWithType:UIButtonTypeCustom];
        view.titleLabel.font = [UIFont systemFontOfSize:18];
        [view setTitle:title forState:UIControlStateNormal];
        [view setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [view addTarget:self action:@selector(switched:) forControlEvents:UIControlEventTouchDown];
        view.backgroundColor = UIColor.clearColor;
        view.tag = type;
        [self.view addSubview:view];
        self.switches[@(type)] = view;
    };
    switchFabric(kTravelType_Train, @"TRAIN");
    switchFabric(kTravelType_Bus, @"BUS");
    switchFabric(kTravelType_Flight, @"FLIGHT");

    _selectorView = [[UIView alloc] init];
    _selectorView.backgroundColor = UIColor.orangeColor;
    [self.view addSubview:_selectorView];
    
    _lists = NSMutableDictionary.dictionary;
    void(^listFabric)(TravelType) = ^(TravelType type){
        TravelList *list = [[TravelList alloc] initWithTravelType:type];
        list.delegate = self;
        list.view.backgroundColor = UIColor.clearColor;
        [self.view addSubview:list.view];
        self.lists[@(type)] = list;
    };
    listFabric(kTravelType_Train);
    listFabric(kTravelType_Bus);
    listFabric(kTravelType_Flight);
    
    UIButton *sort = [UIButton buttonWithType:UIButtonTypeCustom];
    sort.tag = 'SORT';
    sort.titleLabel.font = [UIFont systemFontOfSize:12];
    [sort setTitle:@"Sort" forState:UIControlStateNormal];
    [sort setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [sort addTarget:self action:@selector(sort:) forControlEvents:UIControlEventTouchDown];
    sort.backgroundColor = UIColor.clearColor;
    sort.contentVerticalAlignment = UIControlContentVerticalAlignmentBottom;
    sort.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [self.view addSubview:sort];
    
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"arrows.png"]];
    icon.tag = 'ICON';
    icon.userInteractionEnabled = NO;
    icon.backgroundColor = UIColor.clearColor;
    [sort addSubview:icon];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_reachability startNotifier];
    
    CGFloat y = 20;
    
    UIView *direction = [self.view viewWithTag:'DIRE'];
    direction.width = self.view.width;
    direction.x = 0;
    direction.y = y;
    y += direction.height + 5;

    UIView *date = [self.view viewWithTag:'DATE'];
    date.width = self.view.width;
    date.x = 0;
    date.y = y;
    y += date.height;

    CGFloat buttonsWidth = self.view.width / 3;
    CGFloat buttonsHeight = 60;
    UIButton *button = self.switches[@(kTravelType_Train)];
    [button sizeToFit];
    button.x = buttonsWidth * 0 + (buttonsWidth - button.width) / 2;
    button.y = y;
    button.height = buttonsHeight;
    button = self.switches[@(kTravelType_Bus)];
    [button sizeToFit];
    button.x = buttonsWidth * 1 + (buttonsWidth - button.width) / 2;
    button.y = y;
    button.height = buttonsHeight;
    button = self.switches[@(kTravelType_Flight)];
    [button sizeToFit];
    button.x = buttonsWidth * 2 + (buttonsWidth - button.width) / 2;
    button.y = y;
    button.height = buttonsHeight;
    y += buttonsHeight;

    self.selectorView.x = self.switches[@(kTravelType_Bus)].x;
    self.selectorView.y = y;
    self.selectorView.width = self.switches[@(kTravelType_Bus)].width;
    self.selectorView.height = 5;
    y += self.selectorView.height;

    [self.lists[@(kTravelType_Train)].view setFrame:CGRectMake(-self.view.width, y, self.view.width, self.view.height - y - 50)];
    [self.lists[@(kTravelType_Bus)].view setFrame:CGRectMake(0, y, self.view.width, self.view.height - y - 50)];
    [self.lists[@(kTravelType_Flight)].view setFrame:CGRectMake(self.view.width, y, self.view.width, self.view.height - y - 50)];
    y = self.view.height - 50;
    
    UIButton *sort = [self.view viewWithTag:'SORT'];
    sort.x = 20;
    sort.y = y + 5;
    sort.width = 50 - 10;
    sort.height = 50 - 10;
    UIImageView *icon = [sort viewWithTag:'ICON'];
    icon.width = sort.width - sort.titleLabel.font.capHeight - 10;
    icon.height = icon.width;
    icon.x = (sort.width - icon.width) / 2;
    icon.y = 0;
    
    self.travelType = kTravelType_Bus;
}

- (void)viewDidDisappear:(BOOL)animated {
    [_reachability stopNotifier];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}

- (void)setTravelType:(TravelType)travelType {
    AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
    [UIView animateWithDuration:.5 * abs((int)travelType - (int)_travelType) animations:^{
        self.lists[@(kTravelType_Train)].view.x = (self.view.width * (kTravelType_Train - travelType));
        self.lists[@(kTravelType_Bus)].view.x = (self.view.width * (kTravelType_Bus - travelType));
        self.lists[@(kTravelType_Flight)].view.x = (self.view.width * (kTravelType_Flight - travelType));
        
        self.selectorView.x = self.switches[@(travelType)].x;
        self.selectorView.width = self.switches[@(travelType)].width;
    }];
    _travelType = travelType;
    if (![appDelegate cached:travelType].count) {
        [self needUpdateTravelList:self.lists[@(travelType)] completion:nil];
    }
}

- (IBAction)switched:(UIButton *)sender {
    self.travelType = sender.tag;
}

- (IBAction)sort:(UIButton *)sender {
    AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
    SortType sortType = [appDelegate sortType:self.travelType];
    if (sortType == kSortType_Departure || sortType == kSortType_Duration) {
        [appDelegate travelList:self.travelType sortBy:kSortType_Arrival];
    } else {
        [appDelegate travelList:self.travelType sortBy:kSortType_Duration];
    }
    [self.lists[@(self.travelType)] reloadData];
}

- (void)needUpdateTravelList:(TravelList *)travelList completion:(void (^)(void))completion {
    AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
    [appDelegate travelList:travelList.travelType completion:^(NSArray *list, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [travelList reloadData];
            if (completion) {
                completion();
            }
        });
    }];
}

- (void)reachabilityDidChange:(NSNotification *)notification {
    NetworkStatus status = [self.reachability currentReachabilityStatus];
    if (status != NotReachable && self.networkStatus == NotReachable) {
        [self setTravelType:self.travelType];
    }
    self.networkStatus = status;
}

@end
