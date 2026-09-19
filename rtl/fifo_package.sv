/* *****************************************************************************
   * title:         uart_16550_rll module                                      *
   * description:   RS232 Protocol 16550D uart (mostly supported)              *
   * languages:     systemVerilog                                              *
   *                                                                           *
   * Copyright (C) 2010, 2026 RedLeafLogic Co., Ltd                                  *
   *                                                                           *
   * Licensed under the Apache License, Version 2.0 (the "License");
   * you may not use this file except in compliance with the License.
   * You may obtain a copy of the License at
   *
   *     https://www.apache.org/licenses/LICENSE-2.0
   *
   * Unless required by applicable law or agreed to in writing, software
   * distributed under the License is distributed on an "AS IS" BASIS,
   * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   * See the License for the specific language governing permissions and
   * limitations under the License.
   * SPDX-License-Identifier: Apache-2.0
   *****************************************************************************
   *                            RedLeafLogic Co., Ltd                          *
   ***************************************************************************** */

package fifo_package ;
`ifdef SYN
 /* empty */
`else
   timeunit      1ps ;
   timeprecision 1ps ;
`endif
   // -- read for manual -> 4.4 FIFO Control Register (FCR)
   // -- almost trgger level --
   localparam LEVEL_1 = 5'h1 ;
   localparam LEVEL_2 = 5'h4 ;
   localparam LEVEL_3 = 5'h8 ;
   localparam LEVEL_4 = 5'hE ;
   
   typedef struct packed{ 
 //                    logic [10:0] mem [0:15] ;
 //                    logic [0:0]  err [0:15] ;
                     logic [3:0]  write_pointer ;
                     logic [3:0]  read_pointer ;
//                     logic        full ;
//                     logic        almost_full ;
//                     logic        empty ;
                     } u_fifo_t ;

endpackage : fifo_package
