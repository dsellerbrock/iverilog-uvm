// IEEE 1800-2017/2023 12.7.3: prefix selection is not a loop declaration.
package lookup_pkg;
  typedef struct { bit [31:0] start_addr, end_addr; } range_t;
  typedef struct { string device_name; range_t addr_ranges[$]; } device_t;
  device_t devices[$] = '{
    '{"debug", '{'{32'h0, 32'h1ff}}},
    '{"control", '{'{32'h2300, 32'h231f}}}
  };
  function automatic bit valid_addr(string device_name, bit [31:0] addr);
    foreach (devices[i]) begin
      if (devices[i].device_name == device_name) begin
        foreach (devices[i].addr_ranges[j]) begin
          if (addr inside {[devices[i].addr_ranges[j].start_addr :
                            devices[i].addr_ranges[j].end_addr]}) return 1;
        end
      end
    end
    return 0;
  endfunction
endpackage
module main;
 import lookup_pkg::*;
 localparam int PICK = 1;
 int count = 0;
 initial begin
  if (valid_addr("debug",32'h2309) || !valid_addr("control",32'h2309) || !valid_addr("debug",32'hdc)) $fatal(1,"bad address map");
  foreach (devices[PICK].addr_ranges[j]) begin
   count++;
   if (devices[PICK].addr_ranges[j].start_addr != 32'h2300) $fatal(1,"constant selector changed");
  end
  if (count != 1) $fatal(1,"constant selector iterated outer devices");
  $display("PASSED");
 end
endmodule
