# == Schema Information
#
# Table name: diy_intakes
#
#  id                 :bigint           not null, primary key
#  email_address      :string
#  locale             :string
#  preferred_name     :string
#  referrer           :string
#  source             :string
#  state_of_residence :string
#  token              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  requester_id       :bigint
#  ticket_id          :bigint
#  visitor_id         :string
#
# Indexes
#
#  index_diy_intakes_on_token  (token) UNIQUE
#
FactoryBot.define do
  factory :diy_intake do
    preferred_name { "Gary Gnome" }
    state_of_residence { "CA" }

    trait :filled_out do
      ticket_id { 789 }
      locale { "es" }
      referrer { "https://www.gallopingacrosstheplains.horse/tax-help" }
      source { "horse-help" }
    end
  end
end
