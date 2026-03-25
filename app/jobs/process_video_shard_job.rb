class ProcessVideoShardJob < ApplicationJob
  include ActiveJob::Status
  
  queue_as :default

  def perform(shard_id)
    shard = VideoShard.find(shard_id)
    shard.update!(status: :processing, job_id: self.job_id)

    service = VideoShardProcessorService.new(shard)
    result = service.process

    unless result[:success]
      # Обновляем статус без валидации, чтобы ошибки в проверке видео не мешали смене статуса
      shard.update_column(:status, VideoShard.statuses[:error])
    end
  rescue => e
    Rails.logger.error("ProcessVideoShardJob error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    shard.update_column(:status, VideoShard.statuses[:error]) if shard&.persisted?
  end
end