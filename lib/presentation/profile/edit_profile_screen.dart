import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../application/helpers/error_helper.dart';
import '../../application/helpers/booking_validation_helper.dart';
import '../../application/providers/profile_providers.dart';
import '../../application/providers/auth_providers.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/models/vehicle_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  final List<VehicleModel> _vehicles = [];
  String _selectedGender = "Male";
  bool _isLoading = false;
  bool _isInitialized = false;
  XFile? _selectedImage;
  Map<String, bool> _vehicleSubscriptionStatus = {};
  bool _isLoadingSubscriptionStatus = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _initializeData(UserProfileModel? profile) {
    if (_isInitialized || profile == null) return;
    _nameController.text = profile.fullName;
    _phoneController.text = profile.phone ?? '';
    _addressController.text = profile.address ?? '';
    _selectedGender = profile.gender ?? 'Male';

    _vehicles.clear();
    _vehicles.addAll(profile.vehicles);

    _isInitialized = true;

    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    if (_vehicles.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoadingSubscriptionStatus = true);

    try {
      final vehicleNumbers = _vehicles.map((v) => v.licensePlate).toList();
      final status =
          await BookingValidationHelper.getAllVehiclesSubscriptionStatus(
            userId: user.id,
            vehicleNumbers: vehicleNumbers,
          );

      if (mounted) {
        setState(() {
          _vehicleSubscriptionStatus = status;
          _isLoadingSubscriptionStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSubscriptionStatus = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  void _addVehicle() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VehicleFormSheet(
        userId: user.id,
        onSave: (vehicle) {
          setState(() => _vehicles.add(vehicle));
        },
      ),
    );
  }

  void _editVehicle(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VehicleFormSheet(
        userId: _vehicles[index].userId,
        vehicle: _vehicles[index],
        onSave: (vehicle) {
          setState(() => _vehicles[index] = vehicle);
        },
      ),
    );
  }

  Future<void> _removeVehicle(int index) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final vehicleToRemove = _vehicles[index];

    final hasActiveSubscription =
        await BookingValidationHelper.hasActiveSubscriptionForVehicle(
          userId: user.id,
          vehicleNumber: vehicleToRemove.licensePlate,
        );

    if (hasActiveSubscription) {
      if (mounted) {
        showErrorDialog(
          context,
          message:
              'Cannot delete vehicle with active subscription. Please cancel your subscription first.',
          title: 'Cannot Delete Vehicle',
        );
      }
      return;
    }

    setState(() => _vehicles.removeAt(index));
  }

  Future<void> _saveProfile(UserProfileModel? currentProfile) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Basic Validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? avatarUrl = currentProfile?.avatarUrl;

      // 1. Handle image upload if selected
      if (_selectedImage != null) {
        avatarUrl = await ref
            .read(userRepositoryProvider)
            .uploadProfilePhoto(user.id, _selectedImage!);
      }

      // 2. Update User Profile
      final updatedProfile =
          (currentProfile ??
                  UserProfileModel(
                    id: user.id,
                    fullName: _nameController.text,
                    createdAt: DateTime.now(),
                  ))
              .copyWith(
                fullName: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                gender: _selectedGender,
                avatarUrl: avatarUrl,
              );

      await ref.read(userRepositoryProvider).updateProfile(updatedProfile);

      // 3. Handle Vehicles (Simple approach: delete all and re-insert for now or track changes)
      // Industry standard usually tracks IDs, but for a small list like this, syncing is common.
      // However, we'll use our repo to update/insert.
      final repo = ref.read(userRepositoryProvider);

      // Check if any vehicle with subscription has license plate changed
      final dbVehicles = await repo.getVehicles(user.id);
      for (final updatedVehicle in _vehicles) {
        final dbVehicle = dbVehicles
            .where((v) => v.id == updatedVehicle.id)
            .firstOrNull;
        if (dbVehicle != null) {
          // Check if license plate was changed
          if (dbVehicle.licensePlate.toUpperCase() !=
              updatedVehicle.licensePlate.toUpperCase()) {
            // License plate changed - check if vehicle has active subscription
            final hasSubscription =
                await BookingValidationHelper.hasActiveSubscription(
                  userId: user.id,
                  vehicleNumber: dbVehicle.licensePlate,
                );
            if (hasSubscription) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot edit license plate for "${dbVehicle.model}" - vehicle has active subscription. Please cancel subscription first.',
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              setState(() => _isLoading = false);
              return;
            }
          }
        }
      }

      // First, fetch current vehicles from DB to identify deletions
      for (var dbV in dbVehicles) {
        bool stillExists = _vehicles.any((v) => v.id == dbV.id);
        if (!stillExists) {
          await repo.deleteVehicle(dbV.id);
        }
      }

      // Then update/insert current list
      for (var v in _vehicles) {
        await repo.updateVehicle(v);
      }

      // 4. Force refresh: invalidate the stream provider so the profile page re-fetches
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          message: e.toString(),
          title: 'Operation Failed',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            _initializeData(profile);
            return _buildForm(context, profile);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFE85A10)),
          ),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, UserProfileModel? profile) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: false,
          elevation: 0,
          backgroundColor: const Color(0xFFF8F6F6).withValues(alpha: 0.95),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.inter(
              color: const Color(0xFF1C120D),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: const Color(0xFFE85A10).withValues(alpha: 0.1),
              height: 1,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPhotoSection(profile),
                const SizedBox(height: 32),
                _buildPersonalInformation(),
                const SizedBox(height: 32),
                _buildVehiclesManagement(),
                const SizedBox(height: 48),
                _buildSaveButton(profile),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(UserProfileModel? profile) {
    final avatar =
        profile?.avatarUrl ??
        "https://lh3.googleusercontent.com/aida-public/AB6AXuBvuAd7CB5GWMQnUhL0hiEmymj5jjXDJ-Y_X0gsb-PvNAmbEzeL8SMKpY30GCvw72MgzNmHgSPGHegphtJL5e9FSgR9osfgCixZakBarf5nIAJbCZDBvm0ZSZJ65OCtkkJNpPxBEVmn6JmfC3xkKhkBPSD_uULhQYGGrKRd_fHu_vY9LyjjZQf1DU3LZNhY-Kt0zcIBwTAxGYKv1dDbjxo7cmxFXK3lxFEvsts45HHMXZohwRoJQPf1AS1qNaeDxJTa3OpBbAKaM_s";

    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE85A10).withValues(alpha: 0.2),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _selectedImage != null
                        ? FutureBuilder<Uint8List>(
                            future: _selectedImage!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              }
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          )
                        : Image.network(avatar, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE85A10),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _pickImage,
          child: Text(
            'Change Photo',
            style: GoogleFonts.inter(
              color: const Color(0xFFE85A10),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person, color: Color(0xFFE85A10), size: 20),
            const SizedBox(width: 8),
            Text(
              'Personal Information',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C120D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Full Name',
          placeholder: 'Enter full name',
          controller: _nameController,
          suffixIcon: Icons.edit_outlined,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),
        _buildGenderSelector(),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Phone Number',
          placeholder: 'Enter phone number',
          controller: _phoneController,
          suffixIcon: Icons.call_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Address',
          placeholder: 'Enter address',
          controller: _addressController,
          suffixIcon: Icons.location_on_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildVehiclesManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_car,
                  color: Color(0xFFE85A10),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'My Vehicles',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1C120D),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _addVehicle,
              icon: const Icon(Icons.add, size: 18, color: Color(0xFFE85A10)),
              label: Text(
                'Add New',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE85A10),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_vehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Text(
                'No vehicles added yet',
                style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _vehicles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vehicle = _vehicles[index];
              final hasSubscription =
                  _vehicleSubscriptionStatus[vehicle.licensePlate
                      .toUpperCase()] ??
                  false;

              return Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: vehicle.isPrimary
                            ? const Color(0xFFE85A10).withValues(alpha: 0.3)
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE85A10,
                            ).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.directions_car_outlined,
                            color: Color(0xFFE85A10),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      vehicle.model,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (vehicle.isPrimary) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE85A10),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'PRIMARY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${vehicle.licensePlate} • ${vehicle.color}',
                                style: GoogleFonts.inter(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => _editVehicle(index),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _removeVehicle(index),
                        ),
                      ],
                    ),
                  ),
                  if (hasSubscription)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SUBSCRIBED',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    IconData? suffixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C120D).withValues(alpha: 0.7),
            ),
          ),
        ),
        TextField(
          maxLines: maxLines,
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, size: 18, color: Colors.grey[400])
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE85A10),
                width: 1.5,
              ),
            ),
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1C120D),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
          child: Text(
            'Gender',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C120D).withValues(alpha: 0.7),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              _buildGenderOption("Male"),
              _buildGenderOption("Female"),
              _buildGenderOption("Other"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderOption(String gender) {
    bool isSelected = _selectedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = gender),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              gender,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFFE85A10) : Colors.grey[500],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(UserProfileModel? currentProfile) {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE85A10).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _saveProfile(currentProfile),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE85A10),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Save Profile',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class _VehicleFormSheet extends StatefulWidget {
  final String userId;
  final VehicleModel? vehicle;
  final Function(VehicleModel) onSave;

  const _VehicleFormSheet({
    required this.userId,
    this.vehicle,
    required this.onSave,
  });

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  late TextEditingController _modelController;
  late TextEditingController _plateController;
  late TextEditingController _colorController;
  bool _isPrimary = false;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.vehicle?.model);
    _plateController = TextEditingController(
      text: widget.vehicle?.licensePlate,
    );
    _colorController = TextEditingController(text: widget.vehicle?.color);
    _isPrimary = widget.vehicle?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1C120D),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildField('Vehicle Model', 'e.g. BMW M4', _modelController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  'License Plate',
                  'ABC-1234',
                  _plateController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildField('Color', 'Black', _colorController)),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(
              'Set as Primary Vehicle',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            value: _isPrimary,
            activeThumbColor: const Color(0xFFE85A10),
            onChanged: (val) => setState(() => _isPrimary = val),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              if (_modelController.text.isEmpty) return;

              final newLicensePlate = _plateController.text
                  .trim()
                  .toUpperCase();

              final newVehicle = VehicleModel(
                id: widget.vehicle?.id ?? '',
                userId: widget.userId,
                model: _modelController.text.trim(),
                licensePlate: newLicensePlate,
                color: _colorController.text.trim(),
                isPrimary: _isPrimary,
              );
              widget.onSave(newVehicle);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85A10),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
