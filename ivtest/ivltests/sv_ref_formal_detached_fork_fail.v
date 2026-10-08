module sv_ref_formal_detached_fork_fail;
  int shared;

  task automatic invalid(ref int value);
    fork
      begin
        value = value + 1;
      end
    join_none
  endtask

  initial invalid(shared);
endmodule
