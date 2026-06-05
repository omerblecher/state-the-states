import 'package:flutter/foundation.dart' show kDebugMode;

// AdMob production App ID (matches AndroidManifest meta-data).
const String kAdMobAppId = 'ca-app-pub-4227443066128564~7081667253';

// Google's official test ad unit IDs — always fill on any device/emulator.
const String _kTestBannerAdUnitId       = 'ca-app-pub-3940256099942544/6300978111';
const String _kTestInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const String _kTestRewardedAdUnitId     = 'ca-app-pub-3940256099942544/5224354917';
const String _kTestAppOpenAdUnitId      = 'ca-app-pub-3940256099942544/9257395921';

// Production ad unit IDs.
const String _kProdBannerAdUnitId       = 'ca-app-pub-4227443066128564/1019125702';
const String _kProdInterstitialAdUnitId = 'ca-app-pub-4227443066128564/9220059672';
const String _kProdRewardedAdUnitId     = 'ca-app-pub-4227443066128564/7906978004';
const String _kProdAppOpenAdUnitId      = 'ca-app-pub-4227443066128564/5312604258';

// Active ad unit IDs — test in debug, production in release.
String get kBannerAdUnitId       => kDebugMode ? _kTestBannerAdUnitId       : _kProdBannerAdUnitId;
String get kInterstitialAdUnitId => kDebugMode ? _kTestInterstitialAdUnitId : _kProdInterstitialAdUnitId;
String get kRewardedAdUnitId     => kDebugMode ? _kTestRewardedAdUnitId     : _kProdRewardedAdUnitId;
String get kAppOpenAdUnitId      => kDebugMode ? _kTestAppOpenAdUnitId      : _kProdAppOpenAdUnitId;

// AppLovin — disabled. Set to true ONLY when: (1) AppLovin account is approved,
// (2) AppLovin is back on the Google Play Families Self-Certified Ads SDK
// Program list. Mediation is v2 scope; AppLovin SDK 13.0+ refuses child-directed init.
const bool   kAppLovinEnabled = false;
const String kAppLovinSdkKey  = '';
