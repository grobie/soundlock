require "sinatra"

require_relative "lib/samplesumo"
require_relative "lib/canoris"

Samplesumo.configure do |config|
  config.api_root = "http://api.samplesumo.com/melotranscript"
  config.api_key  = "CCC8094CEEAC3B9AAFDAACC49857CD12"
end

Canoris.configure do |config|
  config.api_root   = "http://api.canoris.com"
  config.api_key    = "84253000f4f14d1ead5bca322ee14b78"
  config.api_secret = "964ceb2f290e472684be5ae453130f35"
end

get "/" do
  erb :index
end

post "/upload" do
  params.inspect
end