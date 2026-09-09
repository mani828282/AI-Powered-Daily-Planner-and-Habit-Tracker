import 'api_service.dart';

class LocationData {
  final int locationId;
  final int userId;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String? category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> linkedItems;

  LocationData({
    required this.locationId,
    required this.userId,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.category,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.linkedItems = const [],
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      locationId: json['location_id'],
      userId: json['user_id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      radiusMeters: json['radius_meters'],
      category: json['category'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      linkedItems: List<Map<String, dynamic>>.from(json['linked_items'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'user_id': userId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'category': category,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'linked_items': linkedItems,
    };
  }
}

class LocationManagementService {
  final ApiService _apiService;

  LocationManagementService(this._apiService);

  /// Create a new location
  Future<LocationData?> createLocation({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
    int radiusMeters = 200,
    String? category,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/locations',
        {
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'radius_meters': radiusMeters,
          'category': category,
        },
      );

      return LocationData.fromJson(response);
    } catch (e) {
      // print('Error creating location: $e');
      return null;
    }
  }

  /// Get all user locations
  Future<List<LocationData>> getLocations({bool activeOnly = true}) async {
    try {
      final response = await _apiService.get(
        '/api/locations?active_only=$activeOnly',
      );

      if (response is List) {
        return response.map((json) => LocationData.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      // print('Error getting locations: $e');
      return [];
    }
  }

  /// Get a specific location
  Future<LocationData?> getLocation(int locationId) async {
    try {
      final response = await _apiService.get(
        '/api/locations/$locationId',
      );

      return LocationData.fromJson(response);
    } catch (e) {
      // print('Error getting location: $e');
      return null;
    }
  }

  /// Update a location
  Future<LocationData?> updateLocation({
    required int locationId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    String? category,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> data = {};

      if (name != null) data['name'] = name;
      if (address != null) data['address'] = address;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (radiusMeters != null) data['radius_meters'] = radiusMeters;
      if (category != null) data['category'] = category;
      if (isActive != null) data['is_active'] = isActive;

      final response = await _apiService.put(
        '/api/locations/$locationId',
        data,
      );

      return LocationData.fromJson(response);
    } catch (e) {
      // print('Error updating location: $e');
      return null;
    }
  }

  /// Delete a location
  Future<bool> deleteLocation(int locationId) async {
    try {
      await _apiService.delete('/api/locations/$locationId');
      return true;
    } catch (e) {
      // print('Error deleting location: $e');
      return false;
    }
  }

  /// Link a location to a task, goal, or habit
  Future<bool> linkLocationToItem({
    required int locationId,
    required String itemType, // 'task', 'goal', or 'habit'
    required int itemId,
  }) async {
    try {
      await _apiService.post(
        '/api/locations/$locationId/link',
        {
          'location_id': locationId,
          'item_type': itemType,
          'item_id': itemId,
        },
      );
      return true;
    } catch (e) {
      // print('Error linking location: $e');
      return false;
    }
  }

  /// Unlink a location from an item
  Future<bool> unlinkLocation({
    required String itemType,
    required int itemId,
  }) async {
    try {
      await _apiService.delete('/api/locations/link/$itemType/$itemId');
      return true;
    } catch (e) {
      // print('Error unlinking location: $e');
      return false;
    }
  }

  /// Get locations by category
  Future<List<LocationData>> getLocationsByCategory(String category) async {
    try {
      final allLocations = await getLocations();
      return allLocations
          .where((loc) => loc.category?.toLowerCase() == category.toLowerCase())
          .toList();
    } catch (e) {
      // print('Error getting locations by category: $e');
      return [];
    }
  }

  /// Search locations by name
  Future<List<LocationData>> searchLocations(String query) async {
    try {
      final allLocations = await getLocations();
      final lowerQuery = query.toLowerCase();

      return allLocations
          .where((loc) =>
              loc.name.toLowerCase().contains(lowerQuery) ||
              (loc.address?.toLowerCase().contains(lowerQuery) ?? false))
          .toList();
    } catch (e) {
      // print('Error searching locations: $e');
      return [];
    }
  }
}
