module issue3510_clockvar_scope;
  bit clk = 0;
  bit a = 1, backing = 0;
  typedef struct packed { logic [3:0] flags; } payload_t;
  payload_t selected = '0, vec = 4'b0100;
  bit [2:0] words_source[2], expected_words[2];
  int outside_pass, actual_pass, mapped_pass, forward_pass;
  int local_pass, disable_pass, const_pass;
  always #5 clk = !clk;
  always @(posedge clk) vec.flags[2] <= 1'b0;
  always @(negedge clk) vec.flags[2] <= 1'b1;
  always @(posedge clk) words_source[1] <= 0;
  always @(negedge clk) words_source[1] <= 1;

  // At each rising edge the raw signal is 1, but its #2 clockvar is 0.
  initial begin
    words_source[1] = 1;
    expected_words[1] = 1;
    #4 backing = 1;
    #2 backing = 0;
    #8 backing = 1;
  end

  property outside_prop;
    @(posedge clk) a;
  endproperty
  property late_input;
    @(negedge clk) 1'b0;
  endproperty

  clocking cb @(posedge clk);
    default input #2;
    input a = backing;
    input #1step selected = vec;
    input #1step words = words_source;
    input #1step expected_words;

    property outside_read;
      outside_prop;
    endproperty
    property use_actual(untyped a);
      a;
    endproperty
    property mapped_read;
      selected.flags[2] && words == expected_words;
    endproperty
    property forward_read;
      late_input;
    endproperty
    input #1step late_input = a;
    property local_read;
      int a = 1;
      a == 1;
    endproperty
    property current_disable;
      disable iff (a) 1'b1;
    endproperty
    property current_const;
      !const'(a);
    endproperty
  endclocking

  assert property (cb.outside_read)
    outside_pass++; else $fatal(1, "outside property read the clockvar");
  assert property (cb.use_actual(a))
    actual_pass++; else $fatal(1, "outside actual read the clockvar");
  assert property (cb.mapped_read)
    mapped_pass++; else $fatal(1, "mapped #1step clockvar sample");
  assert property (cb.forward_read)
    forward_pass++; else $fatal(1, "forward clockvar name resolved to the outside property");
  assert property (cb.local_read)
    local_pass++; else $fatal(1, "local name read the clockvar");
  assert property (cb.current_disable)
    disable_pass++; else $fatal(1, "disabled property failed");
  assert property (cb.current_const)
    const_pass++; else $fatal(1, "const cast did not read the current clockvar");

  initial begin
    #20;
    if (outside_pass != 2 || actual_pass != 2 || mapped_pass != 2 || forward_pass != 2
        || local_pass != 2 || disable_pass != 2 || const_pass != 2)
      $fatal(1, "pass counts: %0d %0d %0d %0d %0d %0d %0d",
             outside_pass, actual_pass, mapped_pass, forward_pass, local_pass,
             disable_pass, const_pass);
    $display("PASSED");
    $finish(0);
  end
endmodule
