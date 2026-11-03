class StringConstraint;
  string label = "ready";
  rand bit enabled;
  constraint legal_string_comparison { label == "ready"; }
endclass

module top;
  StringConstraint item;
  initial begin
    item = new;
    if (item.randomize()) $fatal(1, "2017 accepted a string constraint");
    $display("PASS");
  end
endmodule
