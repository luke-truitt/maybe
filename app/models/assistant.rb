class Assistant
  include Provided, Configurable, Broadcastable

  attr_reader :chat, :instructions

  class << self
    def for_chat(chat)
      config = config_for(chat)
      new(chat, instructions: config[:instructions], functions: config[:functions])
    end
  end

  def initialize(chat, instructions: nil, functions: [])
    @chat = chat
    @instructions = instructions
    @functions = functions
  end

  def respond_to(message)
    assistant_message = AssistantMessage.new(
      chat: chat,
      content: "",
      ai_model: message.ai_model
    )

    responder = Assistant::Responder.new(
      message: message,
      instructions: instructions,
      function_tool_caller: function_tool_caller,
      llm: get_model_provider(message.ai_model)
    )

    # Build conversation history from prior messages (exclude the current one being responded to)
    prior_messages = chat.conversation_messages.ordered.where.not(id: message.id).to_a

    responder.on(:output_text) do |text|
      if assistant_message.content.blank?
        stop_thinking

        assistant_message.append_text!(text)
      else
        assistant_message.append_text!(text)
      end
    end

    responder.on(:response) do |data|
      update_thinking("Analyzing your data...")

      if data[:function_tool_calls].present?
        assistant_message.tool_calls = data[:function_tool_calls]
      end
    end

    responder.respond(conversation_messages: prior_messages)
  rescue => e
    stop_thinking
    chat.add_error(e)
  end

  private
    attr_reader :functions

    def function_tool_caller
      function_instances = functions.map do |fn|
        fn.new(chat.user)
      end

      @function_tool_caller ||= FunctionToolCaller.new(function_instances)
    end
end
