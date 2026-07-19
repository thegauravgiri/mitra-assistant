class PromptTemplates {
  static const String systemPrompt = '''
You are an expert real-time meeting co-pilot assistant ("Mitra Assistant").
Your goal is to analyze the ongoing live meeting transcript between the user, their clients, or team members, and provide actionable, highly relevant context, smart talking points, and key details so the user can speak with authority, clarity, and depth.

Given the recent transcript, output a valid JSON array of insights. Each insight MUST follow this exact JSON structure:
[
  {
    "category": "suggestion" | "keyPoint" | "question" | "actionItem",
    "title": "Short catchy title (3-6 words)",
    "description": "Concise, highly actionable bullet point or insight (1-2 sentences max)"
  }
]

Categories:
- "suggestion": High-value talking point, technical detail, or advice for what the user should mention right now.
- "keyPoint": Important topic, client requirement, or consensus reached.
- "question": Smart follow-up question the user can ask to drive the conversation forward.
- "actionItem": Explicit task, commitment, or follow-up agreed upon.

Keep your response extremely concise and focused. Respond ONLY with the JSON array.
''';

  static String buildAnalysisPrompt(
    String recentTranscript, {
    List<String> existingInsights = const [],
    String documentContext = '',
  }) {
    final docBlock = documentContext.trim().isEmpty
        ? ''
        : '''

Reference Documents:
---
$documentContext
---
''';

    final existingBlock = existingInsights.isEmpty
        ? ''
        : '''

Already Suggested Insights (DO NOT REPEAT, REPHRASE, OR PARAPHRASE ANY OF THESE):
${existingInsights.map((e) => '- $e').join('\n')}
''';

    return '''
Live Meeting Transcript:
---
$recentTranscript
---
$docBlock$existingBlock
Analyze the recent conversation above (and any relevant reference documents provided) and generate 1-2 fresh contextual insights/talking points for the user.

STRICT DEDUPLICATION RULES:
1. ABSOLUTELY DO NOT repeat, rephrase, or output conceptually similar items to anything listed under "Already Suggested Insights".
2. Quality over quantity: If no genuinely NEW actionable topic, question, or follow-up is present in recent conversation, return an empty JSON array [].
3. Do NOT output generic filler advice. Only output fresh, high-value insights directly tied to new statements in the transcript or reference documents.
''';
  }

  static String buildQuestionPrompt(
    String recentTranscript,
    String userQuestion, {
    String documentContext = '',
  }) {
    final docBlock = documentContext.trim().isEmpty
        ? ''
        : '''

Reference Documents:
---
$documentContext
---
''';

    return '''
Live Meeting Context/Transcript:
---
${recentTranscript.isEmpty ? "(No meeting transcript captured yet)" : recentTranscript}
---
$docBlock
User's Direct Question to AI Copilot:
"$userQuestion"

Answer the user's question directly with actionable insight tailored to the meeting context and reference documents.
Output a valid JSON array of insights with 1-2 items matching the exact JSON structure.
''';
  }

  static String buildDocumentSummaryPrompt(String documentText) {
    return '''
Provide a concise 2-3 sentence plain text summary of the key topics, concepts, and scope of the following document:
---
$documentText
---
''';
  }
}
