# Timespan Feature - Quick Reference Guide

## 🎯 What Was Added
A new **Product Timespan** field in the Add Product screen to specify shelf life for perishable products.

## 📍 Location in UI
**Add Product Screen** → After "Date of Harvest" → Before "Submit Product"

## ⚙️ How It Works

### Input Fields
```
Timespan Value: [________]  [Hours/Days dropdown]
```

### Options
- **Unit**: Hours or Days
- **Value**: Any positive number
- **Required**: No (optional field)

## 💾 What Gets Saved
When a product is created with timespan, Firestore stores:
```json
{
  "timespan": 24,
  "timespanUnit": "Hours"
}
```

## 📝 Common Use Cases

| Product Type | Timespan | Reason |
|--------------|----------|--------|
| Fresh Vegetables | 5-7 Days | Wilting and decay |
| Meat/Fish | 24-48 Hours | Spoilage risk |
| Dairy Products | 7-14 Days | Expiration date |
| Eggs | 21-28 Days | Shelf stable longer |
| Fruits | 3-7 Days | Ripening and decay |
| Bread | 2-3 Days | Mold growth |
| Grains | 30+ Days | Long shelf life |

## 🔧 Code Reference

### State Variables
```dart
final _timespanController = TextEditingController();
String _selectedTimespanUnit = 'Hours';
final List<String> _timespanUnits = ['Hours', 'Days'];
```

### Saving to Firestore
```dart
'timespan': _timespanController.text.isNotEmpty
    ? int.tryParse(_timespanController.text)
    : null,
'timespanUnit': _selectedTimespanUnit,
```

## 🎨 UI Features
- ✅ Info banner explaining the feature
- ✅ Dual input (value + unit selector)
- ✅ Example helper text with common scenarios
- ✅ Orange color theme for perishable products
- ✅ Responsive design for all screen sizes

## ✅ Backwards Compatible
- Existing products unaffected
- New field is optional
- No database migration needed
- Works with all product types

## 🚀 Next Steps (Future Implementation)
1. Display timespan on product details
2. Show freshness badge on product cards
3. Calculate remaining shelf life
4. Warn buyers about near-expiry items
5. Suggest discounts for near-expiry products

## 📱 Integration Examples

### Example 1: Display on Product Details
```dart
if (product['timespan'] != null) {
  Text('Fresh for: ${product['timespan']} ${product['timespanUnit']}')
}
```

### Example 2: Show Freshness Badge
```dart
Chip(
  label: Text('Fresh for ${product['timespan']}${product['timespanUnit'] == 'Hours' ? 'h' : 'd'}'),
  backgroundColor: Colors.orange.shade100,
)
```

### Example 3: Calculate Expiry Date
```dart
if (product['harvestDate'] != null && product['timespan'] != null) {
  DateTime expiryDate = product['harvestDate'].toDate();
  if (product['timespanUnit'] == 'Hours') {
    expiryDate = expiryDate.add(Duration(hours: product['timespan']));
  } else {
    expiryDate = expiryDate.add(Duration(days: product['timespan']));
  }
  // Use expiryDate for calculations
}
```

## 🔍 Verification

After implementing, verify:
1. ✅ Timespan field appears in add product screen
2. ✅ Can select Hours or Days
3. ✅ Can enter numeric values
4. ✅ Product saves with timespan data
5. ✅ Firestore contains correct data
6. ✅ Non-perishable products work without timespan
7. ✅ Form validates properly

## 📊 Database Schema

**Products Collection**
```
products/
  ├─ productId
  │  ├─ name: "Fresh Tomatoes"
  │  ├─ price: 50
  │  ├─ timespan: 7          ← NEW
  │  ├─ timespanUnit: "Days"  ← NEW
  │  ├─ harvestDate: Timestamp
  │  └─ ... other fields
```

## 🎓 Learning Resources

- **File Location**: `lib/screens/seller/add_product_screen.dart`
- **Lines Added**: ~39-41 (state), ~478-480 (data), ~1343-1420 (UI)
- **Documentation**: `TIMESPAN_FEATURE_IMPLEMENTATION.md`

## ❓ FAQ

**Q: Is timespan required?**
A: No, it's optional. Leave blank for non-perishable items.

**Q: Can I change units?**
A: Yes! Use the dropdown to switch between Hours and Days.

**Q: Will this affect existing products?**
A: No! Existing products without timespan continue to work normally.

**Q: How is this different from harvest date?**
A: Harvest date is WHEN the product was harvested. Timespan is HOW LONG it stays fresh.

**Q: Can I set it to 0?**
A: Technically yes, but it doesn't make practical sense. Use at least 1.

## 📞 Support

For issues or questions:
1. Check `TIMESPAN_FEATURE_IMPLEMENTATION.md` for detailed docs
2. Review code comments in `add_product_screen.dart`
3. Verify Firestore data structure
4. Check Flutter TextFormField documentation

---

**Status**: ✅ Implementation Complete and Ready to Use
