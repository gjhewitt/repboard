class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @reviews = current_user.reviews_received.includes(:reviewer).recent

    if params[:stars].present?
      @reviews = @reviews.where(stars: params[:stars])
    end

    @reviews = @reviews.page(params[:page]).per(10)

    @chart_data = current_user.reviews_received
                              .group_by_month(:created_at)
                              .average(:stars)
  end
end
