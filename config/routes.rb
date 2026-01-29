Rails.application.routes.draw do
  root "api/videos#new"

  namespace :api do
    resources :videos, only: [:new, :create]
  end

  get "/upload", to: "api/videos#new"
end
