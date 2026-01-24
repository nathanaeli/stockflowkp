import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _statusMessage = 'Initializing sync...';
  double _progress = 0.0;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startSync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSync() async {
    try {
      final dbService = DatabaseService();
      final user = await dbService.getUserData();

      if (user == null ||
          user['data'] == null ||
          user['data']['token'] == null) {
        throw Exception('User authentication not found. Please login again.');
      }

      final token = user['data']['token'];

      setState(() {
        _statusMessage = 'Connecting to server...';
        _progress = 0.1;
      });

      final response = await ApiService().syncOfficerProducts(token);

      if (response == null) {
        throw Exception('Failed to fetch data from server.');
      }

      setState(() {
        _statusMessage = 'Processing data...';
        _progress = 0.3;
      });

      // 2. Save to Local Database with Progress
      await dbService.syncAllData(
        response,
        onProgress: (label, current, total) {
          if (!mounted) return;
          setState(() {
            _statusMessage = 'Syncing ${label.replaceAll('_', ' ')}...';
            // Map the remaining 70% of progress to the database steps
            _progress = 0.3 + (0.7 * (current / total));
          });
        },
      );

      // 3. Complete
      setState(() {
        _statusMessage = 'Sync Complete!';
        _progress = 1.0;
      });
      _controller.stop();

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _statusMessage = 'Sync Failed';
        _controller.stop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Dark background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [if (_hasError) _buildErrorView() else _buildSyncView()],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Premium Pulse Animation
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF3B82F6,
                        ).withOpacity(0.5 * (1 - _controller.value)),
                        blurRadius: 20 + (30 * _controller.value),
                        spreadRadius: 5 + (20 * _controller.value),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Inner circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F172A),
                border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF3B82F6),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.sync, color: Colors.white, size: 40),
            ),
          ],
        ),
        const SizedBox(height: 60),

        // Status Text
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${(_progress * 100).toInt()}%',
          style: GoogleFonts.spaceMono(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, color: Colors.red, size: 60),
        ),
        const SizedBox(height: 32),
        Text(
          'Oops!',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(color: Colors.white54),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _statusMessage = 'Retrying...';
                  _progress = 0.0;
                });
                _controller.repeat();
                _startSync();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
