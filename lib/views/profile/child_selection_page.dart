import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/child_profile.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/child_action_bar.dart';
import '../../widgets/child_avatar.dart';
import '../../services/audio/app_sounds.dart';
import '../../services/audio/sound_controller.dart';
import '../../widgets/play/play.dart';
import '../../widgets/parent_area_button.dart';

/// The screen a signed-in parent lands on: nothing but the learners' faces and
/// names, so the child can start on their own. Everything a parent needs sits
/// behind the one small door in the corner.
class ChildSelectionPage extends StatefulWidget {
  const ChildSelectionPage({super.key});

  @override
  State<ChildSelectionPage> createState() => _ChildSelectionPageState();
}

class _ChildSelectionPageState extends State<ChildSelectionPage> {
  String? _loadedParentId;

  @override
  void initState() {
    super.initState();
    AppSound.instance.playMusic(MusicTrack.home);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ProfileViewModel>().loadProfiles(parent.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final profileVm = context.watch<ProfileViewModel>();

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      bottomNavigationBar: ChildActionBar(
        actions: [ParentAreaButton(onPressed: () => _openParentArea(context))],
      ),
      body: PlayGround(
        color: PlayColors.grape,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _SelectionHero(),
            const SizedBox(height: 22),
            if (profileVm.isLoading && profileVm.profiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (profileVm.profiles.isEmpty)
              _NoLearnersYet(onAddLearner: () => _openAddLearner(context))
            else ...[
              _LearnerGrid(
                profiles: profileVm.profiles,
                canAdd: profileVm.canCreateProfile,
                onSelect: (profile) => _startLearning(context, profile),
                onAddLearner: () => _openAddLearner(context),
              ),
              if (!profileVm.canCreateProfile) ...[
                const SizedBox(height: 14),
                const PlayNote(
                  'This account holds up to 3 learners. Remove one in the '
                  'parent area to make room.',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startLearning(
    BuildContext context,
    ChildProfile profile,
  ) async {
    context.read<ActiveChildSession>().selectProfile(profile);
    await context.read<LearningViewModel>().loadForProfile(profile);
    if (!context.mounted) return;

    // Pushed rather than replaced: the back gesture lands the child right back
    // on the faces instead of dropping them out of the app.
    Navigator.of(context).pushNamed(RouteNames.childHome);
  }

  /// The parent area is a door out of the child's part of the app, so it opens
  /// through the same check that already guards profile edits and reports.
  void _openParentArea(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.parentDashboard,
      ),
    );
  }

  void _openAddLearner(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.profileEdit,
        successArguments: ProfileEditArgs(
          returnRoute: RouteNames.childSelection,
        ),
      ),
    );
  }
}

class _SelectionHero extends StatelessWidget {
  const _SelectionHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.22),
            offset: const Offset(0, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/koala/koala_guide_portrait.png',
            height: 72,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          const Text(
            'Who is learning today?',
            style: TextStyle(
              fontFamily: 'Fredoka',
              color: PlayColors.ink,
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap your picture to start.',
            style: TextStyle(
              color: PlayColors.grape,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnerGrid extends StatelessWidget {
  const _LearnerGrid({
    required this.profiles,
    required this.canAdd,
    required this.onSelect,
    required this.onAddLearner,
  });

  final List<ChildProfile> profiles;

  /// False once the account holds its three learners.
  final bool canAdd;

  final ValueChanged<ChildProfile> onSelect;
  final VoidCallback onAddLearner;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 500
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: profiles.length + (canAdd ? 1 : 0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            // The way to add a second learner used to exist only when there
            // were none at all. After that the only route was the parent
            // area, behind two separate parental checks, which is why adding
            // a child looked impossible.
            if (index == profiles.length) {
              return _AddLearnerCard(onTap: onAddLearner);
            }

            final profile = profiles[index];
            return _LearnerCard(
              profile: profile,
              onTap: () => onSelect(profile),
            );
          },
        );
      },
    );
  }
}

class _LearnerCard extends StatelessWidget {
  const _LearnerCard({required this.profile, required this.onTap});

  final ChildProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Each child gets their own bright colour, so a two-year-old picks their
    // tile by colour long before they can read their own name.
    final tint = PlayColors.byIndex(profile.id.hashCode);

    return Squishy(
      semanticLabel: 'Start learning as ${profile.name}',
      onTap: onTap,
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: PlayColors.ink.withValues(alpha: 0.22),
                  offset: const Offset(0, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    child: ChildAvatar(
                      name: profile.name,
                      avatarValue: profile.avatarAsset,
                      radius: 52,
                      borderColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoLearnersYet extends StatelessWidget {
  const _NoLearnersYet({required this.onAddLearner});

  final VoidCallback onAddLearner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          const Icon(Icons.child_care_rounded, size: 38, color: AppColors.plum),
          const SizedBox(height: 10),
          Text(
            'No learners yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask a grown-up to add a child profile.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddLearner,
            icon: const Icon(Icons.add_reaction_rounded),
            label: const Text('Add a learner'),
          ),
        ],
      ),
    );
  }
}

/// The last tile in the grid: one more learner.
///
/// Deliberately quieter than a learner's own tile — an outline rather than a
/// solid colour — so a child scanning for their own face is not drawn to it.
/// It still opens the parental check, so a two-year-old who taps it lands on a
/// sum rather than on a form.
class _AddLearnerCard extends StatelessWidget {
  const _AddLearnerCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Squishy(
      semanticLabel: 'Add a learner',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.75),
            width: 4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Icon(Icons.add_rounded, size: 44,
                  color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add a learner',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                color: Colors.white,
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
