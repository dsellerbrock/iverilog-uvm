// IEEE 1800-2017/2023 11.2.1: $sformatf with constant arguments is a
// constant system function. Each folded parameter must equal the string the
// same call produces at run time.
module issue1228_constant_sformatf;
  localparam int N = 25;
  localparam int NEG = -7;
  localparam logic [11:0] H = 12'h0a5;
  localparam byte B = 8'sd5;
  localparam string NAME = "core";
  localparam real R = 2.5;

  localparam string P0 = $sformatf("v=%0d", 25);
  localparam string P1 = $sformatf("%d|%0d|%5d|%-5d|%05d|%+d", N, N, N, N, N, N);
  localparam string P2 = $sformatf("%d|%0d|%6d|%06d", NEG, NEG, NEG, NEG);
  localparam string P3 = $sformatf("%h|%0h|%x|%6h|%-6h|%06h", H, H, H, H, H, H);
  localparam string P4 = $sformatf("%o|%0o|%b|%0b|%4b", H, H, B, B, B);
  localparam string P5 = $sformatf("%s_%0d|%8s|%-8s|", NAME, B, NAME, NAME);
  localparam string P6 = $sformatf("%c%c|%3c|%-3c|", 8'h48, 8'h69, 8'h41, 8'h42);
  localparam string P7 = $sformatf("%f|%0.2f|%e|%g|%8.3f", R, R, R, R, R);
  localparam string P8 = $sformatf("100%%|%m|%d", B);

  int n = 25, neg = -7;
  logic [11:0] h = 12'h0a5;
  byte b = 8'sd5;
  string name = "core";
  real r = 2.5;
  int dec = 25;
  bit failed = 0;

  task check(string got, string want, string what);
    if (got != want) begin
      $display("FAILED %s: constant \"%s\" runtime \"%s\"", what, got, want);
      failed = 1;
    end
  endtask

  initial begin
    check(P0, $sformatf("v=%0d", dec), "P0");
    check(P1, $sformatf("%d|%0d|%5d|%-5d|%05d|%+d", n, n, n, n, n, n), "P1");
    check(P2, $sformatf("%d|%0d|%6d|%06d", neg, neg, neg, neg), "P2");
    check(P3, $sformatf("%h|%0h|%x|%6h|%-6h|%06h", h, h, h, h, h, h), "P3");
    check(P4, $sformatf("%o|%0o|%b|%0b|%4b", h, h, b, b, b), "P4");
    check(P5, $sformatf("%s_%0d|%8s|%-8s|", name, b, name, name), "P5");
    check(P6, $sformatf("%c%c|%3c|%-3c|", 8'h48, 8'h69, 8'h41, 8'h42), "P6");
    check(P7, $sformatf("%f|%0.2f|%e|%g|%8.3f", r, r, r, r, r), "P7");
    check(P8, $sformatf("100%%|%m|%d", b), "P8");
    if (P0 != "v=25") begin $display("FAILED: P0=%s", P0); failed = 1; end
    if (!failed) $display("PASSED");
  end
endmodule
