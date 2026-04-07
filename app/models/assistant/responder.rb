class Assistant::Responder
  def initialize(message:, instructions:, function_tool_caller:, llm:)
    @message = message
    @instructions = instructions
    @function_tool_caller = function_tool_caller
    @llm = llm
  end

  def on(event_name, &block)
    listeners[event_name.to_sym] << block
  end

  def respond(conversation_messages: [])
    @conversation_messages = conversation_messages

    streamer = proc do |chunk|
      case chunk.type
      when "output_text"
        emit(:output_text, chunk.data)
      when "response"
        response = chunk.data

        if response.function_requests.any?
          handle_follow_up_response(response)
        else
          emit(:response, { id: response.id })
        end
      end
    end

    get_llm_response(streamer: streamer)
  end

  private
    attr_reader :message, :instructions, :function_tool_caller, :llm, :conversation_messages

    def handle_follow_up_response(response)
      streamer = proc do |chunk|
        case chunk.type
        when "output_text"
          emit(:output_text, chunk.data)
        when "response"
          emit(:response, { id: chunk.data.id })
        end
      end

      function_tool_calls = function_tool_caller.fulfill_requests(response.function_requests)

      emit(:response, {
        id: response.id,
        function_tool_calls: function_tool_calls
      })

      get_llm_response(
        streamer: streamer,
        function_results: function_tool_calls.map(&:to_result)
      )
    end

    def get_llm_response(streamer:, function_results: [])
      response = llm.chat_response(
        message.content,
        model: message.ai_model,
        instructions: instructions,
        functions: function_tool_caller.function_definitions,
        function_results: function_results,
        streamer: streamer,
        messages: conversation_messages
      )

      unless response.nil? || response.success?
        raise response.error
      end

      response&.data
    end

    def emit(event_name, payload = nil)
      listeners[event_name.to_sym].each { |block| block.call(payload) }
    end

    def listeners
      @listeners ||= Hash.new { |h, k| h[k] = [] }
    end
end
