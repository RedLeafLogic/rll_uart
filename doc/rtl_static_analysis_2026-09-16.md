# UART RTL 静的解析報告

解析日: 2026-09-16

追記: 本報告書に基づくRTL修正とlint確認を実施した。対応表・維持した仕様・最終ログは [修正結果](rtl_fix_summary_2026-09-16.md) を参照。以下の解析結果・行番号・ログは修正前の状態を記録したもの。

## 結論と解析範囲

FIFOのデータ保護・状態管理、受信割り込み、割り込みのマスクと解除、受信エラー通知に機能不具合がある。通常の送受信が一部成功しても、FIFO境界、連続エラー、割り込み同時発生などでデータ破損や通知欠落が起こり得る。まずF01～F03のFIFOとF06～F09の割り込み・受信状態管理を修正することを推奨する。

対象は `rtl/*.sv` 全12ファイル、接続確認用の `bench/uart_top.sv`。あわせて既存テスト、ビルド設定、合成設定、付属資料を確認した。RTLは変更していない。

実施したのは、コードレビュー、Verilatorによる構文・エラボレーション・lint、代表的な次状態式の静的評価である。RTLシミュレーション、形式検証、合成、配置配線、STA、専用CDC解析は実施していない。以下の「確認」は静的に条件式・接続から確認したことを指す。

重大度は、P1=データ破損・通信/割り込み動作に直接影響、P2=条件付きの機能不具合・品質問題。CDCについては故障が実測されたという意味ではなく、構造上のリスクとする。

付属xlsxは接続図の文字列、astaはJavaシリアライズ形式のモデルから文字列を確認した。astaには `char7bit`、`char8bit`、`baud_reg[7:0]` があるが、完全な機能仕様としては読めていない。一般的な16550との差は、実装内部の不整合と分けて末尾に記載した。

## lint結果と再現方法

使用版: `Verilator 5.050 2026-07-01 rev v5.050`。`sim/` で実行する。

```sh
verilator --lint-only -Wall -Wno-fatal --top-module uart_top --timing +define+ALIGN_4B -f uart_rtl.list
verilator --lint-only -Wall -Wno-fatal --top-module uart_top --timing +define+ALIGN_1B -f uart_rtl.list
verilator --lint-only -Wall -Wno-fatal --top-module uart_top --no-timing +define+SYN+ALIGN_4B -f uart_rtl.list
```

| 構成 | 結果 | 警告数 |
|---|---|---:|
| ALIGN_4B | 構文・エラボレーションエラーなし | 10 |
| ALIGN_1B | 構文・エラボレーションエラーなし | 10 |
| SYN + ALIGN_4B、遅延無視 | 構文・エラボレーションエラーなし | 15 |

`-Wno-fatal` を指定しているため、終了コード0は警告なしや機能正常を意味しない。上記構成ではラッチ・幅不一致の警告は出ていないが、機能不具合は以下のとおり残る。

ログと対象ソースのSHA-256は [rtl_static_analysis_logs](rtl_static_analysis_logs/) に保存した。`static_counterexamples.json` はRTLの式をPythonで評価した反例で、RTLシミュレーション結果や形式証明ではない。状態タプルは `(write_pointer, read_pointer, f_fr)`。

## 機能上の指摘と修正方法

### F01 — P1: full/emptyに関係なくFIFOの操作を受理する

箇所: `rtl/uart_fifo.sv:135-145,165-185`、`rtl/uart_register.sv:185-187`、`rtl/uart_receiver.sv:68-74,127`。

`push` と `pop` が無条件にメモリとポインタを更新する。TX書き込み、RX読み出し、RX受信完了のいずれも上位で境界を保護していない。

- 空のRX FIFOを読むと `(w,r,f)=(0,0,0)` が `(0,1,0)` になり、次サイクル以降に非空と認識される。未受信のデータを有効として扱う。
- 満杯にさらにpushすると未読データを上書きし、ポインタ一致が崩れてfullも解除される。
- RXのoverrunはFIFO投入時ではなく `DATA_END` のサンプル時にfullを記録する。その後のCPU読み出しによって、実際の投入可否と通知が食い違う。

