Rails.application.routes.draw do
  root "rooms#index"

  resources :rooms, only: [ :index, :show ] do
    resources :messages, only: [ :create ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
