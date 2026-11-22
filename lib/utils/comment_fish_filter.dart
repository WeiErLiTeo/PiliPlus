import 'dart:convert';

import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/models/common/reply/fish_filter_strictness.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';

class FishSubscribeResult {
  final int successUrls;
  final int failedUrls;
  final int totalUids;
  final List<String> errors;

  const FishSubscribeResult({
    required this.successUrls,
    required this.failedUrls,
    required this.totalUids,
    required this.errors,
  });
}

abstract final class CommentFishFilter {
  static const String presetAiSlopUrl =
      'https://raw.githubusercontent.com/guoyunhe/bilibili-blocker/main/rules/aislop.txt';
  static const String presetSpamUrl =
      'https://raw.githubusercontent.com/guoyunhe/bilibili-blocker/main/rules/spam.txt';

  static bool enableFishFilter = Pref.enableCommentFishFilter;
  static FishFilterStrictness strictness = Pref.commentFishStrictness;

  static bool enableBanNameForReply = Pref.enableBanNameForReply;
  static RegExp replyNameRegExp = RegExp(
    Pref.banNameForReply,
    caseSensitive: false,
  );
  static bool enableNameFilter =
      enableBanNameForReply && replyNameRegExp.pattern.isNotEmpty;

  static bool enableMinLevelForReply = Pref.enableMinLevelForReply;
  static int minLevelForReply = Pref.minLevelForReply;

  static Map<int, String> fishBlockMap = Pref.fishBlockMidsMap;
  static Set<int> fishBlockMids = fishBlockMap.keys.toSet();

  static Map<int, String> humanWhiteMap = Pref.humanWhiteMidsMap;
  static Set<int> humanWhiteMids = humanWhiteMap.keys.toSet();

  static Set<int> subscribedBlockMids = Pref.subscribedBlockMids;
  static String subscribedRawTxt = Pref.subscribedBlockTxt;
  static List<String> subscribeUrls = Pref.fishSubscribeUrls;

  // --- 多维打分特征正则（纯本地运行，不做头像颜色检测） ---

  static final RegExp _fishNameStrongReg = RegExp(
    r'大肥鱼|小肥鱼|肥鱼|赛博.*鱼|电子鱼|深度求索|deepseek|dsh[_\-\s]|'
    r'ai小?助手|ai评论|ai水军|ai机器人|自动回复|电子宠物|智能体|'
    r'(?:^|[_\-\s])(?:bot|agent)(?:$|[_\-\s\d])',
    caseSensitive: false,
  );

  static final RegExp _defaultBiliNameReg = RegExp(
    r'^bili_\d{8,}$',
    caseSensitive: false,
  );

  // 高置信“鱼八股”/AI 自称话术
  static final RegExp _fishPhraseStrongReg = RegExp(
    r'作为一个\s*ai|作为人工智能|我是.{0,8}ai|本鱼|这条鱼|鱼鱼我|'
    r'吐了?个?泡泡|吐泡泡|甩了甩尾巴|摇了摇尾巴|游过来了|咕噜咕噜|'
    r'赛博大肥鱼|大肥鱼来|大肥鱼路过|已触发自动回复',
    caseSensitive: false,
  );

  // 常见大模型评论腔/论文连接词（需多条命中或配合其他特征）
  static final List<RegExp> _llmClicheRegs = [
    RegExp(r'综上所述'),
    RegExp(r'值得注意的是[,，]?'),
    RegExp(r'总而言之[,，]?'),
    RegExp(r'不可否认的是'),
    RegExp(r'从某种意义上来说'),
    RegExp(r'不仅如此[,，]'),
    RegExp(r'换句话说[,，]'),
    RegExp(r'核心观点如下'),
    RegExp(r'以下几点[:：]'),
    RegExp(r'总的来说[,，]'),
    RegExp(r'总结一下[:：]'),
    RegExp(r'希望能帮到你'),
  ];

  // RP 动作描写括号（AI 角色扮演常见写法）
  static final RegExp _rpActionReg = RegExp(
    r'[（(][^）)\n]{2,22}(?:尾巴|泡泡|游|吐泡|歪头|点头|叹气|眨眼|托腮|'
    r'思考|微笑|挥手|拍手|扶额|擦汗|摸头|脸红|小声|嘀咕|摊手|翻身|摆尾)[^）)\n]{0,10}[）)]|'
    r'\*[^*\n]{2,24}\*|'
    r'【[^】\n]{1,16}(?:系统提示|动作|内心|旁白|AI回复|自动评论)[^】\n]{0,10}】',
    caseSensitive: false,
  );

  static final RegExp _multiParenReg = RegExp(r'[（(][^）)\n]{3,20}[）)]');

