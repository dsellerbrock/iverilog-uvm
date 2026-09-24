typedef int unsigned uint;

class coupled_301_item;
  rand bit [9:0] value;
  rand bit [9:0] auxiliary;
  constraint distribution_c { value dist {[0:300] :/ 1}; }
  constraint coupled_c { auxiliary == value + 1; }
endclass

class isolated_span_257_item;
  rand bit [8:0] size;
  constraint c { size dist {[0:256] :/ 1}; }
endclass

class first_endpoint_item;
  rand bit [8:0] size;
  constraint c { size dist {[0:256] :/ 1}; size == 0; }
endclass

class last_endpoint_item;
  rand bit [8:0] size;
  constraint c { size dist {[0:256] :/ 1}; size == 256; }
endclass

class coupled_span_256_item;
  rand bit [31:0] start_addr, end_addr;
  rand uint size;
  constraint c {
    solve start_addr, size before end_addr;
    start_addr == 32'h1000;
    end_addr == start_addr + size;
    end_addr <= 32'h10ff;
    size dist {[0:255] :/ 1};
  }
endclass

class coupled_span_3001_item;
  rand bit [31:0] start_addr, end_addr;
  rand uint size;
  constraint c {
    solve start_addr, size before end_addr;
    start_addr == 32'h1000;
    end_addr == start_addr + size;
    end_addr <= 32'h1fff;
    size dist {[0:3000] :/ 6};
  }
endclass

class impossible_large_item;
  rand bit [31:0] start_addr, end_addr;
  rand uint size;
  constraint c {
    start_addr == 0;
    end_addr == 1;
    size == 17;
    end_addr == start_addr + size;
    size dist {[0:3000] :/ 1};
  }
endclass

module test;
  coupled_301_item small_coupled;
  isolated_span_257_item over_cap;
  first_endpoint_item first_value;
  last_endpoint_item last_value;
  coupled_span_256_item coupled_256;
  coupled_span_3001_item coupled_3001;
  impossible_large_item unsat;

  initial begin
    small_coupled = new;
    over_cap = new;
    first_value = new;
    last_value = new;
    coupled_256 = new;
    coupled_3001 = new;
    unsat = new;

    repeat (2) begin
      if (!small_coupled.randomize()
          || small_coupled.value > 300
          || small_coupled.auxiliary != small_coupled.value + 1)
        $fatal(1, "coupled span-301 dist failed");
      if (!over_cap.randomize() || over_cap.size > 256)
        $fatal(1, "isolated span-257 control failed");
      if (!first_value.randomize() || first_value.size != 0)
        $fatal(1, "first source-range endpoint failed");
      if (!last_value.randomize() || last_value.size != 256)
        $fatal(1, "last source-range endpoint failed");
      if (!coupled_256.randomize()
          || coupled_256.size > 255
          || coupled_256.end_addr
               != coupled_256.start_addr + coupled_256.size)
        $fatal(1, "coupled span-256 control failed");
      if (!coupled_3001.randomize()
          || coupled_3001.size > 3000
          || coupled_3001.end_addr
               != coupled_3001.start_addr + coupled_3001.size
          || coupled_3001.end_addr > 32'h1fff)
        $fatal(1, "coupled span-3001 dist failed");
    end

    unsat.start_addr = 0;
    unsat.end_addr = 1;
    unsat.size = 17;
    if (unsat.randomize()) $fatal(1, "impossible large dist succeeded");
    if (unsat.start_addr != 0 || unsat.end_addr != 1 || unsat.size != 17)
      $fatal(1, "failed randomize did not roll back prior values");

    $display("PASSED");
  end
endmodule
