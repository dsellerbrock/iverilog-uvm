`timescale 1ns/1ps

// A static task that owns explicit-automatic locals has a mixed-lifetime
// activation context. The variable-index read port used by @(words[index])
// must keep independent address/change state for simultaneous invocations.
module sv_static_task_auto_array_port_context;
  time woke_at[0:1];
  logic [7:0] observed[0:1];
  int done[0:1];

  task static watch(input int id);
    automatic int call_id = id;
    automatic logic [7:0] words[0:1];
    automatic int index;
    automatic int delay_ns;

    index = call_id;
    delay_ns = call_id == 0 ? 5 : 10;
    words[0] = 0;
    words[1] = 0;

    fork
      begin
        @(words[index]);
        woke_at[call_id] = $time;
        observed[call_id] = words[index];
        done[call_id] = 1;
      end
      begin
        #(delay_ns);
        words[index] = call_id == 0 ? 8'h51 : 8'ha2;
      end
    join
  endtask

  initial begin
    fork
      watch(0);
      watch(1);
    join_none

    #20;
    if (done[0] !== 1 || woke_at[0] != 5 || observed[0] !== 8'h51)
      $fatal(1, "call 0 shared array-port state: done=%0d time=%0t value=%h",
             done[0], woke_at[0], observed[0]);
    if (done[1] !== 1 || woke_at[1] != 10 || observed[1] !== 8'ha2)
      $fatal(1, "call 1 shared array-port state: done=%0d time=%0t value=%h",
             done[1], woke_at[1], observed[1]);
    $display("PASSED");
  end
endmodule
