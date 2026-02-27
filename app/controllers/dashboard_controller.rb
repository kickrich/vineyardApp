class DashboardController < ApplicationController
  def index
    @videos = Video.order(created_at: :desc).limit(10)
  end

  def show
    @video = Video.find(params[:id])
  end
end