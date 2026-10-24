typedef struct {
  rand bit first;
  rand bit second;
} rand_mode_record_t;

class rand_mode_struct_item;
  rand rand_mode_record_t record;

  constraint both_one {
    record.first == 1'b1;
    record.second == 1'b1;
  }
endclass

module test;
  initial begin
    rand_mode_struct_item item;
    item = new;
    item.record.first = 1'b0;
    item.record.second = 1'b0;

    item.record.rand_mode(0);
    if (item.record.first.rand_mode() !== 0
        || item.record.second.rand_mode() !== 0)
      $fatal(1, "whole-struct rand_mode(0) did not disable every member");
    if (item.randomize() !== 0
        || item.record.first !== 1'b0 || item.record.second !== 1'b0)
      $fatal(1, "disabled struct members were randomized");

    item.record.rand_mode(1);
    if (item.record.first.rand_mode() !== 1
        || item.record.second.rand_mode() !== 1)
      $fatal(1, "whole-struct rand_mode(1) did not enable every member");
    if (item.randomize() !== 1
        || item.record.first !== 1'b1 || item.record.second !== 1'b1)
      $fatal(1, "enabled struct members were not randomized");

    $display("PASS whole-struct-rand-mode");
  end
endmodule
