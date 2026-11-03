class StringConstraint;
  string label = "ready";
  rand bit enabled;
  constraint legal_string_comparison { label == "ready"; }
endclass

module top;
  StringConstraint item;
  initial begin
    item = new;
    if (!item.randomize()) $fatal(1, "matching string constraint failed");
    item.label = "busy";
    if (item.randomize()) $fatal(1, "mismatching string constraint passed");
    $display("PASS");
  end
endmodule
