# == Schema Information
#
# Table name: users
#
#  id                        :bigint           not null, primary key
#  active                    :boolean
#  current_sign_in_at        :datetime
#  current_sign_in_ip        :string
#  email                     :string           not null
#  encrypted_access_token    :string
#  encrypted_access_token_iv :string
#  encrypted_password        :string           default(""), not null
#  failed_attempts           :integer          default(0), not null
#  invitation_accepted_at    :datetime
#  invitation_created_at     :datetime
#  invitation_limit          :integer
#  invitation_sent_at        :datetime
#  invitation_token          :string
#  invitations_count         :integer          default(0)
#  last_sign_in_at           :datetime
#  last_sign_in_ip           :string
#  locked_at                 :datetime
#  name                      :string
#  phone_number              :string
#  provider                  :string
#  reset_password_sent_at    :datetime
#  reset_password_token      :string
#  role_type                 :string
#  sign_in_count             :integer          default(0), not null
#  suspended                 :boolean
#  ticket_restriction        :string
#  timezone                  :string           default("America/New_York"), not null
#  two_factor_auth_enabled   :boolean
#  uid                       :string
#  verified                  :boolean
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  invited_by_id             :bigint
#  role_id                   :bigint
#  zendesk_user_id           :bigint
#
# Indexes
#
#  index_users_on_email                  (email) UNIQUE
#  index_users_on_invitation_token       (invitation_token) UNIQUE
#  index_users_on_invitations_count      (invitations_count)
#  index_users_on_invited_by_id          (invited_by_id)
#  index_users_on_reset_password_token   (reset_password_token) UNIQUE
#  index_users_on_role_type_and_role_id  (role_type,role_id)
#
# Foreign Keys
#
#  fk_rails_...  (invited_by_id => users.id)
#
class User < ApplicationRecord
  devise :database_authenticatable, :lockable, :validatable, :timeoutable, :trackable, :invitable, :recoverable

  before_validation :format_phone_number
  validates :phone_number, phone: true, allow_blank: true, format: { with: /\A\+1[0-9]{10}\z/ }
  validates :role_id, uniqueness: { scope: :role_type }
  has_many :assigned_tax_returns, class_name: "TaxReturn", foreign_key: :assigned_user_id
  has_many :access_logs
  belongs_to :role, polymorphic: true, optional: true

  belongs_to :organization_lead_role, -> { where(users: { role_type: 'OrganizationLeadRole' }) }, foreign_key: 'role_id', optional: true

  attr_encrypted :access_token, key: ->(_) { EnvironmentCredentials.dig(:db_encryption_key) }

  validates_presence_of :name
  validates_inclusion_of :timezone, in: ActiveSupport::TimeZone.country_zones("us").map { |tz| tz.tzinfo.name }

  def accessible_coalitions
    case role_type
    when AdminRole::TYPE
      Coalition.all
    when CoalitionLeadRole::TYPE
      Coalition.where(id: role.coalition)
    when GreeterRole::TYPE
      role.coalitions
    else
      Coalition.none
    end
  end

  def accessible_vita_partners
    case role_type
    when AdminRole::TYPE
      VitaPartner.all
    when OrganizationLeadRole::TYPE
      VitaPartner.organizations.where(id: role.organization).or(
        VitaPartner.sites.where(parent_organization_id: role.organization)
      )
    when TeamMemberRole::TYPE, SiteCoordinatorRole::TYPE
      VitaPartner.sites.where(id: role.site)
    when CoalitionLeadRole::TYPE
      organizations = role.coalition.organizations
      sites = VitaPartner.sites.where(parent_organization: organizations)
      organizations.or(sites)
    when GreeterRole::TYPE
      organizations = VitaPartner.where(coalition: role.coalitions).or(
        VitaPartner.organizations.where(id: role.organizations)
      )
      sites = VitaPartner.sites.where(parent_organization: organizations)
      organizations.or(sites)
    else
      VitaPartner.none
    end
  end

  def first_name
    name&.split(" ")&.first
  end

  def start_date
    invitation_accepted_at || created_at
  end

  def format_phone_number
    self.phone_number = PhoneParser.normalize(phone_number) if phone_number_changed?
  end

  # Send Devise emails via job, per https://github.com/heartcombo/devise#activejob-integration
  def send_devise_notification(notification, *args)
    if Rails.env.development?
      devise_mailer.send(notification, self, *args).deliver_later
    else
      super
    end
  end
end
