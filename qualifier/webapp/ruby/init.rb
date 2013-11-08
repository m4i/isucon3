#!/usr/bin/env ruby

require 'benchmark'
require 'redis'

require_relative 'lib'

$redis = Redis.new(driver: :hiredis)
$mysql = Util.connect_mysql

puts 'cache memos order'
puts Benchmark.realtime {
  sql = 'SELECT id FROM memos WHERE is_private = 0 ORDER BY created_at DESC, id DESC'
  memo_ids = $mysql.query(sql).map do |row|
    row['id']
  end
  $redis.del('memo:public:ids')
  $redis.rpush('memo:public:ids', memo_ids)
}

#puts 'cache memos:header'
#puts Benchmark.realtime {
#  $mysql.xquery('SELECT id, content FROM memos').each do |row|
#    Util.cache_memo_header(row['id'], row['content'])
#  end
#}
