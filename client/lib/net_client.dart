// 联机客户端：WebSocket 消息封装
// 协议见 server/src/room.js 顶部注释

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'game/tiles.dart';
import 'game/scoring.dart' show Meld;

/// 服务器推送的个人视角状态（对应 table.view()）
class OnlineView {
  final String state; // huan | dingque | playing | over
  final String phase;
  final int turn;
  final int wallLeft;
  final Map<String, dynamic>? lastDiscard;
  final Map<String, dynamic>? canSelfDraw;
  final List<int> canGangTiles;
  final List<OnlinePlayer> players;
  final int mySeat;
  final bool exchangeDone;
  final String exchangeDirection;
  final int wallStartSide;

  OnlineView({
    required this.state,
    required this.phase,
    required this.turn,
    required this.wallLeft,
    required this.lastDiscard,
    required this.canSelfDraw,
    required this.canGangTiles,
    required this.players,
    required this.mySeat,
    required this.exchangeDone,
    required this.exchangeDirection,
    required this.wallStartSide,
  });

  factory OnlineView.fromJson(Map<String, dynamic> j, int mySeat) {
    return OnlineView(
      state: j['state'] as String,
      phase: j['phase'] as String,
      turn: j['turn'] as int,
      wallLeft: j['wallLeft'] as int? ?? 0,
      lastDiscard: j['lastDiscard'] as Map<String, dynamic>?,
      canSelfDraw: j['canSelfDraw'] as Map<String, dynamic>?,
      canGangTiles: j['canGangTiles'] != null
          ? List<int>.from(j['canGangTiles'])
          : <int>[],
      players: (j['players'] as List)
          .map((p) => OnlinePlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      mySeat: mySeat,
      exchangeDone: j['exchangeDone'] as bool? ?? true,
      exchangeDirection: j['exchangeDirection'] as String? ?? '下家',
      wallStartSide: j['wallStartSide'] as int? ?? 0,
    );
  }

  OnlinePlayer get me => players[mySeat];
  List<int> get myHand => sortHand(me.hand ?? []);
}

class OnlinePlayer {
  final int seat;
  final String name;
  final int? dingque;
  final List<Meld> melds;
  final List<int> discards;
  final Map<String, dynamic>? hu;
  final int handCount;
  final List<int>? hand;

  OnlinePlayer({
    required this.seat,
    required this.name,
    required this.dingque,
    required this.melds,
    required this.discards,
    required this.hu,
    required this.handCount,
    required this.hand,
  });

  bool get isHued => hu != null;

  factory OnlinePlayer.fromJson(Map<String, dynamic> j) {
    return OnlinePlayer(
      seat: j['seat'] as int,
      name: j['name'] as String? ?? '玩家${j['seat']}',
      dingque: j['dingque'] as int?,
      melds: (j['melds'] as List? ?? [])
          .map((m) => Meld.fromJson(m as Map<String, dynamic>))
          .toList(),
      discards: j['discards'] != null ? List<int>.from(j['discards']) : <int>[],
      hu: j['hu'] as Map<String, dynamic>?,
      handCount: j['handCount'] as int? ?? 13,
      hand: j['hand'] != null ? List<int>.from(j['hand']) : null,
    );
  }
}

/// 事件（用于飘字提示）
class GameEventMsg {
  final String type;
  final Map<String, dynamic> data;
  GameEventMsg(this.type, this.data);
  String describe() {
    switch (type) {
      case 'discard':
        return '${data['seat']} 打出 ${tileName(data['tile'] as int)}';
      case 'peng':
        return '碰 ${tileName(data['tile'] as int)}';
      case 'minggang':
        return '明杠 ${tileName(data['tile'] as int)}';
      case 'zimo':
        return '自摸 ${tileName(data['tile'] as int)}！${data['base']} 分';
      case 'dianpao':
        return '点炮 ${tileName(data['tile'] as int)}！${data['base']} 分';
      case 'gang_pay':
        return '${data['label']}：${data['detail']}';
      case 'chadajiao':
        return '🔎 查大叫：有玩家未听，赔 ${data['amount']} 分';
      case 'huazhu':
        return '🐷 ${data['name']} 花猪（三门俱全）· 赔 16×家数';
      case 'dice_exchange':
        return '🎲 ${data['d1']} + ${data['d2']} · 与${data['direction']}换三张';
      case 'dice_draw':
        return '🎲 ${data['d3']} + ${data['d4']} · 从${data['startSide']}起牌';
      case 'liuju':
        return '流局';
      default:
        return type;
    }
  }
}

/// 待回应请求
class AskClaim {
  final int tile;
  final List<String> options;
  AskClaim(this.tile, this.options);
}

class NetClient {
  WebSocketChannel? _channel;
  final _viewCtrl = StreamController<OnlineView>.broadcast();
  final _eventCtrl = StreamController<GameEventMsg>.broadcast();
  final _askCtrl = StreamController<AskClaim>.broadcast();
  final _systemCtrl = StreamController<Map<String, dynamic>>.broadcast();
  int mySeat = 0;
  bool connected = false;

