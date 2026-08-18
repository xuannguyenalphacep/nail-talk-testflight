import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../controllers/social_hub_controller.dart';
import '../core/localization/app_localizer.dart';
import '../models/session_user.dart';
import '../widgets/metro_ui.dart';
import '../widgets/remote_image.dart';

enum AccountHubSection { profile, faq, questions, terms, privacy }

class AccountHubScreen extends StatefulWidget {
  const AccountHubScreen({
    this.initialSection = AccountHubSection.profile,
    super.key,
  });

  final AccountHubSection initialSection;

  @override
  State<AccountHubScreen> createState() => _AccountHubScreenState();
}

class _AccountHubScreenState extends State<AccountHubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarController = TextEditingController();
  final _bioController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AccountHubSection _section;
  bool _uploadingAvatar = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<SessionController>().user;
    if (user != null && _nameController.text.isEmpty) {
      _hydrateUser(user);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _hydrateUser(SessionUser user) {
    _nameController.text = user.name;
    _emailController.text = _recoveryEmailForEditing(user.email);
    _phoneController.text = user.phone;
    _avatarController.text = user.avatarUrl;
    _bioController.text = user.bio;
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    final session = context.read<SessionController>();
    final social = context.read<SocialHubController>();

    try {
      await session.updateProfile(
        name: _nameController.text.trim(),
        email: _cleanOptional(_emailController.text),
        phone: _cleanOptional(_phoneController.text),
        bio: _cleanOptional(_bioController.text),
        avatarUrl: _cleanOptional(_avatarController.text),
      );
      if (!mounted) {
        return;
      }
      await social.refreshHome();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.tr('Profile updated.'))));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            session.error ?? context.tr('Could not update profile right now.'),
          ),
        ),
      );
    }
  }

  String? _cleanOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _recoveryEmailForEditing(String rawEmail) {
    final trimmed = rawEmail.trim();
    if (trimmed.isEmpty || _isLocalOnlyEmail(trimmed)) {
      return '';
    }
    return trimmed;
  }

  bool _isLocalOnlyEmail(String rawEmail) {
    return rawEmail.trim().toLowerCase().endsWith('.local');
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    final session = context.read<SessionController>();

    try {
      final message = await session.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.tr(message))));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            session.error ?? context.tr('Could not change password right now.'),
          ),
        ),
      );
    }
  }

  Future<void> _pickAvatarImage() async {
    if (_uploadingAvatar) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.image,
    );
    final file = result?.files.single;
    if (file == null || !mounted) return;

    setState(() => _uploadingAvatar = true);

    try {
      final uploadedUrl = await context.read<SessionController>().uploadImage(
        file,
      );
      if (!mounted) return;
      setState(() => _avatarController.text = uploadedUrl);
    } catch (_) {
      if (!mounted) return;
      final session = context.read<SessionController>();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            session.error ?? context.tr('Could not upload the selected image.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  void _clearAvatarImage() {
    setState(() => _avatarController.clear());
  }

  String _sectionTitle(BuildContext context) {
    switch (_section) {
      case AccountHubSection.profile:
        return context.tr('Edit profile');
      case AccountHubSection.faq:
        return context.tr('FAQ');
      case AccountHubSection.questions:
        return context.tr('Q&A');
      case AccountHubSection.terms:
        return context.tr('Terms & Conditions');
      case AccountHubSection.privacy:
        return context.tr('Privacy Policy');
    }
  }

  String _sectionSubtitle(BuildContext context) {
    switch (_section) {
      case AccountHubSection.profile:
        return context.tr(
          'Manage your profile, app help, and community policies.',
        );
      case AccountHubSection.faq:
        return context.tr(
          'Need quick help? Start here before posting, chatting, or buying.',
        );
      case AccountHubSection.questions:
        return context.tr(
          'Answers for common posting, account, and chat situations.',
        );
      case AccountHubSection.terms:
        return context.tr(
          'Please use respectful language, truthful listings, and only post services, housing, movies, and items that fit the community.',
        );
      case AccountHubSection.privacy:
        return context.tr(
          'Your account details are used to sign in, display your profile, and keep chat and listing activity tied to your account.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final bottomSpacing = MediaQuery.viewPaddingOf(context).bottom + 24;

    return Scaffold(
      appBar: AppBar(titleSpacing: 16, title: Text(context.tr('Account'))),
      body: MetroPageBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomSpacing),
          children: [
            _AccountHeroCard(
              user: user,
              title: _sectionTitle(context),
              subtitle: _sectionSubtitle(context),
            ),
            const SizedBox(height: 14),
            _AccountSectionPicker(
              selected: _section,
              onChanged: (section) => setState(() => _section = section),
            ),
            const SizedBox(height: 14),
            if (_section == AccountHubSection.profile)
              _ProfileEditorSection(
                formKey: _formKey,
                passwordFormKey: _passwordFormKey,
                session: session,
                nameController: _nameController,
                emailController: _emailController,
                phoneController: _phoneController,
                avatarUrl: _avatarController.text.trim(),
                bioController: _bioController,
                currentPasswordController: _currentPasswordController,
                newPasswordController: _newPasswordController,
                confirmPasswordController: _confirmPasswordController,
                uploadingAvatar: _uploadingAvatar,
                obscureCurrentPassword: _obscureCurrentPassword,
                obscureNewPassword: _obscureNewPassword,
                obscureConfirmPassword: _obscureConfirmPassword,
                onPickAvatar: _pickAvatarImage,
                onClearAvatar: _clearAvatarImage,
                onToggleCurrentPassword: () => setState(
                  () => _obscureCurrentPassword = !_obscureCurrentPassword,
                ),
                onToggleNewPassword: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
                onToggleConfirmPassword: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
                onSave: _saveProfile,
                onChangePassword: _changePassword,
                showRecoveryEmailHint:
                    user == null ||
                    _recoveryEmailForEditing(user.email).isEmpty,
                visibleRecoveryEmail: user == null
                    ? ''
                    : _recoveryEmailForEditing(user.email),
              )
            else if (_section == AccountHubSection.faq)
              const _InfoSection(
                items: [
                  (
                    'How do I post a job quickly?',
                    'Open the Work tab, choose hiring or job seeker mode, fill in the basics, and publish.',
                  ),
                  (
                    'How do I contact a seller or recruiter?',
                    'Tap the contact or chat button on any listing and Nails Talk will open a direct chat room.',
                  ),
                  (
                    'Why can some movies require a plan?',
                    'Some titles are free while premium shelves unlock after an active movie plan is purchased.',
                  ),
                  (
                    'How do I join a group chat?',
                    'Admin-created groups appear in the Chat tab. Tap a group to join and start reading or sending messages.',
                  ),
                  (
                    'Can I switch language later?',
                    'Yes. Use the language button in the app header to switch between Vietnamese and English.',
                  ),
                ],
              )
            else if (_section == AccountHubSection.questions)
              const _InfoSection(
                items: [
                  (
                    'What if my listing does not appear right away?',
                    'Pull to refresh first. If it is still missing, check whether the post was saved as draft or is waiting for approval.',
                  ),
                  (
                    'What should I put in my profile?',
                    'Use a clear name, optional phone, short bio, and a clean avatar so salons and community members can recognize you faster.',
                  ),
                  (
                    'What if chat with another member does not open?',
                    'Make sure the listing has a valid owner account. If the room already exists but is hidden, Nails Talk will restore it automatically.',
                  ),
                ],
              )
            else if (_section == AccountHubSection.terms)
              const _InfoSection(
                items: [
                  (
                    'Community Terms',
                    'Please use respectful language, truthful listings, and only post services, housing, movies, and items that fit the community.',
                  ),
                  (
                    'Account safety',
                    'Do not post scams, duplicate listings, harassment, or illegal content. Admin can remove content or disable accounts that break these rules.',
                  ),
                ],
              )
            else
              const _InfoSection(
                items: [
                  (
                    'Privacy & data',
                    'Your account details are used to sign in, display your profile, and keep chat and listing activity tied to your account.',
                  ),
                  (
                    'Shared content visibility',
                    'If you share a phone number, address, or media in posts or chat, other members may see that content based on where you post it.',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountHeroCard extends StatelessWidget {
  const _AccountHeroCard({
    required this.user,
    required this.title,
    required this.subtitle,
  });

  final SessionUser? user;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return MetroInsetPanel(
      borderColor: kMetroPrimary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccountAvatar(user: user, size: 62),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name.trim().isNotEmpty == true
                      ? user!.name
                      : context.tr('Guest'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: kMetroInk,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user?.username.isNotEmpty == true ? user!.username : 'member'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kMetroPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(title),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(subtitle),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditorSection extends StatelessWidget {
  const _ProfileEditorSection({
    required this.formKey,
    required this.passwordFormKey,
    required this.session,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.avatarUrl,
    required this.bioController,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.uploadingAvatar,
    required this.obscureCurrentPassword,
    required this.obscureNewPassword,
    required this.obscureConfirmPassword,
    required this.onPickAvatar,
    required this.onClearAvatar,
    required this.onToggleCurrentPassword,
    required this.onToggleNewPassword,
    required this.onToggleConfirmPassword,
    required this.onSave,
    required this.onChangePassword,
    required this.showRecoveryEmailHint,
    required this.visibleRecoveryEmail,
  });

  final GlobalKey<FormState> formKey;
  final GlobalKey<FormState> passwordFormKey;
  final SessionController session;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String avatarUrl;
  final TextEditingController bioController;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool uploadingAvatar;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final Future<void> Function() onPickAvatar;
  final VoidCallback onClearAvatar;
  final VoidCallback onToggleCurrentPassword;
  final VoidCallback onToggleNewPassword;
  final VoidCallback onToggleConfirmPassword;
  final Future<void> Function() onSave;
  final Future<void> Function() onChangePassword;
  final bool showRecoveryEmailHint;
  final String visibleRecoveryEmail;

  @override
  Widget build(BuildContext context) {
    final user = session.user;

    return Column(
      children: [
        MetroInsetPanel(
          borderColor: kMetroPrimary,
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Edit profile'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                ),
                if (showRecoveryEmailHint) ...[
                  const SizedBox(height: 12),
                  _ProfileHintCard(
                    icon: Icons.mark_email_unread_outlined,
                    message:
                        'Add a recovery email so you can reset your password later.',
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Display name'),
                    hintText: context.tr('Enter your full name'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('Enter your full name');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Recovery email'),
                    hintText: 'name@example.com',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isNotEmpty && !trimmed.contains('@')) {
                      return context.tr('Enter a valid email address');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Phone number'),
                    hintText: context.tr('Optional'),
                  ),
                ),
                const SizedBox(height: 12),
                _ProfileAvatarField(
                  imageUrl: avatarUrl,
                  displayName: nameController.text.trim(),
                  username: user?.username ?? '',
                  uploading: uploadingAvatar,
                  onPick: onPickAvatar,
                  onClear: onClearAvatar,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: bioController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: context.tr('Short bio'),
                    hintText: context.tr(
                      'Tell members what kind of nail work, services, or local interests you want to share.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: session.submitting ? null : onSave,
                        child: Text(
                          context.tr(
                            session.submitting ? 'Saving...' : 'Save changes',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        MetroInsetPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Account details'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: kMetroInk),
              ),
              const SizedBox(height: 12),
              _ReadOnlyField(label: 'Username', value: user?.username ?? ''),
              const SizedBox(height: 10),
              _ReadOnlyField(
                label: 'Email',
                value: visibleRecoveryEmail.isEmpty
                    ? context.tr('Not added yet')
                    : visibleRecoveryEmail,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetroInsetPanel(
          borderColor: kMetroPrimary.withValues(alpha: 0.26),
          child: Form(
            key: passwordFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Change password'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Use your current password once, then set a new one for future sign-ins.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrentPassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Current password'),
                    suffixIcon: IconButton(
                      onPressed: onToggleCurrentPassword,
                      icon: Icon(
                        obscureCurrentPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Enter your current password');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('New password'),
                    hintText: context.tr('Use at least 6 characters'),
                    suffixIcon: IconButton(
                      onPressed: onToggleNewPassword,
                      icon: Icon(
                        obscureNewPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Enter your new password');
                    }
                    if (value.length < 6) {
                      return context.tr('Use at least 6 characters');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: context.tr('Confirm new password'),
                    suffixIcon: IconButton(
                      onPressed: onToggleConfirmPassword,
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Confirm your password');
                    }
                    if (value != newPasswordController.text) {
                      return context.tr('Passwords do not match');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: session.submitting ? null : onChangePassword,
                    child: Text(
                      context.tr(
                        session.submitting
                            ? 'Updating password...'
                            : 'Update password',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHintCard extends StatelessWidget {
  const _ProfileHintCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMetroCoralSoft,
        borderRadius: BorderRadius.circular(kMetroRadius),
        border: Border.all(color: kMetroLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kMetroCoral),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(message),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: kMetroInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: kMetroMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: kMetroPrimarySoft,
            borderRadius: BorderRadius.circular(kMetroRadius),
            border: Border.all(color: kMetroLine),
          ),
          child: Text(
            value.isEmpty ? '...' : value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: kMetroInk),
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MetroInsetPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(item.$1),
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: kMetroInk),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(item.$2),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: kMetroMuted),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AccountSectionPicker extends StatelessWidget {
  const _AccountSectionPicker({
    required this.selected,
    required this.onChanged,
  });

  final AccountHubSection selected;
  final ValueChanged<AccountHubSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (AccountHubSection.profile, Icons.person_outline_rounded, 'Edit profile'),
      (AccountHubSection.faq, Icons.help_outline_rounded, 'FAQ'),
      (AccountHubSection.questions, Icons.forum_outlined, 'Q&A'),
      (AccountHubSection.terms, Icons.gavel_rounded, 'Terms & Conditions'),
      (AccountHubSection.privacy, Icons.privacy_tip_outlined, 'Privacy Policy'),
    ];

    return MetroInsetPanel(
      padding: const EdgeInsets.all(12),
      borderColor: kMetroPrimary.withValues(alpha: 0.2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items
                .map(
                  (item) => SizedBox(
                    width: itemWidth,
                    child: _AccountSectionButton(
                      label: item.$3,
                      icon: item.$2,
                      selected: selected == item.$1,
                      onTap: () => onChanged(item.$1),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _AccountSectionButton extends StatelessWidget {
  const _AccountSectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMetroRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? null : kMetroSurface,
            gradient: selected
                ? const LinearGradient(
                    colors: [kMetroPrimary, Color(0xFF334894)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(kMetroRadius),
            border: Border.all(
              color: selected ? kMetroCoral : kMetroLine,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kMetroPrimary.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: kMetroCoral.withValues(alpha: 0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : kMetroPrimarySoft,
                  borderRadius: BorderRadius.circular(kMetroRadius),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : kMetroLine,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? const Color(0xFFFFE2CE) : kMetroPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? Colors.white : kMetroInk,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.user, required this.size});

  final SessionUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl.trim() ?? '';
    final initialSource = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : user?.username.trim() ?? '';
    final initial = initialSource.isEmpty ? 'N' : initialSource[0];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kMetroPrimarySoft,
        borderRadius: BorderRadius.circular(kMetroRadius),
        border: Border.all(color: kMetroLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isEmpty
          ? Center(
              child: Text(
                initial.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: kMetroPrimary),
              ),
            )
          : RemoteImage(
              url: avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorFallback: Center(
                child: Text(
                  initial.toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: kMetroPrimary),
                ),
              ),
            ),
    );
  }
}

class _ProfileAvatarField extends StatelessWidget {
  const _ProfileAvatarField({
    required this.imageUrl,
    required this.displayName,
    required this.username,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  final String imageUrl;
  final String displayName;
  final String username;
  final bool uploading;
  final Future<void> Function() onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final initialSource = displayName.isNotEmpty ? displayName : username;
    final initial = initialSource.isEmpty ? 'N' : initialSource[0];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kMetroSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kMetroLine),
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: kMetroPrimarySoft,
              shape: BoxShape.circle,
              border: Border.all(color: kMetroLine),
            ),
            clipBehavior: Clip.antiAlias,
            child: uploading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                : imageUrl.isEmpty
                ? Center(
                    child: Text(
                      initial.toUpperCase(),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: kMetroPrimary),
                    ),
                  )
                : RemoteImage(
                    url: imageUrl,
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                    errorFallback: Center(
                      child: Text(
                        initial.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: kMetroPrimary),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Avatar photo'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: kMetroInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Choose avatar photo from your device instead of pasting a link.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: kMetroMuted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: uploading ? null : () => onPick(),
                      icon: Icon(
                        uploading
                            ? Icons.sync_rounded
                            : Icons.add_a_photo_outlined,
                      ),
                      label: Text(
                        context.tr(
                          imageUrl.isEmpty
                              ? 'Choose from device'
                              : 'Change avatar',
                        ),
                      ),
                    ),
                    if (imageUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: uploading ? null : onClear,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(context.tr('Remove avatar')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
