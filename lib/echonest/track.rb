module Echonest
  class Track
    EVENT_CONFIDENCE   = 0.85
    TONE_CONFIDENCE    = 0.85
    SIMILARITY_MINIMUM = 0.75



    attr_accessor :data

    def self.all(keys = Echonest.store.keys("echonest:lock:*"))
      keys.nil? || keys.empty? ? [] : Echonest.store.mget(*keys).map do |data|
        new(JSON.parse(data))
      end
    end

    def self.create(options = {})
      data = upload(options["file_location"])
      attributes = data["track"].merge(options).merge("created_at" => Time.now.to_i)
      record = new(attributes).save
      if record.lock
        Echonest.store.rpush("echonest:solvers:#{record.lock.id}", record.identifier)
      end
      record
    end

    def self.find(id)
      data = Echonest.store.get("echonest:lock:#{id}")
      data ? new(JSON.parse(data)) : nil
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
      "echonest:lock:#{id}"
    end

    def solvers
      @solvers ||= self.class.all(Echonest.store.lrange("echonest:solvers:#{id}", 0, -1))
    end

    def lock_id
      data["lock_id"]
    end

    def lock
      @lock ||= lock_id ? self.class.find(lock_id) : nil
    end

    def lock?
      lock_id.nil?
    end

    def valid?
      !lock? && similar_to?(lock)
    end

    def created_at
      Time.at(data["created_at"].to_i)
    end

    def filename
      File.basename(data["file_location"])
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

    # TODO delete file
    def destroy
      Echonest.store.del(identifier)
      self
    end

    def rhythm_distance_to(other)
      euclid(rhythm_distances, other.rhythm_distances)
    end

    def tone_distance_to(other)
      euclid(tone_distances, other.tone_distances)
    end

    def distance_to(other)
      # (2 * rhythm_distance_to(other) + tone_distance_to(other)) / 3
      rhythm_distance_to(other)
    end

    def similar_to?(other)
      distance_to(other) < SIMILARITY_MINIMUM
    end

    def events
      @events ||= begin
        analyze unless data["segments"]
        data["segments"].select { |event| event["confidence"] >= EVENT_CONFIDENCE }
      end
    end

    def beats
      @beats ||= events.map { |event| event["start"] }
    end

    def rhythm_distances
      @rhythm_distances ||= (beats.size - 1).times.map do |element|
        beats[element + 1] - beats[element]
      end
    end

    # return value is 0..11
    # C - Cis/Des - D - Dis/Es - E - F - Fis/Ges - G - Gis/As - A - Ais/B - H
    def tones
      @tones ||= events.map do |event|
        event["pitches"].index(event["pitches"].max)
      end
    end

    def tone_distances
      @tone_distances ||= (tones.size - 1).times.map do |element|
        a, b = tones[element + 1], tones[element]
        a > b ? a - b : b - a
      end
    end

  private

    def euclid(array1, array2)
      sum = [array1.size, array2.size].max.times.inject(0) do |m, i|
        m += ((array1[i] || 0) - (array2[i] || 0)) ** 2
      end
      Math.sqrt(sum)
    end

  end
end
