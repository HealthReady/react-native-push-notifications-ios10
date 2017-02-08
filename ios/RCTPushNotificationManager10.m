/**
 * Copyright 2016 One Degree Health
 *
 */

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import "RCTPushNotificationManager10.h"

#import "RCTBridge.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"
#import "RCTUtils.h"

NSString *const RCTLocalNotificationReceived10 = @"LocalNotificationReceived";
NSString *const RCTNotificationResponseReceived10 = @"NotificationResponseReceived";
NSString *const RCTRemoteNotificationReceived10 = @"RemoteNotificationReceived";
NSString *const RCTRemoteNotificationsRegistered10 = @"RemoteNotificationsRegistered";
NSString *const RCTRegisterUserNotificationSettings10 = @"RegisterUserNotificationSettings";

NSString *const RCTErrorUnableToRequestPermissions10 = @"E_UNABLE_TO_REQUEST_PERMISSIONS";
NSString *const RCTErrorRemoteNotificationRegistrationFailed10 = @"E_FAILED_TO_REGISTER_FOR_REMOTE_NOTIFICATIONS";

@implementation RCTConvert (UILocalNotification)

+ (UILocalNotification *)UILocalNotification:(id)json
{
  NSDictionary<NSString *, id> *details = [self NSDictionary:json];
  UILocalNotification *notification = [UILocalNotification new];
  notification.fireDate = [RCTConvert NSDate:details[@"fireDate"]] ?: [NSDate date];
  notification.alertBody = [RCTConvert NSString:details[@"alertBody"]];
  notification.alertAction = [RCTConvert NSString:details[@"alertAction"]];
  notification.soundName = [RCTConvert NSString:details[@"soundName"]] ?: UILocalNotificationDefaultSoundName;
  notification.userInfo = [RCTConvert NSDictionary:details[@"userInfo"]];
  notification.category = [RCTConvert NSString:details[@"category"]];
  if (details[@"applicationIconBadgeNumber"]) {
    notification.applicationIconBadgeNumber = [RCTConvert NSInteger:details[@"applicationIconBadgeNumber"]];
  }
  return notification;
}
@end

@implementation RCTConvert (UNNotificationContent)

+ (UNNotificationContent *)UNNotificationContent:(id)json
{
  NSError *error;
  NSDictionary<NSString *, id> *details = [self NSDictionary:json];
  UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
  content.title = [RCTConvert NSString:details[@"alertTitle"]];
  content.body = [RCTConvert NSString:details[@"alertBody"]];
  //content.sound = [RCTConvert NSString:details[@"soundName"]] ?: UILocalNotificationDefaultSoundName;
  UNNotificationAttachment *attachment;
  NSString *imageName = [RCTConvert NSString:details[@"imageName"]];
  // Used to get Documents folder path
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  NSString *imagePath = [NSString stringWithFormat:@"file://%@/images/%@", documentsDirectory, imageName];
  NSURL *imageURL = [NSURL URLWithString:imagePath];
  
  if ( [[NSFileManager defaultManager] isReadableFileAtPath:imageURL] ){
    NSString *tempImagePath = [NSString stringWithFormat:@"file://%@/images/temp_%@", documentsDirectory, imageName];
    NSURL *tempImageURL = [NSURL URLWithString:tempImagePath];
    [[NSFileManager defaultManager] copyItemAtURL:imageURL toURL:tempImageURL error:nil];
      attachment=[UNNotificationAttachment attachmentWithIdentifier:@"imageID"
                                                                URL: tempImageURL
                                                            options:nil
                                                              error:&error];
  }
  int count;
  NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/images", documentsDirectory] error:NULL];
  for (count = 0; count < (int)[directoryContent count]; count++)
  {
    NSLog(@"File %d: %@", (count + 1), [directoryContent objectAtIndex:count]);
  }
  
  if (attachment) {
    content.attachments=@[attachment];
    content.attachments = [NSArray arrayWithObject:attachment];
  }
  content.categoryIdentifier = [RCTConvert NSString:details[@"category"]];
  content.userInfo = [RCTConvert NSDictionary:details[@"userInfo"]];
  
  return content;
}
@end

@implementation RCTPushNotificationManager10
{
  RCTPromiseResolveBlock _requestPermissionsResolveBlock;
}

