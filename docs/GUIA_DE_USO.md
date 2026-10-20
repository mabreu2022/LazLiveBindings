# Guia de Uso Completo do LiveBindings para Lazarus

O **LiveBindings** permite sincronizar propriedades entre componentes visuais e não-visuais da LCL de forma declarativa, eliminando código repetitivo de atribuição em eventos `OnChange`, `OnClick` ou `OnExit`.

---

## 1. Componentes Principais

### `TBindingManager`
É o componente central que deve ser adicionado ao Formulário ou DataModule. Ele atua como o orquestrador de todos os vínculos:
- **`Links`:** Coleção de vínculos (`TBindingLinks`) persistida nativamente no arquivo `.lfm`.
- **`AutoSyncOnLoaded`:** Quando `True` (padrão), sincroniza automaticamente todos os vínculos assim que o formulário termina de carregar.
- **`Active`:** Permite pausar ou ativar globalmente a sincronização do formulário.
- **Eventos:**
  - `OnBeforeSync`: Disparado imediatamente antes da sincronização de cada vínculo.
  - `OnAfterSync`: Disparado após a sincronização bem-sucedida de um vínculo.
  - `OnBindingError`: Notifica erros de sintaxe ou conversão sem interromper o fluxo da aplicação.

### `TBindingLink`
Cada item dentro de `TBindingManager.Links` representa uma regra de sincronização entre um componente de origem (`Source`) e um componente de destino (`Target`).

| Propriedade | Tipo | Descrição |
|---|---|---|
| `Source` | `TComponent` | Componente de origem (com notificação automática de exclusão). |
| `SourceProperty` | `string` | Nome da propriedade do `Source` a ser lida quando `Mode = bmDirectProperty`. |
| `SourceExpression` | `string` | Expressão dinâmica calculada quando `Mode = bmExpression`. |
| `Target` | `TComponent` | Componente de destino que receberá o valor calculado ou lido. |
| `TargetProperty` | `string` | Nome da propriedade do `Target` onde o resultado será aplicado. |
| `Direction` | `TBindingDirection` | Direção do fluxo: `bdSourceToTarget` (padrão), `bdTargetToSource` ou `bdTwoWay`. |
| `Mode` | `TBindingMode` | `bmDirectProperty` (leitura direta RTTI) ou `bmExpression` (cálculo via parser). |
| `Active` | `Boolean` | Ativa ou desativa individualmente este vínculo. |
| `FormatMask` | `string` | Máscara de formatação opcional (ex: `'R$ #,##0.00'`, `'%d%%'`). |

---

## 2. Modos de Operação

### Modo 1: Vínculo Direto (`bmDirectProperty`)
Lê o valor de `Source.SourceProperty` via RTTI estendida e o atribui a `Target.TargetProperty`.

O motor realiza **coerção automática de tipos**, permitindo vincular tipos diferentes sem erros de conversão:
- `Integer` ou `Float` -> `TLabel.Caption` (converte para string automaticamente).
- `TTrackBar.Position` (`Integer`) -> `TProgressBar.Position` (`Integer`).
- `TCheckBox.Checked` (`Boolean`) -> `TButton.Enabled` (`Boolean`).
- `TEdit.Text` (`String`) -> `TSpinEdit.Value` (`Integer`).

### Modo 2: Vínculo por Expressão (`bmExpression`)
Avalia em tempo de execução uma expressão baseada no motor nativo `fpexprpars`.

- As propriedades publicadas do `Source` são injetadas automaticamente como variáveis na fórmula.
- Exemplo com `Source = sePreco` (`TFloatSpinEdit` com propriedade `Value`):
  ```
  Value * 1.20
  ```
- Exemplo referenciando outro controle do formulário (sintaxe `Componente_Propriedade`):
  ```
  Value * seQtd_Value * 1.15
  ```
- Exemplo com formatação de texto:
  ```
  Upper(Text)
  ```
- Exemplo com lógica condicional:
  ```
  If(Checked, 'ATIVO', 'INATIVO')
  ```

---

## 3. Criando seu Primeiro Vínculo no Designer

1. Crie um novo formulário na IDE do Lazarus.
2. Adicione os seguintes controles:
   - Um `TEdit` chamado `edtNome`.
   - Um `TLabel` chamado `lblResultado`.
3. Na paleta **LiveBindings**, clique em `TBindingManager` e solte-o no formulário (`BindingManager1`).
4. Selecione o `BindingManager1` no Object Inspector e dê duplo clique na propriedade `Links`.
5. Na janela da coleção:
   - Clique em **Adicionar (+)** para criar um novo vínculo.
   - Defina `Source` como `edtNome`.
   - No campo `SourceProperty`, abra a lista suspensa e escolha `Text`.
   - Defina `Target` como `lblResultado`.
   - No campo `TargetProperty`, abra a lista suspensa e escolha `Caption`.
6. No evento `edtNome.OnChange`, adicione uma linha para disparar a sincronização enquanto o usuário digita:
   ```pascal
   procedure TForm1.edtNomeChange(Sender: TObject);
   begin
     BindingManager1.SynchronizeSource(edtNome);
   end;
   ```
7. Execute o projeto (`F9`): ao digitar no `edtNome`, o `lblResultado` atualiza automaticamente!

---

## 4. Práticas Recomendadas

1. **Reentrancy Safe:** O motor possui proteção automática contra recursão (`FSynchronizing`), permitindo vínculos bidirecionais (`bdTwoWay`) com total segurança.
2. **Gerenciamento de Memória:** Se um componente vinculado for excluído do formulário, o `TBindingManager` recebe uma notificação via `Notification(opRemove)` e anula as referências (`nil`) com segurança, evitando falhas de ponteiro (`Access Violation`).
3. **Persistência `.lfm`:** Todos os vínculos são serializados como `TCollectionItem` dentro do `TBindingManager` no arquivo de formulário `.lfm`.
