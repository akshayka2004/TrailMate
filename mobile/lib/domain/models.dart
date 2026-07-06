// Plain domain models mirroring the backend schemas.

class Building {
  final int id;
  final String name;
  final String? description;
  final double lat;
  final double lng;

  Building({
    required this.id,
    required this.name,
    this.description,
    required this.lat,
    required this.lng,
  });

  factory Building.fromJson(Map<String, dynamic> j) => Building(
        id: j['id'] as int,
        name: j['name'] as String,
        description: j['description'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'lat': lat,
        'lng': lng,
      };
}

class Room {
  final int id;
  final String name;
  final String type;
  final int floor;
  final int buildingId;

  Room({
    required this.id,
    required this.name,
    required this.type,
    required this.floor,
    required this.buildingId,
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as int,
        name: j['name'] as String,
        type: j['type'] as String,
        floor: j['floor'] as int,
        buildingId: j['building_id'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'floor': floor,
        'building_id': buildingId,
      };
}

class Department {
  final int id;
  final String name;
  final int buildingId;

  Department({required this.id, required this.name, required this.buildingId});

  factory Department.fromJson(Map<String, dynamic> j) => Department(
        id: j['id'] as int,
        name: j['name'] as String,
        buildingId: j['building_id'] as int,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'building_id': buildingId};
}

class Checkpoint {
  final int id;
  final String label;
  final double lat;
  final double lng;
  final int? buildingId;

  Checkpoint({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    this.buildingId,
  });

  factory Checkpoint.fromJson(Map<String, dynamic> j) => Checkpoint(
        id: j['id'] as int,
        label: j['label'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        buildingId: j['building_id'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lng': lng,
        'building_id': buildingId,
      };
}

class RouteStep {
  final int checkpointId;
  final String label;
  final double lat;
  final double lng;

  RouteStep({
    required this.checkpointId,
    required this.label,
    required this.lat,
    required this.lng,
  });

  factory RouteStep.fromJson(Map<String, dynamic> j) => RouteStep(
        checkpointId: j['checkpoint_id'] as int,
        label: j['label'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}

class RouteResult {
  final List<RouteStep> steps;
  final double totalDistanceMeters;
  final int totalTimeSeconds;

  RouteResult({
    required this.steps,
    required this.totalDistanceMeters,
    required this.totalTimeSeconds,
  });

  factory RouteResult.fromJson(Map<String, dynamic> j) => RouteResult(
        steps: (j['steps'] as List)
            .map((e) => RouteStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalDistanceMeters: (j['total_distance_meters'] as num).toDouble(),
        totalTimeSeconds: j['total_time_seconds'] as int,
      );
}

/// A searchable destination resolved to its nearest checkpoint.
class SearchHit {
  final String title;
  final String subtitle;
  final double lat;
  final double lng;

  SearchHit({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });
}
