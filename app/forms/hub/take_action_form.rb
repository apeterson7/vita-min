module Hub
  class TakeActionForm < Form
    include MessageSending
    attr_accessor :tax_return,
                  :tax_return_id, 
                  :tax_returns, 
                  :status, 
                  :locale, 
                  :message_body, 
                  :contact_method, 
                  :internal_note_body, 
                  :action_list
    validate :belongs_to_client
    validate :status_has_changed

    def initialize(client, current_user, *args, **attributes)
      @client = client
      @current_user = current_user
      @tax_returns = client.tax_returns.order(year: :asc)
      @action_list = []
      super(*args, **attributes)

      set_default_locale if @locale.blank?
      set_default_message_body if @message_body.nil?
      set_default_contact_method if @contact_method.nil?
    end

    def language_difference_help_text
      if @client.intake.preferred_interview_language.present? && (locale != @client.intake.preferred_interview_language)
        I18n.t(
          "hub.clients.edit_take_action.language_mismatch",
          interview_language: language_label(@client.intake.preferred_interview_language)
        )
      end
    end

    def contact_method_options
      methods = []
      methods << { value: "email", label: I18n.t("general.email") } if @client.intake.email_notification_opt_in_yes?
      methods << { value: "text_message", label: I18n.t("general.text_message") } if @client.intake.sms_notification_opt_in_yes?

      # We should not have an expected case where a client hasn't opted in, but it might occur rarely or on demo
      # We don't want this form to fail silently if that is the case.
      raise StandardError.new("Client has not opted in to any communications") unless methods.present?

      methods
    end

    def contact_method_help_text
      if @client.intake.email_notification_opt_in_yes? ^ @client.intake.sms_notification_opt_in_yes? # ^ = XOR operator
        preferred = @client.intake.email_notification_opt_in_yes? ? I18n.t("general.email") : I18n.t("general.text_message")
        other_method = preferred == I18n.t("general.text_message") ? I18n.t("general.email") : I18n.t("general.text_message")
        I18n.t(
          "hub.clients.edit_take_action.prefers_one_contact_method",
          preferred: preferred.downcase,
          other_method: other_method.downcase
        )
      end
    end

    def take_action
      return false unless valid?

      tax_return.status = status
      if tax_return.save
        SystemNote.create_status_change_note(@current_user, tax_return)
        @action_list << I18n.t("hub.clients.update_take_action.flash_message.status")
        send_message if message_body.present?
        create_note if internal_note_body.present?
      end
      true
    end

    def self.permitted_params
      [:tax_return_id, :status, :locale, :message_body, :contact_method, :internal_note_body]
    end

    def tax_return
      @tax_return ||= @client.tax_returns.find_by(id: tax_return_id)
    end

    private

    def send_message
      case contact_method
      when "email"
        send_email(message_body, subject_locale: locale)
        @action_list << I18n.t("hub.clients.update_take_action.flash_message.email")
      when "text_message"
        send_text_message(message_body)
        @action_list << I18n.t("hub.clients.update_take_action.flash_message.text_message")
      end
    end

    def create_note
      Note.create!(
          body: internal_note_body,
          client: @client,
          user: @current_user
      )
      @action_list << I18n.t("hub.clients.update_take_action.flash_message.internal_note")
    end

    def current_user
      @current_user
    end

    def language_label(key)
      I18n.t("general.language_options.#{key}")
    end

    def set_default_message_body
      @message_body = case status
                      when "intake_more_info", "prep_more_info", "review_more_info"
                        document_list = @client.intake.relevant_document_types.map do |doc_type|
                          "  - " + doc_type.translated_label(@client.intake.locale)
                        end.join("\n")
                        I18n.t(
                            "hub.status_macros.needs_more_information",
                            required_documents: document_list,
                            document_upload_link: @client.intake.requested_docs_token_link,
                            locale: @client.intake.locale
                        )
                      when "prep_ready_for_review"
                        I18n.t("hub.status_macros.ready_for_qr", locale: @client.intake.locale)
                      when "filed_accepted"
                        I18n.t("hub.status_macros.accepted", locale: @client.intake.locale)
                      else
                        ""
                      end
    end

    def set_default_contact_method
      default = "email"
      prefers_sms_only = @client.intake.sms_notification_opt_in_yes? && @client.intake.email_notification_opt_in_no?
      @contact_method = prefers_sms_only ? "text_message" : default
    end

    def set_default_locale
      @locale = @client.intake.locale
    end

    def status_has_changed
      errors.add(:status, I18n.t("forms.errors.status_must_change")) if status == tax_return&.status
    end

    def belongs_to_client
      errors.add(:tax_return_id, I18n.t("forms.errors.tax_return_belongs_to_client")) unless tax_return.present?
    end
  end
end
