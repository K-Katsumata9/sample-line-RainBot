require 'json'
require 'logger'
require 'net/http'
require 'uri'
require 'line/bot' 
require 'open-uri'
require 'kconv'
require 'rexml/document'
require 'mysql2'

def lambda_handler(event:, context:)
  logger = Logger.new(STDOUT)
  log_formatter = proc { |severity, timestamp, _, msg|
      JSON.dump({time: timestamp, level: severity, message: msg})
  }
  logger.formatter = log_formatter
  
  # 使用したxmlデータ（毎日朝6時更新）：以下URLを入力すれば見ることができます。
  url  = "https://www.drk7.jp/weather/xml/13.xml"
  # xmlデータをパース（利用しやすいように整形）
  xml  = URI.open( url ).read.toutf8 # open でエラーになるときは URI.open としてみてください
  doc = REXML::Document.new(xml)
  logger.info doc
  # パスの共通部分を変数化（area[4]は「東京地方」を指定している）
  xpath = 'weatherforecast/pref/area[4]/info/rainfallchance/'
  # 6時〜12時の降水確率（以下同様）
  per06to12 = doc.elements[xpath + 'period[2]'].text
  per12to18 = doc.elements[xpath + 'period[3]'].text
  per18to24 = doc.elements[xpath + 'period[4]'].text
  # メッセージを発信する降水確率の下限値の設定
  min_per = 20
  if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
    word1 =
      ["いい朝だね！",
      "今日もよく眠れた？",
      "二日酔い大丈夫？",
      "早起きしてえらいね！",
      "いつもより起きるのちょっと遅いんじゃない？"].sample
    word2 =
      ["気をつけて行ってきてね(^^)",
      "良い一日を過ごしてね(^^)",
      "雨に負けずに今日も頑張ってね(^^)",
      "今日も一日楽しんでいこうね(^^)",
      "楽しいことがありますように(^^)"].sample
    # 降水確率によってメッセージを変更する閾値の設定
    mid_per = 50
    if per06to12.to_i >= mid_per || per12to18.to_i >= mid_per || per18to24.to_i >= mid_per
      word3 = "今日は雨が降りそうだから傘を忘れないでね！"
    else
      word3 = "今日は雨が降るかもしれないから折りたたみ傘があると安心だよ！"
    end
    # 発信するメッセージの設定
    push = "#{word1}\n#{word3}\n降水確率はこんな感じだよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\n#{word2}"
    # メッセージの発信先idを配列で渡す必要があるため、userテーブルよりpluck関数を使ってidを配列で取得
    results = dbclient.query("SELECT line_id FROM users")
    logger.info results
    user_ids = results.map { |row| row['line_id'] }
    logger.info user_ids
    message = {
      type: 'text',
      text: push
    }
    client.multicast(user_ids, message)
  end
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

  def dbclient
    dbclient = Mysql2::Client.new(
      host: ENV['DB_HOST'],
      username: ENV['DB_USER'],
      password: ENV['DB_PW'],
      database: "rain_bot_development"
    )
  end