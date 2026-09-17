# RTL静的解析指摘への修正とlint結果

対象: [静的解析報告書](rtl_static_analysis_2026-09-16.md) のF01～F15、および関連するバス・構成・検証準備の不整合。

RTL修正、lint、既存benchを使った自己判定シミュレーションまで実施した。形式検証、合成、STA、専用CDC/RDC解析は実施していない。

## 指摘との対応

| 指摘 | 実施した修正 | 主なファイル |
|---|---|---|
| F01 | FIFO内でpush/popの受理条件を生成し、受理された操作だけでメモリ・ポインタ・個数を更新。RX投入拒否をoverrunイベント化 | `rtl/uart_fifo.sv`, `rtl/fifo_interface.sv`, `rtl/uart_register.sv` |
| F02 | 5bitの要素数でempty/fullを判定。clear最優先、同時push/popでは個数維持 | `rtl/uart_fifo.sv` |
| F03 | `count >= trigger_level` に変更。RDAはマスク付きレベル条件から生成 | `rtl/uart_fifo.sv`, `rtl/uart_register.sv` |
| F04 | FIFOクリアでエラーvalidを全消去。同一スロットの置換では新データのエラーを優先 | `rtl/uart_fifo.sv` |
| F05 | ALIGN_1Bの書き込み値を指定レーンから選択。MCRの読み出しを追加 | `rtl/uart_register.sv` |
| F06 | 全割り込み原因をIERでマスクし、その同じ有効原因からIRQとIIRを生成 | `rtl/uart_register.sv` |
| F07 | 各原因の状態を独立管理し、ベクタ全体のset優先処理を廃止。THRE解除はIIRがTHREを返したときのみ。IER再有効化は書き込み当日に検出 | `rtl/uart_register.sv` |
| F08 | FIFO先頭文字ごとにLSR既読状態を管理。popで既読状態を解除し、同種エラーの連続でも次の文字を通知。空FIFOの出力は0 | `rtl/uart_register.sv`, `rtl/uart_fifo.sv` |
| F09 | RX状態機械から独立したFIFO非空時のタイマーへ変更。RBR読み出し・受信完了・FIFOクリアで再開始。設定形式の4文字分を計測 | `rtl/uart_register.sv` |
| F10 | 状態と実際に出力中のビットを対応させ、最後のstop期間終了までTXをbusyに保持。THREはTX FIFO空から別管理 | `rtl/uart_transmitter.sv`, `rtl/uart_baud.sv`, `rtl/uart_register.sv` |
| F11 | TX/RX共通のパリティ関数でstick parity対応。FEは最初のstop中央の値から判定。BIはPEと独立し、設定フレーム全期間の連続lowを確認 | `rtl/uart_package.sv`, `rtl/uart_receiver.sv` |
| F12 | RXフィルタを毎システムクロックの3点多数決へ変更。最小bit期間16クロックより十分短いフィルタとした | `rtl/uart_noize_shaver.sv` |
| F13 | RXD・modem入力に2段同期器を追加。機能論理は最終段のみ使用。コアresetは非同期assert・2クロック同期deassertへ変更 | `rtl/uart_noize_shaver.sv`, `rtl/uart_register.sv`, `rtl/uart_16550_rll.sv` |
| F14 | modem変化履歴をORで保持し、MSR読み出しと同時の新イベントを優先。RIは端子low→highのみ検出 | `rtl/uart_register.sv` |
| F15 | START中央がhighなら受信中止。連続break中は1文字だけ投入し、highへ戻ってから再待機 | `rtl/uart_receiver.sv` |

F13はRTL構造の修正まで。同期器属性は付与したが、対象デバイスでの認識、配置、MTBF、reset解除のタイミングは今回確認していない。

## 追加修正と維持した仕様

- 文字長5/6/7/8bitとTXの1/1.5/2 stopを扱う。5bitで追加stopを指定した場合が1.5、それ以外が2。RXのFE検査は最初のstop中央で行い、break判定・タイムアウトには設定stop長も含める。
- LCRのフレーム形式とボーレートをフレーム開始時に保持する。ソフトウェアの途中変更で送受信中の文字形式・bit長が変わらないようにした。
- modem loopback中のRTS/DTR外部出力を非アクティブに固定する。
- TX FIFOへの11bitデータを全駆動し、両FIFOインターフェースの公開状態信号も駆動する。
- FIFOは16×11bitの固定仕様に整理し、実装と不整合だったDATA_WIDTH/ADDR_WIDTHパラメータを削除した。
- 合成対象の `#1` を削除した。
- `syn/uart_top.qsf` にALIGN_4Bを追加し、sim既定の配置と一致させた。
- 既存の8bitボーレート設定を維持する。**bit期間は `16*(baud_reg+1)` クロック**で、0は16クロック、255は4096クロック。標準16550の16bit DLL/DLM・divisor値とは異なる。
- DLAB=1のoffset1は予約扱いとし、読み出し0・書き込み無視。未対応のDLMアクセスでIERを破壊しないようにした。
- 常時16byte FIFO、FCR[0]無視、IIR[7:4]=0xCを維持する。非FIFOモードは実装していない。
- 対象基板のI/Oタイミング条件が不明なため、新しいSDCやfalse-path例外は追加していない。旧QSFのクロック制約は現状維持で、実機向けSTA整備は別途必要。

