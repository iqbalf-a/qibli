# Qibli — Flutter

Muslim prayer companion app. Reference UI/features: `D:\github-repos\qibli-expo`.

## Code Formatting

### Widget parameters — satu parameter per baris

Setiap widget dengan lebih dari satu parameter harus ditulis multi-line, satu parameter per baris.

```dart
// ❌ Jangan
Text('Dhuhr', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))

// ✓ Harus
Text(
  'Dhuhr',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
)
```

Berlaku untuk semua widget dan constructor call di seluruh project.
