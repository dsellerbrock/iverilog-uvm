// IEEE 1800-2017 21.2.1.3: %p on a container of a signed integral element
// must render negative values in signed decimal. Dynamic-array and queue
// elements are stored as unsigned vec4 words at run time, so previously a
// signed element printed as a large unsigned number (-1 -> 4294967295).
// The declared element signedness is now carried on the .var/darray /
// .var/queue declaration and used by the element value read.
module sv_display_p_signed;
  int    sq[$];      // signed queue
  int    sd[];       // signed dynamic array
  byte   bq[$];      // signed byte queue
  int    saa[int];   // signed values
  bit [7:0] uq[$];   // unsigned queue (must stay unsigned)
  int    errors = 0;

  task automatic chk(string what, string got, string exp);
    if (got != exp) begin $display("FAIL %0s: got %0s exp %0s", what, got, exp); errors++; end
  endtask

  initial begin
    sq.push_back(-1); sq.push_back(-5); sq.push_back(7);
    sd = new[2]; sd[0] = -3; sd[1] = 7;
    bq.push_back(-1); bq.push_back(-128);
    saa[1] = -5; saa[2] = 9;
    uq.push_back(200); uq.push_back(8'hFF);

    chk("signed queue",   $sformatf("%p", sq),  "'{-1, -5, 7}");
    chk("signed darray",  $sformatf("%p", sd),  "'{-3, 7}");
    chk("signed byteq",   $sformatf("%p", bq),  "'{-1, -128}");
    chk("signed assoc",   $sformatf("%p", saa), "'{1:-5, 2:9}");
    chk("unsigned queue", $sformatf("%p", uq),  "'{200, 255}");

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
