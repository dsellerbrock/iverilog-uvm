interface issue3731_bus;
  logic [31:0] data [0:3];
  bit [7:0] flags [5:2];
  logic [99:0] wide [-2:0];
  string label [1:0];
endinterface

class issue3731_driver;
  virtual issue3731_bus vif;

  task print_words(int slot);
    logic [31:0] copy;
    copy = vif.data[slot];
    $display("data %h %h", copy, vif.data[slot]);
    $display("flags %h %h", vif.flags[5], vif.flags[slot]);
    $display("wide %h %h", vif.wide[slot-3], vif.wide[slot-3][71:64]);
    $display("label <%s>", vif.label[slot-1]);
  endtask

  task print_invalid(logic [63:0] slot);
    $display("invalid %h %h <%s>", vif.data[slot], vif.flags[slot],
             vif.label[slot]);
  endtask
endclass

module issue3731;
  issue3731_bus first_bus();
  issue3731_bus second_bus();
  issue3731_driver driver;

  initial begin
    first_bus.data[2] = 32'h00000f0f;
    first_bus.flags[5] = 8'h09;
    first_bus.flags[2] = 8'h07;
    first_bus.wide[-1] = 100'h123456789abcdef01234567xz;
    first_bus.label[1] = "first";

    second_bus.data[2] = 32'h12345678;
    second_bus.flags[5] = 8'h19;
    second_bus.flags[2] = 8'h17;
    second_bus.wide[-1] = 100'hfedcba9876543210123456789;
    second_bus.label[1] = "second";

    driver = new;
    driver.vif = first_bus;
    driver.print_words(2);
    driver.vif = second_bus;
    driver.print_words(2);
    driver.print_invalid(64'h100000002);
    driver.print_invalid('x);
  end
endmodule
