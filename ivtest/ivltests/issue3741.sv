// IEEE 1800-2017/2023 4.9.1 and 10.3: continuous assignment function reads.
interface issue3741_bus;
  int value = 3;
  extern function int get();
  modport exporter(ref value, export get);
endinterface

module issue3741_provider(issue3741_bus.exporter port);
  function int port.get(); return port.value; endfunction
endmodule

module issue3741;
  int a = 1, h = 0, c = 0;
  int y, z, n;
  function automatic int f(int x); return x + h; endfunction
  function automatic int g(); return a + h; endfunction
  function automatic int nested(); return g() * 2; endfunction
  assign y = f(a);
  assign z = g();
  assign n = f(a) + c;
  wire signed [31:0] twice = nested();

  issue3741_bus bus();
  issue3741_provider provider(bus.exporter);
  function automatic int read_extern(); return bus.get(); endfunction
  wire signed [31:0] extern_value = read_extern();

  real offset = 0.25;
  function automatic real read_real(); return offset + 1.0; endfunction
  wire real real_value = read_real();

  logic uninitialized;
  function automatic bit is_unknown(); return uninitialized === 1'bx; endfunction
  wire known = is_unknown();

  logic [1:0] source_bits = 0;
  int calls = 0;
  function automatic logic [1:0] read_selected();
    calls = calls + 1;
    return source_bits[2:1];
  endfunction
  wire [1:0] selected = read_selected();

  int count = 0;
  function automatic int increment(); return ++count; endfunction
  wire signed [31:0] counted = increment();

  logic enable = 0, hidden = 0;
  int gated_calls = 0;
  function automatic logic read_gated();
    gated_calls++;
    return hidden;
  endfunction
  wire gated = enable && read_gated();

  logic data = 0;
  function automatic logic read_data(); return data; endfunction
  wire delayed;
  assign #2 delayed = read_data();

  task automatic check_values(int ey, int ez, int en);
    if (y !== ey || z !== ez || n !== en || twice !== ez * 2)
      $fatal(1, "y/z/n/nested = %0d/%0d/%0d/%0d, expected %0d/%0d/%0d/%0d",
             y, z, n, twice, ey, ez, en, ez * 2);
  endtask

  initial begin
    #0;
    if (known !== 1)
      $fatal(1, "dependency stayed X but the assignment must run at startup");
    #1;
    check_values(1, 1, 1);
    if (extern_value !== 3 || real_value != 1.25 || selected !== 2'bx0 || calls != 1 ||
        counted !== 1 || count != 1 || gated !== 0 || gated_calls != 0 ||
        delayed !== 1'bx)
      $fatal(1, "incorrect initial value or evaluation count");

    h = 10;
    bus.value = 47;
    offset = 2.5;
    source_bits[0] = 1;
    hidden = 1;
    uninitialized = 0;
    #1;
    check_values(11, 11, 11);
    if (extern_value !== 47 || real_value != 3.5 || known !== 0 ||
        selected !== 2'bx0 || calls != 1 ||
        gated !== 0 || gated_calls != 0)
      $fatal(1, "incorrect body-read sensitivity or short-circuit evaluation");

    a = 2;
    source_bits[1] = 1;
    enable = 1;
    #1;
    check_values(12, 12, 12);
    if (selected !== 2'bx1 || calls != 2 || gated !== 1 || gated_calls != 1 ||
        delayed !== 0)
      $fatal(1, "selected bit, enabled function, or initial delayed drive failed");

    c = 5;
    hidden = 0;
    data = 1;
    calls = 100;  // Reads that are also writes do not add sensitivity.
    count = 100;
    #1;
    check_values(12, 12, 17);
    if (gated !== 0 || gated_calls != 2 || delayed !== 0 || calls != 100 ||
        counted !== 1 || count != 100)
      $fatal(1, "incorrect reevaluation or early delayed update");
    #2;
    if (delayed !== 1)
      $fatal(1, "function body change did not propagate through the delay");
    $display("PASSED");
  end
endmodule
