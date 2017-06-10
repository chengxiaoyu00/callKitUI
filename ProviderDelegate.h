//
//  ProviderDelegate.h
//  OneCallKitDemo
//
//  Created by wintel on 16/8/23.
//  Copyright © 2016年 wintel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CallKit/CallKit.h>

#import "WTCallManager.h"
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


@interface ProviderDelegate : NSObject <CXProviderDelegate>

@property (nonatomic, copy)  void(^ actionNotificationBlock)(CXCallAction * action, ADCallActionType actionType) ;
@property (nonatomic, strong) WTCallManager *callManager;

- (instancetype)initWithCallManager:(WTCallManager *)callManager;

- (void)reportIncomingCallUUID:(NSUUID *)uuid handle:(NSString *)handle hasVideo:(BOOL)hasVideo completion:(void (^ __nullable)(NSError * error))completion;

+ (void)authorizationSiri;
@end
