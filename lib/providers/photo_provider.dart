import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import '../models/photo_folder.dart';

class PhotoProvider extends ChangeNotifier {
  List<PhotoFolder> _folders = [];
  List<File> _photos = [];
  File? _selectedPhoto;
  bool _isLoading = false;
  String _error = '';
  
  // 기본 AntCamera 폴더 경로
  String? _defaultAntCameraPath;
  
  // 초기화 플래그
  bool _initialized = false;

  List<PhotoFolder> get folders => _folders;
  List<File> get photos => _photos;
  File? get selectedPhoto => _selectedPhoto;
  bool get isLoading => _isLoading;
  String get error => _error;
  String? get defaultAntCameraPath => _defaultAntCameraPath;

  PhotoProvider() {
    // 생성자에서는 초기화만 예약
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAsync();
    });
  }

  // 비동기 초기화 작업
  Future<void> _initAsync() async {
    if (_initialized) return;
    try {
      // 권한 요청
      bool permissionGranted = false;
      
      // 권한 요청 - 이미지 읽기 권한 요청
      final storageStatus = await Permission.storage.request();
      final photosStatus = await Permission.photos.request();
      
      permissionGranted = storageStatus.isGranted || photosStatus.isGranted;
      
      // 권한 없음
      if (!permissionGranted) {
        _error = 'Gallery access permission denied.';
        notifyListeners();
        return;
      }

      // AntCamera 폴더 경로 찾기
      await _findDefaultAntCameraPath();
      
      // 초기화 완료
      _initialized = true;
      
      // 폴더 로드 (별도 호출)
      await loadFolders();
    } catch (e) {
      _error = 'Initialization error: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  Future<void> _findDefaultAntCameraPath() async {
    try {
      // 안드로이드에서 표준 DCIM 경로 사용
      String dcimPath = '/storage/emulated/0/DCIM';
      String antCameraPath = '$dcimPath/AntCamera';
      
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // 상대 경로 대신 절대 경로로 바로 설정
          dcimPath = '/storage/emulated/0/DCIM';
          antCameraPath = '$dcimPath/AntCamera';
          
          // 경로 유효성 확인
          Directory antCameraDir = Directory(antCameraPath);
          if (await antCameraDir.exists()) {
            _defaultAntCameraPath = antCameraPath;
          } else {
            // 폴더가 없으면 생성
            await antCameraDir.create(recursive: true);
            _defaultAntCameraPath = antCameraPath;
          }
        } else {
          // 외부 저장소 접근 실패 시 기본 경로 사용
          _defaultAntCameraPath = antCameraPath;
        }
      } catch (e) {
        // 오류 발생 시 기본 경로 사용
        debugPrint('DCIM path access error, using default path: $e');
        _defaultAntCameraPath = antCameraPath;
      }
    } catch (e) {
      _error = 'Error finding AntCamera folder: $e';
      debugPrint(_error);
    }
  }

  Future<void> loadFolders() async {
    if (!_initialized) {
      // 초기화되지 않았다면 작업 취소
      return;
    }
    
    // 디렉토리 캐시 비우기 (새로고침을 위함)
    clearCache();
    
    // 로딩 시작
    _setLoading(true);
    
    try {
      if (_defaultAntCameraPath == null) {
        _error = 'Cannot find AntCamera folder.';
        _setLoading(false);
        return;
      }
      
      List<PhotoFolder> newFolders = [];
      final Directory antCameraDir = Directory(_defaultAntCameraPath!);
      
      if (await antCameraDir.exists()) {
        // AntCamera 폴더 내의 하위 폴더들 찾기
        List<FileSystemEntity> entities = [];
        try {
          entities = await antCameraDir.list().toList();
        } catch (e) {
          debugPrint('Error reading folder list: $e');
          _error = 'Cannot read folder list: $e';
          _setLoading(false);
          return;
        }
        
        // 하위 폴더 처리
        for (var entity in entities) {
          if (entity is Directory) {
            try {
              // 각 폴더 내 이미지 파일 수 확인 (새로고침 시 갱신)
              PhotoFolder processedFolder = await _processDirectory(entity);
              if (processedFolder.path.isNotEmpty) {
                newFolders.add(processedFolder);
              }
            } catch (e) {
              debugPrint('Folder processing error (ignored): $e');
              // 개별 폴더 오류는 무시하고 계속 진행
            }
          }
        }
        
        // Root folder is not displayed
      } else {
        // AntCamera 폴더가 없으면 생성
        try {
          await antCameraDir.create(recursive: true);
        } catch (e) {
          debugPrint('Error creating AntCamera folder: $e');
        }
      }
      
      // 날짜순으로 정렬 (최신순)
      newFolders.sort((a, b) {
        if (a.lastModified != null && b.lastModified != null) {
          return b.lastModified!.compareTo(a.lastModified!);
        } else if (a.lastModified != null) {
          return -1;
        } else if (b.lastModified != null) {
          return 1;
        }
        return 0;
      });
      
      // 폴더 목록 업데이트
      _folders = newFolders;
      
    } catch (e) {
      _error = 'Error loading folders: $e';
      debugPrint(_error);
    } finally {
      // 로딩 종료
      _setLoading(false);
    }
  }
  
  // 디렉토리 처리 헬퍼 메소드
  Future<PhotoFolder> _processDirectory(Directory dir, {String? name, String? id}) async {
    final dirName = name ?? path.basename(dir.path);
    final dirId = id ?? dir.path;
    
    // 이미지 파일만 필터링
    List<FileSystemEntity> files = [];
    try {
      files = await dir
          .list()
          .where((entity) => 
              entity is File && 
              ['.jpg', '.jpeg', '.png'].contains(path.extension(entity.path).toLowerCase()))
          .toList();
    } catch (e) {
      debugPrint('Error reading directory contents: $e');
      // 오류 발생 시 빈 목록 사용
    }
    
    if (files.isNotEmpty) {
      // 날짜순으로 정렬
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      // 최신 파일을 썸네일로 사용
      final File thumbnailFile = files.first as File;
      
      return PhotoFolder(
        id: dirId,
        name: dirName,
        path: dir.path,
        thumbnailFile: thumbnailFile,
        lastModified: thumbnailFile.statSync().modified,
        photos: files.map((e) => e as File).toList(),
      );
    } else {
      return PhotoFolder(
        id: dirId,
        name: dirName,
        path: dir.path,
      );
    }
  }

  Future<void> loadPhotos(PhotoFolder folder) async {
    // 빌드 중 호출되는 것을 방지하기 위해 한 틱 지연
    await Future.microtask(() {});
    
    // 디렉토리 캐시 비우기 (새로고침을 위함)
    clearCache();
    
    // 로딩 시작
    _setLoading(true);
    _photos = [];
    
    // 한 틱 더 지연하여 빌드 사이클 간 충돌 방지
    await Future.microtask(() {});
    
    try {
      // 디렉토리에서 이미지 파일들 로드
      final Directory dir = Directory(folder.path);
      if (await dir.exists()) {
        final List<FileSystemEntity> files = await dir
            .list()
            .where((entity) => 
                entity is File && 
                ['.jpg', '.jpeg', '.png'].contains(path.extension(entity.path).toLowerCase()))
            .toList();
        
        // 날짜 기준으로 정렬 (최신순)
        files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        
        _photos = files.map((e) => e as File).toList();
      }
    } catch (e) {
      _error = 'Error loading photos: $e';
      debugPrint(_error);
    } finally {
      // 로딩 종료
      _setLoading(false);
    }
  }

  void selectPhoto(File photo) {
    _selectedPhoto = photo;
    notifyListeners();
  }
  
  void clearSelectedPhoto() {
    _selectedPhoto = null;
    notifyListeners();
  }
  
  // 로딩 상태 안전하게 변경
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 루트 폴더 경로 설정 메서드 추가
  Future<void> setRootFolderPath(String newPath) async {
    try {
      // 입력 경로 유효성 검사
      if (newPath.isEmpty) {
        throw Exception('Invalid path.');
      }
      
      debugPrint('Setting path: $newPath');
      
      // 디렉토리 객체 생성
      Directory dir = Directory(newPath);
      
      // 실제 절대 경로 확인
      String absolutePath = dir.absolute.path;
      debugPrint('Absolute path: $absolutePath');
      
      // 디렉토리 존재 확인
      bool exists = false;
      try {
        exists = await dir.exists();
      } catch (e) {
        debugPrint('Error checking directory existence: $e');
        // 오류 발생 시 기본 경로로 대체
        newPath = '/storage/emulated/0/DCIM/AntCamera';
        dir = Directory(newPath);
        absolutePath = dir.absolute.path;
        exists = await dir.exists();
      }
      
      if (!exists) {
        // 폴더가 없으면 생성 시도
        try {
          await dir.create(recursive: true);
          debugPrint('New folder created: $absolutePath');
        } catch (e) {
          debugPrint('Error trying to create folder: $e');
          throw Exception('Cannot create folder. Please check storage permissions.');
        }
      } else {
        // 폴더 접근 가능 여부 확인
        try {
          final fileList = await dir.list();
          await fileList.isEmpty; // 값을 사용하지는 않지만 비동기 완료 대기
          debugPrint('Folder is accessible: $absolutePath');
        } catch (e) {
          debugPrint('Folder access error: $e');
          throw Exception('Cannot access the selected folder. Please check permissions.');
        }
      }
      
      // 경로 설정 (절대 경로 사용)
      _defaultAntCameraPath = absolutePath;
      
      // 폴더 목록 다시 로드
      await loadFolders();
      
      debugPrint('Root folder set: $absolutePath');
    } catch (e) {
      _error = 'Error setting root folder: $e';
      debugPrint(_error);
      notifyListeners();
      throw e; // 에러를 다시 throw하여 UI에서 처리할 수 있게 함
    }
  }

  // 파일 시스템 캐시 비우기
  void clearCache() {
    try {
      // 안전하게 특정 디렉토리만 접근
      if (_defaultAntCameraPath != null) {
        final Directory antCameraDir = Directory(_defaultAntCameraPath!);
        if (antCameraDir.existsSync()) {
          // 캐시 갱신을 위해 디렉토리 정보 읽기
          antCameraDir.listSync(recursive: false);
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      // 오류가 발생해도 앱 실행에 영향을 주지 않도록 무시
    }
  }
} 