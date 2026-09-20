# rll_uart

[English](README_eng.md) | 日本語

`rll_uart` は、SystemVerilogで記述した16550系UART IPコアです。32ビットの
Wishboneインターフェース、送受信FIFO、割り込み、モデム制御信号、内部
ループバックを備えています。

> [!NOTE]
> 2010にSystemVerilogの書き方見本として公開したRTLのgpt-6-astraによる改修版です。
> astraに静的解析を依頼して修正、2010では5/6bitモード非対応だったがastra君が対応してくれた。
> 本コアは16550の主要機能を実装していますが、完全互換を保証するものでは
> ありません。採用前に、対象システムで必要なレジスタ動作とタイミングを
> 確認してください。

## 主な機能

- SystemVerilog RTL
- 32ビットWishboneバスインターフェース
- 5～8ビットのデータ長、パリティ、ストップビット、ブレーク制御
- 16エントリの送信FIFOと受信FIFO
- 受信、送信、ライン状態、モデム状態の割り込み
- RTS、CTS、DTR、DSR、RI、DCDのモデム信号
- 内部ループバック
- バイト間隔と32ビットワード間隔の2種類のレジスタ配置

## レジスタ配置

ビルド時に次のいずれかを定義します。

| 定義 | 配置 | データレーン |
| --- | --- | --- |
| `ALIGN_1B` | レジスタを1バイト間隔で配置 | アドレスに対応するバイトレーン |
| `ALIGN_4B` | レジスタを4バイト間隔で配置 | 下位8ビット |

レジスタ構造の詳細は[レジスタ構造](doc/register_structure.md)、状態遷移は
[UARTステートマシン](doc/uart_state_machines.md)、モジュール間の関係は
[モジュール構成](doc/module_structure.md)を参照してください。

## ディレクトリ構成

| パス | 内容 |
| --- | --- |
| `rtl/` | UARTコア、FIFO、パッケージ、インターフェース |
| `bench/` | 合成用トップと検証用ラッパー |
| `sim/` | Verilator／ModelSim向けのテストベンチとファイルリスト |
| `syn/` | 合成制約、Docker環境、Yosys合成フロー |
| `gate/` | 代表的なゲートレベル機能シミュレーション |
| `doc/` | 設計資料と解析結果 |

## RTLシミュレーションとLint

Verilatorが利用できる環境で、リポジトリのルートから実行します。

```sh
# ALIGN_1BとALIGN_4Bの回帰テスト
make -C sim regress

# 両構成の静的Lint
make -C sim lint
```

個別に実行する場合は、`make -C sim sim_1b` または
`make -C sim sim_4b` を使用します。

## Yosys合成規模

Yosys 0.68（`38e001a6f`）で `uart_top` を汎用セルへ合成した結果です。
測定日は2026-09-20です。

| 構成 | 組合せゲート | 1ビットFF | 総セル数 |
| --- | ---: | ---: | ---: |
| `SYN` + `ALIGN_1B` | 1,771 | 523 | 2,294 |
| `SYN` + `ALIGN_4B` | 1,685 | 523 | 2,208 |

フローは `read_slang` の後に `synth -top uart_top -flatten` を実行し、ABCの
標準汎用ゲートへマッピングします。MUXやインバータを含む組合せセルを各1
ゲートとして数え、イネーブル／リセット付きFFとレジスタへ展開されたFIFOを
FF数に含めています。

この値はNAND2換算ゲート数、FPGAのLUT／LE数、物理面積ではありません。
セルライブラリ、クロック制約、配置配線は適用していません。最終ネットリスト
にはラッチ、未展開メモリ、ブラックボックスはなく、両構成で
`check -assert` が成功しています。

### 再実行

`syn/dockerfile` のDocker環境を使用します。

```sh
# Dockerイメージがない場合
make -C syn/yosys image

# 2構成を合成し、results.jsonを更新
make -C syn/yosys
```

記録済みの実行では `fpga-suite_080823:y0.68-v5.050` を使用しました。
イメージID、ツールバージョン、入力ファイルのSHA-256、セル別の内訳は
[合成結果](syn/yosys/results.json)に保存しています。算出方法と生成物の詳細は
[Yosys合成手順](syn/yosys/README.md)を参照してください。

## ゲートレベルシミュレーション

Quartus PrimeとQuesta／ModelSimが利用できる環境では、次のコマンドで代表的な
ポストフィット機能シミュレーションを実行できます。

```sh
make -C gate
```

使用するツールや生成物、タイミングシミュレーションの制約については
[ゲートレベルシミュレーション手順](gate/README.md)を参照してください。

## ライセンス

RedLeafLogic Co., Ltdが著作権を持つ本プロジェクトのコードは、
[Apache License 2.0](LICENSE)で提供します。