static NSDictionary *RCTFormatLocalNotification(UILocalNotification *notification)
{
  NSMutableDictionary *formattedLocalNotification = [NSMutableDictionary dictionary];
  if (notification.fireDate) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"];
    NSString *fireDateString = [formatter stringFromDate:notification.fireDate];
    formattedLocalNotification[@"fireDate"] = fireDateString;
  }
  formattedLocalNotification[@"alertAction"] = RCTNullIfNil(notification.alertAction);
  formattedLocalNotification[@"alertBody"] = RCTNullIfNil(notification.alertBody);
  formattedLocalNotification[@"applicationIconBadgeNumber"] = @(notification.applicationIconBadgeNumber);
  formattedLocalNotification[@"category"] = RCTNullIfNil(notification.category);
  formattedLocalNotification[@"soundName"] = RCTNullIfNil(notification.soundName);
  formattedLocalNotification[@"userInfo"] = RCTNullIfNil(RCTJSONClean(notification.userInfo));
  formattedLocalNotification[@"remote"] = @NO;
  return formattedLocalNotification;
}

static NSDictionary *RCTFormatNotificationResponse(UNNotificationResponse *response)
{
  NSMutableDictionary *formattedNotificationResponse = [NSMutableDictionary dictionary];
  formattedNotificationResponse[@"actionIdentifier"] = RCTNullIfNil(response.actionIdentifier);
  formattedNotificationResponse[@"userInfo"] = RCTNullIfNil(RCTJSONClean(response.notification.request.content.userInfo));
  formattedNotificationResponse[@"title"] = RCTNullIfNil(response.notification.request.content.title);
  formattedNotificationResponse[@"body"] = RCTNullIfNil(response.notification.request.content.body);
  return formattedNotificationResponse;
}

- (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)startObserving
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleLocalNotificationReceived:)
                                               name:RCTLocalNotificationReceived10
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleNotificationResponseReceived:)
                                               name:RCTNotificationResponseReceived10
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleRemoteNotificationReceived:)
                                               name:RCTRemoteNotificationReceived10
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleRemoteNotificationsRegistered:)
                                               name:RCTRemoteNotificationsRegistered10
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleRemoteNotificationRegistrationError:)
                                               name:RCTErrorRemoteNotificationRegistrationFailed10
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleRegisterUserNotificationSettings:)
                                               name:RCTRegisterUserNotificationSettings10
                                             object:nil];
}

- (void)stopObserving
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"localNotificationReceived",
           @"notificationResponseReceived",
           @"remoteNotificationReceived",
           @"remoteNotificationsRegistered",
           @"remoteNotificationRegistrationError"];
}

+ (void)didRegisterUserNotificationSettings:(__unused UIUserNotificationSettings *)notificationSettings
{
  if ([UIApplication instancesRespondToSelector:@selector(registerForRemoteNotifications)]) {
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    [[NSNotificationCenter defaultCenter] postNotificationName:RCTRegisterUserNotificationSettings10
                                                        object:self
                                                      userInfo:@{@"notificationSettings": notificationSettings}];
  }
}

+ (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
  NSMutableString *hexString = [NSMutableString string];
  NSUInteger deviceTokenLength = deviceToken.length;
  const unsigned char *bytes = deviceToken.bytes;
  for (NSUInteger i = 0; i < deviceTokenLength; i++) {
    [hexString appendFormat:@"%02x", bytes[i]];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTRemoteNotificationsRegistered10
                                                      object:self
                                                    userInfo:@{@"deviceToken" : [hexString copy]}];
}

+ (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTErrorRemoteNotificationRegistrationFailed10
                                                      object:self
                                                    userInfo:@{@"error": error}];
}

+ (void)didReceiveRemoteNotification:(NSDictionary *)notification
{
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTRemoteNotificationReceived10
                                                      object:self
                                                    userInfo:notification];
}

//+ (void)didReceiveLocalNotification:(UILocalNotification *)notification
//{
//  [[NSNotificationCenter defaultCenter] postNotificationName:RCTLocalNotificationReceived
//                                                      object:self
//                                                    userInfo:RCTFormatLocalNotification(notification)];
//}
//
//- (void)handleLocalNotificationReceived:(NSNotification *)notification
//{
//  [self sendEventWithName:@"localNotificationReceived" body:notification.userInfo];
//}

