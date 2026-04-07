class Provider::Anthropic < Provider
  include LlmConcept

  Error = Class.new(Provider::Error)

  MODELS = %w[claude-sonnet-4-20250514]

  def initialize(api_key)
    @client = ::Anthropic::Client.new(api_key: api_key)
  end

  def supports_model?(model)
    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, messages: [])
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results,
        messages: messages
      )

      collected_output = ""
      collected_tool_uses = []
      response_id = nil

      if streamer.present?
        client.messages.create(
          model: model,
          max_tokens: 4096,
          system: instructions || "",
          messages: chat_config.build_messages(prompt),
          tools: chat_config.tools,
          stream: proc { |event|
            parsed = ChatStreamParser.new(event).parsed
            next if parsed.nil?

            case parsed.type
            when "output_text"
              collected_output += parsed.data
              streamer.call(parsed)
            when "tool_use"
              collected_tool_uses << parsed.data
            when "response"
              response_id = parsed.data[:id]
              function_requests = collected_tool_uses.map do |tu|
                LlmConcept::ChatFunctionRequest.new(
                  id: tu[:id],
                  call_id: tu[:id],
                  function_name: tu[:name],
                  function_args: tu[:input].to_json
                )
              end

              chat_response = LlmConcept::ChatResponse.new(
                id: response_id,
                model: model,
                messages: collected_output.present? ? [ LlmConcept::ChatMessage.new(id: response_id, output_text: collected_output) ] : [],
                function_requests: function_requests
              )

              streamer.call(LlmConcept::ChatStreamChunk.new(type: "response", data: chat_response))
            end
          }
        )

        # Return nil — streaming handled via callbacks
        nil
      else
        raw_response = client.messages.create(
          model: model,
          max_tokens: 4096,
          system: instructions || "",
          messages: chat_config.build_messages(prompt),
          tools: chat_config.tools
        )

        ChatParser.new(raw_response).parsed
      end
    end
  end

  private
    attr_reader :client
end
