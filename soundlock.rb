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
  set :root,    File.expand_path(File.dirname(__FILE__))
  set :public,  File.expand_path("public",  settings.root)
  set :solvers, File.expand_path("solvers", settings.public)
  set :locks,   File.expand_path("locks",   settings.public)

  get "/" do
    @locks = Echonest::Track.all.select(&:lock?)
    erb :index
  end

  post "/record" do
    lock = upload(params[:file])
    "{\"location\": \"/lock/#{lock.id}\"}"
  end

  get "/lock/:id" do
    if @lock = Echonest::Track.find(params[:id])
      erb :show
    else
      erb :error
    end
  end

  get "/solver/:id" do
    if @solver = Echonest::Track.find(params[:id])
      erb :solved
    else
      erb :error
    end
  end

  post "/lock/:id" do
    @lock = Echonest::Track.find(params[:id])
    if @lock && (@solver = upload(params[:file], @lock)) && @solver.similar_to?(@lock)
      "{\"location\": \"/solver/#{@solver.id}\"}"
    else
      erb :error
    end
  end

  def upload(upload, lock = nil)
    destination = File.join(lock ? settings.solvers : settings.locks, "#{Time.now.to_i}.wav")
    if FileUtils.mv(upload[:tempfile].path, destination) && FileUtils.chmod(0640, destination)
      Echonest::Track.create("file_location" => destination, "lock_id" => lock && lock.id)
    end
  end
end
