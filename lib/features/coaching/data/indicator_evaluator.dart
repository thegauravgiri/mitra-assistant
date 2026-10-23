import '../../../core/constants/app_constants.dart';
import '../domain/models/speaker_metrics.dart';
import 'progress_service.dart';
import 'session_metrics.dart';

enum IndicatorStatus { good, ok, watch, unknown }

enum IndicatorGroup { delivery, listening }

class Indicator {
  final String id;
  final String label;
  final IndicatorGroup group;
  final double? value;
  final String display; // e.g. "142 wpm"
  final String rangeText; // e.g. "120-170 is typical"
  final IndicatorStatus status;

  const Indicator({
    required this.id,
    required this.label,
    required this.group,
    required this.value,
    required this.display,
    required this.rangeText,
    required this.status,
  });
}

/// Turns raw [SpeakerMetrics] into labelled indicators with a status.
/// Thresholds are heuristics from [AppConstants], shown to the user as such.
class IndicatorEvaluator {
  static const ids = [
    'pace',
    'fillers',
    'monologue',
    'talkShare',
    'interruptions',
    'questions',
    'responseGap',
  ];

  static const labels = {
    'pace': 'Speaking pace (wpm)',
    'fillers': 'Filler words (/min)',
    'monologue': 'Longest stretch (s)',
    'talkShare': 'Talk share (%)',
    'interruptions': 'Interrupted others',
    'questions': 'Questions asked',
    'responseGap': 'Time to respond (s)',
  };

  /// Raw value used for status, goals, baselines and sparklines.
  static double? valueOf(String id, SpeakerMetrics m, int speakerCount) {
    switch (id) {
      case 'pace':
        return m.paceWpm;
      case 'fillers':
        return m.fillersPerMin;
      case 'monologue':
        return m.longestMonologueSec;
      case 'talkShare':
        // signed distance from the fair share, in percentage points
        return speakerCount < 2 ? null : m.talkSharePct - 100 / speakerCount;
      case 'interruptions':
        return m.interruptionsMade.toDouble();
      case 'questions':
        return m.wordCount < 30 ? null : m.questionsAsked.toDouble();
      case 'responseGap':
        return m.avgResponseGapSec;
    }
    return null;
  }

  static List<Indicator> evaluate(SpeakerMetrics m, {required int speakerCount}) {
    IndicatorStatus band(double? v, double good, double ok, {bool lowerIsBetter = true}) {
      if (v == null) return IndicatorStatus.unknown;
      if (lowerIsBetter) {
        return v <= good ? IndicatorStatus.good : (v <= ok ? IndicatorStatus.ok : IndicatorStatus.watch);
      }
      return v >= good ? IndicatorStatus.good : (v >= ok ? IndicatorStatus.ok : IndicatorStatus.watch);
    }

    final pace = valueOf('pace', m, speakerCount);
    final fillers = valueOf('fillers', m, speakerCount);
    final mono = valueOf('monologue', m, speakerCount);
    final share = valueOf('talkShare', m, speakerCount);
    final interr = valueOf('interruptions', m, speakerCount);
    final q = valueOf('questions', m, speakerCount);
    final gap = valueOf('responseGap', m, speakerCount);
    final fair = speakerCount < 2 ? 100.0 : 100 / speakerCount;

    String f0(double? v, String unit) => v == null ? 'n/a' : '${v.toStringAsFixed(0)}$unit';
    String f1(double? v, String unit) => v == null ? 'n/a' : '${v.toStringAsFixed(1)}$unit';

    return [
      Indicator(
        id: 'pace',
        label: 'Speaking pace',
        group: IndicatorGroup.delivery,
        value: pace,
        display: f0(pace, ' wpm'),
        rangeText:
            '${AppConstants.paceGoodMinWpm.toStringAsFixed(0)}-${AppConstants.paceGoodMaxWpm.toStringAsFixed(0)} wpm is typical',
        status: pace == null
            ? IndicatorStatus.unknown
            : (pace >= AppConstants.paceGoodMinWpm && pace <= AppConstants.paceGoodMaxWpm
                ? IndicatorStatus.good
                : (pace >= AppConstants.paceOkMinWpm && pace <= AppConstants.paceOkMaxWpm
                    ? IndicatorStatus.ok
                    : IndicatorStatus.watch)),
      ),
      Indicator(
        id: 'fillers',
        label: 'Filler words',
        group: IndicatorGroup.delivery,
        value: fillers,
        display: f1(fillers, ' /min'),
        rangeText: 'under ${AppConstants.fillersGoodPerMin.toStringAsFixed(0)} per minute',
        status: band(fillers, AppConstants.fillersGoodPerMin, AppConstants.fillersOkPerMin),
      ),
      Indicator(
        id: 'monologue',
        label: 'Longest stretch',
        group: IndicatorGroup.delivery,
        value: mono,
        display: f0(mono, ' s'),
        rangeText: 'under ${AppConstants.monologueGoodSec.toStringAsFixed(0)} s keeps others in',
        status: band(mono, AppConstants.monologueGoodSec, AppConstants.monologueOkSec),
      ),
      Indicator(
        id: 'talkShare',
        label: 'Talk share',
        group: IndicatorGroup.listening,
        value: share == null ? null : m.talkSharePct,
        display: f0(m.talkSharePct, '%'),
        rangeText: 'fair share is ${fair.toStringAsFixed(0)}% with $speakerCount speakers',
        status: share == null
            ? IndicatorStatus.unknown
            : band(share.abs(), AppConstants.talkShareGoodBandPts, AppConstants.talkShareOkBandPts),
      ),
      Indicator(
        id: 'interruptions',
        label: 'Interrupted others',
        group: IndicatorGroup.listening,
        value: interr,
        display: '${m.interruptionsMade}x',
        rangeText: 'estimate; ${AppConstants.interruptionsGood} or fewer is good',
        status: band(interr, AppConstants.interruptionsGood.toDouble(), AppConstants.interruptionsOk.toDouble()),
      ),
      Indicator(
        id: 'questions',
        label: 'Questions asked',
        group: IndicatorGroup.listening,
        value: q,
        display: q == null ? 'n/a' : '${m.questionsAsked}',
        rangeText: 'questions invite others in',
        status: q == null
            ? IndicatorStatus.unknown
            : (q >= 2 ? IndicatorStatus.good : (q >= 1 ? IndicatorStatus.ok : IndicatorStatus.watch)),
      ),
      Indicator(
        id: 'responseGap',
        label: 'Time to respond',
        group: IndicatorGroup.listening,
        value: gap,
        display: f1(gap, ' s'),
        rangeText: 'under ${AppConstants.responseGapGoodMaxSec} s feels responsive',
        status: band(gap, AppConstants.responseGapGoodMaxSec, AppConstants.responseGapOkMaxSec),
      ),
    ];
  }

  static int speakerCountOf(ProgressPoint p) {
    final n = metricsOf(p.session).length;
    return n == 0 ? 2 : n;
  }

  /// Average of the last [n] values before the current meeting (oldest-first
  /// [prior] points). Null when there is no history with a value.
  static double? baseline(
    String id,
    List<ProgressPoint> prior, {
    int n = AppConstants.baselineMeetings,
  }) {
    final values = <double>[];
    for (final p in prior.reversed) {
      final v = valueOf(id, p.metrics, speakerCountOf(p));
      if (v != null) values.add(v);
      if (values.length == n) break;
    }
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Oldest-first values for a sparkline.
  static List<double?> series(String id, List<ProgressPoint> points) => [
        for (final p in points) valueOf(id, p.metrics, speakerCountOf(p)),
      ];
}
