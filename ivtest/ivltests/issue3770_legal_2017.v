typedef logic [12:0] imported_t;
typedef logic [6:0] qualified_t;
typedef logic [4:0] local_t;
typedef logic [8:0] unit_actual_t;
nettype logic [1:0] shared_net_t;

class Choice;
  typedef logic [1:0] nested_t;
endclass

package provider;
  typedef logic [2:0] imported_t;
  typedef logic [3:0] qualified_t;
  nettype logic [5:0] shared_net_t;
  class Actual;
    typedef logic [3:0] nested_t;
  endclass
  class Box #(type T = int);
    T field;
  endclass
endpackage

package consumer;
  import provider::*;
  typedef logic [5:0] local_t;
  typedef Actual Choice;

  typedef imported_t from_import_t;
  typedef provider::qualified_t from_qualified_t;
  typedef Choice::nested_t selected_t;
  nettype provider::shared_net_t local_net_t;

  function automatic int check_names();
    int qualified_t = 7;
    local_t data;
    return qualified_t + $bits(data);
  endfunction
endpackage

module test;
  import consumer::local_net_t;
  local_net_t bus;
  provider::Box #(unit_actual_t) boxed;
  consumer::from_import_t imported_word;
  consumer::from_qualified_t qualified_word;
  consumer::selected_t class_word;
  initial begin
    boxed = new;
    if ($bits(imported_word) != 3 || $bits(qualified_word) != 4 ||
        $bits(class_word) != 4 || $bits(bus) != 6 ||
        $bits(boxed.field) != 9 || consumer::check_names() != 13)
      $fatal(1, "Incorrect shadowing or package binding");
    $display("PASSED");
  end
endmodule
