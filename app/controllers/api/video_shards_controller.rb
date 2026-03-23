class Api::VideoShardsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:results]

  def results
    shard = VideoShard.find(params[:id])
    
    shard.update!(
      bushes_count: params[:bushes_count],
      gaps_count: params[:gaps_count],
      bush_spacing_avg: params[:bush_spacing_avg],
      result_json: params[:result_json],
      recorded_at: Time.current,
      status: :completed
    )
    
    render json: { success: true, message: "Результаты сохранены" }
  end

  def destroy
    shard = VideoShard.find(params[:id])
    video = shard.video
    
    shard.destroy!
    
    video.recalculate_status!
    
    render json: { 
      message: "Шард успешно удален",
      video_status: video.status,
      shards_count: video.video_shards.count
    }, status: :ok
  end

end