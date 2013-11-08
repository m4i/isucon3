require 'sinatra/base'
require 'digest/sha2'
require 'erubis'
require 'tempfile'
require 'redcarpet'
require 'redis'

require_relative 'lib'

class Isucon3App < Sinatra::Base
  $stdout.sync = true

  use Rack::Session::Cookie, {
    :key => 'isucon_session',
    :secret => 'secret',
  }

  configure do
    mysql = Util.connect_mysql

    $users     = {}
    $usernames = {}
    mysql.xquery('SELECT id, username, password, salt FROM users').each do |row|
      $users[row['id']]           = row
      $usernames[row['username']] = row['id']
    end

    mysql.close
  end

  helpers do
    set :erb, :escape_html => true

    def redis
      $redis ||= Redis.new(driver: :hiredis)
    end

    def connection
      $mysql ||= Util.connect_mysql
    end

    def get_user
      mysql = connection
      user_id = session["user_id"]
      if user_id
        user = $users[user_id]
        headers "Cache-Control" => "private"
      end
      return user || {}
    end

    def require_user(user)
      unless user["username"]
        redirect "/"
        halt
      end
    end

    def gen_markdown(md)
      $markdown ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      $markdown.render(md)
    end

    def anti_csrf
      if params["sid"] != session["token"]
        halt 400, "400 Bad Request"
      end
    end

    def url_for(path)
      base = "http://#{request.host}"
      "#{base}#{path}"
    end
  end

  get '/' do
    mysql = connection
    user  = get_user

    total = redis.llen('memo:public:ids')
    memo_ids = redis.lrange('memo:public:ids', 0, 100 - 1)
    memos = memo_ids.empty? ? [] :
      mysql.xquery('SELECT id, user, header, created_at FROM memos WHERE id IN (?) ORDER BY created_at DESC, id DESC', memo_ids)
    memos.each do |row|
      row["username"] = $users[row['user']]['username']
    end
    erb :index, :layout => :base, :locals => {
      :memos => memos,
      :page  => 0,
      :total => total,
      :user  => user,
    }
  end

  get '/recent/:page' do
    mysql = connection
    user  = get_user

    page  = params["page"].to_i
    total = redis.llen('memo:public:ids')
    memo_ids = redis.lrange('memo:public:ids', page * 100, (page + 1) * 100 - 1)
    memos = memo_ids.empty? ? [] :
      mysql.xquery('SELECT id, user, header, created_at FROM memos WHERE id IN (?) ORDER BY created_at DESC, id DESC', memo_ids)
    if memos.count == 0
      halt 404, "404 Not Found"
    end
    memos.each do |row|
      row["username"] = $users[row['user']]['username']
    end
    erb :index, :layout => :base, :locals => {
      :memos => memos,
      :page  => page,
      :total => total,
      :user  => user,
    }
  end

  post '/signout' do
    user = get_user
    require_user(user)
    anti_csrf

    session.destroy
    redirect "/"
  end

  get '/signin' do
    user = get_user
    erb :signin, :layout => :base, :locals => {
      :user => user,
    }
  end

  post '/signin' do
    mysql = connection

    username = params[:username]
    password = params[:password]
    user = $users[$usernames[username]]
    if user && user["password"] == Digest::SHA256.hexdigest(user["salt"] + password)
      session.clear
      session["user_id"] = user["id"]
      session["token"] = Digest::SHA256.hexdigest(Random.new.rand.to_s)
      redirect "/mypage"
    else
      erb :signin, :layout => :base, :locals => {
        :user => {},
      }
    end
  end

  get '/mypage' do
    mysql = connection
    user  = get_user
    require_user(user)

    memos = mysql.xquery('SELECT id, header, is_private, created_at FROM memos WHERE user=? ORDER BY created_at DESC', user["id"])
    erb :mypage, :layout => :base, :locals => {
      :user  => user,
      :memos => memos,
    }
  end

  get '/memo/:memo_id' do
    mysql = connection
    user  = get_user

    memo = mysql.xquery('SELECT id, user, content, is_private, created_at FROM memos WHERE id=?', params[:memo_id]).first
    unless memo
      halt 404, "404 Not Found"
    end
    if memo["is_private"] == 1
      if user["id"] != memo["user"]
        halt 404, "404 Not Found"
      end
    end
    memo["username"] = $users[memo['user']]['username']
    memo["content_html"] = gen_markdown(memo["content"])
    if user["id"] == memo["user"]
      cond = ""
    else
      cond = "AND is_private=0"
    end
    memos = []
    older = nil
    newer = nil
    results = mysql.xquery("SELECT * FROM memos WHERE user=? #{cond} ORDER BY created_at", memo["user"])
    results.each do |m|
      memos.push(m)
    end
    0.upto(memos.count - 1).each do |i|
      if memos[i]["id"] == memo["id"]
        older = memos[i - 1] if i > 0
        newer = memos[i + 1] if i < memos.count
      end
    end
    erb :memo, :layout => :base, :locals => {
      :user  => user,
      :memo  => memo,
      :older => older,
      :newer => newer,
    }
  end

  post '/memo' do
    mysql = connection
    user  = get_user
    require_user(user)
    anti_csrf

    mysql.xquery(
      'INSERT INTO memos (user, content, header, is_private, created_at) VALUES (?, ?, ?, ?, ?)',
      user["id"],
      params["content"],
      Util.memo_header(params['content']),
      params["is_private"].to_i,
      Time.now,
    )
    memo_id = mysql.last_id
    if params["is_private"].to_i == 0
      redis.lpush('memo:public:ids', memo_id)
    end
    redirect "/memo/#{memo_id}"
  end

  run! if app_file == $0
end
