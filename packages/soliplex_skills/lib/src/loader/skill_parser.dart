import 'package:soliplex_skills/src/model/skill.dart';
import 'package:soliplex_skills/src/model/skill_metadata.dart';
import 'package:yaml/yaml.dart';

/// Parses skill files into [Skill] instances.
abstract final class SkillParser {
  /// Splits YAML frontmatter from body content.
  ///
  /// Frontmatter is delimited by `---` on its own line at the start.
  /// Returns `(yamlMap, bodyAfterFrontmatter)`.
  /// If no frontmatter is found, returns `({}, originalContent)`.
  static (Map<String, dynamic>, String) extractFrontmatter(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('---')) {
      return (<String, dynamic>{}, content);
    }

    final afterOpening = trimmed.substring(3);
    final closeIndex = afterOpening.indexOf('\n---');
    if (closeIndex == -1) {
      return (<String, dynamic>{}, content);
    }

    final yamlBlock = afterOpening.substring(0, closeIndex).trim();
    final body = afterOpening.substring(closeIndex + 4).trimLeft();

    final parsed = loadYaml(yamlBlock);
    if (parsed is! YamlMap) {
      return (<String, dynamic>{}, content);
    }

    final map = <String, dynamic>{};
    for (final entry in parsed.entries) {
      map[entry.key as String] = _convertYaml(entry.value);
    }

    return (map, body);
  }

  /// Parses a `.md` file into a [MarkdownSkill].
  static MarkdownSkill parseMarkdown(String path, String raw) {
    final (frontmatter, body) = extractFrontmatter(raw);
    final metadata = _metadataFromMap(frontmatter, path);
    return MarkdownSkill(
      metadata: metadata,
      sourcePath: path,
      content: body,
    );
  }

  /// Parses a `.py` file into a [PythonSkill].
  ///
  /// Metadata is extracted from a YAML frontmatter block in the module
  /// docstring (triple-quoted string at the start of the file), or from
  /// a sidecar `.yaml` file if provided via [sidecarYaml].
  static PythonSkill parsePython(
    String path,
    String raw, {
    String? sidecarYaml,
  }) {
    Map<String, dynamic> frontmatter;
    String code;

    if (sidecarYaml != null) {
      final parsed = loadYaml(sidecarYaml);
      frontmatter = parsed is YamlMap ? _yamlMapToMap(parsed) : {};
      code = raw;
    } else {
      final docstring = _extractDocstring(raw);
      if (docstring != null) {
        (frontmatter, _) = extractFrontmatter(docstring);
      } else {
        frontmatter = {};
      }
      code = raw;
    }

    final metadata = _metadataFromMap(frontmatter, path);
    return PythonSkill(
      metadata: metadata,
      sourcePath: path,
      code: code,
    );
  }

  static SkillMetadata _metadataFromMap(
    Map<String, dynamic> map,
    String path,
  ) {
    final metaSection = map['metadata'] is Map<String, dynamic>
        ? map['metadata'] as Map<String, dynamic>
        : const <String, dynamic>{};

    // Build extra map excluding known keys.
    final extra = <String, dynamic>{};
    for (final entry in metaSection.entries) {
      final key = entry.key;
      if (key != 'bridge_version' && key != 'category' && key != 'generated') {
        extra[key] = entry.value;
      }
    }

    // Derive name from frontmatter or filename.
    final name = map['name'] as String? ?? _nameFromPath(path);

    return SkillMetadata(
      name: name,
      description: map['description'] as String? ?? '',
      category: metaSection['category'] as String?,
      bridgeVersion: metaSection['bridge_version'] as String?,
      isGenerated: metaSection['generated'] == 'true' ||
          metaSection['generated'] == true,
      extra: extra,
    );
  }

  static String _nameFromPath(String path) {
    final segments = path.split('/');
    final filename = segments.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }

  /// Extracts a triple-quoted docstring from the start of a Python file.
  static String? _extractDocstring(String code) {
    final trimmed = code.trimLeft();

    for (final quote in ['"""', "'''"]) {
      if (!trimmed.startsWith(quote)) continue;
      final after = trimmed.substring(quote.length);
      final endIndex = after.indexOf(quote);
      if (endIndex == -1) continue;
      return after.substring(0, endIndex).trim();
    }
    return null;
  }

  static dynamic _convertYaml(dynamic value) {
    if (value is YamlMap) return _yamlMapToMap(value);
    if (value is YamlList) return value.map(_convertYaml).toList();
    return value;
  }

  static Map<String, dynamic> _yamlMapToMap(YamlMap yamlMap) {
    final map = <String, dynamic>{};
    for (final entry in yamlMap.entries) {
      map[entry.key as String] = _convertYaml(entry.value);
    }
    return map;
  }
}
