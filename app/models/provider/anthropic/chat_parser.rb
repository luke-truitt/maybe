class Provider::Anthropic::ChatParser
  def initialize(response)
    @response = response
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :response

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      response.dig("id")
    end

    def response_model
      response.dig("model")
    end

    def messages
      text_blocks = content_blocks.select { |b| b.dig("type") == "text" }
      return [] if text_blocks.empty?

      [ ChatMessage.new(
        id: response_id,
        output_text: text_blocks.map { |b| b.dig("text") }.join("\n")
      ) ]
    end

    def function_requests
      tool_blocks = content_blocks.select { |b| b.dig("type") == "tool_use" }

      tool_blocks.map do |block|
        ChatFunctionRequest.new(
          id: block.dig("id"),
          call_id: block.dig("id"),
          function_name: block.dig("name"),
          function_args: block.dig("input").to_json
        )
      end
    end

    def content_blocks
      response.dig("content") || []
    end
end
