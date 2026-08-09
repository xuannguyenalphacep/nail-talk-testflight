import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/constants/app_constants.dart';
import '../widgets/app_logo.dart';

enum _AuthMode { login, register }

const _authInk = Color(0xFF132642);
const _authMuted = Color(0xFF6B7E97);
const _authLine = Color(0xFFDDE7F4);
const _authBlueSoft = Color(0xFFEAF3FF);
const _authMintSoft = Color(0xFFEAF9F4);
const _authCoralSoft = Color(0xFFFFEEF1);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _nameController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _obscureLogin = true;
  bool _obscureRegister = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _registerUsernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final session = context.read<SessionController>();
    try {
      await session.login(
        username: _loginUsernameController.text.trim(),
        password: _loginPasswordController.text,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.error ?? 'Sign-in failed.')),
      );
    }
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final session = context.read<SessionController>();
    try {
      await session.register(
        name: _nameController.text.trim(),
        username: _registerUsernameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        password: _registerPasswordController.text,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.error ?? 'Sign-up failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);
    final isLogin = _mode == _AuthMode.login;
    final serviceReady = session.selectedApp != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9FBFF), Color(0xFFEFF4FF), Color(0xFFF8FCFB)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;

              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, wide ? 28 : 16, 18, 26),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 11,
                                child: _AuthHeroPanel(theme: theme),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 10,
                                child: _AuthFormPanel(
                                  mode: _mode,
                                  showLogo: false,
                                  serviceReady: serviceReady,
                                  submitting: session.submitting,
                                  error: session.error,
                                  onRetry: session.bootstrap,
                                  onModeChanged: (mode) =>
                                      setState(() => _mode = mode),
                                  onFlipMode: () => setState(() {
                                    _mode = isLogin
                                        ? _AuthMode.register
                                        : _AuthMode.login;
                                  }),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: isLogin
                                        ? _LoginForm(
                                            key: const ValueKey('login-form'),
                                            formKey: _loginFormKey,
                                            usernameController:
                                                _loginUsernameController,
                                            passwordController:
                                                _loginPasswordController,
                                            obscure: _obscureLogin,
                                            submitting: session.submitting,
                                            ready: serviceReady,
                                            onTogglePassword: () => setState(
                                              () => _obscureLogin =
                                                  !_obscureLogin,
                                            ),
                                            onSubmit: _submitLogin,
                                          )
                                        : _RegisterForm(
                                            key: const ValueKey(
                                              'register-form',
                                            ),
                                            formKey: _registerFormKey,
                                            nameController: _nameController,
                                            usernameController:
                                                _registerUsernameController,
                                            emailController: _emailController,
                                            phoneController: _phoneController,
                                            passwordController:
                                                _registerPasswordController,
                                            confirmPasswordController:
                                                _confirmPasswordController,
                                            obscurePassword: _obscureRegister,
                                            obscureConfirm: _obscureConfirm,
                                            submitting: session.submitting,
                                            ready: serviceReady,
                                            onTogglePassword: () => setState(
                                              () => _obscureRegister =
                                                  !_obscureRegister,
                                            ),
                                            onToggleConfirm: () => setState(
                                              () => _obscureConfirm =
                                                  !_obscureConfirm,
                                            ),
                                            onSubmit: _submitRegister,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _AuthFormPanel(
                                mode: _mode,
                                showLogo: true,
                                serviceReady: serviceReady,
                                submitting: session.submitting,
                                error: session.error,
                                onRetry: session.bootstrap,
                                onModeChanged: (mode) =>
                                    setState(() => _mode = mode),
                                onFlipMode: () => setState(() {
                                  _mode = isLogin
                                      ? _AuthMode.register
                                      : _AuthMode.login;
                                }),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: isLogin
                                      ? _LoginForm(
                                          key: const ValueKey('login-form'),
                                          formKey: _loginFormKey,
                                          usernameController:
                                              _loginUsernameController,
                                          passwordController:
                                              _loginPasswordController,
                                          obscure: _obscureLogin,
                                          submitting: session.submitting,
                                          ready: serviceReady,
                                          onTogglePassword: () => setState(
                                            () =>
                                                _obscureLogin = !_obscureLogin,
                                          ),
                                          onSubmit: _submitLogin,
                                        )
                                      : _RegisterForm(
                                          key: const ValueKey('register-form'),
                                          formKey: _registerFormKey,
                                          nameController: _nameController,
                                          usernameController:
                                              _registerUsernameController,
                                          emailController: _emailController,
                                          phoneController: _phoneController,
                                          passwordController:
                                              _registerPasswordController,
                                          confirmPasswordController:
                                              _confirmPasswordController,
                                          obscurePassword: _obscureRegister,
                                          obscureConfirm: _obscureConfirm,
                                          submitting: session.submitting,
                                          ready: serviceReady,
                                          onTogglePassword: () => setState(
                                            () => _obscureRegister =
                                                !_obscureRegister,
                                          ),
                                          onToggleConfirm: () => setState(
                                            () => _obscureConfirm =
                                                !_obscureConfirm,
                                          ),
                                          onSubmit: _submitRegister,
                                        ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthHeroPanel extends StatelessWidget {
  const _AuthHeroPanel({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10213D), Color(0xFF185EC9), Color(0xFF27B7C9)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16102642),
            blurRadius: 34,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const AppLogo(size: 56),
          ),
          const SizedBox(height: 32),
          Text(
            'One place for salon work, room share, and local updates.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: 42,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Nail Talk is built for Vietnamese beauty professionals in the U.S. Sign in once, then move between job leads, housing posts, movie access, marketplace finds, and live chat without extra setup.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.62,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroChip(
                icon: Icons.badge_rounded,
                label: 'Salon-ready profiles',
              ),
              _HeroChip(
                icon: Icons.maps_home_work_rounded,
                label: 'Room share and housing',
              ),
              _HeroChip(
                icon: Icons.chat_bubble_rounded,
                label: 'Real-time community chat',
              ),
            ],
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;

              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 156,
                ),
                children: const [
                  _SignalCard(
                    number: '24/7',
                    title: 'Always available',
                    subtitle: 'Fast local auth and chat sync for everyday use.',
                  ),
                  _SignalCard(
                    number: '5',
                    title: 'Core spaces',
                    subtitle: 'Feed, movies, market, work & stay, and chat.',
                  ),
                  _SignalCard(
                    number: 'US',
                    title: 'Community-first',
                    subtitle:
                        'Made for Vietnamese beauty workers across America.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.mode,
    required this.showLogo,
    required this.serviceReady,
    required this.submitting,
    required this.error,
    required this.onRetry,
    required this.onModeChanged,
    required this.onFlipMode,
    required this.child,
  });

  final _AuthMode mode;
  final bool showLogo;
  final bool serviceReady;
  final bool submitting;
  final String? error;
  final Future<void> Function() onRetry;
  final ValueChanged<_AuthMode> onModeChanged;
  final VoidCallback onFlipMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLogin = mode == _AuthMode.login;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _authLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLogo) ...[
            const Center(child: AppLogo(size: 66)),
            const SizedBox(height: 24),
          ],
          Text(
            isLogin ? 'Sign in' : 'Create your account',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: _authInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isLogin
                ? 'Use your username and password to enter the ${AppConstants.appName} community.'
                : 'Set up your ${AppConstants.appName} profile once and start posting jobs, rooms, marketplace items, and chat updates.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: _authMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          _ServiceBanner(
            ready: serviceReady,
            busy: submitting,
            onRetry: onRetry,
          ),
          const SizedBox(height: 18),
          SegmentedButton<_AuthMode>(
            segments: const [
              ButtonSegment<_AuthMode>(
                value: _AuthMode.login,
                icon: Icon(Icons.login_rounded),
                label: Text('Sign in'),
              ),
              ButtonSegment<_AuthMode>(
                value: _AuthMode.register,
                icon: Icon(Icons.person_add_alt_1_rounded),
                label: Text('Register'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
          const SizedBox(height: 22),
          child,
          if (error != null && error!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: error!),
          ],
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: submitting ? null : onFlipMode,
              child: Text(
                isLogin
                    ? 'Need an account? Create one here'
                    : 'Already have an account? Sign in',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'By continuing you agree to local community rules and respectful communication.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _authMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.obscure,
    required this.submitting,
    required this.ready,
    required this.onTogglePassword,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscure;
  final bool submitting;
  final bool ready;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _AuthInput(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            label: 'Username',
            hint: 'Enter your username',
            icon: Icons.person_outline_rounded,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter a username'
                : null,
          ),
          const SizedBox(height: 14),
          _AuthInput(
            controller: passwordController,
            obscureText: obscure,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            onFieldSubmitted: (_) => onSubmit(),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Enter your password' : null,
            suffix: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _authBlueSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Your account opens feed, movies, room share, marketplace, and chat in one sign-in.',
                style: TextStyle(
                  color: _authInk,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting || !ready ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(submitting ? 'Signing in...' : 'Enter Nail Talk'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.nameController,
    required this.usernameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.submitting,
    required this.ready,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool submitting;
  final bool ready;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _AuthInput(
            controller: nameController,
            textInputAction: TextInputAction.next,
            label: 'Full name',
            hint: 'Enter your full name',
            icon: Icons.badge_outlined,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter your full name'
                : null,
          ),
          const SizedBox(height: 14),
          _AuthInput(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            label: 'Username',
            hint: 'Choose a username',
            icon: Icons.alternate_email_rounded,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Choose a username'
                : null,
          ),
          const SizedBox(height: 14),
          _AuthInput(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            label: 'Email',
            hint: 'name@example.com',
            icon: Icons.mail_outline_rounded,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return 'Enter your email';
              }
              if (!trimmed.contains('@')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _AuthInput(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            label: 'Phone number',
            hint: 'Optional',
            icon: Icons.call_outlined,
          ),
          const SizedBox(height: 14),
          _AuthInput(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            label: 'Password',
            hint: 'Use at least 6 characters',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter your password';
              }
              if (value.length < 6) {
                return 'Use at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _AuthInput(
            controller: confirmPasswordController,
            obscureText: obscureConfirm,
            label: 'Confirm password',
            hint: 'Repeat your password',
            icon: Icons.verified_user_outlined,
            onFieldSubmitted: (_) => onSubmit(),
            suffix: IconButton(
              onPressed: onToggleConfirm,
              icon: Icon(
                obscureConfirm
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm your password';
              }
              if (value != passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _authMintSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'You can update jobs, room posts, marketplace items, and your profile after account creation.',
                style: TextStyle(
                  color: _authInk,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting || !ready ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                submitting ? 'Creating account...' : 'Create account',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthInput extends StatelessWidget {
  const _AuthInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
      validator: validator,
    );
  }
}

class _ServiceBanner extends StatelessWidget {
  const _ServiceBanner({
    required this.ready,
    required this.busy,
    required this.onRetry,
  });

  final bool ready;
  final bool busy;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (ready) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _authMintSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCFECDD)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF169467)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Local service is ready. You can sign in or create an account now.',
                style: TextStyle(
                  color: _authInk,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _authCoralSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF4CFD7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFC94960)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'The local service is not ready yet. Retry the connection before signing in.',
              style: TextStyle(
                color: _authInk,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: busy ? null : onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _authCoralSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1C8D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFD0475F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _authInk,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
