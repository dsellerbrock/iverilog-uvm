class issue766_c #(int N = 6, type T = bit);
  typedef T [N-1:0] word_t;
endclass

package issue766_pkg;
  class issue766_c #(int N = 7);
    typedef bit [N-1:0] word_t;
  endclass
endpackage

class issue766_d;
  extern function issue766_c#(5)::word_t external_word();
  function issue766_c#(6)::word_t f();
    return 6'h2a;
  endfunction
  function issue766_c#(3)::word_t narrow();
    return 3'h5;
  endfunction
  function issue766_c#(3)::word_t [1:0] packed_words();
    return 6'h2a;
  endfunction
  function issue766_c#()::word_t default_word();
    return 6'h31;
  endfunction
  function issue766_c#(4) make_null();
    return null;
  endfunction
  function issue766_pkg::issue766_c#(7)::word_t package_word();
    return 7'h65;
  endfunction
  function issue766_pkg::issue766_c#(7) package_null();
    return null;
  endfunction
endclass

function issue766_c#(5)::word_t issue766_d::external_word();
  return 5'h19;
endfunction

class issue766_dependent #(int N = 4);
  function issue766_c#(N)::word_t f();
    return '1;
  endfunction
endclass

module issue766_specialized_return;
  issue766_d d;
  issue766_dependent#(4) dep4;
  issue766_dependent#(7) dep7;
  function issue766_c#(.N(4), .T(logic))::word_t module_word();
    return 4'b10xz;
  endfunction
  initial begin
    d = new;
    dep4 = new;
    dep7 = new;
    if ($bits(d.f()) != 6 || d.f() !== 6'h2a) $fatal(1, "f");
    if ($bits(d.narrow()) != 3 || d.narrow() !== 3'h5) $fatal(1, "narrow");
    if ($bits(d.packed_words()) != 6 || d.packed_words() !== 6'h2a) $fatal(1, "packed");
    if ($bits(d.default_word()) != 6 || d.default_word() !== 6'h31) $fatal(1, "default");
    if ($bits(d.external_word()) != 5 || d.external_word() !== 5'h19) $fatal(1, "extern");
    if (d.make_null() != null) $fatal(1, "class handle return");
    if ($bits(d.package_word()) != 7 || d.package_word() !== 7'h65) $fatal(1, "package");
    if (d.package_null() != null) $fatal(1, "package class handle return");
    if ($bits(dep4.f()) != 4 || dep4.f() !== 4'hf) $fatal(1, "dependent 4");
    if ($bits(dep7.f()) != 7 || dep7.f() !== 7'h7f) $fatal(1, "dependent 7");
    if ($bits(module_word()) != 4 || module_word() !== 4'b10xz) $fatal(1, "module");
    $display("PASS");
  end
endmodule
