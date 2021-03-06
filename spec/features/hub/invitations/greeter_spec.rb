require "rails_helper"

RSpec.feature "Inviting greeters" do
  context "As an admin user" do
    let(:user) { create :admin_user }

    let!(:coalition) { create :coalition, name: "Kohlrabi Koalition" }
    let!(:coalition_2) { create :coalition, name: "Cabbage Coalition" }
    let!(:organization) { create :vita_partner, name: "Octopus Organization" }

    before do
      login_as user
    end

    scenario "Inviting, re-sending invites, and accepting invites" do
      visit hub_user_profile_path
      click_on "Invitations"

      # Invitations page
      within("h1") do
        expect(page).to have_text "Invitations"
      end
      click_on "Invite a new greeter"

      # new invitation page
      expect(page).to have_text "Send a new invitation"
      fill_in "What is their name?", with: "Gavin Ginger"
      fill_in "What is their email?", with: "colleague@ginger.org"
      expect(page).to have_text "Select coalition(s) and/or organizations(s)"
      check "Kohlrabi Koalition"
      check "Cabbage Coalition"
      check "Octopus Organization"
      click_on "Send invitation email"

      # back on the invitations page
      within(".flash--notice") do
        expect(page).to have_text "We sent an email invitation to colleague@ginger.org"
      end
      within(".invitations") do
        expect(page).to have_text "Gavin Ginger"
        expect(page).to have_text "colleague@ginger.org"
        expect(page).to have_text "Greeter"
        expect(page).to have_text "Kohlrabi Koalition"
        expect(page).to have_text "Octopus Organization"
        expect(page).to have_text "Cabbage Coalition"
      end
      invited_user = User.where(invited_by: user).last
      expect(invited_user).to be_present

      # resend invitation
      within("#invitation-#{invited_user.id}") do
        click_on "Resend invitation email"
      end
      within(".flash--notice") do
        expect(page).to have_text "Invitation re-sent to colleague@ginger.org"
      end
      within(".invitations") do
        expect(page).to have_text "Gavin Ginger"
        expect(page).to have_text "colleague@ginger.org"
        expect(page).to have_text "Greeter"
        expect(page).to have_text "Kohlrabi Koalition"
        expect(page).to have_text "Octopus Organization"
        expect(page).to have_text "Cabbage Coalition"
      end
      invited_user = User.where(invited_by: user).last
      expect(invited_user.invitation_token).to be_present

      logout

      # New invitation recipient signing up!
      mail = ActionMailer::Base.deliveries.last
      html_body = mail.body.parts[1].decoded
      accept_invite_url = Nokogiri::HTML.parse(html_body).at_css("a")["href"]
      expect(mail.subject).to eq "You've been invited to GetYourRefund"
      expect(accept_invite_url).to be_present
      expect(mail.body.encoded).to have_text "Hello,"
      expect(mail.body.encoded).to have_text "#{user.name} (#{user.email}) has invited #{invited_user.name} to create an account on GetYourRefund"
      expect(mail.body.encoded).to have_text "If you don't want to accept the invitation, please ignore this email."

      # Sign up page
      visit accept_invite_url
      expect(page).to have_text "Thank you for signing up to help!"
      expect(page).to have_text "colleague@ginger.org"
      expect(page).to have_text "Kohlrabi Koalition"
      expect(page).to have_text "Cabbage Coalition"
      expect(page).to have_text "Octopus Organization"
      expect(find_field("What is your name?").value).to eq "Gavin Ginger"
      fill_in "Please choose a strong password", with: "c0v3rt-c4ul1fl0wer"
      fill_in "Enter your new password again", with: "c0v3rt-c4ul1fl0wer"
      click_on "Get started"

      expect(page).to have_text "You're all set and ready to go! You've joined an amazing team!"
      expect(page).to have_text "Gavin Ginger"
      expect(page).to have_text "Greeter"
      expect(page).to have_text "Kohlrabi Koalition"
      expect(page).to have_text "Cabbage Coalition"
      expect(page).to have_text "Octopus Organization"
    end
  end
end
