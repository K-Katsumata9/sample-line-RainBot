#!/bin/bash
bundle config --local build.mysql2 --with-mysql2-config=/usr/lib64/mysql/mysql_config
bundle config --local silence_root_warning true
bundle install --path vendor/bundle --clean
mkdir -p /var/task/lib
cp -a /usr/lib64/mysql/*.so.* /var/task/lib/