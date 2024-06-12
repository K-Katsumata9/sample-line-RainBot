# LambdaのRuby 3.2ベースイメージを使用
FROM public.ecr.aws/lambda/ruby:3.2

# 必要なパッケージのインストール
RUN yum update -y && \
    yum install -y gcc make mysql-devel postgresql-devel

# GemfileとGemfile.lockをコピー
COPY Gemfile Gemfile.lock ${LAMBDA_TASK_ROOT}/

# Bundlerをインストールし、Gemをインストール
RUN gem install bundler && \
    bundle install

# Lambda関数のコードをコピー
COPY lambda_function.rb ${LAMBDA_TASK_ROOT}/

# Lambda関数のハンドラーを設定
CMD ["lambda_function.lambda_handler"]
