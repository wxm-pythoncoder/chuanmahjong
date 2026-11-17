# 川麻血战到底

Flutter + Node.js 的四川麻将（血战到底）游戏。支持单机（3 个机器人）与真人联机。

## 项目结构

```
chuanmahjong/
├── client/          # Flutter 客户端（iOS / Android / Web）
│   └── lib/
│       ├── game/    # Dart 版规则引擎（单机模式用）
│       │   ├── tiles.dart      # 牌定义
│       │   ├── win.dart        # 胡牌/听牌/缺一门判定
│       │   ├── scoring.dart    # 番数计分
│       │   ├── table.dart      # 牌桌状态机
│       │   └── bot.dart        # Bot AI
│       └── main.dart           # 界面
├── server/          # Node.js 联机服务器（权威规则引擎）
│   └── src/game/
│       ├── tiles.js / win.js / scoring.js / table.js
└── codemagic.yaml   # 云端构建配置（iOS ipa / Android apk）
```

## 本地开发

```bash
# 服务器
cd server && npm install && npm start          # ws://127.0.0.1:8080
node --test                                    # 规则引擎测试

# 客户端（Web 预览）
cd client && flutter pub get
flutter run -d chrome
flutter test                                   # Dart 引擎测试
```

## 安装到 iPhone（无 Mac / 无开发者账号）

1. 代码推到 GitHub，在 [codemagic.io](https://codemagic.io) 导入仓库
2. 运行 `ios-sideload` workflow，得到未签名 ipa
3. 用 [Sideloadly](https://sideloadly.io) + 你的 Apple ID 把 ipa 装进 iPhone
   - 免费 Apple ID 签名 7 天有效，到期用数据线重签
   - ¥688/年 开发者账号可 TestFlight 长期安装

## 规则要点（成都血战到底）

- 只有万/条/筒三门共 108 张，无风牌花牌
- 定缺后必须先打完缺门的牌
- 无吃，只有碰 / 明杠 / 暗杠 / 补杠
- 有人胡牌后其他人继续打（血战到底），直到 3 家胡或流局
- 自摸：其余未胡家各付；点炮：炮家独付
- **自摸加一翻**（自摸/杠上花均 +1），点炮胡不加
- **杠上炮**：杠后摸牌打出的牌点炮 → 点炮分加一翻
- **四番封顶**：总番超过 4 番按 4 番计（最高 16 分）
- **刮风下雨**：点杠（直杠）2 分、暗杠 2×3、补杠 1×3，即时结算
- **流局查大叫**：未听者赔给听牌者其最大听牌型的自摸分
- **查花猪**：流局时手里三门俱全的未听者（花猪）赔其他未胡家各 16 分
- 番型：对对胡 ×2、清一色 ×4、七对 ×4、龙七对、金钩钓、根（每根 ×2）、杠上花、杠上炮、抢杠、天胡/地胡

## 路线图

- [x] 阶段 1：规则引擎（JS 服务端 + Dart 客户端）
- [ ] 阶段 2：Flutter 界面 + 单机模式
- [ ] 阶段 3：WebSocket 联机（房间 / 匹配 / 掉线重连）
- [ ] 阶段 4：云端打包 + 侧载 iPhone
