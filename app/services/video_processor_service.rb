require 'faraday'
require 'faraday/multipart'

class VideoProcessorService
  def initialize(video)
    @video = video
    @cv_service_url = ENV.fetch('CV_SERVICE_URL', 'http://localhost:8000')
  end

  def process
    @video.update!(status: :processing)
    
    response = send_video_to_cv_service
    
    if response.success?
      { success: true, message: "Видео отправлено на обработку" }
    else
      @video.update!(status: :error)
      { success: false, error: "Ошибка сервиса обработки" }
    end
  rescue => e
    @video.update!(status: :error)
    { success: false, error: e.message }
  end

  private

  def send_video_to_cv_service
    unless @video.video_file.attached?
      raise "Видео файл не прикреплен"
    end

    blob = @video.video_file.blob
    
    temp_file = Tempfile.new(["video_#{@video.id}".force_encoding('UTF-8'), '.mp4'])
    temp_file.binmode
    
    blob.open do |file|
      IO.copy_stream(file, temp_file)
    end
    
    temp_file.rewind
    
    file_size = File.size(temp_file.path)
    
    if file_size == 0
      raise "Скачанный файл имеет нулевой размер"
    end

    conn = Faraday.new(url: @cv_service_url) do |faraday|
      faraday.request :multipart
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = 300
    end

    callback_url = "http://host.docker.internal:3000/api/videos/#{@video.id}/detections"

    payload = {
      video_id: @video.id.to_s,
      video_file: Faraday::UploadIO.new(temp_file.path, 'video/mp4', 'video.mp4'),
      callback_url: callback_url
    }

    response = conn.post('/process_video') do |req|
      req.body = payload
    end

    response
  rescue => e
    raise
  ensure
    temp_file.close if temp_file
    temp_file.unlink if temp_file
  end
end