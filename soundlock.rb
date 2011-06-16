require "fileutils"
require "sinatra/base"
begin
  require 'sinatra/reloader'
rescue LoadError
end

require_relative "lib/samplesumo"
# require_relative "lib/canoris"

Samplesumo.configure do |config|
  config.api_root = "http://api.samplesumo.com/melotranscript"
  config.api_key  = "CCC8094CEEAC3B9AAFDAACC49857CD12"
end

# Canoris.configure do |config|
#   config.api_root   = "http://api.canoris.com"
#   config.api_key    = "84253000f4f14d1ead5bca322ee14b78"
#   config.api_secret = "964ceb2f290e472684be5ae453130f35"
# end

class Soundlock < Sinatra::Base
  set :root,   File.expand_path(File.dirname(__FILE__))
  set :public, File.expand_path('public', settings.root)
  set :files,  File.expand_path("resources", settings.root)

  get "/" do
    erb :index
  end

  post "/record" do
    upload = params[:file]
    destination = File.join(settings.files, "upload#{Time.now.to_i}.wav")
    FileUtils.mv(upload[:tempfile].path, destination) && FileUtils.chmod(0640, destination)

    puts Samplesumo.upload(destination)

    "saved"
  end

  get "/upload/:id" do
    Samplesumo.upload(params[:id])
  end
end
