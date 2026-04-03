import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/constants/workspace_config.dart';
import '../core/theme/aegis_theme.dart';

/// The first screen users see — select their regulated industry workspace.
/// Premium dark-mode UI with glassmorphism cards.
class WorkspaceSelector extends StatefulWidget {
  final void Function(AegisWorkspace workspace) onWorkspaceSelected;

  const WorkspaceSelector({
    super.key,
    required this.onWorkspaceSelected,
  });

  @override
  State<WorkspaceSelector> createState() => _WorkspaceSelectorState();
}

class _WorkspaceSelectorState extends State<WorkspaceSelector>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: AegisTheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOut,
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo + Title ──
                  _buildHeader(),
                  const SizedBox(height: 48),

                  // ── Workspace Cards ──
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: isLandscape
                        ? Row(
                            children: AegisWorkspace.values
                                .asMap()
                                .entries
                                .map((entry) => Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: entry.key == 0 ? 0 : 12,
                                          right: entry.key ==
                                                  AegisWorkspace
                                                          .values.length -
                                                      1
                                              ? 0
                                              : 12,
                                        ),
                                        child: _buildWorkspaceCard(
                                            entry.value, entry.key),
                                      ),
                                    ))
                                .toList(),
                          )
                        : Column(
                            children: AegisWorkspace.values
                                .asMap()
                                .entries
                                .map((entry) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 20),
                                      child: _buildWorkspaceCard(
                                          entry.value, entry.key),
                                    ))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 48),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Shield icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6C63FF).withValues(alpha: 0.3),
                const Color(0xFF00C9A7).withValues(alpha: 0.3),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.shield_rounded,
            size: 36,
            color: Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'AEGIS',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: AegisTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Air-Gapped Edge AI Infrastructure',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            color: AegisTheme.onSurfaceDim,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF00C9A7).withValues(alpha: 0.1),
            border: Border.all(
              color: const Color(0xFF00C9A7).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00C9A7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '100% On-Device • Zero Cloud Transmission',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF00C9A7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Select Your Regulated Workspace',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AegisTheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceCard(AegisWorkspace workspace, int index) {
    final isHovered = _hoveredIndex == index;

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _scaleController,
        curve: Interval(
          index * 0.15,
          0.6 + index * 0.15,
          curve: Curves.easeOutBack,
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = index),
        onExit: (_) => setState(() => _hoveredIndex = null),
        child: GestureDetector(
          onTap: () => widget.onWorkspaceSelected(workspace),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.diagonal3Values(
              isHovered ? 1.02 : 1.0,
              isHovered ? 1.02 : 1.0,
              1.0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AegisTheme.surfaceContainer.withValues(alpha: 0.8),
                    border: Border.all(
                      color: isHovered
                          ? workspace.accentColor.withValues(alpha: 0.6)
                          : AegisTheme.divider,
                      width: isHovered ? 1.5 : 0.5,
                    ),
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: workspace.accentColor.withValues(alpha: 0.15),
                              blurRadius: 30,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: workspace.accentColor.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          workspace.icon,
                          size: 28,
                          color: workspace.accentColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      Text(
                        'Aegis for ${workspace.name}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AegisTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workspace.subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: workspace.accentColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        workspace.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AegisTheme.onSurfaceDim,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Regulation badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: workspace.accentColor.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          '🔒 ${workspace.regulation}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: workspace.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Enter button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              widget.onWorkspaceSelected(workspace),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: workspace.accentColor,
                          ),
                          child: const Text('Enter Workspace →'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterChip(Icons.memory_rounded, 'Gemma 4 E4B'),
            const SizedBox(width: 12),
            _buildFooterChip(Icons.wifi_off_rounded, 'Offline-First'),
            const SizedBox(width: 12),
            _buildFooterChip(Icons.lock_rounded, 'Air-Gapped'),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AegisTheme.surfaceContainerHigh,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AegisTheme.onSurfaceDim),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AegisTheme.onSurfaceDim,
            ),
          ),
        ],
      ),
    );
  }
}
