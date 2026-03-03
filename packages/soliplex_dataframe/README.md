# soliplex_dataframe

A pure Dart DataFrame engine providing a familiar, pandas-like API for in-memory data manipulation. It includes a handle-based registry for managing DataFrame instances, facilitating interoperability with external runtimes in Soliplex.

## Quick Start

```bash
cd packages/soliplex_dataframe
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Core

- `DataFrame` -- An immutable, in-memory data table backed by a `List<Map<String, dynamic>>`. It provides a rich API for common data manipulation tasks like filtering, sorting, selecting, grouping, and aggregation.
- `DfRegistry` -- A handle-based storage and management system for `DataFrame` instances. It allows DataFrames to be created, retrieved, and disposed of using integer handles, which is essential for communication with external language runtimes that cannot directly manage Dart objects.

## Dependencies

- `meta` -- Provides annotations like `@immutable` to improve code analysis and clarity.

## Example

```dart
import 'package:soliplex_dataframe/soliplex_dataframe.dart';

void main() {
  // The registry manages DataFrames using integer handles.
  final registry = DfRegistry();

  // Create a DataFrame from a list of maps.
  final data = [
    {'city': 'New York', 'temperature': 15.2, 'humidity': 65},
    {'city': 'London', 'temperature': 8.5, 'humidity': 81},
    {'city': 'Tokyo', 'temperature': 18.3, 'humidity': 70},
    {'city': 'Sydney', 'temperature': 22.1, 'humidity': 55},
  ];

  final dfHandle = registry.create(data);
  final df = registry.get(dfHandle);

  // Filter for cities with temperature above 15 degrees.
  final warmCities = df.filter('temperature', '>', 15);

  // Select specific columns and print the result as a CSV string.
  final result = warmCities.select(['city', 'temperature']);

  print(result.toCsv());
}
```
