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

@implementation RCTConvert (UNNotificationRequest)

+ (UNNotificationRequest *)UNNotificationRequest:(id)json
{
  NSError *error;
  NSDictionary<NSString *, id> *details = [self NSDictionary:json];
  UNMutableNotificationContent *content = [UNMutableNotificationContent new];
  content.title = [RCTConvert NSString:details[@"alertTitle"]];
  content.body = [RCTConvert NSString:details[@"alertBody"]];
  content.sound = [UNNotificationSound soundNamed:[RCTConvert NSString:details[@"soundName"]]] ?: [UNNotificationSound defaultSound];
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
  if (attachment) {
    content.attachments=@[attachment];
    content.attachments = [NSArray arrayWithObject:attachment];
  }
  content.categoryIdentifier = [RCTConvert NSString:details[@"category"]];
  content.userInfo = [RCTConvert NSDictionary:details[@"userInfo"]];
  NSString *identifier = [RCTConvert NSString:content.userInfo[@"id"]];
  NSDateComponents *triggerDate = [[NSCalendar currentCalendar]
                                   components:NSCalendarUnitYear +
                                   NSCalendarUnitMonth + NSCalendarUnitDay +
                                   NSCalendarUnitHour + NSCalendarUnitMinute +
                                   NSCalendarUnitSecond fromDate:[RCTConvert NSDate:details[@"fireDate"]]];
  UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:triggerDate repeats:NO];
  UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
  return request;
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

static NSDictionary *RCTFormatNotificationRequest(UNNotificationRequest *request)
{
  NSMutableDictionary *formattedNotificationRequest = [NSMutableDictionary dictionary];
  if (request.trigger) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"];
    if ([request.trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]]){
      UNTimeIntervalNotificationTrigger *trigger = (UNTimeIntervalNotificationTrigger *)request.trigger;
      formattedNotificationRequest[@"fireDate"] = [formatter stringFromDate:[trigger nextTriggerDate]];
    } else if ([request.trigger isKindOfClass:[UNCalendarNotificationTrigger class]]){
      UNCalendarNotificationTrigger *trigger = (UNCalendarNotificationTrigger *)request.trigger;
      formattedNotificationRequest[@"fireDate"] = [formatter stringFromDate:[trigger nextTriggerDate]];
    } else if ([request.trigger isKindOfClass:[UNLocationNotificationTrigger class]]){
      UNLocationNotificationTrigger *trigger = (UNLocationNotificationTrigger *)request.trigger;
      formattedNotificationRequest[@"fireDate"] = @"UNLocationNotificationTrigger";
    } else if ([request.trigger isKindOfClass:[UNPushNotificationTrigger class]]){
      UNPushNotificationTrigger *trigger = (UNPushNotificationTrigger *)request.trigger;
      formattedNotificationRequest[@"fireDate"] = @"UNPushNotificationTrigger";
    }
  }
  if (request.content){
    formattedNotificationRequest[@"alertTitle"] = RCTNullIfNil(request.content.title);
    formattedNotificationRequest[@"alertSubtitle"] = RCTNullIfNil(request.content.subtitle);
    formattedNotificationRequest[@"alertBody"] = RCTNullIfNil(request.content.body);
    formattedNotificationRequest[@"applicationIconBadgeNumber"] = request.content.badge;
    if (request.content.sound){
      UNNotificationSound *sound = request.content.sound;
      formattedNotificationRequest[@"soundName"] = RCTNullIfNil([sound valueForKey:@"toneFileName"]);
    }
    formattedNotificationRequest[@"launchImageName"] = request.content.launchImageName;
    formattedNotificationRequest[@"userInfo"] = RCTNullIfNil(RCTJSONClean(request.content.userInfo));
    formattedNotificationRequest[@"attachments"] = request.content.attachments;
    formattedNotificationRequest[@"category"] = RCTNullIfNil(request.content.categoryIdentifier);
  }
  formattedNotificationRequest[@"identifier"] = request.identifier;
  formattedNotificationRequest[@"remote"] = @NO;
  return formattedNotificationRequest;
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

+ (void)willPresentNotification:(UNNotification *)notification completionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
  UIImage *attachmentImage = nil;
  UNNotificationAttachment *attachment = notification.request.content.attachments.firstObject;
  if (attachment) {
    if ([attachment.URL startAccessingSecurityScopedResource]){
      attachmentImage = [UIImage imageWithContentsOfFile:attachment.URL.path];
      [attachment.URL stopAccessingSecurityScopedResource];
    }
  }
  completionHandler(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge);
}

