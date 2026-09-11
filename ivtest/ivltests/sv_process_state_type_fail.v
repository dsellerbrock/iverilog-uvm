module sv_process_state_type_fail;
  typedef enum { OTHER_FINISHED, OTHER_RUNNING } other_t;
  typedef process::state state_t;
  state_t s;
  other_t other;
  initial begin
    s = 1;
    s = OTHER_RUNNING;
    other = process::RUNNING;
  end
endmodule
