Rails.application.routes.draw do
  resources :properties do
    collection do
      get :set_all
      post :delete_selected
      get :edit_multiple
      put :update_multiple
    end
  end
  resources :products do
    collection do
      get :get_file
      get :get_file_vstrade
      get :load_by_api
      get :edit_multiple
      put :update_multiple
      post :delete_selected
      get :csv_param
      get :set_cattitle
      get :insales_param
    end
  end
  root to: 'visitors#index'
  devise_for :users
  resources :users
end
