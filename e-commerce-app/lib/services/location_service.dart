import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class LocationService {
  static Map<String, dynamic>? _locationData;
  static bool _isLoaded = false;

  // Load the Philippine location data from JSON file
  static Future<void> _loadLocationData() async {
    if (_isLoaded) return;

    try {
      // Try to load from assets first
      String jsonString =
          await rootBundle.loadString('assets/data/philippine_dataset.json');
      _locationData = json.decode(jsonString);
      _isLoaded = true;
    } catch (e) {
      // If assets don't exist, try to load from the downloaded file
      try {
        final file = File('philippine_dataset.json');
        if (await file.exists()) {
          String jsonString = await file.readAsString();
          _locationData = json.decode(jsonString);
          _isLoaded = true;
        }
      } catch (e) {
        print('Error loading location data: $e');
        // Fallback to basic data if file loading fails
        _loadFallbackData();
      }
    }
  }

  // Fallback data in case the main dataset fails to load
  static void _loadFallbackData() {
    _locationData = {
      "01": {
        "region_name": "REGION I",
        "province_list": {
          "ILOCOS NORTE": {
            "municipality_list": {
              "LAOAG CITY": {
                "barangay_list": ["BARANGAY 1", "BARANGAY 2", "BARANGAY 3"]
              },
              "BATAC CITY": {
                "barangay_list": ["BARANGAY A", "BARANGAY B", "BARANGAY C"]
              }
            }
          },
          "ILOCOS SUR": {
            "municipality_list": {
              "VIGAN CITY": {
                "barangay_list": ["BARANGAY X", "BARANGAY Y", "BARANGAY Z"]
              }
            }
          }
        }
      },
      "NCR": {
        "region_name": "NCR",
        "province_list": {
          "METRO MANILA": {
            "municipality_list": {
              "MANILA CITY": {
                "barangay_list": ["BARANGAY 1", "BARANGAY 2"]
              },
              "QUEZON CITY": {
                "barangay_list": ["BARANGAY A", "BARANGAY B"]
              }
            }
          }
        }
      }
    };
    _isLoaded = true;
  }

  // Get all regions
  static Future<List<String>> getRegions() async {
    await _loadLocationData();
    if (_locationData == null) return [];

    List<String> regions = [];
    _locationData!.forEach((key, value) {
      if (value is Map && value.containsKey('region_name')) {
        regions.add(value['region_name']);
      }
    });
    return regions..sort();
  }

  // Get all provinces in a specific region
  static Future<List<String>> getProvinces(String regionName) async {
    await _loadLocationData();
    if (_locationData == null) return [];

    // Find the region
    String? regionKey;
    _locationData!.forEach((key, value) {
      if (value is Map && value['region_name'] == regionName) {
        regionKey = key;
      }
    });

    if (regionKey == null) return [];

    final regionData = _locationData![regionKey];
    if (regionData['province_list'] == null) return [];

    return (regionData['province_list'] as Map<String, dynamic>).keys.toList()
      ..sort();
  }

  // Get all cities/municipalities in a specific province
  static Future<List<String>> getCitiesMunicipalities(
      String regionName, String provinceName) async {
    await _loadLocationData();
    if (_locationData == null) return [];

    // Find the region
    String? regionKey;
    _locationData!.forEach((key, value) {
      if (value is Map && value['region_name'] == regionName) {
        regionKey = key;
      }
    });

    if (regionKey == null) return [];

    final regionData = _locationData![regionKey];
    final provinceData = regionData['province_list']?[provinceName];
    if (provinceData == null || provinceData['municipality_list'] == null)
      return [];

    return (provinceData['municipality_list'] as Map<String, dynamic>)
        .keys
        .toList()
      ..sort();
  }

  // Get all barangays in a specific city/municipality
  static Future<List<String>> getBarangays(
      String regionName, String provinceName, String cityMunicipality) async {
    await _loadLocationData();
    if (_locationData == null) return [];

    // Find the region
    String? regionKey;
    _locationData!.forEach((key, value) {
      if (value is Map && value['region_name'] == regionName) {
        regionKey = key;
      }
    });

    if (regionKey == null) return [];

    final regionData = _locationData![regionKey];
    final provinceData = regionData['province_list']?[provinceName];
    final cityData = provinceData?['municipality_list']?[cityMunicipality];

    if (cityData == null || cityData['barangay_list'] == null) return [];

    return List<String>.from(cityData['barangay_list'])..sort();
  }

  // Search locations by query
  static Future<List<Map<String, String>>> searchLocations(String query) async {
    await _loadLocationData();
    if (_locationData == null || query.isEmpty) return [];

    List<Map<String, String>> results = [];
    String queryLower = query.toLowerCase();

    _locationData!.forEach((regionKey, regionValue) {
      if (regionValue is! Map) return;

      String regionName = regionValue['region_name'] ?? '';
      Map<String, dynamic> provinces = regionValue['province_list'] ?? {};

      provinces.forEach((provinceName, provinceValue) {
        if (provinceValue is! Map) return;

        Map<String, dynamic> municipalities =
            provinceValue['municipality_list'] ?? {};

        municipalities.forEach((municipalityName, municipalityValue) {
          if (municipalityValue is! Map) return;

          List<dynamic> barangays = municipalityValue['barangay_list'] ?? [];

          // Check if region matches
          if (regionName.toLowerCase().contains(queryLower)) {
            results.add({
              'type': 'region',
              'name': regionName,
              'region': regionName,
              'province': '',
              'city': '',
              'barangay': '',
            });
          }

          // Check if province matches
          if (provinceName.toLowerCase().contains(queryLower)) {
            results.add({
              'type': 'province',
              'name': provinceName,
              'region': regionName,
              'province': provinceName,
              'city': '',
              'barangay': '',
            });
          }

          // Check if municipality matches
          if (municipalityName.toLowerCase().contains(queryLower)) {
            results.add({
              'type': 'city',
              'name': municipalityName,
              'region': regionName,
              'province': provinceName,
              'city': municipalityName,
              'barangay': '',
            });
          }

          // Check barangays
          for (String barangay in barangays) {
            if (barangay.toLowerCase().contains(queryLower)) {
              results.add({
                'type': 'barangay',
                'name': barangay,
                'region': regionName,
                'province': provinceName,
                'city': municipalityName,
                'barangay': barangay,
              });
            }
          }
        });
      });
    });

    // Remove duplicates and limit results
    final seen = <String>{};
    results = results
        .where((item) {
          final key = '${item['type']}_${item['name']}';
          return seen.add(key);
        })
        .take(50)
        .toList();

    return results;
  }

  // Get complete address information
  static Future<Map<String, String>?> getCompleteAddress(
      String region, String province, String city, String barangay) async {
    await _loadLocationData();

    return {
      'region': region,
      'province': province,
      'city': city,
      'barangay': barangay,
      'full_address': '$barangay, $city, $province, $region',
    };
  }

  // Validate if a location combination exists
  static Future<bool> validateLocation(
      String region, String province, String city, String barangay) async {
    await _loadLocationData();
    if (_locationData == null) return false;

    try {
      // Find the region
      String? regionKey;
      _locationData!.forEach((key, value) {
        if (value is Map && value['region_name'] == region) {
          regionKey = key;
        }
      });

      if (regionKey == null) return false;

      final regionData = _locationData![regionKey];
      final provinceData = regionData['province_list']?[province];
      if (provinceData == null) return false;

      final cityData = provinceData['municipality_list']?[city];
      if (cityData == null) return false;

      final barangays = List<String>.from(cityData['barangay_list'] ?? []);
      return barangays.contains(barangay);
    } catch (e) {
      return false;
    }
  }

  // Get statistics about the dataset
  static Future<Map<String, int>> getDatasetStats() async {
    await _loadLocationData();
    if (_locationData == null) return {};

    int regionCount = 0;
    int provinceCount = 0;
    int cityCount = 0;
    int barangayCount = 0;

    _locationData!.forEach((regionKey, regionValue) {
      if (regionValue is! Map) return;

      regionCount++;
      Map<String, dynamic> provinces = regionValue['province_list'] ?? {};

      provinces.forEach((provinceName, provinceValue) {
        if (provinceValue is! Map) return;

        provinceCount++;
        Map<String, dynamic> municipalities =
            provinceValue['municipality_list'] ?? {};

        municipalities.forEach((municipalityName, municipalityValue) {
          if (municipalityValue is! Map) return;

          cityCount++;
          List<dynamic> barangays = municipalityValue['barangay_list'] ?? [];
          barangayCount += barangays.length;
        });
      });
    });

    return {
      'regions': regionCount,
      'provinces': provinceCount,
      'cities': cityCount,
      'barangays': barangayCount,
    };
  }
}
