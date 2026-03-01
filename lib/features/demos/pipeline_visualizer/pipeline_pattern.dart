// DAG pattern definitions for the Pipeline Visualizer demo.
//
// Each PipelinePattern defines a graph of DagNodes connected by
// DagEdges.  The executionLayers method topologically sorts the
// nodes so the executor knows which can run in parallel.

// ---------------------------------------------------------------------------
// Node status
// ---------------------------------------------------------------------------

enum NodeStatus { pending, running, completed, failed, cancelled }

// ---------------------------------------------------------------------------
// Graph primitives
// ---------------------------------------------------------------------------

class DagNode {
  const DagNode({
    required this.id,
    required this.label,
    required this.roomId,
    this.dependsOn = const [],
  });

  final String id;
  final String label;
  final String roomId;
  final List<String> dependsOn;
}

class DagEdge {
  const DagEdge({required this.from, required this.to});

  final String from;
  final String to;
}

// ---------------------------------------------------------------------------
// Pipeline pattern
// ---------------------------------------------------------------------------

class PipelinePattern {
  const PipelinePattern({
    required this.id,
    required this.name,
    required this.description,
    required this.nodes,
    required this.edges,
  });

  final String id;
  final String name;
  final String description;
  final List<DagNode> nodes;
  final List<DagEdge> edges;

  /// Topological sort into execution layers.
  ///
  /// Nodes in the same layer have no mutual dependencies and can run
  /// in parallel.
  List<List<DagNode>> executionLayers() {
    final remaining = {for (final n in nodes) n.id: n};
    final completed = <String>{};
    final layers = <List<DagNode>>[];

    while (remaining.isNotEmpty) {
      final ready = remaining.values
          .where(
            (n) => n.dependsOn.every(completed.contains),
          )
          .toList();
      if (ready.isEmpty) {
        throw StateError('Cycle detected in DAG');
      }
      layers.add(ready);
      for (final n in ready) {
        completed.add(n.id);
        remaining.remove(n.id);
      }
    }
    return layers;
  }
}

// ---------------------------------------------------------------------------
// Built-in patterns
// ---------------------------------------------------------------------------

const planFanOutSynthesize = PipelinePattern(
  id: 'plan-fanout-synth',
  name: 'Plan-FanOut-Synthesize',
  description: 'A planner splits work across parallel workers, '
      'then a synthesizer combines their outputs.',
  nodes: [
    DagNode(id: 'planner', label: 'Planner', roomId: 'plain'),
    DagNode(
      id: 'worker-1',
      label: 'Worker 1',
      roomId: 'plain',
      dependsOn: ['planner'],
    ),
    DagNode(
      id: 'worker-2',
      label: 'Worker 2',
      roomId: 'plain',
      dependsOn: ['planner'],
    ),
    DagNode(
      id: 'worker-3',
      label: 'Worker 3',
      roomId: 'plain',
      dependsOn: ['planner'],
    ),
    DagNode(
      id: 'synthesizer',
      label: 'Synthesizer',
      roomId: 'demo-synthesizer',
      dependsOn: ['worker-1', 'worker-2', 'worker-3'],
    ),
  ],
  edges: [
    DagEdge(from: 'planner', to: 'worker-1'),
    DagEdge(from: 'planner', to: 'worker-2'),
    DagEdge(from: 'planner', to: 'worker-3'),
    DagEdge(from: 'worker-1', to: 'synthesizer'),
    DagEdge(from: 'worker-2', to: 'synthesizer'),
    DagEdge(from: 'worker-3', to: 'synthesizer'),
  ],
);

const mapReduce = PipelinePattern(
  id: 'map-reduce',
  name: 'MapReduce',
  description: 'Five parallel mappers feed into a single reducer.',
  nodes: [
    DagNode(id: 'mapper-1', label: 'Mapper 1', roomId: 'plain'),
    DagNode(id: 'mapper-2', label: 'Mapper 2', roomId: 'plain'),
    DagNode(id: 'mapper-3', label: 'Mapper 3', roomId: 'plain'),
    DagNode(id: 'mapper-4', label: 'Mapper 4', roomId: 'plain'),
    DagNode(id: 'mapper-5', label: 'Mapper 5', roomId: 'plain'),
    DagNode(
      id: 'reducer',
      label: 'Reducer',
      roomId: 'demo-synthesizer',
      dependsOn: [
        'mapper-1',
        'mapper-2',
        'mapper-3',
        'mapper-4',
        'mapper-5',
      ],
    ),
  ],
  edges: [
    DagEdge(from: 'mapper-1', to: 'reducer'),
    DagEdge(from: 'mapper-2', to: 'reducer'),
    DagEdge(from: 'mapper-3', to: 'reducer'),
    DagEdge(from: 'mapper-4', to: 'reducer'),
    DagEdge(from: 'mapper-5', to: 'reducer'),
  ],
);

const consensusVoting = PipelinePattern(
  id: 'consensus',
  name: 'Consensus Voting',
  description: 'Three independent opinions feed into a judge '
      'who renders a verdict.',
  nodes: [
    DagNode(id: 'opinion-1', label: 'Opinion 1', roomId: 'plain'),
    DagNode(id: 'opinion-2', label: 'Opinion 2', roomId: 'plain'),
    DagNode(id: 'opinion-3', label: 'Opinion 3', roomId: 'plain'),
    DagNode(
      id: 'judge',
      label: 'Judge',
      roomId: 'debate-judge',
      dependsOn: ['opinion-1', 'opinion-2', 'opinion-3'],
    ),
  ],
  edges: [
    DagEdge(from: 'opinion-1', to: 'judge'),
    DagEdge(from: 'opinion-2', to: 'judge'),
    DagEdge(from: 'opinion-3', to: 'judge'),
  ],
);

const adversarialDebate = PipelinePattern(
  id: 'adversarial',
  name: 'Adversarial Debate',
  description: 'Advocate → Critic → Rebuttal → Judge, '
      'rendered as a DAG.',
  nodes: [
    DagNode(
      id: 'advocate',
      label: 'Advocate',
      roomId: 'debate-advocate',
    ),
    DagNode(
      id: 'critic',
      label: 'Critic',
      roomId: 'debate-critic',
      dependsOn: ['advocate'],
    ),
    DagNode(
      id: 'rebuttal',
      label: 'Rebuttal',
      roomId: 'debate-advocate',
      dependsOn: ['critic'],
    ),
    DagNode(
      id: 'judge',
      label: 'Judge',
      roomId: 'debate-judge',
      dependsOn: ['advocate', 'critic', 'rebuttal'],
    ),
  ],
  edges: [
    DagEdge(from: 'advocate', to: 'critic'),
    DagEdge(from: 'critic', to: 'rebuttal'),
    DagEdge(from: 'advocate', to: 'judge'),
    DagEdge(from: 'critic', to: 'judge'),
    DagEdge(from: 'rebuttal', to: 'judge'),
  ],
);

/// All built-in patterns, shown in the pattern dropdown.
const builtInPatterns = [
  planFanOutSynthesize,
  mapReduce,
  consensusVoting,
  adversarialDebate,
];
