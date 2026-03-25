class SendResultsToExternalServiceJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    
    return unless video.external_service?
    return unless video.status == 'completed'

    service = SendResultsToExternalServiceService.new(video)
    service.send_results
  rescue => e
    Rails.logger.error("SendResultsToExternalServiceJob error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end
end
