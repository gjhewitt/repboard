# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  avatar_url             :string
#  bio                    :text
#  display_name           :string
#  email                  :citext           default(""), not null
#  encrypted_password     :string           default(""), not null
#  links_count            :integer          default(0), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  reviewable             :boolean          default(FALSE)
#  reviews_given_count    :integer          default(0), not null
#  reviews_received_count :integer          default(0), not null
#  slug                   :citext
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_display_name          (display_name)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_slug                  (slug) UNIQUE
#
class User < ApplicationRecord
  include Sluggable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :slug, uniqueness: true, allow_nil: true
  validates :display_name, presence: true, length: { maximum: 60 }
  validates :bio, length: { maximum: 500 }, allow_nil: true

  has_many :reviews_given, class_name: "Review", foreign_key: "reviewer_id", dependent: :destroy
  has_many :reviews_received, class_name: "Review", foreign_key: "reviewee_id", dependent: :destroy
  # Reviews a visitor can see. Excludes hidden and flagged rows, so public rating stats can't disagree with the list rendered on the profile page.
  has_many :public_reviews,
           -> { published },
           class_name: "Review", foreign_key: :reviewee_id, inverse_of: :reviewee

  has_many :links, dependent: :destroy
  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: :all_blank
  scope :freelancers, -> { where(reviewable: true) }

  def average_rating
    public_reviews.average(:stars)&.round(1)
  end

  def review_count
    public_reviews.count
  end
end
