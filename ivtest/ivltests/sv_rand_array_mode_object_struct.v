class mode_leaf;
  rand bit [7:0] value;
  constraint fixed_value { value == 8'ha5; }
endclass

typedef struct {
  rand bit [31:0] word;
} mode_record_t;

class aggregate_mode_item;
  rand mode_leaf handles[2];
  rand mode_record_t records[2];

  function new;
    foreach (handles[i]) handles[i] = new;
  endfunction
endclass

module test;
  initial begin
    aggregate_mode_item item;
    bit [7:0] frozen_handle;
    bit [31:0] frozen_record;
    bit [31:0] before_record;
    bit enabled_record_changed;

    item = new;
    item.srandom(32'h1020_3040);
    item.handles[0].value = 8'h11;
    item.handles[1].value = 8'h22;
    item.records[0].word = 32'h1111_2222;
    item.records[1].word = 32'h3333_4444;

    item.handles[0].rand_mode(0);
    item.records[0].rand_mode(0);
    frozen_handle = item.handles[0].value;
    frozen_record = item.records[0].word;

    repeat (4) begin
      before_record = item.records[1].word;
      if (item.randomize() !== 1)
        $fatal(1, "aggregate fixed-array randomize failed");
      if (item.handles[0].value !== frozen_handle)
        $fatal(1, "disabled class-handle leaf was randomized");
      if (item.records[0].word !== frozen_record)
        $fatal(1, "disabled unpacked-struct leaf was randomized");
      if (item.handles[1].value !== 8'ha5)
        $fatal(1, "enabled class-handle leaf was not randomized");
      if (item.records[1].word !== before_record)
        enabled_record_changed = 1'b1;
    end
    if (!enabled_record_changed)
      $fatal(1, "enabled unpacked-struct leaf never changed");

    $display("PASSED");
  end
endmodule
