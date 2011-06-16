require "json"
require "faraday"

require_relative "samplesumo/config"

module Samplesumo

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield(config)
  end

  def self.connection
    @connection ||= begin
      Faraday.new(:params => { :key => config.api_key }) do |builder|
        builder.request :multipart
        builder.request :url_encoded
        builder.request :json

        builder.adapter :net_http
      end
    end
  end

  def self.upload(filename)
    payload = { :file => Faraday::UploadIO.new(filename, "audio/mp3") }
    post("#{config.api_root}/upload", payload)["status_url"] || false
  end

  def self.processed?(url)
    case get(url)["state"]
    when "PE" then nil  # pending, we have to wait
    when "OK" then true # finished
    else false          # failed
    end
  end

  def self.result(url)
    loop do
      response = get(url)
      case response["state"]
      when "PE" then sleep(3)
      when "OK" then return response["results"]["json"]
      else           return false
      end
    end
  end

private

  def self.post(path, payload)
    response = connection.post(path, payload)
    JSON.parse(response.body)
  end

  def self.get(path)
    response = connection.get(path)
    JSON.parse(response.body)
  end
end
