require "json"
require "faraday"

require_relative "canoris/config"

module Canoris

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield(config)
  end

  def self.connection
    @connection ||= begin
      Faraday.new(:url => config.api_root, :params => { :api_key => config.api_key }) do |builder|
        builder.request :multipart
        builder.request :url_encoded
        builder.request :json

        builder.adapter :net_http
      end
    end
  end

  def self.files(collection = nil)
    get(collection ? "collections/#{collection["key"]}/files" : "files")
  end

  def self.upload(filename)
    post("files", :file => Faraday::UploadIO.new(filename, "audio/mp3"))
  end

  def self.collections
    get("collections")
  end

  def self.create_collection(name)
    post("collections", :name => name, :license => "CC_AT")
  end

  def self.add_file_to_collection(collection, file)
    post("collections/#{collection["key"]}/files", :filekey => file["key"])
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
