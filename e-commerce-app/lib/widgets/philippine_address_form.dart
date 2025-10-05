import 'package:flutter/material.dart';

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
  // Hardcoded values for Mabini, Pangasinan
  final String _region = "REGION I";
  final String _province = "PANGASINAN";
  final String _municipality = "MABINI";
  
  String? selectedBarangay;

  // Barangays in Mabini, Pangasinan
  final List<String> barangays = [
    "BACNIT",
    "BARLO", 
    "CAABIANGAAN",
    "CABANAETAN",
    "CABINUANGAN",
    "CALZADA",
    "CARANGLAAN",
    "DE GUZMAN",
    "LUNA",
    "MAGALONG",
    "NIBALIW",
    "PATAR",
    "POBLACION",
    "SAN PEDRO",
    "TAGUDIN",
    "VILLACORTA"
  ];

  @override
  void initState() {
    super.initState();
    _initializeFromInitialAddress();
  }

  void _initializeFromInitialAddress() {
    if (widget.initialAddress != null) {
      selectedBarangay = widget.initialAddress!['barangay'];
    }
  }

  void _onAddressChange() {
    if (selectedBarangay != null) {
      widget.onAddressSelected({
        'region': _region,
        'province': _province,
        'city': _municipality,
        'barangay': selectedBarangay!,
        'full_address': '$selectedBarangay, $_municipality, $_province, $_region',
      });
    }
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
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
          suffixIcon: Icon(
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
        onChanged: enabled ? onChanged : null,
        validator: widget.isRequired
            ? (value) => value == null ? 'Please select a barangay' : null
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
        // Fixed Municipality Information
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_city, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Municipality Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Province: $_province',
                style: TextStyle(fontSize: 13, color: Colors.green.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                'Municipality: $_municipality',
                style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        // Barangay Dropdown
        Text(
          'Select Barangay*',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 8),
        _buildDropdown<String>(
          hint: 'Choose your barangay',
          value: selectedBarangay,
          items: barangays,
          onChanged: (String? newValue) {
            setState(() => selectedBarangay = newValue);
            _onAddressChange();
          },
        ),
      ],
    );
  }
}
