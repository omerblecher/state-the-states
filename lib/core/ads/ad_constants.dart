// AdMob production App ID (matches AndroidManifest meta-data).
const String kAdMobAppId = 'ca-app-pub-4227443066128564~7081667253';

// Production ad unit IDs — populated for Phase 8 real ad activation.
const String kBannerAdUnitId       = 'ca-app-pub-4227443066128564/1019125702';
const String kInterstitialAdUnitId = 'ca-app-pub-4227443066128564/9220059672';
const String kRewardedAdUnitId     = 'ca-app-pub-4227443066128564/7906978004';
const String kAppOpenAdUnitId      = 'ca-app-pub-4227443066128564/5312604258';

// AppLovin — disabled. Set to true ONLY when: (1) AppLovin account is approved,
// (2) AppLovin is back on the Google Play Families Self-Certified Ads SDK
// Program list. Mediation is v2 scope; AppLovin SDK 13.0+ refuses child-directed init.
const bool   kAppLovinEnabled = false;
const String kAppLovinSdkKey  = '';
