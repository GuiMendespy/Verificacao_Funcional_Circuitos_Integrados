module controladora #( parameter DEBOUNCE_P = 300,
		parameter SWITCH_MODE_MIN_T = 5300,
		parameter AUTO_SHUTDOWN_T = 30000) (
		input wire clk, rst,
		input logic infravermelho,
		push_button,
		output logic led, saida );
		

	wire A,B,C;
	submodulo_3  #(
	.AUTO_SHUTDOWN_T(AUTO_SHUTDOWN_T))
	sub_3 (.clk(clk), .rst(rst),
	.infravermelho(infravermelho),
	.C(C));

	submodulo_2 #(
	.DEBOUNCE_P(DEBOUNCE_P),
	.SWITCH_MODE_MIN_T(SWITCH_MODE_MIN_T))
	sub_2 (.clk(clk), .rst(rst),
	.push_button(push_button),
	.A(A), .B(B));

	submodulo_1 sub_1 (.clk(clk), .rst(rst),
	.a(A), .b(B), .c(C), .d(infravermelho),
	.led(led), .saida(saida));
		
endmodule



// **********************


module submodulo_1(
input logic clk, rst,
a, b, c, d,
output logic led, saida);

    typedef enum logic [1:0] { 
        LAMP_LIG_AUTO,
        LAMP_DES_AUTO,
        LAMP_LIG_MAN,
        LAMP_DES_MAN
    } stateMachine_e;

    stateMachine_e state, next_state;

    always_ff @(posedge clk or posedge rst) begin
       if(rst)begin
        state <= LAMP_DES_AUTO;
       end
       else begin
        state <= next_state;
       end
    end

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            next_state <= LAMP_DES_AUTO;
        end
        else begin
            case (state)
                LAMP_LIG_AUTO: begin
                    if(a) begin
                        next_state <= LAMP_DES_MAN;
                    end
                    else if(c) begin
                        next_state <= LAMP_DES_AUTO;
                    end
                    else if(d)begin
                        next_state <= LAMP_LIG_AUTO;
                    end
                    else begin
                        next_state <= next_state;
                    end
                end

                LAMP_DES_AUTO:begin
                    if(a)begin
                        next_state <= LAMP_DES_MAN;
                    end
                    else if(d) begin
                        next_state <= LAMP_LIG_AUTO;
                    end
                    else begin
                        next_state <= next_state; 
                    end
                end

                LAMP_LIG_MAN:begin
                    if(a) begin
                      next_state <= LAMP_LIG_AUTO;  
                    end
                    else if(b)begin
                        next_state <= LAMP_DES_MAN;
                    end
                    else begin
                        next_state <= next_state;
                    end
                end

                LAMP_DES_MAN:begin
                    if(a) begin
                        next_state <= LAMP_LIG_AUTO;  
                    end
                    else if(b) begin
                        next_state <= LAMP_LIG_MAN;
                    end
                    else begin
                        next_state <= next_state;
                    end
                end
            endcase
        end
    end

    always_comb begin 
        if(rst)begin
            led = 0;
            saida = 0;
        end
        else begin
            case (next_state)
                LAMP_LIG_AUTO:begin
                    saida = 1;
                    led = 0;
                end 
                LAMP_DES_AUTO:begin
                    saida = 0;
                    led = 0;
                end
                LAMP_LIG_MAN:begin
                    saida = 1;
                    led = 1;
                end
                LAMP_DES_MAN:begin
                    saida = 0;
                    led = 1;
                end
            endcase
        end
    end
endmodule

//*********************



