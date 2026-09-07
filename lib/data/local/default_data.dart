import '../../domain/models/word_item.dart';
import '../../domain/models/listening_test_info.dart';
import '../../domain/models/subtitle_sentence.dart';
import '../../domain/models/exam_question.dart';

class DefaultData {
  DefaultData._();

  static List<ListeningTestInfo> get initialTests => [
        ListeningTestInfo(
          testId: 'c18_t1_s1',
          book: 'Cambridge 18',
          testNumber: 1,
          section: 1,
          title: 'Transport Survey - Commuter Feedback',
          audioUrl:
              'https://actions.google.com/sounds/v1/ambiences/train_station.ogg',
          localAudioPath: 'assets/demo/c18_t1_s1.mp3',
          totalDurationMs: 64500,
          isDownloaded: true,
          playCount: 1,
          completionRate: 0.8,
          questions: [
            ExamQuestion(
              questionNumber: 1,
              promptBefore: 'Customer Full Name: Luisa ',
              promptAfter: '',
              acceptableAnswers: ['Gould'],
              targetSentenceIndex: 3,
            ),
            ExamQuestion(
              questionNumber: 2,
              promptBefore: 'Occupation: ',
              promptAfter: ' (environmental)',
              acceptableAnswers: ['consultant'],
              targetSentenceIndex: 3,
            ),
            ExamQuestion(
              questionNumber: 3,
              promptBefore: 'Journey Purpose: mainly for ',
              promptAfter: '',
              acceptableAnswers: ['commuting'],
              targetSentenceIndex: 5,
            ),
            ExamQuestion(
              questionNumber: 4,
              promptBefore: 'Frequency: travels ',
              promptAfter: ' days a week by train',
              acceptableAnswers: ['5', 'five'],
              targetSentenceIndex: 5,
            ),
            ExamQuestion(
              questionNumber: 5,
              promptBefore: 'Peak service: satisfied with the ',
              promptAfter: '',
              acceptableAnswers: ['punctuality'],
              targetSentenceIndex: 7,
            ),
            ExamQuestion(
              questionNumber: 6,
              promptBefore: 'Train conditions: carriages are often ',
              promptAfter: '',
              acceptableAnswers: ['overcrowded'],
              targetSentenceIndex: 7,
            ),
            ExamQuestion(
              questionNumber: 7,
              promptBefore: 'Crowding worst between 8 and ',
              promptAfter: ' AM',
              acceptableAnswers: ['9', 'nine'],
              targetSentenceIndex: 7,
            ),
            ExamQuestion(
              questionNumber: 8,
              promptBefore: 'Ticket type: monthly ',
              promptAfter: ' ticket',
              acceptableAnswers: ['season'],
              targetSentenceIndex: 8,
            ),
            ExamQuestion(
              questionNumber: 9,
              promptBefore: 'Fares have risen ',
              promptAfter: ' this year',
              acceptableAnswers: ['significantly'],
              targetSentenceIndex: 9,
            ),
            ExamQuestion(
              questionNumber: 10,
              promptBefore: 'Cost is hardest on ',
              promptAfter: ' and interns',
              acceptableAnswers: ['students'],
              targetSentenceIndex: 9,
            ),
          ],
          sentences: [
            const SubtitleSentence(
              index: 0,
              startMs: 0,
              endMs: 4200,
              textEn:
                  'Good morning. Could you spare a few minutes to complete a transport survey?',
              textZh: '早上好。请问您能抽几分钟完成一份交通出行问卷调查吗？',
              keyWords: ['transport', 'survey', 'complete'],
            ),
            const SubtitleSentence(
              index: 1,
              startMs: 4300,
              endMs: 8500,
              textEn:
                  'Sure, I have about ten minutes before my next train arrives.',
              textZh: '当然可以，距离我的下一趟火车进站还有大约十分钟。',
              keyWords: ['train', 'arrive'],
            ),
            const SubtitleSentence(
              index: 2,
              startMs: 8600,
              endMs: 14200,
              textEn:
                  'Great, thank you! First, can I take your full name and occupation for our records?',
              textZh: '太好了，谢谢您！首先，我能记录一下您的全名和职业吗？',
              keyWords: ['occupation', 'records'],
            ),
            const SubtitleSentence(
              index: 3,
              startMs: 14300,
              endMs: 19800,
              textEn:
                  "Yes, it's Luisa Gould, and I work as an environmental consultant in the city center.",
              textZh: '可以，我是路易莎·古尔德，我在市中心担任环境顾问。',
              keyWords: ['environmental', 'consultant'],
            ),
            const SubtitleSentence(
              index: 4,
              startMs: 19900,
              endMs: 26500,
              textEn:
                  'And what is the main purpose of your journey today? Is it for commuting or leisure?',
              textZh: '那么您今天出行的主要目的是什么？是通勤上班还是休闲出游？',
              keyWords: ['purpose', 'commuting', 'leisure'],
            ),
            const SubtitleSentence(
              index: 5,
              startMs: 26600,
              endMs: 33100,
              textEn:
                  'Mainly commuting. I take the railway line into town five days a week from Monday to Friday.',
              textZh: '主要是日常通勤。我周一到周五每周有五天都坐铁路线进城。',
              keyWords: ['railway', 'commuting'],
            ),
            const SubtitleSentence(
              index: 6,
              startMs: 33200,
              endMs: 40500,
              textEn:
                  'How would you rate the punctuality and frequency of the train service during peak hours?',
              textZh: '在高峰时段，您对列车服务的准点率和发车频次评价如何？',
              keyWords: ['punctuality', 'frequency', 'peak'],
            ),
            const SubtitleSentence(
              index: 7,
              startMs: 40600,
              endMs: 48200,
              textEn:
                  'Punctuality is satisfactory, but the carriages are often overcrowded, especially between 8 and 9 AM.',
              textZh: '准点率令人满意，但车厢常常过度拥挤，尤其是早上八点到九点之间。',
              keyWords: ['satisfactory', 'carriages', 'overcrowded'],
            ),
            const SubtitleSentence(
              index: 8,
              startMs: 48300,
              endMs: 56000,
              textEn:
                  'Do you feel the monthly season ticket offers reasonable value for money?',
              textZh: '您觉得月度定期票的价格在性价比方面是否合理？',
              keyWords: ['season', 'reasonable', 'value'],
            ),
            const SubtitleSentence(
              index: 9,
              startMs: 56100,
              endMs: 64500,
              textEn:
                  'Honestly, fares have increased significantly this year, so it is quite expensive for students and interns.',
              textZh: '老实说，今年票价上涨幅度很大，因此对学生和实习生来说相当昂贵。',
              keyWords: ['fares', 'significantly', 'expensive', 'interns'],
            ),
          ],
        ),
        ListeningTestInfo(
          testId: 'c18_t1_s2',
          book: 'Cambridge 18',
          testNumber: 1,
          section: 2,
          title: 'Community Center Facilities & Volunteer Program',
          audioUrl:
              'https://actions.google.com/sounds/v1/ambiences/coffee_shop.ogg',
          localAudioPath: 'assets/demo/c18_t1_s2.mp3',
          totalDurationMs: 80000,
          isDownloaded: false,
          playCount: 0,
          completionRate: 0.0,
          sentences: [],
        ),
        ListeningTestInfo(
          testId: 'c18_t2_s1',
          book: 'Cambridge 18',
          testNumber: 2,
          section: 1,
          title: 'Holiday Rental Apartment Inquiry',
          audioUrl:
              'https://actions.google.com/sounds/v1/ambiences/rain_heavy.ogg',
          localAudioPath: 'assets/demo/c18_t2_s1.mp3',
          totalDurationMs: 92000,
          isDownloaded: false,
          playCount: 0,
          completionRate: 0.0,
          sentences: [],
        ),
      ];

