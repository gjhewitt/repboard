desc "Reset the database and seed it with believable demo data"
task({ sample_data: :environment }) do
  starting = Time.now

  if Rails.env.production?
    puts "Refusing to run sample_data in production!"
    exit
  end

  puts "Wiping existing data..."
  Review.destroy_all
  Link.destroy_all
  User.destroy_all

  puts "Creating demo freelancer account..."
  demo = User.create!(
    email: "demo@repboard.com",
    password: "password123",
    display_name: "Demo Admin",
    bio: "Personal demo account — use email demo@repboard.com / password123 to log in.",
    reviewable: true,
    avatar_url: "https://i.pravatar.cc/300?img=16"
  )

  # A freelancer can't leave reviews, so demoing the client side needs its own login.
  puts "Creating demo client account..."
  demo_client = User.create!(
    email: "client@repboard.com",
    password: "password123",
    display_name: "Demo Client",
    bio: "Personal demo account — use email client@repboard.com / password123 to log in.",
    reviewable: false
  )

  puts "Creating freelancers..."
  freelancers = []
  15.times do |i|
    name = Faker::Name.unique.name
    freelancers << User.create!(
      email: Faker::Internet.unique.email(name: name),
      password: "password123",
      display_name: name,
      bio: "#{Faker::Company.catch_phrase}. #{Faker::Lorem.sentence(word_count: 12)}",
      reviewable: true,
      avatar_url: "https://i.pravatar.cc/300?img=#{i + 1}"
    )
  end

  # Only clients may leave reviews, so the seed data needs them or every
  # Review.create! below fails validation.
  puts "Creating clients..."
  clients = []
  12.times do
    name = Faker::Name.unique.name
    clients << User.create!(
      email: Faker::Internet.unique.email(name: name),
      password: "password123",
      display_name: name,
      bio: "Hires freelancers for #{Faker::Company.buzzword} projects.",
      reviewable: false
    )
  end

  puts "Creating portfolio links..."
  link_labels = [ "Portfolio", "LinkedIn", "GitHub", "Twitter", "Personal Site", "Blog" ]
  (freelancers + [ demo ]).each do |user|
    rand(2..4).times do |idx|
      Link.create!(
        user: user,
        label: link_labels.sample,
        url: "https://#{Faker::Internet.domain_name}",
        position: idx
      )
    end
  end

  # product yields every client/freelancer combination exactly once, so no
  # shuffle can violate the unique index on (reviewer_id, reviewee_id).
  puts "Creating reviews..."
  review_pairs = clients.product(freelancers).shuffle.first(50)
  review_pairs.each do |reviewer, reviewee|
    Review.create!(
      reviewer: reviewer,
      reviewee: reviewee,
      stars: rand(1..5),
      body: Faker::Lorem.paragraph(sentence_count: rand(2..6))
    )
  end

  # demo is not in the freelancers array, so these can't collide with the batch above.
  puts "Creating reviews received by the demo account..."
  clients.sample(8).each do |reviewer|
    Review.create!(
      reviewer: reviewer,
      reviewee: demo,
      stars: rand(3..5),
      body: Faker::Lorem.paragraph(sentence_count: rand(2..6))
    )
  end

  # Gives the demo client's dashboard something to show. demo_client is not in
  # the clients array, so no pair here was already generated.
  puts "Creating reviews given by the demo client..."
  freelancers.sample(3).each do |reviewee|
    Review.create!(
      reviewer: demo_client,
      reviewee: reviewee,
      stars: rand(3..5),
      body: Faker::Lorem.paragraph(sentence_count: rand(2..6))
    )
  end

  puts "Flagging a few reviews so the moderation UI has something to act on..."
  demo.reviews_received.limit(3).each(&:flagged!)

  ending = Time.now

  puts
  puts "Sample data created in #{(ending - starting).round(1)} seconds:"
  puts "  - #{User.count} users (2 demo accounts + #{freelancers.size} freelancers + #{clients.size} clients)"
  puts "  - #{Link.count} portfolio links"
  puts "  - #{Review.count} reviews (#{Review.flagged.count} flagged)"
  puts
  puts "Freelancer login: demo@repboard.com / password123"
  puts "Client login:     client@repboard.com / password123"
end
