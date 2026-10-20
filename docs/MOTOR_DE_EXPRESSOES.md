# Referência Completa do Motor de Expressões (Binding Expressions)

O motor de expressões em tempo de execução do LiveBindings é baseado na unit nativa do Free Pascal **`fpexprpars`** (`TFPExpressionParser`), complementado por funções auxiliares e injeção automática de RTTI.

---

## 1. Como as Variáveis são Injetadas

Ao avaliar uma expressão no modo `bmExpression`, o `TBindingLink` analisa em tempo real o componente de origem (`Source`) e seu proprietário (`Owner`):

### 1.1. Propriedades do Componente `Source`
Todas as propriedades publicadas legíveis do componente `Source` tornam-se variáveis diretamente acessíveis pelo seu nome:
- Se `Source = sePreco` (`TFloatSpinEdit`), você pode usar diretamente `Value` na expressão.
- Se `Source = edtNome` (`TEdit`), você pode usar diretamente `Text`.
- Se `Source = chkAtivo` (`TCheckBox`), você pode usar diretamente `Checked`.

### 1.2. Propriedades de Componentes Irmãos (Formulário)
Para criar cálculos que combinam múltiplos componentes do mesmo formulário, cada controle tem suas propriedades exportadas com o prefixo do nome do componente seguido de sublinhado (`_`):
- `seQtd_Value`: Propriedade `Value` do controle `seQtd`.
- `edtPreco_Text`: Propriedade `Text` do controle `edtPreco`.
- `chkDesconto_Checked`: Propriedade `Checked` do controle `chkDesconto`.

---

## 2. Operadores Suportados

| Operador | Tipo | Descrição | Exemplo |
|---|---|---|---|
| `+` | Aritmético / Concatenação | Soma numérica ou concatenação de textos | `Valor + 10`, `'Olá ' + Nome` |
| `-` | Aritmético | Subtração ou inversão de sinal | `Total - Desconto`, `-Valor` |
| `*` | Aritmético | Multiplicação | `Preco * Quantidade` |
| `/` | Aritmético | Divisão de ponto flutuante | `Total / 2` |
| `=` | Comparação | Igualdade | `Status = 'A'` |
| `<>` | Comparação | Diferente | `Qtd <> 0` |
| `>` | Comparação | Maior que | `Idade > 18` |
| `<` | Comparação | Menor que | `Estoque < Minimo` |
| `>=` | Comparação | Maior ou igual | `Pontos >= 100` |
| `<=` | Comparação | Menor ou igual | `Tentativas <= 3` |
| `AND` | Lógico | E lógico | `(Idade >= 18) AND Ativo` |
| `OR` | Lógico | OU lógico | `Vip OR (Total > 1000)` |
| `NOT` | Lógico | Negação lógica | `NOT Bloqueado` |

---

## 3. Catálogo de Funções Embutidas

### 3.1. Funções de Texto (Strings)
- **`UPPER(S)` / `UPPERCASE(S)`:** Converte para letras maiúsculas.
  ```
  Upper(Text)
  ```
- **`LOWER(S)` / `LOWERCASE(S)`:** Converte para letras minúsculas.
  ```
  Lower(Text)
  ```
- **`TRIM(S)`:** Remove espaços em branco do início e do final da cadeia de caracteres.
  ```
  Trim(Text)
  ```
- **`LENGTH(S)`:** Retorna a quantidade de caracteres da string.
  ```
  Length(Text)
  ```
- **`COPY(S, Inicio, Qtd)`:** Extrai uma substring a partir do índice `Inicio`.
  ```
  Copy(Text, 1, 3)
  ```
- **`POS(Substr, S)`:** Retorna a posição de uma substring dentro do texto (base 1).
  ```
  Pos('@', Email)
  ```
- **`COMPARETEXT(S1, S2)`:** Compara dois textos sem distinguir maiúsculas de minúsculas.

### 3.2. Funções Lógicas e Condicionais
- **`IF(Condicao, SeVerdade, SeFalso)`:** Retorna uma string condicional.
  ```
  If(Checked, 'ATIVO', 'INATIVO')
  ```
- **`IFNUM(Condicao, NumVerdade, NumFalso)`:** Retorna um valor numérico condicional.
  ```
  IfNum(chkVip_Checked, Preco * 0.80, Preco)
  ```
