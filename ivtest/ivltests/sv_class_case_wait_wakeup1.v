module test;
  typedef enum int { PH_DORMANT = 1, PH_DONE = 256 } phase_state_t;
  typedef enum int { OP_EQ = 0, OP_NE = 1 } wait_op_t;

  class phase_t;
    phase_state_t m_state;

    function new();
      m_state = PH_DORMANT;
    endfunction

    function void set_state(phase_state_t s);
      m_state = s;
    endfunction

    function phase_state_t get_state();
      return m_state;
    endfunction

    task wait_for_state(phase_state_t s, wait_op_t op = OP_EQ);
      case (op)
        OP_EQ: begin
          wait ((s & m_state) != 0);
        end
        OP_NE: begin
          wait ((s & m_state) == 0);
        end
      endcase
    endtask
  endclass

  phase_t common;
  bit woke;

  initial begin
    common = new();
    woke = 1'b0;

    fork
      begin
        common.wait_for_state(PH_DONE);
        woke = 1'b1;
      end
    join_none

    #1;
    common.set_state(PH_DONE);
    #1;

    if (!woke || common.get_state() != PH_DONE) begin
      $display("FAIL woke=%0d state=%0d", woke, common.get_state());
      $finish(1);
    end

    $display("PASS");
  end
endmodule
