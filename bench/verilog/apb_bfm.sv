/////////////////////////////////////////////////////////////////////
//   ,------.                    ,--.                ,--.          //
//   |  .--. ' ,---.  ,--,--.    |  |    ,---. ,---. `--' ,---.    //
//   |  '--'.'| .-. |' ,-.  |    |  |   | .-. | .-. |,--.| .--'    //
//   |  |\  \ ' '-' '\ '-'  |    |  '--.' '-' ' '-' ||  |\ `--.    //
//   `--' '--' `---'  `--`--'    `-----' `---' `-   /`--' `---'    //
//                                             `---'               //
//   APB Master BFM                                                //
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

module apb_master_bfm #(
  parameter PADDR_SIZE = 16,
  parameter PDATA_SIZE = 32
)
(
  input                         PRESETn,
                                PCLK,

  //APB Master Interface
  output reg                    PSEL,
  output reg                    PENABLE,
  output reg [PADDR_SIZE  -1:0] PADDR,
  output reg [PDATA_SIZE/8-1:0] PSTRB,
  output reg [PDATA_SIZE  -1:0] PWDATA,
  input      [PDATA_SIZE  -1:0] PRDATA,
  output reg                    PWRITE,
  input                         PREADY,
  input                         PSLVERR
);

  always @(negedge PRESETn) reset();


  /////////////////////////////////////////////////////////
  //
  // Tasks
  //
  task automatic reset();
    //Reset AHB Bus
    PSEL      = 1'b0;
    PENABLE   = 1'b0;
    PADDR     = 'hx;
    PSTRB     = 'hx;
    PWDATA    = 'hx;
    PWRITE    = 'hx;

    @(posedge PRESETn);
  endtask


  task automatic write (
    input [PADDR_SIZE  -1:0] address,
    input [PDATA_SIZE/8-1:0] strb,
    input [PDATA_SIZE  -1:0] data
  );
    PSEL    = 1'b1;
    PADDR   = address;
    PSTRB   = strb;
    PWDATA  = data;
    PWRITE  = 1'b1;
    @(posedge PCLK);

    PENABLE = 1'b1;
    @(posedge PCLK);

    while (!PREADY) @(posedge PCLK);

    PSEL    = 1'b0;
    PADDR   = {PADDR_SIZE{1'bx}};
    PSTRB   = {PDATA_SIZE/8{1'bx}};
    PWDATA  = {PDATA_SIZE{1'bx}};
    PWRITE  = 1'bx;
    PENABLE = 1'b0;
  endtask


  task automatic read (
    input  [PADDR_SIZE -1:0] address,
    output [PDATA_SIZE -1:0] data
  );
    PSEL    = 1'b1;
    PADDR   = address;
    PSTRB   = {PDATA_SIZE/8{1'bx}};
    PWDATA  = {PDATA_SIZE{1'bx}};
    PWRITE  = 1'b0;
    @(posedge PCLK);

    PENABLE = 1'b1;
    @(posedge PCLK);

    while (!PREADY) @(posedge PCLK);

    data = PRDATA;

    PSEL    = 1'b0;
    PADDR   = {PADDR_SIZE{1'bx}};
    PWRITE  = 1'bx;
    PENABLE = 1'b0;
  endtask

endmodule : apb_master_bfm
