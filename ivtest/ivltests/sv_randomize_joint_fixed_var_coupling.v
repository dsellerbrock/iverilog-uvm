// Hard-constraint-fixed variables must not couple the factors that mention
// them. A fixed 48 MHz clock that both a derived AON frequency (840 legal
// values) and a host frequency (37) reference merged those two into one
// 31,080-tuple joint component, over the enumeration limit, so
// randomize() failed although each factor is small (OpenTitan usbdev cfg).
`define CLK_DIST(F) F dist { [5:23] :/ 2, [24:25] :/ 2, [26:47] :/ 1, [48:50] :/ 2, [51:95] :/ 1, 96 :/ 1, [97:99] :/ 1, 100 :/ 1 };
class agent_cfg;
  rand bit zero_delays;
  constraint zd_c { zero_delays dist { 1'b0 := 6, 1'b1 := 4 }; }
endclass
class clk_cfg;
  rand agent_cfg agent;
  rand int unsigned clk_mhz;
  rand int unsigned clk_mhzs[string];
  constraint clk_c { `CLK_DIST(clk_mhz) foreach (clk_mhzs[i]) { `CLK_DIST(clk_mhzs[i]) } }
  function new(); agent = new; endfunction
  function void pre_randomize(); clk_mhzs["a"] = 0; clk_mhzs["b"] = 0; clk_mhzs["c"] = 0; endfunction
  rand bit zero_delays;
  rand int unsigned usb_khz;
  rand int unsigned aon_khz;
  rand int unsigned host_khz;
  constraint zero_delays_c { zero_delays dist { 1'b0 := 6, 1'b1 := 4 }; }
  constraint usb_c  { usb_khz == 48_000; }
  constraint aon_c  { aon_khz > usb_khz / 300 && aon_khz <= usb_khz / 48; }
  constraint host_c { host_khz >= usb_khz - 18 && host_khz <= usb_khz + 18; }
endclass

// The same factors when the fixed clock is a plain property.
class clk_cfg_state;
  rand bit zero_delays;
  int unsigned usb_khz = 48_000;
  rand int unsigned aon_khz;
  rand int unsigned host_khz;
  constraint zero_delays_c { zero_delays dist { 1'b0 := 6, 1'b1 := 4 }; }
  constraint aon_c  { aon_khz > usb_khz / 300 && aon_khz <= usb_khz / 48; }
  constraint host_c { host_khz >= usb_khz - 18 && host_khz <= usb_khz + 18; }
endclass

module main;
  int errors;
  initial begin
    automatic clk_cfg c = new;

    automatic int unsigned aon_min = 32'hffffffff, aon_max = 0;
    for (int i = 0; i < 25; i++) begin
      if (!c.randomize()) begin $display("FAILED randomize %0d", i); errors++; break; end
      if (!(c.clk_mhz >= 5 && c.clk_mhz <= 100)) begin $display("FAILED clk %0d", c.clk_mhz); errors++; end
      if (c.usb_khz != 48000) begin $display("FAILED usb %0d", c.usb_khz); errors++; end
      if (!(c.aon_khz > 160 && c.aon_khz <= 1000)) begin $display("FAILED aon %0d", c.aon_khz); errors++; end
      if (!(c.host_khz >= 47982 && c.host_khz <= 48018)) begin $display("FAILED host %0d", c.host_khz); errors++; end
      if (c.aon_khz < aon_min) aon_min = c.aon_khz;
      if (c.aon_khz > aon_max) aon_max = c.aon_khz;
    end
    // Spread: 25 draws over 840 legal values must not collapse to a corner.
    if (aon_max - aon_min < 250) begin $display("FAILED aon spread %0d..%0d", aon_min, aon_max); errors++; end
    begin
      automatic clk_cfg_state st = new;
      for (int i = 0; i < 25; i++) begin
        if (!st.randomize()) begin $display("FAILED state randomize %0d", i); errors++; break; end
        if (!(st.aon_khz > 160 && st.aon_khz <= 1000)) begin $display("FAILED state aon %0d", st.aon_khz); errors++; end
        if (!(st.host_khz >= 47982 && st.host_khz <= 48018)) begin $display("FAILED state host %0d", st.host_khz); errors++; end
      end
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
