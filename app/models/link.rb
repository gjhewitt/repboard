# == Schema Information
#
# Table name: links
#
#  id         :bigint           not null, primary key
#  label      :string
#  position   :integer
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_links_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Link < ApplicationRecord
  belongs_to :user, counter_cache: true

  validates :label, presence: true, length: { maximum: 50 }
  validates :url, presence: true,
                  format: { with: %r{\Ahttps?://\S+\z}i,
                            message: "must start with http:// or https://" }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
