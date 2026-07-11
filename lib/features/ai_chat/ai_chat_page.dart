import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_chat_service.dart';
import '../../core/ai/ai_quiz_service.dart';
import '../../core/ai/claude_client.dart';
import '../../core/theme/app_theme.dart';
import '../practice/widgets/quiz_widgets.dart';
import '../settings/settings_page.dart';

const chatScenarios = [
  ('✈️', '機場報到櫃檯'),
  ('🚉', '車站售票口'),
  ('🏨', '飯店入住櫃檯'),
  ('🍜', '餐廳點餐'),
  ('🛍️', '商店購物'),
];

/// 一則訊息（UI 用）。
class _Msg {
  final bool isUser;
  final String text; // 日文（user 輸入或 AI reply）
  final String translation; // AI 訊息的繁中
  final String correction; // 對使用者上一句的糾正

  const _Msg({
    required this.isUser,
    required this.text,
    this.translation = '',
    this.correction = '',
  });
}

/// AI 情境對話：Claude 扮演店員/地勤，練習開口說（打字版）。
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  String? _scenario;
  final List<_Msg> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;

  static const _maxTurns = 20;

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_Msg(isUser: true, text: text));
      _sending = true;
      _error = null;
      _input.clear();
    });
    _scrollDown();

    try {
      final reply = await ref.read(aiChatServiceProvider).send(
            apiKey: ref.read(apiKeyProvider),
            scenario: _scenario!,
            history: [
              for (final m in _messages.takeLast(_maxTurns))
                (isUser: m.isUser, text: m.text),
            ],
          );
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(
          isUser: false,
          text: reply.reply,
          translation: reply.translation,
          correction: reply.correction,
        ));
        _sending = false;
      });
      _scrollDown();
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(_scenario == null ? 'AI 情境對話' : _scenario!),
        actions: [
          if (_scenario != null)
            IconButton(
              tooltip: '換情境',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => setState(() {
                _scenario = null;
                _messages.clear();
                _error = null;
              }),
            ),
        ],
      ),
      body: _scenario == null ? _buildPicker() : _buildChat(),
    );
  }

  Widget _buildPicker() {
    final hasKey = ref.watch(apiKeyProvider).isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 3),
            boxShadow: AppShadows.hardSmall,
          ),
          child: Column(
            children: [
              const Text('💬', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              const Text(
                '和 AI 用日語對話',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.indigo,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasKey
                    ? 'AI 扮演店員，用 N5 日語回覆＋繁中翻譯；你的日語有錯會溫和糾正。中文也能聊！'
                    : '需要 Claude API Key（設定頁貼上）',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigoFaded,
                ),
              ),
              if (!hasKey) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.key, size: 18),
                  label: const Text('前往設定 API Key'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '選擇情境',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.indigo,
          ),
        ),
        const SizedBox(height: 10),
        for (final (emoji, name) in chatScenarios)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: InkWell(
                onTap: hasKey
                    ? () {
                        setState(() => _scenario = name);
                        _send('こんにちは。'); // 開場
                      }
                    : null,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppColors.indigo, width: 2),
                  ),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: hasKey
                              ? AppColors.indigo
                              : AppColors.indigoFaded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(14),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.indigo,
                      ),
                    ),
                  ),
                );
              }
              return _bubble(_messages[i]);
            },
          ),
        ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.red, width: 2),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppColors.indigo, width: 2),
                    ),
                    child: TextField(
                      controller: _input,
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        hintText: '打日文（或中文）…',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.indigo,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: InkWell(
                    onTap: _sending ? null : _send,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.send, color: AppColors.gold, size: 20),
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

  Widget _bubble(_Msg m) {
    if (m.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Text(
            m.text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.indigo,
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 40),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.indigo, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    m.text,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SpeakButton(text: m.text, size: 28),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m.translation,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.indigoFaded,
              ),
            ),
            if (m.correction.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '💡 ${m.correction}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  Iterable<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
