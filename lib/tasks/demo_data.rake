desc "Add demo content without deleting existing records"
task({ demo_data: :environment }) do
  demo = User.find_or_create_by!(email: "demo@repboard.com") do |u|
    u.password = "password123"
    u.display_name = "Demo Admin"
    u.bio = "Personal demo account - use demo@repboard.com / password123 to log in."
    u.reviewable = true
  end

  puts "Demo account: #{demo.display_name} (#{demo.email})"
  puts "Users: #{User.count}"
end
