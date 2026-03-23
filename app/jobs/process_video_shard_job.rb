class ProcessVideoShardJob < ApplicationJob
  include ActiveJob::Status
  
  queue_as :default

  def perform(shard_id)
    shard = VideoShard.find(shard_id)
    shard.update!(status: :processing, job_id: self.job_id)
    
    service = VideoShardProcessorService.new(shard)
    service.process  
  end
end