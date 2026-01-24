import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stockflowkp/services/api_service.dart';
import 'package:stockflowkp/services/database_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CreateDukaPage extends StatefulWidget {
  const CreateDukaPage({super.key});

  @override
  State<CreateDukaPage> createState() => _CreateDukaPageState();
}

class _CreateDukaPageState extends State<CreateDukaPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _managerNameController = TextEditingController();

  // Optional coordinates
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _managerNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _submitFormat() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _dbService.getUserData();
      if (userData == null || userData['data'] == null) {
        throw Exception("User session not found.");
      }
      final token = userData['data']['token'];

      final Map<String, dynamic> dukaData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'manager_name': _managerNameController.text.trim(),
      };

      if (_latitudeController.text.isNotEmpty) {
        dukaData['latitude'] = double.tryParse(_latitudeController.text);
      }
      if (_longitudeController.text.isNotEmpty) {
        dukaData['longitude'] = double.tryParse(_longitudeController.text);
      }

      final response = await _apiService.createDuka(dukaData, token);

      if (response['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Shop created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        throw Exception(response['message'] ?? 'Failed to create shop');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Register New Shop',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  Color(0xFF1E4976),
                  Color(0xFF0A1B32),
                  Color(0xFF020B18),
                ],
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  // Moved Form up for better structure
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildSectionTitle('Basic Information'),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _nameController,
                          label: 'Shop Name',
                          icon: Icons.storefront_rounded,
                          validator:
                              (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _locationController,
                          label: 'Location / Address',
                          icon: Icons.location_on_outlined,
                          validator:
                              (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _managerNameController,
                          label: 'Manager Name (Optional)',
                          icon: Icons.person_outline_rounded,
                        ),

                        const SizedBox(height: 40),
                        _buildSectionTitle('Location Coordinates (Optional)'),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _showMapPicker,
                            icon: const Icon(
                              Icons.map_outlined,
                              color: Color(0xFF4BB4FF),
                            ),
                            label: Text(
                              'Pick on Map',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF4BB4FF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _latitudeController,
                                label: 'Latitude',
                                icon: Icons.explore_outlined,
                                readOnly: true,
                                onTap: _showMapPicker,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _longitudeController,
                                label: 'Longitude',
                                icon: Icons.explore_outlined,
                                readOnly: true,
                                onTap: _showMapPicker,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 50),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitFormat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4BB4FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 10,
                              shadowColor: const Color(
                                0xFF4BB4FF,
                              ).withOpacity(0.4),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      'Create Shop',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      onTap: onTap,
      style: GoogleFonts.plusJakartaSans(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFF4BB4FF).withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4BB4FF)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
      ),
    );
  }

  void _showMapPicker() async {
    // Default to Dar es Salaam or current text values
    double initialLat = -6.7924;
    double initialLong = 39.2083;

    if (_latitudeController.text.isNotEmpty &&
        _longitudeController.text.isNotEmpty) {
      initialLat = double.tryParse(_latitudeController.text) ?? initialLat;
      initialLong = double.tryParse(_longitudeController.text) ?? initialLong;
    }

    LatLng? selectedPoint = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => _MapPickerScreen(
              initialCenter: LatLng(initialLat, initialLong),
            ),
      ),
    );

    if (selectedPoint != null) {
      setState(() {
        _latitudeController.text = selectedPoint.latitude.toStringAsFixed(6);
        _longitudeController.text = selectedPoint.longitude.toStringAsFixed(6);
      });
    }
  }
}

class _MapPickerScreen extends StatefulWidget {
  final LatLng initialCenter;

  const _MapPickerScreen({required this.initialCenter});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late LatLng _currentPoint;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _currentPoint = widget.initialCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1B32).withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1B32).withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Tap to Select Location',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _currentPoint = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.stockflowkp.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPoint,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _currentPoint),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BB4FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 10,
                ),
                child: Text(
                  'Confirm Location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
