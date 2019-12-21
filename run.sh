#!/usr/bin/env bash

#-- 設定 --#
settings=$(cd $(dirname $0) && pwd)/settings.conf



#-- エラーチェック
set -eu



#===== 各基本ウィンドウの使い方 =====#
# プログレスバー
# command | loading [横幅] [高さ] [メッセージ]
#
# エラーウィンドウ
# error [横幅] [高さ] [メッセージ]
#
# 警告ウィンドウ
# warning [横幅] [高さ] [メッセージ]
#
# 情報ウィンドウ
# info [横幅] [高さ] [メッセージ]
#
# 改行する場合は \n と記述してください。　



#-- 変数定義 --#
current_path=$(cd $(dirname $0) && pwd)/$(basename $0)
current_dir=$(dirname $current_path)



#-- 関数定義 --#

function call_me () {
    export recall=true
    options=$@
    bash ${0} $options
}

# ウィンドウの基本型
function window () {
    zenity \
        --title="$window_text" \
        --window-icon="$window_icon" \
        $@
}

# 読み込みウィンドウ
function loading () {
    window \
        --progress \
        --auto-close \
        --pulsate \
        --width="$1" \
        --height="$2" \
        --text="$3"
}

# エラーウィンドウ
function error () {
    window \
        --error \
        --width="$1" \
        --height="$2" \
        --text="$3"
}

# 警告ウィンドウ
function warning () {
    window \
        --warning \
        --width="$1" \
        --height="$2" \
        --text="$3"
}

# 情報ウィンドウ
function info () {
    window \
        --info \
        --width="$1" \
        --height="$2" \
        --text="$3"
}

# ユーザーチェック
function user_check () {
    if [[ $(getent passwd $1 > /dev/null ; printf $?) = 0 ]]; then
        if [[ -z $1 ]]; then
            printf 1
        fi
        printf 0
    else
        printf 1
    fi
}

# 設定上の関数チェック
function check_func () {
    if [[ ! $(type -t $1) = "function" ]]; then
        error 800 100 "$2"
        exit 1
    fi
}

# パッケージチェック
check_pkg () {
    if [[ -n $(installed_list | grep -x "$1") ]]; then
        printf 0
    else
        printf 1
    fi
}



#-- ディスプレイチェック --#
if [[ -z $DISPLAY ]]; then
    echo "GUI環境で起動してください。" >&2
    exit 1
fi



#-- Rootチェック --#
if [[ ! $UID = 0 ]]; then
    if [[ ! -f /tmp/user || -w /tmp/user ]]; then
        echo -n 'aur_user=' > /tmp/user
        echo "$(whoami)" >> /tmp/user
    fi
    options=$@
    pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY $current_path $options> /dev/null
    exit
fi



#-- 設定読み込み --#
set +eu
if [[ ! -f $settings ]]; then
    error 600 100 "$settingsが存在しません。"
fi
source $settings
if [[ -z $ID ]]; then
    source /etc/os-release
fi
set -eu



#-- デバッグ用引数 --#
set +eu
while getopts 'adhpu:' arg; do
    case "${arg}" in
        a) export ID=arch;;
        d) installed_list () { ${pacman} -Q | awk '{print $2}'; }; [[ ! $recall = true ]] && warning 600 100 "dpkg,apt用のinstalled_listを使用します。" ;;
        h) info 600 100 "==　デバッグ用　==\nこれはデバッグ用オプションです。通常利用はしないでください。\n\n-a　:　ArchLinuxモードを強制的に有効化します。\n-d　:　dpkg,apt用のinstalled_listを使用します。\n-h　:　このヘルプを表示します。\n-p　:　pacman用のinstalled_listを使用します。\n-u　[ユーザー名]　:　パッケージのビルドに使用するユーザーを指定します。"; exit 0;;
        p) installed_list () { ${pacman} -Q | awk '{print $1}'; }; [[ ! $recall = true ]] && warning 600 100 "pacman用のinstalled_listを使用します。" ;;
        u) aur_user=${OPTARG};;
        ""):;;
        * ) exit 1;;
    esac
done
set -eu



#-- check_pkgについて --#
check_func installed_list "$settingsで、installed_listをディストリビューションごとに設定してください。\nわからない場合は、ディストリビューションの配布元へ連絡してください。"



#-- pacapt --#
if [[ ! $ID = "arch" || ! $ID = "arch32" ]]; then
    if [[ ! -f $pacman ]]; then
        error 600 100 "$pacmanがありません。"
        exit 1
    fi
    if [[ ! -x $pacman ]]; then
        chmod 755 $pacman
    fi
else
    pacman=pacman
fi



#-- AURユーザー --#
set +eu
if [[ ! $recall = true ]]; then
    if [[ $ID = "arch" || $ID = "arch32" ]]; then
        function ask_user () {
            set -eu
            aur_user=$(window --entry --text="パッケージのビルドに使用する一般ユーザーを入力してください。")
            set +eu
            if [[ -z $aur_user ]]; then
                error 600 100 "ユーザー名を入力してください。"
                ask_user
            fi
            if [[ $aur_user = "root" ]]; then
                error 600 100 "一般ユーザーを入力してください。"
                ask_user
            fi
        }
        if [[ -n $aur_user ]]; then
            warning 600 100 "デバッグ用引数で指定されたユーザー($aur_user)を使用します。この設定は/tmp/userに保存されます。"
        elif [[ -f /tmp/user ]]; then
            source /tmp/user
            info 600 100 "/etc/userに保存されているユーザー($aur_user)を使用します。"
            [[ -z $aur_user ]] && ask_user
        elif [[ ! $SUDO_USER = root ]]; then
            aur_user=$SUDO_USER
            info 600 100 "sudoで使用されていたユーザー($aur_user)を使用します。この設定は/tmp/userに保存されます。"
        else
            ask_user
        fi
        while [ $(user_check $aur_user) = 1 ]; do
            error 600 100 "指定されたユーザー($aur_user)は正しくありません。"
            ask_user
        done
        if [[ -f /tmp/user ]]; then
            rm -f /tmp/user
        fi
        echo -n 'aur_user=' > /tmp/user
        echo "$aur_user" >> /tmp/user
        export aur_user=$aur_user
    fi
