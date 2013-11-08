require 'json'
require 'mysql2-cs-bind'

module Util
  extend self

  def connect_mysql
    config = JSON.parse(IO.read(File.dirname(__FILE__) + "/../config/#{ ENV['ISUCON_ENV'] || 'local' }.json"))['database']
    Mysql2::Client.new(
      :host => config['host'],
      :port => config['port'],
      :username => config['username'],
      :password => config['password'],
      :database => config['dbname'],
      :reconnect => true,
    )
  end

  def cache_memo_header(memo_id, content)
    cache_key = memo_header_cache_key(memo_id)
    header    = memo_header(content)
    $cache.set(cache_key, header)
  end

  def memo_header_cache_key(memo_id)
    "memos:header:#{memo_id}"
  end

  private

  def memo_header(content)
    content.each_line.first.chomp
  end
end
