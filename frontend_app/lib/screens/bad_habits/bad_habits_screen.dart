import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/bad_habit_service.dart';
import '../../services/usage_monitor_service.dart';
import '../../services/detox_native_timer.dart';
import 'add_bad_habit_screen.dart';

class BadHabitsScreen extends StatefulWidget {
  const BadHabitsScreen({super.key});

  @override
  State<BadHabitsScreen> createState() => _BadHabitsScreenState();
}

class _BadHabitsScreenState extends State<BadHabitsScreen> {
  final BadHabitService _service = BadHabitService();

  List<Map<String, dynamic>> _apps = [];
  Map<String, dynamic> _usageData  = {};
  bool _loading          = true;
  bool _hasPermission    = false;
  bool _batteryOptimized = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _hasPermission = await UsageMonitorService.hasUsagePermission();
    await _loadData();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      // Use a platform channel to check if battery optimization is disabled
      const platform = MethodChannel('android_battery_channel');
      final isIgnoring = await platform.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      if (mounted) setState(() => _batteryOptimized = isIgnoring);
    } catch (_) {
      // If channel not available, assume OK
    }
  }

  Future<void> _openBatterySettings() async {
    try {
      const platform = MethodChannel('android_battery_channel');
      await platform.invokeMethod('openBatterySettings');
    } catch (_) {
      // fallback: show instructions dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.battery_alert, color: Colors.orange),
              SizedBox(width: 8),
              Text('Disable Battery Optimization'),
            ],
          ),
          content: const Text(
            'To receive notifications on time:\n\n'
            '1. Go to Settings → Battery\n'
            '2. Find "AI Planner"\n'
            '3. Set to "No restrictions" or "Don\'t optimize"\n\n'
            'This allows the app to check your screen time in the background.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final usageData = await _service.getTodayUsage();
      setState(() {
        _usageData = usageData;
        _apps = List<Map<String, dynamic>>.from(
          (_usageData['apps'] as List?) ?? [],
        );
        _loading = false;
      });
      // Start the native foreground-service monitor for tracked apps.
      // This uses queryEvents() to detect real foreground usage — no old data.
      _startNativeTimersForAllApps();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  /// Starts the native Kotlin foreground service with ALL tracked apps at once.
  /// The service monitors which app is actively in the foreground and only
  /// counts session time for that one (resets others to 0 on switch).
  void _startNativeTimersForAllApps() {
    if (_apps.isEmpty) {
      DetoxNativeTimer.cancel();
      return;
    }
    DetoxNativeTimer.startAll(_apps);
  }

  Color _usageColor(int pct) {
    if (pct >= 100) return const Color(0xFFE53935);
    if (pct >= 75)  return const Color(0xFFFF7043);
    if (pct >= 50)  return const Color(0xFFFFA726);
    return const Color(0xFF4CAF50);
  }

  IconData _appIcon(String appName) {
    final n = appName.toLowerCase();
    if (n.contains('instagram'))   return Icons.camera_alt;
    if (n.contains('tiktok'))      return Icons.music_video;
    if (n.contains('twitter') || n.contains('x ')) return Icons.tag;
    if (n.contains('youtube'))     return Icons.play_circle;
    if (n.contains('facebook'))    return Icons.facebook;
    if (n.contains('snapchat'))    return Icons.camera;
    if (n.contains('whatsapp'))    return Icons.chat;
    return Icons.phone_android;
  }

  Future<void> _openSettingsForPermission() async {
    // On Android, direct user to Usage Access settings
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF7C4DFF)),
            SizedBox(width: 8),
            Text('Grant Usage Access'),
          ],
        ),
        content: const Text(
          'To track screen time, please go to:\n\n'
          'Settings → Apps → Special app access → Usage access\n\n'
          'Then enable access for AI Planner.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // In production, use `open_settings` package or platform channel
              // to deep-link to android.settings.USAGE_ACCESS_SETTINGS
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteApp(int appId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Stop Tracking?'),
        content: Text('Remove $name from your tracked apps?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteTrackedApp(appId);
      // Cancel the OS alarm for this app
      await UsageMonitorService.cancelAlarmsForPackage(
        _apps.firstWhere((a) => a['id'] == appId, orElse: () => {})['package_name'] ?? '',
      );
      _loadData();
    }
  }

  Future<void> _editLimit(Map<String, dynamic> app) async {
    int newLimit = (app['daily_limit_minutes'] as num).toInt();
    // Clamp to new minimum of 10
    if (newLimit < 10) newLimit = 10;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Set limit for ${app['app_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$newLimit minutes/day',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: newLimit.toDouble(),
                min: 10,
                max: 120,
                divisions: 110,
                label: '$newLimit min',
                activeColor: AppTheme.primaryPurple,
                onChanged: (v) => setDlgState(() => newLimit = v.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Clear "already notified" flag so the new limit gets a fresh alarm
                await UsageMonitorService.resetNotifiedFlagForPackage(
                  app['package_name'] as String? ?? '',
                );
                await _service.updateLimit(app['id'], newLimit);
                // Restart the native timer with the new limit immediately
                await DetoxNativeTimer.cancel();
                await DetoxNativeTimer.start(
                  appName:      app['app_name']     as String? ?? 'App',
                  packageName:  app['package_name'] as String? ?? '',
                  limitMinutes: newLimit,
                );
                _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (!_hasPermission) SliverToBoxAdapter(child: _buildPermissionBanner()),
                  if (!_batteryOptimized) SliverToBoxAdapter(child: _buildBatteryBanner()),
                  if (_apps.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildAppCard(_apps[i]),
                        childCount: _apps.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBadHabitScreen()),
          );
          _loadData();
        },
        backgroundColor: AppTheme.primaryPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Track App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7C4DFF),
            Color(0xFFE040FB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Text(
                'Digital Detox',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Track and limit your addictive app usage',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return GestureDetector(
      onTap: _openSettingsForPermission,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF9800), width: 1.5),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Usage Access not granted. Tap here to enable screen time tracking.',
                style: TextStyle(fontSize: 13, color: Color(0xFFE65100)),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFFF9800)),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryBanner() {
    return GestureDetector(
      onTap: _openBatterySettings,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE), // Light red
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF44336), width: 1.5), // Red
        ),
        child: const Row(
          children: [
            Icon(Icons.battery_alert, color: Color(0xFFF44336)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Battery optimization may delay notifications. Tap to disable.',
                style: TextStyle(fontSize: 13, color: Color(0xFFC62828)), // Dark red
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFF44336)),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_android, size: 64, color: Color(0xFF7C4DFF)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Apps Tracked Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add apps you spend too much time on — Instagram, TikTok, YouTube — and set daily limits.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app) {
    final limit    = (app['daily_limit_minutes'] as num? ?? 30).toInt();
    final appName  = app['app_name'] as String? ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // App icon bubble
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_appIcon(appName), color: AppTheme.primaryPurple, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Monitoring active usage',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _editLimit(app),
                tooltip: 'Edit limit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: () => _deleteApp(app['id'], appName),
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Alert triggers after $limit continuous minutes',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
