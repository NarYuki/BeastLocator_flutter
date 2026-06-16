import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/settings_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BeastSettingsScaffold(
      title: 'このアプリについて',
      children: [
        SettingsCard(
          title: 'BeastLocator',
          subtitle: 'Version 0.9.5-flutter',
          children: [
            Center(child: Image.asset('assets/images/icon.png', height: 96)),
            const BodyText(
              'このアプリは、個人的に制作したファンメイドアプリです。'
              'コートコーポレーション本社周辺での迷惑行為を推奨、および助長するものではありません。',
            ),
          ],
        ),
        SettingsCard(
          title: 'サポート',
          subtitle: '関連リンク',
          children: [
            FullWidthButton(
              icon: Icons.public,
              label: 'サポートサイトを開く',
              outlined: true,
              onPressed: () => launchUrl(Uri.parse('https://linkserver.jp/')),
            ),
            FullWidthButton(
              icon: Icons.open_in_new,
              label: 'X (Twitter) を開く',
              outlined: true,
              onPressed: () => launchUrl(Uri.parse('https://x.com/Link_2011A')),
            ),
          ],
        ),
        SettingsCard(
          title: 'オープンソースライセンス',
          subtitle: '利用ライブラリ',
          children: [
            const BodyText('利用しているパッケージのライセンスを一覧で表示できます。'),
            FullWidthButton(
              icon: Icons.article,
              label: 'ライセンス一覧を表示',
              outlined: true,
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'BeastLocator',
                applicationVersion: '0.9.5-flutter',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset('assets/images/icon.png', height: 72),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
