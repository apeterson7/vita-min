class RequireVisitorIdOnIntake < ActiveRecord::Migration[6.0]
  def change
    Intake.where(visitor_id: nil).or(Intake.where(visitor_id: "")).find_each do |intake|
      intake.update(visitor_id: SecureRandom.hex(26))
    end

    change_column_null :intakes, :visitor_id, false
  end
end
