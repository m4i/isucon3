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
end
