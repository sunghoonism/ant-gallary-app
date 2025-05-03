import 'dart:io';

class PhotoFolder {
  final String id;
  final String name;
  final String path;
  final File? thumbnailFile;
  final DateTime? lastModified;
  final List<File> photos;

  PhotoFolder({
    required this.id,
    required this.name,
    required this.path,
    this.thumbnailFile,
    this.lastModified,
    this.photos = const [],
  });

  PhotoFolder copyWith({
    String? id,
    String? name,
    String? path,
    File? thumbnailFile,
    DateTime? lastModified,
    List<File>? photos,
  }) {
    return PhotoFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      thumbnailFile: thumbnailFile ?? this.thumbnailFile,
      lastModified: lastModified ?? this.lastModified,
      photos: photos ?? this.photos,
    );
  }
} 