  Stream<OnlineView> get views => _viewCtrl.stream;
  Stream<GameEventMsg> get events => _eventCtrl.stream;
  Stream<AskClaim> get asks => _askCtrl.stream;
  Stream<Map<String, dynamic>> get system => _systemCtrl.stream;

  String? lastUrl;
  String? roomId;

  Future<void> connect(String url) async {
    lastUrl = url;
    _channel = WebSocketChannel.connect(Uri.parse(url));
    await _channel!.ready;
    connected = true;
    _channel!.stream.listen((data) {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'joined':
          mySeat = msg['seat'] as int;
          _systemCtrl.add(msg);
          break;
        case 'state':
          _viewCtrl.add(OnlineView.fromJson(
              msg['view'] as Map<String, dynamic>, mySeat));
          break;
        case 'ask_claim':
          _askCtrl.add(AskClaim(msg['tile'] as int,
              List<String>.from(msg['options'] as List)));
          break;
        case 'event':
          _eventCtrl.add(GameEventMsg(
              msg['event']['type'] as String,
              Map<String, dynamic>.from(msg['event'] as Map)));
          break;
        case 'your_turn':
          _systemCtrl.add(msg);
          break;
        default:
          _systemCtrl.add(msg);
      }
    }, onDone: () {
      connected = false;
      _systemCtrl.add({'type': 'disconnected'});
    });
  }

  void send(Map<String, dynamic> msg) {
    if (connected) _channel!.sink.add(jsonEncode(msg));
  }

  void quickMatch(String name) => send({'type': 'quick_match', 'name': name});
  void createRoom(String name) => send({'type': 'create_room', 'name': name});
  void joinRoom(String roomId, String name) =>
      send({'type': 'join_room', 'roomId': roomId, 'name': name});

  /// 断线重连：连回服务器并找回原座位
  Future<bool> rejoinRoom(String roomId, String name) async {
    if (lastUrl == null) return false;
    try {
      await connect(lastUrl!);
      send({'type': 'rejoin_room', 'roomId': roomId, 'name': name});
      return true;
    } catch (_) {
      return false;
    }
  }
  void dingque(int suit) => send({'type': 'dingque', 'suit': suit});
  void exchange(List<int> tiles) =>
      send({'type': 'exchange', 'tiles': tiles});
  void discard(int tile) => send({'type': 'discard', 'tile': tile});
  void claim(String action) => send({'type': 'claim', 'action': action});
  void zimo() => send({'type': 'zimo'});
  void passZimo() => send({'type': 'pass_zimo'});
  void gang(int tile, String gtype) =>
      send({'type': 'gang', 'tile': tile, 'gtype': gtype});

  void dispose() {
    _channel?.sink.close();
    _viewCtrl.close();
    _eventCtrl.close();
    _askCtrl.close();
    _systemCtrl.close();
  }
}

/// 生成随机昵称
String randomName() {
  const adjectives = ['快乐的', '稳重的', '神秘的', '勇猛的', '悠闲的'];
  const animals = ['熊猫', '火锅', '盖碗茶', '蜀锦', '变脸师'];
  final r = Random();
  return '${adjectives[r.nextInt(adjectives.length)]}${animals[r.nextInt(animals.length)]}';
}
