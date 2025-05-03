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

  // 폴더 선택 다이얼로그 표시
  Future<String?> _showFolderSelectionDialog() async {
    final provider = Provider.of<PhotoProvider>(context, listen: false);
    String? selectedFolderPath;
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppStrings.get('select_folder')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: provider.folders.length,
              itemBuilder: (context, index) {
                final folder = provider.folders[index];
                return ListTile(
                  title: Text(folder.name),
                  onTap: () {
                    selectedFolderPath = folder.path;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.cancel),
            ),
          ],
        );
      },
    );
    
    return selectedFolderPath;
  }

  // 선택된 사진 삭제 확인 다이얼로그
  Future<void> _confirmDeletePhotos() async {
    final provider = Provider.of<PhotoProvider>(context, listen: false);
    
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.get('delete')),
        content: Text(AppStrings.format('delete_confirm', {'arg1': provider.selectedCount})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.get('delete')),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm && mounted) {
      final bool result = await provider.deleteSelectedPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? AppStrings.get('delete_success') : AppStrings.get('delete_error')),
          ),
        );
      }
    }
  }

  // 선택된 사진 이동 처리
  Future<void> _moveSelectedPhotos() async {
    final provider = Provider.of<PhotoProvider>(context, listen: false);
    
    final String? targetFolderPath = await _showFolderSelectionDialog();
    if (targetFolderPath != null && mounted) {
      final bool result = await provider.moveSelectedPhotos(targetFolderPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? AppStrings.get('move_success') : AppStrings.get('move_error')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoProvider>(
      builder: (ctx, provider, child) {
        return WillPopScope(
          onWillPop: () async {
            if (provider.isSelectionMode) {
              provider.cancelSelectionMode();
              return false; // 뒤로가기 이벤트 소비
            }
            return true; // 일반 뒤로가기 허용
          },
          child: Scaffold(
            appBar: _buildAppBar(provider),
            body: _buildBody(provider),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(PhotoProvider provider) {
    if (provider.isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => provider.cancelSelectionMode(),
        ),
        title: FutureBuilder<String>(
          future: AppStrings.selectedItemsAsync(provider.selectedCount),
          builder: (context, snapshot) {
            return Text(snapshot.data ?? '${provider.selectedCount}개 선택됨');
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeletePhotos();
              } else if (value == 'move') {
                _moveSelectedPhotos();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(AppStrings.get('delete')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    const Icon(Icons.drive_file_move),
                    const SizedBox(width: 8),
                    Text(AppStrings.get('move')),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return AppBar(
        title: Text(widget.folder.name),
        centerTitle: true,
      );
    }
  }

  Widget _buildBody(PhotoProvider provider) {
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
                  return _buildPhotoItem(photos[index], provider);
                },
              ),
            ],
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

  Widget _buildPhotoItem(File file, PhotoProvider provider) {
    final String id = file.path;
    final bool isSelected = provider.selectedPhotos.contains(file);
    
    return GestureDetector(
      onTap: () {
        if (provider.isSelectionMode) {
          provider.togglePhotoSelection(file);
        } else {
          provider.selectPhoto(file);
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => PhotoDetailScreen(file: file),
            ),
          );
        }
      },
      onLongPress: () {
        if (!provider.isSelectionMode) {
          provider.startSelectionMode(file);
        } else {
          provider.togglePhotoSelection(file);
        }
      },
      child: Stack(
        children: [
          Hero(
            tag: id,
            child: Container(
              decoration: BoxDecoration(
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 3)
                    : null,
              ),
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
          ),
          if (isSelected)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 