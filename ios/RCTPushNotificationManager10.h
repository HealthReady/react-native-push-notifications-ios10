/**
 * Copyright 2016 One Degree Health
 *
 */

#import "RCTEventEmitter.h"
#import <UserNotifications/UserNotifications.h>
#define SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface RCTPushNotificationManager10 : RCTEventEmitter

+ (void)willPresentNotification:(UNNotification *)notification completionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler;
+ (void)didReceiveNotificationResponse:(UNNotificationResponse *)response completionHandler:(void (^)())completionhandler;
+ (void)didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;
+ (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
+ (void)didReceiveRemoteNotification:(NSDictionary *)notification;
+ (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
+ (void)didReceiveLocalNotification:(UILocalNotification *)notification;

@end
