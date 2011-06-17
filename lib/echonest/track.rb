require "rack"

module Echonest
  class Track
    CONFIDENCE_THRESHOLD = 0.85
    SIMILARITY_THRESHOLD = 0.2

    attr_accessor :data

    def self.all
      keys = Echonest.store.keys("echonest:track:*")
      keys.empty? ? [] : Echonest.store.mget(*keys).map { |data| new(JSON.parse(data)) }
    end

    def self.create(filename)
      data = upload(filename)
      new(data["track"]).save
    end

    def self.upload(filename)
      extension = File.extname(filename).delete(".")
      path = "track/upload?api_key=#{Echonest.config.api_key}&filetype=#{extension}&bucket=audio_summary"
      payload = Faraday::UploadIO.new(filename, "audio/#{extension}")
      headers = {
        :"Content-Type" => "application/octet-stream",
        :"Content-Length" => File.size(filename).to_s,
      }
      Echonest.post(path, payload, headers)
    end

    def initialize(data)
      self.data = data
    end

    def id
      data["id"]
    end

    def identifier
      "echonest:track:#{id}"
    end

    # def analysis_url
    #   response = Echonest.post("track/analyze", {
    #     :id => id,
    #     :bucket => "audio_summary",
    #     :api_key => Echonest.config.api_key
    #   })
    #   Rack::Utils.unescape(response["track"]["audio_summary"]["analysis_url"])
    # end
    #
    # def analyze
    #   response = Echonest.connection.get(analysis_url)
    # end
    def analyze
      response = Echonest.post("track/analyze", {
        :id => id,
        :bucket => "audio_summary",
        :api_key => Echonest.config.api_key
      })
      if response["status"]["message"] == "Success"
        uri = URI.parse(response["track"]["audio_summary"]["analysis_url"])
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        self.data.merge!(JSON.parse(response.body))
        save
      else
        response
      end
    end

    def save
      Echonest.store.set(identifier, data.to_json)
      self
    end

    def destroy
      Echonest.store.del(identifier)
      self
    end

    def similar_to?(other)
      sum = [distances.size, other.distances.size].max.times.inject(0) do |m, i|
        m += ((distances[i] || 0) - (other.distances[i] || 0)) ** 2
      end
      Math.sqrt(sum) < SIMILARITY_THRESHOLD
    end

    def beats
      @beats ||= begin
        analyze unless data["segments"]
        data["segments"]
          .select { |beat| beat["confidence"] >= CONFIDENCE_THRESHOLD }
          .map    { |beat| beat["start"] }
      end
    end

    def distances
      @distances ||= (beats.size - 1).times.map do |element|
        beats[element + 1] - beats[element]
      end
    end

  end
end
