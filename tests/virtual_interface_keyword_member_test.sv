// Regression: a virtual-interface class member declared with the explicit
// `interface` keyword: `virtual interface <type> <name>;`.
//
// IEEE 1800 allows `virtual interface_identifier` with or without the
// `interface` keyword. iverilog only parsed the bare form (`virtual <type> v`)
// and rejected the keyword form as "Invalid class item". UVM testbenches use
// both, e.g. OpenTitan spi_host's
// `virtual interface spi_host_fsm_if force_spi_fsm_vif;`.
interface foo_if;
  logic [7:0] data;
endinterface

module top;
  class c;
    virtual interface foo_if vi_kw;   // explicit `interface` keyword form
    virtual foo_if            vi_bare; // bare form (already supported)
    function void connect(virtual foo_if v); vi_bare = v; vi_kw = v; endfunction
  endclass

  foo_if u_if();
  initial begin
    c o = new();
    u_if.data = 8'hA5;
    o.connect(u_if);
    if (o.vi_kw.data == 8'hA5 && o.vi_bare.data == 8'hA5) $display("PASS");
    else $display("FAIL kw=%h bare=%h", o.vi_kw.data, o.vi_bare.data);
  end
endmodule
