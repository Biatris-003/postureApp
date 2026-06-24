import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/datasources/auth_service_mock.dart';
import '../../data/datasources/exercise_data.dart';

final ragChatServiceProvider = Provider((ref) => RagChatService(ref));

class RagChatService {
  final Ref _ref;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── API Keys & Endpoints ─────────────────────────────────────────────
  String get _pineconeKey => dotenv.env['PINECONE_API_KEY'] ?? '';
  String get _groqKey => dotenv.env['GROQ_API_KEY'] ?? '';
  String get _pineconeHost => dotenv.env['PINECONE_INDEX_HOST'] ?? '';

  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // ── Conversation History (in-memory, per session) ────────────────────
  final List<Map<String, String>> _conversationHistory = [];

  RagChatService(this._ref);

  // ── MAIN ENTRY POINT ─────────────────────────────────────────────────
  Future<String> sendMessage(String userMessage) async {
    try {
      // Step 1: Get patient context from Firestore
      final context = await _getPatientContext();

      // Step 2: Search Pinecone for relevant book chunks
      final relevantKnowledge = await _searchPinecone(userMessage);

      // Step 3: Build and send prompt to Groq
      final answer = await _callGroq(
        userMessage: userMessage,
        patientContext: context,
        relevantKnowledge: relevantKnowledge,
      );

      // Step 4: Save to conversation history for memory
      _conversationHistory.add({'role': 'user', 'content': userMessage});
      _conversationHistory.add({'role': 'assistant', 'content': answer});

      // Keep only last 10 messages to avoid token overflow
      if (_conversationHistory.length > 10) {
        _conversationHistory.removeRange(0, 2);
      }

      return answer;
    } catch (e) {
      print('❌ RagChatService error: $e');
      return 'I apologize, I am having trouble connecting right now. Please try again in a moment.';
    }
  }


  // ── STEP 1: GET PATIENT CONTEXT FROM FIRESTORE ───────────────────────
  Future<String> _getPatientContext() async {
    try {
      final appUser = _ref.read(authStateProvider);
      if (appUser == null) return 'Patient context unavailable.';

      final userId = appUser.userId;

      // ── Get patient profile + resolve logical patientId ──────────────
      final patientQuery = await _db
          .collection('patients')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      String patientName = 'Patient';
      String patientId = userId; // fallback

      if (patientQuery.docs.isNotEmpty) {
        final patientDoc = patientQuery.docs.first;
        final patient = patientDoc.data();
        patientName = patient['fullName'] ?? 'Patient';

        // ✅ Use the logical patientId field, same as AnalyticsService does
        patientId = patient['patientId'] as String? ?? patientDoc.id;
      }

      // ── Look up today's statistics using the correct doc ID ──────────
      String mostProblematic = 'unknown';
      int postureScore = 0;
      int uprightMinutes = 0;

      final now = DateTime.now();
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // ✅ doc ID must be patientId_date (e.g. "p001_2026-06-24")
      final statsDoc = await _db
          .collection('statistics')
          .doc('${patientId}_$dateKey')
          .get();

      if (statsDoc.exists) {
        final stats = statsDoc.data()!;
        postureScore = (stats['postureScore'] as num?)?.toInt() ?? 0;
        mostProblematic = stats['mostProblematicPosture'] as String? ?? 'unknown';
        uprightMinutes = (stats['uprightMinutes'] as num?)?.toInt() ?? 0;

        print('✅ RAG context loaded: score=$postureScore, problematic=$mostProblematic');
      } else {
        print('⚠️ No stats doc found for ${patientId}_$dateKey');

        // ── Fallback: query statistics collection by patientId field ────
        final statsQuery = await _db
            .collection('statistics')
            .where('patientId', isEqualTo: patientId)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (statsQuery.docs.isNotEmpty) {
          final stats = statsQuery.docs.first.data();
          postureScore = (stats['postureScore'] as num?)?.toInt() ?? 0;
          mostProblematic = stats['mostProblematicPosture'] as String? ?? 'unknown';
          uprightMinutes = (stats['uprightMinutes'] as num?)?.toInt() ?? 0;
          print('✅ RAG context loaded from fallback query');
        }
      }

      // ── Build exercises list ─────────────────────────────────────────
      final exercises = ExerciseData.catalog
          .map((e) => '- ${e.title} (${e.reps}, ${e.sets})')
          .join('\n');

      return '''
  PATIENT PROFILE:
  - Name: $patientName
  - Today's Posture Score: $postureScore%
  - Most Problematic Posture: ${mostProblematic.replaceAll('_', ' ')}
  - Upright Time Today: $uprightMinutes minutes

  ASSIGNED EXERCISES:
  $exercises
  ''';
    } catch (e) {
      print('❌ Error getting patient context: $e');
      return 'Patient context temporarily unavailable.';
    }
  }