+ (void)didReceiveLocalNotification:(UNNotification *)notification
{
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTLocalNotificationReceived10
                                                      object:self
                                                    userInfo:notification];
}

- (void)handleLocalNotificationReceived:(UNNotification *)notification
{
  [self sendEventWithName:@"localNotificationReceived" body:notification.request.content.userInfo];
}

+ (void)didReceiveNotificationResponse:(UNNotificationResponse *)response
{
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTNotificationResponseReceived10
                                                      object:self
                                                    userInfo:RCTFormatNotificationResponse(response)];
}

- (void)handleNotificationResponseReceived:(NSNotification *)response
{
  NSLog(@"response %@", response);
  [self sendEventWithName:@"notificationResponseReceived" body:response.userInfo];
}

- (void)handleRemoteNotificationReceived:(NSNotification *)notification
{
  NSMutableDictionary *userInfo = [notification.userInfo mutableCopy];
  userInfo[@"remote"] = @YES;
  [self sendEventWithName:@"remoteNotificationReceived" body:userInfo];
}

- (void)handleRemoteNotificationsRegistered:(NSNotification *)notification
{
  [self sendEventWithName:@"remoteNotificationsRegistered" body:notification.userInfo];
}

- (void)handleRemoteNotificationRegistrationError:(NSNotification *)notification
{
  NSError *error = notification.userInfo[@"error"];
  NSDictionary *errorDetails = @{
    @"message": error.localizedDescription,
    @"code": @(error.code),
    @"details": error.userInfo,
  };
  [self sendEventWithName:@"remoteNotificationRegistrationError" body:errorDetails];
}

- (void)handleRegisterUserNotificationSettings:(NSNotification *)notification
{
  if (_requestPermissionsResolveBlock == nil) {
    return;
  }

  UIUserNotificationSettings *notificationSettings = notification.userInfo[@"notificationSettings"];
  NSDictionary *notificationTypes = @{
    @"alert": @((notificationSettings.types & UIUserNotificationTypeAlert) > 0),
    @"sound": @((notificationSettings.types & UIUserNotificationTypeSound) > 0),
    @"badge": @((notificationSettings.types & UIUserNotificationTypeBadge) > 0),
  };

  _requestPermissionsResolveBlock(notificationTypes);
  _requestPermissionsResolveBlock = nil;
}

/**
 * Update the application icon badge number on the home screen
 */
RCT_EXPORT_METHOD(setApplicationIconBadgeNumber:(NSInteger)number)
{
  RCTSharedApplication().applicationIconBadgeNumber = number;
}

/**
 * Get the current application icon badge number on the home screen
 */
RCT_EXPORT_METHOD(getApplicationIconBadgeNumber:(RCTResponseSenderBlock)callback)
{
  callback(@[@(RCTSharedApplication().applicationIconBadgeNumber)]);
}

RCT_EXPORT_METHOD(requestPermissions:(NSDictionary *)permissions
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (RCTRunningInAppExtension()) {
    reject(RCTErrorUnableToRequestPermissions10, nil, RCTErrorWithMessage(@"Requesting push notifications is currently unavailable in an app extension"));
    return;
  }

  if (_requestPermissionsResolveBlock != nil) {
    RCTLogError(@"Cannot call requestPermissions twice before the first has returned.");
    return;
  }

  _requestPermissionsResolveBlock = resolve;

  UIUserNotificationType types = UIUserNotificationTypeNone;
  if (permissions) {
    if ([RCTConvert BOOL:permissions[@"alert"]]) {
      types |= UIUserNotificationTypeAlert;
    }
    if ([RCTConvert BOOL:permissions[@"badge"]]) {
      types |= UIUserNotificationTypeBadge;
    }
    if ([RCTConvert BOOL:permissions[@"sound"]]) {
      types |= UIUserNotificationTypeSound;
    }
  } else {
    types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
  }

  UIApplication *app = RCTSharedApplication();
  if ([app respondsToSelector:@selector(registerUserNotificationSettings:)]) {
    UIUserNotificationSettings *notificationSettings =
      [UIUserNotificationSettings settingsForTypes:(NSUInteger)types categories:nil];
    [app registerUserNotificationSettings:notificationSettings];
  } else {
    [app registerForRemoteNotificationTypes:(NSUInteger)types];
  }
}

