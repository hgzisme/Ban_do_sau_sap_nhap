/// Geographic bounding box (south-west / north-east).
class GeoBounds {
  final double south;
  final double north;
  final double west;
  final double east;

  const GeoBounds({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
  });

  bool contains(double lat, double lng) {
    return lat >= south && lat <= north && lng >= west && lng <= east;
  }

  bool intersects(GeoBounds other) {
    return south <= other.north &&
        north >= other.south &&
        west <= other.east &&
        east >= other.west;
  }

  GeoBounds expand(double bufferDegrees) {
    return GeoBounds(
      south: south - bufferDegrees,
      north: north + bufferDegrees,
      west: west - bufferDegrees,
      east: east + bufferDegrees,
    );
  }

  static GeoBounds fromPoints(List<({double lat, double lng})> points) {
    if (points.isEmpty) {
      return const GeoBounds(south: 0, north: 0, west: 0, east: 0);
    }
    var south = points.first.lat;
    var north = points.first.lat;
    var west = points.first.lng;
    var east = points.first.lng;
    for (final p in points.skip(1)) {
      if (p.lat < south) south = p.lat;
      if (p.lat > north) north = p.lat;
      if (p.lng < west) west = p.lng;
      if (p.lng > east) east = p.lng;
    }
    return GeoBounds(south: south, north: north, west: west, east: east);
  }
}
