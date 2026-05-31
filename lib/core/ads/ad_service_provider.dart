import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_service.dart';
import 'stub_ad_service.dart';

/// The COPPA walled garden (COMP-03). In v1 this provider returns ONLY the
/// no-op [StubAdService] — there is no compile-time path to a real AdMob
/// service. Do NOT import `google_mobile_ads` or any AdMob service here, and do
/// NOT call any preload routine. The real ad service is introduced in v2.
final adServiceProvider = Provider<AdService>((ref) => const StubAdService());