修正: FIFO内で受理操作 `do_pop = pop && !empty`、`do_push = push && (!full || do_pop)` を定義し、メモリ、ポインタ、個数、エラービットを同じ受理条件で更新する。この例は空時の同時push/popをバイパスせず、新しい1要素を残す方式。full時同時操作のメモリread/write仕様も明確にする。RX overrunは受信完了時のpush要求が拒否されたイベントから生成し、既存の未読データを保持する。

### F02 — P1: FIFOクリアと満杯時同時push/popでfull/emptyが壊れる

箇所: `rtl/uart_fifo.sv:63-67,152-185`。

`f_fr` は `read_pointer-1 == write_pointer` を `clear` や `pop` より優先してセットし、実際に受理した操作の結果を表していない。

| 条件 | 実装の次状態 | 問題 |
|---|---|---|
| リセット後15回pushし、clear | `(0,0,1)` | クリア後にfull=1、empty=0。その後idleでも維持 |
| full状態でpush/pop同時 | 両ポインタ+1、`f_fr=0` | 16要素を維持するべきところempty=1 |

修正: 0～16を表す5bitの要素数カウンタを使い、reset/clearを最優先、その後に受理したpush/popの差分で更新する。`empty=(count==0)`、`full=(count==16)` とする。現方式を維持する場合も、clearの優先順位だけでなく同時操作と周回を含む次状態全体の修正が必要。

### F03 — P1: RX割り込みのFIFOしきい値判定が誤っている

箇所: `rtl/uart_fifo.sv:70-90`、`rtl/uart_register.sv:445,470`。

`f_fr=0` の経路が要素数の差ではなく `write_pointer + read_pointer` を使っている。また判定が `== LEVEL` のため、しきい値を超えると解除される。`f_fr=1` 側もポインタ差を5bitの定数と比較しており、周回・満杯の要素数を正しく表せない。

例: しきい値4、`w=5,r=1,f=0` は4要素だが、実装は `5+1==4` を評価して偽になる。`w=5,r=0,f=0` の5要素でも `5==4` は偽。割り込み解除がこの信号の立ち下がりを使うため、4→5要素への増加でも受信割り込みが消える。

