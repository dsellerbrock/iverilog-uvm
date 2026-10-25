typedef enum logic [1:0] { E0 = 2'b00, E1 = 2'b01, E2 = 2'b10 } e_t;
module top;
  logic [3:0] narrow;
  int unsigned value;
  e_t e;
  initial begin
    e = E2;
    value = e;
    narrow = 8'hf3;
    e = e_t'(2);
    if (value != 2 || narrow != 4'h3 || e != E2)
      $fatal(1, "FAIL value=%0d narrow=%0h enum=%0d", value, narrow, e);
    $display("PASS value=%0d narrow=%0h enum=%0d", value, narrow, e);
  end
endmodule
