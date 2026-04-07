class Provider::Anthropic::ChatStreamParser
  Chunk = Provider::LlmConcept::ChatStreamChunk

  def initialize(event)
    @event = event
  end

  def parsed
    type = event.dig("type")

    case type
    when "content_block_delta"
      delta = event.dig("delta")
      delta_type = delta&.dig("type")

      case delta_type
      when "text_delta"
        Chunk.new(type: "output_text", data: delta.dig("text"))
      when "input_json_delta"
        # Tool input streaming — accumulate but don't emit
        nil
      end
    when "content_block_start"
      block = event.dig("content_block")
      if block&.dig("type") == "tool_use"
        Chunk.new(type: "tool_use", data: {
          id: block.dig("id"),
          name: block.dig("name"),
          input: {}
        })
      end
    when "content_block_stop"
      # Individual block finished — no action needed
      nil
    when "message_stop"
      Chunk.new(type: "response", data: { id: event.dig("message", "id") || "msg_stream" })
    when "message_start"
      # Message started — no action needed
      nil
    when "message_delta"
      # Message-level delta (stop_reason, usage) — check for end
      if event.dig("delta", "stop_reason") == "end_turn"
        Chunk.new(type: "response", data: { id: "msg_complete" })
      end
    end
  end

  private
    attr_reader :event
end
