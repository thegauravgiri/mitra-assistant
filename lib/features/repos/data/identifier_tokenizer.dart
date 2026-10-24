/// Turns code, paths and plain English into comparable lowercase word stems.
///
/// "PaymentRetryPolicy", "payment_retry_policy" and "payment retry policy" all
/// become [payment, retri, polici]; "retries" and "retry" meet at the same stem.
/// This is what lets a client's plain-English question match descriptive code
/// names without any AI call at question time.
class IdentifierTokenizer {
  static const Set<String> _stop = {
    'the', 'an', 'and', 'or', 'of', 'to', 'in', 'is', 'it', 'for', 'on', 'with', 'as', 'by', 'this', 'that',
    'from', 'be', 'are', 'was', 'were', 'if', 'else', 'then', 'at', 'we', 'you', 'your', 'our', 'can', 'do',
    'does', 'did', 'what', 'how', 'when', 'where', 'which', 'who', 'will', 'would', 'should', 'could', 'has',
    'have', 'had', 'not', 'but', 'so', 'about', 'there', 'their', 'they', 'them', 'its', 'also', 'just',
    // very common code noise
    'var', 'final', 'const', 'new', 'null', 'true', 'false', 'void', 'int', 'return', 'import', 'package',
    'public', 'private', 'static', 'async', 'await', 'self', 'let', 'def', 'func', 'fn', 'get', 'set',
  };

  static final RegExp _lowerUpper = RegExp(r'([a-z0-9])([A-Z])');
  static final RegExp _acronym = RegExp(r'([A-Z]+)([A-Z][a-z])');
  static final RegExp _nonWord = RegExp(r'[^A-Za-z0-9]+');

  /// Stemmed tokens, in order, duplicates kept (callers count them).
  static List<String> tokens(String text) {
    if (text.isEmpty) return const [];
    final spaced = text
        .replaceAllMapped(_acronym, (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(_lowerUpper, (m) => '${m[1]} ${m[2]}')
        .replaceAll(_nonWord, ' ')
        .toLowerCase();
    final out = <String>[];
    for (final w in spaced.split(' ')) {
      if (w.length < 2 || _stop.contains(w)) continue;
      final s = stem(w);
      if (s.length >= 2 && !_stop.contains(s)) out.add(s);
    }
    return out;
  }

  static Set<String> uniqueTokens(String text) => tokens(text).toSet();

  /// Deliberately light: enough to join "retries/retry/retrying/retried",
  /// "payments/payment", "failed/fails/fail", "handle/handling".
  static String stem(String w) {
    var s = w;
    if (s.length > 4 && s.endsWith('ies')) {
      s = '${s.substring(0, s.length - 3)}y';
    } else if (s.length > 4 && s.endsWith('ied')) {
      s = '${s.substring(0, s.length - 3)}y';
    } else if (s.length > 4 && s.endsWith('sses')) {
      s = s.substring(0, s.length - 2);
    } else if (s.length > 3 && s.endsWith('s') && !s.endsWith('ss') && !s.endsWith('us') && !s.endsWith('is')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.length > 5 && s.endsWith('ing')) {
      s = s.substring(0, s.length - 3);
    } else if (s.length > 4 && s.endsWith('ed')) {
      s = s.substring(0, s.length - 2);
    }
    // handle/handling/handled -> handl; retry stays retry
    if (s.length > 4 && s.endsWith('e')) s = s.substring(0, s.length - 1);
    // retry vs retri: normalise a trailing y/i
    if (s.length > 3 && s.endsWith('y')) s = '${s.substring(0, s.length - 1)}i';
    return s;
  }

  /// Words that mean nearly the same thing in plain speech and in code, so a
  /// client saying "ends a meeting" still finds code that says `stop`.
  static const List<List<String>> _synonymGroups = [
    ['end', 'stop', 'finish', 'terminate', 'close', 'complete'],
    ['start', 'begin', 'launch', 'open', 'init'],
    ['delete', 'remove', 'drop', 'clear', 'erase'],
    ['save', 'store', 'persist', 'write', 'cache'],
    ['fail', 'error', 'exception', 'crash', 'broken'],
    ['retry', 'attempt', 'again'],
    ['send', 'post', 'submit', 'push', 'upload'],
    ['login', 'signin', 'authenticate', 'auth', 'session', 'credential'],
    ['pay', 'payment', 'charge', 'bill', 'invoice', 'checkout'],
    ['refund', 'reimburse', 'chargeback'],
    ['user', 'customer', 'account', 'member', 'person'],
    ['limit', 'quota', 'cap', 'maximum', 'throttle'],
    ['notify', 'alert', 'email', 'message', 'notification'],
    ['permission', 'access', 'role', 'authorize', 'allow'],
    ['config', 'setting', 'option', 'preference'],
    ['speed', 'fast', 'performance', 'latency', 'slow'],
    ['secure', 'security', 'encrypt', 'privacy', 'protect'],
    ['connect', 'link', 'integrate', 'sync', 'hook'],
    ['show', 'display', 'render', 'view'],
    ['hide', 'conceal', 'mask', 'invisible'],
  ];

  static final Map<String, Set<String>> _synonyms = () {
    final map = <String, Set<String>>{};
    for (final group in _synonymGroups) {
      final stems = {for (final w in group) stem(w)};
      for (final s in stems) {
        (map[s] ??= {}).addAll(stems.where((o) => o != s));
      }
    }
    return map;
  }();

  /// Stems that mean about the same as [stemmed], or an empty set.
  static Set<String> synonymsOf(String stemmed) => _synonyms[stemmed] ?? const {};
}
