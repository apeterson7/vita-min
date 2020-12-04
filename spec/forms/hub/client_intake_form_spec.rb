require "rails_helper"

RSpec.describe Hub::ClientIntakeForm do

  describe ".save" do
    let!(:intake) { create :intake, :with_contact_info, :with_dependents }
    let(:form_attributes) do
      {   primary_first_name: intake.primary_first_name,
          primary_last_name: intake.primary_last_name,
          email_address: "some-valid-address@example.com",
          dependents_attributes: {
              "0" => {
                  id: intake.dependents.first.id,
                  first_name: intake.dependents.first.first_name,
                  last_name: intake.dependents.first.last_name,
                  birth_date_month: "May",
                  birth_date_day: "9",
                  birth_date_year: "2013",
              }
          }
      }
    end

    context "with invalid form attributes" do
      context "primary_first_name" do
        before do
          form_attributes[:primary_first_name] = nil
        end

        it "is not valid, has error" do
          form = described_class.new(intake, form_attributes)
          expect(form.valid?).to eq false
          expect(form.errors[:primary_first_name]).to eq ["Please enter your first name."]
        end
      end

      context "primary_last_name" do
        before do
          form_attributes[:primary_last_name] = nil
        end

        it "is not valid, has error" do
          form = described_class.new(intake, form_attributes)
          expect(form.valid?).to eq false
          expect(form.errors[:primary_last_name]).to eq ["Please enter your  name."]
        end
      end

      context "sms_phone_number" do
        context "when opted out of sms and number not provided" do
          before do
            form_attributes[:sms_phone_number] = nil
            form_attributes[:sms_notification_opt_in] = "no"
          end

          it "is valid" do
            form = described_class.new(intake, form_attributes)
            expect(form.valid?).to eq true
            expect(form.errors[:sms_phone_number]).to match_array([])
          end
        end

        context "when opted in to texting, but number not provided" do
          before do
            form_attributes[:sms_phone_number] = nil
            form_attributes[:sms_notification_opt_in] = "yes"
          end

          it "is not valid, has error" do
            form = described_class.new(intake, form_attributes)
            expect(form.valid?).to eq false
            expect(form.errors[:sms_phone_number]).to include "Can't be blank."
          end
        end

        context "when opted in to texting, but number is invalid" do
          before do
            form_attributes[:sms_phone_number] = "some-invalid-phone-number"
            form_attributes[:sms_notification_opt_in] = "yes"
          end

          it "is not valid, has error" do
            form = described_class.new(intake, form_attributes)
            expect(form.valid?).to eq false
            expect(form.errors[:sms_phone_number]).to eq ["Please enter a valid phone number."]
          end
        end

        context "when opted in to texting, number is valid, but improperly formatted" do
          before do
            form_attributes[:sms_phone_number] = "500-555-0006"
            form_attributes[:sms_notification_opt_in] = "yes"
          end

          it "is valid, phone is re-formatted" do
            form = described_class.new(intake, form_attributes)
            expect(form.valid?).to eq true
            expect(form.errors[:sms_phone_number]).to match_array([])
            expect(form.sms_phone_number).to eq "15005550006"
          end
        end
      end

      # context "state_of_residence" do
      #   context "when state_of_residence is not provided" do
      #     before do
      #       form_attributes[:state_of_residence] = nil
      #     end
      #
      #     it "is not valid" do
      #       expect(described_class.new(intake, form_attributes).valid?).to eq false
      #     end
      #
      #     it "adds an error to the attribute" do
      #       form = described_class.new(intake, form_attributes)
      #       form.valid?
      #       expect(form.errors[:state_of_residence]).to eq ["Please select a state from the list."]
      #     end
      #   end
      #
      #   context "when state_of_residence is not in list" do
      #     before do
      #       form_attributes[:state_of_residence] = "France"
      #     end
      #
      #     it "adds an error to the attribute" do
      #       form = described_class.new(intake, form_attributes)
      #       form.valid?
      #       expect(form.errors[:state_of_residence]).to eq ["Please select a state from the list."]
      #     end
      #   end
      # end

      context "email_address" do
        context "when provided but not valid" do
          before do
            form_attributes[:email_address] = "not_valid!!"
          end

          it "is not valid, has error" do
            form = described_class.new(intake, form_attributes)
            expect(form.valid?).to eq false
            expect(form.errors[:email_address]).to eq ["Please enter a valid email address."]
          end
        end

        context "when not provided" do
          before do
            form_attributes[:email_address] = nil
            form_attributes[:email_notification_opt_in] = "no"
          end

          it "is not valid" do
            expect(described_class.new(intake, form_attributes).valid?).to eq false
          end
        end
      end

    end

    context "preferred name" do
      context "when blank" do
        before do
          form_attributes[:preferred_name] = nil
        end

        it "uses legal name to create preferred name" do
          described_class.new(form_attributes).save
          expect(Client.last.preferred_name).to eq form_attributes[:primary_first_name] + " " + form_attributes[:primary_last_name]
        end
      end

      context "when present" do
        before do
          form_attributes[:preferred_name] = "Preferred Name"
        end

        it "uses provided name to create preferred name" do
          described_class.new(form_attributes).save
          expect(Client.last.preferred_name).to eq "Preferred Name"
        end
      end
    end

    context "when some attributes on the intake are updated" do
      let(:intake) { create :intake, :filled_out, :with_contact_info }
      let(:form) { Hub::ClientIntakeForm.from_intake(intake, { primary_first_name: "Patty" }) }

      it "updates the provided attributes" do
        form.save
        intake.reload
        expect(intake.primary_first_name).to eq "Patty"
      end
    end

    context "adding/updating dependents" do
      before do
        form_attributes[:dependents_attributes]["0"] = {
            id: intake.dependents.first.id,
            first_name: "Julia",
            last_name: "Childs",
            birth_date_month: "August",
            birth_date_day: "15",
            birth_date_year: "1912"
        }

        form_attributes[:dependents_attributes]["1"] = {
            id: "",
            first_name: "New",
            last_name: "Dependent",
            birth_date_month: "September",
            birth_date_day: "4",
            birth_date_year: "2001"
        }
      end

      it "updates the related dependent objects too" do
        expect do
          form = Hub::ClientIntakeForm.new(intake, form_attributes)
          form.save
          intake.reload
        end.to change(intake.dependents, :count).by 1

        expect(intake.dependents.first.first_name).to eq "Julia"
        expect(intake.dependents.first.last_name).to eq "Childs"
        expect(intake.dependents.first.birth_date).to eq DateTime.parse("1912-08-15")

        expect(intake.dependents.last.first_name).to eq "New"
        expect(intake.dependents.last.last_name).to eq "Dependent"
        expect(intake.dependents.last.birth_date).to eq DateTime.parse("2001-09-04")
      end

      it "can add more than one dependent" do
        form_attributes[:dependents_attributes]["2"] = {
            id: "",
            first_name: "Second New",
            last_name: "Dependent",
            birth_date_month: "May",
            birth_date_day: "5",
            birth_date_year: "2007"
        }

        expect do
          form = Hub::ClientIntakeForm.new(intake, form_attributes)
          form.save
          intake.reload
        end.to change(intake.dependents, :count).by 2
      end
    end

    context "attempting to add a dependent with empty required values" do
      before do
        form_attributes[:primary_first_name] = "Patty"
        form_attributes[:dependents_attributes]["1"] = {
            id: "",
            first_name: "New",
            last_name: "",
            birth_date_month: "",
            birth_date_day: "",
            birth_date_year: "2001"
        }
      end

      it "adds an error onto the form object for dependents_attributes" do
        form = Hub::ClientIntakeForm.new(intake, form_attributes)
        form.save
        expect(form.valid?).to be false
        expect(form.errors[:dependents_attributes]).to be_present
      end
    end

    context "removing dependents" do
      before do
        form_attributes[:dependents_attributes]["0"]["_destroy"] = "1"
      end

      it "removes the dependent marked with _destroy" do
        expect do
          form = Hub::ClientIntakeForm.new(intake, form_attributes)
          form.save
          intake.reload
        end.to change(intake.dependents, :count).by -1
      end
    end

    context "adding a dependent with blank fields" do
      before do
        form_attributes[:dependents_attributes]["1"] = {
            "id" => "",
            "first_name" => "New",
            "last_name" => "",
            "birth_date_month" => "September",
            "birth_date_day" => "4",
            "birth_date_year" => "2001"
        }
      end

      it "will show a validation message" do
        form = Hub::ClientIntakeForm.new(intake, form_attributes)
        form.save
        expect(form).not_to be_valid
        expect(form.errors).to include :dependents_attributes
        expect(form.errors[:dependents_attributes]).to eq(["Please enter the last name of each dependent."])
      end
    end
  end

  describe "#dependents_attributes" do
    context "without dependents_attributes or current dependents" do
      let(:intake) { create :intake, :filled_out, :with_contact_info }
      let(:form) { Hub::ClientIntakeForm.new(intake, { primary_first_name: "Patty" }) }
      it "returns nil" do
        expect(form.dependents_attributes).to eq nil
      end
    end

    context "with current dependents and no dependents attributes" do
      let(:intake) { create :intake, :filled_out, :with_contact_info, dependents: [create(:dependent)] }
      let(:form) { Hub::ClientIntakeForm.new(intake, { primary_first_name: "Patty" }) }
      it "returns nil" do
        expect(form.dependents_attributes).to eq nil
      end
    end

    context "with dependents attributes" do
      let(:intake) { create :intake, dependents: [(create :dependent)] }
      let(:form) { Hub::ClientIntakeForm.new(intake, dependents_attributes: [{ id: intake.dependents.first.id, first_name: "Paul", last_name: "Persimmon", birth_date: "2009-12-12" }]) }
      it "returns an array with dependent attributes" do
        expect(form.dependents_attributes.length).to eq 1
        expect(form.dependents_attributes.first).to have_key(:birth_date)
        expect(form.dependents_attributes.first).to have_key(:first_name)
        expect(form.dependents_attributes.first).to have_key(:id)
        expect(form.dependents_attributes.first).to have_key(:last_name)
      end
    end
  end
end