  // 结构化分点长文特征
  static final RegExp _structuredListReg = RegExp(
    r'(?:^|\n)\s*(?:[1-4][.、)）]|[-•·]\s|第[一二三四][,，、：:]|首先.{4,60}其次)',
    multiLine: true,
  );

  /// 统一 UID 屏蔽检查：评论区 + 首页推荐 + 热门 + 排行 + 相关视频 + 搜索 均生效
  /// 活人白名单优先级最高，不会被本地黑名单或远程订阅误伤
  static bool isMidBlocked(Object? mid) {
    final int? uid = mid is int ? mid : (mid is num ? mid.toInt() : null);
    if (uid == null || uid <= 0) return false;
    if (humanWhiteMids.contains(uid)) return false;
    return fishBlockMids.contains(uid) || subscribedBlockMids.contains(uid);
  }

  /// 评论区综合过滤入口
  static bool shouldBlockReply(ReplyInfo reply, int? upMid) {
    final mid = reply.mid.toInt();
    // UP 本人或活人白名单直接豁免
    if ((upMid != null && mid == upMid) || humanWhiteMids.contains(mid)) {
      return false;
    }

    // 1. 本地 UID 黑名单 & 远程订阅名单
    if (fishBlockMids.contains(mid) || subscribedBlockMids.contains(mid)) {
      return true;
    }

    final member = reply.member;
    final name = member.name;

    // 2. 评论者昵称正则过滤
    if (enableNameFilter &&
        name.isNotEmpty &&
        replyNameRegExp.hasMatch(name)) {
      return true;
    }

    // 3. 低等级评论过滤
    if (enableMinLevelForReply && minLevelForReply > 0) {
      final level = member.level.toInt();
      if (level < minLevelForReply) {
        return true;
      }
    }

    // 4. 多维启发式防鱼灾打分
    if (enableFishFilter) {
      if (scoreReply(reply) >= strictness.threshold) {
        return true;
      }
    }

    return false;
  }

  /// 本地多维启发式打分（0~99），不检测头像颜色
  static int scoreReply(ReplyInfo reply) {
    final member = reply.member;
    // 官方认证（蓝V/黄V）豁免自动打分
    if (member.hasOfficialVerifyType() &&
        member.officialVerifyType.toInt() >= 0) {
      return 0;
    }

    int score = 0;
    final name = member.name;
    final msg = reply.content.message;
    final level = member.level.toInt();
    final isVip = member.vipStatus.toInt() > 0;
    final isSenior = member.isSeniorMember == 1;

    // A. 昵称特征
    if (name.isNotEmpty) {
      if (_fishNameStrongReg.hasMatch(name)) {
        score += 45;
      } else if (_defaultBiliNameReg.hasMatch(name)) {
        score += 15;
      }
    }

    // B. 话术与“鱼八股”特征
    if (msg.isNotEmpty) {
      if (_fishPhraseStrongReg.hasMatch(msg)) {
        score += 40;
      }

      int clicheHits = 0;
      for (final reg in _llmClicheRegs) {
        if (reg.hasMatch(msg)) {
          clicheHits++;
          if (clicheHits >= 2) break;
        }
      }
      if (clicheHits == 1) {
        score += 15;
      } else if (clicheHits >= 2) {
        score += 32;
      }

      // C. RP 动作括号特征
      if (_rpActionReg.hasMatch(msg)) {
        score += 25;
      } else if (_multiParenReg.allMatches(msg).length >= 3) {
        score += 18;
      }

      // D. 结构化分点长文 / 机械多 @ 长评
      if (msg.length >= 140 && _structuredListReg.allMatches(msg).length >= 2) {
        score += 20;
      } else if (msg.length >= 100 && reply.content.atNameToMid.length >= 2) {
        score += 15;
      }
    }

    // E. 账号权重修正（低等级小号小幅加分，高信誉账号减分防误杀）
    if (level <= 2 && !isVip) {
      score += 15;
    }
    if (isVip) {
      score -= 10;
    }
    if (isSenior) {
      score -= 15;
    }
    if (level >= 6) {
      score -= 15;
    } else if (level == 5) {
      score -= 5;
    }

    return score.clamp(0, 99);
  }

  // --- 本地黑白名单增删 ---

  static void addFishMid(int mid, {String name = ''}) {
    if (mid <= 0) return;
    humanWhiteMap.remove(mid);
    humanWhiteMids.remove(mid);
    fishBlockMap[mid] = name.trim();
    fishBlockMids.add(mid);
    Pref.humanWhiteMidsMap = humanWhiteMap;
    Pref.fishBlockMidsMap = fishBlockMap;
  }

  static void removeFishMid(int mid) {
    if (fishBlockMap.remove(mid) != null) {
      fishBlockMids.remove(mid);
      Pref.fishBlockMidsMap = fishBlockMap;
    }
  }

