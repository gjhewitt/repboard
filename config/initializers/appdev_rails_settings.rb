# AppDev Rails Settings (Phase 1 - Beginner)
# Consolidated Rails configuration for AppDev projects

Rails.application.configure do
  # Allow unsafe redirects (for student convenience)
  config.action_controller.raise_on_open_redirects = false

  # Allow envoy.fyi to frame the app
  config.content_security_policy do |policy|
    policy.frame_ancestors :self, "https://envoy.fyi"
  end
end
