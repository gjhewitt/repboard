# RepBoard

A portable reputation platform that lets freelancers collect structured client feedback and showcase a verified public profile.

## Setup Instructions

🔗 **Live Demo:** [repboard.onrender.com](https://repboard.onrender.com)

### Tech Stack
- Ruby on Rails 8
- PostgreSQL (Supabase)
- Devise (authentication)
- Bootstrap 5
- Turbo & Stimulus
- Deployed on Render

### Local Setup

1. **Clone the repo**
```bash
   git clone https://github.com/gjhewitt/repboard.git
   cd repboard
```

2. **Install dependencies**
```bash
   bundle install
```

3. **Set up environment variables**

   Create a `.env` file in the root with:
```
   DATABASE_URL=your_supabase_postgres_url
```

4. **Set up the database**
```bash
   rails db:create db:migrate db:seed
```

5. **Start the server**
```bash
   bin/dev
```

6. Visit `http://localhost:3000`

### Requirements
- Ruby 3.4+
- PostgreSQL
- Node.js (for asset pipeline)

## ERD

users                          reviews
-----------                    -----------
id (PK)                        id (PK)
email                          reviewer_id (FK → users)
display_name                   reviewee_id (FK → users)
reviewable (boolean)           body (text)
bio (text)                     stars (integer 1-5)
slug (string, unique)          created_at
encrypted_password             updated_at

- User has_many :reviews_given (foreign_key: reviewer_id)
- User has_many :reviews_received (foreign_key: reviewee_id)
- Review belongs_to :reviewer (User)
- Review belongs_to :reviewee (User)

## Screenshots

*Coming soon*
