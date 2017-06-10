//
//  ADCallKitManager.m
//  Copyright © 2016 Appdios Inc. All rights reserved.
//

#import "ADCallKitManager.h"
#import "CallAudio.h"
#import <Intents/Intents.h>
NS_ASSUME_NONNULL_BEGIN

@implementation CXTransaction (ADPrivateAdditions)

+ (CXTransaction *)transactionWithActions:(NSArray <CXAction *> *)actions {
    CXTransaction *transcation = [[CXTransaction alloc] init];
    for (CXAction *action in actions) {
        [transcation addAction:action];
    }
    return transcation;
}

@end

@interface ADCallKitManager() <CXProviderDelegate>
@property (nonatomic, strong) CXProvider *provider;
@property (nonatomic, strong) CXCallController *callController;
@property (nonatomic, strong) CXCallUpdate *Update;

@end

@implementation ADCallKitManager

static const NSInteger ADDefaultMaximumCallsPerCallGroup = 1;
static const NSInteger ADDefaultMaximumCallGroups = 1;

+ (ADCallKitManager *)sharedInstance {
	static ADCallKitManager *instance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        instance = [[super allocWithZone:nil] init];
    });
    return instance;
}

- (void)setupWithAppName:(NSString *)appName supportsVideo:(BOOL)supportsVideo {
    self.callController = [[CXCallController alloc] initWithQueue:dispatch_get_main_queue()];
    CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:appName];
    configuration.maximumCallGroups = ADDefaultMaximumCallGroups;
    configuration.maximumCallsPerCallGroup = ADDefaultMaximumCallsPerCallGroup;
    configuration.supportsVideo = supportsVideo;
    configuration.iconTemplateImageData = UIImagePNGRepresentation([UIImage imageNamed:@"icon_128x128"]);
    self.provider = [[CXProvider alloc] initWithConfiguration:configuration];
    [self.provider setDelegate:self queue:dispatch_get_main_queue()];
    
}

- (void)setCompletionQueue:(dispatch_queue_t)completionQueue {
    _completionQueue = completionQueue;
    if (self.provider) {
        [self.provider setDelegate:self queue:_completionQueue];
    }
}
- (NSUUID *)reportIncomingCallWithContact:(id<ADContactProtocol>)contact completion:(ADCallKitManagerCompletion)completion {
    NSUUID *callUUID = [NSUUID UUID];
    
    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
//    callUpdate.callerIdentifier = [contact uniqueIdentifier];
    callUpdate.localizedCallerName = [contact displayNames];
    CXHandle * hand= [[CXHandle alloc]initWithType:CXHandleTypePhoneNumber value:[contact handles]];
    callUpdate.remoteHandle = hand;
    callUpdate.hasVideo = [contact hasVideos];
    
    self.Update = callUpdate;
//    __weak typeof(self) weakSelf = self;
    __weak __typeof(&*self)weakSelf=self;
    [self.provider reportNewIncomingCallWithUUID:callUUID update:callUpdate completion:^(NSError * _Nullable error) {
        if (error==nil) {
            WTCall *call = [[WTCall alloc] initWithUUID:[contact uuids]];
            call.handle = [contact handles];
            [weakSelf.callManager addCall:call];
        }
        completion(error);
    }];

    return callUUID;
}

- (void)reportOutgoingCallWithContact:(id<ADContactProtocol>)contact completion:(ADCallKitManagerCompletion)completion {
    NSUUID *callUUID = [NSUUID UUID];
    CXHandle *handle = [[CXHandle alloc]initWithType:CXHandleTypePhoneNumber value:[contact phoneNumbers]];
    CXStartCallAction *action = [[CXStartCallAction alloc] initWithCallUUID:callUUID handle:handle];
    action.contactIdentifier = [contact uniqueIdentifiers];
//    action.destination = [contact phoneNumber];

    [self.callController requestTransaction:[CXTransaction transactionWithActions:@[action]] completion:completion];
 
}
#pragma mark ________//被动操作__________
- (void)updateCall:(NSUUID *)callUUID state:(ADCallState)state {
    switch (state) {
        case ADCallStateConnecting:
            [self.provider reportOutgoingCallWithUUID:callUUID startedConnectingAtDate:nil];
            break;
        case ADCallStateConnected:
            [self.provider reportOutgoingCallWithUUID:callUUID connectedAtDate:nil];
            break;
        case ADCallStateEnded:
            [self.provider reportCallWithUUID:callUUID endedAtDate:nil reason:CXCallEndedReasonRemoteEnded];
            break;
        case ADCallStateEndedWithFailure:
            [self.provider reportCallWithUUID:callUUID endedAtDate:nil reason:CXCallEndedReasonFailed];
            break;
        case ADCallStateEndedUnanswered:
            [self.provider reportCallWithUUID:callUUID endedAtDate:nil reason:CXCallEndedReasonUnanswered];
            break;
        
        default:
            break;
    }
}
#pragma mark ________主动操作__________
- (void)mute:(BOOL)mute callUUID:(NSUUID *)callUUID completion:(ADCallKitManagerCompletion)completion {
    CXSetMutedCallAction *action = [[CXSetMutedCallAction alloc] initWithCallUUID:callUUID muted:YES];
    action.muted = mute;
    
    [self.callController requestTransaction:[CXTransaction transactionWithActions:@[action]] completion:completion];
}

