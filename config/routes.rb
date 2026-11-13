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
        get  "leases", to: "leases#index"
        post "leases", to: "leases#create"
        get "maintenance_requests", to: "maintenance_requests#index"
        post "maintenance_requests", to: "maintenance_requests#create"
        get "maintenance_requests/:maintenance_request_id", to: "maintenance_requests#show", as: :maintenance_request
        patch "maintenance_requests/:maintenance_request_id", to: "maintenance_requests#update"
        post "maintenance_requests/:maintenance_request_id/acknowledge", to: "maintenance_requests#acknowledge"
        post "maintenance_requests/:maintenance_request_id/submit_for_approval", to: "maintenance_requests#submit_for_approval"
        post "maintenance_requests/:maintenance_request_id/approve", to: "maintenance_requests#approve"
        post "maintenance_requests/:maintenance_request_id/reject", to: "maintenance_requests#reject"
        post "maintenance_requests/:maintenance_request_id/schedule", to: "maintenance_requests#schedule"
        post "maintenance_requests/:maintenance_request_id/start", to: "maintenance_requests#start"
        post "maintenance_requests/:maintenance_request_id/complete", to: "maintenance_requests#complete"
        post "maintenance_requests/:maintenance_request_id/close", to: "maintenance_requests#close"
        post "maintenance_requests/:maintenance_request_id/cancel", to: "maintenance_requests#cancel"
        post "maintenance_requests/:maintenance_request_id/dispute_responsibility", to: "maintenance_requests#dispute_responsibility"
        post "maintenance_requests/:maintenance_request_id/allocations", to: "maintenance_requests#allocate_costs"
        post "maintenance_requests/:maintenance_request_id/financial_entries", to: "maintenance_requests#add_financial_entry"
        get "maintenance_requests/:maintenance_request_id/documents", to: "maintenance_request_documents#index"
        post "maintenance_requests/:maintenance_request_id/documents", to: "maintenance_request_documents#create"
        get "maintenance_schedules", to: "maintenance_schedules#index"
        post "maintenance_schedules", to: "maintenance_schedules#create"
        patch "maintenance_schedules/:maintenance_schedule_id", to: "maintenance_schedules#update"
        post "maintenance_schedules/:maintenance_schedule_id/pause", to: "maintenance_schedules#pause"
        post "maintenance_schedules/:maintenance_schedule_id/resume", to: "maintenance_schedules#resume"
        post "maintenance_schedules/:maintenance_schedule_id/generate", to: "maintenance_schedules#generate"
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
