/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule PushNotificationIOS10
 * @flow
 */
'use strict';

const NativeEventEmitter = require('react-native').NativeEventEmitter;
const RCTPushNotificationManager = require('react-native').NativeModules.PushNotificationManager10;
const invariant = require('fbjs/lib/invariant');

const PushNotificationEmitter = new NativeEventEmitter(RCTPushNotificationManager);

const _notifHandlers = new Map();

const DEVICE_NOTIF_EVENT = 'remoteNotificationReceived';
const NOTIF_REGISTER_EVENT = 'remoteNotificationsRegistered';
const NOTIF_REGISTRATION_ERROR_EVENT = 'remoteNotificationRegistrationError';
const DEVICE_LOCAL_NOTIF_EVENT = 'localNotificationReceived';
const DEVICE_LOCAL_RESPONSE_EVENT = 'notificationResponseReceived';

/**
 * An event emitted by PushNotificationIOS.
 */
export
    type
    PushNotificationEventName = $Enum < {
    /**
     * Fired when a remote notification is received. The handler will be invoked
     * with an instance of `PushNotificationIOS`.
     */
        notification: string,
    /**
     * Fired when a local notification is received. The handler will be invoked
     * with an instance of `PushNotificationIOS`.
     */
        localNotification: string,
    /**
     * Fired when the user registers for remote notifications. The handler will be
     * invoked with a hex string representing the deviceToken.
     */
        register: string,
    /**
     * Fired when the user fails to register for remote notifications. Typically
     * occurs when APNS is having issues, or the device is a simulator. The
     * handler will be invoked with {message: string, code: number, details: any}.
     */
        registrationError: string,
} >;

export type ActionOption = $Enum < {
    none: string,
    authenticationRequired: string,
    destructive: string,
    foreground: string
} >;

class PushNotificationIOS10Response {
    _userInfo: Object;
    _actionIdentifier: string;
    _body: string;
    _title: string;

    constructor(response: Object) {
        this._userInfo = {};

        this._userInfo = response.userInfo;
        this._actionIdentifier = response.actionIdentifier;
        this._body = response.body;
        this._title = response.title;
    }

    /**
     * An alias for `getData` to get the notification's main message string
     */
    getUserInfo(): ?string | ?Object {
        return this._userInfo;
    }

    /**
     * An alias for `getActionIdentifier` to get the action response identifier
     */
    getActionIdentifier(): ?string {
        return this._actionIdentifier;
    }

    /**
     * An alias for `getBody` to get the action response body text
     */
    getBody(): ?string {
        return this._body;
    }

    /**
     * An alias for `getTitle` to get the action response title text
     */
    getTitle(): ?string {
        return this._title;
    }
}

/**
 * Handle push notifications for your app, including permission handling and
 * icon badge number.
 *
 * To get up and running, [configure your notifications with Apple](https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/AppDistributionGuide/AddingCapabilities/AddingCapabilities.html#//apple_ref/doc/uid/TP40012582-CH26-SW6)
 * and your server-side system. To get an idea, [this is the Parse guide](https://parse.com/tutorials/ios-push-notifications).
 *
 * [Manually link](docs/linking-libraries-ios.html#manual-linking) the PushNotificationIOS library
 *
 * - Add the following to your Project: `node_modules/react-native/Libraries/PushNotificationIOS/RCTPushNotification.xcodeproj`
 * - Add the following to `Link Binary With Libraries`: `libRCTPushNotification.a`
 * - Add the following to your `Header Search Paths`:
 * `$(SRCROOT)/../node_modules/react-native/Libraries/PushNotificationIOS` and set the search to `recursive`
 *
 * Finally, to enable support for `notification` and `register` events you need to augment your AppDelegate.
 *
 * At the top of your `AppDelegate.m`:
 *
 *   `#import "RCTPushNotificationManager.h"`
 *
 * And then in your AppDelegate implementation add the following:
 *
 *   ```
 *    // Required to register for notifications
 *    - (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
 *    {
 *     [RCTPushNotificationManager didRegisterUserNotificationSettings:notificationSettings];
 *    }
 *    // Required for the register event.
 *    - (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
 *    {
 *     [RCTPushNotificationManager didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
 *    }
 *    // Required for the registrationError event.
 *    - (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
 *    {
 *     [RCTPushNotificationManager didFailToRegisterForRemoteNotificationsWithError:error];
 *    }
 *    // Required for the notification event.
 *    - (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)notification
 *    {
 *     [RCTPushNotificationManager didReceiveRemoteNotification:notification];
 *    }
 *    // Required for the localNotification event.
 *    - (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
 *    {
 *     [RCTPushNotificationManager didReceiveLocalNotification:notification];
 *    }
 *   ```
 */
