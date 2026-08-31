// IEEE 1800-2017/2023 8.19: lexical authorization is limited to a whole
// property in the constructor of its declaring class.
module top;
  class duplicate_c;
    const int value;
    function new;
      value = 1;
      value = 2;
    endfunction
  endclass

  class outside_c;
    const int value;
    function new;
    endfunction
    function void mutate;
      value = 3;
    endfunction
  endclass

  class base_c;
    const int value;
    function new;
    endfunction
  endclass

  class derived_c extends base_c;
    function new;
      super.new;
      value = 4;
    endfunction
  endclass

  class selected_c;
    const bit [3:0] value;
    function new;
      value[0] = 1'b1;
    endfunction
  endclass
endmodule
