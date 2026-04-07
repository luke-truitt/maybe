class User < ApplicationRecord
  has_secure_password

  belongs_to :family
  belongs_to :last_viewed_chat, class_name: "Chat", optional: true
  has_many :sessions, dependent: :destroy
  has_many :chats, dependent: :destroy
  accepts_nested_attributes_for :family, update_only: true

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :ensure_valid_profile_image
  validates :default_period, inclusion: { in: Period::PERIODS.keys }
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :unconfirmed_email, with: ->(email) { email&.strip&.downcase }

  normalizes :first_name, :last_name, with: ->(value) { value.strip.presence }

  enum :role, { member: "member", admin: "admin", super_admin: "super_admin" }, validate: true

  has_one_attached :profile_image do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [ 300, 300 ], convert: :webp, saver: { quality: 80 }
    attachable.variant :small, resize_to_fill: [ 72, 72 ], convert: :webp, saver: { quality: 80 }, preprocessed: true
  end

  validate :profile_image_size

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  generates_token_for :email_confirmation, expires_in: 1.day do
    unconfirmed_email
  end

  def pending_email_change?
    unconfirmed_email.present?
  end

  def initiate_email_change(new_email)
    return false if new_email == email
    return false if new_email == unconfirmed_email

    if Rails.application.config.app_mode.self_hosted? && !Setting.require_email_confirmation
      update(email: new_email)
    else
      if update(unconfirmed_email: new_email)
        EmailConfirmationMailer.with(user: self).confirmation_email.deliver_later
        true
      else
        false
      end
    end
  end

  def admin?
    super_admin? || role == "admin"
  end

  def display_name
    [ first_name, last_name ].compact.join(" ").presence || email
  end

  def initial
    (display_name&.first || email.first).upcase
  end

  def initials
    if first_name.present? && last_name.present?
      "#{first_name.first}#{last_name.first}".upcase
    else
      initial
    end
  end

  def show_ai_sidebar?
    show_ai_sidebar
  end

  def ai_available?
    false # AI disabled — uncomment anthropic gem and set ANTHROPIC_API_KEY to re-enable
  end

  def ai_enabled?
    ai_enabled && ai_available?
  end

  # Deactivation
  validate :can_deactivate, if: -> { active_changed? && !active }
  after_update_commit :purge_later, if: -> { saved_change_to_active?(from: true, to: false) }

  def deactivate
    update active: false, email: deactivated_email
  end

  def can_deactivate
    if admin? && family.users.count > 1
      errors.add(:base, :cannot_deactivate_admin_with_other_users)
    end
  end

  def purge_later
    UserPurgeJob.perform_later(self)
  end

  def purge
    if last_user_in_family?
      family.destroy
    else
      destroy
    end
  end

  def onboarded?
    onboarded_at.present?
  end

  def needs_onboarding?
    !onboarded?
  end

  private
    def ensure_valid_profile_image
      return unless profile_image.attached?

      unless profile_image.content_type.in?(%w[image/jpeg image/png])
        errors.add(:profile_image, "must be a JPEG or PNG")
        profile_image.purge
      end
    end

    def last_user_in_family?
      family.users.count == 1
    end

    def deactivated_email
      email.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def profile_image_size
      if profile_image.attached? && profile_image.byte_size > 10.megabytes
        errors.add(:profile_image, :invalid_file_size, max_megabytes: 10)
      end
    end

end
