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
        // Row 1: Region and Province
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Region *',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  isDense: true,
                ),
                isExpanded: true,
                value: _selectedRegionCode,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: _regionCodes.map((code) {
                  final regionName = _locationData[code]['region_name'] ?? code;
                  return DropdownMenuItem(
                    value: code,
                    child: Text(regionName, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _onRegionChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Province *',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  isDense: true,
                ),
                isExpanded: true,
                value: _selectedProvince,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: _provinces.map((province) {
                  return DropdownMenuItem(
                    value: province,
                    child: Text(province, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _provinces.isEmpty ? null : _onProvinceChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: Municipality and Barangay
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
