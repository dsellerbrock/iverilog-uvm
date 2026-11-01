package issue2150_pkg;
  parameter int TxWidth = 4;
  typedef logic [TxWidth-1:0] tx_t;
  parameter tx_t On = 4'b0101;
  parameter tx_t Off = 4'b1010;
  typedef enum logic [1:0] {Idle = 2'd0, Busy = 2'd2} state_t;
endpackage

module issue2150_sub (
  input issue2150_pkg::tx_t en_i,
  input issue2150_pkg::state_t st_i,
  input logic [7:0] k_i,
  output logic [13:0] q
);
  assign q = {en_i, st_i, k_i};
endmodule

module issue2150_explicit_named_package_ports;
  localparam logic [7:0] K = 8'h5a;
  logic [13:0] q1, q2;

  issue2150_sub u1 (
    .en_i(issue2150_pkg::Off), .st_i(issue2150_pkg::Busy), .k_i(K), .q(q1)
  );
  issue2150_sub u2 (
    .en_i(issue2150_pkg::On), .st_i(issue2150_pkg::Idle),
    .k_i(8'hc3), .q(q2)
  );

  initial begin
    #1;
    if (q1 !== 14'b1010_10_01011010 || q2 !== 14'b0101_00_11000011)
      $fatal(1, "explicit named package port values mismatch: q1=%b q2=%b", q1, q2);
    $display("PASSED");
    $finish;
  end
endmodule
