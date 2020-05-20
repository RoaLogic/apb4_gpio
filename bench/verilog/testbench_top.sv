/////////////////////////////////////////////////////////////////////
//   ,------.                    ,--.                ,--.          //
//   |  .--. ' ,---.  ,--,--.    |  |    ,---. ,---. `--' ,---.    //
//   |  '--'.'| .-. |' ,-.  |    |  |   | .-. | .-. |,--.| .--'    //
//   |  |\  \ ' '-' '\ '-'  |    |  '--.' '-' ' '-' ||  |\ `--.    //
//   `--' '--' `---'  `--`--'    `-----' `---' `-   /`--' `---'    //
//                                             `---'               //
//   APB4 GPIO Testbench (top)                                     //
//                                                                 //
/////////////////////////////////////////////////////////////////////
//                                                                 //
//             Copyright (C) 2020 ROA Logic BV                     //
//             www.roalogic.com                                    //
//                                                                 //
//   This source file may be used and distributed without          //
//   restriction provided that this copyright statement is not     //
//   removed from the file and that any derivative work contains   //
//   the original copyright notice and the associated disclaimer.  //
//                                                                 //
//    This soure file is free software; you can redistribute it    //
//  and/or modify it under the terms of the GNU General Public     //
//  License as published by the Free Software Foundation,          //
//  either version 3 of the License, or (at your option) any later //
//  versions. The current text of the License can be found at:     //
//  http://www.gnu.org/licenses/gpl.html                           //
//                                                                 //
//    This source file is distributed in the hope that it will be  //
//  useful, but WITHOUT ANY WARRANTY; without even the implied     //
//  warranty of MERCHANTABILITY or FITTNESS FOR A PARTICULAR       //
//  PURPOSE. See the GNU General Public License for more details.  //
//                                                                 //
/////////////////////////////////////////////////////////////////////

module testbench_top;
  parameter PDATA_SIZE        = 8;


  /////////////////////////////////////////////////////////
  //
  // Variables
  //
  //APB signals
  logic                    PSEL;
  logic                    PENABLE;
  logic [             3:0] PADDR;
  logic [PDATA_SIZE/8-1:0] PSTRB;
  logic [PDATA_SIZE  -1:0] PWDATA;
  logic [PDATA_SIZE  -1:0] PRDATA;
  logic                    PWRITE;
  logic                    PREADY;
  logic                    PSLVERR;

  //GPIOs
  logic [PDATA_SIZE -1:0] gpio_o, gpio_i, gpio_oe;

  //IRQ
  logic irq_o;


  /////////////////////////////////////////////////////////
  //
  // Clock & Reset
  //
  bit PCLK, PRESETn;
  initial begin : gen_PCLK
      PCLK <= 1'b0;
      forever #10 PCLK = ~PCLK;
  end : gen_PCLK

  initial begin : gen_PRESETn;
    PRESETn = 1'b1;
    //ensure falling edge of PRESETn
    #10;
    PRESETn = 1'b0;
    #32;
    PRESETn = 1'b1;
  end : gen_PRESETn;


  /////////////////////////////////////////////////////////
  //
  // Instantiate the TB and DUT
  //
  test #( .PDATA_SIZE ( PDATA_SIZE ))
  tb ( .* );


  apb_gpio #( .PDATA_SIZE ( PDATA_SIZE ))
  dut ( .* );
 
endmodule : testbench_top
