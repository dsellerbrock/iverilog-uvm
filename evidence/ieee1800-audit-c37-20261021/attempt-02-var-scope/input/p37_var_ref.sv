module p37 #(parameter int P = 7) (
  input logic a,
  output logic [3:0] y
);
  logic [7:0] v;
  sub u();
  initial begin
    $display("v=%0d", v);
    $probe37;
  end
endmodule

module sub;
endmodule
