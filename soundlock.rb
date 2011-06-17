require "fileutils"
require "sinatra/base"
begin
  require 'sinatra/reloader'
rescue LoadError
end

require_relative "lib/echonest"

Echonest.configure do |config|
  config.api_root = "http://developer.echonest.com/api/v4"
  config.api_key = "WIU43FOYVQXSRNV1V"
end

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

    Echonest::Track.create(destination)

    "saved"
  end

  get "/track/:id" do
    erb :show
  end
end
