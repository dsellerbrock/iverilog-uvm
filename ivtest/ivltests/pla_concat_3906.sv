module pla_concat_3906;
  logic [1:3] mem[1:3];
  logic a, b, c;
  logic s1, s2, s3, t1, t2, t3;
  logic [1:3] async_in;
  logic [1:6] watched;

  logic [1:4] mixed_mem[1:4];
  logic [1:4] mixed_in, wide, tail;
  bit [1:3] two_state;

  task automatic watch(input integer base);
    $async$and$array(mem, async_in, {watched[base +: 2], watched[base+2]});
  endtask

  initial begin
    mem[1] = 3'b100;
    mem[2] = 3'b010;
    mem[3] = 3'b001;
    {a, b, c} = 3'b101;
    $sync$and$array(mem, {a, b, c}, {s1, s2, s3});
    if ({s1, s2, s3} !== 3'b101)
      $fatal(1, "sync output %b", {s1, s2, s3});

    async_in = 3'b101;
    $async$and$array(mem, async_in, {t1, t2, t3});
    watch(1);
    watch(4);
    if ({t1, t2, t3} !== 3'b101 || watched !== 6'b101101)
      $fatal(1, "initial async outputs %b and %b", {t1, t2, t3}, watched);
    async_in = 3'b011;
    #0;
    if ({t1, t2, t3} !== 3'b011 || watched !== 6'b011011)
      $fatal(1, "updated async outputs %b and %b", {t1, t2, t3}, watched);
    mem[1] = 3'b010;
    #0;
    if ({t1, t2, t3} !== 3'b111 || watched !== 6'b111111)
      $fatal(1, "after personality change %b and %b", {t1, t2, t3}, watched);

    mixed_mem[1] = 4'b1000;
    mixed_mem[2] = 4'b0100;
    mixed_mem[3] = 4'b0010;
    mixed_mem[4] = 4'b0001;
    mixed_in = 4'b1xx0;
    wide = 4'b0011;
    two_state = 3'b111;
    tail = 4'b1111;
    $sync$and$array(mixed_mem, mixed_in, {wide[2:3], {two_state[2], tail[3]}});
    if (wide !== 4'b01x1 || two_state !== 3'b101 || tail !== 4'b1101)
      $fatal(1, "mixed output slices %b %b %b", wide, two_state, tail);
    $display("PASSED");
  end
endmodule
