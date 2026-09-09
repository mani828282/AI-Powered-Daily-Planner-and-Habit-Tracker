import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  Widget _buildNavIcon(IconData icon, String label, int index) {
    final isSelected = currentIndex == index;
    // Purple color for all icons, but more vibrant/opaque for the selected one
    final color = isSelected
        ? const Color(0xFF9C27B0)
        : const Color(0xFF9C27B0).withValues(alpha: 0.5);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 12.0, // Space around the FAB
      color: Colors.transparent, // Let the inner Container show through
      elevation:
          0, // Shadow handling is tricky with transparent color, so we use container or set zero
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.zero,
      child: Container(
        height: 65,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF0F5), // Lavender Blush (light pink)
              Color(0xFFFFE4E1), // Misty Rose
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Side
            _buildNavIcon(Icons.home, 'Home', 0),
            _buildNavIcon(Icons.check_circle, 'Tasks', 1),
            _buildNavIcon(Icons.repeat, 'Habits', 2),

            // Middle cutout for FAB
            const SizedBox(width: 60),

            // Right Side
            _buildNavIcon(Icons.phone_android, 'Detox', 3),
            _buildNavIcon(Icons.flag, 'Goals', 4),
            _buildNavIcon(Icons.person, 'Profile', 5),
          ],
        ),
      ),
    );
  }
}
