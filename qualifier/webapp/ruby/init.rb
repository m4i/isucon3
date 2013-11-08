#!/usr/bin/env ruby

require 'benchmark'
require 'dalli'
require 'redis'

require_relative 'lib'

$redis = Redis.new(driver: :hiredis)
$cache = Dalli::Client.new('localhost:11211')
$mysql = Util.connect_mysql

puts 'clear cache'
puts Benchmark.realtime {
  $cache.flush_all
}

puts 'cache memos count'
puts Benchmark.realtime {
  $cache.set(
    'memos:count',
    $mysql.query('SELECT COUNT(*) AS c FROM memos WHERE is_private = 0').first['c'],
    nil,
    raw: true,
  )
}

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
