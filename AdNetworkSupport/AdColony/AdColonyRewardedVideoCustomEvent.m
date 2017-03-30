//
//  AdColonyRewardedVideoCustomEvent.m
//  MoPubSDK
//
//  Copyright (c) 2016 MoPub. All rights reserved.
//

#import <SUAdColonyAdapter/AdColony.h>

#import "AdColonyRewardedVideoCustomEvent.h"
#import "AdColonyInstanceMediationSettings.h"
#import "AdColonyController.h"
#import "MoPub.h"
#import "MPLogging.h"
#import "MPRewardedVideoReward.h"

@interface AdColonyRewardedVideoCustomEvent ()

@property (nonatomic, retain) AdColonyInterstitial *ad;
@property (nonatomic, retain) AdColonyZone *zone;

@end

@implementation AdColonyRewardedVideoCustomEvent

- (void)requestRewardedVideoWithCustomEventInfo:(NSDictionary *)info {
    NSString *appId = [info objectForKey:@"appId"];
    if (appId == nil) {
        MPLogError(@"Invalid setup. Use the appId parameter when configuring your network in the MoPub website.");
        return;
    }

    NSArray *allZoneIds = [info objectForKey:@"allZoneIds"];
    if (allZoneIds.count == 0) {
        MPLogError(@"Invalid setup. Use the allZoneIds parameter when configuring your network in the MoPub website.");
        return;
    }

    NSString *zoneId = [info objectForKey:@"zoneId"];
    if (zoneId == nil) {
        zoneId = allZoneIds[0];
    }

    NSString *customerId = [self.delegate customerIdForRewardedVideoCustomEvent:self];

    [AdColonyController initializeAdColonyCustomEventWithAppId:appId allZoneIds:allZoneIds userId:customerId callback:^{

        AdColonyInstanceMediationSettings *settings = [self.delegate instanceMediationSettingsForClass:[AdColonyInstanceMediationSettings class]];
        BOOL showPrePopup = (settings) ? settings.showPrePopup : NO;
        BOOL showPostPopup = (settings) ? settings.showPostPopup : NO;

        AdColonyAdOptions *options = [AdColonyAdOptions new];
        options.showPrePopup = showPrePopup;
        options.showPostPopup = showPostPopup;

        __weak AdColonyRewardedVideoCustomEvent *weakSelf = self;

        [AdColony requestInterstitialInZone:zoneId options:options success:^(AdColonyInterstitial * _Nonnull ad) {
            MPLogInfo(@"AdColony ad loaded for zone %@", zoneId);
            weakSelf.zone = [AdColony zoneForID:zoneId];
            weakSelf.ad = ad;

            [ad setOpen:^{
                MPLogInfo(@"AdColony zone %@ started", zoneId);
                [weakSelf.delegate rewardedVideoWillAppearForCustomEvent:weakSelf];
                [weakSelf.delegate rewardedVideoDidAppearForCustomEvent:weakSelf];
            }];
            [ad setClose:^{
                MPLogInfo(@"AdColony zone %@ finished", zoneId);
                [weakSelf.delegate rewardedVideoWillDisappearForCustomEvent:weakSelf];
                [weakSelf.delegate rewardedVideoDidDisappearForCustomEvent:weakSelf];
            }];
            [ad setExpire:^{
                MPLogInfo(@"AdColony zone %@ expired", zoneId);
                [weakSelf.delegate rewardedVideoDidExpireForCustomEvent:weakSelf];
            }];
            [ad setLeftApplication:^{
                MPLogInfo(@"AdColony zone %@ click caused application transition", zoneId);
                [weakSelf.delegate rewardedVideoWillLeaveApplicationForCustomEvent:weakSelf];
            }];
            [ad setClick:^{
                MPLogInfo(@"AdColony zone %@ ad clicked", zoneId);
                [weakSelf.delegate rewardedVideoDidReceiveTapEventForCustomEvent:weakSelf];
            }];

            [weakSelf.zone setReward:^(BOOL success, NSString * _Nonnull name, int amount) {
                if (!success) {
                    MPLogInfo(@"AdColony reward failure in zone %@", zoneId);
                    return;
                }
                [weakSelf.delegate rewardedVideoShouldRewardUserForCustomEvent:weakSelf reward:[[MPRewardedVideoReward alloc] initWithCurrencyType:name amount:@(amount)]];
            }];

            [weakSelf.delegate rewardedVideoDidLoadAdForCustomEvent:weakSelf];
        } failure:^(AdColonyAdRequestError * _Nonnull error) {
            MPLogInfo(@"Failed to load AdColony rewarded video in zone %@", error);
            weakSelf.ad = nil;
            [weakSelf.delegate rewardedVideoDidFailToLoadAdForCustomEvent:weakSelf error:error];
        }];

    }];
}

- (BOOL)hasAdAvailable {
    return self.ad != nil;
}

- (void)presentRewardedVideoFromViewController:(UIViewController *)viewController {
    if (self.ad) {
        MPLogInfo(@"AdColony zone %@ attempting to start", self.ad.zoneID);
        if (![self.ad showWithPresentingViewController:viewController]) {
            MPLogInfo(@"Failed to show AdColony video");
            NSError *error = [NSError errorWithDomain:MoPubRewardedVideoAdsSDKDomain code:MPRewardedVideoAdErrorUnknown userInfo:nil];
            [self.delegate rewardedVideoDidFailToPlayForCustomEvent:self error:error];
        }
    } else {
        MPLogInfo(@"Failed to show AdColony video interstitial, ad is not available");
        NSError *error = [NSError errorWithDomain:MoPubRewardedVideoAdsSDKDomain code:MPRewardedVideoAdErrorNoAdsAvailable userInfo:nil];
        [self.delegate rewardedVideoDidFailToPlayForCustomEvent:self error:error];
    }
}

@end
