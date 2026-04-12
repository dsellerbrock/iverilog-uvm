module test;
  typedef enum int {
    PH_DORMANT   = 1,
    PH_SCHEDULED = 2,
    PH_SYNCING   = 4,
    PH_DONE      = 256
  } phase_state_t;

  class phase_t;
    string name;
    phase_state_t m_state;
    phase_t pred;
    phase_t succ;

    function new(string n);
      name = n;
      m_state = PH_DORMANT;
    endfunction

    function void set_state(phase_state_t state);
      m_state = state;
    endfunction

    task wait_for_state(phase_state_t state);
      wait (m_state >= state);
    endtask
  endclass

  class hopper_t;
    phase_t q[$];

    function void schedule_phase(phase_t ph);
      if (ph.m_state < PH_SCHEDULED) begin
        ph.set_state(PH_SCHEDULED);
        q.push_back(ph);
      end
    endfunction

    task get(output phase_t ph);
      wait (q.size() != 0);
      ph = q.pop_front();
    endtask

    task process_phase(phase_t ph);
      if (ph.pred != null)
        ph.pred.wait_for_state(PH_DONE);
      ph.set_state(PH_SYNCING);
      ph.set_state(PH_DONE);
      if (ph.succ != null)
        schedule_phase(ph.succ);
    endtask

    task run(phase_t first);
      phase_t ph;

      schedule_phase(first);
      fork
        forever begin
          get(ph);
          fork
            automatic phase_t cur = ph;
            begin
              process_phase(cur);
            end
          join_none
        end
      join_none
    endtask
  endclass

  initial begin
    hopper_t hopper;
    phase_t common;
    phase_t build;

    hopper = new;
    common = new("common");
    build = new("build");
    common.succ = build;
    build.pred = common;

    hopper.run(common);
    #1;

    if (common.m_state !== PH_DONE) begin
      $display("FAIL common=%0d", common.m_state);
      $finish(1);
    end

    if (build.m_state !== PH_DONE) begin
      $display("FAIL build=%0d", build.m_state);
      $finish(1);
    end

    $display("PASS");
  end
endmodule
