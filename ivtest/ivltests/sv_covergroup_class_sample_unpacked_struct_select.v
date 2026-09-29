// Class-embedded covergroup sample formals retain descending unpacked arrays.
package class_sample_flags_pkg;
  typedef struct packed { logic Z, L, M, C; } flags_t;
  class sample_item;
    flags_t flags[1:0];
    covergroup cg with function sample(bit fg, flags_t flags[1:0]);
      option.per_instance = 1;
      cp: coverpoint {fg, flags[fg].C} {
        bins first = {2'b00};
        bins second = {2'b11};
      }
    endgroup
    function new;
      cg = new;
    endfunction
  endclass
endpackage

module top;
  import class_sample_flags_pkg::*;
  sample_item item;
  initial begin
    item = new;
    item.flags[0] = 4'b1010;
    item.flags[1] = 4'b0101;
    item.cg.sample(0, item.flags);
    if (item.cg.get_inst_coverage() != 50.0)
      $fatal(1, "first class sample missed selected flag");

    item.flags[0] = 4'b1111;
    item.flags[1] = 4'b0100;
    item.cg.sample(1, item.flags);
    if (item.cg.get_inst_coverage() != 50.0)
      $fatal(1, "changed source array altered earlier class sample");

    item.flags[1] = 4'b0101;
    item.cg.sample(1, item.flags);
    if (item.cg.get_inst_coverage() != 100.0)
      $fatal(1, "second class sample missed selected flag");
    $display("PASSED");
  end
endmodule