  static void addWhiteMid(int mid, {String name = ''}) {
    if (mid <= 0) return;
    fishBlockMap.remove(mid);
    fishBlockMids.remove(mid);
    humanWhiteMap[mid] = name.trim();
    humanWhiteMids.add(mid);
    Pref.fishBlockMidsMap = fishBlockMap;
    Pref.humanWhiteMidsMap = humanWhiteMap;
  }

  static void removeWhiteMid(int mid) {
    if (humanWhiteMap.remove(mid) != null) {
      humanWhiteMids.remove(mid);
      Pref.humanWhiteMidsMap = humanWhiteMap;
    }
  }

  // --- TXT / JSON 解析与导出 ---

  /// 解析 .txt（每行一个 UID，支持 `# 备注`）或常见 JSON（数组、Map、dafeiyu-cleaner 导出格式）
  static Map<int, String> parseUidText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return <int, String>{};

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        final parsed = _extractFromJson(decoded);
        if (parsed.isNotEmpty) return parsed;
      } catch (_) {
        // 回退按纯文本逐行解析
      }
    }

    final result = <int, String>{};
    final lines = const LineSplitter().convert(raw);
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }

      String left = line;
      String note = '';
      final hashIdx = line.indexOf('#');
      if (hashIdx >= 0) {
        left = line.substring(0, hashIdx).trim();
        note = line.substring(hashIdx + 1).trim();
      } else {
        final slashIdx = line.indexOf('//');
        if (slashIdx >= 0) {
          left = line.substring(0, slashIdx).trim();
          note = line.substring(slashIdx + 2).trim();
        }
      }

      if (left.isEmpty) continue;

      // 支持 "123456 昵称" 或 "123456,昵称" 或 "UID:123456"
      final match = RegExp(r'^(?:uid[:：\s]*)?(\d+)(?:[\s,，\t]+(.+))?$', caseSensitive: false)
          .firstMatch(left);
      if (match != null) {
        final uid = int.tryParse(match.group(1)!);
        if (uid != null && uid > 0) {
          final inlineNote = match.group(2)?.trim() ?? '';
          result[uid] = note.isNotEmpty ? note : inlineNote;
        }
        continue;
      }

      // 兜底：一行里塞了多个用逗号/空格隔开的 UID
      for (final m in RegExp(r'\b(\d{4,})\b').allMatches(left)) {
        final uid = int.tryParse(m.group(1)!);
        if (uid != null && uid > 0) {
          result.putIfAbsent(uid, () => note);
        }
      }
    }
    return result;
  }

  static Map<int, String> _extractFromJson(dynamic decoded) {
    final result = <int, String>{};
    void visit(dynamic node) {
      if (node is int && node > 0) {
        result.putIfAbsent(node, () => '');
      } else if (node is String) {
        final uid = int.tryParse(node.trim());
        if (uid != null && uid > 0) {
          result.putIfAbsent(uid, () => '');
        }
      } else if (node is List) {
        for (final item in node) {
          visit(item);
        }
      } else if (node is Map) {
        // 常见对象结构: {"uid": 123, "name": "xxx"} / {"mid": 123, "uname": "xxx"}
        final rawId = node['uid'] ?? node['mid'] ?? node['id'];
        if (rawId != null) {
          final uid = rawId is int ? rawId : int.tryParse(rawId.toString());
          if (uid != null && uid > 0) {
            final name =
                (node['name'] ?? node['uname'] ?? node['note'] ?? node['reason'] ?? '')
                    .toString()
                    .trim();
            result[uid] = name;
            return;
          }
        }
        // 常见键值结构或嵌套结构: {"12345": "备注"} / {"blacklist": [...]}
        node.forEach((k, v) {
          final keyUid = int.tryParse(k.toString());
          if (keyUid != null && keyUid > 0) {
            if (v is String) {
              result[keyUid] = v.trim();
            } else if (v is Map) {
              final name = (v['name'] ?? v['uname'] ?? v['note'] ?? '').toString().trim();
              result[keyUid] = name;
            } else {
              result.putIfAbsent(keyUid, () => '');
            }
          } else if (k.toString().toLowerCase() != 'whitelist') {
            visit(v);
          }
        });
      }
    }

    visit(decoded);
    return result;
  }

  static String exportMapToTxt(Map<int, String> map, {String? header}) {
    final buf = StringBuffer();
    if (header != null && header.isNotEmpty) {
      buf.writeln('# $header');
    }
    final sortedKeys = map.keys.toList()..sort();
    for (final uid in sortedKeys) {
      final note = (map[uid] ?? '').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      if (note.isNotEmpty) {
        buf.writeln('$uid # $note');
      } else {
        buf.writeln('$uid');
      }
    }
    return buf.toString();
  }

  static String getSubscribedTxt() {
    if (subscribedRawTxt.trim().isNotEmpty) {
      return subscribedRawTxt;
    }
    if (subscribedBlockMids.isEmpty) {
      return '# 每行一个 UID，支持 # 注释（兼容 bilibili-blocker .txt 格式）\n';
    }
    final buf = StringBuffer(
      '# 远程订阅 UID 列表（共 ${subscribedBlockMids.length} 条）\n',
    );
    final sorted = subscribedBlockMids.toList()..sort();
    for (final uid in sorted) {
      buf.writeln(uid);
    }
    return buf.toString();
  }

  static int replaceFishBlockFromText(String raw) {
    final parsed = parseUidText(raw);
    fishBlockMap = parsed;
    fishBlockMids = parsed.keys.toSet();
    Pref.fishBlockMidsMap = fishBlockMap;
    return fishBlockMap.length;
  }

  static int mergeFishBlockFromText(String raw) {
    final parsed = parseUidText(raw);
    fishBlockMap.addAll(parsed);
    fishBlockMids = fishBlockMap.keys.toSet();
    Pref.fishBlockMidsMap = fishBlockMap;
    return parsed.length;
  }

  static int replaceHumanWhiteFromText(String raw) {
    final parsed = parseUidText(raw);
    humanWhiteMap = parsed;
    humanWhiteMids = parsed.keys.toSet();
    Pref.humanWhiteMidsMap = humanWhiteMap;
    return humanWhiteMap.length;
  }

  static int mergeHumanWhiteFromText(String raw) {
    final parsed = parseUidText(raw);
    humanWhiteMap.addAll(parsed);
    humanWhiteMids = humanWhiteMap.keys.toSet();
    Pref.humanWhiteMidsMap = humanWhiteMap;
    return parsed.length;
  }

  static int replaceSubscribedFromText(String raw) {
    final parsed = parseUidText(raw);
    subscribedRawTxt = raw;
    subscribedBlockMids = parsed.keys.toSet();
    Pref.subscribedBlockTxt = subscribedRawTxt;
    Pref.subscribedBlockMids = subscribedBlockMids;
    return subscribedBlockMids.length;
  }

  static int mergeSubscribedFromText(String raw) {
    final parsed = parseUidText(raw);
    final merged = <int>{...subscribedBlockMids, ...parsed.keys};
    subscribedBlockMids = merged;
    final prefix = subscribedRawTxt.trim();
    subscribedRawTxt = prefix.isEmpty ? raw : '$prefix\n${raw.trim()}\n';
    Pref.subscribedBlockTxt = subscribedRawTxt;
    Pref.subscribedBlockMids = subscribedBlockMids;
    return parsed.length;
  }

  static void clearSubscribed() {
    subscribedBlockMids = <int>{};
    subscribedRawTxt = '';
    Pref.subscribedBlockMids = subscribedBlockMids;
    Pref.subscribedBlockTxt = '';
  }

  static void saveSubscribeUrls(List<String> urls) {
    final cleaned = urls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    subscribeUrls = cleaned;
    Pref.fishSubscribeUrls = cleaned;
  }

  /// 从订阅 URL 列表拉取远程 .txt / .json 规则并更新本地缓存
  static Future<FishSubscribeResult> fetchSubscriptions({
    List<String>? urls,
  }) async {
    final targetUrls = urls ?? subscribeUrls;
    if (targetUrls.isEmpty) {
      return const FishSubscribeResult(
        successUrls: 0,
        failedUrls: 0,
        totalUids: 0,
        errors: ['请先添加至少一个订阅链接'],
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
        headers: const {'User-Agent': 'PiliPlus/FishFilter'},
      ),
    );

    final mergedUids = <int>{};
    final rawSections = StringBuffer();
    int success = 0;
    int failed = 0;
    final errors = <String>[];

    for (final rawUrl in targetUrls) {
      final url = rawUrl.trim();
      if (url.isEmpty) continue;
      try {
        final resp = await dio.get<String>(url);
        final body = resp.data ?? '';
        final parsed = parseUidText(body);
        mergedUids.addAll(parsed.keys);
        rawSections.writeln('# Source: $url (${parsed.length} UIDs)');
        rawSections.writeln(body.trim());
        rawSections.writeln();
        success++;
      } catch (e) {
        failed++;
        errors.add('$url -> $e');
      }
    }

    dio.close();

    if (success > 0) {
      subscribedBlockMids = mergedUids;
      subscribedRawTxt = rawSections.toString();
      Pref.subscribedBlockMids = subscribedBlockMids;
      Pref.subscribedBlockTxt = subscribedRawTxt;
    }

    return FishSubscribeResult(
      successUrls: success,
      failedUrls: failed,
      totalUids: subscribedBlockMids.length,
      errors: errors,
    );
  }
}
