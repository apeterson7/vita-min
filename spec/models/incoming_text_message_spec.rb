require "rails_helper"

RSpec.describe IncomingTextMessage, type: :model do
  describe "required fields" do
    context "without required fields" do
      let(:message) { described_class.new }

      it "is not valid and adds an error to each field" do
        expect(message).not_to be_valid
        expect(message.errors).to include :body
        expect(message.errors).to include :from_phone_number
        expect(message.errors).to include :received_at
        expect(message.errors).to include :client
      end
    end

    context "with all required fields" do
      let(:message) do
        described_class.new(
          body: "hi",
          from_phone_number: "+15005550006",
          received_at: DateTime.now,
          client: create(:client)
        )
      end

      it "is valid and does not have errors" do
        expect(message).to be_valid
        expect(message.errors).to be_blank
      end
    end
  end

  describe "#from_phone_number" do
    let(:incoming_text_message) { build :incoming_text_message, from_phone_number: input_number }
    before { incoming_text_message.valid? }

    context "with e164" do
      let(:input_number) { "+15005550006" }
      it "is valid" do
        expect(incoming_text_message.errors).not_to include :from_phone_number
      end
    end

    context "without a + but otherwise correct" do
      let(:input_number) { "15005550006" }
      it "is not valid" do
        expect(incoming_text_message.errors).to include :from_phone_number
      end
    end

    context "without a +1 but otherwise correct" do
      let(:input_number) { "5005550006" }

      it "is not valid" do
        expect(incoming_text_message.errors).to include :from_phone_number
      end
    end

    context "with any non-numeric characters" do
      let(:input_number) { "+1500555-006" }

      it "is not valid" do
        expect(incoming_text_message.errors).to include :from_phone_number
      end
    end
  end

  describe "#formatted_time" do
    let(:message) { create :incoming_text_message, received_at: DateTime.new(2020, 2, 1, 2, 45, 1) }

    it "returns a human readable time" do
      expect(message.formatted_time).to eq "2:45 AM UTC"
    end
  end
end
