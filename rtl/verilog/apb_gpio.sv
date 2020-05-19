/////////////////////////////////////////////////////////////////////
//   ,------.                    ,--.                ,--.          //
//   |  .--. ' ,---.  ,--,--.    |  |    ,---. ,---. `--' ,---.    //
//   |  '--'.'| .-. |' ,-.  |    |  |   | .-. | .-. |,--.| .--'    //
//   |  |\  \ ' '-' '\ '-'  |    |  '--.' '-' ' '-' ||  |\ `--.    //
//   `--' '--' `---'  `--`--'    `-----' `---' `-   /`--' `---'    //
//                                             `---'               //
//    APB4 GPIO                                                    //
//                                                                 //
/////////////////////////////////////////////////////////////////////
//                                                                 //
//             Copyright (C) 2016-2018 ROA Logic BV                //
//             www.roalogic.com                                    //
//                                                                 //
//     Unless specifically agreed in writing, this software is     //
//   licensed under the RoaLogic Non-Commercial License            //
//   version-1.0 (the "License"), a copy of which is included      //
//   with this file or may be found on the RoaLogic website        //
//   http://www.roalogic.com. You may not use the file except      //
//   in compliance with the License.                               //
//                                                                 //
//     THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY           //
//   EXPRESS OF IMPLIED WARRANTIES OF ANY KIND.                    //
//   See the License for permissions and limitations under the     //
//   License.                                                      //
//                                                                 //
/////////////////////////////////////////////////////////////////////

// +FHDR -  Semiconductor Reuse Standard File Header Section  -------
// FILE NAME      : apb_gpio.sv
// DEPARTMENT     :
// AUTHOR         : rherveille
// AUTHOR'S EMAIL :
// ------------------------------------------------------------------
// RELEASE HISTORY
// VERSION DATE        AUTHOR      DESCRIPTION
// 1.0     2017-03-29  rherveille  initial release
// ------------------------------------------------------------------
// KEYWORDS : AMBA APB4 General Purpose IO GPIO     
// ------------------------------------------------------------------
// PURPOSE  : General purpose IO          
// ------------------------------------------------------------------
// PARAMETERS
//  PARAM NAME        RANGE    DESCRIPTION              DEFAULT UNITS
//  PDATA_SIZE        1+       Databus (and GPIO) size  8       bits
// ------------------------------------------------------------------
// REUSE ISSUES 
//   Reset Strategy      : external asynchronous active low; PRESETn
//   Clock Domains       : PCLK, rising edge
//   Critical Timing     : 
//   Test Features       : na
//   Asynchronous I/F    : no
//   Scan Methodology    : na
//   Instantiations      : na
//   Synthesizable (y/n) : Yes
//   Other               :                                         
// -FHDR-------------------------------------------------------------


/*
 * address  description         comment
 * ------------------------------------------------------------------
 * 0x0      mode register       0=push-pull
 *                              1=open-drain
 * 0x1      direction register  0=input
 *                              1=output
 * 0x2      output register     mode-register=0? 0=drive pad low
 *                                               1=drive pad high
 *                              mode-register=1? 0=drive pad low
 *                                               1=open-drain
 * 0x3      input register      returns data at pad
 * 0x4      trigger type        0=level
 *                              1=edge
 * 0x5      trigger level/edge0 trigger-type=0? 0=no trigger when low
 *                                              1=trigger when low
 *                              trigger-type=1? 0=no trigger on falling edge
 *                                              1=trigger on falling edge
 * 0x6      trigger level/edge1 trigger-type=0? 0=no trigger when high
 *                                              1=trigger when high
 *                              trigger-type=1? 0=no trigger on rising edge
 *                                              1=trigger on rising edge
 * 0x7      trigger status      0=no trigger detected/irq pending
                                1=trigger detected/irq pending
 * 0x8      irq enable          0=disable irq generation
 *                              1=enable irq generation
 */

