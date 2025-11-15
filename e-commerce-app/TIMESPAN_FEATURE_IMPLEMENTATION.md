# Timespan Feature for Perishable Products

## Overview
The Timespan feature has been implemented to help sellers indicate the shelf life of perishable products. This allows buyers to understand how long products will remain fresh after purchase and helps optimize inventory management.

## Feature Specifications

### ✨ What's New

#### Added to Add Product Screen
- **Timespan Value Input**: Numeric field to enter the duration
- **Timespan Unit Selector**: Dropdown to select between "Hours" or "Days"
- **Optional Field**: Not required, but recommended for perishable items
- **User-Friendly Interface**: Clear instructions and examples

### 📊 UI Components

#### Timespan Input Section
```
┌─────────────────────────────────────────────┐
│ 📋 Product Timespan (Optional)              │
├─────────────────────────────────────────────┤
│                                             │
│  [Timespan Value Input] [Hours/Days Dropdown]│
│                                             │
│  💡 Example: "24" + "Hours" or "7" + "Days" │
│                                             │
└─────────────────────────────────────────────┘
```

#### Info Banner
- Orange-themed information box before the input section
- Clear message: "Add timespan to indicate shelf life for perishable products"
- Visual icon (ℹ️) for better UX

## Implementation Details

### 1. State Variables Added
```dart
// Timespan for perishable products
final _timespanController = TextEditingController();
String _selectedTimespanUnit = 'Hours';
final List<String> _timespanUnits = ['Hours', 'Days'];
```

### 2. Product Data Storage
When submitting a product, the timespan is stored as:
```dart
'timespan': _timespanController.text.isNotEmpty
    ? int.tryParse(_timespanController.text)
    : null,
'timespanUnit': _selectedTimespanUnit,
```

### 3. Firestore Schema Update
**Products Collection** now includes:
```
{
  ...existing fields...
  "timespan": 24,                    // Optional - numeric value
  "timespanUnit": "Hours",           // Optional - "Hours" or "Days"
  "harvestDate": Timestamp,          // Existing field
  "createdAt": Timestamp,            // Existing field
}
```

### 4. UI Features
- **Value Input**: TextFormField with number keyboard
- **Unit Selector**: DropdownButtonFormField with Hours/Days options
- **Example Display**: Helpful tip showing common use cases
- **Responsive Design**: Works on all screen sizes
- **Color Scheme**: Orange theme for perishable products context

## Usage Examples

### Example 1: Leafy Vegetables
```
Timespan Value: 5
Timespan Unit: Days
Interpretation: Product stays fresh for 5 days
```

### Example 2: Fresh Meat/Fish
```
Timespan Value: 24
Timespan Unit: Hours
Interpretation: Product must be used within 24 hours
```

### Example 3: Dairy Products
```
Timespan Value: 7
Timespan Unit: Days
Interpretation: Product stays fresh for 1 week
```

### Example 4: Non-Perishable Items
```
Timespan Value: (empty)
Timespan Unit: (default)
Interpretation: No expiration concern, product is non-perishable
```

## File Structure

### Modified Files
- **Location**: `lib/screens/seller/add_product_screen.dart`
- **Changes**:
  - Added 3 new state variables for timespan
  - Added timespan data to product submission
  - Added UI section with input field and dropdown
  - Info banner for user guidance

### Lines Modified
- **State Variables**: Lines 39-41
- **Product Data**: Lines ~478-480 (added 'timespan' and 'timespanUnit')
- **UI Section**: Lines ~1343-1420 (new timespan input section)

## Integration Points

### 1. Product Details Display
To show timespan on product details screen:
```dart
if (product['timespan'] != null) {
  Text('Fresh for: ${product['timespan']} ${product['timespanUnit']}')
}
```

### 2. Product Freshness Calculation
Calculate expiry from harvest date:
```dart
if (product['harvestDate'] != null && product['timespan'] != null) {
  DateTime expiryDate = product['harvestDate'].toDate();
  if (product['timespanUnit'] == 'Hours') {
    expiryDate = expiryDate.add(Duration(hours: product['timespan']));
  } else {
    expiryDate = expiryDate.add(Duration(days: product['timespan']));
  }
}
```

