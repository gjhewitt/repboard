require "rails_helper"

RSpec.describe "Devise registration params", type: :request do
  describe "PATCH /users (account update)" do
    let(:client) do
      User.create!(email: "client@example.com", password: "password123",
                   display_name: "Test Client", reviewable: false)
    end

    before { sign_in client }

    it "does not let a client promote themselves to freelancer" do
      patch user_registration_path, params: {
        user: { display_name: "New Name", reviewable: "1", current_password: "password123" }
      }

      client.reload
      expect(client.display_name).to eq("New Name")
      expect(client.reviewable).to be(false)
    end
  end

  describe "POST /users (sign up)" do
    it "lets a new user choose freelancer at sign up (intentional)" do
      post user_registration_path, params: {
        user: {
          email: "new_freelancer@example.com",
          password: "password123",
          password_confirmation: "password123",
          display_name: "New Freelancer",
          reviewable: "1"
        }
      }

      new_user = User.find_by(email: "new_freelancer@example.com")
      expect(new_user).to be_present
      expect(new_user.reviewable).to be(true)
    end
  end
end
