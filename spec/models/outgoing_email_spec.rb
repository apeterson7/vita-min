# == Schema Information
#
# Table name: outgoing_emails
#
#  id         :bigint           not null, primary key
#  body       :string           not null
#  sent_at    :datetime         not null
#  subject    :string           not null
#  to         :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  client_id  :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_outgoing_emails_on_client_id  (client_id)
#  index_outgoing_emails_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe OutgoingEmail, type: :model do
  before do
    allow(ClientChannel).to receive(:broadcast_contact_record)
  end

  context "interaction tracking" do
    it_behaves_like "an outgoing interaction" do
      let(:subject) { build :outgoing_email }
    end
  end

  describe "required fields" do
    context "without required fields" do
      let(:email) { OutgoingEmail.new }

      it "is not valid and adds an error to each field" do
        expect(email).not_to be_valid
        expect(email.errors).to include :client
        expect(email.errors).to include :to
        expect(email.errors).to include :subject
        expect(email.errors).to include :body
        expect(email.errors).to include :sent_at
      end
    end

    context "with all required fields" do
      let(:message) do
        OutgoingEmail.new(
            client: create(:client),
            to: "someone@example.com",
            subject: "this is a subject",
            body: "hi",
            sent_at: DateTime.now,
            user: create(:user)
            )
      end

      it "is valid and does not have errors" do
        expect(message).to be_valid
        expect(message.errors).to be_blank
      end

      context "after create" do
        it "enqueues delivery of the message" do
          expect {
            message.save
          }.to have_enqueued_email
        end

        it "broadcasts a message" do
          message.save
          expect(ClientChannel).to have_received(:broadcast_contact_record).with(message)
        end
      end
    end
  end
end
