import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/ai/ai_chat_service.dart';
import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/ai/claude_client.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/features/settings/settings_page.dart';

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

  _Msg({
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
            level: ref.read(settingsProvider).jlptLevel,
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
          duration: Duration(milliseconds: 250),
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
              icon: Icon(Icons.swap_horiz),
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
      padding: EdgeInsets.all(18),
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 3),
            boxShadow: AppShadows.hardSmall,
          ),
          child: Column(
            children: [
              Text('💬', style: TextStyle(fontSize: 36)),
              SizedBox(height: 8),
              Text(
                '和 AI 用日語對話',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.indigo,
                ),
              ),
              SizedBox(height: 4),
              Text(
                hasKey
                    ? 'AI 扮演店員，用 N5 日語回覆＋繁中翻譯；你的日語有錯會溫和糾正。中文也能聊！'
                    : '需要 Claude API Key（設定頁貼上）',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigoFaded,
                ),
              ),
              if (!hasKey) ...[
                SizedBox(height: 12),
                FilledButton.icon(
                  icon: Icon(Icons.key, size: 18),
                  label: Text('前往設定 API Key'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SettingsPage()),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 20),
        Text(
          '選擇情境',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.indigo,
          ),
        ),
        SizedBox(height: 10),
        for (final (emoji, name) in chatScenarios)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
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
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppColors.indigo, width: 2),
                  ),
                  child: Row(
                    children: [
                      Text(emoji, style: TextStyle(fontSize: 24)),
                      SizedBox(width: 12),
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
            padding: EdgeInsets.all(14),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) {
                return Padding(
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
            margin: EdgeInsets.symmetric(horizontal: 14),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.red, width: 2),
            ),
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppColors.indigo, width: 2),
                    ),
                    child: TextField(
                      controller: _input,
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: '打日文（或中文）…',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Material(
                  color: AppColors.indigoSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: InkWell(
                    onTap: _sending ? null : _send,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: SizedBox(
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
          margin: EdgeInsets.only(bottom: 10, left: 60),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Text(
            m.text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.indigoSurface,
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 10, right: 40),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
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
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                SpeakButton(text: m.text, size: 28),
              ],
            ),
            SizedBox(height: 4),
            Text(
              m.translation,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.indigoFaded,
              ),
            ),
            if (m.correction.isNotEmpty) ...[
              SizedBox(height: 6),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '💡 ${m.correction}',
                  style: TextStyle(
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
