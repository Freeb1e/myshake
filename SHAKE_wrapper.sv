module SHAKE_wrapper(
    input        clk,
    input        rst_n,
    input [31:0] seed_buffer,
    //input        seed_valid,
    input [7:0]  absorb_num,//一共需要吸收的块的数量
    input [5:0]  last_block_bytes,//最后一块数据的字节数
    input        init,
    input        mode, // 0 for SHAKE128, 1 for SHAKE256
    output [31:0] dout,
    output logic [31:0] addr_seed,
    output       ready,
    output       valid 
    );
    logic [2:0] state,next_state;
    logic nreset;
    logic [5:0] cnt_absorb_once;
    logic [7:0] cnt_absorb_total;
    logic PADDING_FLAG1,PADDING_FLAG2,PADDING_FLAG3;
    logic wr_keccak;
    logic absorb_done;
    logic [31:0] din;
    logic [6:0] addr_keccak;
    logic [7:0] ABSORB_TOTAL_CNT;
    logic [5:0] ABSORB_ONCE_CNT;
    assign ABSORB_TOTAL_CNT = absorb_num;
    assign ABSORB_ONCE_CNT = (mode==1'b0)?6'd42:6'd34;
    // FSM ctrl
    parameter IDLE = 3'b000,
               INIT = 3'b001,
               ABSORB = 3'b010,
               SQUEEZING = 3'b011;

    parameter SHAKE128_CNT=6'd42,
               SHAKE256_CNT=6'd34;

    always_comb begin
        case(state)
            IDLE: begin
                if(init) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
                next_state = ABSORB;
            end
            ABSORB: begin
                if(absorb_done) next_state = SQUEEZING;
                else next_state = ABSORB;
            end
            default: next_state = IDLE;
        endcase
    end

    always_ff@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state <= 3'b0;
        end
        else begin
            state<=next_state;
        end
    end



    always_ff @(posedge clk or negedge rst_n) begin:counter_of_absorbing
        if(!rst_n) begin
            cnt_absorb_once <= 6'd0;
            cnt_absorb_total <= 8'd0;
            absorb_done <= 1'b0;
        end
        else begin
            if(next_state==ABSORB && state==INIT)begin
                cnt_absorb_once <= 6'd0;
                cnt_absorb_total <= 8'd0;
                absorb_done <= 1'b0;
                PADDING_FLAG1 <= 1'b0;
            end else if(state==ABSORB)begin
                if(cnt_absorb_once < ABSORB_ONCE_CNT - 1) begin
                    cnt_absorb_once <= cnt_absorb_once + 6'd1;
                    if(PADDING_FLAG1==1'b1 && cnt_absorb_once == {last_block_bytes[5:2],2'b00}) begin
                        PADDING_FLAG2 <= 1'b1;
                    end
                end
                else begin
                    cnt_absorb_once <= 6'd0;
                    if(cnt_absorb_total < ABSORB_TOTAL_CNT - 1)begin
                        cnt_absorb_total <= cnt_absorb_total + 8'd1;
                        if(cnt_absorb_total == absorb_num - 1) begin
                            PADDING_FLAG1 <= 1'b1;
                        end
                    end
                    else begin 
                        cnt_absorb_total <= cnt_absorb_total;
                        absorb_done <= 1'b1;
                    end
                end
            end
        end
        end

    always_ff @(posedge clk or negedge rst_n) begin:absorb_addr
        if(!rst_n) begin
            addr_seed <= 32'd0;
            wr_keccak <= 1'b0;
            addr_keccak <= 7'd0;
        end
        else begin
            if(state!=ABSORB) begin
                addr_seed <= 32'd0;
                wr_keccak <= 1'b0;
                addr_keccak <= 7'd0;
            end
            else begin
                addr_seed <= addr_seed + 32'd4;
                wr_keccak <= 1'b1;
                addr_keccak <= addr_keccak + 7'd4;
            end
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            din <= 32'd0;
            PADDING_FLAG3 <= 1'b0;
        end
        else begin
            if(state==ABSORB) begin
                if(!PADDING_FLAG1 && !PADDING_FLAG2) begin
                    din <= seed_buffer;
                end
                else if(PADDING_FLAG2) begin
                    case(last_block_bytes[1:0])
                        2'b00: din <= 32'h0000001F;
                        2'b11: din <={8'h1F,seed_buffer[23:0]};
                        2'b10: din <={16'h001F,seed_buffer[15:0]};
                        2'b01: din <={24'h00001F,seed_buffer[7:0]};
                        default: din <= 32'd0;
                    endcase
                    PADDING_FLAG3 <= 1'b1;
                end
                else begin
                    if(PADDING_FLAG3)begin
                        if(cnt_absorb_once == ABSORB_ONCE_CNT - 1)
                        din<=32'h0000009F;
                        else
                        din<=32'h00000000;
                    end else din<=seed_buffer;
                end
            end
            else begin
                
            end
        end
    end

// nreset control
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            nreset <= 1'b0;
        end
        else begin
            if(state==INIT)begin
                nreset <= 1'b0;
            end
            else begin
                nreset <= 1'b1;
            end
        end
    end

// interface with sha3
logic init_keccak,next;
        sha3 u_sha3(
             .clk    	(clk     ),
             .nreset 	(nreset  ),
             .w      	(wr_keccak ),
             .addr   	(addr_keccak    ),
             .din    	(din     ),
             .dout   	(dout    ),
             .init   	(init_keccak    ),
             .next   	(next    ),
             .ready  	(ready   )
         );
endmodule
