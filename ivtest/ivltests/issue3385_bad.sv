class issue3385_bad_class;
  extern function int renamed_function(input int value);
  extern task renamed_task(input int value);
  extern function new(input int);
endclass

function int issue3385_bad_class::renamed_function(input int other);
  return other;
endfunction

task issue3385_bad_class::renamed_task(input int other);
endtask

function issue3385_bad_class::new(input int value);
endfunction

module issue3385_bad;
  task unnamed_body(input int);
  endtask
endmodule
