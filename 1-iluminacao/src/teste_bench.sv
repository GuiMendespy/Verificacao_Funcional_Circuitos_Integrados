`timescale 1ns/1ps
// nosso testbench
/* Guilherme dividiu os testes e fiquei com os 4 primeiros divididos assim:
  // Legenda : *(botao >=5000) e ->(troca de modo)

  test_1(); //Aut deslg *-> Manu deslg (comuta led)
  test_2(); //Aut lig *-> Manu deslg (comuta led)
  test_3(); //Manu deslg *-> Aut lig (comuta led)
  test_4(); //Manu lig *-> Aut lig (comuta led)


  // Legenda : **(botao < 5000) e -->(auto transição de modo)

  test_5(); //Aut deslg **--> (permanece lampada e led)
  test_6(); //Aut lig **-->  (permanece lampada e led)
  test_7(); //Manu deslg **--> (lampada comuta e led permanece)
  test_8(); //Manu lig **--> (lampada comuta e led permanece)
*/

module tb;

  logic clk, rst;
  logic push_button, infravermelho;
  logic led, saida;
  string autoMan[2];
  string ligDes[2];
  string maiorOuMenor[2];

  initial clk = 0;
  always #1 clk = ~clk;  // clock de 2ns período (500 MHz)

  // DUT
  controladora #(
    .DEBOUNCE_P(300),
    .SWITCH_MODE_MIN_T(5000),
    .AUTO_SHUTDOWN_T(30000)
  ) dut (
    .clk(clk),
    .rst(rst),
    .infravermelho(infravermelho),
    .push_button(push_button),
    .led(led),
    .saida(saida)
  );

  task test_setup_inicial();
    // INPUTS
    rst = 1;
    infravermelho = 0;
    push_button = 0;

    repeat(5) @(posedge clk);

    rst = 0;

    repeat(5) @(posedge clk);
  endtask

  task titulo(input int autoInicial, ligInicial, autoFinal, ligFinal, tempo);
    autoMan[0] = "automático";
    autoMan[1] = "manual";
    ligDes[0] = "desligado";
    ligDes[1] = "ligado";
    maiorOuMenor[0] = "<";
    maiorOuMenor[1] = ">=";

    $display("\n---------------------------------------------------------------------------------");
    $display(
      "   Modo %s %s para %s %s %s 5000",
      autoMan[autoInicial],
      ligDes[ligInicial],
      autoMan[autoFinal],
      ligDes[ligFinal],
      maiorOuMenor[tempo >= 5000]
    );
    $display("---------------------------------------------------------------------------------");
  endtask

  task ir_para_estado(input int automaticoIni, ligadoIni);
    begin
      test_setup_inicial();

      if (!automaticoIni && ligadoIni) begin
        infravermelho = 1;
        repeat(1) @(posedge clk);
        infravermelho = 0;
      end

      if (automaticoIni) begin
        pressiona_por(5100);

        if (ligadoIni) begin
          pressiona_por(500);
        end
      end

      repeat(5) @(posedge clk);
    end
  endtask

  task pressiona_por(input int pulsos);
    begin
      push_button = 1;
      repeat(pulsos) @(posedge clk);
      push_button = 0;
      repeat(5) @(posedge clk);
    end
  endtask

  task verificar_sinal(input string nome, bit esperado, recebido);
    if (esperado != recebido) begin
      $display("[FAIL] %s está com o estado errado.", nome);
      $display("   Esperado: %0d", esperado);
      $display("   Recebido: %0d", recebido);
    end else begin
      $display("[PASS] Passou no teste do sinal %s.", nome);
    end
  endtask

  task test_x(input int autoInicial, ligInicial,  autoFinal, ligFinal, tempo_pressionamento);
    titulo(autoInicial, ligInicial, autoFinal, ligFinal, tempo_pressionamento);

    ir_para_estado(autoInicial, ligInicial);

    pressiona_por(tempo_pressionamento);

    $display("Tempo atual: %0t", $time);

    verificar_sinal("LED", autoFinal, led);
    verificar_sinal("lâmpada", ligFinal, saida);
  endtask

  task test_1();
    test_x(0, 0, 1, 0, 5005);
  endtask

  task test_2();
    test_x(0, 1, 1, 0, 5005);
  endtask

  task test_3();
    test_x(1, 0, 0, 1, 5005);
  endtask

  task test_4();
    test_x(1, 1, 0, 1, 5005);
  endtask

  task test_5();
    test_x(0, 0, 0, 0, 4900);
  endtask

  task test_6();
    test_x(0, 1, 0, 1, 4900);
  endtask

  task test_7();
    test_x(1, 0, 1, 1, 4900);
  endtask

  task test_8();
    test_x(1, 1, 1, 0, 4900);
  endtask

  initial begin
    $dumpfile("simular.vcd");
    $dumpvars(0);
    // Legenda : *(botao >=5000) e ->(troca de modo)
    test_1(); //Aut deslg *-> Manu deslg
    test_2(); //Aut lig *-> Manu deslg
    test_3(); //Manu deslg *-> Aut deslg
    test_4(); //Manu lig *-> Aut deslg

    // // Legenda : **(botao < 5000) e -->(auto transição de modo)
    test_5(); //Aut deslg **-->
    test_6(); //Aut lig **-->
    test_7(); //Manu deslg **--> (comuta a lampada e permanece o led)
   	test_8(); //Manu lig **--> (comuta a lampada e permanece o led)
    $finish;
  end
endmodule