- **`IFS(Condicao, S1, S2)`:** Condicional nativo para Strings.
- **`IFF(Condicao, F1, F2)`:** Condicional nativo para Floats.
- **`IFI(Condicao, I1, I2)`:** Condicional nativo para Inteiros.

### 3.3. Funções Matemáticas
- **`ABS(X)`:** Retorna o valor absoluto de `X`.
- **`ROUND(X)`:** Arredonda um número de ponto flutuante para o inteiro mais próximo.
- **`TRUNC(X)`:** Trunca a parte fracionária do número.
- **`SQR(X)`:** Retorna o quadrado do número (`X * X`).
- **`SQRT(X)`:** Retorna a raiz quadrada do número.
- **`INT(X)` / `FRAC(X)`:** Retorna a parte inteira ou a parte fracionária.
- **`SIN(X)`, `COS(X)`, `ARCTAN(X)`:** Funções trigonométricas.
- **`PI`:** Constante numérica de $\pi$ ($3.14159...$).

### 3.4. Funções de Data e Hora
- **`NOW`:** Retorna a data e hora atual do sistema.
- **`DATE`:** Retorna a data atual.
- **`TIME`:** Retorna a hora atual.
- **`DAYOFWEEK(Data)`:** Retorna o dia da semana (1 a 7).
- **`EXTRACTYEAR(Data)`:** Retorna o ano da data informada.
- **`EXTRACTMONTH(Data)`:** Retorna o mês da data informada.
- **`EXTRACTDAY(Data)`:** Retorna o dia do mês.
- **`FORMATDATETIME(Mascara, Data)`:** Formata a data com uma máscara personalizada.
  ```
  FormatDateTime('dd/mm/yyyy hh:nn', Now)
  ```

### 3.5. Funções de Conversão
- **`FORMATFLOAT(Mascara, Numero)`:** Formata um valor de ponto flutuante.
  ```
  FormatFloat('#,##0.00', Valor * 1.15)
  ```
- **`INTTOSTR(N)` / `STRTOINT(S)`:** Converte entre Inteiro e String.
- **`FLOATTOSTR(N)` / `STRTOFLOAT(S)`:** Converte entre Ponto Flutuante e String.
- **`BOOLTOSTR(B)` / `STRTOBOOL(S)`:** Converte entre Booleano e String.

---

## 4. Máscaras de Formatação (`FormatMask`)

Cada `TBindingLink` possui a propriedade opcional **`FormatMask`**. Quando definida, a formatação é aplicada automaticamente ao valor antes de atribuí-lo a um destino do tipo `String` (como `TLabel.Caption` ou `TEdit.Text`):

| Tipo do Dado | Exemplo de Máscara | Exemplo de Entrada | Saída Resultante |
|---|---|---|---|
| Moeda / Float | `R$ #,##0.00` | `1540.5` | `R$ 1.540,50` |
| Percentual | `%d%%` | `75` | `75%` |
| Quantidade Decimal | `0.000 kg` | `2.5` | `2.500 kg` |
| Data | `dd/mm/yyyy` | `2026-10-20` | `20/10/2026` |
| Hora | `hh:nn:ss` | `20:15:00` | `20:15:00` |

---

## 5. Exemplos Práticos de Expressões

### Exemplo 1: Carrinho de Compras com Imposto
- Origem: `sePreco` (`TFloatSpinEdit`)
- Destino: `lblTotal` (`TLabel.Caption`)
- Expressão:
  ```
  Value * seQtd_Value * 1.15
  ```
- Máscara (`FormatMask`): `R$ #,##0.00`

### Exemplo 2: Nome Completo Formatado
- Origem: `edtNome` (`TEdit`)
- Destino: `lblNomeCompleto` (`TLabel.Caption`)
- Expressão:
  ```
  Upper(Trim(Text)) + ' ' + Upper(Trim(edtSobrenome_Text))
  ```

### Exemplo 3: Alerta de Faixa de Temperatura
- Origem: `tbTemperatura` (`TTrackBar`)
- Destino: `lblStatusTemp` (`TLabel.Caption`)
- Expressão:
  ```
  If(Position > 80, "PERIGO: TEMPERATURA CRÍTICA!", If(Position > 50, "Atenção: Temperatura Elevada", "Temperatura Normal"))
  ```
