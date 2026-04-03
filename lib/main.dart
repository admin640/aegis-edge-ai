import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/constants/workspace_config.dart';
import 'core/theme/aegis_theme.dart';
import 'core/engine/gemma_service.dart';
import 'core/engine/audio_service.dart';
import 'core/auth/auth_service.dart';
import 'core/storage/firestore_service.dart';
import 'core/storage/local_storage_service.dart';
import 'workspaces/workspace_selector.dart';
import 'workspaces/healthcare/healthcare_home.dart';
import 'workspaces/legal/legal_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize on-device AI runtime
  GemmaService.initializeRuntime();

  // Initialize local storage directories
  await LocalStorageService.init();

  runApp(const AegisApp());
}

class AegisApp extends StatefulWidget {
  const AegisApp({super.key});

  @override
  State<AegisApp> createState() => _AegisAppState();
}

class _AegisAppState extends State<AegisApp> {
  AegisWorkspace? _activeWorkspace;

  void _selectWorkspace(AegisWorkspace workspace) {
    setState(() => _activeWorkspace = workspace);
  }

  void _exitWorkspace() {
    setState(() => _activeWorkspace = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _activeWorkspace != null
        ? AegisTheme.forWorkspace(_activeWorkspace!)
        : AegisTheme.defaultTheme;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GemmaService()),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
      ],
      child: MaterialApp(
        title: 'Aegis — Air-Gapped Edge AI',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: _activeWorkspace == null
            ? WorkspaceSelector(onWorkspaceSelected: _selectWorkspace)
            : _buildWorkspaceScreen(_activeWorkspace!),
      ),
    );
  }

  Widget _buildWorkspaceScreen(AegisWorkspace workspace) {
    switch (workspace) {
      case AegisWorkspace.healthcare:
        return HealthcareHome(onExit: _exitWorkspace);
      case AegisWorkspace.legal:
        return LegalHome(onExit: _exitWorkspace);
    }
  }
}

