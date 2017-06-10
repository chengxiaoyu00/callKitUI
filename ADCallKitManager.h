//
//  ADCallKitManager.h
//  Copyright © 2016 Appdios Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CallKit/CallKit.h>
#import "WTCallManager.h"


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ADCallActionType) {
    ADCallActionTypeStart,
    ADCallActionTypeEnd,
    ADCallActionTypeAnswer,
    ADCallActionTypeMute,
    ADCallActionTypeHeld
};

typedef NS_ENUM(NSInteger, ADCallState) {
    ADCallStatePending,
    ADCallStateConnecting,
    ADCallStateConnected,
    ADCallStateEnded,
    ADCallStateEndedWithFailure,
    ADCallStateEndedUnanswered
};

typedef void(^ADCallKitManagerCompletion)(NSError * _Nullable error);
typedef void(^ADCallKitActionNotificationBlock)(CXCallAction * action, ADCallActionType actionType);

@protocol ADContactProtocol <NSObject>

- (NSString *)uniqueIdentifiers;
- (NSString *)displayNames;
- (NSString *)phoneNumbers;
- (BOOL)hasVideos;
- (NSUUID *)uuids;
- (NSString *)handles;

@end

@class ADUser;
@interface ADCallKitManager : NSObject


@property (nonatomic, copy)  void(^actionNotificationBlock)(CXCallAction * action, ADCallActionType actionType) ;
@property (nonatomic, strong) dispatch_queue_t completionQueue; // Default to mainQueue

@property (nonatomic, strong) WTCallManager *callManager;

+ (ADCallKitManager *)sharedInstance;

- (void)setupWithAppName:(NSString *)appName supportsVideo:(BOOL)supportsVideo;

- (void)setCompletionQueue:(dispatch_queue_t)completionQueue;

/*
 *
 */
- (NSUUID *)reportIncomingCallWithContact:(id<ADContactProtocol>)contact completion:(ADCallKitManagerCompletion)completion;

- (void)reportOutgoingCallWithContact:(id<ADContactProtocol>)contact completion:(ADCallKitManagerCompletion)completion;
- (void)updateCall:(NSUUID *)callUUID state:(ADCallState)state;

- (void)mute:(BOOL)mute callUUID:(NSUUID *)callUUID completion:(ADCallKitManagerCompletion)completion;
- (void)hold:(BOOL)hold callUUID:(NSUUID *)callUUID completion:(ADCallKitManagerCompletion)completion;
- (void)endCall:(NSUUID *)callUUID completion:(ADCallKitManagerCompletion)completion;

@end
NS_ASSUME_NONNULL_END
