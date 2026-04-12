module sv_class_getter_handle_wait1;
  class hopper_t;
    int q[$];
    function void try_put(int v);
      q.push_back(v);
    endfunction
    task get(output int v);
      wait (q.size() != 0);
      v = q.pop_front();
    endtask
    task run();
      int v;
      forever begin
        get(v);
        if (v == 2) break;
      end
    endtask
  endclass

  class service_impl;
    hopper_t h;
    function new();
      h = new;
    endfunction
    function hopper_t get_hopper();
      return h;
    endfunction
  endclass

  initial begin
    service_impl svc;
    hopper_t h;
    svc = new;
    h = svc.get_hopper();
    fork
      h.run();
    join_none
    #0 h.try_put(1);
    #0 h.try_put(2);
    repeat (20) #0;
    if (h.q.size() != 0) begin
      $display("FAIL size=%0d", h.q.size());
      $finish_and_return(1);
    end
    $display("PASS");
  end
endmodule
