#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Copyright (C) garin <garin54@gmail.com> 2013
# See the included file COPYING for details.

# catch(https://catch.com) のテキストメモの作成と表示をするコマンドラインツール
#
# == 環境(Environment)
# 以下の環境でのみ動作確認済み
#
# * Debian-7.0
# * Ruby 2.0.0
#
# == 必須(Require)
# rest-client(https://github.com/archiloque/rest-client)のgemパッケージが必要
#
#   # gem install rest-client
#
# == 設定(Configuration)
# ~/.catchrc にユーザ名とパスワードを記入(OAuth は未対応)
#
#  $ vi ~/.catchrc
#  @name = "namae"
#  @password = "oshienai"
#
#  $ chmod 600 ~/.catchrc
#
# == 使い方(Usage)
#  // メモの表示 : default ストリームの最新メモを5個
#  // ※[]内の数字が $MEMO_ID
#  $ catch.rb --list
#  [1] sono1
#  [2] memo2
#
#  // メモの作成 : ストリーム,タグ指定とかは未サポート。ただメモをとるだけ
#  $ catch.rb --create memomemo
#
#  // メモの更新
#  $ catch.rb --update $MEMO_ID mememo
#
#  // メモの削除
#  $ catch.rb --delete $MEMO_ID
#
# == 履歴
# 2013-02-14: 0.0.0 : 初版
# 2013-02-14: 0.0.1 : ちょっとだけリファクタリング
# 2013-02-20: 0.1.0 : --list, --create, --update, --delete コマンドの追加
# 2013-03-05: 0.2.0 : Ruby 2.0.0 に移行
#
# メモ: catch.com は json のみをサポート(xml は未サポート)
#
require 'rest_client'
require 'json'
require 'optparse'
CONF_FILE="~/.catchrc"
load(CONF_FILE)

class Catch
  def initialize(user, password)
    @user     = user
    @password = password
    @base_url = "https://#{@user}:#{@password}@api.catch.com/v3/streams"
    @stream   = "default"
  end

  # メモの作成
  def create(text)
    url = "#{@base_url}/#{@stream}"
    RestClient.post(url,
                    {:text => text},
                    :content_type => :json, :accept => :json
                    ) {|response, request, result|
      puts "request : #{request}\nresponse: #{respons}\nresult  : #{result}" if $DEBUG
      puts response.code
    }
  end

  # メモの検索
  def search(limit = 5, offset = 0, sort = 'modified_desc', full = 1)
    url = "#{@base_url}/#{@stream}"
    ret = RestClient.get(url,
                         {:params => { :limit => limit,
                             :offset => offset,
                             :full => full,
                             :sort => sort},
                           :content_type => :json, :accept => :json }
                         ) do |response, request, result|
      puts "request : #{request}\nresponse: #{respons}\nresult  : #{result}" if $DEBUG
      JSON.parse(response.body)["result"]["objects"]
    end
  end

  # メモの更新
  def update(id, text)
    obj = search(id).last
    url = "#{@base_url}/sync/#{obj['id']}"

    puts "id change from #{id} to 1"
    puts "[old]\n#{obj['text']}"
    puts "[new]\n#{text}"
    RestClient.put(url,
                   {:text => text, :server_modified_at => obj["server_modified_at"]},
                     :content_type => :json, :accept => :json
                   ) do |response, request, result|
      puts "request : #{request}\nresponse: #{respons}\nresult  : #{result}" if $DEBUG
      puts response.code
    end
  end

  # メモの削除
  def delete(id)
    obj = search(id).last
    url = "#{@base_url}/#{@stream}/#{obj['id']}"
    puts "#{obj['id']}: #{obj['server_modified_at']}" if $DEBUG
    puts "#{obj['text']}"
    RestClient.delete(url,
                      {:params => { :server_modified_at => obj["server_modified_at"]},
                        :content_type => :json, :accept => :json
                      }
                   ) do |response, request, result|
      puts "request : #{request}\nresponse: #{respons}\nresult  : #{result}" if $DEBUG
      puts response.code
    end
  end
end

# = main
if __FILE__ == $0
  # ===== option
  options = {}
  opt = OptionParser.new do |opt|
    opt.on("-c","--create text", "create memo"){|text|
      options[:command] = :create
      options[:text]    = text
    }
    opt.on("-l","--list [limit]", "show memo list"){|limit|
      options[:command] = :list
      options[:limit]   = limit
    }
    opt.on("-d", "--delete id", "delete memo"){|id|
      options[:command] = :delete
      options[:id]      = id
    }
    opt.on("-u", "--update id", "update memo (require --text option)"){|id|
      options[:command] = :update
      options[:id]      = id
    }
    opt.on("-t", "--text text", "memo body text (only use --update)"){|text|
      options[:text]      = text
    }
  end.permute!(ARGV)

  # ===== main
  c = Catch.new(@user, @password)
  puts options[:command]
  case options[:command]
  when :create
    puts options[:text]
    c.create(options[:text])
  when :update
    if options[:text].nil?
      puts "No exit text.\nusage: $ catch.rb -u id -t text"
      exit 1
    end
    c.update(options[:id], options[:text])
  when :delete
    puts options[:id]
    c.delete(options[:id])
  else
    options[:limit] ||= 5
    c.search(options[:limit]).each_with_index do |obj,i|
      puts "[#{i+1}] #{obj['text']}"
    end
  end
end
