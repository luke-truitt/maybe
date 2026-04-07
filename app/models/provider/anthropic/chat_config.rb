class Provider::Anthropic::ChatConfig
  def initialize(functions: [], function_results: [], messages: [])
    @functions = functions
    @function_results = function_results
    @messages = messages
  end

  def tools
    functions.map do |fn|
      {
        name: fn[:name],
        description: fn[:description],
        input_schema: fn[:params_schema]
      }
    end
  end

  def build_messages(prompt)
    conversation = build_conversation_history

    # Add tool results if this is a follow-up after function execution
    if function_results.any?
      tool_result_content = function_results.map do |fn_result|
        {
          type: "tool_result",
          tool_use_id: fn_result[:call_id],
          content: fn_result[:output].to_json
        }
      end

      conversation << { role: "user", content: tool_result_content }
    else
      conversation << { role: "user", content: prompt }
    end

    conversation
  end

  private
    attr_reader :functions, :function_results, :messages

    def build_conversation_history
      messages.filter_map do |msg|
        case msg.role
        when "user"
          { role: "user", content: msg.content }
        when "assistant"
          { role: "assistant", content: msg.content }
        end
      end
    end
end
