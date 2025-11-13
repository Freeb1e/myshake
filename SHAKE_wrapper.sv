module SHAKE_wrapper(
        input logic         clk,
        input logic         rst_n,
        input logic [31:0]  seed_buffer,
        input logic [7:0]   absorb_num,        //一共需要吸收的块的数量
        input logic [7:0]   last_block_bytes,  //最后一块数据的字节数
        input logic         init,
        input logic         mode,              // 0 for SHAKE128, 1 for SHAKE256

        output logic [31:0] dout,
        output logic [31:0] addr_seed,
        output logic        ready,
        output logic        valid
    );
    // Internal signals
    logic        nreset;
    logic        wr_keccak;
    logic [6:0]  addr_keccak;
    logic [31:0] din_keccak;
    logic [31:0] dout_keccak;
    logic        init_keccak;
    logic        next_keccak;
    logic        ready_keccak;

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
                if (last_block_bytes == 0)
                    next_state = DONE;
                else
                    next_state = SQUEEZE;
            end
            DONE: begin
                next_state = IDLE;
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
            end else begin
                if(ready_keccak && state == ABSORB) begin
                    if(cnt_once < ABSORB_CNT_ONCE && !init_keccak) begin
                        cnt_once<=cnt_once+8'b1;
                        wr_keccak<=1'b1;
                    end else begin
                        if(cnt_total<absorb_num)begin
                            cnt_total<=cnt_total+8'b1;
                            cnt_once<=8'b0;
                            wr_keccak<=1'b0;
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
            next_keccak<=1'b0;
        end else begin
            if(cnt_once==ABSORB_CNT_ONCE && cnt_total != absorb_num)begin
                init_keccak<=1'b1;
            end else begin
                init_keccak<=1'b0;
            end
        end
    end

    sha3 u_sha3(
             .clk    	(clk     ),
             .nreset 	(nreset  ),
             .w      	(wr_keccak ),
             .addr   	(addr_keccak    ),
             .din    	(din_keccak     ),
             .dout   	(dout_keccak    ),
             .init   	(init_keccak    ),
             .next   	(next_keccak    ),
             .ready  	(ready_keccak   )
         );

endmodule


