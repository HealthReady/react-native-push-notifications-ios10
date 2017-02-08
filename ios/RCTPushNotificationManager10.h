/**
 * Copyright 2016 One Degree Health
 *
 */

#import "RCTEventEmitter.h"
#import <UserNotifications/UserNotifications.h>

@interface RCTPushNotificationManager10 : RCTEventEmitter

+ (void)didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;
+ (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
+ (void)didReceiveRemoteNotification:(NSDictionary *)notification;
//+ (void)didReceiveLocalNotification:(UILocalNotification *)notification;
+ (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
+ (void)didReceiveLocalNotification:(UNNotification *)notification;
+ (void)didReceiveNotificationResponse:(UNNotificationResponse *)response;

@end