module apb_gpio #(
  PDATA_SIZE = 8  //must be a multiple of 8
)
(
  input                         PRESETn,
                                PCLK,
  input                         PSEL,
  input                         PENABLE,
  input      [             3:0] PADDR,
  input                         PWRITE,
  input      [PDATA_SIZE/8-1:0] PSTRB,
  input      [PDATA_SIZE  -1:0] PWDATA,
  output reg [PDATA_SIZE  -1:0] PRDATA,
  output                        PREADY,
  output                        PSLVERR,

  output reg                    irq_o,

  input      [PDATA_SIZE  -1:0] gpio_i,
  output reg [PDATA_SIZE  -1:0] gpio_o,
                                gpio_oe
);
  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam PADDR_SIZE = $bits(PADDR);


  localparam MODE      = 0,
             DIRECTION = 1,
             OUTPUT    = 2,
             INPUT     = 3,
             TR_TYPE   = 4,
             TR_LVL0   = 5,
             TR_LVL1   = 6,
             TR_STAT   = 7,
             IRQ_ENA   = 8;

  //number of synchronisation flipflop stages on GPIO inputs
  localparam INPUT_STAGES = 3;


  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  //Control registers
  logic [PDATA_SIZE-1:0] mode_reg,
                         dir_reg,
                         out_reg,
                         in_reg,
                         tr_type_reg,
                         tr_lvl0_reg,
                         tr_lvl1_reg,
                         tr_stat_reg,
                         irq_ena_reg;

  //Trigger registers
  logic [PDATA_SIZE-1:0] tr_in_dly_reg,
                         tr_rising_edge_reg,
                         tr_falling_edge_reg,
                         tr_status;


  //Input register, to prevent metastability
  logic [PDATA_SIZE-1:0] input_regs [INPUT_STAGES];

  integer n;


  //////////////////////////////////////////////////////////////////
  //
  // Functions
  //

  //Is this a valid read access?
  function automatic is_read();
    return PSEL & PENABLE & ~PWRITE;
  endfunction : is_read

  //Is this a valid write access?
  function automatic is_write();
    return PSEL & PENABLE & PWRITE;
  endfunction : is_write

  //Is this a valid write to address 0x...?
  //Take 'address' as an argument
  function automatic is_write_to_adr(input [PADDR_SIZE-1:0] address);
    return is_write() & (PADDR == address);
  endfunction : is_write_to_adr

  //What data is written?
  //- Handles PSTRB, takes previous register/data value as an argument
  function automatic [PDATA_SIZE-1:0] get_write_value (input [PDATA_SIZE-1:0] orig_val);
    for (int n=0; n < PDATA_SIZE/8; n++)
       get_write_value[n*8 +: 8] = PSTRB[n] ? PWDATA[n*8 +: 8] : orig_val[n*8 +: 8];
  endfunction : get_write_value

  //Clear bits on write
  //- Handles PSTRB
  function automatic [PDATA_SIZE-1:0] get_clearonwrite_value (input [PDATA_SIZE-1:0] orig_val);
    for (int n=0; n < PDATA_SIZE/8; n++)
       get_clearonwrite_value[n*8 +: 8] = PSTRB[n] ? orig_val[n*8 +: 8] & ~PWDATA[n*8 +: 8] : orig_val[n*8 +: 8];
  endfunction : get_clearonwrite_value


  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  /*
   * APB accesses
   */
  //The core supports zero-wait state accesses on all transfers.
  //It is allowed to drive PREADY with a hard wired signal
  assign PREADY  = 1'b1; //always ready
  assign PSLVERR = 1'b0; //Never an error


  /*
   * APB Writes
   */
  //APB write to Mode register
  always @(posedge PCLK,negedge PRESETn)
    if      (!PRESETn              ) mode_reg <= {PDATA_SIZE{1'b0}};
    else if ( is_write_to_adr(MODE)) mode_reg <= get_write_value(mode_reg);


  //APB write to Direction register
  always @(posedge PCLK,negedge PRESETn)
    if      (!PRESETn                   ) dir_reg <= {PDATA_SIZE{1'b0}};
    else if ( is_write_to_adr(DIRECTION)) dir_reg <= get_write_value(dir_reg);


  //APB write to Output register
  //treat writes to Input register same
  always @(posedge PCLK,negedge PRESETn)
    if      (!PRESETn                  ) out_reg <= {PDATA_SIZE{1'b0}};
    else if ( is_write_to_adr(OUTPUT) ||
              is_write_to_adr(INPUT )  ) out_reg <= get_write_value(out_reg);


  //APB write to Trigger Type register
  always @(posedge PCLK,negedge PRESETn)
    if      (!PRESETn                 ) tr_type_reg <= {PDATA_SIZE{1'b0}};
    else if ( is_write_to_adr(TR_TYPE)) tr_type_reg <= get_write_value(tr_type_reg);


  //APB write to Trigger Level/Edge0 register
  always @(posedge PCLK,negedge PRESETn)
    if      (!PRESETn                 ) tr_lvl0_reg <= {PDATA_SIZE{1'b0}};
    else if ( is_write_to_adr(TR_LVL0)) tr_lvl0_reg <= get_write_value(tr_lvl0_reg);


  //APB write to Trigger Level/Edge1 register
  always @(posedge PCLK,negedge PRESETn)
    if      (!PRESETn                 ) tr_lvl1_reg <= {PDATA_SIZE{1'b0}};
    else if ( is_write_to_adr(TR_LVL1)) tr_lvl1_reg <= get_write_value(tr_lvl1_reg);


  //APB write to Trigger Status register
  //Writing a '1' clears the status register
  always @(posedge PCLK,negedge PRESETn)
    if      (!PRESETn                 ) tr_stat_reg <= {PDATA_SIZE{1'b0}};
    else if ( is_write_to_adr(TR_STAT)) tr_stat_reg <= get_clearonwrite_value(tr_stat_reg) | tr_status;
    else                                tr_stat_reg <= tr_stat_reg | tr_status;


  //APB write to Interrupt Enable register
  always @(posedge PCLK,negedge PRESETn)
    if      (!PRESETn                 ) irq_ena_reg <= {PDATA_SIZE{1'b0}};
    else if ( is_write_to_adr(IRQ_ENA)) irq_ena_reg <= get_write_value(irq_ena_reg);


  /*
   * APB Reads
   */
  always @(posedge PCLK)
    case (PADDR)
      MODE     : PRDATA <= mode_reg;
      DIRECTION: PRDATA <= dir_reg;
      OUTPUT   : PRDATA <= out_reg;
      INPUT    : PRDATA <= in_reg;
      TR_TYPE  : PRDATA <= tr_type_reg;
      TR_LVL0  : PRDATA <= tr_lvl0_reg;
      TR_LVL1  : PRDATA <= tr_lvl1_reg;
      TR_STAT  : PRDATA <= tr_stat_reg;
      IRQ_ENA  : PRDATA <= irq_ena_reg;
      default  : PRDATA <= {PDATA_SIZE{1'b0}};
    endcase


  /*
   * Internals
   */
  always @(posedge PCLK)
    for (n=0; n<INPUT_STAGES; n++)
       if (n==0) input_regs[n] <= gpio_i;
       else      input_regs[n] <= input_regs[n-1];

  always @(posedge PCLK)
    in_reg <= input_regs[INPUT_STAGES-1];


  // mode
  // 0=push-pull    drive out_reg value onto transmitter input
  // 1=open-drain   always drive '0' onto transmitter
  always @(posedge PCLK)
    for (n=0; n<PDATA_SIZE; n++)
      gpio_o[n] <= mode_reg[n] ? 1'b0 : out_reg[n];


  // direction  mode          out_reg
  // 0=input                           disable transmitter-enable (output enable)
  // 1=output   0=push-pull            always enable transmitter
  //            1=open-drain  1=Hi-Z   disable transmitter
  //                          0=low    enable transmitter
  always @(posedge PCLK)
    for (n=0; n<PDATA_SIZE; n++)
      gpio_oe[n] <= dir_reg[n] & ~(mode_reg[n] ? out_reg[n] : 1'b0);


  /*
   * Triggers
   */

  //delay input register
  always @(posedge PCLK)
    tr_in_dly_reg <= in_reg;


  //detect rising edge
  always @(posedge PCLK, negedge PRESETn)
    if (!PRESETn) tr_rising_edge_reg <= {PDATA_SIZE{1'b0}};
    else          tr_rising_edge_reg <= in_reg & ~tr_in_dly_reg;


  //detect falling edge
  always @(posedge PCLK, negedge PRESETn)
    if (!PRESETn) tr_falling_edge_reg <= {PDATA_SIZE{1'b0}};
    else          tr_falling_edge_reg <= tr_in_dly_reg & ~in_reg;


  //trigger status
  always_comb
    for (n=0; n<PDATA_SIZE; n++)
      case (tr_type_reg[n])
        0: tr_status = (tr_lvl0_reg[n] & ~in_reg[n]) |
                       (tr_lvl1_reg[n] &  in_reg[n]);
        1: tr_status = (tr_lvl0_reg[n] & tr_falling_edge_reg[n]) |
                       (tr_lvl1_reg[n] & tr_rising_edge_reg [n]);
      endcase


  /*
   * Interrupt
   */
  always @(posedge PCLK, negedge PRESETn)
    if (!PRESETn) irq_o <= 1'b0;
    else          irq_o <= |(irq_ena_reg & tr_stat_reg);
endmodule
