// IEEE 1800-2017/2023 18.8: the built-in rand_mode() cannot be overridden.
class invalid_rand_mode_override;
  rand int value;
  function void rand_mode(bit on_off);
  endfunction
endclass

module test;
  invalid_rand_mode_override item = new;
endmodule
