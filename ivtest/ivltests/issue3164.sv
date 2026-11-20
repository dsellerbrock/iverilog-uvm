// IEEE 1800-2017/2023 25.7 and 10.3.2: a continuous RHS can call a
// function on the physical interface bound to its modport port.
typedef struct { int value; } issue3164_sample_t;

interface issue3164_bus;
  int n = 0;
  int helper_state = 0;
  int helper_default = 0;
  int calls = 0;
  int read_calls = 0;

  function int f(input int x);
    calls++;
    return x + n;
  endfunction

  function int read_helper_state(input int offset);
    return helper_state + offset;
  endfunction

  function int read_n();
    read_calls++;
    return n;
  endfunction

  function int with_default(input int x, input int offset = 100);
    return x + offset;
  endfunction

  function int startup();
    $display("startup");
    return 30;
  endfunction

  function issue3164_sample_t sample();
    issue3164_sample_t result;
    result.value = n;
    return result;
  endfunction

  modport h(ref n, import f, read_n, startup, sample,
            import function int read_helper_state(input int offset = helper_default),
            import function int with_default(input int x, input int offset = n));
endinterface

module issue3164_cpu(issue3164_bus.h b, input int x, input int bias, output int y);
  function int helper();
    return b.read_helper_state();
  endfunction

  assign y = b.f(x) + bias + helper();
endmodule

module issue3164_array_leaf(issue3164_bus.h b[4:3], output wire [31:0] delayed_y);
  assign #2 delayed_y = b[4].read_n();
endmodule

module issue3164_array_forward(issue3164_bus.h b[4:3], output wire [31:0] delayed_y);
  issue3164_array_leaf leaf(b, delayed_y);
endmodule

module issue3164_proto(issue3164_bus.h b, output int y, output int constant_y);
  issue3164_sample_t snapshot;
  int words[2];
  assign y = b.with_default(.x(7));
  assign constant_y = b.startup();
  assign snapshot = b.sample();
  assign words = '{99, b.with_default(.x(1))};
endmodule

module issue3164;
  issue3164_bus b1(), b2(), unrelated(), array_bus[4:3]();
  int x1 = 1;
  int bias = 0;
  wire [31:0] delayed_y;
  wire signed [31:0] y1, y2, proto_y, constant_y;
  int before1, before2, before_array;
  issue3164_cpu c1(b1.h, x1, bias, y1);
  issue3164_cpu c2(b2.h, 2, 0, y2);
  issue3164_array_forward forward_port(array_bus, delayed_y);
  issue3164_proto p(b1.h, proto_y, constant_y);

  initial begin
    b1.n = 10;
    b2.n = 20;
    array_bus[3].n = 99;
    array_bus[4].n = 40;
    #1;
    if (y1 !== 11 || y2 !== 22 || proto_y !== 17 || constant_y !== 30)
      $fatal(1, "initial results %0d %0d %0d %0d", y1, y2, proto_y, constant_y);
    if (p.snapshot.value !== 10)
      $fatal(1, "initial struct result");
    if (p.words[0] !== 99 || p.words[1] !== 11)
      $fatal(1, "initial array pattern");
    $display("Y %0d %0d", x1, y1);
    $display("Y %0d %0d", 2, y2);
    if (delayed_y !== 32'bx)
      $fatal(1, "array assignment lost its delay");
    #2;
    if (delayed_y !== 40)
      $fatal(1, "wrong initial array element");

    before1 = b1.calls;
    before2 = b2.calls;
    x1 = 5;
    #1;
    if (y1 !== 15 || y2 !== 22 ||
        b1.calls != before1 + 1 || b2.calls != before2)
      $fatal(1, "argument change did not stay on the bound instance");

    before1 = b1.calls;
    b1.n = -4;
    #1;
    if (y1 !== 1 || proto_y !== 3 || y2 !== 22 ||
        p.snapshot.value !== -4 || p.words[1] !== -3 ||
        b1.calls != before1 + 1 || b2.calls != before2)
      $fatal(1, "bound body or prototype default change was missed");

    before1 = b1.calls;
    bias = 9;
    #1;
    if (y1 !== 10 || b1.calls != before1 + 1 || b2.calls != before2)
      $fatal(1, "separate RHS operand change did not reevaluate the whole RHS");

    before1 = b1.calls;
    b1.helper_state = 3;
    #1;
    if (y1 !== 13 || b1.calls != before1 + 1 || b2.calls != before2)
      $fatal(1, "helper sensitivity did not stay on the bound instance");

    before1 = b1.calls;
    b1.helper_default = 2;
    #1;
    if (y1 !== 15 || b1.calls != before1 + 1 || b2.calls != before2)
      $fatal(1, "helper default sensitivity was missed");

    before1 = b1.calls;
    unrelated.n = 900;
    unrelated.helper_state = 901;
    unrelated.helper_default = 902;
    #1;
    if (b1.calls != before1 || b2.calls != before2)
      $fatal(1, "unconnected interface triggered a function call");

    before_array = array_bus[4].read_calls;
    array_bus[3].n = 100;
    #1;
    if (array_bus[4].read_calls != before_array)
      $fatal(1, "unselected array word triggered a function call");

    array_bus[4].n = 41;
    #1;
    if (delayed_y !== 40)
      $fatal(1, "forwarded assignment updated too soon");
    #2;
    if (delayed_y !== 41)
      $fatal(1, "forwarded assignment missed the selected element");
    $display("PASSED");
  end
endmodule
