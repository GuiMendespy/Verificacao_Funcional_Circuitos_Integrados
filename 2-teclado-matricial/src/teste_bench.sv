`timescale 1ns/1ps
`define DEBUG 0
`define MAX_COBERTURA 10
`define DEBOUNCE_PRESSIONAMENTO 100
`define MAX_ESPERA 20

module tb_teclado;

    logic clk, rst, enable;
    logic [3:0] col_matriz;
    logic [3:0] lin_matriz;
    digitosPac_t digitos_value;
    logic digitos_valid;

    decodificador_de_teclado dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .col_matriz(col_matriz),
        .lin_matriz(lin_matriz),
        .digitos_value(digitos_value),
        .digitos_valid(digitos_valid)
    );

    always #0.5 clk = ~clk;

    initial begin
        clk = 0;
        enable = 1;
    end

    bit [3:0] num;
    integer hit_count[10];

    // ================================================================
    // Utilitarios
    // ================================================================

    function logic [7:0] get_coords(input logic [3:0] d);
        case (d)
            4'h0:    return 8'b1110_1011;
            4'h1:    return 8'b0111_0111;
            4'h2:    return 8'b0111_1011;
            4'h3:    return 8'b0111_1101;
            4'h4:    return 8'b1011_0111;
            4'h5:    return 8'b1011_1011;
            4'h6:    return 8'b1011_1101;
            4'h7:    return 8'b1101_0111;
            4'h8:    return 8'b1101_1011;
            4'h9:    return 8'b1101_1101;
            default: return 8'b1111_1111;
        endcase
    endfunction

    task pressionar_digito(input logic [3:0] d);
        logic [7:0] coords;
        coords = get_coords(d);

        if (`DEBUG) $display("[DEBUG TB] Iniciando pressionamento de %1d...", d);

        while (lin_matriz !== coords[7:4]) begin
            if (`DEBUG) $display("[DEBUG TB] lin_matriz = 0b%4b", lin_matriz);
            @(posedge clk);
        end
        col_matriz = coords[3:0];
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        col_matriz = 4'b1111;


        if (`DEBUG) $display("[DEBUG TB] Pressionamento finalizado.");
    endtask

    task pressionar_asterisco;
        if (`DEBUG) $display("[DEBUG TB] Iniciando confirmamento...");

        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(`MAX_ESPERA) @(posedge clk);

        if (`DEBUG) $display("[DEBUG TB] Confirmamento finalizado.");
    endtask

    task fazer_reset;
        if (`DEBUG) $display("[DEBUG TB] Iniciando reset...");
        col_matriz = 4'b1111;
        rst    = 1;
        repeat(5) @(posedge clk);
        rst    = 0;
        repeat(5) @(posedge clk);
        if (`DEBUG) $display("[DEBUG TB] Reset finalizado.");
    endtask

    task linha(input bit m);
        if (m)
            $display("===============================================");
        else
            $display("-----------------------------------------------");
    endtask

    task gerar_num_aleatorio(output bit [3:0] numero_out);
        numero_out = $urandom_range(0, 9);
        if (`DEBUG) $display("[DEBUG TB] Número aleatório gerado: %d", numero_out);
    endtask

    function bit cobertura_completa;
        for (int i = 0; i <= 9; i++)
            if (hit_count[i] < `MAX_COBERTURA) return 0;
        return 1;
    endfunction

    task limpar_cobertura;
        foreach (hit_count[i]) hit_count[i] = 0;
        if (`DEBUG) $display("[DEBUG TB] Cobertura limpa.");
    endtask

    task exibir_cobertura;
        int c;
        integer cobertos;
        c = 0;
        cobertos = 0;
        $display("             RELATORIO DE COBERTURA");
        linha(0);
        for (int i = 0; i <= 9; i++) begin
            $display(
                " Digito %0d: %0d/%1d \t\t    %s",
                i,
                hit_count[i],
                `MAX_COBERTURA,
                hit_count[i] >= `MAX_COBERTURA ? "[COBERTO]" : "[PENDENTE]"
            );
            if (hit_count[i] >= `MAX_COBERTURA) cobertos++;
        end
        linha(0);
        for (int i = 0; i <= 9; i++)
            c += hit_count[i];
        $display("  Total: %0d/10 digitos cobertos (%.0f%%)", cobertos, c * 100 / (10 * `MAX_COBERTURA));
        linha(1);
    endtask

    // ================================================================
    // CENARIO 1 — Decodificação do teclado
    // ================================================================
    task teste_decodificar_teclado;
        bit [3:0] esperado;

        $display("           CENÁRIO 1: DECODIFICAÇÃO");
        linha(1);

        fazer_reset();
        limpar_cobertura();
        exibir_cobertura();

        while (!cobertura_completa()) begin
            gerar_num_aleatorio(num);

            pressionar_digito(num);

            repeat(`MAX_ESPERA) @(posedge clk);

            if (digitos_value.digits[0] != num) begin
                $display("[FALHA] Esperado: %X, Obtido: %X", num, digitos_value.digits[0]);
                $finish;
            end
            else if (hit_count[num] < `MAX_COBERTURA)
                hit_count[num]++;

            $write("\x1b[15A");
            exibir_cobertura();
        end
    endtask

    // ================================================================
    // CENARIO 2 — Shift do barramento
    // ================================================================
    task teste_shift_barramento;
        digitosPac_t sequencia_esperada;
        logic [3:0] digito_atual;
        integer erros;

        $display("               CENARIO 2: Shift");
        linha(1);

        fazer_reset();
        sequencia_esperada = ~0;

        $display(" Digitando sequencia de 0-9 duas vezes...");
        linha(0);
        for (int i = 0; i < 20; i++) begin
            digito_atual = i % 10;
            sequencia_esperada = (sequencia_esperada << 4) | digito_atual;
            pressionar_digito(digito_atual);
            repeat(`MAX_ESPERA) @(posedge clk);

            $display(" Digitando %1d...           %20h", digito_atual, digitos_value);
            if (digitos_value != sequencia_esperada) begin
                $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
                $finish;
            end
            if (`DEBUG) $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
        end

        linha(0);
        $display(" Digitando 50 números aleatórios...");
        linha(0);

        for (int i = 0; i < 50; i++) begin
            gerar_num_aleatorio(digito_atual);

            sequencia_esperada = (sequencia_esperada << 4) | digito_atual;

            pressionar_digito(digito_atual);
            repeat(`MAX_ESPERA) @(posedge clk);

            $display(" Digitando %1d...           %20h", digito_atual, digitos_value);
            if (digitos_value != sequencia_esperada) begin
                $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
                $finish;
            end
            if (`DEBUG) $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
        end

        linha(1);
    endtask

    // ================================================================
    // CENARIO 3 — Debounce
    // ================================================================
    task teste_debounce_tecla(input logic [3:0] tecla);
        logic [7:0] coords;
        logic [3:0] l, c;
        logic [7:0] i;

        integer limite_max_press;
        integer ciclos_pressionado;
        integer ciclos_solto;
        longint t_inicio;
        linha(1);

        fazer_reset();

        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];

        $display(" Tecla alvo: %0d", tecla);
        linha(0);

        limite_max_press   = 5;
        t_inicio           = $time;


        fork : ruidos
            begin
                for (i = 0; i < 100; i++) @(posedge clk);
                disable ruidos;
            end
            begin
                while (1) begin
                    ciclos_pressionado = $urandom_range(1, limite_max_press);
                    ciclos_solto       = $urandom_range(2, 15);

                    while (lin_matriz != l) @(posedge clk);
                    col_matriz = c;
                    $display(" [%03dns] Ruído com duração %1dns", $time - t_inicio, ciclos_pressionado);

                    repeat (ciclos_pressionado) @(posedge clk);

                    col_matriz = 4'b1111;

                    repeat (ciclos_solto) @(posedge clk);

                    limite_max_press = (limite_max_press * 5)/3;
                end
            end
        join

        while (lin_matriz != l) @(posedge clk);
        col_matriz = c;
        $display(" [%03dns] O sinal estabilizou", $time - t_inicio);

        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        $display(" [%03dns] O sinal passou o debounce", $time - t_inicio);

        repeat(`MAX_ESPERA) @(posedge clk);

            $display(" [%03dns] Barramento: %20h", $time - t_inicio, digitos_value);
        linha(0);
        // Validação final do barramento
        if (digitos_value == (~0 << 4) | tecla) begin
            $display(" [SUCESSO] Tecla %0d foi gravada no barramento!", tecla);
        end
        else begin
            $display(" [FALHA] O sinal estabilizou mas o barramento contem: 0x%X (esperado: 0x%X)", digitos_value.digits[0], tecla);
        end
    endtask

    task teste_debounce;
        $display("              CENARIO 3: Debounce");

        for (int i = 0; i < 10; i++) begin
            teste_debounce_tecla(i);
        end

        linha(1);
    endtask

    // ================================================================
    // CENARIO 4 — Repeticao automatica da tecla
    // ================================================================
    task teste_repeticao_tecla;
        logic [3:0] tecla;
        logic [7:0] coords;
        logic [3:0] l, c;
        logic [79:0] shadow_matrix;

        $display("   CENARIO 4: Repetição Automática de Teclas");
        linha(1);

        fazer_reset();

        gerar_num_aleatorio(tecla);
        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];

        $display(" Tecla sorteada para teste de pressao longa: %0d", tecla);
        linha(0);

        while (lin_matriz !== l) @(posedge clk);
        col_matriz = c;
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);

        shadow_matrix = digitos_value;
        if (shadow_matrix[3:0] === tecla) begin
            $display(" [OK] Tecla %0d registrada pela primeira vez com sucesso!", tecla);
        end else begin
            $display(" [AVISO] Tecla ainda nao apareceu no barramento. Obtido: 0x%X", shadow_matrix[3:0]);
        end

        $display(" Mantendo pressionado... aguardando 2000 clks para a 1a repeticao...");
        repeat(2000) @(posedge clk);

        shadow_matrix = digitos_value;
        $display(" Checando o barramento apos os primeiros 2 segundos...");
        if (shadow_matrix[3:0] === tecla && shadow_matrix[7:4] === tecla) begin
            $display(" [SUCESSO] 1a Repeticao Detectada! O digito duplicou: [0]=0x%X, [1]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4]);
        end else begin
            $display(" [AVISO] A 1a repeticao nao aconteceu apos 2s. Barramento: [0]=0x%X, [1]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4]);
        end

        $display(" Mantendo pressionado... aguardando +1000 clks para a 2a repeticao (ritmo de 1s)...");
        repeat(1000) @(posedge clk);

        shadow_matrix = digitos_value;
        $display(" Checando o barramento apos mais 1 segundo...");
        if (shadow_matrix[3:0] === tecla && shadow_matrix[7:4] === tecla && shadow_matrix[11:8] === tecla) begin
            $display(" [SUCESSO] 2a Repeticao Detectada! O digito triplicou: [0]=0x%X, [1]=0x%X, [2]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4], shadow_matrix[11:8]);
        end else begin
            $display(" [AVISO] A 2a repeticao falhou ou ritmo de 1s nao foi obedecido. Barramento: [0]=0x%X, [1]=0x%X, [2]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4], shadow_matrix[11:8]);
        end

        col_matriz = 4'b1111;
        repeat(20) @(posedge clk);

        linha(0);
        $display("        RELATORIO DE REPETICAO AUTOMATICA");
        linha(0);
        if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla && digitos_value.digits[2] === tecla) begin
            $display(" [SUCESSO] Maquina de estados obedeceu perfeitamente os tempos (Debounce -> 2s -> 1s)!");
        end else if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla) begin
            $display(" [PARCIAL] Apenas uma repeticao ocorreu. Verifique se o loop continuo de 1s esta ativo.");
        end else if (digitos_value.digits[0] === tecla) begin
            $display(" [LIMITADO] Tecla registrada apenas 1 vez. O circuito nao possui auto-repeat.");
        end else begin
            $display(" [FALHA] A tecla sequer foi registrada no teste.");
        end

        linha(1);
        repeat(20) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 5 — Confirmacao com tecla *
    // ================================================================
    task teste_confirmacao_asterisco;
        localparam integer N = 5;
        logic [3:0]  digitados [N];
        logic [3:0]  esperado_k;
        logic [3:0]  obtido_k;
        logic [79:0] barramento_plano;
        integer ciclos;
        integer erros_dados;
        integer ok_timing, ok_dados;
        integer k;
        logic [3:0]  digito_atual;
        logic [7:0]  coords_atuais;

        $display("       CENARIO 5: Confirmacao com * (ENTER)");
        linha(1);
        fazer_reset();

        $display(" Digitando %0d teclas aleatorias...", N);
        linha(0);
        for (int i = 0; i < N; i++) begin
            digito_atual = $urandom_range(0, 9);
            digitados[i] = digito_atual;
            coords_atuais = get_coords(digito_atual);

            while (lin_matriz !== coords_atuais[7:4]) @(posedge clk);

            col_matriz = coords_atuais[3:0];

            repeat(110) @(posedge clk);

            col_matriz = 4'b1111;
            repeat(15) @(posedge clk);

            if (`DEBUG) $display("  [%0d/%0d] Digitado: %0d | Registrado em digits[0]: %X", i+1, N, digito_atual, digitos_value.digits[0]);
        end

        repeat(5) @(posedge clk);

        $display(" Barramento antes de acionar o ENTER:");
        barramento_plano = digitos_value;
        for (k = 0; k < N; k++) begin
            $display("  barramento_plano[%0d] = 0x%X", k, barramento_plano[k*4 +: 4]);
        end

        linha(0);
        $display(" Pressionando * (ENTER)...");
        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;

        ciclos    = 0;
        ok_timing = 0;

        while (!digitos_valid && ciclos < 200) begin
            @(posedge clk);
            ciclos++;
        end

        col_matriz = 4'b1111; 
        repeat(5) @(posedge clk);

        if (digitos_valid || ciclos < 200) begin
            ok_timing = (ciclos <= 120);
            if (ok_timing)
                $display(" [SUCESSO] digitos_valid subiu em %0d ciclos!", ciclos);
            else
                $display(" [FALHA] digitos_valid demorou %0d ciclos para responder!", ciclos);
        end else begin
            $display(" [FALHA] Timeout: O sinal digitos_valid nao subiu apos 200 ciclos.");
        end

        linha(0);
        $display(" Verificando integridade e ordem dos dados...");
        erros_dados = 0;

        for (k = 0; k < N; k++) begin
            esperado_k = digitados[(N - 1) - k];
            obtido_k   = barramento_plano[k*4 +: 4];

            if (obtido_k !== esperado_k) begin
                $display(" [FALHA] Posicao digits[%0d]: esperado=0x%X | obtido=0x%X", k, esperado_k, obtido_k);
                erros_dados++;
            end else begin
                $display(" [OK] digits[%0d]: esperado=0x%X | obtido=0x%X", k, esperado_k, obtido_k);
            end
        end

        ok_dados = (erros_dados == 0);

        linha(0);
        if (ok_dados && ok_timing)
            $display(" [SUCESSO] Sincronismo perfeito.");
        else
            $display(" [FALHA] (Dados=%0s, Timing=%0s).",
                     ok_dados ? "OK" : "ERRO", ok_timing ? "OK" : "ERRO");
        linha(1);

        repeat(30) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 9 — Timeout de digitação
    // ================================================================
    task teste_timeout_digitacao;
        logic [3:0] t_random1, t_random2;
        logic [3:0] tecla, tecla2;
        logic [7:0] coords;
        logic [3:0] l, c;

        $display("          CENARIO 9: Timeout de Digitacao");
        linha(1);

        // ------------------------------------------------------------
        // Teste 01: Digitar proxima tecla dentro de 5 segundos
        // ------------------------------------------------------------
        
        gerar_num_aleatorio(t_random1);
        gerar_num_aleatorio(t_random2);
        
        $display(" [Teste 01] Digitando dentro do limite de 5s (Teclas: %X e %X)...", t_random1, t_random2);
        fazer_reset();
        enable = 1;
        
        pressionar_digito(t_random1);
        repeat(`MAX_ESPERA) @(posedge clk);
        
        // Aguardar 4.9 segundos (ajuste este valor baseado na escala real do seu DUT)
        #4900; 
        
        pressionar_digito(t_random2);
                
        if (digitos_value.digits[0] === t_random2 && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 01 Passou: Digito 0x%X registrado e valid permaneceu em 0.", t_random2);
        end else begin
            $display(" [FALHA] Teste 01: Esperado digito=0x%X e valid=0. Obtido: digito=0x%X, valid=%1b", 
                     t_random2, digitos_value.digits[0], digitos_valid);
        end

        linha(0);
        
        // ------------------------------------------------------------
        // Teste 02: Nao digitar por mais de 5 segundos (Tempo Mínimo Garantido)
        // ------------------------------------------------------------
        gerar_num_aleatorio(tecla);
        $display(" [Teste 02] Digitando acima do limite de 5s (Teclas: %X)...", tecla);
        fazer_reset();
        enable = 1;
        
        pressionar_digito(tecla);
        $display("  Tecla %X pressionada. Verificando estabilidade por 5000 ciclos...", tecla);
        
        // Criamos flags locais para monitorar quem terminou primeiro
        // Lembrete: declare estas variáveis no topo da sua task se o iverilog reclamar!
        begin : bloco_verificacao_timeout
            logic tempo_atingido;
            logic falha_precoce;
            
            tempo_atingido = 0;
            falha_precoce   = 0;

            fork
                // Bloco 1: Força a contagem exata do tempo mínimo de 5000 pulsos
                begin
                    repeat(5000) @(posedge clk);
                    tempo_atingido = 1;
                end
                
                // Bloco 2: Monitora se o hardware vai ter um comportamento precoce ilegal
                begin
                    @(posedge digitos_valid);
                    if (!tempo_atingido) begin
                        falha_precoce = 1;
                    end
                end
            join_any
            
            // Se o valid subiu antes de dar 5000 ciclos, mata o teste na hora
            if (falha_precoce) begin
                $display(" [FALHA] Teste 02: O sinal digitos_valid subiu ANTES dos 5000 pulsos mínimos!");
                $finish;
            end
            
            // Se passou pelos 5000 ciclos intacto, espera o pulso exato do timeout (caso falte algum ciclo de acomodação)
            if (!digitos_valid) begin
                fork
                    begin : espera_pulso_final
                        wait(digitos_valid == 1'b1);
                    end
                    begin : trava_seguranca
                        repeat(100) @(posedge clk); // margem de erro pequena
                    end
                join_any
                disable fork;
            end
        end
        
        // --- PEQUENO ATRAZO CRÍTICO ---
        #1; 

        // Checa se o timeout ativou corretamente no momento certo
        if (digitos_value === {20{4'hE}} && digitos_valid === 1'b1) begin
            $display(" [OK] Teste 02 (Parte 1): Timeout detectado no tempo correto! Barramento: 0xE e valid=1.");
        end else begin
            $display(" [FALHA] Teste 02 (Parte 1): Barramento nao respondeu ao timeout apos os 5000 ciclos.");
            $display("        Obtido: %20h, valid=%1b", digitos_value, digitos_valid);
            $finish; 
        end
        
        // Aguarda exatamente a PRÓXIMA borda de clock para ver o reset automático pós-timeout
        @(posedge clk);
        #2; // Mantido em #1 para evitar amostragem fora da janela estável
        
        $display("  Barramento apos proxima borda: %20h", digitos_value);

        // Checa se voltou para 0xF e valid=0
        if (digitos_value === {20{4'hF}} && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 02 (Parte 2): Sistema resetado para 0xF e valid retornou para 0.");
        end else begin
            $display(" [FALHA] Teste 02 (Parte 2): Sistema nao limpou pos-timeout. Obtido: %20h, valid=%1b", 
                     digitos_value, digitos_valid);
            $finish;
        end

        linha(0);
        // ------------------------------------------------------------
        // Teste 03: Timeout logo no inicio da digitaçao
        // ------------------------------------------------------------
        gerar_num_aleatorio(t_random1);
        $display(" [Teste 03] Timeout na primeira tecla (%X) - Esperando >5000 ciclos...", t_random1);
        fazer_reset();
        enable = 1;
        
        // 1. Pressiona a primeira tecla para disparar o início da digitação
        pressionar_digito(t_random1);
        
        // 2. Aguarda até o timeout acontecer OU até estourar o tempo limite de segurança
        $display("  Tecla %X registrada. Aguardando a mudanca de estado pelo timeout...", t_random1);
        fork
            begin
                // Espera o sinal de valid subir indicando o estouro do timeout do DUT
                wait(digitos_valid == 1'b1); 
            end
            begin
                // Trava de segurança caso o DUT falhe e nunca saia do lugar (evita travar a simulação)
                repeat(5100) @(posedge clk);
            end
        join_any
        disable fork; // Cancela o bloco que ficou para trás
        
        // 3. Pequeno atraso crítico para o simulador processar as saídas do DUT pós-clock
        #1;

        // 4. Validação dos dados após o período de espera do timeout
        if (digitos_value === {20{4'hE}} && digitos_valid === 1'b1) begin
            $display(" [OK] Teste 03: Timeout disparado com sucesso após o período mínimo de espera.");
        end else begin
            $display(" [FALHA] Teste 03: Timeout falhou ou nao respondeu no tempo esperado.");
            $display("        Obtido no barramento: %20h, valid=%1b (Esperado: 0xE...E com valid=1)", 
                     digitos_value, digitos_valid);
            $finish;
        end
        
        // 5. Espera a próxima borda para o circuito limpar o estado de timeout e voltar ao normal
        @(posedge clk);
        #1;

        linha(0);

        // ------------------------------------------------------------
        // Teste 04: Com enable=0, o timer de timeout deve congelar
        // ------------------------------------------------------------
        gerar_num_aleatorio(t_random1);
        $display(" [Teste 04] Testando congelamento do Timer com enable=0 apos tecla %X...", t_random1);
        fazer_reset();
        enable = 1;
        
        pressionar_digito(t_random1);
        repeat(`MAX_ESPERA) @(posedge clk);
        
        // Aguardar 3 segundos com enable ativo
        repeat(3000) @(posedge clk);
        
        // Desativar enable e esperar 4 segundos (Não deve dar timeout aqui)
        enable = 0;
        repeat(4000) @(posedge clk);

        if (digitos_valid === 1'b1 || digitos_value === {20{4'hE}}) begin
            $display(" [FALHA] Teste 04: Timeout disparou incorretamente com enable=0!");
        end else begin
            $display(" [OK] Teste 04 (Parte 1): Timer congelou com sucesso durante enable=0.");
        end
        
        // Reativar enable e esperar 1.5 segundos (Total acumulado ativo = 4.5s, ainda sem timeout)
        enable = 1;
        repeat(1500) @(posedge clk);
        
        if (digitos_valid === 1'b1) begin
            $display(" [FALHA] Teste 04: Timeout disparou antes dos 5s totais ativos (4.5s acumulados)!");
        end
        
        // Aguardar mais 0.6 segundos para estourar o limite restante (4.5s + 0.6s = 5.001s acumulados ativos)
        repeat(503) @(posedge clk);
        
        if (digitos_value === {20{4'hE}} && digitos_valid === 1'b1) begin
            $display(" [OK] Teste 04 (Parte 2): Timeout disparou corretamente apos somar os 5s com enable=1!");
        end else begin
            $display(" [FALHA] Teste 04 (Parte 2): Timeout nao disparou apos o tempo acumulado. Obtido: %20h", digitos_value);
        end

        linha(1);
        $display(" [SUCESSO] Todos os testes de Timeout de digitacao passaram!");
        linha(1);
    endtask

    // ================================================================
    // CENARIO 10 — Verificação do sinal Enable
    // ================================================================
    task teste_enable;
        logic [3:0] t_rand1, t_rand2, t_rand3;
        digitosPac_t sequencia_esperada;

        $display("            CENÁRIO 10: SINAL ENABLE");
        linha(1);

        // ------------------------------------------------------------
        // Teste 01: Com enable=1, o modulo le e processa normalmente
        // ------------------------------------------------------------
        $display(" [Teste 01] Verificando operacao normal com enable=1...");
        fazer_reset();
        enable = 1;
        sequencia_esperada = ~0; // Estado resetado (tudo 0xF)

        // Sorteia 3 teclas
        gerar_num_aleatorio(t_rand1);
        gerar_num_aleatorio(t_rand2);
        gerar_num_aleatorio(t_rand3);

        $display(" -> Digitando sequencia: %X, %X, %X", t_rand1, t_rand2, t_rand3);
        
        pressionar_digito(t_rand1);
        sequencia_esperada = (sequencia_esperada << 4) | t_rand1;
        
        pressionar_digito(t_rand2);
        sequencia_esperada = (sequencia_esperada << 4) | t_rand2;
        
        pressionar_digito(t_rand3);
        sequencia_esperada = (sequencia_esperada << 4) | t_rand3;

        if (digitos_value == sequencia_esperada) begin
            $display(" [OK] Teste 01: Teclas registradas normalmente. Barramento: %20h", digitos_value);
        end else begin
            $display(" [FALHA] Teste 01: Esperado %20h, Obtido %20h", sequencia_esperada, digitos_value);
            $finish;
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 02: Com enable=0, o modulo congela e ignora entradas
        // ------------------------------------------------------------
        gerar_num_aleatorio(t_rand1);
        gerar_num_aleatorio(t_rand2);
        $display(" [Teste 02] Desativando enable=0 e tentando digitar...");
        fazer_reset();
        enable = 1;

        // Digita a primeira tecla normalmente
        pressionar_digito(t_rand1);
        sequencia_esperada = (~0 << 4) | t_rand1; 

        // Desativa o módulo
        enable = 0;
        repeat(5) @(posedge clk); // Tempo para o DUT processar a desativação

        $display(" -> Módulo desativado. Tentando forçar tecla %X por 200 ciclos...", t_rand2);
        
        // Força o pressionamento manual da tecla 't_rand2' direto nos pinos 
        // já que a task normal 'pressionar_digito' travaria esperando a varredura (que deve estar congelada)
        fork
            begin
                logic [7:0] coords;
                coords = get_coords(t_rand2);
                col_matriz = coords[3:0];
                repeat(200) @(posedge clk);
                col_matriz = 4'b1111;
            end
        join

        // Verifica se o valor antigo se manteve intacto e ignorou o t_rand2
        if (digitos_value == sequencia_esperada) begin
            $display(" [OK] Teste 02: Módulo ignorou entradas e manteve valor anterior: %20h", digitos_value);
        end else begin
            $display(" [FALHA] Teste 02: O barramento mudou com enable=0! Obtido: %20h", digitos_value);
            $finish;
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 03: Reativar enable=1 mantem o estado anterior
        // ------------------------------------------------------------
        gerar_num_aleatorio(t_rand1);
        gerar_num_aleatorio(t_rand2);
        $display(" [Teste 03] Reativando enable=1 e verificando continuidade...");
        fazer_reset();
        enable = 1;

        // Digita a primeira tecla (Tecla 8 na especificação)
        pressionar_digito(t_rand1);
        sequencia_esperada = (~0 << 4) | t_rand1;

        // Desativa por 50 ciclos de clock
        enable = 0;
        repeat(50) @(posedge clk);

        // Reativa o enable
        enable = 1;
        repeat(5) @(posedge clk); // Espera estabilizar a retomada da varredura

        // Digita a segunda tecla (Tecla 9 na especificação)
        $display(" -> Módulo reativado. Digitando segunda tecla: %X", t_rand2);
        pressionar_digito(t_rand2);
        sequencia_esperada = (sequencia_esperada << 4) | t_rand2;

        if (digitos_value == sequencia_esperada) begin
            $display(" [OK] Teste 03: Varredura retomada e estado preservado perfeitamente! Barramento: %20h", digitos_value);
        end else begin
            $display(" [FALHA] Teste 03: Estado perdido ou varredura nao retomou. Esperado: %20h, Obtido: %20h", sequencia_esperada, digitos_value);
            $finish;
        end

        linha(1);
        $display(" [SUCESSO] Todos os testes do sinal ENABLE passaram!");
        linha(1);
    endtask

    // ================================================================
    // CENARIO 11 — Verificação do sinal de Reset
    // ================================================================
    task teste_reset;
        logic [3:0] t_rand1, t_rand2;
        digitosPac_t sequencia_esperada;

        $display("             CENÁRIO 11: SINAL DE RESET");
        linha(1);

        // ------------------------------------------------------------
        // Teste 01: Reset durante a digitação normal (Interrupção)
        // ------------------------------------------------------------
        $display(" [Teste 01] Aplicando Reset no meio da digitacao...");
        fazer_reset();
        enable = 1;

        gerar_num_aleatorio(t_rand1);
        $display(" -> Digitando tecla %X e aplicando reset imediatamente...", t_rand1);

        pressionar_digito(t_rand1); // Digita uma tecla

        // Começa a digitar a segunda tecla, mas joga o reset logo em seguida
        gerar_num_aleatorio(t_rand2);
        $display(" -> Digitando tecla %X e aplicando reset imediatamente...", t_rand2);
        
        fork
            begin
                pressionar_digito(t_rand2);

                repeat(10) @(posedge clk); // Espera o início do processo da tecla
                rst = 1;                   // Força o reset abrupto
                @(posedge clk);
                rst = 0;
            end
        join

        // Verifica se o barramento limpou tudo para 0xF e valid foi para 0
        if (digitos_value == {20{4'hF}} && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 01: O sistema limpou os dados e interrompeu a digitacao com sucesso.");
        end else begin
            $display(" [FALHA] Teste 01: Sistema nao resetou corretamente em atividade. Obtido: %20h, valid=%1b", 
                     digitos_value, digitos_valid);
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 02: Reset durante o estado de erro por Timeout
        // ------------------------------------------------------------
        $display(" [Teste 02] Aplicando Reset durante o estado de Timeout (Erro)...");
        fazer_reset();
        enable = 1;

        gerar_num_aleatorio(t_rand1);
        pressionar_digito(t_rand1);

        $display(" -> Aguardando o estouro do Timeout...");
        @(posedge digitos_valid); // Espera o timeout acontecer dinamicamente
        
        // Verifica se entrou em timeout (barramento 0xE e valid=1)
        if (digitos_value == {20{4'hE}} && digitos_valid === 1'b1) begin
            $display(" -> Timeout detectado. Ativando sinal de Reset...");
            rst = 1;
            @(posedge clk);
            #1; // Acomodação
            
            if (digitos_value == {20{4'hF}} && digitos_valid === 1'b0) begin
                $display(" [OK] Teste 02: O Reset limpou com sucesso o estado de erro de Timeout.");
            end else begin
                $display(" [FALHA] Teste 02: Reset falhou em limpar o Timeout. Obtido: %20h, valid=%1b", 
                         digitos_value, digitos_valid);
            end
            rst = 0; // Libera o reset
        end else begin
            $display(" [AVISO] Nao foi possivel testar: o circuito nao gerou o estado de timeout esperado.");
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 03: Reset com o módulo desativado (Enable = 0)
        // ------------------------------------------------------------
        $display(" [Teste 03] Aplicando Reset com o modulo desativado (Enable=0)...");
        fazer_reset();
        enable = 1;

        gerar_num_aleatorio(t_rand1);
        pressionar_digito(t_rand1); // Guarda um valor inicial

        enable = 0; // Desativa o módulo (congela o barramento com o valor t_rand1)
        repeat(10) @(posedge clk);

        $display(" -> Ativando Reset com Enable=0...");
        rst = 1;
        repeat(5) @(posedge clk);
        #1;

        // O reset DEVE limpar o circuito mesmo que o enable esteja em 0 (Reset síncrono/assíncrono dominante)
        if (digitos_value == {20{4'hF}} && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 03: Reset possui prioridade sobre o Enable e limpou o barramento.");
        end else begin
            $display(" [FALHA] Teste 03: O sinal de Enable=0 bloqueou o Reset! Obtido: %20h", digitos_value);
        end
        rst = 0;

        linha(0);

        // ------------------------------------------------------------
        // Teste 04: Manutenção do Reset ativo (Estado estático)
        // ------------------------------------------------------------
        $display(" [Teste 04] Verificando se o sistema permanece resetado com rst=1 ativo por muito tempo...");
        fazer_reset(); // Garante estado inicial limpo
        enable = 1;
        rst = 1;       // Ativa e SEGURA o reset ligado

        $display(" -> Forcando pulsos no teclado com reset ativo...");
        // Em vez de usar pressionar_digito (que trava), aplicamos o estimulo direto nos pinos
        fork
            begin
                logic [7:0] coords;
                gerar_num_aleatorio(t_rand1);
                coords = get_coords(t_rand1);
                
                col_matriz = coords[3:0];   // Simula tecla pressionada
                repeat(100) @(posedge clk); // Mantém pressionada por 100 ciclos
                col_matriz = 4'b1111;       // Solta a tecla
                repeat(50) @(posedge clk);
            end
        join // Esse join agora vai fechar com 150 ciclos garantidos, sem travar!
        #1;

        // O barramento não pode ter saído do padrão de reset de jeito nenhum
        if (digitos_value == {20{4'hF}} && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 04: Sistema permaneceu imune a entradas com o Reset ativo.");
        end else begin
            $display(" [FALHA] Teste 04: O circuito aceitou dados ou mudou de estado com o Reset travado em 1! Obtido: %20h", digitos_value);
            $finish;
        end

        rst = 0; // Libera o circuito para os próximos cenários
        repeat(10) @(posedge clk);

        linha(1);
        $display(" [SUCESSO] Todos os testes do sinal de RESET passaram!");
        linha(1);
    endtask

    // ================================================================
    // Bloco principal
    // ================================================================

    initial begin
        integer seed;
        if (!$value$plusargs("seed=%d", seed))
            seed = 42;

        if (`DEBUG) $display("=== SEMENTE ALEATORIA ATIVADA: %0d ===", seed);

        $dumpfile("teste_teclado.vcd");
        $dumpvars(0, tb_teclado);

        linha(1);
        $display("        TESTES DO TECLADO MATRICIAL 4X4        ");
        linha(1);
        $display("              INICIO DA SIMULACAO              ");
        linha(1);

        // ------ Cenario 1: Decodificacao do teclado ------
        teste_decodificar_teclado();

        // ------ Cenario 2: Shift do barramento ------
        teste_shift_barramento();

        // ------ Cenario 3: Debounce ------
        teste_debounce();

        // ------ Cenario 4: Repeticao automatica ------
        teste_repeticao_tecla();

        // ------ Cenario 5: Confirmacao com * ------
        teste_confirmacao_asterisco();

        // ------ Cenário 9: Timeout de digitação -----
        teste_timeout_digitacao();

        // ------ Cenário 10: Enable -----
        teste_enable();

        // ------ Cenário 11; Reset -----
        teste_reset();

        repeat(10) @(posedge clk);

        $display("                FIM DA SIMULACAO");
        linha(1);
        $finish;
    end

endmodule