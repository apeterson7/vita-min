require "rails_helper"

RSpec.describe BacktaxesForm do
  describe "#save" do
    it "makes a new client with tax returns for each year they need" do
      intake = Intake.new
      form = BacktaxesForm.new(intake, {
        needs_help_2017: "yes",
        needs_help_2018: "no",
        needs_help_2019: "yes",
      })
      expect {
        form.save
      }.to change(Client, :count).by(1)
      client = Client.last
      expect(client.intake).to eq(intake.reload)
      expect(client.tax_returns.pluck(:year).sort).to eq([2017, 2019])
      expect(client.tax_returns.where(service_type: "online_intake").count).to eq 2
    end
  end
end