import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../../config/theme.dart';
import '../../services/bad_habit_service.dart';
import '../../services/usage_monitor_service.dart';
import '../../services/detox_native_timer.dart';

class AddBadHabitScreen extends StatefulWidget {
  const AddBadHabitScreen({super.key});

  @override
  State<AddBadHabitScreen> createState() => _AddBadHabitScreenState();
}

class _AddBadHabitScreenState extends State<AddBadHabitScreen> {
  final BadHabitService _service = BadHabitService();
  final _customNameCtrl    = TextEditingController();
  final _customPackageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  AppInfo? _selectedInstalledApp;
  List<AppInfo> _installedApps = [];
  bool _isLoadingApps = false;
  bool _saving        = false;
  int  _limitMinutes  = 10;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _fetchInstalledApps();
    }
  }

  Future<void> _fetchInstalledApps() async {
    setState(() => _isLoadingApps = true);
    try {
      final apps = await InstalledApps.getInstalledApps(excludeSystemApps: false, withIcon: true);
      setState(() {
        _installedApps = apps
          ..sort((a, b) => a.name.compareTo(b.name));
        _isLoadingApps = false;
      });
    } catch (_) {
      setState(() => _isLoadingApps = false);
    }
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customPackageCtrl.dispose();
    super.dispose();
  }

  String get _selectedName {
    if (_selectedInstalledApp != null) return _selectedInstalledApp!.name;
    return _customNameCtrl.text.trim();
  }

  String get _selectedPackage {
    if (_selectedInstalledApp != null) return _selectedInstalledApp!.packageName;
    return _customPackageCtrl.text.trim();
  }

  bool get _canSubmit {
    if (_selectedInstalledApp != null) return true;
    return _customNameCtrl.text.trim().isNotEmpty &&
        _customPackageCtrl.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an app first')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.addTrackedApp(
        appName: _selectedName,
        packageName: _selectedPackage,
        dailyLimitMinutes: _limitMinutes,
      );
      await UsageMonitorService.scheduleDetoxAlarms();
      // Start the native foreground-service timer immediately.
      // This timer runs in Kotlin and is NOT paused when Flutter goes to
      // the background, so the user will get an alert after exactly
      // _limitMinutes of continuous use.
      await DetoxNativeTimer.start(
        appName:      _selectedName,
        packageName:  _selectedPackage,
        limitMinutes: _limitMinutes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now tracking $_selectedName (${_limitMinutes}min/day)'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track an App'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Info banner ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                  const Color(0xFFE040FB).withValues(alpha: 0.1),
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select any app from your device to set a daily screen time limit.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Section: Choose from installed apps ────────────────────
            _buildSectionTitle('Choose from Installed Apps'),
            const SizedBox(height: 12),

            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: _isLoadingApps
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<AppInfo>(
                          isExpanded: true,
                          hint: const Text('Select an app from your device'),
                          value: _selectedInstalledApp,
                          items: _installedApps.map((AppInfo app) {
                            return DropdownMenuItem<AppInfo>(
                              value: app,
                              child: Row(
                                children: [
                                  if (app.icon != null)
                                    Image.memory(app.icon!, width: 28, height: 28)
                                  else
                                    const Icon(Icons.android, size: 28, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      app.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (AppInfo? newValue) {
                            setState(() {
                              _selectedInstalledApp = newValue;
                              _customNameCtrl.clear();
                              _customPackageCtrl.clear();
                            });
                          },
                        ),
                      ),
              )
            else
              // Non-Android fallback: manual entry fields
              Column(
                children: [
                  TextFormField(
                    controller: _customNameCtrl,
                    decoration: _inputDecoration('App name (e.g. "Clash of Clans")', Icons.label_outline),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customPackageCtrl,
                    decoration: _inputDecoration('Package name (e.g. "com.supercell.clashofclans")', Icons.code),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find the package name by searching "{app name} apk package name".',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),

            const SizedBox(height: 28),

            // ── Section: Daily time limit ──────────────────────────────
            _buildSectionTitle('Daily Time Limit'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_limitMinutes',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C4DFF),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('min / day', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                  Slider(
                    value: _limitMinutes.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 110,
                    label: '$_limitMinutes min',
                    activeColor: const Color(0xFF7C4DFF),
                    inactiveColor: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                    onChanged: (v) => setState(() => _limitMinutes = v.toInt()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('10 min', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      Text(_limitHint, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      Text('2 hrs', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Submit button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shield_outlined),
                          const SizedBox(width: 8),
                          Text(
                            _canSubmit
                                ? 'Start Tracking $_selectedName'
                                : 'Start Tracking',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String get _limitHint {
    if (_limitMinutes <= 1)  return '🧪 Test (1 min)';
    if (_limitMinutes <= 5)  return '🧪 Test mode';
    if (_limitMinutes <= 15) return '🛡️ Very strict';
    if (_limitMinutes <= 30) return '✅ Recommended';
    if (_limitMinutes <= 60) return '🟡 Moderate';
    return '⚠️ Lenient';
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