- (void)hold:(BOOL)hold callUUID:(NSUUID *)callUUID completion:(ADCallKitManagerCompletion)completion {
    CXSetHeldCallAction *action = [[CXSetHeldCallAction alloc] initWithCallUUID:callUUID onHold:YES];
    action.onHold = hold;
    
    [self.callController requestTransaction:[CXTransaction transactionWithActions:@[action]] completion:completion];
}

- (void)endCall:(NSUUID *)callUUID completion:(ADCallKitManagerCompletion)completion {
    CXEndCallAction *action = [[CXEndCallAction alloc] initWithCallUUID:callUUID];
    
    [self.callController requestTransaction:[CXTransaction transactionWithActions:@[action]] completion:completion];
}

#pragma mark - CXProviderDelegate
- (BOOL)provider:(CXProvider *)provider executeTransaction:(CXTransaction *)transaction {

//    [self.provider reportCallWithUUID:transaction.UUID updated:self.Update];
    return YES;
}
- (void)provider:(CXProvider *)provider performAnswerCallAction:(nonnull CXAnswerCallAction *)action {
    
//    if (_actionNotificationBlock) {
//        _actionNotificationBlock(action, ADCallActionTypeAnswer);
//    }
//    [action fulfill];
    WTCall *call = [_callManager callWithUUID:action.callUUID];
    if (call == nil) {
        [action fail];
    }else{
        configureAudioSession();
        [call answerWTCallCall];
        [action fulfill];
    }
}

- (void)provider:(CXProvider *)provider performEndCallAction:(nonnull CXEndCallAction *)action {
//    if (_actionNotificationBlock) {
//        _actionNotificationBlock(action, ADCallActionTypeEnd);
//    }
//    [action fulfill];
    WTCall *call = [_callManager callWithUUID:action.callUUID];
    if (call == nil) {
        [action fail];
    }else{
        stopAudio();
        [call endWTCallCall];
        [action fulfill];
        [_callManager removeCall:call];
    }
}

- (void)provider:(CXProvider *)provider performStartCallAction:(nonnull CXStartCallAction *)action {
    
//    if (self.actionNotificationBlock) {
//        self.actionNotificationBlock(action, ADCallActionTypeStart);
//    }
//    if (action.isVideo) {
//        [action fulfill];
//    } else {
//        [action fail];
//    }
    WTCall *call = [[WTCall alloc] initWithUUID:action.callUUID isOutgoing:YES];
    call.handle = action.handle.value;
    
    configureAudioSession();
    
    __weak __typeof(self) weakSelf = self;
    __weak __typeof(WTCall *) weakCall = call;
    call.hasStartedConnectingDidChange = ^(BOOL success){
        [weakSelf.provider reportOutgoingCallWithUUID:weakCall.uuid startedConnectingAtDate:weakCall.connectingDate];
    };
    
    call.hasConnectedDidChange = ^(BOOL success){
        [weakSelf.provider reportOutgoingCallWithUUID:weakCall.uuid connectedAtDate:weakCall.connectDate];
    };
    [call startWTCallCallCompletion:^(BOOL success) {
        if (success) {
            [action fulfill];
            [weakSelf.callManager addCall:weakCall];
        }else{
            [action fail];
        }
    }];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(nonnull CXSetMutedCallAction *)action {
    if (self.actionNotificationBlock) {
        self.actionNotificationBlock(action, ADCallActionTypeMute);
    }
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(nonnull CXSetHeldCallAction *)action {
    if (self.actionNotificationBlock) {
        self.actionNotificationBlock(action, ADCallActionTypeHeld);
    }
    [action fulfill];
    
}
- (void)providerDidReset:(CXProvider *)provider {
    NSLog(@"provider Did Reset");
    stopAudio();
    
    for (WTCall *call in _callManager.calls) {
        [call endWTCallCall];
    }
    [_callManager removeAllCalls];
}
#pragma mark - CallAudio
void stopAudio(){
    CallAudio *audio = [CallAudio sharedCallAudio];
    [audio stopAudio];
}

void startAudio(){
    CallAudio *audio = [CallAudio sharedCallAudio];
    [audio startAudio];
}

void configureAudioSession(){
    CallAudio *audio = [CallAudio sharedCallAudio];
    [audio configureAudioSession];
}


+ (void)authorizationSiri{
    //Capabilities 中打开 Siri 的开关,仅仅支持付费开发者证书
    //    switch ([INPreferences siriAuthorizationStatus]) {
    //        case INSiriAuthorizationStatusNotDetermined://不确定
    //            [INPreferences requestSiriAuthorization:^(INSiriAuthorizationStatus status) {
    //                //请求Siri权限
    //            }];
    //            break;
    //        case INSiriAuthorizationStatusRestricted://受限
    //
    //            break;
    //        case INSiriAuthorizationStatusDenied://拒绝
    //
    //            break;
    //        case INSiriAuthorizationStatusAuthorized://通过
    //
    //            break;
    //        default:
    //            break;
    //    }
}

@end
NS_ASSUME_NONNULL_END
