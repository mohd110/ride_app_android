import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

/// Full profile edit form — the only editable field before this screen was
/// the profile photo. Saves straight to Supabase via AppState.updateProfile.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _vehicleModelController;
  late final TextEditingController _vehicleRegController;
  late final TextEditingController _licenseController;
  late final TextEditingController _addressController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyPhoneController;

  static const _vehicleTypes = ['Electric Bicycle', 'Electric Scooter', 'Motorcycle', 'Car'];
  String? _vehicleType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final rider = AppState.instance.rider;
    _nameController = TextEditingController(text: rider.displayName);
    _phoneController = TextEditingController(text: rider.phone ?? '');
    _vehicleModelController = TextEditingController(text: rider.vehicleModel ?? '');
    _vehicleRegController = TextEditingController(text: rider.vehicleRegistrationNumber ?? '');
    _licenseController = TextEditingController(text: rider.licenseNumber ?? '');
    _addressController = TextEditingController(text: rider.address ?? '');
    _emergencyNameController = TextEditingController(text: rider.emergencyContactName ?? '');
    _emergencyPhoneController = TextEditingController(text: rider.emergencyContactPhone ?? '');
    _vehicleType = _vehicleTypes.contains(rider.vehicleType) ? rider.vehicleType : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleModelController.dispose();
    _vehicleRegController.dispose();
    _licenseController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final error = await AppState.instance.updateProfile(
      fullName: _nameController.text,
      phone: _phoneController.text,
      vehicleType: _vehicleType,
      vehicleModel: _vehicleModelController.text,
      vehicleRegistrationNumber: _vehicleRegController.text,
      licenseNumber: _licenseController.text,
      address: _addressController.text,
      emergencyContactName: _emergencyNameController.text,
      emergencyContactPhone: _emergencyPhoneController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.success),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('PERSONAL INFO'),
              AppCard(
                child: Column(
                  children: [
                    _field(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('VEHICLE INFO'),
              AppCard(
                child: Column(
                  children: [
                    _dropdown(),
                    const SizedBox(height: 14),
                    _field(
                      controller: _vehicleModelController,
                      label: 'Vehicle Model',
                      icon: Icons.two_wheeler_rounded,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _vehicleRegController,
                      label: 'Vehicle Registration Number',
                      icon: Icons.confirmation_number_outlined,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _licenseController,
                      label: 'Driving License Number',
                      icon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel('ADDRESS & EMERGENCY CONTACT'),
              AppCard(
                child: Column(
                  children: [
                    _field(
                      controller: _addressController,
                      label: 'Address',
                      icon: Icons.home_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _emergencyNameController,
                      label: 'Emergency Contact Name',
                      icon: Icons.contact_emergency_outlined,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _emergencyPhoneController,
                      label: 'Emergency Contact Phone',
                      icon: Icons.phone_in_talk_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      );

  Widget _dropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _vehicleType,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.local_shipping_outlined, color: AppColors.textMuted),
        labelText: 'Vehicle Type',
      ),
      items: _vehicleTypes
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      onChanged: (value) => setState(() => _vehicleType = value),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        labelText: label,
      ),
    );
  }
}
