class Api::MissionsController < ApplicationController
  protect_from_forgery with: :null_session

  # Создание нового видео с миссией от внешнего сервиса
  # POST /api/missions/create
  # Параметры:
  # - mission_id (required): ID миссии от внешнего сервиса
  # - external_service_url (required): URL внешнего сервиса для отправки результатов
  # - external_callback_token (optional): Токен для безопасности
  # - name (optional): Имя видео
  def create
    mission_id = params[:mission_id]
    external_service_url = params[:external_service_url]
    external_callback_token = params[:external_callback_token]
    name = params[:name] || "Миссия #{mission_id} - #{Time.current.strftime('%Y-%m-%d %H:%M')}"

    unless mission_id.present? && external_service_url.present?
      return render json: { 
        error: "mission_id и external_service_url обязательны" 
      }, status: :unprocessable_entity
    end

    # Проверяем что видео с такой миссией еще не создано
    if Video.exists?(mission_id: mission_id)
      return render json: { 
        error: "Видео для этой миссии уже существует" 
      }, status: :conflict
    end

    video = Video.new(
      mission_id: mission_id,
      external_service_url: external_service_url,
      external_callback_token: external_callback_token,
      name: name,
      status: :uploading
    )

    if video.save
      render json: {
        id: video.id,
        mission_id: video.mission_id,
        name: video.name,
        status: video.status,
        message: "Видео создано, можно загружать шарды"
      }, status: :created
    else
      render json: { error: video.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Загрузка шарда видео для миссии
  # POST /api/missions/upload_shard
  # Параметры:
  # - mission_id (required): ID миссии
  # - shard_index (required): Индекс шарда (1, 2, 3...)
  # - video (required): Файл видео
  # - external_service_url (optional): URL внешнего сервиса для отправки результатов
  # - external_callback_token (optional): Токен для безопасности
  # - name (optional): Имя видео (если видео создаётся автоматически)
  def upload_shard
    mission_id = params[:mission_id]
    shard_index = params[:shard_index].to_i
    external_service_url = params[:external_service_url]
    external_callback_token = params[:external_callback_token]
    name = params[:name]

    unless mission_id.present?
      return render json: { error: "mission_id обязателен" }, status: :unprocessable_entity
    end

    video = Video.find_by(mission_id: mission_id)
    
    # Если видео не найдено, создаём его автоматически
    unless video
      video_name = name || "Миссия #{mission_id} - #{Time.current.strftime('%Y-%m-%d %H:%M')}"
      
      video = Video.new(
        mission_id: mission_id,
        external_service_url: external_service_url,
        external_callback_token: external_callback_token,
        name: video_name,
        status: :uploading
      )
      
      unless video.save
        return render json: { error: video.errors.full_messages }, status: :unprocessable_entity
      end
    end

    unless params[:video]
      return render json: { error: "Файл не выбран" }, status: :unprocessable_entity
    end

    if video.video_shards.exists?(shard_index: shard_index)
      return render json: { error: "Shard #{shard_index} уже загружен" }, status: :conflict
    end

    shard = video.video_shards.new(
      shard_index: shard_index,
      original_filename: params[:video].original_filename,
      status: :pending
    )

    if shard.save
      shard.video_file.attach(params[:video])
      
      unless shard.video_file.attached?
        shard.destroy
        return render json: { error: "Не удалось прикрепить файл" }, status: :unprocessable_entity
      end
      
      job = ProcessVideoShardJob.perform_later(shard.id)
      shard.update!(job_id: job.job_id)
      
      # Обновляем статус видео
      video.update!(status: :processing) if video.uploading?
      
      render json: {
        id: shard.id,
        video_id: video.id,
        mission_id: mission_id,
        shard_index: shard_index,
        status: shard.status,
        message: "Shard #{shard_index} загружен и поставлен в очередь на обработку"
      }, status: :created
    else
      render json: { error: shard.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Получить статус видео/миссии
  # GET /api/missions/:mission_id/status
  def status
    mission_id = params[:mission_id]
    video = Video.find_by(mission_id: mission_id)

    unless video
      return render json: { error: "Видео с этой миссией не найден" }, status: :not_found
    end

    render json: video.aggregated_results, status: :ok
  end
end
