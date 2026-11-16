`timescale 1ns/1ns
module tb;
  reg a = 0;
  integer arr [0:1];
  integer idx = 1;
  wire fixed_q, indexed_q, transitions_q;
  assign #(arr[0]) fixed_q = a;
  assign #(arr[idx]) indexed_q = a;
  assign #(arr[0], arr[idx], arr[1]) transitions_q = a;

  task check;
    input [2:0] expected;
    begin
      if ({fixed_q, indexed_q, transitions_q} !== expected) begin
        $display("FAIL t=%0t got=%b expected=%b", $time,
                 {fixed_q, indexed_q, transitions_q}, expected);
        $finish(0);
      end
    end
  endtask

  initial begin
    arr[0] = 2;
    arr[1] = 5;
    #10 a = 1;
    #3 check(3'b101);
    #3 check(3'b111);
    #4 idx = 0;
    arr[0] = 3;
    a = 0;
    #2 check(3'b111);
    #2 check(3'b000);
    #6 a = 1'bz;
    #4 check(3'bzz0);
    #2 check(3'bzzz);
    $display("PASS");
    $finish(0);
  end
endmodule
