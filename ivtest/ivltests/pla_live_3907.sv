module pla_live_3907;
  logic [1:3] mem [1:3];
  logic a, b, c;
  logic [1:3] result, selected;

  logic masked, enable, tail;
  logic [1:2] choices [1:2];
  int word_index, bit_index;
  int samples = 0;

  logic [1:2] feedback_mem [1:2], feedback;
  logic step;
  logic shared;
  logic [1:2] bound_out [1:2];

  logic [1:2] scoped_mem [1:2], from_a, from_b;
  logic scoped_terms [1:2];
  int scoped_index;

  function automatic logic read_term(input logic value);
    samples++;
    return value;
  endfunction

  task automatic bind_pla(input int slot, input logic saved);
    logic [1:2] personality [1:2];
    personality[1] = 2'b10;
    personality[2] = 2'b01;
    begin : watch
      logic input_term;
      input_term = saved;
      $async$and$array(personality, {input_term, shared}, bound_out[slot]);
    end
    #0;
    if (slot == 1)
      personality[2] = 2'b00;
  endtask

  task automatic watch_a;
    logic owned;
    owned = 0;
    $async$and$array(scoped_mem, {owned, scoped_terms[scoped_index]}, from_a);
    owned = 1;
  endtask

  task automatic watch_b;
    logic owned;
    owned = 1;
    $async$and$array(scoped_mem, {owned, scoped_terms[scoped_index]}, from_b);
    owned = 0;
  endtask

  initial begin
    mem[1] = 3'b100;
    mem[2] = 3'b010;
    mem[3] = 3'b001;
    {a, b, c} = 3'b101;
    $async$and$array(mem, {a, b, c}, result);
    if (result !== 3'b101)
      $fatal(1, "initial concatenated input gave %b", result);
    {a, b, c} = 3'b011;
    #0;
    if (result !== 3'b011)
      $fatal(1, "changed concatenated input gave %b", result);
    result = 3'b000;
    a = 1;
    a = 0;
    #0;
    if (result !== 3'b011)
      $fatal(1, "same-slot input pulse gave %b", result);
    result = 3'b000;
    mem[1] = 3'b010;
    mem[1] = 3'b100;
    #0;
    if (result !== 3'b011)
      $fatal(1, "same-slot personality pulse gave %b", result);

    masked = 0;
    enable = 0;
    choices[1] = 2'b10;
    choices[2] = 2'b00;
    word_index = 1;
    bit_index = 1;
    tail = 0;
    $async$and$array(mem,
        {masked & enable, read_term(choices[word_index][bit_index]), tail},
        selected);
    if (selected !== 3'b010 || samples != 1)
      $fatal(1, "initial expression gave %b with %0d samples", selected, samples);

    selected = 3'b000;
    masked = 1;
    #0;
    if (selected !== 3'b000)
      $fatal(1, "masked change overwrote the output with %b", selected);
    enable = 1;
    #0;
    if (selected !== 3'b110)
      $fatal(1, "changed expression gave %b", selected);

    mem[3] = 3'b010;
    #0;
    if (selected !== 3'b111)
      $fatal(1, "memory-only change gave %b", selected);

    word_index = 2;
    #0;
    if (selected !== 3'b100)
      $fatal(1, "word selector change gave %b", selected);
    choices[2] = 2'b10;
    #0;
    if (selected !== 3'b111)
      $fatal(1, "selected word change gave %b", selected);
    selected = 3'b000;
    choices[1] = 2'b00;
    #0;
    if (selected !== 3'b000)
      $fatal(1, "unselected word change gave %b", selected);
    bit_index = 2;
    #0;
    if (selected !== 3'b100)
      $fatal(1, "bit selector change gave %b", selected);

    tail = 1'bx;
    #0;
    selected = 3'b111;
    tail = 1'bz;
    #0;
    if (selected !== 3'b100)
      $fatal(1, "X-to-Z change gave %b", selected);

    shared = 0;
    fork
      bind_pla(1, 1'b0);
      bind_pla(2, 1'b1);
    join
    #0;
    if (bound_out[1] !== 2'b01 || bound_out[2] !== 2'b10)
      $fatal(1, "automatic personality change gave %b %b", bound_out[1], bound_out[2]);
    shared = 1;
    #0;
    if (bound_out[1] !== 2'b01 || bound_out[2] !== 2'b11)
      $fatal(1, "automatic input change gave %b %b", bound_out[1], bound_out[2]);

    scoped_mem[1] = 2'b10;
    scoped_mem[2] = 2'b01;
    scoped_index = 1;
    scoped_terms[1] = 0;
    watch_a();
    watch_b();
    #0;
    if (from_a !== 2'b10 || from_b !== 2'b00)
      $fatal(1, "local input changes reached the wrong frames: %b %b", from_a, from_b);
    scoped_terms[1] = 1;
    #0;
    if (from_a !== 2'b11 || from_b !== 2'b01)
      $fatal(1, "shared input array change gave %b %b", from_a, from_b);
    scoped_mem[1] = 2'b00;
    #0;
    if (from_a !== 2'b11 || from_b !== 2'b11)
      $fatal(1, "shared personality change gave %b %b", from_a, from_b);

    feedback_mem[1] = 2'b10;
    feedback_mem[2] = 2'b01;
    step = 0;
    feedback = 2'b00;
    $async$and$array(feedback_mem, {step, feedback[1]}, feedback);
    step = 1;
    #0;
    if (feedback !== 2'b11 || $time != 0)
      $fatal(1, "feedback did not settle in the current time slot: %b", feedback);
    $display("PASSED");
  end
endmodule
