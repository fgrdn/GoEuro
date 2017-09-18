//
//  AppDelegate.m
//  GoEuro
//
//  Created by George Ulyanov on 07/09/2017.
//  Copyright © 2017 George Ulyanov. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSMutableArray *> *cached;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSNumber *> *sortType;

@end

@implementation AppDelegate

- (NSMutableDictionary<NSNumber *, NSMutableArray *> *)cached {
    NSMutableDictionary *r;
    @synchronized (_cached) {
        r = _cached;
    }
    return r;
}

- (NSMutableDictionary<NSNumber *,NSNumber *> *)sortType {
    NSMutableDictionary *r;
    @synchronized (_sortType) {
        r = _sortType;
    }
    return r;
}

- (NSArray * _Nullable)cached:(TravelType)type {
    return self.cached[@(type)];
}

- (SortType)sortType:(TravelType)type {
    return (SortType)self.sortType[@(type)].intValue;
}

- (NSString *)travelDirection {
    // TODO: hardcoded
    return [self localize:@"Berlin - Munich"];
}

- (NSDate *)travelDate {
    // TODO: let user choose
    return NSDate.date;
}

- (void)travelList:(TravelType)type completion:(void (^)(NSArray *, NSError *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //
        NSURLSessionConfiguration *sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
        NSString *url;
        if (type == kTravelType_Train) {
            url = @"https://api.myjson.com/bins/3zmcy";
        } else if (type == kTravelType_Bus) {
            url = @"https://api.myjson.com/bins/37yzm";
        } else if (type == kTravelType_Flight) {
            url = @"https://api.myjson.com/bins/w60i";
        }
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        request.HTTPMethod = @"GET";
        __weak typeof(self) wself = self;
        NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            //
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            if (!error) {
                NSError *dataError;
                NSMutableArray *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&dataError];
                if (json) {
                    sself.cached[@(type)] = json;
                    [sself travelList:type sortBy:kSortType_Departure];
                    sself.sortType[@(type)] = @(kSortType_Departure);
                    completion(json, dataError);
                } else {
                    completion(sself.cached[@(type)], dataError);
                }
            } else {
                completion(sself.cached[@(type)], error);
            }
            //
        }];
        [postDataTask resume];
        //
    });
}

- (void)travelList:(TravelType)type sortBy:(SortType)sort {
    self.sortType[@(type)] = @(sort);
    NSMutableArray *travel = self.cached[@(type)];
    if (travel) {
        if (sort == kSortType_Departure) {
            self.cached[@(type)] = [travel sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                NSString *timeA = [a[@"departure_time"] stringByReplacingOccurrencesOfString:@":" withString:@"."];
                NSString *timeB = [b[@"departure_time"] stringByReplacingOccurrencesOfString:@":" withString:@"."];
                return timeA.floatValue > timeB.floatValue;
            }].mutableCopy;
        } else if (sort == kSortType_Arrival) {
            self.cached[@(type)] = [travel sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                NSString *timeA = [a[@"arrival_time"] stringByReplacingOccurrencesOfString:@":" withString:@"."];
                NSString *timeB = [b[@"arrival_time"] stringByReplacingOccurrencesOfString:@":" withString:@"."];
                return timeA.floatValue > timeB.floatValue;
            }].mutableCopy;
        } else if (sort == kSortType_Duration) {
            NSString *(^routine)(NSArray<NSString *> *, NSArray<NSString *> *) = ^(NSArray<NSString *> *departureTime, NSArray<NSString *> *arrivalTime) {
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
                return [NSString stringWithFormat:@"%d:%02d", h, m];
            };
            self.cached[@(type)] = [travel sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                NSString *durationA = [routine([a[@"departure_time"] componentsSeparatedByString:@":"], [a[@"arrival_time"] componentsSeparatedByString:@":"]) stringByReplacingOccurrencesOfString:@":" withString:@"."];
                NSString *durationB = [routine([b[@"departure_time"] componentsSeparatedByString:@":"], [b[@"arrival_time"] componentsSeparatedByString:@":"]) stringByReplacingOccurrencesOfString:@":" withString:@"."];
                return durationA.floatValue > durationB.floatValue;
            }].mutableCopy;
        }
    }
}

- (NSString *)localize:(NSString *)text {
    // TODO: localization mechanism
    return text.copy;
}

+ (NSString *)cachesDirectory {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        path = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    });
    return path;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.cached = NSMutableDictionary.dictionary;
    self.cached[@(kTravelType_Train)] = [NSArray arrayWithContentsOfFile:[AppDelegate.cachesDirectory stringByAppendingPathComponent:@"train.plist"]].mutableCopy;
    self.cached[@(kTravelType_Bus)] = [NSArray arrayWithContentsOfFile:[AppDelegate.cachesDirectory stringByAppendingPathComponent:@"bus.plist"]].mutableCopy;
    self.cached[@(kTravelType_Flight)] = [NSArray arrayWithContentsOfFile:[AppDelegate.cachesDirectory stringByAppendingPathComponent:@"flight.plist"]].mutableCopy;
    self.sortType = NSMutableDictionary.dictionary;
    self.sortType[@(kTravelType_Train)] = @(kSortType_Departure);
    self.sortType[@(kTravelType_Bus)] = @(kSortType_Departure);
    self.sortType[@(kTravelType_Flight)] = @(kSortType_Departure);
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self.cached[@(kTravelType_Train)] writeToFile:[AppDelegate.cachesDirectory stringByAppendingPathComponent:@"train.plist"] atomically:NO];
    [self.cached[@(kTravelType_Bus)] writeToFile:[AppDelegate.cachesDirectory stringByAppendingPathComponent:@"bus.plist"] atomically:NO];
    [self.cached[@(kTravelType_Flight)] writeToFile:[AppDelegate.cachesDirectory stringByAppendingPathComponent:@"flight.plist"] atomically:NO];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
