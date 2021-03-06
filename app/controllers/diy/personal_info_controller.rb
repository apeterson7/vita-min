module Diy
  class PersonalInfoController < DiyController
    def current_diy_intake
      super || DiyIntake.new
    end

    def illustration_path; end

    def self.form_name
      "diy_personal_info_form"
    end

    def tracking_data
      {}
    end

    def after_update_success
      session[:diy_intake_id] = @form.diy_intake.id
    end

    def form_params
      super.merge(
        source: current_diy_intake.source || source,
        referrer: current_diy_intake.referrer || referrer,
        locale: I18n.locale,
      )
    end
  end
end
