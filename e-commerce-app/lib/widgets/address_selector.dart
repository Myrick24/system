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

  List<String> _regionCodes = [];
  List<String> _provinces = [];
  List<String> _municipalities = [];
  List<String> _barangays = [];

  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _houseNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocationData();

    if (widget.initialAddress != null) {
      _streetController.text = widget.initialAddress!['street'] ?? '';
      _houseNumberController.text = widget.initialAddress!['houseNumber'] ?? '';
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _houseNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('philippine_dataset.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;

      setState(() {
        _locationData = data;
        _regionCodes = data.keys.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading location data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onRegionChanged(String? regionCode) {
    if (regionCode == null) return;

    setState(() {
      _selectedRegionCode = regionCode;
      _selectedProvince = null;
      _selectedMunicipality = null;
      _selectedBarangay = null;

      final regionData = _locationData[regionCode];
      if (regionData != null && regionData['province_list'] != null) {
        _provinces = (regionData['province_list'] as Map<String, dynamic>)
            .keys
            .toList()
          ..sort();
      } else {
        _provinces = [];
      }
      _municipalities = [];
      _barangays = [];
    });

    _notifyAddressChange();
  }

  void _onProvinceChanged(String? province) {
    if (province == null || _selectedRegionCode == null) return;

    setState(() {
      _selectedProvince = province;
      _selectedMunicipality = null;
      _selectedBarangay = null;

      final provinceData =
          _locationData[_selectedRegionCode!]['province_list'][province];
      if (provinceData != null && provinceData['municipality_list'] != null) {
        _municipalities = (provinceData['municipality_list']
                as Map<String, dynamic>)
            .keys
            .toList()
          ..sort();
      } else {
        _municipalities = [];
      }
      _barangays = [];
    });

    _notifyAddressChange();
  }

  void _onMunicipalityChanged(String? municipality) {
    if (municipality == null ||
        _selectedRegionCode == null ||
        _selectedProvince == null) return;

    setState(() {
      _selectedMunicipality = municipality;
      _selectedBarangay = null;

      final municipalityData = _locationData[_selectedRegionCode!]
              ['province_list'][_selectedProvince!]['municipality_list']
          [municipality];
      if (municipalityData != null &&
          municipalityData['barangay_list'] != null) {
        _barangays = List<String>.from(municipalityData['barangay_list'])
          ..sort();
      } else {
        _barangays = [];
      }
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
      'houseNumber': _houseNumberController.text.trim(),
      'fullAddress': _buildFullAddress(),
    };
  }

  String _buildFullAddress() {
    final parts = <String>[];

    if (_houseNumberController.text.trim().isNotEmpty) {
      parts.add(_houseNumberController.text.trim());
    }
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
    return _selectedRegionCode != null &&
        _selectedProvince != null &&
        _selectedMunicipality != null &&
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
        // Region Dropdown
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Region *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.map),
          ),
          value: _selectedRegionCode,
          items: _regionCodes.map((code) {
            final regionName = _locationData[code]['region_name'] ?? code;
            return DropdownMenuItem(
              value: code,
              child: Text(regionName),
            );
          }).toList(),
          onChanged: _onRegionChanged,
        ),
        const SizedBox(height: 12),

        // Province Dropdown
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Province *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_city),
          ),
          value: _selectedProvince,
          items: _provinces.map((province) {
            return DropdownMenuItem(
              value: province,
              child: Text(province),
            );
          }).toList(),
          onChanged: _provinces.isEmpty ? null : _onProvinceChanged,
        ),
        const SizedBox(height: 12),

        // Municipality/City Dropdown
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Municipality/City *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          value: _selectedMunicipality,
          items: _municipalities.map((municipality) {
            return DropdownMenuItem(
              value: municipality,
              child: Text(municipality),
            );
          }).toList(),
          onChanged: _municipalities.isEmpty ? null : _onMunicipalityChanged,
        ),
        const SizedBox(height: 12),

        // Barangay Dropdown
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Barangay *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.house),
          ),
          value: _selectedBarangay,
          items: _barangays.map((barangay) {
            return DropdownMenuItem(
              value: barangay,
              child: Text(barangay),
            );
          }).toList(),
          onChanged: _barangays.isEmpty ? null : _onBarangayChanged,
        ),
        const SizedBox(height: 12),

        // Street/Subdivision
        TextField(
          controller: _streetController,
          decoration: const InputDecoration(
            labelText: 'Street/Subdivision (Optional)',
            hintText: 'e.g., Rizal Street',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.signpost),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _notifyAddressChange(),
        ),
        const SizedBox(height: 12),

        // House/Building Number
        TextField(
          controller: _houseNumberController,
          decoration: const InputDecoration(
            labelText: 'House/Building Number (Optional)',
            hintText: 'e.g., #123 or Block 4 Lot 5',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _notifyAddressChange(),
        ),

        if (_buildFullAddress().isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.preview, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Address Preview:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _buildFullAddress(),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
