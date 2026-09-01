// IEEE 1800-2017/2023 8.19: a detached constructor branch shares the
// constructed object and must not perform a second assignment after new
// returns.
module top;
  class fork_c;
    const bit [7:0] value;
    function new(bit spawn_child);
      fork
        if (spawn_child)
          this.value = 8'ha1;
      join_none
      this.value = 8'ha2;
    endfunction
  endclass

  fork_c object;
  initial begin
    object = new(1);
    #0;
    #1 $fatal(1, "duplicate detached assignment was not rejected");
  end
endmodule
