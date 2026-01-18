# Feature 01: Visual Knowledge Graph

## Usage
When viewing a RAG response with multiple citations, the user can tap a "Graph View" icon. This transitions the screen to an interactive 2D/3D force-directed graph. Central nodes represent the core answer concepts, linked to peripheral nodes representing source documents. Tapping a node expands a snippet or navigates to the source inspector.

## Specification
- **Library:** `graphview` or `flutter_force_directed_graph`.
- **Input:** List of `Citation` objects from the RAG response.
- **Interaction:** Pinch-zoom, drag nodes, tap to inspect.
- **Transition:** Hero animation from the text citation to the graph node.

## Skeleton Code

```dart
import 'package:graphview/GraphView.dart';

class KnowledgeGraphView extends StatefulWidget {
  final List<Citation> citations;
  const KnowledgeGraphView({required this.citations});

  @override
  _KnowledgeGraphViewState createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView> {
  final Graph graph = Graph()..isTree = false;
  final BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  void _buildGraph() {
    final centerNode = Node.Id("Answer");
    for (var c in widget.citations) {
      final node = Node.Id(c.documentTitle);
      graph.addEdge(centerNode, node);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: EdgeInsets.all(100),
      minScale: 0.01,
      maxScale: 5.6,
      child: GraphView(
        graph: graph,
        algorithm: FruchtermanReingoldAlgorithm(),
        builder: (Node node) {
            var id = node.key!.value as String;
            return Chip(label: Text(id));
        },
      ),
    );
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** Moderate. Graph layout algorithms can be expensive on the UI thread for large datasets. Suggest running layout logic in an `Isolate`.
**Novelty:** High. Most RAG clients only show list citations.

### Skeptic Review (Product)
**Critique:** "Looks cool, but is it useful?" Users usually just want the answer. This might be a 'demo feature' that gets used once and ignored. Ensure it solves a real problem (e.g., finding conflicting sources).
