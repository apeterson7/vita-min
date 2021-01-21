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
require "rails_helper"

describe VitaPartner do
  describe "#at_capacity?" do
    let(:out_of_range_statuses) { [:intake_before_consent, :intake_in_progress, :file_accepted, :file_not_filing] }
    let(:in_range_statuses) {
      TaxReturnStatus::STATUSES.keys - out_of_range_statuses
    }

    context "an organization" do
      let(:organization) { create :organization, weekly_capacity_limit: 10 }

      context "at or over capacity" do
        context "at capacity" do
          before do
            organization.weekly_capacity_limit.times do
              client = create :client, vita_partner: organization
              create :tax_return, status: "intake_ready", client: client
            end
          end

          it "returns true" do
            expect(organization).to be_at_capacity
          end
        end

        context "over capacity" do
          context "clients assigned to organization exceed capacity limit" do
            before do
              (organization.weekly_capacity_limit + 1).times do
                client = create :client, vita_partner: organization
                create :tax_return, status: in_range_statuses.sample, client: client
              end
            end

            it "returns true" do
              expect(organization).to be_at_capacity
            end
          end

          context "sum of clients assigned to sites within organization exceed capacity limit" do
            let(:site_1) { create :site, parent_organization: organization }
            let(:site_2) { create :site, parent_organization: organization }

            before do
              (organization.weekly_capacity_limit + 1).times do
                client = create :client, vita_partner: [site_1, site_2, organization].sample
                create :tax_return, status: in_range_statuses.sample, client: client
              end
            end

            it "returns true" do
              expect(organization).to be_at_capacity
            end
          end
        end
      end

      context "under capacity" do
        context "total number of clients is less than capacity limit" do
          before do
            (organization.weekly_capacity_limit - 1).times do
              client = create :client, vita_partner: organization
              create :tax_return, client: client
            end
          end

          it "returns false" do
            expect(organization).not_to be_at_capacity
          end
        end

        context "number of clients in status range is less than capacity limit" do
          before do
            (organization.weekly_capacity_limit / 2).times do
              client = create :client, vita_partner: organization
              create :tax_return, status: out_of_range_statuses.sample, client: client
            end

            (organization.weekly_capacity_limit / 2).times do
              client = create :client, vita_partner: organization
              create :tax_return, status: in_range_statuses.sample, client: client
            end
          end

          it "returns false" do
            expect(organization).not_to be_at_capacity
          end
        end
      end
    end

    context "with no capacity set" do
      let(:organization) { create :organization }
      before do
        100.times do
          client = create :client, vita_partner: organization
          create :tax_return, status: "intake_ready", client: client
        end
      end

      it "always returns false" do
        expect(organization).not_to be_at_capacity
      end
    end

    context "a site" do
      let(:site) { create :site }

      it "throws an error because sites do not have capacity" do
        expect do
          site.at_capacity?
        end.to raise_error(StandardError)
      end
    end
  end

  context "site-specific properties" do
    context "with a parent_organization_id" do
      let(:organization) { create(:vita_partner) }
      let(:site) { create(:vita_partner, parent_organization: organization) }

      it "is a site" do
        expect(site.site?).to eq(true)
        expect(site.organization?).to eq(false)
        expect(VitaPartner.sites).to eq [site]
      end

      it "cannot be added to a coalition" do
        coalition = create(:coalition)
        site.coalition = coalition
        expect(site).not_to be_valid
      end

      it "cannot have the same name as another site in the same organization" do
        create(:site, parent_organization: organization, name: "Salty Site")
        new_site = build(:site, parent_organization: organization, name: "Salty Site")
        expect(new_site).not_to be_valid
      end
    end

    it "cannot be assigned a capacity" do
      site = VitaPartner.new(parent_organization: create(:organization), weekly_capacity_limit: 1)
      expect(site.valid?).to eq false
    end
  end

  context "organization-specific properties" do
    context "without a parent_organization_id" do
      let(:organization) { create(:vita_partner, parent_organization: nil) }

      it "is an organization" do
        expect(organization.organization?).to eq(true)
        expect(organization.site?).to eq(false)
        expect(VitaPartner.organizations).to eq [organization]
      end

      it "cannot have the same name as another organization in the same coalition" do
        coalition = create :coalition
        create(:organization, coalition: coalition, name: "Oregano Org")
        new_org = build(:organization, coalition: coalition, name: "Oregano Org")
        expect(new_org).not_to be_valid
      end

      describe "#child_sites" do
        before do
          create_list(:site, 3, parent_organization: organization)
        end

        it "includes the sites an org has" do
          expect(organization.child_sites.count).to eq(3)
        end
      end
    end
  end

  context "sub-organizations" do
    let(:vita_partner) { create(:vita_partner) }

    it "permits one level of depth" do
      child = VitaPartner.new(
        name: "Child", parent_organization: vita_partner
      )
      expect(child).to be_valid
    end

    it "does not permit two levels of depth" do
      child = create(:vita_partner, parent_organization: vita_partner)
      grandchild = VitaPartner.new(
        name: "Grand Child", parent_organization: child
      )
      expect(grandchild).not_to be_valid
    end
  end
end
