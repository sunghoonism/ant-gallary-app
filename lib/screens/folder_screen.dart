import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/photo_provider.dart';
import '../models/photo_folder.dart';
import '../utils/app_strings.dart';
import 'photo_screen.dart';

class FolderScreen extends StatefulWidget {
  const FolderScreen({Key? key}) : super(key: key);

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  @override
  void initState() {
    super.initState();
    // Post-frame callback을 사용하여 빌드 사이클과 분리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFolders();
    });
  }

  Future<void> _loadFolders() async {
    try {
      final provider = Provider.of<PhotoProvider>(context, listen: false);
      
      // 폴더 목록을 다시 로드하여 항목 수 갱신
      await provider.loadFolders();
      
      // 충분한 새로고침 시간 확보 (최소 0.5초)
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error loading folders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/assets/app_icon.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            Text(AppStrings.appTitle),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
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
                    style: const TextStyle(color: Color.fromARGB(255, 255, 59, 15)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadFolders(),
                    child: Text(AppStrings.tryAgain),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    child: Text(AppStrings.permissionSettings),
                  ),
                ],
              ),
            );
          }
          
          if (provider.folders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _loadFolders,
              child: ListView(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Text(AppStrings.noFoldersFound),
                    ),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: _loadFolders,
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: provider.folders.length,
              itemBuilder: (ctx, index) {
                final folder = provider.folders[index];
                return FolderItem(folder: folder);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final provider = Provider.of<PhotoProvider>(context, listen: false);
    
    // 현재 경로에서 기본 경로 추출 (경로가 없으면 기본값 사용)
    String currentPath = provider.defaultAntCameraPath ?? '/storage/emulated/0/DCIM/AntCamera';
    
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppStrings.rootFolderSettings),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.currentPath,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentPath,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        // 파일 선택기 실행
                        String? directoryPath = await _pickDirectory();
                        if (directoryPath != null && directoryPath.isNotEmpty) {
                          setState(() {
                            currentPath = directoryPath;
                          });
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.directorySelectionError(e.toString()))),
                        );
                      }
                    },
                    icon: const Icon(Icons.folder_open),
                    label: Text(AppStrings.browseFolders),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.subfolderInfo,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (currentPath.isNotEmpty) {
                      Navigator.pop(context);
                      
                      // 빌드 사이클 완료 후 실행
                      await Future.microtask(() {});
                      
                      // 로딩 표시
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                      
                      try {
                        await provider.setRootFolderPath(currentPath);
                        
                        // 로딩 닫기
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        // 로딩 닫기
                        if (context.mounted) {
                          Navigator.pop(context);
                          
                          // 에러 표시
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppStrings.errorMessage(e.toString()))),
                          );
                        }
                      }
                    }
                  },
                  child: Text(AppStrings.apply),
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  // 디렉토리 선택 메서드
  Future<String?> _pickDirectory() async {
    try {
      // 모든 필요한 권한 요청
      bool permissionGranted = false;
      
      // 저장소 권한 요청 (다양한 권한 시도)
      final storageStatus = await Permission.storage.request();
      final photosStatus = await Permission.photos.request();
      final manageStatus = await Permission.manageExternalStorage.request();
      
      permissionGranted = storageStatus.isGranted || 
                          photosStatus.isGranted || 
                          manageStatus.isGranted;
      
      if (!permissionGranted) {
        // 사용자에게 권한 필요성 안내
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.storagePermissionRequired),
            action: SnackBarAction(
              label: AppStrings.settings,
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
        return null;
      }
      
      // 디렉토리 선택 다이얼로그 표시
      String? result = await FilePicker.platform.getDirectoryPath();
      
      // 선택된 경로가 없으면 기본 경로 제안
      if (result == null || result.isEmpty) {
        return null;
      }
      
      // Android 경로 정규화 (file_picker가 반환하는 경로 형식에 따라 조정)
      if (result.startsWith('/storage/emulated/0')) {
        // 이미 정규화된 경로
        return result;
      } else if (result.startsWith('/storage/')) {
        // 다른 형태의 저장소 경로도 그대로 사용
        return result;
      } else if (result.startsWith('/data/')) {
        // 내부 저장소 경로도 그대로 사용
        return result;
      } else {
        // 그 외의 경우 표준 외부 저장소 경로 형식으로 변환
        final Directory resultDir = Directory(result);
        return resultDir.absolute.path;
      }
    } catch (e) {
      debugPrint('Directory selection error: $e');
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.folderSelectionError(e.toString()))),
      );
      return null;
    }
  }
}

class FolderItem extends StatelessWidget {
  final PhotoFolder folder;
  
  const FolderItem({Key? key, required this.folder}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 런타임에 폴더 항목 수 확인 (최신 상태 반영)
    int itemCount = folder.photos.length;
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PhotoScreen(folder: folder),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: folder.thumbnailFile != null
                ? _buildThumbnail(folder.thumbnailFile!)
                : Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.photo_album,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: AppStrings.itemsAsync(itemCount),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? '$itemCount items',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildThumbnail(File file) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.broken_image,
              size: 48,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }
} 