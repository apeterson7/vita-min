# == Schema Information
#
# Table name: vita_partners
#
#  id                     :bigint           not null, primary key
#  accepts_overflow       :boolean          default(FALSE)
#  archived               :boolean          default(FALSE)
#  logo_path              :string
#  name                   :string           not null
#  source_parameter       :string
#  weekly_capacity_limit  :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  coalition_id           :bigint
#  parent_organization_id :bigint
#
# Indexes
#
#  index_vita_partners_on_coalition_id               (coalition_id)
#  index_vita_partners_on_parent_name_and_coalition  (parent_organization_id,name,coalition_id) UNIQUE
#  index_vita_partners_on_parent_organization_id     (parent_organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (coalition_id => coalitions.id)
#
class VitaPartner < ApplicationRecord
  belongs_to :coalition, optional: true
  has_many :clients
  has_many :intakes
  has_many :source_parameters
  has_many :users
  belongs_to :parent_organization, class_name: "VitaPartner", optional: true
  validate :one_level_of_depth
  validate :no_coalitions_for_sites
  validate :no_capacity_for_sites
  validates :name, uniqueness: { scope: [:coalition, :parent_organization] }

  scope :organizations, -> { where(parent_organization: nil) }
  scope :sites, -> { where.not(parent_organization: nil) }
  has_many :child_sites, -> { order(:id) }, class_name: "VitaPartner", foreign_key: "parent_organization_id"

  default_scope { includes(:child_sites) }

  def at_capacity?
    raise StandardError if site?
    return false if weekly_capacity_limit.blank?

    Client
      .where(vita_partner_id: [id, *child_site_ids])
      .joins(:tax_returns).where(tax_returns: { status: TaxReturnStatus.statuses_that_count_towards_capacity })
      .count >= weekly_capacity_limit
  end

  def organization?
    parent_organization_id.blank?
  end

  def site?
    parent_organization_id.present?
  end

  private

  def no_coalitions_for_sites
    if site? && coalition_id.present?
      errors.add(:coalition, "Sites cannot be direct members of coalitions")
    end
  end

  def no_capacity_for_sites
    if site? && weekly_capacity_limit.present?
      errors.add(:weekly_capacity_limit, "Sites cannot be assigned a capacity")
    end
  end

  def one_level_of_depth
    if parent_organization&.parent_organization.present?
      errors.add(:parent_organization, "Only one level of sub-organization depth allowed.")
    end
  end
end
