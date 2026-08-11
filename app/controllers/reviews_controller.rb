class ReviewsController < ApplicationController
  before_action :authenticate_user!, only: [ :create, :destroy, :moderate ]

  def create
    service = CreateReview.new(**review_params.to_h.symbolize_keys, reviewer: current_user)

    if service.call
      redirect_to profile_path(service.review.reviewee.slug), notice: "Review submitted successfully."
    else
      reviewee = User.find(review_params[:reviewee_id])
      redirect_to profile_path(reviewee.slug), alert: service.error
    end
  end

  def destroy
    the_id = params.fetch(:id)
    the_review = Review.find(the_id)

    if the_review.reviewer_id == current_user.id
      the_review.destroy
      redirect_to profile_path(the_review.reviewee.slug), notice: "Review deleted."
    else
      redirect_to profile_path(the_review.reviewee.slug), alert: "Not authorized."
    end
  end

  def moderate
    review = Review.find(params[:id])

    if review.reviewee_id != current_user.id
      redirect_to root_path, alert: "Not authorized."
      return
    end

    new_status = params[:status]

    unless Review.statuses.key?(new_status)
      redirect_to dashboard_path, alert: "Invalid status."
      return
    end

    review.update!(status: new_status)
    redirect_to dashboard_path, notice: "Review marked as #{new_status}."
  end

  private

  def review_params
    params.require(:review).permit(:body, :stars, :reviewee_id)
  end
end
