// IEEE 1800-2017/2023 10.3.2 and 11.4.11.
module issue3942;
  int a = 1, b = 2, c = 3;
  int calls = 0, nested_calls = 0, single_calls = 0;
  int select_calls = 0, true_calls = 0, false_calls = 0;
  logic sel = 1;
  wire [31:0] n[0:1];
  wire [31:0] m[4:3][-1:-2];
  wire [31:0] one[7:7];
  wire [7:0] choice[2:1];

  function automatic int f(input int x);
    calls++;
    return x + 8;
  endfunction

  function automatic int nested_f(input int x);
    nested_calls++;
    return x + 20;
  endfunction

  function automatic int single_f(input int x);
    single_calls++;
    return x + 30;
  endfunction

  function automatic logic select_arm(input logic test);
    select_calls++;
    return test;
  endfunction

  function automatic logic [7:0] true_value(input int x);
    true_calls++;
    return 8'(x + 4);
  endfunction

  function automatic logic [7:0] false_value(input int x);
    false_calls++;
    return 8'(x + 6);
  endfunction

  assign n = '{f(a) + c, b};
  assign m = '{'{nested_f(a), b}, '{c, 32'd99}};
  assign one = {single_f(a) + b};
  assign choice = select_arm(sel) ? '{true_value(a), b[7:0]}
                                  : '{false_value(a), b[7:0]};

  task automatic show_arrays;
    $display("%0d/%0d calls=%0d", n[0], n[1], calls);
    $display("nested=%0d/%0d/%0d/%0d calls=%0d",
             m[4][-1], m[4][-2], m[3][-1], m[3][-2], nested_calls);
    $display("single=%0d calls=%0d", one[7], single_calls);
  endtask

  task automatic show_choice;
    $display("choice=%b/%0d select=%0d true=%0d false=%0d",
             choice[2], choice[1], select_calls, true_calls, false_calls);
  endtask

  initial begin
    #1 show_arrays();
    show_choice();
    b = 9;
    #1 show_arrays();
    show_choice();
    c = 4;
    #1 show_arrays();
    show_choice();
    sel = 0;
    #1 show_choice();
    sel = 1'bx;
    #1 show_choice();
    sel = 1'bz;
    #1 show_choice();
  end
endmodule
