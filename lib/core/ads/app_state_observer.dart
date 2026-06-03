// Thin re-export so app.dart can subscribe to AppStateEventNotifier
// without importing google_mobile_ads directly.
// The google_mobile_ads import stays inside the lib/core/ads/ walled garden.
export 'package:google_mobile_ads/google_mobile_ads.dart'
    show AppStateEventNotifier, AppState;
