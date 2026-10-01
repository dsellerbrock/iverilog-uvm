// An event control on a ref formal must wake when the variable bound to it
// changes, for class-handle, real and string actuals as for integral ones.
// Such a binding was rejected at run time as an unsupported non-integral
// whole-variable actual (UVM's m_get_q takes a class handle by ref).
class cb;
  int id;
  function new(int i);
    id = i;
  endfunction
endclass

module main;
  int errors;
  int got_obj_module = -1, got_obj_local = -1;
  real got_r = -1.0;
  string got_s = "";
  cb h;
  real hr;
  string hs;

  task automatic wait_handle(ref cb r, output int got);
    @(r);
    got = (r == null) ? -2 : r.id;
  endtask
  task automatic wait_real(ref real r, output real got);
    @(r);
    got = r;
  endtask
  task automatic wait_string(ref string r, output string got);
    @(r);
    got = r;
  endtask

  initial begin
    fork
      wait_handle(h, got_obj_module);
      wait_real(hr, got_r);
      wait_string(hs, got_s);
    join_none
    #1 h = new(5); hr = 2.5; hs = "hello";
    #1;
    if (got_obj_module != 5) begin
      $display("FAILED module handle woke with %0d", got_obj_module); errors++;
    end
    if (got_r != 2.5) begin $display("FAILED real %f", got_r); errors++; end
    if (got_s != "hello") begin $display("FAILED string %s", got_s); errors++; end

    begin
      cb local_h;
      fork
        wait_handle(local_h, got_obj_local);
      join_none
      #1 local_h = new(9);
      #1 if (got_obj_local != 9) begin
        $display("FAILED local handle woke with %0d", got_obj_local); errors++;
      end
    end

    if (errors == 0) $display("PASSED");
  end
endmodule
