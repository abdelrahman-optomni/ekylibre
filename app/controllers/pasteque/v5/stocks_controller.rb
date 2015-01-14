class Pasteque::V5::StocksController < Pasteque::V5::BaseController
  manage_restfully only: [:index, :search], model: :product, search_filters: {locationId: :default_storage_id}
end