class PushNotificationIOS10 {
    _data: Object;
    _alert: string | Object;
    _sound: string;
    _badgeCount: number;

    /**
     * Schedules the localNotification for immediate presentation.
     *
     * details is an object containing:
     *
     * - `alertBody` : The message displayed in the notification alert.
     * - `alertAction` : The "action" displayed beneath an actionable notification. Defaults to "view";
     * - `soundName` : The sound played when the notification is fired (optional).
     * - `category`  : The category of this notification, required for actionable notifications (optional).
     * - `userInfo`  : An optional object containing additional notification data.
     * - `applicationIconBadgeNumber` (optional) : The number to display as the app's icon badge. The default value of this property is 0, which means that no badge is displayed.
     */
    static presentLocalNotification(details: Object) {
        RCTPushNotificationManager.presentLocalNotification(details);
    }

    /**
     * Schedules the localNotification for future presentation.
     *
     * details is an object containing:
     *
     * - `fireDate` : The date and time when the system should deliver the notification.
     * - `alertBody` : The message displayed in the notification alert.
     * - `alertAction` : The "action" displayed beneath an actionable notification. Defaults to "view";
     * - `soundName` : The sound played when the notification is fired (optional).
     * - `category`  : The category of this notification, required for actionable notifications (optional).
     * - `userInfo` : An optional object containing additional notification data.
     * - `applicationIconBadgeNumber` (optional) : The number to display as the app's icon badge. Setting the number to 0 removes the icon badge.
     */
    static scheduleLocalNotification(details: Object) {
        RCTPushNotificationManager.scheduleLocalNotification(details);
    }

    /**
     * Cancels all scheduled localNotifications
     */
    static cancelAllLocalNotifications() {
        RCTPushNotificationManager.cancelAllLocalNotifications();
    }

    /**
     * Sets the badge number for the app icon on the home screen
     */
    static setApplicationIconBadgeNumber(number: number) {
        RCTPushNotificationManager.setApplicationIconBadgeNumber(number);
    }

    /**
     * Gets the current badge number for the app icon on the home screen
     */
    static getApplicationIconBadgeNumber(callback: Function) {
        RCTPushNotificationManager.getApplicationIconBadgeNumber(callback);
    }

    /**
     * Cancel local notifications.
     *
     * Optionally restricts the set of canceled notifications to those
     * notifications whose `userInfo` fields match the corresponding fields
     * in the `userInfo` argument.
     */
    static cancelLocalNotifications(userInfo: Object) {
        RCTPushNotificationManager.cancelLocalNotifications(userInfo);
    }

    /**
     * Gets the local notifications that are currently scheduled.
     */
    static getScheduledLocalNotifications(callback: Function) {
        RCTPushNotificationManager.getScheduledLocalNotifications(callback);
    }

    /**
     * Gets the notifications that have been currently delivered.
     */
    static getDeliveredNotifications(callback: Function) {
        RCTPushNotificationManager.getDeliveredNotifications(callback);
    }

    /**
     * Remove delivered notifications matching an id.
     *
     * A `userInfo` object is required with an `id` field to match the specified notifications.
     */
    static removeDeliveredNotifications(userInfo: Object) {
        RCTPushNotificationManager.removeDeliveredNotifications(userInfo);
    }

