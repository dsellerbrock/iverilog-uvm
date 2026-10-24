module sv_covergroup_parameterized_class;
  class B #(parameter int W = 4, type T = int);
    bit [W-1:0] value_source;
    T type_source;
    int plain_source;

    covergroup cg;
      cp_value: coverpoint value_source {
        bins zero = {0};
        bins nonzero = {[1:(2**W)-1]};
      }
      cp_type: coverpoint type_source {
        bins zero = {0};
        bins nonzero = {[1:15]};
      }
      cp_plain: coverpoint plain_source {
        bins zero = {0};
        bins nonzero = {[1:15]};
      }
    endgroup

    function new(); cg = new; endfunction
  endclass

  B#(3, byte) item;
  initial begin
    item = new;
    item.value_source = 1;
    item.type_source = 0;
    item.plain_source = 1;
    item.cg.sample();
    $display("coverage=%0.1f", item.cg.get_inst_coverage());
  end
endmodule
