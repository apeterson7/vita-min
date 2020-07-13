require "rails_helper"

RSpec.describe Documents::Form1099miscsController do
  let(:attributes) { {} }
  let(:intake) { create :intake, intake_ticket_id: 1234, **attributes }

  describe ".show?" do
    it "returns false" do
      expect(subject.class.show?(intake)).to eq false
    end
  end
end

