class Api::VideosController < ApplicationController
  protect_from_forgery with: :null_session, only: [:create]

  def create
    unless params[:video]
      return render json: { error: "Файл не выбран" }, status: :unprocessable_entity
    end

    video = Video.new(
      status: :uploaded,
      original_filename: params[:video].original_filename
    )

    if video.save
      video.video_file.attach(params[:video])
      
      unless video.video_file.attached?
        video.destroy
        return render json: { error: "Не удалось прикрепить файл" }, status: :unprocessable_entity
      end
      
      if video.valid?
        job = ProcessVideoJob.perform_later(video.id)
        video.update!(job_id: job.job_id)
        
        render json: {
          id: video.id,
          status: video.status,
          job_id: job.job_id,
          message: "Видео загружено и поставлено в очередь на обработку"
        }, status: :created
      else
        error_messages = video.errors.full_messages.join(", ")
        video.destroy
        render json: { error: error_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: video.errors.full_messages.join(", ") },
             status: :unprocessable_entity
    end
  end

  def job_status
    video = Video.find(params[:id])
    
    if video.job_id.present?
      status = ActiveJob::Status.get(video.job_id)
      
      if status.present?
        render json: {
          job_id: video.job_id,
          status: status.status.to_s,
          progress: status[:progress] || 0,
          step: status[:step] || "Обработка...",
          total: status[:total] || 100,
          message: status[:message] || "Идет обработка..."
        }
      else
        render json: {
          job_id: video.job_id,
          status: "not_found",
          progress: 0,
          step: "Не найден",
          total: 100,
          message: "Статус задачи не найден"
        }
      end
    else
      render json: { error: "Job не найден" }, status: :not_found
    end
  end

  def show
    video = Video.find(params[:id])
    
    response = {
      id: video.id,
      status: video.status,
      original_filename: video.original_filename,
      created_at: video.created_at
    }
    
    if video.detection.present?
      response[:detection] = {
        id: video.detection.id,
        bushes_count: video.detection.bushes_count,
        gaps_count: video.detection.gaps_count,
        row_spacing: video.detection.row_spacing,
        bush_spacing_avg: video.detection.bush_spacing_avg,
        processed_at: video.detection.created_at
      }
    end
    
    render json: response
  end

  def index
    videos = Video.order(created_at: :desc).limit(100)
    
    render json: videos.map { |v|
      {
        id: v.id,
        status: v.status,
        original_filename: v.original_filename,
        created_at: v.created_at,
        has_detection: v.detection.present?
      }
    }
  end
end