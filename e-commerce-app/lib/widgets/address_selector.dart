import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddressSelector extends StatefulWidget {
  final Function(Map<String, String>) onAddressChanged;
  final Map<String, String>? initialAddress;

  const AddressSelector({
    Key? key,
    required this.onAddressChanged,
    this.initialAddress,
  }) : super(key: key);

  @override
  State<AddressSelector> createState() => _AddressSelectorState();
}

class _AddressSelectorState extends State<AddressSelector> {
  Map<String, dynamic> _locationData = {};
  bool _isLoading = true;

  String? _selectedRegionCode;
  String? _selectedProvince;
  String? _selectedMunicipality;
  String? _selectedBarangay;

  List<String> _municipalities = [];
  List<String> _barangays = [];

  final TextEditingController _streetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocationData();

    if (widget.initialAddress != null) {
      _streetController.text = widget.initialAddress!['street'] ?? '';
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('philippine_dataset.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;

      setState(() {
        _locationData = data;
        
        // Populate municipalities from PANGASINAN province only
        Set<String> pangasinanMunicipalities = {};
        for (var regionCode in data.keys) {
          final regionData = data[regionCode];
          if (regionData != null && regionData['province_list'] != null) {
            final provinces = regionData['province_list'] as Map<String, dynamic>;
            // Only get municipalities from Pangasinan province
            if (provinces.containsKey('PANGASINAN')) {
              final pangasinanData = provinces['PANGASINAN'];
              if (pangasinanData != null && pangasinanData['municipality_list'] != null) {
                final municipalities = pangasinanData['municipality_list'] as Map<String, dynamic>;
                pangasinanMunicipalities.addAll(municipalities.keys);
              }
            }
          }
        }
        _municipalities = pangasinanMunicipalities.toList()..sort();
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading location data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMunicipalityChanged(String? municipality) {
    if (municipality == null) return;

    setState(() {
      _selectedMunicipality = municipality;
      _selectedBarangay = null;

      // Find barangays for the selected municipality in Pangasinan province only
      Set<String> foundBarangays = {};
      for (var regionCode in _locationData.keys) {
        final regionData = _locationData[regionCode];
        if (regionData != null && regionData['province_list'] != null) {
          final provinces = regionData['province_list'] as Map<String, dynamic>;
          // Only search in Pangasinan province
          if (provinces.containsKey('PANGASINAN')) {
            final pangasinanData = provinces['PANGASINAN'];
            if (pangasinanData != null && pangasinanData['municipality_list'] != null) {
              final municipalities = pangasinanData['municipality_list'] as Map<String, dynamic>;
              if (municipalities.containsKey(municipality)) {
                final municipalityData = municipalities[municipality];
                if (municipalityData != null && municipalityData['barangay_list'] != null) {
                  foundBarangays.addAll(List<String>.from(municipalityData['barangay_list']));
                  // Store region and province (Pangasinan)
                  _selectedRegionCode = regionCode;
                  _selectedProvince = 'PANGASINAN';
                }
              }
            }
          }
        }
      }
      _barangays = foundBarangays.toList()..sort();
    });

    _notifyAddressChange();
  }

  void _onBarangayChanged(String? barangay) {
    setState(() {
      _selectedBarangay = barangay;
    });

    _notifyAddressChange();
  }

  void _notifyAddressChange() {
    final address = getFullAddress();
    widget.onAddressChanged(address);
  }

  Map<String, String> getFullAddress() {
    String? regionName;
    if (_selectedRegionCode != null) {
      regionName = _locationData[_selectedRegionCode!]['region_name'];
    }

    return {
      'regionCode': _selectedRegionCode ?? '',
      'regionName': regionName ?? '',
      'province': _selectedProvince ?? '',
      'municipality': _selectedMunicipality ?? '',
      'barangay': _selectedBarangay ?? '',
      'street': _streetController.text.trim(),
      'fullAddress': _buildFullAddress(),
    };
  }

  String _buildFullAddress() {
    final parts = <String>[];

    if (_streetController.text.trim().isNotEmpty) {
      parts.add(_streetController.text.trim());
    }
    if (_selectedBarangay != null && _selectedBarangay!.isNotEmpty) {
      parts.add('Brgy. $_selectedBarangay');
    }
    if (_selectedMunicipality != null && _selectedMunicipality!.isNotEmpty) {
      parts.add(_selectedMunicipality!);
    }
    if (_selectedProvince != null && _selectedProvince!.isNotEmpty) {
      parts.add(_selectedProvince!);
    }

    return parts.join(', ');
  }

  bool isComplete() {
    return _selectedMunicipality != null &&
        _selectedBarangay != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Municipality and Barangay
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'City/Municipality *',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  isDense: true,
                ),
                isExpanded: true,
                value: _selectedMunicipality,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: _municipalities.map((municipality) {
                  return DropdownMenuItem(
                    value: municipality,
                    child: Text(municipality, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged:
                    _municipalities.isEmpty ? null : _onMunicipalityChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Barangay *',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  isDense: true,
                ),
                isExpanded: true,
                value: _selectedBarangay,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: _barangays.map((barangay) {
                  return DropdownMenuItem(
                    value: barangay,
                    child: Text(barangay, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _barangays.isEmpty ? null : _onBarangayChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Street/Address field (Optional)
        TextField(
          controller: _streetController,
          decoration: InputDecoration(
            labelText: 'Street/House No. (Optional)',
            labelStyle: const TextStyle(fontSize: 12),
            hintText: 'e.g., #123 Rizal St.',
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            isDense: true,
            prefixIcon: const Icon(Icons.home, size: 20),
          ),
          style: const TextStyle(fontSize: 13),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _notifyAddressChange(),
        ),

        if (_buildFullAddress().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: const Color(0xFF4CAF50).withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on,
                    size: 14, color: const Color(0xFF4CAF50)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _buildFullAddress(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
