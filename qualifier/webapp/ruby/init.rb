#!/usr/bin/env ruby

require 'benchmark'
require 'dalli'

require_relative 'lib'

$cache = Dalli::Client.new('localhost:11211')
$mysql = Util.connect_mysql

puts 'clear cache'
puts Benchmark.realtime {
  $cache.flush_all
}

#puts 'cache memos:header'
#puts Benchmark.realtime {
#  $mysql.xquery('SELECT id, content FROM memos').each do |row|
#    Util.cache_memo_header(row['id'], row['content'])
#  end
#}
