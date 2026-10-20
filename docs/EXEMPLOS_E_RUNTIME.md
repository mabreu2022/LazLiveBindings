# Programação em Tempo de Execução e Exemplos Práticos

Embora o LiveBindings ofereça suporte completo em tempo de design (persistência em `.lfm`, diálogos e janela dockable), sua arquitetura foi desenhada para ser igualmente poderosa e concisa quando manipulada **100% via código Pascal em tempo de execução**.

---

## 1. Usando a Unit de Execução

Em qualquer formulário ou unidade onde você desejar criar ou manipular vínculos programaticamente, adicione **`uBindingRuntime`** na cláusula `uses`:

```pascal
uses
  Classes, SysUtils, Forms, Controls, StdCtrls,
  uBindingRuntime;
```

---

## 2. Criando um Vínculo Direto via Código

O método `AddLink` cria e adiciona um `TBindingLink` no modo `bmDirectProperty`:

```pascal
var
  Link: TBindingLink;
begin
  // Vincula o texto do Edit ao Caption do Label
  Link := BindingManager1.AddLink(
    edtNome,       // Componente de Origem
    'Text',        // Propriedade de Origem
    lblResultado,  // Componente de Destino
    'Caption'      // Propriedade de Destino
  );
  
  Link.Active := True;
  Link.Synchronize; // Sincroniza imediatamente
end;
```

### Vínculo com Máscara de Formatação:
```pascal
var
  Link: TBindingLink;
begin
  // Vincula o valor do TrackBar (0-100) formatado com sufixo '%'
  Link := BindingManager1.AddLink(tbPercentual, 'Position', lblPercentual, 'Caption');
  Link.FormatMask := '%d%%';
  Link.Active := True;
  Link.Synchronize;
end;
```

---

## 3. Criando um Vínculo por Expressão Dinâmica

O método `AddExpressionLink` cria e adiciona um `TBindingLink` no modo `bmExpression`:

```pascal
var
  Link: TBindingLink;
begin
  // Calcula o total com 15% de acréscimo e formata como moeda
  Link := BindingManager1.AddExpressionLink(
    sePreco,                     // Origem
    'Value * seQtd_Value * 1.15', // Expressão dinâmica
    lblTotal,                    // Destino
    'Caption'                    // Propriedade de Destino
  );
  
  Link.FormatMask := 'R$ #,##0.00';
  Link.Active := True;
  Link.Synchronize;
end;
```

### Expressão de Texto com Funções:
```pascal
var
  Link: TBindingLink;
begin
  // Transforma o texto digitado em maiúsculas e remove espaços das pontas
  Link := BindingManager1.AddExpressionLink(
    edtSobrenome,
    'Upper(Trim(Text))',
    lblSobrenomeFormatado,
    'Caption'
  );
  Link.Active := True;
  Link.Synchronize;
end;
```

### Expressão Condicional:
```pascal
var
  Link: TBindingLink;
begin
  Link := BindingManager1.AddExpressionLink(
    chkAtivo,
    'If(Checked, "SISTEMA OPERACIONAL", "SISTEMA PAUSADO")',
    lblStatusSistema,
    'Caption'
  );
  Link.Active := True;
  Link.Synchronize;
end;
```

---

## 4. Métodos de Sincronização do `TBindingManager`

Você pode controlar exatamente quando as sincronizações acontecem:

### 4.1. Sincronizar Tudo
Executa todas as regras registradas no gerenciador:
```pascal
BindingManager1.SynchronizeAll;
```

### 4.2. Sincronizar a partir de uma Origem Específica
Ideal para ser chamado em manipuladores de eventos (`OnChange`, `OnClick`) para atualizar apenas os alvos dependentes daquele controle:
```pascal
procedure TForm1.edtPrecoChange(Sender: TObject);
begin
  BindingManager1.SynchronizeSource(edtPreco);
end;
```

### 4.3. Sincronizar para um Destino Específico
Atualiza apenas os vínculos cujo `Target` seja o componente especificado:
```pascal
BindingManager1.SynchronizeTarget(lblTotal);
```

### 4.4. Pausar ou Reativar Todos os Vínculos
```pascal
// Pausa todas as atualizações
BindingManager1.Active := False;

// Reativa e dispara sincronização automática
BindingManager1.Active := True;
```

---

## 5. Monitoramento de Eventos e Telemetria

O `TBindingManager` expõe três eventos fundamentais:

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  BindingManager1.OnBeforeSync   := @DoBeforeSync;
  BindingManager1.OnAfterSync    := @DoAfterSync;
  BindingManager1.OnBindingError := @DoBindingError;
end;

procedure TForm1.DoBeforeSync(Sender: TObject; Link: TBindingLink);
begin
  // Pré-processamento ou log detalhado
end;

procedure TForm1.DoAfterSync(Sender: TObject; Link: TBindingLink);
begin
  // Notificação de sucesso
  WriteLn('Vínculo sincronizado: ', Link.DisplayName);
end;

procedure TForm1.DoBindingError(Sender: TObject; Link: TBindingLink; const ErrorMsg: string);
begin
  // Tratamento seguro de exceções de cálculo ou sintaxe
  WriteLn('Erro no vínculo ', Link.DisplayName, ': ', ErrorMsg);
end;
```

---

## 6. Demonstração Pronta para Uso (`LiveBindingsDemo`)

O projeto [`LiveBindingsDemo`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/demo/LiveBindingsDemo.lpi) foi desenvolvido para validar e demonstrar todas as funcionalidades:

### Como Executar:
- **Direto pelo binário compilado:**
  Execute [`demo/lib/x86_64-win64/LiveBindingsDemo.exe`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/demo/lib/x86_64-win64/LiveBindingsDemo.exe).
- **Pelo Lazarus IDE:**
  Abra o arquivo de projeto [`demo/LiveBindingsDemo.lpi`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/demo/LiveBindingsDemo.lpi) e pressione `F9`.

### Seções da Demonstração:
1. **Aba 1 (Vínculos Diretos):** Demonstra vínculos síncronos entre textos, slider/trackbar com progress bar e percentual, e controle de estado de botão com checkbox.
2. **Aba 2 (Expressões Dinâmicas):** Demonstra cálculos monetários em tempo real com taxa de imposto (`Value * seQtd_Value * 1.15`), manipulação inline de strings com `Upper` e `Trim`, e rótulos condicionais com `If(...)`.
3. **Aba 3 (Monitor & Runtime):** Tabela interativa mostrando todos os links do gerenciador, botão para injetar novos links em tempo de execução e log de eventos de sincronização.