### 3. Product Browse Screen
Show freshness indicator in buyer product list:
```dart
if (product['timespan'] != null) {
  // Display freshness badge
  Chip(
    label: Text('Fresh for ${product['timespan']}${product['timespanUnit'] == 'Hours' ? 'h' : 'd'}'),
    backgroundColor: Colors.orange.shade100,
  )
}
```

## Data Validation

### Input Validation
- ✅ Timespan value: Positive integer or empty
- ✅ Timespan unit: Must be "Hours" or "Days"
- ✅ Optional field: Can be left empty for non-perishable items

### Firestore Storage
- Timespan stored as integer (number of hours/days)
- TimespanUnit stored as string ("Hours" or "Days")
- Both fields nullable for backwards compatibility

## Backwards Compatibility

✅ **Fully Backwards Compatible**
- Existing products without timespan will work normally
- New field is optional (null)
- No migration needed
- Filtering/queries unaffected

## Testing Checklist

- [ ] Add product with timespan in Hours
- [ ] Add product with timespan in Days
- [ ] Add product without timespan
- [ ] Verify data saved correctly in Firestore
- [ ] Verify UI displays properly on different screen sizes
- [ ] Verify dropdown changes between Hours/Days
- [ ] Verify input validation (numbers only)
- [ ] Verify product can be submitted without timespan
- [ ] Verify product can be submitted with timespan
- [ ] Verify existing products unaffected

## Future Enhancements

### Phase 2 - Display Features
- [ ] Show freshness indicator on product card
- [ ] Calculate remaining shelf life from harvest date
- [ ] Display warning for near-expiry products
- [ ] Add freshness badge/ribbon to product image

### Phase 3 - Advanced Features
- [ ] Automatic product expiry/removal after timespan
- [ ] Buyer notifications when product near expiry
- [ ] Discount suggestions for near-expiry products
- [ ] Product freshness analytics for sellers

### Phase 4 - Seller Dashboard
- [ ] Show products by freshness status
- [ ] Alert for soon-to-expire items
- [ ] Inventory management by expiry date
- [ ] Historical freshness metrics

## Query Examples

### Firestore Queries

#### Get all products with timespan defined
```dart
_firestore.collection('products')
  .where('timespan', isNotEqualTo: null)
  .get()
```

#### Get all perishable products (hours-based)
```dart
_firestore.collection('products')
  .where('timespanUnit', isEqualTo: 'Hours')
  .get()
```

#### Get all long-lasting products (days-based)
```dart
_firestore.collection('products')
  .where('timespanUnit', isEqualTo: 'Days')
  .where('timespan', isGreaterThan: 7)
  .get()
```

## Troubleshooting

### Issue: Timespan not saving
**Solution**: Ensure the controller is properly bound and form is validated

### Issue: Dropdown not changing
**Solution**: Check setState is being called in onChanged handler

### Issue: Input not accepting numbers
**Solution**: Verify keyboardType is set to TextInputType.number

## Support & Documentation

### Related Files
- `lib/screens/seller/add_product_screen.dart` - Main implementation
- `FRESHNESS_SYSTEM_IMPLEMENTATION.md` - Freshness calculation guide
- `lib/models/freshness_model.dart` - Freshness model (if exists)
- `lib/services/freshness_service.dart` - Freshness service (if exists)

### Additional Resources
- Firebase Firestore documentation for custom fields
- Flutter TextFormField documentation
- Flutter DropdownButtonFormField documentation

## Summary

The Timespan feature provides sellers with an easy way to specify shelf life for perishable products. It's:
- ✅ Easy to use
- ✅ Optional for non-perishable items
- ✅ Flexible (hours or days)
- ✅ Backwards compatible
- ✅ Ready for future enhancements

This feature forms the foundation for implementing automated freshness calculations and buyer notifications about product shelf life.
