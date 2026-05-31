import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Initializes the AdMob SDK with child-directed flags for COPPA compliance.
///
/// Must be called before [runApp] in main(). The mandatory COPPA init sequence
/// (per RESEARCH.md §AdMob COPPA Initialization and CONTEXT.md D-M04) is:
///   1. updateRequestConfiguration (child-directed flags) — BEFORE initialize()
///   2. MobileAds.instance.initialize() — LAST
///
/// Note: Mediation SDK COPPA flag calls are omitted in v1 — no mediation SDKs
/// are present (gma_mediation_* packages are v2 scope only).
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

  // Step 2: Initialize Google Mobile Ads SDK — AFTER all child-directed flags above.
  await MobileAds.instance.initialize();
}
