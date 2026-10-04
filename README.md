# QuestLHSync — Steam Frame Edition

Windows PC＋Steam Frame向けに、導入ツールと日本語手順を追加したQuestLHSyncのForkです。
LighthouseトラッカーやIndexコントローラーの座標を、Steam Frameのトラッキング座標へ合わせます。

**[配布ZIPをダウンロード](https://github.com/parukoro/QuestLHSync-SteamFrame/releases/latest)** ·
**[日本語の導入手順](README-SteamFrame-ja.md)** · [検証状況](VALIDATION-ja.md)

## 必要な構成

- Windows PCとSteamVR、Steam Frame。同じLANに接続。
- SteamVR 2.0ベースステーションと、対応レシーバーでPCに接続したLighthouseトラッカーまたはIndexコントローラー。
- PCからFrameへのVR配信。Steam Frame単体での利用は対象外です。

## 導入

1. Releasesから `QuestLHSync-SteamFrame-1.7.zip` をダウンロードし、固定のフォルダーへ展開。
2. PCのSteamVRを終了し、`install-pc.cmd` を実行。既存設定はバックアップされます。
3. 同梱の `QuestLHSync-frame-v1.7.tar.gz` をFrameへコピーし、Frameのターミナルで実行。

```sh
tar xzf QuestLHSync-frame-v1.7.tar.gz
./QuestLHSync-frame/install.sh
```

4. 他の座標補正ツールを停止し、VR配信とトラッカーを起動。ヘッドセットを装着し、ベースステーションを見渡しながらゆっくり頭と体を動かします。

Frame側インストールはユーザー領域で動作し、rootやMagiskは不要です。実行時にFrame側SteamVRが再起動します。
SSHでのコピー方法、IP指定、接続確認、削除手順は[日本語手順](README-SteamFrame-ja.md)を参照してください。

## このForkの変更

- Python不要のWindows導入・接続確認・登録解除ツール。
- IP・ヘッドセットシリアル指定と、SteamVR設定のバックアップ。
- Frame側の診断、校正ファイルの事前確認、SteamVR再起動の延期。
- Quest用Magiskモジュール・Android NDK・Fridaを要求しないSteam Frame向け配布ビルド。

上流1.7の動作中の水平補正・動きによる鏡像判定を取り込み、遮蔽時の安定性対策を追加しています。
- 最近5秒に2台のステーションを複数の位置から観測でき、推定が十分に決まる場合だけ通常の座標補正を更新。片方が隠れた場合は直前の補正を保持します。
- 現在の位置合わせを再認識の候補に追加。
- 鏡像判定でも通常の観測数を要求し、少ない観測での大きな切り替えを抑制。

この安定性対策は実機評価前の試験版です。初回認識時間の短縮や頭部トラッカーと同等の精度は未確認です。
ユーザーからWindows PC＋Steam Frameでの問題解決報告を受けていますが、精度・遅延・長時間動作は開発側では未測定です。
デーモンへの接続には認証がありません。信頼できるLANで使用してください。

## ビルド

Visual Studio 2022のC++ビルド環境、Python 3、Zig（検証版0.14.1）を用意し、次を実行します。

```bat
build_frame.bat
```

配布ZIPは `out/` に生成されます。ソルバーの回帰テストは `tests\run_solver_tests.bat` で実行します。テストは `python -m unittest discover -s tests -v` で実行できます。

## Credits and license

Based on [CreoleVR/QuestLHSync](https://github.com/CreoleVR/QuestLHSync), upstream version 1.7,
commit `9e44796f875d21ab75c3239b47f7633a032747ae`.
Steam Frame support was contributed upstream by [@NotZoeyDev](https://github.com/NotZoeyDev).
This fork adds distribution tools and experimental occlusion stability changes; it is not an official Valve or upstream release.

MIT license: [LICENSE](LICENSE). Third-party components: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
The original README is preserved in [README-upstream.md](README-upstream.md).
