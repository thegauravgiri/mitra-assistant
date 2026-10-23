import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text_similarity.dart';
import '../../history/domain/models/meeting_session.dart';
import 'section_card.dart';

/// The part of the meeting notes that is about YOU: action items you own and
/// questions you asked that nobody answered. The full notes live in History.
class FollowUpsCard extends StatelessWidget {
  final MeetingSession session;
  final String? meName;
  final VoidCallback? onOpenNotes;

  const FollowUpsCard({super.key, required this.session, required this.meName, this.onOpenNotes});

  bool _isMe(String? name) =>
      name != null && meName != null && TextSimilarity.normalize(name) == TextSimilarity.normalize(meName!);

  @override
  Widget build(BuildContext context) {
    final digest = session.digest;
    final actions = [
      for (final a in digest?.actionItems ?? const []) if (_isMe(a.owner)) a.task,
    ];
    final questions = [
      for (final q in digest?.openQuestions ?? const []) if (_isMe(q.asker)) q.question,
    ];

    Widget body;
    if (meName == null) {
      body = const Hint('Pick which speaker you are to see your follow-ups.');
    } else if (digest == null) {
      body = const Hint('Meeting notes have not been generated yet. Open this meeting in History to generate them.');
    } else if (actions.isEmpty && questions.isEmpty) {
      body = const Hint('Nothing in this meeting is assigned to you, and none of your questions went unanswered.');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (actions.isNotEmpty) ...[
            const _Label('Action items you own'),
            for (final a in actions) _Bullet(a),
          ],
          if (questions.isNotEmpty) ...[
            if (actions.isNotEmpty) const SizedBox(height: 10),
            const _Label('Your questions that went unanswered'),
            for (final q in questions) _Bullet(q),
          ],
        ],
      );
    }

    return SectionCard(
      icon: Icons.assignment_turned_in_rounded,
      title: 'Your follow-ups',
      trailing: onOpenNotes == null ? null : TextButton(onPressed: onOpenNotes, child: const Text('Full notes')),
      child: body,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
      );
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: AppTheme.primaryAccent)),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textPrimary))),
          ],
        ),
      );
}
