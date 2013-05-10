require 'rubygems'
require 'bud'

module LogProto
  state do
    interface input, :add_entry, [:command]
  end
end

module ReplicatedLog
  include LogProto

  state do
    channel :append_entries_request, [:@dest, :leader_id, :prev_log_index, :prev_log_term, :entries, :commitIndex]
    channel :append_entries_response, [:@dest, :candidate_id, :term, :success]

    table :log, [:term, :index, :command]
  end

end