外部の `uart_top` の端子は変更していない。内部のFIFO、baud、RX/TX、codec-stateモジュール間のポートは整理しているため、これらを単独で利用する外部インスタンスがある場合は接続更新が必要。

reset解除後はコア内の同期解除に2クロックを要する。その間はWishbone ACKを返さない。

## シミュレーション結果

`bench/uart_interface_be.sv` のBFMはレジスタ番号を受け取る契約に統一した。ALIGN_4Bではアドレスを4倍し、ALIGN_1Bでは書き込み・読み出しデータを対応バイトレーンへ配置/取り出す。

`sim/uart_test.sv` を自己判定型に更新し、以下をALIGN_4BとALIGN_1Bの双方で確認した。

- 7bit、パリティなし、8文字連続送受信とデータ一致
- 7bit、偶数パリティ、8文字連続送受信、PE/FEなし
- 7bit、奇数パリティ、8文字連続送受信、PE/FEなし
- FIFOトリガ未満の4文字受信後にtimeout IRQとIIR=0xCを確認
- RBRを1文字読むとtimeout IRQが解除され、IIR=0x1になることを確認
- 5bit/1.5 stopのデータ一致、FEなし、連続フレーム開始間隔390 us
- 6bit/2 stopの連続送受信、データ一致、FEなし
- 8bit/2 stopのデータ一致、FEなし、連続フレーム開始間隔572 us
- RX FIFOへ17文字を送信し、先頭16文字が順序どおり保持され、17文字目が破棄されることを確認
- FIFO満杯後のLSR OE/DR、LSR読み出しによるOE解除、16文字読み出し後のDR解除を確認
- 連続breakからBI/FE付きの0x00が1文字だけ格納され、break継続中に重複格納されないことを確認
- CTS/DSR/RI/DCDの同時変化をMSR=0x3Fとして蓄積し、modem IRQの発生とMSR読み出しによる解除を確認
- line-statusとmodemの複数原因を同時に保留し、IIRがline-statusを優先した後、LSRを読んでもmodem原因が失われないことを確認

両構成とも `$error` / `$fatal` なしで `UART SELF-CHECK PASS` まで完走した。拡張後のシミュレーション時刻は47 ms。

初回は既存の `#(STEP*13000)` が1文字強の待ち時間しかなく、送信途中でFIFOを読んでいた。自己判定化の途中でも `STEP*110000` が32bit演算でオーバーフローすることを確認したため、長い待ち時間は `#6ms` の時間リテラルへ変更した。

`sim/makefile` はトップを明示し、FSTとテキストログを配置ごとに保存する。`ccache` は読み取り専用の既定キャッシュを避けて `/tmp/uart_ccache` を使用する。

```sh
make -C sim regress
```

上記でALIGN_4B、ALIGN_1Bを順に実行する。今回の回帰は要求されたFIFO満杯、overrun、break、5/6/8bit、1.5/2 stop、modem入力、複数割り込み原因を含む。ランダム化、全設定の直積、実クロック誤差、メタステーブル注入、形式検証は対象外。

## lint結果

Verilator: `5.050 2026-07-01 rev v5.050`。

| 対象 | オプション | エラー | 警告 |
|---|---|---:|---:|
| RTL、ALIGN_4B | `--lint-only --timing -Wall` | 0 | 0 |
| RTL、ALIGN_1B | `--lint-only --timing -Wall` | 0 | 0 |
| RTL、SYN+ALIGN_4B | `--lint-only --no-timing -Wall` | 0 | 0 |
| RTL、SYN+ALIGN_1B | `--lint-only --no-timing -Wall` | 0 | 0 |
| 既存bench込み、ALIGN_4B | `--lint-only --timing`、既定警告 | 0 | 0 |
| 既存bench込み、ALIGN_1B | `--lint-only --timing`、既定警告 | 0 | 0 |

RTLの4構成は `-Wno-fatal` を使用せず、警告があれば失敗する設定で通過した。インターフェースをまとめたファイル名のDECLFILENAMEはソース内で局所的に除外し、外部バスの未使用ビット・波形表示専用の状態は `unused_*` 信号で意図を明示している。幅不一致、ラッチ、多重駆動、組み合わせループを新しい抑止指定で隠してはいない。

再実行:

```sh
make -C sim lint
```

上記はRTLの4構成をlintするだけで、sim実行ファイルをビルド/実行しない。

各コマンド、実出力、終了コードは [最終lintログ](rtl_fix_lint_2026-09-16/) に保存した。`summary.json` にチェック結果、`source_sha256.txt` に対象ソースのハッシュを記録している。修正前のログは元の `rtl_static_analysis_logs/` にそのまま残している。