    /**
     * Removes all delivered notifications.
     */
    static removeAllDeliveredNotifications() {
        RCTPushNotificationManager.removeAllDeliveredNotifications();
    }

    /**
     * Attaches a listener to remote or local notification events while the app is running
     * in the foreground or the background.
     *
     * Valid events are:
     *
     * - `notification` : Fired when a remote notification is received. The
     *   handler will be invoked with an instance of `PushNotificationIOS`.
     * - `localNotification` : Fired when a local notification is received. The
     *   handler will be invoked with an instance of `PushNotificationIOS`.
     * - `register`: Fired when the user registers for remote notifications. The
     *   handler will be invoked with a hex string representing the deviceToken.
     * - `registrationError`: Fired when the user fails to register for remote
     *   notifications. Typically occurs when APNS is having issues, or the device
     *   is a simulator. The handler will be invoked with
     *   {message: string, code: number, details: any}.
     */
    static addEventListener(type: PushNotificationEventName, handler: Function) {
        invariant(
            type === 'notification' || type === 'register' || type === 'registrationError' || type === 'localNotification' || type === 'notificationResponse',
            'PushNotificationIOS only supports `notification`, `register`, `registrationError`, and `localNotification` events'
        );
        var listener;
        if (type === 'notification') {
            listener = PushNotificationEmitter.addListener(
                DEVICE_NOTIF_EVENT,
                (notifData) => {
                    handler(new PushNotificationIOS10(notifData));
                }
            );
        } else if (type === 'localNotification') {
            listener = PushNotificationEmitter.addListener(
                DEVICE_LOCAL_NOTIF_EVENT,
                (notifData) => {
                    handler(new PushNotificationIOS10(notifData));
                }
            );
        } else if (type === 'notificationResponse') {
            listener = PushNotificationEmitter.addListener(
                DEVICE_LOCAL_RESPONSE_EVENT,
                (responseData) => {
                    handler(new PushNotificationIOS10Response(responseData));
                }
            );
        } else if (type === 'register') {
            listener = PushNotificationEmitter.addListener(
                NOTIF_REGISTER_EVENT,
                (registrationInfo) => {
                    handler(registrationInfo.deviceToken);
                }
            );
        } else if (type === 'registrationError') {
            listener = PushNotificationEmitter.addListener(
                NOTIF_REGISTRATION_ERROR_EVENT,
                (errorInfo) => {
                    handler(errorInfo);
                }
            );
        }
        _notifHandlers.set(handler, listener);
    }

    /**
     * Removes the event listener. Do this in `componentWillUnmount` to prevent
     * memory leaks
     */
    static removeEventListener(type: PushNotificationEventName, handler: Function) {
        invariant(
            type === 'notification' || type === 'register' || type === 'registrationError' || type === 'localNotification' || type === 'notificationResponse',
            'PushNotificationIOS only supports `notification`, `register`, `registrationError`, and `localNotification` events'
        );
        var listener = _notifHandlers.get(handler);
        if (!listener) {
            return;
        }
        listener.remove();
        _notifHandlers.delete(handler);
    }

    /**
     * Requests notification permissions from iOS, prompting the user's
     * dialog box. By default, it will request all notification permissions, but
     * a subset of these can be requested by passing a map of requested
     * permissions.
     * The following permissions are supported:
     *
     *   - `alert`
     *   - `badge`
     *   - `sound`
     *
     * If a map is provided to the method, only the permissions with truthy values
     * will be requested.

     * This method returns a promise that will resolve when the user accepts,
     * rejects, or if the permissions were previously rejected. The promise
     * resolves to the current state of the permission.
     */
    static requestPermissions(permissions?: {
                                  alert?: boolean,
                                  badge?: boolean,
                                  sound?: boolean,
                                  carPlay?: boolean
                              }): Promise < {
        alert: boolean,
        badge: boolean,
        sound: boolean,
        carPlay: boolean
    } > {
        var requestedPermissions = {};
        if (permissions) {
            requestedPermissions = {
                alert: !!permissions.alert,
                badge: !!permissions.badge,
                sound: !!permissions.sound,
                carPlay: !!permissions.carPlay
            };
        } else {
            requestedPermissions = {
                alert: true,
                badge: true,
                sound: true,
                carPlay: true
            };
        }
        return RCTPushNotificationManager.requestPermissions(requestedPermissions);
    }

