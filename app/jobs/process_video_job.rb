class ProcessVideoJob < ApplicationJob
  include ActiveJob::Status
  
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    
    progress.total = 100
    
    status.update(step: "Подготовка видео", progress: 0, message: "Начинаем обработку...")
    progress.progress = 10
    
    status.update(step: "Обновление статуса", message: "Видео отправляется на обработку")
    video.update!(status: :processing)
    progress.progress = 15
    
    status.update(step: "Отправка в CV сервис", message: "Отправляем видео на анализ...")
    service = VideoProcessorService.new(video)
    progress.progress = 20
    
    status.update(step: "Обработка видео", message: "CV сервис анализирует видео...")
    
    result = service.process
    
    status.update(step: "Сохранение результатов", message: "Сохраняем результаты анализа...", progress: 85)
    
    if result[:success]
      video.reload
      if video.detection.present?
        status.update(step: "Готово", message: "Обработка завершена успешно", progress: 100)
      else
        status.update(step: "Ошибка", message: "Детекция не создана", progress: 0)
      end
    else
      status.update(step: "Ошибка", message: result[:error], progress: 0)
    end
  rescue => e
    status.update(step: "Ошибка", message: e.message, progress: 0)
    raise
  end
end
