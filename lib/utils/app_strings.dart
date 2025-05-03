import 'dart:io';
import 'package:flutter/services.dart';

/// 앱 문자열 리소스 관리 클래스
class AppStrings {
  // 싱글톤 인스턴스
  static final AppStrings _instance = AppStrings._internal();
  factory AppStrings() => _instance;
  AppStrings._internal();

  // 플랫폼 채널
  static const MethodChannel _channel = MethodChannel('app_strings_channel');

  // Android에서 문자열 리소스 가져오기
  static Future<String> _getAndroidString(String key) async {
    try {
      final String value = await _channel.invokeMethod('getString', {'key': key});
      return value;
    } catch (e) {
      // 기본값 사용
      return _defaultStrings[key] ?? key;
    }
  }

  // 기본 문자열 맵 (네이티브에서 가져오지 못할 경우 사용)
  static final Map<String, String> _defaultStrings = {
    'app_title': 'Albums',
    'try_again': 'Try Again',
    'permission_settings': 'Permission Settings',
    'browse_folders': 'Browse Folders',
    'cancel': 'Cancel',
    'apply': 'Apply',
    'settings': 'Settings',
    'no_folders_found': 'No folders found',
    'no_photos_found': 'No photos found',
    'image_not_found': 'Image not found',
    'root_folder_settings': 'Root Folder Settings',
    'current_path': 'Current Path:',
    'subfolder_info': 'Subfolders of the selected folder will be displayed in the gallery.',
    'storage_permission_required': 'Storage access permission is required. Please allow it in settings.',
    'today': 'Today',
    'yesterday': 'Yesterday',
  };

  // 플랫폼에 따라 문자열 가져오기
  static Future<String> _getString(String key) async {
    if (Platform.isAndroid) {
      return await _getAndroidString(key);
    } else {
      // 다른 플랫폼에서는 기본값 사용
      return _defaultStrings[key] ?? key;
    }
  }

  // 문자열 즉시 가져오기 (캐시 활용)
  static final Map<String, String> _cache = {};
  static String get(String key) {
    return _cache[key] ?? _defaultStrings[key] ?? key;
  }

  // 앱 시작시 모든 문자열 미리 로드
  static Future<void> preloadStrings() async {
    for (final key in _defaultStrings.keys) {
      _cache[key] = await _getString(key);
    }
  }

  // 에러 포맷 문자열
  static String folderSelectionError(String error) => 
      '${get('folder_selection_error').replaceAll('%1\$s', '')}$error';
  
  static String directorySelectionError(String error) => 
      '${get('directory_selection_error').replaceAll('%1\$s', '')}$error';
  
  static String errorMessage(String error) => 
      '${get('error_message').replaceAll('%1\$s', '')}$error';
  
  static String cannotLoadImage(String error) => 
      '${get('cannot_load_image').replaceAll('%1\$s', '')}$error';
  
  static String items(int count) => 
      get('items').replaceAll('%1\$d', count.toString());

  // 편의성을 위한 getter
  static String get appTitle => get('app_title');
  static String get tryAgain => get('try_again'); 
  static String get permissionSettings => get('permission_settings');
  static String get browseFolders => get('browse_folders');
  static String get cancel => get('cancel');
  static String get apply => get('apply');
  static String get settings => get('settings');
  static String get noFoldersFound => get('no_folders_found');
  static String get noPhotosFound => get('no_photos_found');
  static String get imageNotFound => get('image_not_found');
  static String get rootFolderSettings => get('root_folder_settings');
  static String get currentPath => get('current_path');
  static String get subfolderInfo => get('subfolder_info');
  static String get storagePermissionRequired => get('storage_permission_required');
  static String get today => get('today');
  static String get yesterday => get('yesterday');
} 