  // ── STEP 2: SEARCH PINECONE ──────────────────────────────────────────
  Future<String> _searchPinecone(String query) async {
    try {
      // First convert query to embedding using HuggingFace
      final embedding = await _getEmbedding(query);
      if (embedding.isEmpty) return '';

      // Search Pinecone
      final response = await http.post(
        Uri.parse('https://$_pineconeHost/query'),
        headers: {
          'Api-Key': _pineconeKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'vector': embedding,
          'topK': 4,
          'includeMetadata': true,
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Pinecone error: ${response.statusCode} ${response.body}');
        return '';
      }

      final data = jsonDecode(response.body);
      final matches = data['matches'] as List;

      if (matches.isEmpty) return '';

      // Extract text from top matches
      final chunks = matches
          .map((m) => m['metadata']['text'] as String)
          .where((text) => text.isNotEmpty)
          .take(4)
          .toList();

      return chunks.join('\n\n---\n\n');
    } catch (e) {
      print('❌ Pinecone search error: $e');
      return '';
    }
  }


  Future<List<double>> _getEmbedding(String text) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.pinecone.io/embed'),
        headers: {
          'Api-Key': _pineconeKey,
          'Content-Type': 'application/json',
          'X-Pinecone-API-Version': '2024-10',
        },
        body: jsonEncode({
          'model': 'multilingual-e5-large',
          'inputs': [
            {'text': text}
          ],
          'parameters': {
            'input_type': 'query',
            'truncate': 'END',
          },
        }),
      );

