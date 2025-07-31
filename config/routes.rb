Rails.application.routes.draw do
  # Health check route
  
  get "up" => "rails/health#show", as: :rails_health_check

  # Products resource with all necessary routes
  resources :products do
    collection do
      get :export  # GET /products/export
      get :bulk_import  # GET /products/bulk_import
      post :process_bulk_import  # POST /products/process_bulk_import
      get :download_template  # GET /products/download_template
    end

    member do
      get :confirm_delete  # GET /products/:id/confirm_delete
      patch :update_stock  # PATCH /products/:id/update_stock
    end
  end

  # Custom stock update route
  patch "/products/:id/stock_update", to: "products#update_stock", as: :stock_update

  # Root route
  root "products#index"
end