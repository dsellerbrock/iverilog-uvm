// Reduced declaration regressions from the sv-tests class/member/typedef
// corpus.  In particular, `bool` remains an Icarus extension type unless a
// visible IEEE typedef shadows it.
class declaration_packet;
endclass

class declaration_holder;
  typedef logic bool;
  localparam int N = 2;

  static const int first_constant = 1, second_constant = 2;
  bool stored;
  declaration_packet compact[*];
  declaration_packet trailing[* ];
  declaration_packet leading[ *];
  declaration_packet separated[ * ];

  extern function void set_value(input bool value);
  extern function void set_array(input bool values[N]);
endclass

function void declaration_holder::set_value(input bool value);
  stored = value;
endfunction

function void declaration_holder::set_array(input bool values[N]);
  stored = values[0] & values[1];
endfunction

module test;
  logic input_value;

  initial begin
    declaration_holder holder;
    logic values[2];

    holder = new;
    input_value = 1'b1;
    holder.set_value(input_value);
    if (holder.stored !== 1'b1)
      $fatal(1, "class bool typedef did not reach an extern method");

    values[0] = 1'b1;
    values[1] = 1'b1;
    holder.set_array(values);
    if (holder.stored !== 1'b1)
      $fatal(1, "class bool typedef did not reach an array formal");
    if (holder.first_constant != 1 || holder.second_constant != 2)
      $fatal(1, "static const class properties were not initialized");

    $display("PASSED");
  end
endmodule