      print('📡 Embedding status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ Pinecone embed error: ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body);
      final values = data['data'][0]['values'] as List;
      print('✅ Embedding length: ${values.length}');
      return values.map((e) => (e as num).toDouble()).toList();

    } catch (e) {
      print('❌ Embedding error: $e');
      return [];
    }
  }


  // ── STEP 3: CALL GROQ ────────────────────────────────────────────────
  Future<String> _callGroq({
    required String userMessage,
    required String patientContext,
    required String relevantKnowledge,
  }) async {
    final systemPrompt = _buildSystemPrompt(patientContext, relevantKnowledge);

    // Build messages array with history
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ..._conversationHistory,
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(_groqUrl),
      headers: {
        'Authorization': 'Bearer $_groqKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': messages,
        'max_tokens': 500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      print('❌ Groq error: ${response.statusCode} ${response.body}');
      throw Exception('Groq API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  // ── SYSTEM PROMPT ────────────────────────────────────────────────────
  String _buildSystemPrompt(String patientContext, String relevantKnowledge) {
    return '''
You are Posture AI, a warm and supportive rehabilitation assistant for the Smart Posture app. 
Patients wear a spinal brace with 4 IMU sensors that monitor their posture throughout the day.

YOUR ROLE:
- Help patients understand and perform their assigned exercises correctly
- Give posture improvement tips based on their sensor data
- Guide them when they feel pain during exercise
- Provide nutrition advice for muscle recovery and health
- Identify dangerous symptoms that need immediate medical attention
- Suggest alternative exercises when needed
- Encourage and motivate patients in their rehabilitation journey

PATIENT CONTEXT (use this to personalize your answers):
$patientContext

EXERCISE SCENARIOS — use this to suggest correct alternatives:

SCENARIO 1 — FORWARD BENDING (tight chest/hip flexors, weak upper back):
Exercises: Chest Stretch, Thoracic Back Extension, Chin Tucks, Wall Angels, Circumduction, Neck Rotation
If patient can't do one → suggest another from THIS list only

SCENARIO 2 — SLOUCHING/KYPHOSIS (tight chest, weak back/core):
Exercises: Cat-Cow Stretch, Bird Dog, Dead Bug, Hip Flexor Stretch, Tummy Twist, Squatting, Seated Core Bracing, Back Extension Holds
If patient can't do one → suggest another from THIS list only
Cat-Cow alternatives: Bird Dog, Tummy Twist, Hip Flexor Stretch

SCENARIO 3 — BACKWARD BENDING/HYPERLORDOSIS (weak core, overextended lower back):
Exercises: Plank, Glute Bridge, Leg Lift, Hip Flexor Stretch, Abdominal Bracing, Posterior Pelvic Tilt
If patient can't do one → suggest another from THIS list only
Plank alternatives: Glute Bridge, Dead Bug (easier on lower back)

SCENARIO 4 — LEFT BENDING (weak right side, tight left side):
Exercises: Right Side Leg Raise, Side Bending Right, Left Side Plank, Single Leg Standing, Flamingo Stand, Flamingo Movement
If patient can't do one → suggest another from THIS list only

SCENARIO 5 — RIGHT BENDING (weak left side, tight right side):
Exercises: Left Side Leg Raise, Side Bending Left, Right Side Plank, Single Leg Standing (left leg)
If patient can't do one → suggest another from THIS list only

SCENARIO 6 — TOO MUCH UPRIGHT (stiffness from prolonged good posture):
Exercises: Micro-Break Walking, Neck Rotation, Sit to Stand, Squatting, Shoulder Rolls
If patient can't do one → suggest another from THIS list only

CRITICAL ALTERNATIVE RULE:
NEVER suggest an exercise from a different scenario as an alternative.
Cat-Cow (Scenario 2) → alternatives must come from Scenario 2 only
Plank (Scenario 3) → alternatives must come from Scenario 3 only

MEDICAL KNOWLEDGE (use this to ground your answers in evidence):
$relevantKnowledge

RESPONSE RULES:
1. Keep responses concise and friendly — 3 to 5 sentences maximum
2. Always use the patient's name if available, but greet patient once only at the start of the conversation
3. For exercise questions → reference their actual assigned exercises
4. For pain during exercise:
   - Electrical/sharp pain → stop immediately, rest, contact doctor
   - Muscle cramps → hydrate, gentle stretch, reduce intensity
   - Shaking/trembling → reduce reps, this is normal fatigue
5. For dangerous symptoms (numbness, chest pain, loss of bladder control, severe weakness) → always say "stop all activity and contact your doctor or emergency services immediately"
6. For alternative exercises → suggest from their assigned list or similar difficulty
7. For nutrition → focus on protein, hydration, anti-inflammatory foods
8. NEVER diagnose medical conditions
9. NEVER replace professional medical advice
10. If unsure → say "I recommend discussing this with your clinician"
11. Respond in the same language the patient uses (Arabic or English)

PERSONALITY:
- Warm, encouraging, like a supportive physiotherapy assistant
- Use simple everyday language, avoid medical jargon
- Always empathetic when patient reports pain or difficulty
''';
  }

  // ── CLEAR HISTORY (call when patient leaves chat tab) ────────────────
  void clearHistory() {
    _conversationHistory.clear();
  }
}