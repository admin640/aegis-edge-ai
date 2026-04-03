import 'package:flutter/material.dart';

/// Defines the supported Aegis workspaces.
/// Each workspace represents a vertical industry with its own
/// UI theme, system prompts, and data models.
enum AegisWorkspace {
  healthcare(
    id: 'healthcare',
    name: 'Healthcare',
    subtitle: 'Clinical Scribe',
    description: 'HIPAA + 42 CFR Part 2 compliant clinical documentation',
    icon: Icons.local_hospital_rounded,
    accentColor: Color(0xFF00C9A7), // Teal-green for health
    regulation: '42 CFR Part 2',
  ),
  legal(
    id: 'legal',
    name: 'Legal',
    subtitle: 'Discovery Desk',
    description: 'Privilege-safe evidence analysis & transcription',
    icon: Icons.gavel_rounded,
    accentColor: Color(0xFF6C63FF), // Purple for legal
    regulation: 'Attorney-Client Privilege',
  );

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String regulation;

  const AegisWorkspace({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.regulation,
  });
}