+ (void)didReceiveNotificationResponse:(UNNotificationResponse *)response completionHandler:(void (^)())completionHandler
{
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTNotificationResponseReceived10
                                                      object:self
                                                    userInfo:RCTFormatNotificationResponse(response)];
  completionHandler();
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

+ (void)didReceiveLocalNotification:(UILocalNotification *)notification
{
  [[NSNotificationCenter defaultCenter] postNotificationName:RCTLocalNotificationReceived10
                                                      object:self
                                                    userInfo:RCTFormatLocalNotification(notification)];
}

- (void)handleLocalNotificationReceived:(NSNotification *)notification
{
  [self sendEventWithName:@"localNotificationReceived" body:notification.userInfo];
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
  NSDictionary *notificationTypes;
  UIUserNotificationSettings *notificationSettings = notification.userInfo[@"notificationSettings"];
  notificationTypes = @{
                        @"alert": @((notificationSettings.types & UIUserNotificationTypeAlert) > 0),
                        @"sound": @((notificationSettings.types & UIUserNotificationTypeSound) > 0),
                        @"badge": @((notificationSettings.types & UIUserNotificationTypeBadge) > 0),
                        };
  _requestPermissionsResolveBlock(notificationTypes);
  _requestPermissionsResolveBlock = nil;
}

/**
 * Add categories to UNUserNotificationCenter
 */
RCT_EXPORT_METHOD(setNotificationCategories:(NSArray *)categories:(RCTPromiseResolveBlock)resolve
                  reject:(__unused RCTPromiseRejectBlock)reject)
{
  if(SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(@"10.0")) {
    NSError *error;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    NSArray *newCategories = [NSArray array];
    for (id category in categories) {
      NSArray *newCategoryIntentIdentifiers = [NSArray array];
      NSArray *newActions = [NSArray array];
      UNNotificationCategoryOptions *categoryOption = UNNotificationCategoryOptionNone;
      if ([category[@"options"] isEqualToString:@"customDismissAction"]) {
        categoryOption = UNNotificationCategoryOptionCustomDismissAction;
      } else if ([category[@"options"] isEqualToString:@"allowInCarPlay"]) {
        categoryOption = UNNotificationCategoryOptionAllowInCarPlay;
      }
      for (id action in category[@"actions"]) {
        NSArray *newActionIntentIdentifiers = [NSArray array];
        if (action[@"identifier"] && action[@"title"] && action[@"options"]) {
          UNNotificationActionOptions *actionOption = UNNotificationActionOptionNone;
          if ([action[@"options"] isEqualToString:@"destructive"]) {
            actionOption = UNNotificationActionOptionDestructive;
          } else if ([action[@"options"] isEqualToString:@"foreground"]) {
            actionOption = UNNotificationActionOptionForeground;
          } else if ([action[@"options"] isEqualToString:@"authenticationRequired"]) {
            actionOption = UNNotificationActionOptionAuthenticationRequired;
          }
          UNNotificationAction *newAction = [UNNotificationAction actionWithIdentifier:action[@"identifier"]
                                                                                 title:action[@"title"] options:actionOption];
          newActions = [newActions arrayByAddingObject:newAction];
          newActionIntentIdentifiers = [newActionIntentIdentifiers arrayByAddingObject:action[@"identifier"]];
        }
      }
      newCategories = [newCategories arrayByAddingObject:[UNNotificationCategory categoryWithIdentifier:category[@"identifier"]
                                                                                                actions:newActions intentIdentifiers:newCategoryIntentIdentifiers
                                                                                                options:categoryOption]];
    }
    NSSet *categoriesSet = [NSSet setWithArray:newCategories];
    [center setNotificationCategories:categoriesSet];
    resolve(@"setNotificationCategories successful");
  } else {
    
  }
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
  
  if(SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(@"10.0")) {
    UNAuthorizationOptions types = UNAuthorizationOptionNone;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    if (permissions) {
      if ([RCTConvert BOOL:permissions[@"alert"]]) {
        types += UNAuthorizationOptionAlert;
      }
      if ([RCTConvert BOOL:permissions[@"badge"]]) {
        types += UNAuthorizationOptionBadge;
      }
      if ([RCTConvert BOOL:permissions[@"sound"]]) {
        types += UNAuthorizationOptionSound;
      }
      if ([RCTConvert BOOL:permissions[@"carPlay"]]) {
        types += UNAuthorizationOptionCarPlay;
      }
    } else {
      types = (UNAuthorizationOptionAlert + UNAuthorizationOptionBadge + UNAuthorizationOptionSound + UNAuthorizationOptionCarPlay);
    }
    
    [center requestAuthorizationWithOptions:types completionHandler:^(BOOL granted, NSError * _Nullable error){
      if(!error) {
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
          NSDictionary *notificationTypes = @{
                                              @"alert": @(settings.alertSetting > 0),
                                              @"sound": @(settings.soundSetting > 0),
                                              @"badge": @(settings.badgeSetting > 0),
                                              @"carPlay": @(settings.carPlaySetting > 0),
                                              };
          _requestPermissionsResolveBlock(notificationTypes);
        }];
      }
    }];
  } else {
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
}

