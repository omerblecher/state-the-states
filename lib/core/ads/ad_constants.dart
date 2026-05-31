// AdMob test app ID (matches AndroidManifest meta-data).
// Replace with the real app ID before Play Store submission (v2).
const String kAdMobTestAppId = 'ca-app-pub-3940256099942544~3347511713';

// Ad unit IDs — intentionally EMPTY in v1. No real ads are requested: the only
// wired AdService is StubAdService (COPPA walled garden). Populate with
// production IDs in v2 when the real AdMob service is introduced.
const String kBannerAdUnitId       = '';
const String kInterstitialAdUnitId = '';
const String kRewardedAdUnitId     = '';
const String kAppOpenAdUnitId      = '';

// AppLovin — disabled. Set to true ONLY when: (1) AppLovin account is approved,
// (2) AppLovin is back on the Google Play Families Self-Certified Ads SDK
// Program list. Mediation is v2 scope; no mediation SDKs ship in v1.
const bool   kAppLovinEnabled = false;
const String kAppLovinSdkKey  = '';
