// IEEE 1800-2017/2023 8.19, 19.5 and 26.3: a package import in a
// constructor's lexical scope shadows an enclosing class parameter.
package repeat_count_shadow_pkg;
  parameter int N = 0;
endpackage

module top;
  class function_import_c #(int N = 1);
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new;
      import repeat_count_shadow_pkg::N;
      repeat (N)
        limit = 14;
      cg = new;
    endfunction
  endclass

  class block_import_c #(int N = 1);
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new;
      begin
        import repeat_count_shadow_pkg::N;
        repeat (N)
          limit = 15;
      end
      cg = new;
    endfunction
  endclass

  class wide_literal_c;
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new;
      repeat (65'h1_0000000000000001)
        limit = 16;
      cg = new;
    endfunction
  endclass

  class wide_parameter_c #(bit [64:0] N = 65'h1_0000000000000001);
    const int limit;
    covergroup cg with function sample(int value);
      cp: coverpoint value {
        bins in_range = {[0:limit]};
      }
    endgroup
    function new;
      repeat (N)
        limit = 17;
      cg = new;
    endfunction
  endclass
endmodule
