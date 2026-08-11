# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## How to work with me

I am learning Rails. RepBoard is my portfolio piece for a job hunt, and I need to
be able to defend every line of it under interview questioning.

- **Do not write application code in `app/` for me.** Explain the pattern, say why
  it's the right call in one or two sentences, then tell me what to write.
- Review what I write. If it works but isn't idiomatic Rails, show the idiomatic
  version side by side and say plainly that mine is wrong.
- You may write without asking: migrations, specs, config, CI, binstubs, one-off scripts.
- Never generate a whole feature at once. PR-sized chunks only.
- Never write journal entries or commit messages describing work I didn't do.
- Don't agree with me to be agreeable. If a decision is bad, say so.

## Project

RepBoard is a Rails 8 app where freelancers collect structured client feedback and showcase a public profile. Ruby on Rails 8, PostgreSQL, Devise, Bootstrap 5, Hotwire (Turbo + Stimulus), Propshaft/importmap-rails. Built from firstdraft's AppDev Rails 8 template (`appdev_support`, `draft_generators`, `dev_toolbar`, `rails_db` gems are learning aids, not app logic).

## Commands

- Run server: `bin/dev` (wraps `bin/rails server`)
- Setup/update env: `bin/setup` (bundles, prepares dev + test DBs, clears logs/tmp)
- Console: `bin/rails console`
- DB: `bin/rails db:create db:migrate db:seed`
- Tests: `bundle exec rspec` (single file: `bundle exec rspec spec/path/to_spec.rb`, single line: `bundle exec rspec spec/path/to_spec.rb:23`)
- Lint: `bin/rubocop` (Rails Omakase style — see `.rubocop.yml` for the small set of overrides: old hash syntax allowed, space inside parens allowed)
- Security scan: `bin/brakeman` — **currently broken.** The binstub exists but the
  `brakeman` gem is in neither `Gemfile` nor `Gemfile.lock`, so the command fails.
  Add `gem "brakeman", require: false` to the `:development` group before relying
  on it, or before enabling the CI job that calls it.
- CI (`.github/workflows/ci.yml`) is a disabled placeholder — brakeman /
  importmap-audit / rubocop jobs exist but are all commented out. The only active
  job echoes "CI jobs disabled". Green checkmarks on GitHub currently mean nothing.

### Seed data — three tasks, two of them destructive

- `bin/rails demo_data` (`lib/tasks/demo_data.rake`) — **safe.** Idempotent,
  uses `find_or_create_by!`, adds a demo account plus named freelancers without
  touching existing records.
- `rake sample_data` (`lib/tasks/sample_data.rake`) — **destructive.** Opens with
  `Review.destroy_all; Link.destroy_all; User.destroy_all`, then generates Faker
  data including 3 flagged reviews on the demo account. Guarded against
  `Rails.env.production?`. Never run this without saying so first.
- `bin/rails db:seed` (`db/seeds.rb`) — **destructive.** Full reseed, wipes
  reviews and users first.

## Environment (local, macOS)

- Ruby 3.4.10 via Homebrew `ruby@3.4`, despite `.ruby-version` saying 3.4.1. rvm is
  installed but manages zero rubies and nags on every `cd` into the repo. Harmless.
  Changing `.ruby-version` deserves its own PR since Render reads it too.
- **Bundler must be exactly 2.6.5.** Never run `bundle update --bundler` — RubyGems
  activates the `BUNDLED WITH` version before running anything, and Render reads
  the same line.
- Postgres 15 via Homebrew, superuser role matching the macOS username, trust auth
  on the local socket.
- `.env` is required in development and is gitignored via `**/.env*`:
  `DATABASE_URL=postgresql://<your-postgres-role>@localhost:5432/repboard_development?pool=5`
  Since PR #41, `config/database.yml` names databases explicitly: `development:`
  uses a bare `ENV.fetch("DATABASE_URL")`, `test:` uses the two-arg form with a
  default. The two-arg form matters — Rails ERB-renders every environment block on
  boot, so a bare fetch in `test:` would raise `KeyError` on Render.
- `config/master.key` is absent on this machine (gitignored, lives only in the
  Codespace). Harmless while nothing reads `Rails.application.credentials`.
- There is a second copy of this repo at `~/Documents/Claude/Projects/` that gets
  mounted into Claude desktop sessions. It is **not** the working copy and is often
  stale. `~/ruby/repboard` is the working copy; GitHub is the source of truth.

## Deployment

Render (web) + Supabase (Postgres), configured in `render.yaml`. Render generates its
own `SECRET_KEY_BASE`. Production runs with `BUNDLE_WITHOUT=development:test`, so
development-only gems never load there — this is why local-only breakage from
`appdev_support` and friends doesn't affect production.

**The recurring deploy breaker is Supabase auto-pausing the database.** Check that
before debugging anything in Rails.

`config/deploy.yml` is unused Kamal scaffolding from the Rails 8 template, not the
real deploy path. Ignore it.

## Architecture

**Two-sided user model, single `User` table.** There's no separate role model — a `reviewable` boolean on `User` determines whether an account is a freelancer (reviewable, receives reviews) or a client (not reviewable, leaves reviews). This flag drives authorization logic throughout (e.g. `CreateReview` rejects the review if `reviewer.reviewable?` is true — freelancers can't leave reviews).

