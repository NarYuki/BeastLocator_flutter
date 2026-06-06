import 'package:flutter/widgets.dart';

String beastText(BuildContext context, String japanese) {
  final locale = Localizations.localeOf(context);
  final language = locale.languageCode;
  if (language == 'en') return _english[japanese] ?? japanese;
  if (language == 'zh') return _simplifiedChinese[japanese] ?? japanese;
  return japanese;
}

const _english = <String, String>{
  '設定': 'Settings',
  '通知表示やウィジェット設定を調整できます': 'Adjust notification display and widget settings',
  '現在の目的地': 'Current Destination',
  '野獣邸の座標です。この目的地を案内します':
      'These are the Beast House coordinates. The app will guide you here.',
  '初期値': 'Default',
  'デバッグ上書き中': 'Debug override active',
  'コンパス': 'Compass',
  '方位表示に関する設定': 'Settings for direction display',
  'コンパスを従来方式にする': 'Use legacy compass mode',
  'コンパスの測定方式を従来の方式にします\nコンパスの動作が不安定な場合にお試しください':
      'Uses the legacy compass measurement method.\n'
      'Try this if the compass is behaving unstable.',
  '野獣先輩の動きを平滑化': "Smooth Yajuu Senpai's movements",
  'ONにすることで、野獣先輩の動きを多少滑らかにすることができます':
      "Enabling this makes Yajuu Senpai's movements slightly smoother.",
  'ウィジェット設定': 'Widget Settings',
  'ウィジェットの方位表示': 'Widget orientation display',
  '絶対方位（北基準）': 'Absolute (North-based)',
  '相対方位（端末の向き基準）': 'Relative (Device-based)',
  '身バレ防止機能': 'Privacy Guard',
  '位置の特定につながる項目に関する設定':
      'Settings to prevent identity revealing from location data',
  '身バレ防止ボタンを表示': 'Show Privacy Mask Button',
  'メイン画面右上に、距離や方角に関する表示を大雑把な表示に切り替えるボタンを表示します':
      'Shows a button on the top right of the main screen to blur distance and direction info.',
  '身バレ防止警告を表示': 'Show Privacy Warning',
  'リスクを忘れないために、スクリーンショットを検知した際に特定リスクがある旨の警告を表示します':
      'Shows a warning about identification risks when a screenshot is detected.',
  'バックグラウンド更新': 'Background Updates',
  'バックグラウンド動作に関する設定': 'Settings for background operation',
  'バックグラウンドで位置を更新': 'Update location in background',
  'バックグラウンドアプリとして動作して位置を更新するため、通知が来やすくなります':
      'Updating location as a background app helps you receive notifications more reliably.',
  '通知': 'Notifications',
  '目的地に近づいた際の通知': 'Notifications when approaching the destination',
  '到達時に通知を表示': 'Show Notification on Arrival',
  '50m以内まで到達した際に、目的地に到着した旨を通知で送信します':
      'Sends a notification when you are within 50m of the destination.',
  '到達進捗を通知で表示': 'Show Progress via Notifications',
  '目的地から一定の距離まで近づくと、ライブアップデートにより進捗を通知で知らせます':
      'Provides live updates on progress once you reach a certain distance from the destination.',
  '進捗表示を開始する距離': 'Progress Start Distance',
  '実験的機能': 'Experimental Features',
  '将来的に追加される機能の設定': 'Settings for upcoming features',
  '実験的機能の設定を開く': 'Open Experimental Settings',
  'このアプリについて': 'About This App',
  'アプリ情報とオープンソースライセンスを表示します': 'View app information and OSS licenses',
  '表示する': 'View',
  '言語設定': 'Language Settings',
  'ローカライズの設定': 'Localization settings',
  '日本語以外の言語も使用可能にする': 'Enable languages other than Japanese',
  '現在は簡体中国語、英語に対応しています': 'Currently supports Simplified Chinese and English.',
  '言語設定に進む': 'Go to Language Settings',
  '将来的に追加される機能です': 'Features planned for future release.',
  'サウンド再生 (実験的)': 'Sound Playback (Experimental)',
  'いずれかをONにすると、位置情報を常に監視するようになるためバッテリーの減りが早くなる可能性があります':
      'Enabling any of these will continuously monitor location, which may increase battery drain.',
  '到着時のこ↑こ↓サウンド': 'Arrival Sound: "Koko"',
  '目的地まで50m以内に入った際に こ↑こ↓ と音声が流れます':
      'Plays "Koko (Right Here)" voice when within 50m of the destination.',
  '114.514kmで呼び込み先輩を再生': 'Play Barker Senpai at 114.514km',
  '距離が114.514kmに到達した際に呼び込み先輩の音楽を再生します\n⚠️この音楽は一時停止できないため、公共の場で鳴らないよう注意してください':
      'Plays Barker Senpai music when the distance reaches 114.514km.\n'
      '⚠️ Note: This music cannot be paused; use caution in public.',
  '元動画を開く': 'Open Original Video',
  '一定間隔ごとに咆哮を再生': 'Play Roar at Regular Intervals',
  '目的地まで一定の距離近づくたびに野獣の咆哮を再生します\n⚠️この音声は一時停止できないため、公共の場で鳴らないよう注意してください':
      'Plays a roar sound every time you get closer to the destination by a set interval.\n'
      '⚠️ Note: This audio cannot be paused; use caution in public.',
  '再生する間隔': 'Playback Interval',
};

