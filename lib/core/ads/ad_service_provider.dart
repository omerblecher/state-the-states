import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_service.dart';
import 'real_ad_service.dart';

/// Phase 8: adServiceProvider now returns RealAdService, which implements all
/// four ad types (banner, interstitial, rewarded, App Open) and calls
/// preloadAll() immediately after construction so ads are ready when needed.
///
/// stub_ad_service.dart is retained for tests — do NOT delete it.
final adServiceProvider = Provider<AdService>((ref) {
  final service = RealAdService(ref);
  service.preloadAll();
  return service;
});
