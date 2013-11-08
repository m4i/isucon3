require './app'

use Rack::Runtime

require 'rack-mini-profiler'
profiler_path = '/tmp/miniprofiler'
Dir.mkdir(profiler_path) unless File.exist?(profiler_path)
Rack::MiniProfiler.config.storage         = Rack::MiniProfiler::FileStore
Rack::MiniProfiler.config.storage_options = { path: profiler_path }
use Rack::MiniProfiler

run Isucon3App