fi
set -eu



#-- クリーンアップ --#
function cleanup () {
    $pacman -Scc --noconfirm
    if [[ $ID = "arch" || $ID = "arch32" ]]; then
        if [[ -n $(pacman -Qttdq) ]]; then
            $pacman -Qttdq | $pacman -Rsnc - | loading 600 100 "クリーンアップを実行中です"
        else
            info 600 100 "クリーンアップの必要はありません。"
        fi
    else
        $pacman -Rsn --noconfirm | loading 600 100 "クリーンアップを実行中です"
    fi
}



#-- データベースのアップデート --#
function update_db () {
    $pacman -Syy --noconfirm
}



#-- パッケージのアップグレード --#
function upgrade_pkg () {
    $pacman -Syu --noconfirm
}



#-- インストールとアンインストール --#
function install_and_uninstall () {
    # スクリプト読み込み
    scripts=($(ls $script_dir))
    for package in ${scripts[@]}; do
        source $script_dir/$package
        if [[ ! $(type -t install) = "function" ]]; then
            error 600 100 "スクリプト$packageのinstall関数が間違っています。"
            exit 1
        fi
        if [[ -z $name ]]; then
            error 600 100 "スクリプト$packageにname変数が設定されていません。"
            exit 1
        fi
    done



    # リスト

    window \
        --warning \
        --width="600" \
        --height="100" \
        --text="スクリプトの読み込みを行います。これにはしばらく時間がかかる場合があります。" \
        --ok-label="読み込み開始"

    gen_list () {
        window \
            --list \
            --checklist \
            --column="選択" \
            --column="パッケージ" \
            --column="インストール済" \
            --column="説明" \
            --width="900" \
            --height="500" \
            --text="インストールまたは削除したいパッケージを選択してください。" \
            $(
                scripts=($(ls $script_dir))
                for package in ${scripts[@]}; do
                    source $script_dir/$package
                    if [[ $(check_pkg $package_name) = 0 ]]; then
                        status_display="はい"
                    else
                        status_display="いいえ"
                    fi
                    echo "FALSE"
                    echo "$name"
                    echo "$status_display"
                    echo "$description"
                done
            )
    }

    selected_list=$(gen_list; exit_code=$?)
    selected_list=(${selected_list//'|'/ })
    if [[ ! $exit_code = 0 && -z $selected_list ]]; then
        error 600 100 "パッケージが選択されませんでした。\nウィザードを再起動します。"
        call_me $@
        exit
    fi


    # データベースの更新
    update_db | loading 600 100 "リポジトリデータベースを更新しています。"



    # 実行

    for selected in ${selected_list[@]}; do
        # 選択パッケージに対応しているファイルを探す
        scripts=($(ls $script_dir))
        for package in ${scripts[@]}; do
            set name
            set description
            set preparing
            set install

            source $script_dir/$package
            if [[ $name = $selected ]]; then
                break
            fi
            unset name
            unset description
            unset preparing
            unset run_preparing
            unset install
        done

        # インストール or アンインストール
        source $script_dir/$package

        if [[ $(check_pkg $package_name) = 1 ]]; then
            window \
                --question \
                --text="パッケージ$nameをインストールします。よろしいですか？" \
                --ok-label="続行する" \
                --cancel-label="中断する" \
                --width=600 \
                --height=100
            if $run_preparing; then
                preparing | loading 600 100 "パッケージをビルドしています"
            fi
            install | loading 600 100 "パッケージ$nameをインストールしています"
        else
            window \
                --question \
                --text="パッケージ$nameをアンインストールします。よろしいですか？" \
                --ok-label="続行する" \
                --cancel-label="中断する" \
                --width=600 \
                --height=100
            uninstall | loading 600 100 "パッケージ$nameをアンインストールしています。"
        fi
    done
    info 600 100 "処理が完了しました。\n詳細はターミナルを参照してください。"
}



#-- 実行 --#
set +eu
unset run
unset exit_code

run=$(
    window \
        --info \
        --text="何を実行しますか？" \
        --ok-label="終了する" \
        $(
            if [[ $ID = "arch" || $ID = "arch32" ]]; then
                echo "--extra-button=保存されているAURユーザーデータを削除"
            fi
        ) \
        --extra-button="パッケージのクリーンアップ" \
        --extra-button="パッケージのアップグレード" \
        --extra-button="パッケージの追加と削除" \
        --width="300" \
        --height="100"
)
exit_code=$?
case $exit_code in
             0 ) exit 0 ;;
             * ) :;;
esac
case $run in
    "パッケージの追加と削除" ) install_and_uninstall ;;
    "パッケージのアップグレード" ) upgrade_pkg | loading 600 100 "パッケージのアップグレードを行っています。" ;;
    "保存されているAURユーザーデータを削除" ) rm -f /tmp/user ; info 600 100 "保存されているユーザーを削除しました" ; exit 0;;
    "パッケージのクリーンアップ" ) cleanup ;;
    * ) exit 1 ;;
esac
set -eu



#-- 最初に戻る --#
call_me $@
