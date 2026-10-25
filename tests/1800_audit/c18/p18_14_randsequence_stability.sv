// IEEE 1800-2017/2023 §18.14.2: randsequence choices are independent
// of sibling-thread execution order.
module test;
  string seq_a, seq_b;
  int unsigned urand_a, urand_b;
  process parent_thread;

  initial begin
    seq_a = "";
    seq_b = "";
    parent_thread = process::self();
    parent_thread.srandom(303);
    fork
      begin
`ifndef DELAY_A
        #1;
`endif
        urand_a = $urandom();
        repeat (16) begin
          randsequence ()
            select_a : a0 | a1 | a2 ;
            a0 : { seq_a = {seq_a, "0"}; } ;
            a1 : { seq_a = {seq_a, "1"}; } ;
            a2 : { seq_a = {seq_a, "2"}; } ;
          endsequence
        end
        $display("A_u=%0d", urand_a);
        $display("A_rs=%s", seq_a);
      end
      begin
`ifdef DELAY_A
        #1;
`endif
        urand_b = $urandom();
        repeat (16) begin
          randsequence ()
            select_b : b0 | b1 | b2 ;
            b0 : { seq_b = {seq_b, "0"}; } ;
            b1 : { seq_b = {seq_b, "1"}; } ;
            b2 : { seq_b = {seq_b, "2"}; } ;
          endsequence
        end
        $display("B_u=%0d", urand_b);
        $display("B_rs=%s", seq_b);
      end
    join

    $display("PASS randsequence thread stability");
    $finish;
  end
endmodule
