module issue3295_signed_zero;
  class C;
    real z;
  endclass
  real m;
  C c = new;
  reg [63:0] bits;

  task check(input [63:0] expected);
    if ($realtobits(m) !== expected || $realtobits(c.z) !== expected) begin
      $display("FAIL: expected %h module %h class %h", expected,
               $realtobits(m), $realtobits(c.z));
      $finish;
    end
  endtask

  initial begin
    m = $bitstoreal(64'h8000000000000000);
    c.z = $bitstoreal(64'h8000000000000000);
    check(64'h8000000000000000);
    bits = 64'h3ff8000000000000;
    m = $bitstoreal(bits);
    c.z = $bitstoreal(bits);
    check(bits);
    bits = 64'h8000000000000000;
    m = $bitstoreal(bits);
    c.z = $bitstoreal(bits);
    check(bits);
    bits = 64'h0000000000000000;
    m = $bitstoreal(bits);
    c.z = $bitstoreal(bits);
    check(bits);
    $display("PASS");
  end
endmodule
