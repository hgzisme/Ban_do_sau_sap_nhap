enum MapDetailLevel { provinces, communes }

class MapZoomThresholds {
  static const double defaultZoomLevel = 1.0;
  static const double minZoomLevel = 1.0;
  static const double maxZoomLevel = 9.0;
  static const double zoomInToCommunes = 5.5;
  static const double zoomOutToProvinces = 4.8;
  static const double focusZoomProvince = 6.5;
  static const double focusZoomCommune = 8.5;
  static const Duration viewportDebounce = Duration(milliseconds: 350);
  static const double viewportBufferDegrees = 0.15;
}
