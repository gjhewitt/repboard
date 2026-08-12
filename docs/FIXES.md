> **Historical.** Written during the firstdraft capstone and not maintained.
> URLs and file references in this document may be stale. Verify against the
> current source before acting on anything here.

# RepBoard — Prioritized Improvement Plan

## P0 — Critical (Security / Architecture / Broken Patterns)

---

### P0-1: ReviewsController#update — No Authorization Check

**File**: `app/controllers/reviews_controller.rb`
**Problem**: The `update` action has no check that `current_user` owns the review being updated. Any authenticated user who knows a review's `path_id` (which is the review slug, derived from user slug + incremental counter — not secret) can modify any review.

**Suggested Solution**: Add the same ownership guard used in `#destroy`, or extract it to a `before_action`.

```ruby
# app/controllers/reviews_controller.rb

before_action :set_review, only: [:show, :update, :destroy]
before_action :require_review_ownership!, only: [:update, :destroy]

def update
  if @review.update(review_params)
    redirect_to @review, notice: "Review updated."
  else
    render :edit, status: :unprocessable_entity
  end
end

private

def set_review
  @review = Review.find_by!(slug: params[:id])
end

def require_review_ownership!
  unless @review.reviewer_id == current_user.id
    redirect_to root_path, alert: "Not authorized."
  end
end
```

---

### P0-2: ReviewsController — Missing Strong Parameters

**File**: `app/controllers/reviews_controller.rb`
**Problem**: The `create` and `update` actions use `params.fetch(:stars)` and `params.fetch(:body)` directly without a `permit` block. Strong parameters are a core Rails security control preventing mass assignment vulnerabilities.

**Suggested Solution**: Define a `review_params` private method with `require`/`permit`.

```ruby
# app/controllers/reviews_controller.rb

private

def review_params
  params.require(:review).permit(:stars, :body, :reviewee_id)
end
```

Then in `create`, pass `review_params` to the `CreateReview` service instead of individual `params.fetch` calls. Update the service's `initialize` signature accordingly.

---

### P0-3: Non-RESTful Routes

**File**: `config/routes.rb`
**Problem**: Routes use non-standard naming and wrong HTTP verbs:
- `post "/insert_review"` — should be `POST /reviews`
- `post "/modify_review/:path_id"` — should be `PATCH /reviews/:id`
- `get "/delete_review/:path_id"` — uses GET for a destructive action (violates HTTP semantics and is unsafe for bots/prefetchers)

Non-RESTful routes also break Rails route helpers, make the codebase harder to maintain, and are a foundational convention in Rails development.

**Suggested Solution**: Replace custom routes with `resources`:

```ruby
# config/routes.rb

resources :reviews, only: [:index, :show, :create, :update, :destroy]
```

Update all link helpers and form actions in views accordingly:
- `form_with url: reviews_path` (create)
- `link_to "Delete", review_path(@review), method: :delete, data: { turbo_method: :delete }` (destroy)

---

### P0-4: Missing Image Alt Attributes (Accessibility Violation)

**File**: `app/views/profiles/show.html.erb`
**Problem**: The freelancer avatar image is rendered without an `alt` attribute, which is an accessibility violation (WCAG 2.1 Level A, Success Criterion 1.1.1). Screen readers will read the full URL instead of descriptive text.

**Suggested Solution**:

```erb
<%= image_tag @freelancer.avatar_url,
      alt: "#{@freelancer.display_name} profile photo",
      class: "rounded-circle",
      width: 80, height: 80 %>
```

If the image is purely decorative, use `alt: ""` (empty string, not omitted).

---

## P1 — Important (Maintainability / Convention / Cleanliness)

---

### P1-1: Zero Test Coverage

**File**: `spec/features/sample_spec.rb` (placeholder only)
**Problem**: RSpec, Capybara, Selenium, Shoulda Matchers, and WebMock are all installed but no real tests exist. For an app that manages user reputation data, the absence of tests makes safe refactoring impossible and critical flows unverifiable.

**Suggested Solution**: Start with the highest-value tests first.

**Model tests** (`spec/models/review_spec.rb`):
```ruby
RSpec.describe Review, type: :model do
  it { should validate_presence_of(:body) }
  it { should validate_numericality_of(:stars).is_in(1..5) }
  it { should belong_to(:reviewer) }
  it { should belong_to(:reviewee) }
  it { should validate_uniqueness_of(:reviewer_id).scoped_to(:reviewee_id) }
end
```

