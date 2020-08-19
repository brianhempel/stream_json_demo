Rails.application.routes.draw do
  resources :random_numbers, only: [:index]
  resources :random_numbers2, only: [:index]
end
