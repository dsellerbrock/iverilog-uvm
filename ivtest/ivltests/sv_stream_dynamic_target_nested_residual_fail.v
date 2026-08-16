// Whole dynamic class-property streaming targets use the property receiver,
// not the root handle signal, and preserve nested receiver identity.
module test;
  class holder;
    byte data[];
  endclass
  holder h;
  byte tag;
  initial begin
    h = new;
    {>>{tag, h.data}} = 24'h01_02_03;
    if (tag == 8'h01 && h.data.size() == 2
        && h.data[0] == 8'h02 && h.data[1] == 8'h03)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