**Service test** (`spec/services/create_review_spec.rb`):
```ruby
RSpec.describe CreateReview do
  it "prevents reviewable users from leaving reviews" do
    freelancer = create(:user, reviewable: true)
    another_user = create(:user, reviewable: false)
    service = CreateReview.new(reviewer: freelancer, reviewee: another_user, stars: 5, body: "Great!")
    expect(service.call).to be false
    expect(service.error).to include("not permitted")
  end
end
```

---

### P1-2: Enable CI/CD Pipeline

**File**: `.github/workflows/ci.yml`
**Problem**: The workflow file exists with jobs defined for Brakeman (security scan), importmap-audit, and Rubocop — but all jobs are commented out. No automated checks run on any push or pull request.

**Suggested Solution**: Uncomment the existing jobs and ensure the workflow triggers on `push` and `pull_request`:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  scan_ruby:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec brakeman --no-pager

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec rubocop --parallel
```

---

### P1-3: Move Chart Data Logic Out of Controller

**File**: `app/controllers/dashboard_controller.rb`
**Problem**: `@chart_data = current_user.reviews_received.group_by_month(:created_at).average(:stars)` is a query that belongs in the model layer, not the controller. Controllers should be thin.

**Suggested Solution**: Add a method to the `User` model:

```ruby
# app/models/user.rb
def rating_trend
  reviews_received.group_by_month(:created_at).average(:stars)
end
```

Then in the controller:
```ruby
# app/controllers/dashboard_controller.rb
@chart_data = current_user.rating_trend
```

---

### P1-4: Inline JavaScript in Views

**File**: `app/views/client_dashboard/index.html.erb`
**Problem**: The share button uses inline `onclick` and `onmouseover`/`onmouseout` event handlers. Inline JavaScript in views violates separation of concerns, bypasses Content Security Policy in strict configurations, and cannot be tested.

**Suggested Solution**: The `clipboard_controller.js` Stimulus controller already exists and handles this pattern. Use it:

```erb
<div data-controller="clipboard" data-clipboard-text-value="<%= profile_url(@freelancer) %>">
  <button data-action="click->clipboard#copy" class="btn btn-outline-secondary btn-sm">
    Share Profile
  </button>
</div>
```

---

### P1-5: Stray Character in JavaScript Entry Point

**File**: `app/javascript/application.js` (line 15)
**Problem**: A stray `i` character exists at the end of the file. While harmless in modern bundlers, it indicates incomplete editing and will cause linter warnings.

**Suggested Solution**: Delete line 15.

---

### P1-6: Disabled Turbo with Active Import

**File**: `app/javascript/application.js`
**Problem**: `import "@hotwired/turbo-rails"` is present but immediately followed by `Turbo.session.drive = false`, which disables Turbo Drive entirely. This imports dead code on every page load.

**Suggested Solution**: Either:
1. Enable Turbo Drive and ensure pages work correctly with it (preferred — reduces page loads)
2. If Turbo Drive is intentionally disabled, remove the import entirely and keep only Turbo Frames/Streams:

```javascript
// Only import what you use
import { turbo } from "@hotwired/turbo"
// Turbo Frames and Streams will still work without Drive
```

---

### P1-7: Non-Standard Parameter Naming in Routes/Controllers

**File**: `config/routes.rb`, `app/controllers/reviews_controller.rb`
**Problem**: Routes use `path_id` and `query_*` prefixes (`query_stars`, `query_body`) instead of standard Rails `params[:id]` and resource-named params. This departs from convention without benefit and makes the codebase harder to onboard to.

**Suggested Solution**: After migrating to RESTful routes (P0-3), use standard `params[:id]` and form-backed `review_params`.

---

### P1-8: Add Comment Explaining Slug Generation Algorithm

**File**: `app/models/concerns/sluggable.rb`
**Problem**: The `generate_slug` method includes a uniqueness loop that appends a counter suffix when slugs conflict. This is non-obvious logic with no explanation.

**Suggested Solution**:

```ruby
# Generates a URL-friendly slug from display_name.
# If a collision exists, appends an incrementing counter (e.g., "john-smith-2").
def generate_slug
  base = display_name.parameterize
  candidate = base
  counter = 1
  while User.exists?(slug: candidate)
    counter += 1
    candidate = "#{base}-#{counter}"
  end
  self.slug = candidate