**Service objects for domain logic.** Business logic that doesn't belong in a controller action lives in plain Ruby service classes under `app/services` (currently `CreateReview`), instantiated with keyword args and exposing `#call`, `#error`/other readers for the result. Follow this pattern for new multi-step/validated operations rather than growing controller actions.

**Slugs via a shared concern.** `User` (and any future sluggable model) includes `Sluggable` (`app/models/concerns/sluggable.rb`), which generates a unique `parameterize`d slug from `display_name` on create, appending `-1`, `-2`, etc. on collision. Profile URLs (`/profile/:slug`) key off this. Note it runs `on: :create` only — renaming a user leaves the old slug, which keeps shared profile links stable.

**Review lifecycle uses an enum status, not soft-delete.** `Review#status` is `published` / `flagged` / `hidden` (default `published`). `ReviewsController#moderate` lets the reviewee (not the reviewer) change status — this is how a freelancer flags/hides a bad review rather than deleting it; `#destroy` is reserved for the reviewer removing their own review. Public profile pages only show `Review.published`.

**Counter caches.** `reviews_given_count`/`reviews_received_count` on `User` and `links_count` are Rails counter caches tied to the `belongs_to` associations on `Review`/`Link` — don't bypass `save`/`create` paths (e.g. bulk SQL) that would skip counter maintenance without also correcting counts. **Counter caches cannot be scoped**: they count every row regardless of `status`, which is why any "how many *published* reviews" question needs a real query, not the cached column.

**Routes are hand-written, not `resources`**, and intentionally partial: `POST /reviews`, `DELETE /reviews/:id`, `PATCH /reviews/:id/moderate` — there is no update or index route for reviews (edits aren't supported; reviews are shown inline on the reviewee's profile and in `/dashboard`/`/client-dashboard`).

**Two dashboards, one for each side of the marketplace**: `DashboardController` (`/dashboard`) shows a freelancer their received reviews, with star-rating filtering, Kaminari pagination, and a Groupdate/Chartkick monthly average-rating chart. `ClientDashboardController` (`/client-dashboard`) shows a client the reviews they've given. Both require authentication; neither currently checks `reviewable` to gate which dashboard a user should see.

**Frontend is server-rendered ERB + Bootstrap 5 + Stimulus**, no SPA framework. JS is managed via importmap (`config/importmap.rb`), pinned files live in `app/javascript/controllers`. In active use: `star_rating_controller.js` (interactive star input on the review form), `review_form_controller.js` (client-side validation, form submitted with `turbo: false`), `auto_submit_controller.js` (dashboard star filter), `clipboard_controller.js` (copy profile link). **Dead code:** `modal_controller.js` is referenced by no view and is written against Pico CSS, which this app does not use; `hello_controller.js` is leftover scaffolding. Both should be deleted, not wired up.

**Solid stack for infra, no Redis.** `solid_cache`/`solid_queue`/`solid_cable` back cache, jobs, and Action Cable directly off Postgres (see `cache`/`queue`/`cable` entries under `production:` in `config/database.yml`, and `db/cache_schema.rb`/`db/queue_schema.rb`/`db/cable_schema.rb`, which are separate schemas from `db/schema.rb`).

## Known issues — do not replicate these patterns

1. **Public rating stats include non-public reviews.** `User#average_rating` and
   `User#review_count` query `reviews_received`, which includes `hidden` and
   `flagged` rows, while `profiles#show` renders only `published`. The header count
   and the rendered list disagree, and hiding a review doesn't move the average.
   Being fixed on branch `gh-scope-public-reviews`.
2. **N+1 on reviewers.** Neither `profiles#show` nor `dashboard#index` eager-loads
   `:reviewer`, and `_review.html.erb` calls `review.reviewer.display_name`. No
   `includes` appears anywhere in `app/`.
3. **`bin/brakeman` fails** — binstub without a gem. See Commands.
4. **`links.user_id` is nullable in the schema** while `Link belongs_to :user`
   requires it. Add `null: false` to match the model.
5. **`settings_controller` permits `_destroy`** and `User` sets
   `allow_destroy: true`, but no view renders a destroy checkbox. Dead config.

## Testing notes

RSpec is configured (`spec/rails_helper.rb`, Capybara + headless Chrome for features, Shoulda Matchers for model specs, WebMock, `rails-controller-testing`) but the suite is effectively empty — `spec/features/sample_spec.rb` is a placeholder (`it "is not graded"`). There is no established spec style to follow yet in this repo; use standard RSpec/Rails conventions (`spec/models`, `spec/requests`, `spec/features`) and Rails' `infer_spec_type_from_file_location!` (already enabled) for new specs.

## Other repo docs

`FIXES.md` and `RUBRIC_REVIEW.md` are point-in-time bootcamp deliverables (a prioritized fix list and a grading rubric review) — useful for historical context but not kept in sync with the code; verify against the current source (e.g. the non-RESTful-routes issue in `FIXES.md` no longer matches `config/routes.rb`) before acting on anything in them.
