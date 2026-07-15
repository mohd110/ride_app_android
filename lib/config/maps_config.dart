import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Maps / Directions API key, loaded from the `.env` file (see
/// `main()`, which loads it before anything touches this) rather than
/// hardcoded — keeps the real key out of source control (`.env` is
/// gitignored; `.env.example` documents the required variable name).
/// Must have both "Maps SDK for Android" and "Directions API" enabled in
/// Google Cloud Console for this key's project — the Directions API returns
/// REQUEST_DENIED otherwise, and the map tiles themselves fail to load
/// without the Maps SDK enabled.
class MapsConfig {
  static String get apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
}
