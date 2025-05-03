import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/photo_folder.dart';
import '../providers/photo_provider.dart';
import '../utils/app_strings.dart';
import 'photo_detail_screen.dart';

class PhotoScreen extends StatefulWidget {
  final PhotoFolder folder;

  const PhotoScreen({Key? key, required this.folder}) : super(key: key);

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  @override
  void initState() {
    super.initState();
    // 빌드 사이클 이후에 사진 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPhotos();
    });
  }

  Future<void> _loadPhotos() async {
    try {
      final provider = Provider.of<PhotoProvider>(context, listen: false);
      
      // 이미지 리스트를 다시 불러옴
      await provider.loadPhotos(widget.folder);
      
      // 충분한 새로고침 시간 확보 (최소 0.5초)
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Photo loading error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        centerTitle: true,
      ),
      body: Consumer<PhotoProvider>(
        builder: (ctx, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.error,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadPhotos(),
                    child: Text(AppStrings.tryAgain),
                  ),
                ],
              ),
            );
          }

          if (provider.photos.isEmpty) {
            return RefreshIndicator(
              onRefresh: _loadPhotos,
              child: ListView(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Text(AppStrings.noPhotosFound),
                    ),
                  ),
                ],
              ),
            );
          }

          // 날짜별로 사진 그룹화
          final photosByDate = _groupPhotosByDate(provider.photos);
          final dates = photosByDate.keys.toList()..sort((a, b) => b.compareTo(a));

          return RefreshIndicator(
            onRefresh: _loadPhotos,
            child: ListView.builder(
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final photos = photosByDate[date]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 16, bottom: 8
                      ),
                      child: Text(
                        _formatDate(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    MasonryGridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: photos.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) {
                        return _buildPhotoItem(photos[index]);
                      },
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  // 날짜별로 사진 그룹화
  Map<DateTime, List<File>> _groupPhotosByDate(List<File> photos) {
    final Map<DateTime, List<File>> photosByDate = {};
    
    for (final photo in photos) {
      // 날짜만 추출 (시간 제외)
      final date = DateTime(
        photo.lastModifiedSync().year,
        photo.lastModifiedSync().month,
        photo.lastModifiedSync().day,
      );
      
      if (!photosByDate.containsKey(date)) {
        photosByDate[date] = [];
      }
      
      photosByDate[date]!.add(photo);
    }
    
    return photosByDate;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return AppStrings.today;
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return AppStrings.yesterday;
    } else {
      return DateFormat('yyyy/MM/dd').format(date);
    }
  }

  Widget _buildPhotoItem(File file) {
    final String id = file.path;
    
    return GestureDetector(
      onTap: () {
        final provider = Provider.of<PhotoProvider>(context, listen: false);
        provider.selectPhoto(file);
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => PhotoDetailScreen(file: file),
          ),
        );
      },
      child: Hero(
        tag: id,
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 