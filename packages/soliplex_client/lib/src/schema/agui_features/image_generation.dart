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
//     final imageGeneration = imageGenerationFromJson(jsonString);

import 'dart:convert';

ImageGeneration imageGenerationFromJson(String str) =>
    ImageGeneration.fromJson(json.decode(str));

String imageGenerationToJson(ImageGeneration data) =>
    json.encode(data.toJson());

class ImageGeneration {
  final List<GeneratedImage>? images;

  ImageGeneration({this.images});

  factory ImageGeneration.fromJson(Map<String, dynamic> json) =>
      ImageGeneration(
        images: json["images"] == null
            ? []
            : List<GeneratedImage>.from(
                json["images"]!.map((x) => GeneratedImage.fromJson(x)),
              ),
      );

  Map<String, dynamic> toJson() => {
        "images": images == null
            ? []
            : List<dynamic>.from(images!.map((x) => x.toJson())),
      };
}

class GeneratedImage {
  final int height;
  final String path;
  final String prompt;
  final int width;

  GeneratedImage({
    required this.height,
    required this.path,
    required this.prompt,
    required this.width,
  });

  factory GeneratedImage.fromJson(Map<String, dynamic> json) => GeneratedImage(
        height: json["height"],
        path: json["path"],
        prompt: json["prompt"],
        width: json["width"],
      );

  Map<String, dynamic> toJson() => {
        "height": height,
        "path": path,
        "prompt": prompt,
        "width": width,
      };
}
