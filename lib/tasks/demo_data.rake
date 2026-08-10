desc "Add demo content without deleting existing records"
task({ demo_data: :environment }) do
  demo = User.find_or_create_by!(email: "demo@repboard.com") do |u|
    u.password = "password123"
    u.display_name = "Demo Admin"
    u.bio = "Personal demo account - use demo@repboard.com / password123 to log in."
    u.reviewable = true
  end

  freelancers = [
    { name: "Maya Okonkwo",    bio: "Brand and packaging designer. Six years with independent food and beverage brands." },
    { name: "Dev Ramachandran", bio: "Full-stack developer. Rails and Postgres for early-stage startups, usually the first engineer in." },
    { name: "Priya Latham",    bio: "Technical writer. API documentation and developer guides for B2B software teams." },
    { name: "Marcus Bell",     bio: "Video editor. Short-form social cuts and documentary-style founder interviews." },
    { name: "Sofia Reyes",     bio: "SEO and content strategy. I help small e-commerce shops stop paying for traffic they could earn." },
    { name: "Tomás Vidal",     bio: "Commercial photographer. Product and interiors, based in Chicago, available for travel." },
    { name: "Hannah Weiss",    bio: "Illustrator. Editorial work for magazines and the occasional children's book." },
    { name: "Ken Arai",        bio: "Fractional bookkeeper. Monthly close and cleanup for agencies and solo consultants." }
  ]

  freelancers.each_with_index do |attrs, i|
    User.find_or_create_by!(email: "demo.freelancer.#{i + 1}@repboard.com") do |u|
      u.password = SecureRandom.hex(24)
      u.display_name = attrs[:name]
      u.bio = attrs[:bio]
      u.reviewable = true
    end
  end

  puts "Demo account: #{demo.display_name} (#{demo.email})"
  puts "Users: #{User.count}"
end
