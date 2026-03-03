# soliplex_skills

Shared skill loading and execution for Soliplex. Skills are composable behaviors defined as `.md` (message injection) or `.py` (Python sandbox) files.

## Quick Start

```bash
cd packages/soliplex_skills
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Model

- `Skill` -- Sealed base class for a loadable skill.
- `MarkdownSkill` -- A skill whose body is a Markdown prompt injected as a chat message.
- `PythonSkill` -- A skill whose body is Python code executed in a sandbox.
- `SkillMetadata` -- Metadata for a skill, parsed from its YAML frontmatter.

### Loading

- `SkillSource` -- Interface for a source of skills (e.g., filesystem, server).
- `FilesystemSkillSource` -- Loads skills from a local directory.
- `ServerSkillSource` -- Loads skills from a remote server API.
- `SkillParser` -- Static utility class to parse `.md` and `.py` files into `Skill` objects.
- `SkillLoadException` -- An exception thrown when a skill fails to load.

### Execution

- `SkillResult` -- Sealed base class for the result of executing a skill.
- `MessageInjection` -- Result of a `MarkdownSkill`, representing a chat message to be injected.
- `ExecutionOutput` -- Result of a `PythonSkill`, containing stdout and an optional error.
- `MessageRole` -- An enum (`system`, `user`) for the role of an injected message.
- `PythonRunner` -- A `typedef` for a function that can execute Python code, injected by the host.

### Registry

- `SkillRegistry` -- An immutable collection of loaded skills, searchable by name and category.

## Dependencies

- `meta` -- For annotations like `@immutable` to enforce class contracts.
- `path` -- For cross-platform file path manipulation in `FilesystemSkillSource`.
- `yaml` -- For parsing YAML frontmatter from skill files.

## Example

```dart
import 'dart:io';
import 'package:soliplex_skills/soliplex_skills.dart';

Future<void> main() async {
  // 1. Load skills from a directory.
  final source = FilesystemSkillSource(Directory('path/to/skills'));
  final skills = await source.load();

  // 2. Build a registry.
  final registry = SkillRegistry(skills);

  // 3. Look up a skill by name.
  final skill = registry.lookup('hello-world');
  if (skill is PythonSkill) {
    print('Found Python skill: ${skill.metadata.name}');
    print('Code: ${skill.body}');
  }
}
```
