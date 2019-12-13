# 概要
GUIでパッケージをインストールできるウィザードです。  
ArchLinux派生ディストリビューションを構築する際の初期セットアップとして作成しました。  
ディストリビューターの方に向いています。  

# 依存関係
- bash
- polkit
- zenity

# 使い方
run.shに実行権限を付与して、起動してください。`display`変数が空の場合は起動しません。

# ソフトウェアの追加
2019年12月13日現在では、デフォルトでインストールできるソフトは`baobab`と`gparted`しかありません。  
しかし、scriptsディレクトリにファイルを追加することで簡単にソフトを追加できます。

## スクリプトについて
一つのスクリプトで一つのパッケージ（パッケージ郡）にしてください。  
スクリプトはrootで実行されます。（そのため`makepkg`などは工夫が必要です。）  
スクリプトはbashで記述してください。（zshなどはテストしていません。）

## 記述するもの

以下の3つのみ記述してください。また、全て記述してください。

### name
`name`変数にリストで表示されるパッケージの名前を入れてください。  
空白は絶対に入れないでください。  

### description
`description`変数に、パッケージの説明を入れてください。  
こちらも空白は絶対に入れないでください。  

### install
`install`関数にパッケージのインストール処理を記述してください。  
rootで実行されるため、注意して記述してください。  
また、対話はすべて無効化してください。  
