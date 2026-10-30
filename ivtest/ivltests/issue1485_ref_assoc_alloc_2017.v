module top;
  int values[string];
  int defaults[string] = '{default:17};

  task automatic touch(ref int slot);
  endtask

  task automatic write_slot(ref int slot);
    slot = 23;
  endtask

  initial begin
    touch(values["missing"]);
    $display("empty exists=%0d entries=%0d value=%0d",
             values.exists("missing"), values.num(), values["missing"]);

    touch(defaults["configured"]);
    $display("default exists=%0d entries=%0d value=%0d",
             defaults.exists("configured"), defaults.num(),
             defaults["configured"]);

    write_slot(values["written"]);
    $display("write exists=%0d entries=%0d value=%0d",
             values.exists("written"), values.num(), values["written"]);
  end
endmodule
