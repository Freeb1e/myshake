module SHAKE_wrapper(
        input logic         clk,
        input logic         rst_n,
        input logic [31:0]  seed_buffer,
        input logic [7:0]   absorb_num,        //一共需要吸收的块的数量
        input logic [7:0]   last_block_bytes,  //最后一块数据的字节数
        input logic         init,
        input logic         mode,              // 0 for SHAKE128, 1 for SHAKE256

        output logic [31:0] dout,
        output logic [31:0] addr_perip,
        output logic        ready,
        output logic        valid,

        input logic [9:0]  squeeze_num         //一共需要挤出的块的数量   
    );
    // Internal signals
    logic        nreset;
    logic        wr_keccak;
    logic [6:0]  addr_keccak;
    logic [31:0] din_keccak;
    logic [31:0] dout_keccak;
    logic        init_keccak;
    logic        next_keccak_absorb,next_keccak_squeeze;
    logic        ready_keccak;

    logic [31:0] addr_seed,addr_storage;
    logic [7:0]  addr_squeeze;
    assign addr_perip = (state==ABSORB)? addr_seed : addr_storage;
    assign nreset = rst_n;
    // State machine states
    logic [2:0] state, next_state,last_state;
    localparam IDLE        = 3'd0,
               ABSORB      = 3'd1,
               SQUEEZE     = 3'd2,
               DONE        = 3'd3;
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            last_state <= IDLE;
        end else begin
            state <= next_state;
            last_state <= state;
        end
            
    end
    // Next state logic
    always_comb begin
        case(state)
            IDLE: begin
                if (init)
                    next_state = ABSORB;
                else
                    next_state = IDLE;
            end
            ABSORB: begin
                if (absorb_done)
                    next_state = SQUEEZE;
                else
                    next_state = ABSORB;
            end
            SQUEEZE: begin
                if (squeeze_done == 1'b1)
                    next_state = IDLE;
                else
                    next_state = SQUEEZE;
            end
            default: next_state = IDLE;
        endcase
    end
    // Control signals and data path
    logic absorb_done;
    logic [7:0] cnt_total,cnt_once;
    logic [7:0] ABSORB_CNT_ONCE = mode ? 8'd34 : 8'd42;

    always_ff@(posedge clk or negedge rst_n) begin:counter
        if(!rst_n)begin
            cnt_once<=8'b0;
            cnt_total<=8'b0;
        end else begin
            if(next_state==ABSORB && state!=ABSORB)begin
                cnt_once<=8'b0;
                cnt_total<=8'b0;
                addr_seed<=32'b0;
            end else begin
                if(ready_keccak && state == ABSORB) begin
                    if(cnt_once < ABSORB_CNT_ONCE && !init_keccak && !next_keccak_absorb) begin
                        cnt_once<=cnt_once+8'b1;
                        addr_seed<=addr_seed+32'd4;//取地址和wr同时拉高，保证同步写入的时序差一个周期
                        wr_keccak<=1'b1;
                    end else begin
                        if(cnt_total<absorb_num)begin
                            if(cnt_once!=8'd0)begin
                                cnt_total<=cnt_total+8'b1;
                                cnt_once<=8'b0;
                                wr_keccak<=1'b0;
                                if(cnt_once < ABSORB_CNT_ONCE)begin
                                    addr_seed<=addr_seed+32'd4;
                                end
                            end
                        end else begin
                            absorb_done<=1'b1;
                            wr_keccak<=1'b0;
                        end
                        end
                end
            end
        end
    end

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            init_keccak<=1'b0;
            next_keccak_absorb<=1'b0;
        end else begin
            if(cnt_once==ABSORB_CNT_ONCE && cnt_total == 8'd0)begin
                init_keccak<=1'b1;
            end else begin
                init_keccak<=1'b0;
            end

            if(cnt_once==ABSORB_CNT_ONCE && cnt_total < absorb_num && cnt_total!=8'd0)begin
                next_keccak_absorb<=1'b1;
            end else begin
                next_keccak_absorb<=1'b0;
            end

        end
    end

    logic [31:0] padding_typeA, padding_mask, padding_typeB;
    logic [7:0] temp_cnt = {2'b00,last_block_bytes[7:2]}+8'd1;

    always_comb begin:din_logic
        //padding_type_A
        if(cnt_once < temp_cnt)begin
            padding_typeA = seed_buffer;
        end else if (cnt_once == temp_cnt) begin
            case(last_block_bytes[1:0])
                    2'b00:padding_typeA = 32'h0000001F;
                    2'b11:padding_typeA ={8'h1F,seed_buffer[23:0]};
                    2'b10:padding_typeA ={16'h001F,seed_buffer[15:0]};
                    2'b01:padding_typeA ={24'h00001F,seed_buffer[7:0]};
                    default:padding_typeA = 32'd0;
            endcase
        end else begin
            padding_typeA = 32'd0;
        end
        //padding_mask
        if(cnt_once == ABSORB_CNT_ONCE && last_block_bytes!=8'd0) begin
            padding_mask = 32'h80000000;
        end else begin
            padding_mask = 32'd0;
        end
        //padding_type_B:空白块填充
        if(cnt_once == 8'd1) begin
            padding_typeB = 32'h0000001F;
        end else if(cnt_once == ABSORB_CNT_ONCE) begin
            padding_typeB = 32'h80000000;
        end else begin
            padding_typeB = 32'd0;
        end

        if(cnt_total != absorb_num-1)begin
            din_keccak = seed_buffer;
        end else begin
            if(last_block_bytes!=8'd0)
            begin
                din_keccak = padding_typeA | padding_mask;
            end else begin
                din_keccak = padding_typeB ;
            end
            
        end
    end
    logic [9:0] squeeze_cnt;
    logic squeeze_done;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            addr_storage<=32'b0;
            addr_squeeze<=8'b0;
            squeeze_cnt<=10'b0;
        end begin
            if(absorb_done && state == ABSORB)begin
                addr_storage<=32'b0;
                addr_squeeze<=8'b0;
                squeeze_cnt<=10'b0;
            end else if(squeeze_cnt < squeeze_num && state == SQUEEZE && ready_keccak ) begin
                if(addr_squeeze < ABSORB_CNT_ONCE-1 ) begin
                    if(!next_keccak_squeeze) begin
                         addr_storage<=addr_storage+32'd4;
                         addr_squeeze<=addr_squeeze+8'd1;
                    end
                    next_keccak_squeeze<=1'b0;
                end else begin
                    if(squeeze_cnt == squeeze_num - 1) begin
                        squeeze_done<=1'b1;
                    end else begin
                        addr_storage<=addr_storage;
                        addr_squeeze<=8'b0;
                        next_keccak_squeeze<=1'b1;
                        squeeze_cnt<=squeeze_cnt+10'b1;
                    end
                end
            end 
        end
    end
    assign valid = (state == SQUEEZE && ready_keccak && !next_keccak_squeeze) ? 1'b1 : 1'b0;
    // Instantiate Keccak module
    assign addr_keccak = (state == ABSORB)? addr_keccak_absorb:{1'b1,addr_squeeze[5:0]};
    logic [6:0] addr_keccak_absorb;
    assign addr_keccak_absorb = cnt_once[6:0] - 7'd1;
    assign dout = dout_keccak;
    sha3 u_sha3(
             .clk    	(clk     ),
             .nreset 	(nreset  ),
             .w      	(wr_keccak ),
             .addr   	(addr_keccak    ),
             .din    	(din_keccak     ),
             .dout   	(dout_keccak    ),
             .init   	(init_keccak    ),
             .next   	(next_keccak_absorb      ),
             .squeeze    (next_keccak_squeeze   ),
             .ready  	(ready_keccak   )
         );

endmodule


