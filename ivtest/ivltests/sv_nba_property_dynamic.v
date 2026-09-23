// A dynamic packed-property bit-select captures its index and RHS before
// the NBA update; a later index change cannot retarget the write.
class nba_dynamic_holder;
  logic [7:0] value;
endclass

module sv_nba_property_dynamic;
  nba_dynamic_holder obj;
  int idx;
  initial begin
    obj = new;
    obj.value = 8'h00;
    idx = 3;
    obj.value[idx] <= 1'b1;
    idx = 0;
    #0;
    if (obj.value !== 8'h00) $fatal(1, "property updated before NBA");
    #1;
    if (obj.value !== 8'h08) $fatal(1, "wrong selected bit: %h", obj.value);
    $display("PASSED");
  end
endmodule