    /**
     * Unregister for all remote notifications received via Apple Push Notification service.
     *
     * You should call this method in rare circumstances only, such as when a new version of
     * the app removes support for all types of remote notifications. Users can temporarily
     * prevent apps from receiving remote notifications through the Notifications section of
     * the Settings app. Apps unregistered through this method can always re-register.
     */
    static abandonPermissions() {
        RCTPushNotificationManager.abandonPermissions();
    }

    /**
     * See what push permissions are currently enabled. `callback` will be
     * invoked with a `permissions` object:
     *
     *  - `alert` :boolean
     *  - `badge` :boolean
     *  - `sound` :boolean
     */
    static checkPermissions(callback: Function) {
        invariant(
            typeof callback === 'function',
            'Must provide a valid callback'
        );
        RCTPushNotificationManager.checkPermissions(callback);
    }

    /**
     * This method returns a promise that resolves to either the notification
     * object if the app was launched by a push notification, or `null` otherwise.
     */
    static getInitialNotification(): Promise<?PushNotificationIOS10> {
        return RCTPushNotificationManager.getInitialNotification().then(notification => {
            return notification && new PushNotificationIOS(notification);
        });
    }

    /**
     *  This method returns a promise that resolves to either the notification
     *  response object if the app was launched by a notification response, or `null` otherwise.
     */
    static getInitialNotificationResponse(): Promise<?PushNotificationIOS10Response> {
        return RCTPushNotificationManager.getInitialNotificationResponse().then(responseData => {
            return responseData && new PushNotificationIOS10Response(responseData);
        })
    }

    /**
     * This method returns a promise that resolves to whether the devices supports content extensions or not.
     * @returns {Promise.<?boolean>}
     */
    static getContentExtensionSupport(): Promise<boolean> {
        return RCTPushNotificationManager.getContentExtensionSupport();
    }

    /**
     * This method adds actions to categories.
     */
    static setNotificationCategories(categories: Array<Object>, callback: Function) {
        return RCTPushNotificationManager.setNotificationCategories(categories).then(response => {
            callback(response);
        });
    }

    /**
     * You will never need to instantiate `PushNotificationIOS` yourself.
     * Listening to the `notification` event and invoking
     * `getInitialNotification` is sufficient
     */
    constructor(nativeNotif: Object) {
        this._data = {};

        if (nativeNotif.remote) {
            // Extract data from Apple's `aps` dict as defined:
            // https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/ApplePushService.html
            Object.keys(nativeNotif).forEach((notifKey) => {
                var notifVal = nativeNotif[notifKey];
                if (notifKey === 'aps') {
                    this._alert = notifVal.alert;
                    this._sound = notifVal.sound;
                    this._badgeCount = notifVal.badge;
                } else {
                    this._data[notifKey] = notifVal;
                }
            });
        } else {
            // Local notifications aren't being sent down with `aps` dict.
            this._badgeCount = nativeNotif.applicationIconBadgeNumber;
            this._sound = nativeNotif.soundName;
            this._alert = nativeNotif.alertBody;
            this._data = nativeNotif.userInfo;
        }
    }

    /**
     * An alias for `getAlert` to get the notification's main message string
     */
    getMessage():?string | ?Object {
        // alias because "alert" is an ambiguous name
        return this._alert;
    }

    /**
     * Gets the sound string from the `aps` object
     */
    getSound():?string {
        return this._sound;
    }

    /**
     * Gets the notification's main message from the `aps` object
     */
    getAlert():?string | ?Object {
        return this._alert;
    }

    /**
     * Gets the badge count number from the `aps` object
     */
    getBadgeCount():?number {
        return this._badgeCount;
    }

    /**
     * Gets the data object on the notif
     */
    getData():?Object {
        return this._data;
    }
}

module.exports = PushNotificationIOS10;