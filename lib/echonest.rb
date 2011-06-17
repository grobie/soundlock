require "json"
require "faraday"
require "redis"

require_relative "echonest/config"
require_relative "echonest/track"

module Echonest

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield(config)
  end

  def self.connection
    @connection ||= begin
      Faraday.new(:url => config.api_root) do |builder|
        builder.request :multipart
        builder.request :url_encoded
        builder.request :json

        builder.adapter :net_http
      end
    end
  end

  def self.store
    @store ||= Redis.new(:host => "localhost", :port => 6379)
  end

  def self.post(path, payload = {}, headers = {})
    puts "Echonest#post to #{path}"
    response = connection.post(path, payload, headers)
    puts "Echonest#post finished"
    JSON.parse(response.body)["response"]
  end

  def self.get(path)
    response = connection.get(path)
    JSON.parse(response.body)["response"]
  end

end
