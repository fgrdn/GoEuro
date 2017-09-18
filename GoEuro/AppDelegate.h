//
//  AppDelegate.h
//  GoEuro
//
//  Created by George Ulyanov on 07/09/2017.
//  Copyright © 2017 George Ulyanov. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum: NSInteger {
    kTravelType_Train = 0,
    kTravelType_Bus,
    kTravelType_Flight,
    
    kTravelType_Max
}
TravelType;

typedef enum: NSInteger {
    kSortType_Departure = 0,
    kSortType_Arrival,
    kSortType_Duration,
    
    kSortType_Max
}
SortType;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow * _Nonnull window;

- (NSArray * _Nullable)cached:(TravelType)type;
- (SortType)sortType:(TravelType)type;

- (NSString * _Nonnull)travelDirection;
- (NSDate * _Nonnull)travelDate;
- (void)travelList:(TravelType)type completion:(void(^ _Nonnull)(NSArray * _Nullable list, NSError * _Nullable error))completion;
- (void)travelList:(TravelType)type sortBy:(SortType)sort;

- (NSString * _Nonnull)localize:(NSString * _Nonnull)text;

@end

