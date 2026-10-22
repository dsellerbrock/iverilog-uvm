// IEEE 1800-2017/2023 18.8: a whole-struct setter disables every rand member.
typedef struct {
  rand bit first;
  rand bit second;
} rand_mode_record;

class rand_mode_struct_item;
  rand rand_mode_record record;
endclass

module test;
  initial begin
    rand_mode_struct_item item = new;
    item.record.rand_mode(0);
    if (item.record.first.rand_mode() !== 0
        || item.record.second.rand_mode() !== 0)
      $fatal(1, "rand_mode(0) did not disable every rand struct member");
    $display("PASS rand_mode unpacked-struct selection");
  end
endmodule