  static List<WordItem> get initialVocabulary => [
        WordItem(
          id: 'vocab_punctuality',
          word: 'punctuality',
          phoneticUk: '/ˌpʌŋktʃuˈæləti/',
          phoneticUs: '/ˌpʌŋktʃuˈæləti/',
          definitionZh: 'n. 准时，守时',
          ieltsTag: '听力考点高频词',
          contextSentenceEn:
              'How would you rate the punctuality and frequency of the train service?',
          contextSentenceZh: '在高峰时段，您对列车服务的准点率和发车频次评价如何？',
          sourceTest: 'C18 T1 S1',
          isFavorite: true,
          addedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        WordItem(
          id: 'vocab_commuting',
          word: 'commuting',
          phoneticUk: '/kəˈmjuːtɪŋ/',
          phoneticUs: '/kəˈmjuːtɪŋ/',
          definitionZh: 'n. 通勤，上下班往返',
          ieltsTag: '交通生活场景',
          contextSentenceEn:
              'Is your journey for commuting or leisure purposes?',
          contextSentenceZh: '您本次出行是用于通勤还是休闲娱乐？',
          sourceTest: 'C18 T1 S1',
          isFavorite: true,
          addedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        WordItem(
          id: 'vocab_overcrowded',
          word: 'overcrowded',
          phoneticUk: '/ˌəʊvəˈkraʊdɪd/',
          phoneticUs: '/ˌoʊvərˈkraʊdɪd/',
          definitionZh: 'adj. 过度拥挤的，容纳过多的',
          ieltsTag: '听力常考形容词',
          contextSentenceEn:
              'The carriages are often overcrowded, especially between 8 and 9 AM.',
          contextSentenceZh: '车厢常常过度拥挤，尤其是早上八点到九点之间。',
          sourceTest: 'C18 T1 S1',
          isFavorite: false,
          addedAt: DateTime.now(),
        ),
        WordItem(
          id: 'vocab_consultant',
          word: 'consultant',
          phoneticUk: '/kənˈsʌltənt/',
          phoneticUs: '/kənˈsʌltənt/',
          definitionZh: 'n. 顾问，咨询专家',
          ieltsTag: '职业听力填空',
          contextSentenceEn:
              'I work as an environmental consultant in the city center.',
          contextSentenceZh: '我在市中心担任环境顾问。',
          sourceTest: 'C18 T1 S1',
          isFavorite: false,
          addedAt: DateTime.now(),
        ),
        WordItem(
          id: 'vocab_accommodation',
          word: 'accommodation',
          phoneticUk: '/əˌkɒməˈdeɪʃn/',
          phoneticUs: '/əˌkɑːməˈdeɪʃn/',
          definitionZh: 'n. 住宿，膳宿（注意双c双m拼写！）',
          ieltsTag: '听力拼写陷阱Top1',
          contextSentenceEn:
              'The student union provides affordable student accommodation near campus.',
          contextSentenceZh: '学生会提供校区附近的实惠学生住宿。',
          sourceTest: 'C17 T3 S1',
          isFavorite: true,
          addedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        WordItem(
          id: 'vocab_sustainable',
          word: 'sustainable',
          phoneticUk: '/səˈsteɪnəbl/',
          phoneticUs: '/səˈsteɪnəbl/',
          definitionZh: 'adj. 可持续的，不破坏环境的',
          ieltsTag: '学术词汇写作高分',
          contextSentenceEn:
              'Investing in sustainable public transport reduces carbon emissions.',
          contextSentenceZh: '投资可持续公共交通能有效降低碳排放。',
          sourceTest: 'C18 T2 S4',
          isFavorite: false,
          addedAt: DateTime.now(),
        ),
      ];
}
