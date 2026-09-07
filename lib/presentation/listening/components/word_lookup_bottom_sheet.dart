import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/word_item.dart';
import '../../providers/app_providers.dart';

class WordLookupBottomSheet extends ConsumerStatefulWidget {
  final String word;
  final String contextSentenceEn;
  final String contextSentenceZh;
  final String sourceTest;
  final Function(WordItem) onAddToNotebook;

  const WordLookupBottomSheet({
    super.key,
    required this.word,
    required this.contextSentenceEn,
    required this.contextSentenceZh,
    this.sourceTest = '剑雅真题',
    required this.onAddToNotebook,
  });

  @override
  ConsumerState<WordLookupBottomSheet> createState() =>
      _WordLookupBottomSheetState();
}

class _WordLookupBottomSheetState
    extends ConsumerState<WordLookupBottomSheet> {
  bool _isAdded = false;

  void _speak() {
    ref.read(audioCacheServiceProvider).playWordUk(widget.word);
  }

  void _speakSentence() {
    ref.read(audioCacheServiceProvider).speakSentence(
          widget.contextSentenceEn,
          word: widget.word,
        );
  }

  @override
  Widget build(BuildContext context) {
    // 简明离线词典词条查找（本地简易快速查询）
    final cleanWord = widget.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final def = _lookupDefinition(cleanWord);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: AppColors.paperBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽手柄条
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 单词与发音
          Row(
            children: [
              Text(
                cleanWord,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.ieltsCrimson),
                onPressed: _speak,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.ieltsCrimson.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  def['tag'] ?? '雅思核心',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.ieltsCrimson,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // 音标
          Text(
            def['phonetic'] ?? '/$cleanWord/',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'sans-serif',
            ),
          ),
          const SizedBox(height: 14),

          // 简释
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paperSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              def['meaning'] ?? '雅思真题关键考点词，需掌握同义转述与拼写',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 真题语境例句
          if (widget.contextSentenceEn.isNotEmpty) ...[
            Row(
              children: [
                const Text(
                  '真题语境出处',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _speakSentence,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_outline_rounded,
                            size: 14, color: AppColors.oxfordNavy),
                        SizedBox(width: 4),
                        Text(
                          '朗读例句',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.oxfordNavy,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.contextSentenceEn,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 操作按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: MiuixButton(
              onPressed: _isAdded
                  ? null
                  : () {
                      final item = WordItem(
                        id: 'vocab_${cleanWord}_${DateTime.now().millisecondsSinceEpoch}',
                        word: cleanWord,
                        phoneticUk: def['phonetic'] ?? '',
                        phoneticUs: def['phonetic'] ?? '',
                        definitionZh: def['meaning'] ?? '雅思真题词汇',
                        ieltsTag: def['tag'] ?? '剑雅精听',
                        contextSentenceEn: widget.contextSentenceEn,
                        contextSentenceZh: widget.contextSentenceZh,
                        sourceTest: widget.sourceTest,
                        isFavorite: true,
                        addedAt: DateTime.now(),
                      );
                      widget.onAddToNotebook(item);
                      setState(() => _isAdded = true);
                    },
              colors: MiuixButtonDefaults.buttonColorsPrimary(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isAdded ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(_isAdded ? '已加入生词本' : '加入雅思生词本'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _lookupDefinition(String word) {
    const dict = {
      'transport': {
        'phonetic': '/ˈtrænspɔːt/',
        'meaning': 'n. 交通，运输工具；v. 运送',
        'tag': '听力场景高频',
      },
      'survey': {
        'phonetic': '/ˈsɜːveɪ/',
        'meaning': 'n. 调查，民意测验；全面审视',
        'tag': '听力题型标志词',
      },
      'complete': {
        'phonetic': '/kəmˈpliːt/',
        'meaning': 'v. 完成，填写；adj. 完整的',
        'tag': '基础考点',
      },
      'train': {
        'phonetic': '/treɪn/',
        'meaning': 'n. 列车，火车；v. 培训',
        'tag': '基础交通词',
      },
      'arrive': {
        'phonetic': '/əˈraɪv/',
        'meaning': 'v. 到达，抵达',
        'tag': '动词考点',
      },
      'occupation': {
        'phonetic': '/ˌɒkjuˈpeɪʃn/',
        'meaning': 'n. 职业，工作；占领',
        'tag': 'Section 1填空必考',
      },
      'records': {
        'phonetic': '/ˈrekɔːdz/',
        'meaning': 'n. 档案，记录；唱片',
        'tag': '高频名词',
      },
      'environmental': {
        'phonetic': '/ɪnˌvaɪrənˈmentl/',
        'meaning': 'adj. 自然环境的，生态的',
        'tag': '学术高频词',
      },
      'consultant': {
        'phonetic': '/kənˈsʌltənt/',
        'meaning': 'n. 顾问，特约咨询专家',
        'tag': 'Section 1职业填空',
      },
      'commuting': {
        'phonetic': '/kəˈmjuːtɪŋ/',
        'meaning': 'n. 通勤，上下班往返',
        'tag': '租房与出行考点',
      },
      'railway': {
        'phonetic': '/ˈreɪlweɪ/',
        'meaning': 'n. 铁路系统，铁路线',
        'tag': '交通设施词',
      },
      'punctuality': {
        'phonetic': '/ˌpʌŋktʃuˈæləti/',
        'meaning': 'n. 准时，守时',
        'tag': '听力难点词',
      },
      'frequency': {
        'phonetic': '/ˈfriːkwənsi/',
        'meaning': 'n. 发车频次，频率',
        'tag': '统计分析高频',
      },
      'overcrowded': {
        'phonetic': '/ˌəʊvəˈkraʊdɪd/',
        'meaning': 'adj. 过于拥挤的，人满为患的',
        'tag': '形容词高分替换',
      },
      'fares': {
        'phonetic': '/feəz/',
        'meaning': 'n. 票价，车船乘车费',
        'tag': '费用相关考点',
      },
      'interns': {
        'phonetic': '/ˈɪntɜːnz/',
        'meaning': 'n. 实习生',
        'tag': '工作场景考点',
      },
      'accommodation': {
        'phonetic': '/əˌkɒməˈdeɪʃn/',
        'meaning': 'n. 住宿，住处（常考双c双m拼写）',
        'tag': '听力拼写陷阱Top1',
      },
    };

    return dict[word] ??
        {
          'phonetic': '/$word/',
          'meaning': '雅思核心语境词条，点击可保存至生词本使用 FSRS 智能复习。',
          'tag': '精听生词',
        };
  }
}
