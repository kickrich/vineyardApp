class Api::VideosController < ApplicationController
  protect_from_forgery with: :null_session, only: [:create]

  def new
  end

  def create
    return render json: { error: "Файл не выбран" }, status: :unprocessable_entity unless params[:video]

    video = Video.new(
      status: :uploaded,
      original_filename: params[:video].original_filename
    )

    video.video_file.attach(params[:video])

    unless video.save
      return render json: { error: video.errors.full_messages.join(", ") },
                   status: :unprocessable_entity
    end

    render json: {
      id: video.id,
      status: video.status
    }, status: :created
  end
end