const _simplifiedChinese = <String, String>{
  '設定': '设置',
  '通知表示やウィジェット設定を調整できます': '调整通知显示和小组件设置',
  '現在の目的地': '现在的目的地',
  '野獣邸の座標です。この目的地を案内します': '这是野兽邸的坐标，应用将引导您前往此处',
  '初期値': '默认值',
  'デバッグ上書き中': '调试覆盖中',
  'コンパス': '方向指引',
  '方位表示に関する設定': '关于方向显示的设置',
  'コンパスを従来方式にする': '使用旧版指南针模式',
  'コンパスの測定方式を従来の方式にします\nコンパスの動作が不安定な場合にお試しください':
      '使用旧版指南针测量方式\n若指南针运行不稳定，请尝试开启此选项。',
  '野獣先輩の動きを平滑化': '平滑野兽先辈的动作',
  'ONにすることで、野獣先輩の動きを多少滑らかにすることができます': '开启后，可以使野兽先辈的动作更加平滑',
  'ウィジェット設定': '小组件设置',
  'ウィジェットの方位表示': '小组件方位显示',
  '絶対方位（北基準）': '绝对方位（以北为基准）',
  '相対方位（端末の向き基準）': '相对方位（以设备朝向为基准）',
  '身バレ防止機能': '隐私保护（防开盒）',
  '位置の特定につながる項目に関する設定': '与位置泄露相关的设置',
  '身バレ防止ボタンを表示': '显示隐私屏蔽按钮',
  'メイン画面右上に、距離や方角に関する表示を大雑把な表示に切り替えるボタンを表示します':
      '在主界面右上角显示一个按钮，可将距离和方位信息切换为模糊显示',
  '身バレ防止警告を表示': '显示隐私警告',
  'リスクを忘れないために、スクリーンショットを検知した際に特定リスクがある旨の警告を表示します': '检测到屏幕截图时显示风险警告，以免忘记特定风险',
  'バックグラウンド更新': '后台更新',
  'バックグラウンド動作に関する設定': '关于后台运行的相关设置',
  'バックグラウンドで位置を更新': '在后台更新位置',
  'バックグラウンドアプリとして動作して位置を更新するため、通知が来やすくなります': '通过作为后台应用运行来更新位置，使通知更易于送达',
  '通知': '通知',
  '目的地に近づいた際の通知': '靠近目的地时的通知',
  '到達時に通知を表示': '到达时显示通知',
  '50m以内まで到達した際に、目的地に到着した旨を通知で送信します': '当距离目的地50米以内时，发送到达通知',
  '到達進捗を通知で表示': '在通知中显示进度',
  '目的地から一定の距離まで近づくと、ライブアップデートにより進捗を通知で知らせます': '距离目的地一定范围内时，通过实时更新通知进度',
  '進捗表示を開始する距離': '开始显示进度距离',
  '実験的機能': '实验性功能',
  '将来的に追加される機能の設定': '未来将加入的功能设置',
  '実験的機能の設定を開く': '打开实验性功能设置',
  'このアプリについて': '关于本应用',
  'アプリ情報とオープンソースライセンスを表示します': '显示应用信息和开源许可',
  '表示する': '显示',
  '言語設定': '语言设置',
  'ローカライズの設定': '本地化相关设置',
  '日本語以外の言語も使用可能にする': '启用日语以外的语言',
  '現在は簡体中国語、英語に対応しています': '目前支持简体中文和英语。',
  '言語設定に進む': '前往语言设置',
  '将来的に追加される機能です': '这些是未来计划加入的功能',
  'サウンド再生 (実験的)': '声音播放 (实验性)',
  'いずれかをONにすると、位置情報を常に監視するようになるためバッテリーの減りが早くなる可能性があります':
      '开启任一选项后，应用将持续监控位置，可能会加快耗电速度',
  '到着時のこ↑こ↓サウンド': '到达时播放“こ↑こ↓”声音',
  '目的地まで50m以内に入った際に こ↑こ↓ と音声が流れます': '到达50米范围内时播放“こ↑こ↓”音效',
  '114.514kmで呼び込み先輩を再生': '距离114.514km时播放“先辈の小曲”',
  '距離が114.514kmに到達した際に呼び込み先輩の音楽を再生します\n⚠️この音楽は一時停止できないため、公共の場で鳴らないよう注意してください':
      '当距离达到114.514km时播放“先辈の小曲”\n⚠️注意：此音频无法暂停，请注意公共场合',
  '元動画を開く': '打开原视频',
  '一定間隔ごとに咆哮を再生': '定距播放“野兽咆哮”',
  '目的地まで一定の距離近づくたびに野獣の咆哮を再生します\n⚠️この音声は一時停止できないため、公共の場で鳴らないよう注意してください':
      '每靠近目的地固定距离时播放“野兽咆哮”音效\n⚠️注意：此音频无法暂停，请注意公共场合',
  '再生する間隔': '播放间隔',
};
