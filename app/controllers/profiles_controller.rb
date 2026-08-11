class ProfilesController < ApplicationController
  def show
    slug = params.fetch("slug")
    @freelancer = User.find_by(slug: slug)

    if @freelancer.nil?
      redirect_to root_path, alert: "Profile not found."
    else
      @reviews = @freelancer.public_reviews.includes(:reviewer).recent
      @new_review = Review.new
    end
  end
end
