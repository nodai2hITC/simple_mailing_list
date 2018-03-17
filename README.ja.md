# SimpleMailingList

シンプルなメーリングリスト／メールマガジンシステムです。

一般的なそうしたシステムと異なり、「最低限必要なもの」が非常に少ないのが特徴です。

## 動作環境

### 最低動作環境

- 送受信可能なメールアドレス１つ
- Ruby が動作するコンピュータ１台

### 推奨動作環境

- 送信可能なメールアドレス１つ
- 受信可能なメールアドレス３つ以上
一般的なそうしたシステムと異なり、「最低限必要なもの」が非常に少ないのが特徴です。

## 動作環境

### 最低動作環境

- 送受信可能なメールアドレス１つ
- Ruby が動作するコンピュータ１台

### 推奨動作環境

- 送信可能なメールアドレス１つ
- 受信可能なメールアドレス３つ以上
- Linux など、プロセスを Daemon 化可能な環境のコンピュータ１台

## インストール

Gemfile に以下を追加し、```$ bundle```

```ruby
gem 'simple_mailing_list'
gem 'sqlite3'
# gem 'mysql2'
# gem 'pg'
```

または、以下のようにしてインストール:

    $ gem install simple_mailing_list

## 使い方

YAML 形式のコンフィグファイルを用意し、

    $ simple_mailing_list setup -c <config.yaml>

でデータベースやディレクトリを作成する。

    $ simple_mailing_list <mode> -c <config.yaml>

で実行。

```<mode>``` を省略すると、「メールの受信・処理」「古いデータの削除」といった一連の処理を行います。

```-c``` を省略すると、「 config.yaml 」が使用されます。

コンフィグファイルの書き方については、[config_example.ja.yaml](https://github.com/nodai2hITC/simple_mailing_list/blob/master/example/config_example.ja.yaml) を参考に。

### Daemon 化

    $ daemons_simple_mailing_list start -- loop -c <config.yaml>

で、「メールの受信・処理」「古いデータの削除」といった一連の処理をずっと繰り返します。

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nodai2hITC/simple_mailing_list.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