修正: F02の要素数を用いて `rx_trigger = count >= trigger_level` とする。RDAはしきい値以上のレベル条件で管理し、しきい値変更にも追従させる。しきい値未満で解除する期待動作は [TI TL16C550Dデータシート p.34](https://www.ti.com/lit/ds/symlink/tl16c550d.pdf#page=34) を参照。

### F04 — P2: FIFOクリアでエラー情報が残り、同一アドレス同時操作でもエラーが消える

箇所: `rtl/uart_fifo.sv:95-149`。

`clear` はポインタには効くが `fifo_err[]` には効かない。エラー付き受信後にFCRでクリアしても、そのスロットのエラーが全スロットORの `all_error` に残る。次のエラー発生を立ち上がり検出できなくなる原因にもなる。clearとpushが同時ならメモリ書き込みも行われる。

また同時push/popで読み書きポインタが同じ場合、同じ `fifo_err[]` への2回のノンブロッキング代入のうち、後のクリアが有効になり、新しく書いたエラーを消す。

修正: reset/clear時に全エラーvalidを消し、clear中は通常操作を行わない。F01の受理操作に合わせ、同一スロットを置き換えるときは新データ側のエラーを残す。全スロットORの対象は有効要素に限定する。

### F05 — P1: ALIGN_1Bの書き込みレーン不一致とMCR読み出し欠落

箇所: `rtl/uart_register.sv:79-101,139-146`。

1バイト配置ではSELと読み出し値をアドレスのバイトレーンに合わせているが、書き込み値は常に `wb_bus.dat_i[7:0]` を取る。例えばLCRへの `adr=3,sel=1000,dat_i=0x03000000` は、LCRに0x03ではなく0を設定する。既存BFMも書き込みを下位8bitに置くため、この不整合を隠す。

加えて、1バイト配置の `rdat[7:0]` にはMCRの選択肢がなく、MCRへ書いた後に読んでも0になる。

修正: ALIGN_1Bでは `adr_i[1:0]` に対応する `dat_i` の8bitを選び、MCRを下位レーンのread muxへ追加する。もし書き込みを常に下位8bitに置く独自バス仕様なら、その非対称仕様を明記する必要がある。少なくともMCRのread mux欠落は独立した不具合。

### F06 — P1: IERで無効化しても割り込みが残る

箇所: `rtl/uart_register.sv:93-97,432-480`。

IERは割り込みのset条件にだけ適用され、保持済みpendingからの `intr_o` 出力やIIRの選択には適用されない。RDA以外にはIER無効化に対応する解除もない。

例: THRE割り込みがpendingになった後、IERを0に書いてもTHR書き込み/IIR読み出しがなければpendingと `intr_o` が残る。ソフトウェアの割り込み禁止が効かない。

修正: 原因状態とマスク後の有効pendingを分離し、`effective_pending = pending & enable_mask` をIRQとIIRの両方に使用する。再有効化時の通知は原因の保持/レベル条件から設計する。IERで割り込みを無効化する期待動作は [TIデータシート p.35](https://www.ti.com/lit/ds/symlink/tl16c550d.pdf#page=35) を参照。

### F07 — P1: 異なる割り込みのsetとclearが同時に発生するとclearを失う

箇所: `rtl/uart_register.sv:432-439,472-480`。

pending更新がベクタ全体の `if(set != 0) ... else if(reset != 0)` になっている。あるビットのsetが他ビットのclearまで抑止する。

例: LSRを読んでline-status割り込みを解除するクロックにmodem割り込みが発生すると、LSRのエラー状態は消えてもline-status pendingだけが残り得る。静的評価では `pending=00001,set=10000,clear=00001` に対して `10001` を生成する。

さらにTHREのclearは「IIRがTHREを返した場合」に限定されず、すべてのIIR読み出しで動作する。優先順位が上の割り込みを読んだだけで、未処理のTHREを消す可能性がある。

修正: イベント保持ビットは原則 `pending_next = (pending & ~clear_mask) | set_mask` のようにビット単位で更新し、同一ビットの優先順位を明文化する。RDAなどレベル原因は別途レベルとして扱う。IIR読み出しによるTHRE解除は、読み出しで実際に返したIDに限定する。IIRとIRQは同一の有効pendingから生成し、現在のIIRの1クロック遅延も整理する。

### F08 — P1: 同じ種類の受信エラーが連続すると2文字目以降を見落とす

箇所: `rtl/uart_register.sv:288-374`、`rtl/uart_fifo.sv:95`。

PE/FE/BIをFIFO先頭データのエラービットの0→1だけで検出している。エラー付き文字A、Bが連続し、AのLSR読み出しで状態を消した後にAをpopしても、先頭のエラービットは1→1なのでBのエラーを再セットできない。

空FIFOでも `pop_dat` は古いメモリを出し続けるが、エラー検出に `!empty` のガードがない。周回後などで無効スロットの古いエラーを通知する経路もある。`all_error` も立ち上がりだけを使うため、残存エラーを安定して表せない。さらに `all_error_r` の更新にはoverrunをORする一方、set側はORしておらず、別原因によりエッジが隠れる。

修正: 「新しい有効な先頭文字が現れた」イベントをpush/popとvalidから求め、その文字のエラーをLSRへ反映する。LSR読み出し後に同じ文字で再通知しない管理と、次の文字では同じ種類でも再通知する管理を分ける。FIFO全体のエラー有無はvalidな要素のエラー状態から管理する。

### F09 — P1: 受信タイムアウトがFIFOアクセスに追従せず、再通知も止まる

箇所: `rtl/uart_baud.sv:96-108`、`rtl/uart_codec_state.sv:71-77,104-110`、`rtl/uart_register.sv:436,444`。

タイムアウトカウンタへの入力にRBR読み出し/FIFO popが存在しない。途中でCPUが1文字読んでもカウンタを再開始しない。カウントは受信開始エッジから進み、受信完了時にはリセットされないため、受信フレーム自体の時間を待機時間に含める。しきい値も文字形式によらず `0x28` に固定されている。

タイムアウト発生後はTIMEOUT→IDLEへ移り、IDLE中はカウンタをリセットし続ける。そこでRBRを1文字だけ読んで割り込みを消しても、FIFOに文字が残っているだけでは再度TIMEOUTへ入れず、次の受信がなければ通知が止まる。

修正: タイムアウト計測を受信FSMから独立させ、FIFO非空時に計測する。受信文字の格納/RBR読み出し/FIFOクリアでリセットし、設定された1文字の長さから4文字分を算出する。割り込み解除後も非空なら再計測する。期待動作は [TIデータシート p.34](https://www.ti.com/lit/ds/symlink/tl16c550d.pdf#page=34) を参照。

### F10 — P1: TEMTが送信完了前に立ち、THREにも送信状態を混ぜている

箇所: `rtl/uart_transmitter.sv:80-121,143-149`、`rtl/uart_register.sv:260-262,443`。

`trans_buf_empty` は送信ビット境界でなく毎クロック `next_state == IDLE || next_state == STOP` でセットされる。`next_state==STOP` の段階では最終データやパリティの処理が残り、実際のストップビット出力も完了していない。TX FIFOが空ならLSR.TEMTまで早く1になる。

この値で送信完了を判断してRS-485の送信許可を落とす、クロックを停止するなどの利用では、フレーム末尾を切る可能性がある。またTHRE割り込み源が `fifo_empty & trans_buf_empty` なので、FIFOが空になって補充できる時点と通知が一致しない。

修正: 送信シフトレジスタのbusyを「フレームの最後のストップビット期間が終了した時点」で解除し、`TEMT = tx_fifo_empty && !tx_busy` とする。THREはFIFO空状態を基に別管理する。期待されるTHRE/TEMTの区別は [TIデータシート p.37](https://www.ti.com/lit/ds/symlink/tl16c550d.pdf#page=37) を参照。

### F11 — P2: RXのstick parityとFE/BI判定に誤りがある

箇所: `rtl/uart_receiver.sv:129-140`、`rtl/uart_transmitter.sv:104-115`。

TXはstick parityを生成するが、RXは `stick_parity` を参照せず通常の偶数/奇数パリティとして検査する。例えばstick mark、データ0x01、受信parity=1はTXの正しい出力でも、RXの奇数パリティ検査ではエラーになる。

またFEを `stop==0 && data!=0` に限定しているため、0x00の不正ストップをFEとして検出しない。BIを `data==0 && stop==0 && parity_err==0` としており、データ/パリティ/ストップ期間を通してlowだったことを判定していない。例えば奇数パリティ設定で連続lowを受けるとPE=1になり、BI判定が阻害される。

修正: RXの期待パリティをTXと同じLCR設定から生成する。FEはストップのサンプル値から判定し、BIは有効な文字期間の連続low検出で別管理する。FEとBIを不必要に排他的にしない。

### F12 — P1（高速設定時）: 固定周期のRXフィルタが有効なビットを消す

箇所: `rtl/uart_noize_shaver.sv:43-66`、`rtl/uart_baud.sv:80-82,127`。

フィルタは16システムクロックに1度しか入力を取り込まず、4サンプル中3個以上が1のときだけ出力を1にする。受信/送信の1bit期間はRTL上 `16*(baud_reg+1)` クロック。

`baud_reg=0` では1bitがフィルタの1サンプル分しかなく、idle=1からの1bit幅のstart=0が消える。`baud_reg=1` でも長いlow後の1bit幅highは2サンプルにしかならず、出力highにならないパターンがある。内部ループバックはこのフィルタを迂回するため、ループバックだけの試験では分からない。

修正: 入力同期後にbaudに対応したサンプルイネーブルでノイズ判定するか、システムクロック毎の短いフィルタへ変更する。許容する最小divisorとフィルタ遅延を仕様化し、最低値・連続0/1・交互パターンで独立送受信器との確認を行う。

### F13 — P1相当の実機リスク: 非同期入力に独立した同期段がない

箇所: `rtl/uart_noize_shaver.sv:53-66`、`rtl/uart_register.sv:107-110,377-404`、`bench/uart_top.sv:62-81`。

RXDを取り込む `shift[0]` は後段で同期し終わる前に比較ロジックへ直接入力される。4段のshift registerがあっても、初段を機能論理へ使っているため、独立した2段同期器とは異なる。

CTS/DSR/RI/DCDも外部入力から直接状態レジスタとXORによる変化検出へ入り、非同期遷移に対する独立した同期段がない。メタステーブル値や取り込み差による通知異常のリスクがある。同期reset解除もこのIP内部では行っておらず、外部保証の有無は不明。

修正: 外部入力ごとに連続クロック動作の同期器を設け、最終段のみをフィルタ、MSR、変化検出に使う。FPGAに応じた同期器属性・配置制約を付ける。resetは外部で同期解除する契約を明示するか、IP側に同期解除回路を設ける。専用CDC/RDC解析とSTAで確認する。STA/CDCの安全性を今回のlintだけで認定することはできない。

### F14 — P2: modemの変化履歴を上書きし、RIの両エッジを通知する

箇所: `rtl/uart_register.sv:386-398,442`。

MSR下位4bitは新しい `modem_pulse` で上書きされる。CTS変化の後、MSR未読のままDSRが変化するとCTSの未読履歴が消える。さらにRIも他の信号と同じXORで両エッジを検出している。

修正: 未読の変化履歴はORで蓄積し、MSR読み出しと新イベントの同時処理をビット単位で定義する。RIは仕様に合わせ片エッジ検出とする。本RTL内の `ri` は端子極性を反転済みなので、端子のlow→highは内部 `ri` の1→0に対応する。TERIの期待動作は [TIデータシート p.38](https://www.ti.com/lit/ds/symlink/tl16c550d.pdf#page=38) を参照。modem割り込み源も一時的なpulseだけでなく、保持された未読状態とIERを考慮する。

### F15 — P2: スタートビット中央で偽スタートを棄却しない

箇所: `rtl/uart_receiver.sv:103-111,156-164`、`rtl/uart_codec_state.sv:80`。

立ち下がり検出で受信を開始した後、STARTのサンプル時にlineがlowか確認せず、そのままデータ受信へ進む。ノイズフィルタを通るが半ビット未満のlowパルスでも、架空の1文字をFIFOへ投入する可能性がある。

修正: START中央でlowを確認できない場合は受信を中止し、FIFOへpushせず再待機する。再同期・break後の再開も含め、次の有効startを受理できる状態へ戻す。

## 互換性・実装品質上の追加確認

これらは部分実装として意図された可能性があるため、すべてを上記と同じ確度の仕様違反とはしない。ただし汎用16550ドライバとの互換性が必要なら対応が必要。

| 項目 | 現在の実装と影響 | 対応 |
|---|---|---|
| 文字長・stop長 | `uart_codec_state.sv:85-93` は7bit以外を8bit扱い。`stop_bit_count` は制御に使われず、5/6bitや追加stopを設定しても反映されない | 対応するならbit数・stop期間で制御。限定するなら対応値を明記 |
| Divisor/DLAB | `uart_package.sv:170` は8bit。`uart_register.sv:69,82` はDLAB=1でもoffset1をIERへ割り当てる。標準のDLM書き込みがIERを変更する | 16bitのDLL/DLMとDLABによるoffset1切替を実装、または独自レジスタ仕様を明記 |
| ボーレートの計算 | `uart_baud.sv:80,127` は0から設定値まで数えるため `fclk / (16*(B+1))`。標準divisor値をそのまま使うとずれる | divisor値そのものとカウンタ終値を区別する。8bit/ゼロ値の扱いも仕様化 |
| FIFO enable | FCR[0]を無視し、IIR上位は0xC固定、常時FIFO扱い | 非FIFOモードを実装するか常時FIFOという制限を明記 |
| loopbackのmodem出力 | `uart_register.sv:104-105` はloopback中もRTS/DTRを外部へ通常出力 | 想定する16550互換loopback仕様を確認し、必要なら外部出力を非アクティブへ固定 |
| 未駆動ビット | `uart_register.sv:186` はTX pushデータ[7:0]のみ駆動し、[10:8]が未駆動。`uart_fifo.sv:68` はpush側almost_fullのみ駆動 | TXは `{3'b000, dat_i}` 全体を駆動。pop側の公開信号も駆動するかインターフェースから削除 |
| 見かけ上のパラメータ化 | `uart_fifo.sv:47-59` のデフォルトADDR_WIDTH=2/DATA_WIDTH=2に対し、ポインタは固定4bit、メモリは16×11、参照も[10:0]固定 | 固定仕様に整理するか、ポインタ・深さ・データ幅を一貫してパラメータ化。現topの4/11設定はこの幅問題に該当しない |
| RTL内の遅延 | `uart_noize_shaver.sv:48-59` に `#1` があり、SYNでも残る | 合成対象RTLから遅延を外す。SYN lintではASSIGNDLYが5件 |
| 制約・構成 | `syn/uart_top.qsf` は旧式50MHz設定とSYNのみを指定し、ALIGN_4Bを指定しない。現simの既定はALIGN_4B。SDC/XDCは見当たらない | 合成・シミュレーションのバス配置を統一し、対象デバイス向けクロック/I/O/reset/CDC制約を整備 |

Divisor、文字形式、FIFO関連の標準との比較には [TI TL16C550Dデータシートのレジスタ説明](https://www.ti.com/lit/ds/symlink/tl16c550d.pdf#page=33) を参照した。これは付属設計資料の代替仕様ではなく、互換性確認の参考資料である。

`MULTIDRIVEN` 警告は `fifo_push_trans.empty` に対して全lint構成で1件出る。ただし両方のドライバ位置が同じ `uart_fifo.sv:63` を指し、ソース上はRX/TXで別インターフェースを使っている。現時点では実際の異なる値の多重駆動とは断定しない。エラボレーション後の接続と別ツールで切り分ける。方向を明示したmodportや単一の内部状態信号からの配線に整理すると確認しやすい。

## 既存検証の不足と修正後の確認項目

`sim/uart_test.sv:69` に無条件の `$finish` があるため、以降の受信FIFO読み出し、偶数/奇数パリティ、FIFOクリア、タイムアウトの試験へ到達しない。またDUTと相手側が同じRTLを使う試験では、共通のボーレートずれや機能制限を相互に隠す可能性がある。今回これらの動的試験は実行していない。

修正後は以下を優先する。

1. FIFOの0/1/14/15/16要素、周回、full/empty中の操作、同時push/pop、clearと操作の同時発生を検証する。`0 <= count <= 16`、clear後empty、未受理操作でポインタ不変をassertする。
2. RXしきい値1/4/8/14に対し、増加・減少・周回・しきい値変更でRDAを確認する。
3. 異なる割り込みの同時set/clear、IER無効化/再有効化、優先度の高いIIR読み出し時のTHRE保持を確認する。
4. 連続する同種PE/FE/BI、LSR→RBRの読み順序、空FIFO、FCRクリア後のエラー消去を確認する。
5. タイムアウト直前のRBR読み出し、1文字だけ読んで残す場合の再通知、受信完了からの待ち時間を確認する。
6. ALIGN_1B/4Bを独立に試験し、全read/writeレジスタのレーンとreadbackを確認する。
7. 独立したUARTモデルで対応文字形式、stick parity、break、偽start、最小divisor、連続フレームを確認する。TEMTの立ち上がりが最終stop期間終了後であることを確認する。
8. 対象FPGA/ASICの同期器・reset解除をCDC/RDCとSTAで確認する。

推奨修正順序は、FIFO共通基盤 → バスread/write → 割り込み/LSR/timeout → 送受信フォーマットとフィルタ → 同期器と制約。F01～F04を別々の小修正で済ませず、受理操作・要素数・エラーvalidを共通の状態更新として整合させることが重要。
