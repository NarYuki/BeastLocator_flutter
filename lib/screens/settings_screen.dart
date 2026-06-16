import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../services/app_store.dart';
import '../utils/geo_utils.dart';
import '../widgets/settings_widgets.dart';
import 'about_screen.dart';
import 'experimental_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppStore get store => widget.store;

  String _formatMeters(int meters) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '$meters m';
  }

  @override
  Widget build(BuildContext context) {
    final destination = store.destination;
    return BeastSettingsScaffold(
      title: '設定',
      subtitle: '通知表示やウィジェット設定を調整できます',
      children: [
        SettingsCard(
          title: '現在の目的地',
          subtitle: '野獣邸の座標です。この目的地を案内します',
          children: [
            BodyText(
              '緯度 ${destination.lat.toStringAsFixed(6)} / 経度 ${destination.lng.toStringAsFixed(6)}',
              monospace: true,
            ),
            BodyText(store.isDestinationOverrideEnabled ? 'デバッグ上書き中' : '初期値'),
          ],
        ),
        SettingsCard(
          title: 'コンパス',
          subtitle: '方位表示に関する設定',
          children: [
            SettingSwitchRow(
              title: 'コンパスを従来方式にする',
              subtitle:
                  'コンパスの測定方式を従来の方式にします\n'
                  'コンパスの動作が不安定な場合にお試しください',
              value: store.legacyCompassModeEnabled,
              onChanged: (value) async {
                await store.setLegacyCompassModeEnabled(value);
                setState(() {});
              },
            ),
            SettingSwitchRow(
              title: '野獣先輩の動きを平滑化',
              subtitle: 'ONにすると矢印の動きが滑らかになります',
              value: store.compassSmoothingEnabled,
              onChanged: (value) async {
                await store.setCompassSmoothingEnabled(value);
                setState(() {});
              },
            ),
          ],
        ),
        SettingsCard(
          title: 'ウィジェット設定',
          subtitle: 'ホーム画面ウィジェットの方位表示',
          children: [
            RadioOption(
              title: '絶対方位（北基準）',
              subtitle: '',
              value: 'absolute',
              groupValue: store.widgetBearingMode,
              onChanged: _setWidgetBearingMode,
            ),
            RadioOption(
              title: '相対方位（端末の向き基準）',
              subtitle: '',
              value: 'relative',
              groupValue: store.widgetBearingMode,
              onChanged: _setWidgetBearingMode,
            ),
          ],
        ),
        SettingsCard(
          title: '身バレ防止機能',
          subtitle: '位置の特定につながる項目に関する設定',
          children: [
            SettingSwitchRow(
              title: '身バレ防止ボタンを表示',
              subtitle:
                  'メイン画面右上に、距離や方角に関する表示を'
                  '大雑把な表示に切り替えるボタンを表示します',
              value: store.distanceMaskButtonVisible,
              onChanged: (value) async {
                await store.setDistanceMaskButtonVisible(value);
                if (!value) await store.setManualDistanceMaskEnabled(false);
                setState(() {});
              },
            ),
            SettingSwitchRow(
              title: '身バレ防止警告を表示',
              subtitle:
                  'リスクを忘れないために、スクリーンショットを検知した際に'
                  '特定リスクがある旨の警告を表示します',
              value: store.screenshotWarningEnabled,
              onChanged: (value) async {
                await store.setScreenshotWarningEnabled(value);
                setState(() {});
              },
            ),
          ],
        ),
        SettingsCard(
          title: 'バックグラウンド更新',
          subtitle: 'バックグラウンド動作に関する設定',
          children: [
            SettingSwitchRow(
              title: 'バックグラウンドで位置を更新',
              subtitle:
                  'バックグラウンドアプリとして動作して位置を更新するため、'
                  '通知が来やすくなります',
              value: store.backgroundLocationUpdateEnabled,
              onChanged: (value) async {
                await store.setBackgroundLocationUpdateEnabled(value);
                setState(() {});
              },
            ),
          ],
        ),
        SettingsCard(
          title: '通知',
          subtitle: '目的地に近づいた際の通知',
          children: [
            SettingSwitchRow(
              title: '到達時に通知を表示',
              subtitle: '50m以内まで到達した際に、目的地に到着した旨を通知で送信します',
              value: store.arrivalNotificationEnabled,
              onChanged: (value) async {
                await store.setArrivalNotificationEnabled(value);
                setState(() {});
              },
            ),
            SettingSwitchRow(
              title: '到達進捗を通知で表示',
              subtitle:
                  '目的地から一定の距離まで近づくと、'
                  'ライブアップデートにより進捗を通知で知らせます',
              value: store.liveUpdateEnabled,
              onChanged: (value) async {
                await store.setLiveUpdateEnabled(value);
                setState(() {});
              },
            ),
            SettingSliderRow(
              title: '進捗表示を開始する距離',
              valueLabel: _formatMeters(store.liveUpdateStartDistanceMeters),
              value: store.liveUpdateStartDistanceMeters.toDouble(),
              min: 200,
              max: 5000,
              divisions: 48,
              enabled: store.liveUpdateEnabled,
              onChanged: (value) async {
                await store.setLiveUpdateStartDistanceMeters(value.round());
                setState(() {});
              },
            ),
          ],
        ),
        SettingsCard(
          title: '実験的機能',
          subtitle: '将来的に追加される機能の設定',
          children: [
            FullWidthButton(
              icon: Icons.science,
              label: '実験的機能の設定を開く',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ExperimentalSettingsScreen(store: store),
                  ),
                );
                setState(() {});
              },
            ),
          ],
        ),
        SettingsCard(
          title: 'このアプリについて',
          subtitle: 'アプリ情報とオープンソースライセンスを表示します',
          children: [
            FullWidthButton(
              icon: Icons.info,
              label: '表示する',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
        SettingsCard(
          title: 'バージョン',
          subtitle: 'BeastLocator / Version 0.9.5-flutter',
          children: [
            FullWidthButton(
              icon: Icons.bug_report,
              label: store.debugMenuVisible ? 'デバッグメニューを非表示' : 'デバッグメニューを表示',
              tonal: true,
              onPressed: () async {
                await store.setDebugMenuVisible(!store.debugMenuVisible);
                setState(() {});
              },
            ),
          ],
        ),
        if (store.debugMenuVisible) ...[
          SettingsCard(
            title: 'デバッグ',
            subtitle: '目的地や現在距離を上書きします',
            children: [
              FullWidthButton(
                icon: Icons.flag,
                label: '現在のセッションを到達とする',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await store.setDestinationAnswered(true);
                  await store.setArrivalName(
                    '${store.destination.lat.toStringAsFixed(6)}, ${store.destination.lng.toStringAsFixed(6)}',
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('現在のセッションを到達にしました')),
                    );
                  }
                },
              ),
              FullWidthButton(
                icon: Icons.speed,
                label: '目的地までの距離を書き換え',
                outlined: true,
                onPressed: _showDebugDistanceDialog,
              ),
              FullWidthButton(
                icon: Icons.refresh,
                label: '目的地までの距離をリセット',
                outlined: true,
                onPressed: () async {
                  await store.clearDebugDistanceOverride();
                  setState(() {});
                },
              ),
              FullWidthButton(
                icon: Icons.edit_location,
                label: '目的地座標を編集',
                outlined: true,
                onPressed: _showDestinationDialog,
              ),
              FullWidthButton(
                icon: Icons.home,
                label: '目的地を初期値に戻す',
                outlined: true,
                onPressed: () async {
                  await store.clearDestinationOverride();
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _setWidgetBearingMode(String value) async {
    await store.setWidgetBearingMode(value);
    setState(() {});
  }

  Future<void> _showDebugDistanceDialog() async {
    final controller = TextEditingController();
    final meters = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目的地までの距離を書き換え'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '例: 1000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(context, value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (meters == null || meters < 0 || meters > 20000000) return;
    final fakeLocation = GeoUtils.destinationAt(store.destination, meters, 180);
    await store.setDebugDistanceOverride(fakeLocation);
    setState(() {});
  }

  Future<void> _showDestinationDialog() async {
    final target = store.destination;
    final latController = TextEditingController(
      text: target.lat.toStringAsFixed(6),
    );
    final lngController = TextEditingController(
      text: target.lng.toStringAsFixed(6),
    );
    final destination = await showDialog<Destination>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目的地を編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: '緯度'),
            ),
            TextField(
              controller: lngController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: '経度'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latController.text.trim());
              final lng = double.tryParse(lngController.text.trim());
              if (lat == null || lng == null) {
                Navigator.pop(context);
              } else {
                Navigator.pop(context, Destination(lat, lng));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (destination == null || !destination.isValid) return;
    await store.setDestinationOverride(destination);
    setState(() {});
  }
}