RCT_EXPORT_METHOD(abandonPermissions)
{
  [RCTSharedApplication() unregisterForRemoteNotifications];
}

RCT_EXPORT_METHOD(checkPermissions:(RCTResponseSenderBlock)callback)
{
  if (RCTRunningInAppExtension()) {
    callback(@[@{@"alert": @NO, @"badge": @NO, @"sound": @NO}]);
    return;
  }

  NSUInteger types = [RCTSharedApplication() currentUserNotificationSettings].types;
  callback(@[@{
    @"alert": @((types & UIUserNotificationTypeAlert) > 0),
    @"badge": @((types & UIUserNotificationTypeBadge) > 0),
    @"sound": @((types & UIUserNotificationTypeSound) > 0),
  }]);
}

RCT_EXPORT_METHOD(presentLocalNotification:(UILocalNotification *)notification)
{
  [RCTSharedApplication() presentLocalNotificationNow:notification];
}

RCT_EXPORT_METHOD(scheduleLocalNotification:(UNNotificationContent *)notification fireDate:(nonnull NSNumber *)fireDate)
{
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  NSError *error = nil;
  NSString *identifier = @"UYLLocalNotification";
  NSTimeInterval seconds = [fireDate doubleValue];
  NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:seconds];
  NSDateComponents *triggerDate = [[NSCalendar currentCalendar]
                                   components:NSCalendarUnitYear +
                                   NSCalendarUnitMonth + NSCalendarUnitDay +
                                   NSCalendarUnitHour + NSCalendarUnitMinute +
                                   NSCalendarUnitSecond fromDate:date];
  
  UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents: triggerDate
                                                                                                    repeats:NO];
  UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                        content:notification trigger:trigger];
  [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
    if (error != nil) {
      NSLog(@"Something went wrong: %@",error);
    }else{
      //NSLog(@"Notification scheduled %@", notification);
      NSLog(@"Notification scheduled");
    }
  }];
  
//  [RCTSharedApplication() scheduleLocalNotification:notification];
}

RCT_EXPORT_METHOD(cancelAllLocalNotifications)
{
  [RCTSharedApplication() cancelAllLocalNotifications];
}

RCT_EXPORT_METHOD(cancelLocalNotifications:(NSDictionary<NSString *, id> *)userInfo)
{
  for (UILocalNotification *notification in [UIApplication sharedApplication].scheduledLocalNotifications) {
    __block BOOL matchesAll = YES;
    NSDictionary<NSString *, id> *notificationInfo = notification.userInfo;
    // Note: we do this with a loop instead of just `isEqualToDictionary:`
    // because we only require that all specified userInfo values match the
    // notificationInfo values - notificationInfo may contain additional values
    // which we don't care about.
    [userInfo enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
      if (![notificationInfo[key] isEqual:obj]) {
        matchesAll = NO;
        *stop = YES;
      }
    }];
    if (matchesAll) {
      [[UIApplication sharedApplication] cancelLocalNotification:notification];
    }
  }
}

RCT_EXPORT_METHOD(getInitialNotification:(RCTPromiseResolveBlock)resolve
                  reject:(__unused RCTPromiseRejectBlock)reject)
{
  NSMutableDictionary<NSString *, id> *initialNotification =
    [self.bridge.launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] mutableCopy];

  UILocalNotification *initialLocalNotification =
    self.bridge.launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];

  if (initialNotification) {
    initialNotification[@"remote"] = @YES;
    resolve(initialNotification);
  } else if (initialLocalNotification) {
    resolve(RCTFormatLocalNotification(initialLocalNotification));
  } else {
    resolve((id)kCFNull);
  }
}

RCT_EXPORT_METHOD(getScheduledLocalNotifications:(RCTResponseSenderBlock)callback)
{
  NSArray<UILocalNotification *> *scheduledLocalNotifications = [UIApplication sharedApplication].scheduledLocalNotifications;
  NSMutableArray<NSDictionary *> *formattedScheduledLocalNotifications = [NSMutableArray new];
  for (UILocalNotification *notification in scheduledLocalNotifications) {
    [formattedScheduledLocalNotifications addObject:RCTFormatLocalNotification(notification)];
  }
  callback(@[formattedScheduledLocalNotifications]);
}

@end