end
```

---

## P2 — Polish / UX / Enhancements

---

### P2-1: Add Background Job for Email Notifications

**File**: `app/jobs/` (directory exists but empty)
**Problem**: When a freelancer receives a new review, they are not notified. Email notifications for new reviews would significantly improve the product's value and demonstrate background job usage (which is configured but unused via SolidQueue).

**Suggested Solution**:

```ruby
# app/jobs/new_review_notification_job.rb
class NewReviewNotificationJob < ApplicationJob
  queue_as :default

  def perform(review_id)
    review = Review.find(review_id)
    ReviewMailer.new_review(review).deliver_now
  end
end

# In CreateReview service, after successful save:
NewReviewNotificationJob.perform_later(review.id)
```

---

### P2-2: Implement Advanced Search / Ransack

**File**: `app/controllers/dashboard_controller.rb`, `app/views/dashboard/index.html.erb`
**Problem**: The current star filter is a basic `WHERE stars = ?` query. Ransack would allow filtering by multiple attributes, date ranges, text search in review body, etc.

**Suggested Solution**:
1. Add `gem "ransack"` to Gemfile
2. Replace manual filter logic with `@q = current_user.reviews_received.ransack(params[:q])`
3. Update dashboard form to use `search_form_for @q`

---

### P2-3: Add Contribution Guidelines to README

**File**: `README.md`
**Problem**: No contribution guidelines, branch naming conventions, or PR process documented.

**Suggested Solution**: Add a `## Contributing` section:

```markdown
## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes and write tests
4. Run linting: `bundle exec rubocop`
5. Submit a pull request against `main` with a clear description

Branch naming: `feature/`, `fix/`, `chore/` prefixes required.
```

---

### P2-4: Add Troubleshooting Section to README

**File**: `README.md`
**Problem**: Common setup issues (PostgreSQL connection, missing ENV vars, Resend configuration) are not addressed.

**Suggested Solution**: Add a `## Troubleshooting` section covering:
- PostgreSQL role not found → `createuser -s postgres`
- Missing `.env` → copy `.env.example`
- Resend emails not sending in development → use `letter_opener` gem

---

### P2-5: Add README Screenshots

**File**: `README.md`
**Problem**: Screenshots are marked "coming soon" but never added. Visual aids significantly help new contributors understand the product quickly.

**Suggested Solution**: Add screenshots to a `docs/screenshots/` folder and embed them in the README:
```markdown
## Screenshots
![Dashboard](docs/screenshots/dashboard.png)
![Profile Page](docs/screenshots/profile.png)
```

---

### P2-6: Add Bullet Gem for N+1 Detection

**File**: `Gemfile`
**Problem**: No N+1 query detection in development. The `profiles/show.html.erb` view loads a freelancer and iterates over their reviews — potential N+1 if reviewer data is accessed within the loop without eager loading.

**Suggested Solution**:

```ruby
# Gemfile (development group)
gem "bullet"

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.rails_logger = true
end
```

---

### P2-7: Add Dynamic Meta Tags for Profile SEO

**File**: `app/views/profiles/show.html.erb`, `app/views/layouts/application.html.erb`
**Problem**: Profile pages (which are public and shareable) have no custom `<title>` or Open Graph meta tags. When shared on LinkedIn or Twitter, they will show generic app metadata instead of the freelancer's name and rating.

**Suggested Solution**:

```erb
<%# app/views/profiles/show.html.erb %>
<% content_for :title, "#{@freelancer.display_name} — RepBoard" %>
<% content_for :og_description, "#{@freelancer.review_count} reviews · #{@freelancer.average_rating.round(1)} avg rating" %>

<%# app/views/layouts/application.html.erb (in <head>) %>
<title><%= content_for?(:title) ? yield(:title) : "RepBoard" %></title>
<meta property="og:title" content="<%= content_for?(:title) ? yield(:title) : "RepBoard" %>">
<meta property="og:description" content="<%= yield(:og_description) if content_for?(:og_description) %>">
```

---

### P2-8: Extract Review Card to Partial

**File**: `app/views/dashboard/index.html.erb`, `app/views/profiles/show.html.erb`
**Problem**: Review card HTML is likely duplicated across the dashboard and profile views. A shared `_review_card.html.erb` partial would apply DRY principles to views.

**Suggested Solution**:

```erb
<%# app/views/reviews/_review_card.html.erb %>
<div class="card mb-3">
  <div class="card-body">
    <div class="d-flex justify-content-between">
      <strong><%= review.reviewer.display_name %></strong>
      <span><%= "⭐" * review.stars %></span>
    </div>
    <p class="mt-2"><%= review.body %></p>
    <small class="text-muted"><%= time_ago_in_words(review.created_at) %> ago</small>
  </div>
</div>

<%# In views: %>
<%= render @reviews %>
```

---

*End of FIXES.md*
