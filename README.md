# jira_create_issue

## About this tool
JIRA に Issue を Bulk Import するツールです。
入力には CSV ファイルを使用します。

- create_issues_from_csv.rb : 実行用スクリプト
- sample.csv : 入力 CSV のサンプル

## Setting up environment on Windows

1. ruby をダウンロードしてインストール  
(Ruby 2.3.7 でテストしています。)
1. gem rest-clientのインストール  
コマンドラインにて"gem install rest-client"実行

## How to use this tool

1. my_credential.rb を編集して自身のアカウント（メールアドレス）とパスワード（API Token）を設定。
1. 作成する Issue の情報を記載した CSV ファイルを作成  
CSV ファイルのフォーマットは sample.csv を参照してください。
1. コマンドプロンプトでツール実行  
$ `ruby import_issue_csv.rb xxxx.csv`  
または  
$ `ruby import_issue_csv.rb`  
CSV ファイルへのパスを入力する

## 制限事項など
- CSVファイルは UTF-8のみ対応
- CSVのファイル名にスペースがあるとエラーになります。
- 以下の条件に当てはまる行を空行とみなし、その行の Issue 作成をスキップします。
  - Sub-Task の場合 : "summary" が空 && "assignee" == "#N/A" && "parent" が空
  - その他の場合 : "summary" が空
- "skipthis" カラムが空でない場合、その行の Issue 作成をスキップします。
  - sample.csv を参照してください。
