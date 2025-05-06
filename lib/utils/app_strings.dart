import 'dart:io';
import 'package:flutter/services.dart';

/// 앱 문자열 리소스 관리 클래스
class AppStrings {
  // 플랫폼 채널
  static const MethodChannel _channel = MethodChannel('app_strings_channel');

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
    'folder_selection_error': 'Folder selection error: %s',
    'directory_selection_error': 'Directory selection error: %s',
    'error_message': 'Error: %s',
    'cannot_load_image': 'Cannot load image: %s',
    'items': '%d items',
    'select_folder': 'Select Folder',
    'delete': 'Delete',
    'move': 'Move',
    'selected_items': '%d selected',
    'delete_confirm': 'Delete %d items?',
    'delete_success': 'Items deleted',
    'delete_error': 'Could not delete some items',
    'move_success': 'Items moved',
    'move_error': 'Could not move some items',
  };

  // 문자열 캐시
  static final Map<String, String> _cache = {};

  // 기본 문자열 가져오기
  static String get(String key) {
    return _cache[key] ?? _defaultStrings[key] ?? key;
  }

  // 문자열 리소스 로드
  static Future<void> preloadStrings() async {
    for (String key in _defaultStrings.keys) {
      try {
        if (Platform.isAndroid) {
          final String value = await _channel.invokeMethod('getString', {'key': key});
          _cache[key] = value;
        } else {
          _cache[key] = _defaultStrings[key] ?? key;
        }
      } catch (e) {
        _cache[key] = _defaultStrings[key] ?? key;
      }
    }
  }

  // 기본 포맷 문자열 처리 (동기식)
  static String format(String key, Map<String, dynamic> args) {
    final String format = _cache[key] ?? _defaultStrings[key] ?? key;
    if (key == 'items' && args.containsKey('arg1')) {
      return format.replaceAll('%d', args['arg1'].toString());
    } else if (args.containsKey('arg1')) {
      return format.replaceAll('%s', args['arg1'].toString());
    }
    return format;
  }

  // 포맷 문자열 메서드 (비동기식)
  static Future<String> _getFormattedString(String key, Map<String, dynamic> args) async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod('getString', {'key': key, ...args});
      }
    } catch (e) {
      // 네이티브 호출 실패 시 기본값 사용
    }

    // 기본 문자열 사용
    return format(key, args);
  }

  // 에러 포맷 문자열 (동기식)
  static String folderSelectionError(String error) => 
      format('folder_selection_error', {'arg1': error});
  
  static String directorySelectionError(String error) => 
      format('directory_selection_error', {'arg1': error});
  
  static String errorMessage(String error) => 
      format('error_message', {'arg1': error});
  
  static String cannotLoadImage(String error) => 
      format('cannot_load_image', {'arg1': error});
  
  static String items(int count) => 
      format('items', {'arg1': count});

  // 에러 포맷 문자열 (비동기식)
  static Future<String> folderSelectionErrorAsync(String error) async =>
      await _getFormattedString('folder_selection_error', {'arg1': error});
  
  static Future<String> directorySelectionErrorAsync(String error) async =>
      await _getFormattedString('directory_selection_error', {'arg1': error});
  
  static Future<String> errorMessageAsync(String error) async =>
      await _getFormattedString('error_message', {'arg1': error});
  
  static Future<String> cannotLoadImageAsync(String error) async =>
      await _getFormattedString('cannot_load_image', {'arg1': error});
  
  static Future<String> itemsAsync(int count) async =>
      await _getFormattedString('items', {'arg1': count});
      
  static Future<String> selectedItemsAsync(int count) async =>
      await _getFormattedString('selected_items', {'arg1': count});

  static Future<String> deleteConfirmAsync(int count) async =>
      await _getFormattedString('delete_confirm', {'arg1': count});

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