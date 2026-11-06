import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/internet_service.dart';
import '../../data/services/storage_service.dart';
import '../../widgets/app_form_controls.dart';

enum _AuthMode { signIn, createAccount }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmationVisible = false;
  bool _acceptedTerms = false;
  String? _message;
  String? _googleMessage;
  InlineNoticeType _noticeType = InlineNoticeType.error;
  InlineNoticeType _googleNoticeType = InlineNoticeType.error;
  AuthRecoveryAction? _recoveryAction;
  AuthRecoveryAction? _googleRecoveryAction;
  Future<void> Function()? _retryAction;
  Future<void> Function()? _googleRetryAction;

  @override
  void initState() {
    super.initState();
    _email.addListener(_refreshForm);
    _password.addListener(_refreshForm);
    _confirmation.addListener(_refreshForm);
  }

  @override
  void dispose() {
    _email
      ..removeListener(_refreshForm)
      ..dispose();
    _password
      ..removeListener(_refreshForm)
      ..dispose();
    _confirmation
      ..removeListener(_refreshForm)
      ..dispose();
    super.dispose();
  }

  void _refreshForm() {
    if (mounted) setState(() {});
  }

  bool get _hasValidEmail =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim());
  bool get _hasLoginPassword => _password.text.length >= 6;
  bool get _hasEightCharacters => _password.text.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(_password.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_password.text);
  bool get _hasStrongPassword => _hasEightCharacters && _hasLetter && _hasDigit;
  bool get _canSubmit {
    if (_mode == _AuthMode.signIn) {
      return _hasValidEmail && _hasLoginPassword;
    }
    return _hasValidEmail &&
        _hasStrongPassword &&
        _password.text == _confirmation.text &&
        _acceptedTerms;
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.home, (route) => false);
    }
  }

  Future<void> _onAuthSuccess(UserCredential? credential) async {
    if (credential?.user == null) {
      _setNotice(
        FirebaseAuthService.instance.lastError ??
            'Connexion annulée ou impossible. Réessaie plus tard.',
        action: AuthRecoveryAction.retry,
      );
      return;
    }

    final user = credential!.user!;
    await StorageService.setUserId(user.uid);
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      await StorageService.setUserName(user.displayName!.trim());
    }
    await InternetService().setEnabled(true);
    await InternetService().reregister();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Connexion réussie.')));
    await _goHome();
  }

  Future<void> _run(
    Future<UserCredential?> Function() action, {
    required bool isGoogle,
  }) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (isGoogle) {
        _googleMessage = null;
        _googleRecoveryAction = null;
        _googleRetryAction = () => _run(action, isGoogle: true);
      } else {
        _message = null;
        _recoveryAction = null;
        _retryAction = () => _run(action, isGoogle: false);
      }
    });

    try {
      final initialized = await FirebaseAuthService.instance.initialize();
      if (!initialized) {
        _setNotice(
          FirebaseAuthService.instance.lastError ??
              'Le service de connexion est indisponible pour le moment.',
          action: AuthRecoveryAction.continueOffline,
          isGoogle: isGoogle,
        );
        return;
      }
      final result = await action();
      await _onAuthSuccess(result);
    } on FirebaseAuthException catch (error) {
      debugPrint('Login Firebase error: ${error.code}');
      _showMappedError(
        ErrorMapper.authentication(
          error,
          isGoogle: isGoogle,
          isCreatingAccount: _mode == _AuthMode.createAccount,
        ),
        isGoogle: isGoogle,
      );
    } catch (error) {
      debugPrint('Login error: $error');
      _showMappedError(
        ErrorMapper.authentication(
          error,
          isGoogle: isGoogle,
          isCreatingAccount: _mode == _AuthMode.createAccount,
        ),
        isGoogle: isGoogle,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMappedError(UserFacingError error, {required bool isGoogle}) {
    HapticFeedback.lightImpact();
    _setNotice(error.message, action: error.action, isGoogle: isGoogle);
  }

  void _setNotice(
    String message, {
    AuthRecoveryAction? action,
    InlineNoticeType type = InlineNoticeType.error,
    bool isGoogle = false,
  }) {
    if (!mounted) return;
    setState(() {
      if (isGoogle) {
        _googleMessage = message;
        _googleNoticeType = type;
        _googleRecoveryAction = action;
      } else {
        _message = message;
        _noticeType = type;
        _recoveryAction = action;
      }
    });
  }

  Future<void> _emailLogin() {
    return _run(
      () => FirebaseAuthService.instance.signInWithEmail(
        _email.text,
        _password.text,
      ),
      isGoogle: false,
    );
  }

  Future<void> _googleLogin() {
    return _run(FirebaseAuthService.instance.signInWithGoogle, isGoogle: true);
  }

  Future<void> _createAccount() {
    return _run(
      () => FirebaseAuthService.instance.createAccount(
        _email.text,
        _password.text,
      ),
      isGoogle: false,
    );
  }

  Future<void> _submitEmailForm() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || !_canSubmit) return;
    if (_mode == _AuthMode.createAccount) {
      await _createAccount();
    } else {
      await _emailLogin();
    }
  }

  Future<void> _sendPasswordReset() async {
    if (!_hasValidEmail) {
      _setNotice(
        'Saisis ton adresse e-mail pour recevoir le lien de réinitialisation.',
      );
      return;
    }
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
      _googleMessage = null;
      _recoveryAction = null;
      _googleRecoveryAction = null;
      _retryAction = _sendPasswordReset;
    });
    try {
      await FirebaseAuthService.instance.sendPasswordReset(_email.text);
      if (!mounted) return;
      _setNotice(
        'Si cette adresse possède un compte, un e-mail de réinitialisation vient d’être envoyé.',
        type: InlineNoticeType.success,
      );
    } on FirebaseAuthException catch (error) {
      debugPrint('Password reset Firebase error: ${error.code}');
      _showMappedError(
        ErrorMapper.authentication(
          error,
          isGoogle: false,
          isCreatingAccount: false,
        ),
        isGoogle: false,
      );
    } catch (error) {
      debugPrint('Password reset error: $error');
      _showMappedError(
        ErrorMapper.authentication(
          error,
          isGoogle: false,
          isCreatingAccount: false,
        ),
        isGoogle: false,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchMode(_AuthMode mode) {
    if (_loading || mode == _mode) return;
    setState(() {
      _mode = mode;
      _message = null;
      _googleMessage = null;
      _recoveryAction = null;
      _googleRecoveryAction = null;
    });
  }

  Future<void> _runRecoveryAction({bool isGoogle = false}) async {
    final action = isGoogle ? _googleRecoveryAction : _recoveryAction;
    switch (action) {
      case AuthRecoveryAction.retry:
        await _retryAction?.call();
        break;
      case AuthRecoveryAction.useEmail:
      case AuthRecoveryAction.signIn:
        _switchMode(_AuthMode.signIn);
        break;
      case AuthRecoveryAction.forgotPassword:
        await _sendPasswordReset();
        break;
      case AuthRecoveryAction.continueOffline:
        await _goHome();
        break;
      case null:
        break;
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Saisis ton adresse e-mail.';
    }
    if (!_hasValidEmail) return 'Adresse e-mail invalide.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Le mot de passe doit comporter au moins 6 caractères.';
    }
    if (_mode == _AuthMode.createAccount && !_hasStrongPassword) {
      return 'Utilise au moins 8 caractères, une lettre et un chiffre.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (_mode == _AuthMode.createAccount && value != _password.text) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }

  String? _actionLabel(AuthRecoveryAction? action) => switch (action) {
    AuthRecoveryAction.retry => 'Réessayer',
    AuthRecoveryAction.useEmail => 'Utiliser mon e-mail',
    AuthRecoveryAction.signIn => 'Se connecter',
    AuthRecoveryAction.forgotPassword => 'Mot de passe oublié ?',
    AuthRecoveryAction.continueOffline => 'Continuer sans compte',
    null => null,
  };
  String? get _noticeActionLabel => _actionLabel(_recoveryAction);
  String? get _googleNoticeActionLabel => _actionLabel(_googleRecoveryAction);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final creating = _mode == _AuthMode.createAccount;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/upchat_u_icon.png',
                              width: 92,
                              height: 92,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _loading ? null : _goHome,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const Text('RETOUR À L’ACCUEIL'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      creating ? 'Créer un compte' : 'Connexion',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: text, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      creating
                          ? 'Crée un compte pour retrouver tes discussions sur tes appareils.'
                          : 'Connecte-toi pour retrouver tes discussions sur tes appareils.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 22),
                    _GoogleButton(loading: _loading, onPressed: _googleLogin),
                    if (_googleMessage != null) ...[
                      const SizedBox(height: 12),
                      InlineNotice(
                        type: _googleNoticeType,
                        message: _googleMessage!,
                        actionLabel: _googleNoticeActionLabel,
                        onAction: _googleRecoveryAction == null
                            ? null
                            : () => _runRecoveryAction(isGoogle: true),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: muted.withValues(alpha: .25)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('ou', style: TextStyle(color: muted)),
                        ),
                        Expanded(
                          child: Divider(color: muted.withValues(alpha: .25)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ModeSelector(mode: _mode, onChanged: _switchMode),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _email,
                            label: 'Adresse e-mail',
                            prefixIcon: Icons.mail_outline_rounded,
                            hintText: 'nom@exemple.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: _validateEmail,
                            enabled: !_loading,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _password,
                            label: 'Mot de passe',
                            prefixIcon: Icons.lock_outline_rounded,
                            textInputAction: creating
                                ? TextInputAction.next
                                : TextInputAction.done,
                            obscureText: !_passwordVisible,
                            autofillHints: [
                              creating
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            suffixIcon: IconButton(
                              tooltip: _passwordVisible
                                  ? 'Masquer le mot de passe'
                                  : 'Afficher le mot de passe',
                              onPressed: _loading
                                  ? null
                                  : () => setState(
                                      () =>
                                          _passwordVisible = !_passwordVisible,
                                    ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            validator: _validatePassword,
                            enabled: !_loading,
                            onFieldSubmitted: creating
                                ? null
                                : (_) => _submitEmailForm(),
                          ),
                          if (creating) ...[
                            const SizedBox(height: 12),
                            _PasswordRules(
                              hasEightCharacters: _hasEightCharacters,
                              hasLetter: _hasLetter,
                              hasDigit: _hasDigit,
                            ),
                            const SizedBox(height: 8),
                            _PasswordStrength(value: [
                              _hasEightCharacters,
                              _hasLetter,
                              _hasDigit,
                              _password.text.length >= 12,
                            ].where((value) => value).length),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _confirmation,
                              label: 'Confirmer le mot de passe',
                              prefixIcon: Icons.lock_reset_rounded,
                              textInputAction: TextInputAction.done,
                              obscureText: !_confirmationVisible,
                              autofillHints: const [AutofillHints.newPassword],
                              suffixIcon: IconButton(
                                tooltip: _confirmationVisible
                                    ? 'Masquer le mot de passe'
                                    : 'Afficher le mot de passe',
                                onPressed: _loading
                                    ? null
                                    : () => setState(
                                        () => _confirmationVisible =
                                            !_confirmationVisible,
                                      ),
                                icon: Icon(
                                  _confirmationVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                              validator: _validateConfirmation,
                              enabled: !_loading,
                              onFieldSubmitted: (_) => _submitEmailForm(),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _acceptedTerms,
                              onChanged: _loading
                                  ? null
                                  : (value) => setState(
                                      () => _acceptedTerms = value ?? false,
                                    ),
                              title: const Text(
                                'J’accepte les conditions d’utilisation.',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppColors.primary,
                            ),
                          ],
                          if (!creating)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading ? null : _sendPasswordReset,
                                child: const Text('Mot de passe oublié ?'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          AppButton(
                            label: creating
                                ? 'Créer mon compte'
                                : 'Se connecter',
                            icon: creating
                                ? Icons.person_add_alt_1_rounded
                                : Icons.login_rounded,
                            loading: _loading,
                            onPressed: _canSubmit ? _submitEmailForm : null,
                          ),
                        ],
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      InlineNotice(
                        type: _noticeType,
                        message: _message!,
                        actionLabel: _noticeActionLabel,
                        onAction: _recoveryAction == null
                            ? null
                            : _runRecoveryAction,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Continuer sans compte',
                      icon: Icons.wifi_off_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _loading ? null : _goHome,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Le mode hors ligne reste disponible sans compte.',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.value});
  final int value;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: List.generate(4, (index) => Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 5,
          margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
          decoration: BoxDecoration(
            color: index < value ? color : color.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      )),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, _AuthMode value) {
      final selected = mode == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          tab('Se connecter', _AuthMode.signIn),
          tab('Créer un compte', _AuthMode.createAccount),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const _GoogleMark(),
        label: Text(
          loading ? 'Connexion en cours…' : 'Continuer avec Google',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFFBBC05),
          Color(0xFFEA4335),
        ],
      ).createShader(bounds),
      child: const Text(
        'G',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PasswordRules extends StatelessWidget {
  const _PasswordRules({
    required this.hasEightCharacters,
    required this.hasLetter,
    required this.hasDigit,
  });

  final bool hasEightCharacters;
  final bool hasLetter;
  final bool hasDigit;

  @override
  Widget build(BuildContext context) {
    Widget rule(bool met, String text) => Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: met
              ? AppColors.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: met
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rule(hasEightCharacters, '8 caractères minimum'),
        const SizedBox(height: 4),
        rule(hasLetter, 'Au moins une lettre'),
        const SizedBox(height: 4),
        rule(hasDigit, 'Au moins un chiffre'),
      ],
    );
  }
}
