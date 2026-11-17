class C;
  rand bit [3:0] down;
  rand bit [0:3] up;
  constraint valid_order { down[3:0] == 4'b0001; up[0:3] == 4'b0010; }
endclass
module top;
  C c;
  initial begin
    c = new;
    if (!c.randomize() || c.down !== 4'b0001 || c.up !== 4'b0010)
      $fatal(1, "wrong randomization result");
    $display("PASS");
  end
endmodule
