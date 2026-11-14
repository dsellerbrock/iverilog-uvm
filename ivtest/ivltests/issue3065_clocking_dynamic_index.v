// IEEE 1800-2023 14.15: the expression of an event control can denote a
// clocking block input or a slice thereof; "Slices can include dynamic
// indices, which are evaluated once when the @ expression executes."
`timescale 1ns/1ps
module top;
  bit clk = 0;
  bit [3:0] d = 0;
  integer index = 0;
  int woke = 0;
  int errors = 0;
  clocking cb @(posedge clk);
    input d;
  endclocking
  initial forever #5 clk = ~clk;

  task automatic check(input int want, input string what);
    if (woke !== want) begin
      $display("FAILED: t=%0t %s: woke=%0d, want %0d", $time, what, woke, want);
      errors += 1;
    end
  endtask

  // Each activation waits on its own bit.
  task automatic wait_bit(input int i, input int tag);
    @(posedge cb.d[i]);
    woke += tag;
  endtask

  initial begin
    @(cb);
    fork
      begin
        @(posedge cb.d[index]);
        woke += 1;
      end
      begin
        // The waiter is on bit 0. Changing the index and raising bit 1
        // must not wake it.
        #1 index = 1;
        d = 4'b0010;
        #10 check(0, "bit 1 rose after the index changed");
        d = 4'b0011;
        #10 check(1, "bit 0 rose");
      end
    join

    fork
      wait_bit(2, 10);
      wait_bit(3, 100);
    join_none
    #1 d = 4'b1011;
    #10 check(101, "bit 3 rose");
    d = 4'b1111;
    #10 check(111, "bit 2 rose");

    // A slice with a dynamic base, no edge keyword: any change of the
    // slice that was selected when the event control executed.
    index = 0;
    fork
      begin
        @(cb.d[index +: 2]);
        woke += 1000;
      end
    join_none
    #1 index = 2;
    d = 4'b0111;
    #10 check(111, "the other slice changed");
    d = 4'b0110;
    #10 check(1111, "the selected slice changed");

    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
