Tahi::Application.routes.draw do
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'
  devise_for :users
  devise_scope :user do
    get "users/sign_out" => "devise/sessions#destroy"
  end

  get '/papers/:id/manage' => 'ember#index'

  resources :journals, only: [:index]

  get '/flow_manager' => 'ember#index'

  # give me a better name
  resources :flows, only: [:index, :destroy, :create]

  resources :papers, only: [:new, :create, :show, :edit, :update] do
    resources :figures, only: :create
    resources :submissions, only: [:new, :create]
    resources :tasks, only: [:update, :create, :show, :destroy] do
      resources :comments, only: :create
    end

    resources :messages, only: [:create] do
      member do
        patch :update_participants
      end
    end

    member do
      patch :upload
      get :manage, to: 'tasks#index'
    end
  end

  resources :comments, only: :create

  resources :message_tasks, only: [:create] do
    member do
      patch :update_participants
    end
  end

  resources :tasks, only: [:update, :create, :show, :destroy]

  resources :phases, only: [:create, :update, :destroy]

  resources :declarations, only: [:update]

  get 'users/chosen_options', to: 'user_info#thumbnails', defaults: {format: 'json'}
  get 'users/dashboard_info', to: 'user_info#dashboard', defaults: {format: 'json'}

  resource :user_settings, only: :update
  root 'ember#index'
end