module submodulo_2 #(
	parameter DEBOUNCE_P = 300,
	parameter SWITCH_MODE_MIN_T = 5300)

	( input logic clk, rst,
	push_button,
	output logic A, B);

    typedef enum logic[2:0] { 
        INITIAL,
        DEBOUNCE,
        STATE_B,
        STATE_A,
        TEMP
    } stateMachine_e;


    stateMachine_e state, next_state;
    int tp;

    //atualiza estado atual com proximo estado
    always_ff @(posedge clk or posedge rst)begin
		if(rst) begin
			state <= INITIAL;
		end
		else begin
        state <= next_state;
	  end
    end

    //define o proximo estado de acordo com as condições atuais.
    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            next_state <= INITIAL;
            tp <= 0;
        end
        else begin
            case (state)

                INITIAL:begin
                    if (push_button) begin
                        next_state <= DEBOUNCE;
                    end
                    else begin
                        tp <= 0;
                        next_state <= INITIAL;
                    end
                end

                DEBOUNCE:begin
                    if (!push_button) begin
                        next_state <= INITIAL;
                        tp <= 0;
                    end
                    else if (tp < DEBOUNCE_P) begin
                        tp ++;
                        next_state <= DEBOUNCE;
                    end 
                    else begin
                        next_state <= STATE_B; 
                    end
                end

                STATE_B:begin
                    if(!push_button) begin
                        next_state <= TEMP;
                        tp <= 0;
                    end
                    else if(tp >= SWITCH_MODE_MIN_T) begin
                        next_state <= STATE_A;
                    end
                    else begin
                        tp ++;
                        next_state <= STATE_B;
                    end
                end

                STATE_A:begin
                    if (!push_button) begin
                        next_state <= TEMP;
                        tp <= 0;
                    end
                    else begin
                       tp ++;
                       next_state <= STATE_A; 
                    end
                end

                TEMP:begin
                    next_state <= INITIAL;
                end
                default: begin
                    $display($time,"entrou no default");
                    next_state <= INITIAL; //volta pro inicio em caso de ambiguidade
                end
           endcase; 
        end 
    end

	logic reg_a, reg_b;
    //gera um registro dos valores anteriores de A e de B
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_a <= 0;
            reg_b <= 0;
        end
        else begin
            case (next_state)
                INITIAL: begin
                    if (state == TEMP) begin
                        // mantém reg_a/reg_b
                        reg_a <= reg_a;
                        reg_b <= reg_b;
                    end
                    else begin
                        reg_a <= 0;
                        reg_b <= 0;
                    end
                end

                TEMP: begin
                    if (state == STATE_B) begin
                        reg_b <= 1;
                        reg_a <= 0;
                    end
                    else if (state == STATE_A) begin
                        reg_a <= 1;
                        reg_b <= 0;
                    end
                    else begin
                        reg_a <= reg_a;
                        reg_b <= reg_b;
                    end
                end

                default: begin
                    reg_a <= 0;
                    reg_b <= 0;
                end
            endcase
        end
    end

    //gera as saidas A e B de acordo com o estado
    always_comb begin
        if (rst) begin
            A = 0;
            B = 0;
        end
        else begin
            case (next_state)

                INITIAL: begin
                    if (state == TEMP) begin
                        A = reg_a;
                        B = reg_b;
                    end
                    else begin
                        A = 0;
                        B = 0;
                    end
                end
                TEMP: begin
                    if (state == STATE_B) begin
                        B = 1;
                        A = 0;
                    end
                    else if (state == STATE_A) begin
                        A = 1;
                        B = 0;                        
                    end begin
                        A = 0;
                        B = 0;
                    end
                    
                end
                default: begin
                    A = 0;
                    B = 0;
                end
           endcase
        end
    end

endmodule: submodulo_2




  
  //*****************

module submodulo_3  #(
parameter AUTO_SHUTDOWN_T = 30000)

(input logic clk, rst,
infravermelho,
output logic C);

    // maximo de estado = 4;
    typedef enum logic [1:0] { 
        INITIAL,
        CONTANDO,
        TEMP
    } maquinaEstado_e;

    maquinaEstado_e state, next_state;
    int tc;

    //atualiza o estado atual  com o proximo estado.
    always_ff @( posedge clk or posedge rst) begin
        if(rst) begin
            state <= INITIAL;
        end
        else begin
            state <= next_state;
        end
    end

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            next_state <= INITIAL;
            tc <= 0;
        end
        else begin
            case (state)
                INITIAL:begin
                    if(!infravermelho)begin
                        next_state <= CONTANDO;
                    end
                    else begin
                        next_state <= next_state;
                        tc <= 0;
                    end
                end 

                CONTANDO: begin
                    //se infra esta em 1, contador < AUTO_SHUTDOWN_T, contador == AUTO_SHUT_DOWN_T 
                    if (infravermelho) begin
                        next_state <= INITIAL;
                        tc <= 0;
                    end
                    else if (tc < AUTO_SHUTDOWN_T)begin
                        next_state <= next_state;
                        tc++;
                    end
                    else begin
                        next_state <= TEMP;
                        tc <= 0;
                    end
                end

                TEMP: begin
                    next_state <= INITIAL;
                end
                default: begin
                    next_state <= INITIAL;
                end
            endcase
        end
    end

    always_comb begin
        if(rst)begin
            C = 0;
        end
        else begin
            case (next_state)
                INITIAL: begin
                    if(state == TEMP)begin
                        C = 1;
                    end
                    else begin
                        C = 0;
                    end
                end 

                TEMP: begin
                   C = 1;
                end

                default:begin
                    C = 0;
                end 
            endcase
        end
    end

endmodule : submodulo_3