Rails.application.routes.draw do
  root 'dashboard#index'
  get 'video/:id', to: 'dashboard#show', as: 'video'

  namespace :api do
    resources :videos, only: [:create, :show, :index] do
      member do
        get 'job_status'
      end
      resources :detections, only: [:create]
    end
    resources :detections, only: [:show]
  end
end
