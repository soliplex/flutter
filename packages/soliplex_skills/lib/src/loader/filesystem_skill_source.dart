import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:soliplex_skills/src/loader/skill_parser.dart';
import 'package:soliplex_skills/src/loader/skill_source.dart';
import 'package:soliplex_skills/src/model/skill.dart';

/// Loads skills from a local filesystem directory.
///
/// Recognises two layouts:
/// - **Directory skills:** `skill-name/SKILL.md`
/// - **Flat files:** `name.md`, `name.py`
class FilesystemSkillSource implements SkillSource {
  const FilesystemSkillSource(this.directory);

  /// Root directory to scan for skill files.
  final Directory directory;

  @override
  Future<List<Skill>> loadAll() async {
    if (!directory.existsSync()) return [];

    final skills = <Skill>[];
    final errors = <SkillLoadException>[];

    await for (final entity in directory.list()) {
      try {
        if (entity is Directory) {
          final skillMd = File(p.join(entity.path, 'SKILL.md'));
          if (skillMd.existsSync()) {
            final raw = await skillMd.readAsString();
            skills.add(SkillParser.parseMarkdown(skillMd.path, raw));
          }
        } else if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          final raw = await entity.readAsString();

          if (ext == '.md') {
            skills.add(SkillParser.parseMarkdown(entity.path, raw));
          } else if (ext == '.py') {
            final sidecarPath = '${p.withoutExtension(entity.path)}.yaml';
            final sidecarFile = File(sidecarPath);
            final sidecarYaml = sidecarFile.existsSync()
                ? await sidecarFile.readAsString()
                : null;
            skills.add(
              SkillParser.parsePython(
                entity.path,
                raw,
                sidecarYaml: sidecarYaml,
              ),
            );
          }
        }
      } on Exception catch (e) {
        errors.add(
          SkillLoadException(entity.path, 'Failed to load skill', e),
        );
      }
    }

    if (errors.isNotEmpty) {
      // Errors are collected but not thrown — the caller gets what loaded.
      // In the future, loadAll could return (List<Skill>, List<Exception>).
    }

    return skills;
  }
}
