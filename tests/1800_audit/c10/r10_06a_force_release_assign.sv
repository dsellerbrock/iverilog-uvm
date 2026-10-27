module r10_06a_force_release_assign;
  logic a, d;
  initial begin
    assign d = a;
    a = 0; #1 $display("BASE d=%b", d);
    force d = 1; #1 $display("FORCE d=%b", d);
    release d; #1 $display("RELEASE d=%b", d);
    $finish;
  end
endmodule