RCT_EXPORT_METHOD(abandonPermissions)
{
  if(SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(@"10.0")) {
    UNAuthorizationOptions types = UNAuthorizationOptionNone;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:types completionHandler:^(BOOL granted, NSError * _Nullable error){
      if(!error){
        NSLog(@"App notification authorization abandoned");
      }
    }];
  } else {
    [RCTSharedApplication() unregisterForRemoteNotifications];
  }
}

RCT_EXPORT_METHOD(checkPermissions:(RCTResponseSenderBlock)callback)
{
  if (RCTRunningInAppExtension()) {
    callback(@[@{@"alert": @NO, @"badge": @NO, @"sound": @NO}]);
    return;
  }
  
  if(SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(@"10.0")) {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
      callback(@[@{
                   @"alert": @((settings.alertSetting) > 0),
                   @"badge": @((settings.badgeSetting) > 0),
                   @"sound": @((settings.soundSetting) > 0),
                   }]);
    }];
  } else {
    NSUInteger types = [RCTSharedApplication() currentUserNotificationSettings].types;
    callback(@[@{
                 @"alert": @((types & UIUserNotificationTypeAlert) > 0),
                 @"badge": @((types & UIUserNotificationTypeBadge) > 0),
                 @"sound": @((types & UIUserNotificationTypeSound) > 0),
                 }]);
  }
}

RCT_EXPORT_METHOD(presentLocalNotification:(UILocalNotification *)notification)
{
  [RCTSharedApplication() presentLocalNotificationNow:notification];
}

RCT_EXPORT_METHOD(scheduleLocalNotification:(NSDictionary *)notification)
{
  if(SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(@"10.0")) {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNNotificationRequest *request = [RCTConvert UNNotificationRequest:notification];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
      if (error != nil) {
        NSLog(@"Something went wrong: %@",error);
      }else{
        //NSLog(@"Notification scheduled %@", notification);
        NSLog(@"Notification scheduled");
      }
    }];
  } else {
    UILocalNotification *localNotification = [RCTConvert UILocalNotification:notification];
    [RCTSharedApplication() scheduleLocalNotification:localNotification];
  }
}

RCT_EXPORT_METHOD(cancelAllLocalNotifications)
{
  if(SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(@"10.0")) {
    [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
  } else {
    [RCTSharedApplication() cancelAllLocalNotifications];
  }
}

RCT_EXPORT_METHOD(cancelLocalNotifications:(NSDictionary<NSString *, id> *)userInfo)
{
  if(SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(@"10.0")) {
    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[userInfo[@"id"]]];
  } else {
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
  if(SYSTEM_VERSION_GREATERTHAN_OR_EQUALTO(@"10.0")) {
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
      NSMutableArray<NSDictionary *> *formattedNotificationRequests = [NSMutableArray new];
      for (UNNotificationRequest *request in requests) {
        [formattedNotificationRequests addObject:RCTFormatNotificationRequest(request)];
      }
      callback(@[formattedNotificationRequests]);
    }] ;
  } else {
    NSArray<UILocalNotification *> *scheduledLocalNotifications = [UIApplication sharedApplication].scheduledLocalNotifications;
    NSMutableArray<NSDictionary *> *formattedScheduledLocalNotifications = [NSMutableArray new];
    for (UILocalNotification *notification in scheduledLocalNotifications) {
      [formattedScheduledLocalNotifications addObject:RCTFormatLocalNotification(notification)];
    }
    callback(@[formattedScheduledLocalNotifications]);
  }
}

@end
