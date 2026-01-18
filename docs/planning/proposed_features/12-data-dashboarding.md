# Feature 12: Data Dashboarding

## Usage
If the RAG response contains tabular data (CSV/JSON), the app automatically renders it as a Chart (Bar/Line/Pie) instead of a Markdown table.

## Specification
- **Library:** `fl_chart`.
- **Detection:** Regex or structured output parsing to detect data arrays.

## Skeleton Code

```dart
class DataVisualizer extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  
  @override
  Widget build(BuildContext context) {
    if (data.length > 20) return LineChart(...);
    return BarChart(
      BarChartData(
        barGroups: data.map((d) => BarChartGroupData(...)).toList(),
      ),
    );
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Medium. Mapping generic JSON to specific chart axes is tricky ("Auto-analysis").
**Feasibility:** Medium.
**Novelty:** Medium.

### Skeptic Review (Product)
**Critique:** Makes data "pop". Executives love charts.
