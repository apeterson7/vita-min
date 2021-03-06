module Questions
  class FinalInfoController < QuestionsController
    layout "question"

    private

    def illustration_path; end

    def after_update_success
      current_intake.update(completed_at: Time.now)
      send_confirmation_message
    end

    def tracking_data
      {}
    end

    def send_confirmation_message
      @client = current_intake.client

      if current_intake.sms_notification_opt_in_yes?
        ClientMessagingService.send_system_text_message(
          @client,
          I18n.t(
            "messages.successful_submission.sms_body",
            locale: current_intake.locale,
            preferred_name: current_intake.preferred_name,
            client_id: current_intake.client_id,
            document_upload_url: current_intake.requested_docs_token_link
          ),
        )
      end

      if current_intake.email_notification_opt_in_yes?
        ClientMessagingService.send_system_email(
          @client,
          I18n.t(
            "messages.successful_submission.email_body",
            locale: current_intake.locale,
            preferred_name: current_intake.preferred_name,
            client_id: current_intake.client_id,
            document_upload_url: current_intake.requested_docs_token_link
          ),
          I18n.t("messages.successful_submission.subject", locale: current_intake.locale)
        )
      end
    end
  end
end
