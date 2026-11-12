// Issue #1274: a port's vpiHighConn is the actual connected in the
// instantiation and its vpiLowConn the module's own port signal (IEEE
// 1800-2023 37.14 details 3 and 4). An unconnected port has a NULL
// vpiHighConn (detail 10).
module child(input logic a, output logic [3:0] y, input logic [7:0] w,
             input logic [3:0] z);
  assign y = {3'b000, a};
endmodule

module top;
  logic a;
  logic [3:0] y;
  logic [7:0] b;
  child u(.a(a), .y(y), .w(b + 8'd1), .z());
  child arr[1:0](.a(a), .y(), .w(b), .z());
  initial begin
    a = 1;
    b = 8'd5;
    #1 $pprobe;
  end
endmodule
