Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "login", to: "sessions#create"
      delete "logout", to: "sessions#destroy"
      get "parties", to: "parties#index"
      resources :properties
      scope "properties/:property_id" do
        post "photos",       to: "property_photos#create"
        get  "portfolio",    to: "portfolio#show"
        get  "buildings",    to: "buildings#index"
        get  "units",        to: "units#index"
        get  "inspections",  to: "inspections#index"
        post "inspections",  to: "inspections#create"
        get  "inspections/:inspection_id",   to: "inspection_detail#show",   as: :inspection_detail
        patch "inspections/:inspection_id",  to: "inspection_detail#update"
        get  "inspections/:inspection_id/photos", to: "inspection_photos#index",  as: :inspection_photos
        post "inspections/:inspection_id/photos", to: "inspection_photos#create"
        get  "ownership",    to: "ownership#index"
        post "ownership",    to: "ownership#create"
        post "ownership/transfers", to: "ownership#transfer"
        patch "ownership/:ownership_id", to: "ownership#update"
        post "ownership/:ownership_id/close", to: "ownership#close"
        get "ownership/:ownership_id/documents", to: "ownership_documents#index"
        post "ownership/:ownership_id/documents", to: "ownership_documents#create"
        get  "assignments",  to: "assignments#index"
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
