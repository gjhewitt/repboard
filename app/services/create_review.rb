class CreateReview
  attr_reader :review, :error

  def initialize(reviewer:, reviewee_id:, body:, stars:)
    @reviewer = reviewer
    @reviewee_id = reviewee_id
    @body = body
    @stars = stars
  end

  def call
    @review = Review.new(
      reviewer: @reviewer,
      reviewee_id: @reviewee_id,
      body: @body,
      stars: @stars
    )

    if @review.save
      true
    else
      @error = @review.errors.full_messages.to_sentence
      false
    end
  end
end
