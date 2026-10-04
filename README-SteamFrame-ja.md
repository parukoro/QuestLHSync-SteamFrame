# QuestLHSync — Steam Frame向けカスタマイズ

Windows PCからSteam Frameへ配信し、LighthouseトラッカーやIndexコントローラーの座標をFrameの座標へ合わせる構成です。
元リポジトリにはSteam Frame対応がすでにあります。本版はその処理を維持し、導入と配布をSteam Frame向けに整えています。

## この版の変更

- Windows用のインストール・接続確認・登録解除ツール。Python不要。
- IPアドレス指定、設定のバックアップ、SteamVR起動中の変更防止。
- Frame上の読み取り専用診断 `doctor.sh` とインストール前の校正ファイル確認。
- `--no-restart` によるFrame側SteamVRの再起動延期。
- Quest用Magiskモジュール、Android NDK、Fridaを要求しない配布ビルド。

カメラ取得と座標推定のアルゴリズムは上流版のものです。Steam Frame単体でのゲーム利用や、Linux PC用の補正ドライバーは対象外です。

## 必要なもの

- Windows PC、SteamVR、Steam Frame。両方を同じLANへ接続。
- SteamVR 2.0ベースステーション。1.0には対応しません。
- LighthouseトラッカーまたはIndexコントローラーと、PC側の対応レシーバー。
- 最初の位置合わせは、通常2台以上のベースステーションを見渡せる配置で行ってください。

## 1. PCへインストール

1. 配布ZIPを、例えば `C:\VR\QuestLHSync-SteamFrame` へ展開。登録後はフォルダーを移動しないでください。
2. SteamVRを一度起動してから終了。
3. `install-pc.cmd` を実行。

IPアドレスを固定したい場合は、展開先のターミナルで次を実行します（IPは例です）。

```bat
install-pc.cmd 192.168.1.50
```

既存の `steamvr.vrsettings` は日時付きでバックアップされます。既存の他の設定項目は保持されます。
複数ヘッドセットから選ぶ場合はPowerShellで次を実行できます。

```powershell
.\setup.ps1 -Action Install -FrameHost 192.168.1.50 -HeadsetSerial YOUR_FRAME_SERIAL
```

自動探索へ戻すには `-FrameHost ''`、シリアル指定を解除するには `-HeadsetSerial ''` を明示します。
ソース版から実行する場合は `pc\setup.ps1` を使います。先にビルドが必要です。

## 2. Frameへインストール

ZIPに入っている `QuestLHSync-frame-v*.tar.gz` をFrameへコピーします。
Desktop Modeからのダウンロードでも構いません。SSHを使う場合はValveの公式手順で開発者モードを有効にし、設定したパスワードを使って `steamos@frame` へ接続します。

Frame上のターミナルで、ファイル名のバージョンを実際のものに置き換えて実行します。

```sh
tar xzf QuestLHSync-frame-vVERSION.tar.gz
./QuestLHSync-frame/install.sh
```

rootやMagiskは不要です。ユーザー領域にインストールされます。
動作中のFrame側SteamVRは一度再起動するため、プレイ中は実行しないでください。
再起動を後回しにする場合は `./QuestLHSync-frame/install.sh --no-restart` を使い、その後Frame上で `systemctl --user restart steamvr.service` を実行してください。

## 3. 動作確認

1. SpaceCalibrator、OpenVR-SpaceSyncなど同じ機器を補正するツールを停止。
2. FrameからWindows PCへVR配信を開始し、トラッカーを起動。
3. ヘッドセットを装着し、両方のベースステーションを視野に入れながら、頭と体をゆっくり動かします。静止したままの観測は位置合わせに使われません。
4. SteamVRダッシュボードのQuestLHSync画面で接続・カメラフレーム・位置合わせを確認。

PC側の接続確認:

```bat
status-pc.cmd 192.168.1.50
```

これはTCP 47280とSteam Frameという応答を確認します。成功してもカメラ取得・トラッカーの位置精度の保証にはなりません。
TCP接続中は仕様により一時的にカメラ取得が始まる場合があります。画像や校正データはこのツールでは読み取りません。

Frame側の診断:

```sh
./QuestLHSync-frame/doctor.sh
```

校正ファイル、インストール済みファイル、サービス、最近のログを表示します。
「No camera frames」の場合はFrameを装着し、Frame側のSteamVRがドライバーを読み込んでいるか確認してください。
検出できない場合はPCからIPを指定し、LAN内のTCP 47280、UDP 47281の通信、AP isolationを確認してください。

`seen not yet` は、位置合わせが未確定の場合にも表示されます。まずCamerasとBright spotsを確認してください。
`Pose timing: 18.0 ms (learning)` は初期値で、位置合わせが成立するまで学習が進まない場合があります。
学習前は毎秒20度を超える頭の回転が位置合わせから除外されるため、急に振り向かず、ゆっくり動いてください。
必要ならRecord sessionで記録できます。記録や校正ファイルには機器情報と動きの情報が含まれるため、公開リポジトリには入れないでください。

## アンインストール

PC: SteamVRを終了して `uninstall-pc.cmd` を実行。保存した位置合わせと設定は残します。

Frame: `./QuestLHSync-frame/uninstall.sh` を実行し、SteamVRを再起動。

## ソースからビルド

WindowsにVisual Studio 2022のC++ビルド環境、Python 3、Zigを用意し、次を実行します。

```bat
build_frame.bat
```

ZigをPATHへ追加するか `ZIG` 環境変数で実行ファイルを指定してください。
`out/QuestLHSync-SteamFrame-*.zip` にWindows用ドライバー、Frame用パッケージ、導入ツール、説明書が生成されます。
Android NDK、Magisk、Fridaのビルドは不要です。

## 検証範囲と注意点

実機での確認状況は同梱の `VALIDATION-ja.md` を参照してください。
SteamOS更新によって上流版のカメラ内部仕様への依存が動かなくなる可能性があります。
デーモンは認証なしでLAN内から接続できます。信頼できるLANで使用してください。

上流: https://github.com/CreoleVR/QuestLHSync
Valve公式SSH/開発手順: https://partner.steamgames.com/doc/steamhardware/steamframe/debugging
ライセンスと第三者通知は同梱ファイルを参照してください。Steam Frame対応は上流の@NotZoeyDevによるものです。
