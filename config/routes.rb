Rails.application.routes.draw do
  resources :random_numbers, only: [:index]
end
