require './app'

use Rack::Runtime

require 'rack/contrib/profiler'
use Rack::Profiler

run Isucon3App
