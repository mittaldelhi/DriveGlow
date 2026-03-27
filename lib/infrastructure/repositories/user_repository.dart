import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/models/vehicle_model.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  Future<UserProfileModel?> getProfile(String userId) async {
    try {
      // Ensure profile exists for new users
      await _ensureProfileExists(userId);
      
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();

      final vehiclesData = await _supabase
          .from('user_vehicles')
          .select()
          .eq('user_id', userId);

      final vehicles = (vehiclesData as List)
          .map((v) => VehicleModel.fromJson(v))
          .toList();

      return UserProfileModel.fromJson(response).copyWith(vehicles: vehicles);
    } catch (e) {
      return UserProfileModel(
        id: userId,
        fullName: 'New User',
        avatarUrl: null,
        phone: '',
        address: '',
        gender: 'Male',
        createdAt: DateTime.now(),
      );
    }
  }

  Future<void> _ensureProfileExists(String userId) async {
    try {
      final existing = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      
      if (existing == null) {
        final authUser = _supabase.auth.currentUser;
        await _supabase.from('user_profiles').insert({
          'id': userId,
          'full_name': authUser?.userMetadata?['full_name'] ?? 'New User',
          'membership_tier': 'FREE',
        });
      }
    } catch (e) {
      // Silently fail - don't block the app
    }
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    try {
      await _supabase.from('user_profiles').upsert(profile.toJson());
    } catch (e) {
      // Log error or notify user - for now just throw so UI can handle
      rethrow;
    }
  }

  Stream<UserProfileModel?> watchProfile(String userId) {
    return _supabase
        .from('user_profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .asyncMap((data) async {
          if (data.isEmpty) return null;
          final profile = UserProfileModel.fromJson(data.first);
          final vehicles = await getVehicles(userId);
          return profile.copyWith(vehicles: vehicles);
        });
  }

  Future<String> uploadProfilePhoto(String userId, XFile file) async {
    final path = '$userId/avatar.jpg';

    try {
      final bytes = await file.readAsBytes();

      // Upload to 'avatars' bucket
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(path);

      // Update profile
      await _supabase
          .from('user_profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', userId);

      return imageUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      rethrow;
    }
  }

  // --- Vehicle Management ---

  Future<List<VehicleModel>> getVehicles(String userId) async {
    final response = await _supabase
        .from('user_vehicles')
        .select()
        .eq('user_id', userId);
    return (response as List).map((v) => VehicleModel.fromJson(v)).toList();
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    await _supabase.from('user_vehicles').upsert(vehicle.toJson());
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _supabase.from('user_vehicles').delete().eq('id', vehicleId);
  }
}
