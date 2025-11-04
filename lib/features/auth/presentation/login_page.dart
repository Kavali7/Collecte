import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/permissions/permissions_controller.dart';
import '../../../core/permissions/permissions_state.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/primary_button.dart';
import '../controllers/auth_controller.dart';
import '../domain/auth_state.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _permissionFlowStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePermissions();
    });
  }

  Future<void> _initializePermissions() async {
    if (!mounted) return;
    final controller = ref.read(permissionsControllerProvider.notifier);
    await controller.initialize();
    if (!mounted) return;

    final permissionsState = ref.read(permissionsControllerProvider);
    final shouldStartFlow = !_permissionFlowStarted &&
        !permissionsState.isGranted &&
        !permissionsState.permanentlyDenied;

    if (shouldStartFlow) {
      _permissionFlowStarted = true;
      await _startPermissionFlow(context);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final permissionsState = ref.watch(permissionsControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      final hasNewError = previous?.errorMessage != next.errorMessage;
      if (hasNewError && next.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    ref.listen(permissionsControllerProvider, (previous, next) {
      final hasNewMessage = previous?.message != next.message;
      if (hasNewMessage && next.message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.message!)));
      }
    });

    final content = _buildContent(context, authState, permissionsState);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AuthState authState,
    PermissionsState permissionsState,
  ) {
    if (permissionsState.isLoading) {
      return const _CenteredLoader();
    }

    if (!permissionsState.isGranted) {
      return _PermissionRequestPanel(
        isProcessing: permissionsState.isLoading,
        permanentlyDenied: permissionsState.permanentlyDenied,
        onRequest: () => _startPermissionFlow(context),
        onOpenSettings: () =>
            ref.read(permissionsControllerProvider.notifier).openSettings(),
        onCheckStatus: () =>
            ref.read(permissionsControllerProvider.notifier).initialize(),
      );
    }

    return _LoginForm(
      authState: authState,
      emailController: _emailController,
      passwordController: _passwordController,
      obscurePassword: _obscurePassword,
      onTogglePassword: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
      onSignInEmail: () {
        ref
            .read(authControllerProvider.notifier)
            .signInWithEmail(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      },
    );
  }

  Future<void> _startPermissionFlow(BuildContext context) async {
    final controller = ref.read(permissionsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final acceptCamera = await _showPermissionDialog(
      context,
      title: 'Autoriser la camera ?',
      description:
          'L\'application a besoin d\'acceder a la camera pour prendre la photo de la boutique. Souhaites-tu autoriser cet acces ?',
      confirmLabel: 'Autoriser la camera',
    );
    if (!acceptCamera) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Autorisation camera necessaire pour poursuivre la collecte.',
          ),
        ),
      );
      return;
    }

    final cameraStatus = await controller.requestCameraOnly();
    if (!context.mounted) return;
    if (!cameraStatus.isGranted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Camera non autorisee. Active-la pour continuer l\'utilisation.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final acceptLocation = await _showPermissionDialog(
      context,
      title: 'Autoriser la localisation ?',
      description:
          'Pour verifier que la photo est prise dans la boutique, nous ajoutons automatiquement les coordonnees GPS. Autorises-tu l\'application a acceder a ta localisation ?',
      confirmLabel: 'Autoriser la localisation',
    );
    if (!acceptLocation) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'La localisation est obligatoire pour valider chaque collecte.',
          ),
        ),
      );
      return;
    }

    final locationStatus = await controller.requestLocationOnly();
    if (!context.mounted) return;
    if (!locationStatus.isGranted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Localisation non activee. Utilise le bouton Reglages pour l\'autoriser.',
          ),
        ),
      );
      return;
    }

    await controller.refreshStatuses();
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Merci ! Les autorisations camera et localisation sont actives.',
        ),
      ),
    );
  }

  Future<bool> _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String description,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.authState,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSignInEmail,
  });

  final AuthState authState;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignInEmail;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppLogo(),
            const SizedBox(height: 32),
            Text(
              'Collecte des revendeurs',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Connecte-toi pour recenser les boutiques et suivre les informations des gerants.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !authState.isLoading,
              decoration: const InputDecoration(
                labelText: 'Adresse email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              enabled: !authState.isLoading,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Se connecter',
              onPressed: authState.isLoading ? null : onSignInEmail,
              isLoading: authState.isLoading,
            ),
            const SizedBox(height: 24),
            Text(
              'En te connectant tu pourras prendre des photos, recuperer les coordonnees des gerants et preparer la synchronisation.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRequestPanel extends StatelessWidget {
  const _PermissionRequestPanel({
    required this.isProcessing,
    required this.permanentlyDenied,
    required this.onRequest,
    required this.onOpenSettings,
    required this.onCheckStatus,
  });

  final bool isProcessing;
  final bool permanentlyDenied;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;
  final VoidCallback onCheckStatus;

  @override
  Widget build(BuildContext context) {
    final actionText = permanentlyDenied
        ? 'Ouvrir les reglages'
        : 'Autoriser l\'acces';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppLogo(),
            const SizedBox(height: 32),
            Text(
              'Autorisation requise',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'L\'application doit acceder a la camera et a la localisation pour verifier que les photos sont prises sur site.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: actionText,
              onPressed: isProcessing
                  ? null
                  : permanentlyDenied
                  ? onOpenSettings
                  : onRequest,
              isLoading: isProcessing,
              icon: permanentlyDenied ? Icons.settings : Icons.verified_user,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isProcessing ? null : onOpenSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Aller aux reglages'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: isProcessing ? null : onCheckStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Verifier a nouveau'),
            ),
            const SizedBox(height: 24),
            Text(
              'Sans ces autorisations, l\'acces restera bloque.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            _PermissionGuidelines(permanentlyDenied: permanentlyDenied),
          ],
        ),
      ),
    );
  }
}

class _PermissionGuidelines extends StatelessWidget {
  const _PermissionGuidelines({required this.permanentlyDenied});

  final bool permanentlyDenied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pourquoi c\'est necessaire :',
          style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _GuidelineRow(
          icon: Icons.photo_camera_outlined,
          text:
              'La camera permet de capturer la boutique directement depuis le terrain.',
        ),
        const SizedBox(height: 6),
        _GuidelineRow(
          icon: Icons.location_on_outlined,
          text:
              'La localisation ajoute automatiquement les coordonnees GPS pour verifier le lieu.',
        ),
        const SizedBox(height: 6),
        if (permanentlyDenied)
          _GuidelineRow(
            icon: Icons.info_outline,
            text:
                'Si aucune fenetre ne s\'affiche, utilise le bouton "Aller aux reglages" pour activer manuellement les autorisations.',
          )
        else
          _GuidelineRow(
            icon: Icons.touch_app,
            text:
                'Accepte les deux demandes d\'autorisation qui vont s\'afficher apres avoir appuye sur "Autoriser maintenant".',
          ),
      ],
    );
  }
}

class _GuidelineRow extends StatelessWidget {
  const _GuidelineRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1D4ED8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
