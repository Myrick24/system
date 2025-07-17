import 'package:flutter/material.dart';
import '../services/location_service.dart';

class PhilippineAddressForm extends StatefulWidget {
  final Function(Map<String, String>) onAddressSelected;
  final Map<String, String>? initialAddress;
  final bool isRequired;

  const PhilippineAddressForm({
    Key? key,
    required this.onAddressSelected,
    this.initialAddress,
    this.isRequired = true,
  }) : super(key: key);

  @override
  _PhilippineAddressFormState createState() => _PhilippineAddressFormState();
}

class _PhilippineAddressFormState extends State<PhilippineAddressForm> {
  String? selectedRegion;
  String? selectedProvince;
  String? selectedCity;
  String? selectedBarangay;

  List<String> regions = [];
  List<String> provinces = [];
  List<String> cities = [];
  List<String> barangays = [];

  bool isLoadingRegions = true;
  bool isLoadingProvinces = false;
  bool isLoadingCities = false;
  bool isLoadingBarangays = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _initializeFromInitialAddress();
  }

  void _initializeFromInitialAddress() {
    if (widget.initialAddress != null) {
      selectedRegion = widget.initialAddress!['region'];
      selectedProvince = widget.initialAddress!['province'];
      selectedCity = widget.initialAddress!['city'];
      selectedBarangay = widget.initialAddress!['barangay'];
    }
  }

  Future<void> _loadRegions() async {
    setState(() => isLoadingRegions = true);
    try {
      final loadedRegions = await LocationService.getRegions();
      setState(() {
        regions = loadedRegions;
        isLoadingRegions = false;
      });

      // If we have an initial region, load its provinces
      if (selectedRegion != null && regions.contains(selectedRegion)) {
        await _loadProvinces(selectedRegion!);
      }
    } catch (e) {
      setState(() => isLoadingRegions = false);
      _showError('Failed to load regions: $e');
    }
  }

  Future<void> _loadProvinces(String region) async {
    setState(() {
      isLoadingProvinces = true;
      selectedProvince = null;
      selectedCity = null;
      selectedBarangay = null;
      provinces.clear();
      cities.clear();
      barangays.clear();
    });

    try {
      final loadedProvinces = await LocationService.getProvinces(region);
      setState(() {
        provinces = loadedProvinces;
        isLoadingProvinces = false;
      });

      // If we have an initial province, load its cities
      if (selectedProvince != null && provinces.contains(selectedProvince)) {
        await _loadCities(region, selectedProvince!);
      }
    } catch (e) {
      setState(() => isLoadingProvinces = false);
      _showError('Failed to load provinces: $e');
    }
  }

  Future<void> _loadCities(String region, String province) async {
    setState(() {
      isLoadingCities = true;
      selectedCity = null;
      selectedBarangay = null;
      cities.clear();
      barangays.clear();
    });

    try {
      final loadedCities =
          await LocationService.getCitiesMunicipalities(region, province);
      setState(() {
        cities = loadedCities;
        isLoadingCities = false;
      });

      // If we have an initial city, load its barangays
      if (selectedCity != null && cities.contains(selectedCity)) {
        await _loadBarangays(region, province, selectedCity!);
      }
    } catch (e) {
      setState(() => isLoadingCities = false);
      _showError('Failed to load cities/municipalities: $e');
    }
  }

  Future<void> _loadBarangays(
      String region, String province, String city) async {
    setState(() {
      isLoadingBarangays = true;
      selectedBarangay = null;
      barangays.clear();
    });

    try {
      final loadedBarangays =
          await LocationService.getBarangays(region, province, city);
      setState(() {
        barangays = loadedBarangays;
        isLoadingBarangays = false;
      });
    } catch (e) {
      setState(() => isLoadingBarangays = false);
      _showError('Failed to load barangays: $e');
    }
  }

  void _onAddressChange() {
    if (selectedRegion != null &&
        selectedProvince != null &&
        selectedCity != null &&
        selectedBarangay != null) {
      widget.onAddressSelected({
        'region': selectedRegion!,
        'province': selectedProvince!,
        'city': selectedCity!,
        'barangay': selectedBarangay!,
        'full_address':
            '$selectedBarangay, $selectedCity, $selectedProvince, $selectedRegion',
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    bool isLoading = false,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.green.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.green.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.green.shade600, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    ),
                  ),
                )
              : Icon(
                  Icons.arrow_drop_down,
                  color: enabled ? Colors.green.shade600 : Colors.grey.shade400,
                ),
        ),
        items: enabled
            ? items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    item.toString(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList()
            : [],
        onChanged: enabled && !isLoading ? onChanged : null,
        validator: widget.isRequired
            ? (value) => value == null ? 'This field is required' : null
            : null,
        style: TextStyle(color: Colors.green.shade800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Region Dropdown
        _buildDropdown<String>(
          hint: 'Select Region',
          value: selectedRegion,
          items: regions,
          isLoading: isLoadingRegions,
          onChanged: (String? newValue) {
            setState(() => selectedRegion = newValue);
            if (newValue != null) {
              _loadProvinces(newValue);
            }
          },
        ),

        // Province Dropdown
        _buildDropdown<String>(
          hint: 'Select Province',
          value: selectedProvince,
          items: provinces,
          isLoading: isLoadingProvinces,
          enabled: selectedRegion != null,
          onChanged: (String? newValue) {
            setState(() => selectedProvince = newValue);
            if (newValue != null && selectedRegion != null) {
              _loadCities(selectedRegion!, newValue);
            }
          },
        ),

        // City/Municipality Dropdown
        _buildDropdown<String>(
          hint: 'Select City/Municipality',
          value: selectedCity,
          items: cities,
          isLoading: isLoadingCities,
          enabled: selectedProvince != null,
          onChanged: (String? newValue) {
            setState(() => selectedCity = newValue);
            if (newValue != null &&
                selectedRegion != null &&
                selectedProvince != null) {
              _loadBarangays(selectedRegion!, selectedProvince!, newValue);
            }
          },
        ),

        // Barangay Dropdown
        _buildDropdown<String>(
          hint: 'Select Barangay',
          value: selectedBarangay,
          items: barangays,
          isLoading: isLoadingBarangays,
          enabled: selectedCity != null,
          onChanged: (String? newValue) {
            setState(() => selectedBarangay = newValue);
            _onAddressChange();
          },
        ),
      ],
    );
  }
}
