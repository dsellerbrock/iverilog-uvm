// IEEE 1800-2017/2023 6.21: an explicit declaration lifetime overrides
// the enclosing subroutine lifetime for every variable storage kind.
module m12_decl_lifetime;
  class payload;
    int value;
  endclass

  task static explicit_automatic;
    automatic logic [3:0] auto_vec;
    automatic real auto_real;
    automatic string auto_string;
    automatic int auto_darray[];
    automatic int auto_queue[$];
    automatic payload auto_object;

    $check_decl_lifetime(1, auto_vec, auto_real, auto_string,
                         auto_darray, auto_queue, auto_object);
  endtask

  task automatic explicit_static;
    static logic [3:0] static_vec;
    static real static_real;
    static string static_string;
    static int static_darray[];
    static int static_queue[$];
    static payload static_object;

    $check_decl_lifetime(0, static_vec, static_real, static_string,
                         static_darray, static_queue, static_object);
  endtask

  initial begin
    explicit_automatic();
    explicit_static();
    $display("PASSED");
    $finish(0);
  end
endmodule
