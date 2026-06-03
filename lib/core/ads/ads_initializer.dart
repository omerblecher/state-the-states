import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gma_mediation_ironsource/gma_mediation_ironsource.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';
// NOTE: NO import for the InMobi mediation adapter — GmaMediationInMobi is an
// empty stub class with no Dart-side COPPA API. InMobi forwards
// tagForChildDirectedTreatment automatically from GMA's RequestConfiguration.
import 'ad_constants.dart';

/// Initializes the AdMob SDK with child-directed flags for COPPA compliance.
///
/// Must be called before [runApp] in main(). The mandatory COPPA init sequence
/// (per RESEARCH.md §AdMob COPPA Initialization and CONTEXT.md D-M04) is:
///   1. updateRequestConfiguration (child-directed flags) — BEFORE initialize()
///   2. ironSource GDPR + CCPA flags
///   3. Unity GDPR + CCPA flags
///   4. AppLovin guard (permanently disabled — kAppLovinEnabled = false)
///   5. MobileAds.instance.initialize() — LAST
Future<void> initializeAds() async {
  // Step 1: Set child-directed flags on AdMob BEFORE initialize().
  // COMP-04: G/PG max content rating; tagForChildDirectedTreatment required
  // for COPPA and Google Play Families Policy compliance.
  // Do NOT set both tagForChildDirectedTreatment AND tagForUnderAgeOfConsent
  // to yes simultaneously — child-directed covers UCPA; dual-flag is not
  // recommended per Google docs.
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      maxAdContentRating: MaxAdContentRating.g,
    ),
  );

  // Step 2: ironSource — GDPR no-consent + CCPA do-not-sell for children.
  // Flags analog: FlagsRoundTheWorld/lib/core/ads/ads_initializer.dart
  GmaMediationIronsource().setConsent(false);
  GmaMediationIronsource().setDoNotSell(true);

  // Step 3: Unity — no GDPR consent + no CCPA consent (child-directed).
  // Flags analog: FlagsRoundTheWorld/lib/core/ads/ads_initializer.dart
  await GmaMediationUnity().setGDPRConsent(false);
  await GmaMediationUnity().setCCPAConsent(false);

  // Step 4: AppLovin — permanently disabled.
  // Activate only when: (1) AppLovin account approved,
  // (2) AppLovin back on Google Play Families Self-Certified Ads SDK list.
  if (kAppLovinEnabled) {
    // No-op: AppLovin SDK 13.0+ refuses child-directed init.
  }

  // Step 5: InMobi: NO Dart call needed. The native adapter auto-forwards
  // tagForChildDirectedTreatment from GMA's RequestConfiguration.
  // (No import of the InMobi adapter — it is a zero-API stub on the Dart side.)

  // Step 6: Initialize Google Mobile Ads SDK — AFTER all child-directed flags above.
  await MobileAds.instance.initialize();
}
