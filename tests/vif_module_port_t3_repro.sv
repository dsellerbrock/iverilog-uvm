// T3 repro: interface connected to a module port can't be passed as
// `virtual` to a static class function — the param reads as null.
//
// Symptom: 8 sv-tests testbenches FAIL with `%wait/vif/posedge: object is
// not a virtual interface (nil=1, ...)` because uvm_resource_db#(virtual T)::set
// stores null instead of the actual interface handle.  When read back in
// connect_phase, vif is null; @(posedge vif.clk) then asserts.
//
// Discriminator: the bug requires BOTH (a) the iface connected to a module
// port (e.g. `dut d(.mif(mif));`), AND (b) the same iface passed as
// `virtual T` to a static or class function.  Without the DUT connection,
// the call works.
//
// Likely fix area: iverilog elaboration of virtual-interface variables
// when the interface is also connected to a module port.  Not in vvp
// runtime — separate from T1/T2/T2b.

interface my_if(input clk);
    logic [7:0] data;
endinterface

module dut(my_if mif);
endmodule

class container#(type T = int);
    static function void set(T val);
        $display("[set] val_null?%0d %s", val == null,
                 val == null ? "FAIL" : "PASS");
    endfunction
endclass

module top;
    bit clk = 0;
    my_if mif(.clk(clk));
    dut d(.mif(mif));
    initial begin
        container#(virtual my_if)::set(mif);
        $finish;
    end
endmodule
