import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_store.dart';
import '../widgets/settings_widgets.dart';

class ExperimentalSettingsScreen extends StatefulWidget {
  const ExperimentalSettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ExperimentalSettingsScreen> createState() =>
      _ExperimentalSettingsScreenState();
}

class _ExperimentalSettingsScreenState
    extends State<ExperimentalSettingsScreen> {
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return BeastSettingsScaffold(
      title: '実験的機能',
      subtitle: '将来的に追加される機能です',
      children: [
        SettingsCard(
          title: '言語設定',
          subtitle: 'ローカライズの設定',
          children: [
            SettingSwitchRow(
              title: '日本語以外の言語も使用可能にする',
              subtitle: '現在は簡体中国語、英語に対応しています',
              value: store.nonJapaneseLanguageEnabled,
              onChanged: (value) async {
                await store.setNonJapaneseLanguageEnabled(value);
                setState(() {});
              },
            ),
            FullWidthButton(
              icon: Icons.language,
              label: '言語設定に進む',
              outlined: true,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('端末の言語設定から変更してください')),
                );
              },
            ),
          ],
        ),
        SettingsCard(
          title: 'コンパス',
          subtitle: '方位表示に関する設定',
          children: [
            SettingSwitchRow(
              title: '野獣先輩の動きを平滑化',
              subtitle: 'ONにすることで、野獣先輩の動きを多少滑らかにすることができます',
              value: store.compassSmoothingEnabled,
              onChanged: (value) async {
                await store.setCompassSmoothingEnabled(value);
                setState(() {});
              },
            ),
          ],
        ),
        SettingsCard(
          title: 'サウンド再生 (実験的)',
          subtitle:
              'いずれかをONにすると、位置情報を常に監視するようになるため'
              'バッテリーの減りが早くなる可能性があります',
          children: [
            SettingSwitchRow(
              title: '到着時のこ↑こ↓サウンド',
              subtitle: '目的地まで50m以内に入った際に こ↑こ↓ と音声が流れます',
              value: store.arrivalSoundEnabled,
              onChanged: (value) async {
                await store.setArrivalSoundEnabled(value);
                setState(() {});
              },
            ),
            SettingSwitchRow(
              title: '114.514kmで呼び込み先輩を再生',
              subtitle:
                  '距離が114.514kmに到達した際に呼び込み先輩の音楽を再生します\n'
                  '⚠️この音楽は一時停止できないため、公共の場で鳴らないよう注意してください',
              value: store.distance114514SoundEnabled,
              onChanged: (value) async {
                await store.setDistance114514SoundEnabled(value);
                setState(() {});
              },
            ),
            FullWidthButton(
              icon: Icons.open_in_new,
              label: '元動画を開く',
              outlined: true,
              onPressed: () => launchUrl(
                Uri.parse('https://www.nicovideo.jp/watch/sm33266722'),
              ),
            ),
            SettingSwitchRow(
              title: '一定間隔ごとに咆哮を再生',
              subtitle:
                  '目的地まで一定の距離近づくたびに野獣の咆哮を再生します\n'
                  '⚠️この音声は一時停止できないため、公共の場で鳴らないよう注意してください',
              value: store.distanceIntervalSoundEnabled,
              onChanged: (value) async {
                await store.setDistanceIntervalSoundEnabled(value);
                setState(() {});
              },
            ),
            SettingSliderRow(
              title: '再生する間隔',
              valueLabel: _formatMeters(store.distanceIntervalMeters),
              value: store.distanceIntervalMeters.toDouble(),
              min: 100,
              max: 5000,
              divisions: 49,
              enabled: store.distanceIntervalSoundEnabled,
              onChanged: (value) async {
                await store.setDistanceIntervalMeters(value.round());
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  String _formatMeters(int meters) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '$meters m';
  }
}
