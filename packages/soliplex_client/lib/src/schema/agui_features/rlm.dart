// Generated code from quicktype - ignoring style issues
// ignore_for_file: sort_constructors_first
// ignore_for_file: prefer_single_quotes
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: argument_type_not_assignable
// ignore_for_file: unnecessary_ignore
// ignore_for_file: avoid_dynamic_calls
// ignore_for_file: inference_failure_on_untyped_parameter
// ignore_for_file: inference_failure_on_collection_literal

// To parse this JSON data, do
//
//     final rlm = rlmFromJson(jsonString);

import 'dart:convert';

Rlm rlmFromJson(String str) => Rlm.fromJson(json.decode(str));

String rlmToJson(Rlm data) => json.encode(data.toJson());

class Rlm {
  final List<AnalysisEntry>? analyses;

  Rlm({this.analyses});

  factory Rlm.fromJson(Map<String, dynamic> json) => Rlm(
        analyses: json["analyses"] == null
            ? []
            : List<AnalysisEntry>.from(
                json["analyses"]!.map((x) => AnalysisEntry.fromJson(x)),
              ),
      );

  Map<String, dynamic> toJson() => {
        "analyses": analyses == null
            ? []
            : List<dynamic>.from(analyses!.map((x) => x.toJson())),
      };
}

class AnalysisEntry {
  final String answer;
  final String? program;
  final String question;

  AnalysisEntry({required this.answer, this.program, required this.question});

  factory AnalysisEntry.fromJson(Map<String, dynamic> json) => AnalysisEntry(
        answer: json["answer"],
        program: json["program"],
        question: json["question"],
      );

  Map<String, dynamic> toJson() => {
        "answer": answer,
        "program": program,
        "question": question,
      };
}
