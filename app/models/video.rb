class Video < ApplicationRecord
    has_one :detection
    has_one_attached :video_file

    validate :video_constraints

    enum :status, {
        uploaded: 0,
        processing: 1,
        done: 2,
        unprocessable_entity: 3,
        error: 4
    }

    private

private

    def video_constraints

        return unless video_file.attached?

        movie = FFMPEG::Movie.new(video_file.download)

        unless movie.valid?
            errors.add(:video_file, "не удалось прочитать видео")
            return
        end

        if video_file.byte_size < 1.megabyte
            errors.add(:video_file, "слишком маленький файл")
        elsif video_file.byte_size > 2.gigabytes
            errors.add(:video_file, "слишком большой файл")
        end

        allowed_types = [
            "video/mp4",
            "video/quicktime",
            "video/x-msvideo",
            "video/x-matroska"
        ]
        unless allowed_types.include?(video_file.content_type)
            errors.add(:video_file, "#{video_file.filename} не является допустимым видеоформатом")
        end

        if movie.duration < 5
            errors.add(:video_file, "слишком короткое видео (минимум 5 секунд)")
        elsif movie.duration > 600
            errors.add(:video_file, "слишком длинное видео (максимум 10 минут)")
        end

        if movie.width < 1280 || movie.height < 720
            errors.add(:video_file, "слишком низкое разрешение (минимум 1280x720)")
        end

        if movie.frame_rate < 30
            errors.add(:video_file, "слишком низкая частота кадров (минимум 30 fps)")
        end
    end

end
