# == Schema Information
#
# Table name: system_emails
#
#  id         :bigint           not null, primary key
#  body       :string           not null
#  sent_at    :datetime         not null
#  subject    :string           not null
#  to         :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  client_id  :bigint           not null
#
class SystemEmail < ApplicationRecord
  include ContactRecord

  belongs_to :client
  validates_presence_of :body
  validates_presence_of :subject
  validates_presence_of :to
  validates_presence_of :sent_at
  has_one_attached :attachment

  after_create :deliver, :broadcast

  def author
    "GetYourRefund Team"
  end

  def datetime
    sent_at
  end

  def attachment
    nil
  end

  private

  def deliver
    OutgoingEmailMailer.user_message(outgoing_email: self).deliver_later
  end

  def broadcast
    ClientChannel.broadcast_contact_record(self)
  end
end
