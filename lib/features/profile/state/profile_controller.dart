import 'package:flutter/material.dart';
import '../../../core/utils/user_facing_error.dart';
import '../data/profile_service.dart';

class ProfileController extends ChangeNotifier {
  final ProfileService _service = ProfileService();

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> get profile => _profile;
  bool _isLoading = false;
  bool _isUpdatingProfile = false;
  bool _isUploadingAvatar = false;
  bool _isSubmittingKyc = false;
  bool _isScanningKyc = false;
  int _avatarRefreshTick = DateTime.now().millisecondsSinceEpoch;
  Map<String, dynamic>? _lastKycScan;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isUpdatingProfile => _isUpdatingProfile;
  bool get isUploadingAvatar => _isUploadingAvatar;
  bool get isSubmittingKyc => _isSubmittingKyc;
  bool get isScanningKyc => _isScanningKyc;
  bool get isSaving =>
      _isUpdatingProfile || _isUploadingAvatar || _isSubmittingKyc || _isScanningKyc;
  int get avatarRefreshTick => _avatarRefreshTick;
  Map<String, dynamic>? get lastKycScan => _lastKycScan;
  String? get error => _error;

  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _service.fetchProfile();
      _profile = data;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to load your profile right now. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> payload) async {
    _isUpdatingProfile = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.updateProfile(payload);
      _profile = {..._profile, ...updated};
      return true;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to update profile right now. Please try again.',
      );
      return false;
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    _isUploadingAvatar = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.uploadProfilePhoto(filePath);
      _profile = {..._profile, ...updated};
      // Fetch authoritative profile to capture latest avatar URL shape/path.
      final fresh = await _service.fetchProfile();
      _profile = {..._profile, ...fresh};
      _avatarRefreshTick = DateTime.now().millisecondsSinceEpoch;
      return true;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to upload photo right now. Please try again.',
      );
      return false;
    } finally {
      _isUploadingAvatar = false;
      notifyListeners();
    }
  }

  Future<bool> submitKyc({
    required String fullName,
    required String idType,
    required String idNumber,
    required String imagePath,
  }) async {
    _isSubmittingKyc = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.submitKyc(
        fullName: fullName,
        idType: idType,
        idNumber: idNumber,
        imagePath: imagePath,
      );
      _profile = {..._profile, ...updated};
      final fresh = await _service.fetchProfile();
      _profile = {..._profile, ...fresh};
      return true;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to submit KYC right now. Please try again.',
      );
      return false;
    } finally {
      _isSubmittingKyc = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> scanKycDocument(String imagePath) async {
    _isScanningKyc = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _service.scanKycDocument(imagePath);
      _lastKycScan = data;
      return data;
    } catch (e) {
      _error = UserFacingError.from(
        e,
        fallback: 'Unable to scan document right now. Please try again.',
      );
      return null;
    } finally {
      _isScanningKyc = false;
      notifyListeners();
    }
  }

  String get displayName {
    if (_profile['full_name'] != null) {
      return _profile['full_name'];
    }
    if (_profile['email'] != null) {
      return _profile['email'];
    }
    return 'User';
  }
}
