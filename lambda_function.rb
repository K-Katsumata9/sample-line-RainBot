require 'json'
require 'logger'
require 'net/http'
require 'uri'
require 'line/bot' 
require 'open-uri'
require 'kconv'
require 'rexml/document'

def lambda_handler(event:, context:)
    logger = Logger.new(STDOUT)
    log_formatter = proc { |severity, timestamp, _, msg|
        JSON.dump({time: timestamp, level: severity, message: msg})
    }
    logger.formatter = log_formatter
    
    signature = event["headers"]["x-line-signature"]
    lambda_event_body = JSON.parse(event['body'])
    body = lambda_event_body.to_json
    unless client.validate_signature(body, signature)
      return  { statusCode: 400 }
    end
    
    
    events =  lambda_event_body["events"]
    
    events.each { |event|
      case event["type"]
        # メッセージが送信された場合の対応（機能①）
      when "message"
        case event["message"]["type"]
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when "text"
          # event.message['text']：ユーザーから送られたメッセージ
          input = event["message"]['text']
          url  = "https://www.drk7.jp/weather/xml/13.xml"
          xml  = URI.open(url).read.toutf8 # open でエラーになるときは URI.open としてみてください
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
          min_per = 30
          case input
            # 「明日」or「あした」というワードが含まれる場合
          when /.*(明日|あした).*/
            # info[2]：明日の天気
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明日の天気だよね。\n明日は雨が降りそうだよ(>_<)\n今のところ降水確率はこんな感じだよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            else
              push =
                "明日の天気？\n明日は雨が降らない予定だよ(^^)\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            end
          when /.*(明後日|あさって).*/
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明後日の天気だよね。\n何かあるのかな？\n明後日は雨が降りそう…\n当日の朝に雨が降りそうだったら教えるからね！"
            else
              push =
                "明後日の天気？\n気が早いねー！何かあるのかな。\n明後日は雨は降らない予定だよ(^^)\nまた当日の朝の最新の天気予報で雨が降りそうだったら教えるからね！"
            end
          when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
            push =
              "ありがとう！！！\n優しい言葉をかけてくれるあなたはとても素敵です(^^)"
          when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
            push =
              "こんにちは。\n声をかけてくれてありがとう\n今日があなたにとっていい日になりますように(^^)"
          else
            per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              word =
                ["雨だけど元気出していこうね！",
                 "雨に負けずファイト！！",
                 "雨だけどあなたの明るさでみんなを元気にしてあげて(^^)"].sample
              push =
                "今日の天気？\n今日は雨が降りそうだから傘があった方が安心だよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\n#{word}"
            else
              word =
                ["天気もいいから一駅歩いてみるのはどう？(^^)",
                 "今日会う人のいいところを見つけて是非その人に教えてあげて(^^)",
                 "素晴らしい一日になりますように(^^)",
                 "雨が降っちゃったらごめんね(><)"].sample
              push =
                "今日の天気？\n今日は雨は降らなさそうだよ。\n#{word}"
            end
          end
          # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = "テキスト以外はわからないよ〜(；；)"
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)
        # LINEお友達追された場合（機能②）
      end
    }
    
    return { statusCode: 200 }
end
private

    def client
        @client ||= Line::Bot::Client.new { |config|
          config.channel_id = ENV["LINE_CHANNEL_ID"]
          config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
          config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
        }
    end