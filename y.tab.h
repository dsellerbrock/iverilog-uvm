/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_Y_TAB_H_INCLUDED
# define YY_YY_Y_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 1
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    IDENTIFIER = 258,              /* IDENTIFIER  */
    SYSTEM_IDENTIFIER = 259,       /* SYSTEM_IDENTIFIER  */
    STRING = 260,                  /* STRING  */
    TIME_LITERAL = 261,            /* TIME_LITERAL  */
    TYPE_IDENTIFIER = 262,         /* TYPE_IDENTIFIER  */
    PACKAGE_IDENTIFIER = 263,      /* PACKAGE_IDENTIFIER  */
    DISCIPLINE_IDENTIFIER = 264,   /* DISCIPLINE_IDENTIFIER  */
    PATHPULSE_IDENTIFIER = 265,    /* PATHPULSE_IDENTIFIER  */
    BASED_NUMBER = 266,            /* BASED_NUMBER  */
    DEC_NUMBER = 267,              /* DEC_NUMBER  */
    UNBASED_NUMBER = 268,          /* UNBASED_NUMBER  */
    REALTIME = 269,                /* REALTIME  */
    K_PLUS_EQ = 270,               /* K_PLUS_EQ  */
    K_MINUS_EQ = 271,              /* K_MINUS_EQ  */
    K_INCR = 272,                  /* K_INCR  */
    K_DECR = 273,                  /* K_DECR  */
    K_LE = 274,                    /* K_LE  */
    K_GE = 275,                    /* K_GE  */
    K_EG = 276,                    /* K_EG  */
    K_EQ = 277,                    /* K_EQ  */
    K_NE = 278,                    /* K_NE  */
    K_CEQ = 279,                   /* K_CEQ  */
    K_CNE = 280,                   /* K_CNE  */
    K_WEQ = 281,                   /* K_WEQ  */
    K_WNE = 282,                   /* K_WNE  */
    K_LP = 283,                    /* K_LP  */
    K_LS = 284,                    /* K_LS  */
    K_RS = 285,                    /* K_RS  */
    K_RSS = 286,                   /* K_RSS  */
    K_SG = 287,                    /* K_SG  */
    K_CONTRIBUTE = 288,            /* K_CONTRIBUTE  */
    K_PO_POS = 289,                /* K_PO_POS  */
    K_PO_NEG = 290,                /* K_PO_NEG  */
    K_POW = 291,                   /* K_POW  */
    K_PSTAR = 292,                 /* K_PSTAR  */
    K_STARP = 293,                 /* K_STARP  */
    K_DOTSTAR = 294,               /* K_DOTSTAR  */
    K_LOR = 295,                   /* K_LOR  */
    K_LAND = 296,                  /* K_LAND  */
    K_NAND = 297,                  /* K_NAND  */
    K_NOR = 298,                   /* K_NOR  */
    K_NXOR = 299,                  /* K_NXOR  */
    K_TRIGGER = 300,               /* K_TRIGGER  */
    K_NB_TRIGGER = 301,            /* K_NB_TRIGGER  */
    K_LEQUIV = 302,                /* K_LEQUIV  */
    K_PIPE_IMPL_OV = 303,          /* K_PIPE_IMPL_OV  */
    K_PIPE_IMPL_NOV = 304,         /* K_PIPE_IMPL_NOV  */
    K_SCOPE_RES = 305,             /* K_SCOPE_RES  */
    K_edge_descriptor = 306,       /* K_edge_descriptor  */
    K_CONSTRAINT_IMPL = 307,       /* K_CONSTRAINT_IMPL  */
    K_always = 308,                /* K_always  */
    K_and = 309,                   /* K_and  */
    K_assign = 310,                /* K_assign  */
    K_begin = 311,                 /* K_begin  */
    K_buf = 312,                   /* K_buf  */
    K_bufif0 = 313,                /* K_bufif0  */
    K_bufif1 = 314,                /* K_bufif1  */
    K_case = 315,                  /* K_case  */
    K_casex = 316,                 /* K_casex  */
    K_casez = 317,                 /* K_casez  */
    K_cmos = 318,                  /* K_cmos  */
    K_deassign = 319,              /* K_deassign  */
    K_default = 320,               /* K_default  */
    K_defparam = 321,              /* K_defparam  */
    K_disable = 322,               /* K_disable  */
    K_edge = 323,                  /* K_edge  */
    K_else = 324,                  /* K_else  */
    K_end = 325,                   /* K_end  */
    K_endcase = 326,               /* K_endcase  */
    K_endfunction = 327,           /* K_endfunction  */
    K_endmodule = 328,             /* K_endmodule  */
    K_endprimitive = 329,          /* K_endprimitive  */
    K_endspecify = 330,            /* K_endspecify  */
    K_endtable = 331,              /* K_endtable  */
    K_endtask = 332,               /* K_endtask  */
    K_event = 333,                 /* K_event  */
    K_for = 334,                   /* K_for  */
    K_force = 335,                 /* K_force  */
    K_forever = 336,               /* K_forever  */
    K_fork = 337,                  /* K_fork  */
    K_function = 338,              /* K_function  */
    K_highz0 = 339,                /* K_highz0  */
    K_highz1 = 340,                /* K_highz1  */
    K_if = 341,                    /* K_if  */
    K_ifnone = 342,                /* K_ifnone  */
    K_initial = 343,               /* K_initial  */
    K_inout = 344,                 /* K_inout  */
    K_input = 345,                 /* K_input  */
    K_integer = 346,               /* K_integer  */
    K_join = 347,                  /* K_join  */
    K_large = 348,                 /* K_large  */
    K_macromodule = 349,           /* K_macromodule  */
    K_medium = 350,                /* K_medium  */
    K_module = 351,                /* K_module  */
    K_nand = 352,                  /* K_nand  */
    K_negedge = 353,               /* K_negedge  */
    K_nmos = 354,                  /* K_nmos  */
    K_nor = 355,                   /* K_nor  */
    K_not = 356,                   /* K_not  */
    K_notif0 = 357,                /* K_notif0  */
    K_notif1 = 358,                /* K_notif1  */
    K_or = 359,                    /* K_or  */
    K_output = 360,                /* K_output  */
    K_parameter = 361,             /* K_parameter  */
    K_pmos = 362,                  /* K_pmos  */
    K_posedge = 363,               /* K_posedge  */
    K_primitive = 364,             /* K_primitive  */
    K_pull0 = 365,                 /* K_pull0  */
    K_pull1 = 366,                 /* K_pull1  */
    K_pulldown = 367,              /* K_pulldown  */
    K_pullup = 368,                /* K_pullup  */
    K_rcmos = 369,                 /* K_rcmos  */
    K_real = 370,                  /* K_real  */
    K_realtime = 371,              /* K_realtime  */
    K_reg = 372,                   /* K_reg  */
    K_release = 373,               /* K_release  */
    K_repeat = 374,                /* K_repeat  */
    K_rnmos = 375,                 /* K_rnmos  */
    K_rpmos = 376,                 /* K_rpmos  */
    K_rtran = 377,                 /* K_rtran  */
    K_rtranif0 = 378,              /* K_rtranif0  */
    K_rtranif1 = 379,              /* K_rtranif1  */
    K_scalared = 380,              /* K_scalared  */
    K_small = 381,                 /* K_small  */
    K_specify = 382,               /* K_specify  */
    K_specparam = 383,             /* K_specparam  */
    K_strong0 = 384,               /* K_strong0  */
    K_strong1 = 385,               /* K_strong1  */
    K_supply0 = 386,               /* K_supply0  */
    K_supply1 = 387,               /* K_supply1  */
    K_table = 388,                 /* K_table  */
    K_task = 389,                  /* K_task  */
    K_time = 390,                  /* K_time  */
    K_tran = 391,                  /* K_tran  */
    K_tranif0 = 392,               /* K_tranif0  */
    K_tranif1 = 393,               /* K_tranif1  */
    K_tri = 394,                   /* K_tri  */
    K_tri0 = 395,                  /* K_tri0  */
    K_tri1 = 396,                  /* K_tri1  */
    K_triand = 397,                /* K_triand  */
    K_trior = 398,                 /* K_trior  */
    K_trireg = 399,                /* K_trireg  */
    K_vectored = 400,              /* K_vectored  */
    K_wait = 401,                  /* K_wait  */
    K_wand = 402,                  /* K_wand  */
    K_weak0 = 403,                 /* K_weak0  */
    K_weak1 = 404,                 /* K_weak1  */
    K_while = 405,                 /* K_while  */
    K_wire = 406,                  /* K_wire  */
    K_wor = 407,                   /* K_wor  */
    K_xnor = 408,                  /* K_xnor  */
    K_xor = 409,                   /* K_xor  */
    K_Shold = 410,                 /* K_Shold  */
    K_Snochange = 411,             /* K_Snochange  */
    K_Speriod = 412,               /* K_Speriod  */
    K_Srecovery = 413,             /* K_Srecovery  */
    K_Ssetup = 414,                /* K_Ssetup  */
    K_Ssetuphold = 415,            /* K_Ssetuphold  */
    K_Sskew = 416,                 /* K_Sskew  */
    K_Swidth = 417,                /* K_Swidth  */
    KK_attribute = 418,            /* KK_attribute  */
    K_bool = 419,                  /* K_bool  */
    K_logic = 420,                 /* K_logic  */
    K_automatic = 421,             /* K_automatic  */
    K_endgenerate = 422,           /* K_endgenerate  */
    K_generate = 423,              /* K_generate  */
    K_genvar = 424,                /* K_genvar  */
    K_localparam = 425,            /* K_localparam  */
    K_noshowcancelled = 426,       /* K_noshowcancelled  */
    K_pulsestyle_onevent = 427,    /* K_pulsestyle_onevent  */
    K_pulsestyle_ondetect = 428,   /* K_pulsestyle_ondetect  */
    K_showcancelled = 429,         /* K_showcancelled  */
    K_signed = 430,                /* K_signed  */
    K_unsigned = 431,              /* K_unsigned  */
    K_Sfullskew = 432,             /* K_Sfullskew  */
    K_Srecrem = 433,               /* K_Srecrem  */
    K_Sremoval = 434,              /* K_Sremoval  */
    K_Stimeskew = 435,             /* K_Stimeskew  */
    K_cell = 436,                  /* K_cell  */
    K_config = 437,                /* K_config  */
    K_design = 438,                /* K_design  */
    K_endconfig = 439,             /* K_endconfig  */
    K_incdir = 440,                /* K_incdir  */
    K_include = 441,               /* K_include  */
    K_instance = 442,              /* K_instance  */
    K_liblist = 443,               /* K_liblist  */
    K_library = 444,               /* K_library  */
    K_use = 445,                   /* K_use  */
    K_wone = 446,                  /* K_wone  */
    K_uwire = 447,                 /* K_uwire  */
    K_alias = 448,                 /* K_alias  */
    K_always_comb = 449,           /* K_always_comb  */
    K_always_ff = 450,             /* K_always_ff  */
    K_always_latch = 451,          /* K_always_latch  */
    K_assert = 452,                /* K_assert  */
    K_assume = 453,                /* K_assume  */
    K_before = 454,                /* K_before  */
    K_bind = 455,                  /* K_bind  */
    K_bins = 456,                  /* K_bins  */
    K_binsof = 457,                /* K_binsof  */
    K_bit = 458,                   /* K_bit  */
    K_break = 459,                 /* K_break  */
    K_byte = 460,                  /* K_byte  */
    K_chandle = 461,               /* K_chandle  */
    K_class = 462,                 /* K_class  */
    K_clocking = 463,              /* K_clocking  */
    K_const = 464,                 /* K_const  */
    K_constraint = 465,            /* K_constraint  */
    K_context = 466,               /* K_context  */
    K_continue = 467,              /* K_continue  */
    K_cover = 468,                 /* K_cover  */
    K_covergroup = 469,            /* K_covergroup  */
    K_coverpoint = 470,            /* K_coverpoint  */
    K_cross = 471,                 /* K_cross  */
    K_dist = 472,                  /* K_dist  */
    K_do = 473,                    /* K_do  */
    K_endclass = 474,              /* K_endclass  */
    K_endclocking = 475,           /* K_endclocking  */
    K_endgroup = 476,              /* K_endgroup  */
    K_endinterface = 477,          /* K_endinterface  */
    K_endpackage = 478,            /* K_endpackage  */
    K_endprogram = 479,            /* K_endprogram  */
    K_endproperty = 480,           /* K_endproperty  */
    K_endsequence = 481,           /* K_endsequence  */
    K_enum = 482,                  /* K_enum  */
    K_expect = 483,                /* K_expect  */
    K_export = 484,                /* K_export  */
    K_extends = 485,               /* K_extends  */
    K_extern = 486,                /* K_extern  */
    K_final = 487,                 /* K_final  */
    K_first_match = 488,           /* K_first_match  */
    K_foreach = 489,               /* K_foreach  */
    K_forkjoin = 490,              /* K_forkjoin  */
    K_iff = 491,                   /* K_iff  */
    K_ignore_bins = 492,           /* K_ignore_bins  */
    K_illegal_bins = 493,          /* K_illegal_bins  */
    K_import = 494,                /* K_import  */
    K_inside = 495,                /* K_inside  */
    K_int = 496,                   /* K_int  */
    K_interface = 497,             /* K_interface  */
    K_intersect = 498,             /* K_intersect  */
    K_join_any = 499,              /* K_join_any  */
    K_join_none = 500,             /* K_join_none  */
    K_local = 501,                 /* K_local  */
    K_longint = 502,               /* K_longint  */
    K_matches = 503,               /* K_matches  */
    K_modport = 504,               /* K_modport  */
    K_new = 505,                   /* K_new  */
    K_null = 506,                  /* K_null  */
    K_package = 507,               /* K_package  */
    K_packed = 508,                /* K_packed  */
    K_priority = 509,              /* K_priority  */
    K_program = 510,               /* K_program  */
    K_property = 511,              /* K_property  */
    K_protected = 512,             /* K_protected  */
    K_pure = 513,                  /* K_pure  */
    K_rand = 514,                  /* K_rand  */
    K_randc = 515,                 /* K_randc  */
    K_randcase = 516,              /* K_randcase  */
    K_randsequence = 517,          /* K_randsequence  */
    K_ref = 518,                   /* K_ref  */
    K_return = 519,                /* K_return  */
    K_sequence = 520,              /* K_sequence  */
    K_shortint = 521,              /* K_shortint  */
    K_shortreal = 522,             /* K_shortreal  */
    K_solve = 523,                 /* K_solve  */
    K_static = 524,                /* K_static  */
    K_string = 525,                /* K_string  */
    K_struct = 526,                /* K_struct  */
    K_super = 527,                 /* K_super  */
    K_tagged = 528,                /* K_tagged  */
    K_this = 529,                  /* K_this  */
    K_throughout = 530,            /* K_throughout  */
    K_timeprecision = 531,         /* K_timeprecision  */
    K_timeunit = 532,              /* K_timeunit  */
    K_type = 533,                  /* K_type  */
    K_typedef = 534,               /* K_typedef  */
    K_union = 535,                 /* K_union  */
    K_unique = 536,                /* K_unique  */
    K_var = 537,                   /* K_var  */
    K_virtual = 538,               /* K_virtual  */
    K_void = 539,                  /* K_void  */
    K_wait_order = 540,            /* K_wait_order  */
    K_wildcard = 541,              /* K_wildcard  */
    K_with = 542,                  /* K_with  */
    K_within = 543,                /* K_within  */
    K_accept_on = 544,             /* K_accept_on  */
    K_checker = 545,               /* K_checker  */
    K_endchecker = 546,            /* K_endchecker  */
    K_eventually = 547,            /* K_eventually  */
    K_global = 548,                /* K_global  */
    K_implies = 549,               /* K_implies  */
    K_let = 550,                   /* K_let  */
    K_nexttime = 551,              /* K_nexttime  */
    K_reject_on = 552,             /* K_reject_on  */
    K_restrict = 553,              /* K_restrict  */
    K_s_always = 554,              /* K_s_always  */
    K_s_eventually = 555,          /* K_s_eventually  */
    K_s_nexttime = 556,            /* K_s_nexttime  */
    K_s_until = 557,               /* K_s_until  */
    K_s_until_with = 558,          /* K_s_until_with  */
    K_strong = 559,                /* K_strong  */
    K_sync_accept_on = 560,        /* K_sync_accept_on  */
    K_sync_reject_on = 561,        /* K_sync_reject_on  */
    K_unique0 = 562,               /* K_unique0  */
    K_until = 563,                 /* K_until  */
    K_until_with = 564,            /* K_until_with  */
    K_untyped = 565,               /* K_untyped  */
    K_weak = 566,                  /* K_weak  */
    K_implements = 567,            /* K_implements  */
    K_interconnect = 568,          /* K_interconnect  */
    K_nettype = 569,               /* K_nettype  */
    K_soft = 570,                  /* K_soft  */
    K_above = 571,                 /* K_above  */
    K_abs = 572,                   /* K_abs  */
    K_absdelay = 573,              /* K_absdelay  */
    K_abstol = 574,                /* K_abstol  */
    K_access = 575,                /* K_access  */
    K_acos = 576,                  /* K_acos  */
    K_acosh = 577,                 /* K_acosh  */
    K_ac_stim = 578,               /* K_ac_stim  */
    K_aliasparam = 579,            /* K_aliasparam  */
    K_analog = 580,                /* K_analog  */
    K_analysis = 581,              /* K_analysis  */
    K_asin = 582,                  /* K_asin  */
    K_asinh = 583,                 /* K_asinh  */
    K_atan = 584,                  /* K_atan  */
    K_atan2 = 585,                 /* K_atan2  */
    K_atanh = 586,                 /* K_atanh  */
    K_branch = 587,                /* K_branch  */
    K_ceil = 588,                  /* K_ceil  */
    K_connect = 589,               /* K_connect  */
    K_connectmodule = 590,         /* K_connectmodule  */
    K_connectrules = 591,          /* K_connectrules  */
    K_continuous = 592,            /* K_continuous  */
    K_cos = 593,                   /* K_cos  */
    K_cosh = 594,                  /* K_cosh  */
    K_ddt = 595,                   /* K_ddt  */
    K_ddt_nature = 596,            /* K_ddt_nature  */
    K_ddx = 597,                   /* K_ddx  */
    K_discipline = 598,            /* K_discipline  */
    K_discrete = 599,              /* K_discrete  */
    K_domain = 600,                /* K_domain  */
    K_driver_update = 601,         /* K_driver_update  */
    K_endconnectrules = 602,       /* K_endconnectrules  */
    K_enddiscipline = 603,         /* K_enddiscipline  */
    K_endnature = 604,             /* K_endnature  */
    K_endparamset = 605,           /* K_endparamset  */
    K_exclude = 606,               /* K_exclude  */
    K_exp = 607,                   /* K_exp  */
    K_final_step = 608,            /* K_final_step  */
    K_flicker_noise = 609,         /* K_flicker_noise  */
    K_floor = 610,                 /* K_floor  */
    K_flow = 611,                  /* K_flow  */
    K_from = 612,                  /* K_from  */
    K_ground = 613,                /* K_ground  */
    K_hypot = 614,                 /* K_hypot  */
    K_idt = 615,                   /* K_idt  */
    K_idtmod = 616,                /* K_idtmod  */
    K_idt_nature = 617,            /* K_idt_nature  */
    K_inf = 618,                   /* K_inf  */
    K_initial_step = 619,          /* K_initial_step  */
    K_laplace_nd = 620,            /* K_laplace_nd  */
    K_laplace_np = 621,            /* K_laplace_np  */
    K_laplace_zd = 622,            /* K_laplace_zd  */
    K_laplace_zp = 623,            /* K_laplace_zp  */
    K_last_crossing = 624,         /* K_last_crossing  */
    K_limexp = 625,                /* K_limexp  */
    K_ln = 626,                    /* K_ln  */
    K_log = 627,                   /* K_log  */
    K_max = 628,                   /* K_max  */
    K_merged = 629,                /* K_merged  */
    K_min = 630,                   /* K_min  */
    K_nature = 631,                /* K_nature  */
    K_net_resolution = 632,        /* K_net_resolution  */
    K_noise_table = 633,           /* K_noise_table  */
    K_paramset = 634,              /* K_paramset  */
    K_potential = 635,             /* K_potential  */
    K_pow = 636,                   /* K_pow  */
    K_resolveto = 637,             /* K_resolveto  */
    K_sin = 638,                   /* K_sin  */
    K_sinh = 639,                  /* K_sinh  */
    K_slew = 640,                  /* K_slew  */
    K_split = 641,                 /* K_split  */
    K_sqrt = 642,                  /* K_sqrt  */
    K_tan = 643,                   /* K_tan  */
    K_tanh = 644,                  /* K_tanh  */
    K_timer = 645,                 /* K_timer  */
    K_transition = 646,            /* K_transition  */
    K_units = 647,                 /* K_units  */
    K_white_noise = 648,           /* K_white_noise  */
    K_wreal = 649,                 /* K_wreal  */
    K_zi_nd = 650,                 /* K_zi_nd  */
    K_zi_np = 651,                 /* K_zi_np  */
    K_zi_zd = 652,                 /* K_zi_zd  */
    K_zi_zp = 653,                 /* K_zi_zp  */
    K_TAND = 654,                  /* K_TAND  */
    K_MUL_EQ = 655,                /* K_MUL_EQ  */
    K_DIV_EQ = 656,                /* K_DIV_EQ  */
    K_MOD_EQ = 657,                /* K_MOD_EQ  */
    K_AND_EQ = 658,                /* K_AND_EQ  */
    K_OR_EQ = 659,                 /* K_OR_EQ  */
    K_XOR_EQ = 660,                /* K_XOR_EQ  */
    K_LS_EQ = 661,                 /* K_LS_EQ  */
    K_RS_EQ = 662,                 /* K_RS_EQ  */
    K_RSS_EQ = 663,                /* K_RSS_EQ  */
    UNARY_PREC = 664,              /* UNARY_PREC  */
    less_than_K_else = 665,        /* less_than_K_else  */
    no_timeunits_declaration = 666, /* no_timeunits_declaration  */
    one_timeunits_declaration = 667 /* one_timeunits_declaration  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif
/* Token kinds.  */
#define YYEMPTY -2
#define YYEOF 0
#define YYerror 256
#define YYUNDEF 257
#define IDENTIFIER 258
#define SYSTEM_IDENTIFIER 259
#define STRING 260
#define TIME_LITERAL 261
#define TYPE_IDENTIFIER 262
#define PACKAGE_IDENTIFIER 263
#define DISCIPLINE_IDENTIFIER 264
#define PATHPULSE_IDENTIFIER 265
#define BASED_NUMBER 266
#define DEC_NUMBER 267
#define UNBASED_NUMBER 268
#define REALTIME 269
#define K_PLUS_EQ 270
#define K_MINUS_EQ 271
#define K_INCR 272
#define K_DECR 273
#define K_LE 274
#define K_GE 275
#define K_EG 276
#define K_EQ 277
#define K_NE 278
#define K_CEQ 279
#define K_CNE 280
#define K_WEQ 281
#define K_WNE 282
#define K_LP 283
#define K_LS 284
#define K_RS 285
#define K_RSS 286
#define K_SG 287
#define K_CONTRIBUTE 288
#define K_PO_POS 289
#define K_PO_NEG 290
#define K_POW 291
#define K_PSTAR 292
#define K_STARP 293
#define K_DOTSTAR 294
#define K_LOR 295
#define K_LAND 296
#define K_NAND 297
#define K_NOR 298
#define K_NXOR 299
#define K_TRIGGER 300
#define K_NB_TRIGGER 301
#define K_LEQUIV 302
#define K_PIPE_IMPL_OV 303
#define K_PIPE_IMPL_NOV 304
#define K_SCOPE_RES 305
#define K_edge_descriptor 306
#define K_CONSTRAINT_IMPL 307
#define K_always 308
#define K_and 309
#define K_assign 310
#define K_begin 311
#define K_buf 312
#define K_bufif0 313
#define K_bufif1 314
#define K_case 315
#define K_casex 316
#define K_casez 317
#define K_cmos 318
#define K_deassign 319
#define K_default 320
#define K_defparam 321
#define K_disable 322
#define K_edge 323
#define K_else 324
#define K_end 325
#define K_endcase 326
#define K_endfunction 327
#define K_endmodule 328
#define K_endprimitive 329
#define K_endspecify 330
#define K_endtable 331
#define K_endtask 332
#define K_event 333
#define K_for 334
#define K_force 335
#define K_forever 336
#define K_fork 337
#define K_function 338
#define K_highz0 339
#define K_highz1 340
#define K_if 341
#define K_ifnone 342
#define K_initial 343
#define K_inout 344
#define K_input 345
#define K_integer 346
#define K_join 347
#define K_large 348
#define K_macromodule 349
#define K_medium 350
#define K_module 351
#define K_nand 352
#define K_negedge 353
#define K_nmos 354
#define K_nor 355
#define K_not 356
#define K_notif0 357
#define K_notif1 358
#define K_or 359
#define K_output 360
#define K_parameter 361
#define K_pmos 362
#define K_posedge 363
#define K_primitive 364
#define K_pull0 365
#define K_pull1 366
#define K_pulldown 367
#define K_pullup 368
#define K_rcmos 369
#define K_real 370
#define K_realtime 371
#define K_reg 372
#define K_release 373
#define K_repeat 374
#define K_rnmos 375
#define K_rpmos 376
#define K_rtran 377
#define K_rtranif0 378
#define K_rtranif1 379
#define K_scalared 380
#define K_small 381
#define K_specify 382
#define K_specparam 383
#define K_strong0 384
#define K_strong1 385
#define K_supply0 386
#define K_supply1 387
#define K_table 388
#define K_task 389
#define K_time 390
#define K_tran 391
#define K_tranif0 392
#define K_tranif1 393
#define K_tri 394
#define K_tri0 395
#define K_tri1 396
#define K_triand 397
#define K_trior 398
#define K_trireg 399
#define K_vectored 400
#define K_wait 401
#define K_wand 402
#define K_weak0 403
#define K_weak1 404
#define K_while 405
#define K_wire 406
#define K_wor 407
#define K_xnor 408
#define K_xor 409
#define K_Shold 410
#define K_Snochange 411
#define K_Speriod 412
#define K_Srecovery 413
#define K_Ssetup 414
#define K_Ssetuphold 415
#define K_Sskew 416
#define K_Swidth 417
#define KK_attribute 418
#define K_bool 419
#define K_logic 420
#define K_automatic 421
#define K_endgenerate 422
#define K_generate 423
#define K_genvar 424
#define K_localparam 425
#define K_noshowcancelled 426
#define K_pulsestyle_onevent 427
#define K_pulsestyle_ondetect 428
#define K_showcancelled 429
#define K_signed 430
#define K_unsigned 431
#define K_Sfullskew 432
#define K_Srecrem 433
#define K_Sremoval 434
#define K_Stimeskew 435
#define K_cell 436
#define K_config 437
#define K_design 438
#define K_endconfig 439
#define K_incdir 440
#define K_include 441
#define K_instance 442
#define K_liblist 443
#define K_library 444
#define K_use 445
#define K_wone 446
#define K_uwire 447
#define K_alias 448
#define K_always_comb 449
#define K_always_ff 450
#define K_always_latch 451
#define K_assert 452
#define K_assume 453
#define K_before 454
#define K_bind 455
#define K_bins 456
#define K_binsof 457
#define K_bit 458
#define K_break 459
#define K_byte 460
#define K_chandle 461
#define K_class 462
#define K_clocking 463
#define K_const 464
#define K_constraint 465
#define K_context 466
#define K_continue 467
#define K_cover 468
#define K_covergroup 469
#define K_coverpoint 470
#define K_cross 471
#define K_dist 472
#define K_do 473
#define K_endclass 474
#define K_endclocking 475
#define K_endgroup 476
#define K_endinterface 477
#define K_endpackage 478
#define K_endprogram 479
#define K_endproperty 480
#define K_endsequence 481
#define K_enum 482
#define K_expect 483
#define K_export 484
#define K_extends 485
#define K_extern 486
#define K_final 487
#define K_first_match 488
#define K_foreach 489
#define K_forkjoin 490
#define K_iff 491
#define K_ignore_bins 492
#define K_illegal_bins 493
#define K_import 494
#define K_inside 495
#define K_int 496
#define K_interface 497
#define K_intersect 498
#define K_join_any 499
#define K_join_none 500
#define K_local 501
#define K_longint 502
#define K_matches 503
#define K_modport 504
#define K_new 505
#define K_null 506
#define K_package 507
#define K_packed 508
#define K_priority 509
#define K_program 510
#define K_property 511
#define K_protected 512
#define K_pure 513
#define K_rand 514
#define K_randc 515
#define K_randcase 516
#define K_randsequence 517
#define K_ref 518
#define K_return 519
#define K_sequence 520
#define K_shortint 521
#define K_shortreal 522
#define K_solve 523
#define K_static 524
#define K_string 525
#define K_struct 526
#define K_super 527
#define K_tagged 528
#define K_this 529
#define K_throughout 530
#define K_timeprecision 531
#define K_timeunit 532
#define K_type 533
#define K_typedef 534
#define K_union 535
#define K_unique 536
#define K_var 537
#define K_virtual 538
#define K_void 539
#define K_wait_order 540
#define K_wildcard 541
#define K_with 542
#define K_within 543
#define K_accept_on 544
#define K_checker 545
#define K_endchecker 546
#define K_eventually 547
#define K_global 548
#define K_implies 549
#define K_let 550
#define K_nexttime 551
#define K_reject_on 552
#define K_restrict 553
#define K_s_always 554
#define K_s_eventually 555
#define K_s_nexttime 556
#define K_s_until 557
#define K_s_until_with 558
#define K_strong 559
#define K_sync_accept_on 560
#define K_sync_reject_on 561
#define K_unique0 562
#define K_until 563
#define K_until_with 564
#define K_untyped 565
#define K_weak 566
#define K_implements 567
#define K_interconnect 568
#define K_nettype 569
#define K_soft 570
#define K_above 571
#define K_abs 572
#define K_absdelay 573
#define K_abstol 574
#define K_access 575
#define K_acos 576
#define K_acosh 577
#define K_ac_stim 578
#define K_aliasparam 579
#define K_analog 580
#define K_analysis 581
#define K_asin 582
#define K_asinh 583
#define K_atan 584
#define K_atan2 585
#define K_atanh 586
#define K_branch 587
#define K_ceil 588
#define K_connect 589
#define K_connectmodule 590
#define K_connectrules 591
#define K_continuous 592
#define K_cos 593
#define K_cosh 594
#define K_ddt 595
#define K_ddt_nature 596
#define K_ddx 597
#define K_discipline 598
#define K_discrete 599
#define K_domain 600
#define K_driver_update 601
#define K_endconnectrules 602
#define K_enddiscipline 603
#define K_endnature 604
#define K_endparamset 605
#define K_exclude 606
#define K_exp 607
#define K_final_step 608
#define K_flicker_noise 609
#define K_floor 610
#define K_flow 611
#define K_from 612
#define K_ground 613
#define K_hypot 614
#define K_idt 615
#define K_idtmod 616
#define K_idt_nature 617
#define K_inf 618
#define K_initial_step 619
#define K_laplace_nd 620
#define K_laplace_np 621
#define K_laplace_zd 622
#define K_laplace_zp 623
#define K_last_crossing 624
#define K_limexp 625
#define K_ln 626
#define K_log 627
#define K_max 628
#define K_merged 629
#define K_min 630
#define K_nature 631
#define K_net_resolution 632
#define K_noise_table 633
#define K_paramset 634
#define K_potential 635
#define K_pow 636
#define K_resolveto 637
#define K_sin 638
#define K_sinh 639
#define K_slew 640
#define K_split 641
#define K_sqrt 642
#define K_tan 643
#define K_tanh 644
#define K_timer 645
#define K_transition 646
#define K_units 647
#define K_white_noise 648
#define K_wreal 649
#define K_zi_nd 650
#define K_zi_np 651
#define K_zi_zd 652
#define K_zi_zp 653
#define K_TAND 654
#define K_MUL_EQ 655
#define K_DIV_EQ 656
#define K_MOD_EQ 657
#define K_AND_EQ 658
#define K_OR_EQ 659
#define K_XOR_EQ 660
#define K_LS_EQ 661
#define K_RS_EQ 662
#define K_RSS_EQ 663
#define UNARY_PREC 664
#define less_than_K_else 665
#define no_timeunits_declaration 666
#define one_timeunits_declaration 667

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 861 "/home/daniel/uvm_iverilog/iverilog/parse.y"

      bool flag;

      char letter;
      int  int_val;

      enum atom_type_t::type_code atom_type;

	/* text items are C strings allocated by the lexor using
	   strdup. They can be put into lists with the texts type. */
      char*text;
      std::list<perm_string>*perm_strings;

      std::list<pform_ident_t>*identifiers;

      std::list<pform_port_t>*port_list;

      std::vector<pform_tf_port_t>* tf_ports;

      pform_name_t*pform_name;

      ivl_discipline_t discipline;

      hname_t*hier;

      std::list<std::string>*strings;

      struct str_pair_t drive;

      PCase::Item*citem;
      std::vector<PCase::Item*>*citems;
      PCaseMatches::Item*cmitem;
      std::vector<PCaseMatches::Item*>*cmitems;

      lgate*gate;
      std::vector<lgate>*gates;

      Module::port_t *mport;
      LexicalScope::range_t* value_range;
      std::vector<Module::port_t*>*mports;

      std::list<PLet::let_port_t*>*let_port_lst;
      PLet::let_port_t*let_port_itm;

      named_pexpr_t*named_pexpr;
      std::list<named_pexpr_t>*named_pexprs;
      struct parmvalue_t*parmvalue;
      std::list<pform_range_t>*ranges;

      PExpr*expr;
      std::list<PExpr*>*exprs;

      PEEvent*event_expr;
      std::vector<PEEvent*>*event_exprs;

      ivl_case_quality_t case_quality;
      NetNet::Type nettype;
      PGBuiltin::Type gatetype;
      NetNet::PortType porttype;
      ivl_variable_type_t vartype;
      PBlock::BL_TYPE join_keyword;

      PWire*wire;
      std::vector<PWire*>*wires;

      PCallTask *subroutine_call;

      PEventStatement*event_statement;
      Statement*statement;
      std::vector<Statement*>*statement_list;

      // C2 (Phase 62f): pointer to file-scope sva_property_t (defined above).
      sva_property_t* sva_prop;

      decl_assignment_t*decl_assignment;
      std::list<decl_assignment_t*>*decl_assignments;

      struct_member_t*struct_member;
      std::list<struct_member_t*>*struct_members;
      struct_type_t*struct_type;

      std::list<std::pair<perm_string,PExpr*>>*named_pattern;

      data_type_t*data_type;
      class_type_t*class_type;
      real_type_t::type_t real_type;
      property_qualifier_t property_qualifier;
      PPackage*package;

      struct {
	    char*text;
	    typedef_t*type;
      } type_identifier;

      struct {
	    data_type_t*type;
	    std::list<named_pexpr_t> *args;
      } class_declaration_extends;

      struct {
	    char*text;
	    PExpr*expr;
      } genvar_iter;

      struct {
	    bool packed_flag;
	    bool signed_flag;
      } packed_signing;

      verinum* number;

      verireal* realtime;

      PSpecPath* specpath;
      std::list<index_component_t> *dimensions;

      PTimingCheck::event_t* timing_check_event;
      PTimingCheck::optional_args_t* spec_optional_args;

      LexicalScope::lifetime_t lifetime;

      enum typedef_t::basic_type typedef_basic_type;

      inside_range_t* irange;
      std::list<inside_range_t>* irange_list;
      class_type_t::pform_coverpoint_t* coverpoint;
      std::list<class_type_t::pform_coverpoint_t*>* coverpoints;
      class_type_t::pform_cov_bins_t* cov_bins;
      std::list<class_type_t::pform_cov_bins_t*>* cov_bins_list;

#line 1022 "y.tab.h"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif

/* Location type.  */
#if ! defined YYLTYPE && ! defined YYLTYPE_IS_DECLARED
typedef struct YYLTYPE YYLTYPE;
struct YYLTYPE
{
  int first_line;
  int first_column;
  int last_line;
  int last_column;
};
# define YYLTYPE_IS_DECLARED 1
# define YYLTYPE_IS_TRIVIAL 1
#endif


extern YYSTYPE yylval;
extern YYLTYPE yylloc;

int yyparse (void);


#endif /* !YY_YY_Y_TAB_H_INCLUDED  */
