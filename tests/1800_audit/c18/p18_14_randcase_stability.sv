// IEEE 1800-2017/2023 §18.14.2: randcase branch choices are independent
// of sibling-thread execution order.
module test;
  string seq_a, seq_b;
  int unsigned urand_a, urand_b;
  process parent_thread;

  initial begin
    seq_a = "";
    seq_b = "";
    parent_thread = process::self();
    parent_thread.srandom(202);
    fork
      begin
`ifndef DELAY_A
        #1;
`endif
        urand_a = $urandom();
        repeat (16) begin
          randcase
            1: seq_a = {seq_a, "0"};
            1: seq_a = {seq_a, "1"};
            1: seq_a = {seq_a, "2"};
          endcase
        end
        $display("A_u=%0d", urand_a);
        $display("A_rc=%s", seq_a);
      end
      begin
`ifdef DELAY_A
        #1;
`endif
        urand_b = $urandom();
        repeat (16) begin
          randcase
            1: seq_b = {seq_b, "0"};
            1: seq_b = {seq_b, "1"};
            1: seq_b = {seq_b, "2"};
          endcase
        end
        $display("B_u=%0d", urand_b);
        $display("B_rc=%s", seq_b);
      end
    join

    $display("PASS randcase thread stability");
    $finish;
  end
endmodule
