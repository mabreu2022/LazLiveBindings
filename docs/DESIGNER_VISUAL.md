# Manual do Designer Visual e Integração com a IDE Lazarus

A suíte LiveBindings traz três integrações profundas com o ambiente de design do Lazarus (`IDEIntf`):
1. **Janela Dockable do LiveBindings Designer.**
2. **Menu de Contexto com atalho rápido ("Vincular com LiveBinding...").**
3. **Property Editors dedicados no Object Inspector.**

---

## 1. Janela Dockable: LiveBindings Designer

A janela do LiveBindings Designer pode ser acoplada (*docked*) em qualquer área da IDE do Lazarus (ao lado do Object Inspector, na parte inferior ou como janela flutuante).

### Como abrir a janela:
- Pelo menu principal da IDE: **Exibir (View) -> Janelas Secundárias (Secondary Windows) -> LiveBinding Designer**.
- Ou clicando com o botão direito em qualquer controle e escolhendo **"Vincular com LiveBinding..."**.

### Anatomia da Janela

```
+-----------------------------------------------------------------------------------------------+
| [ 🔗 Vínculo Direto ] [ ⚡ Vínculo Expressão ] [ ✏️ Editar ] [ 🗑️ Excluir ] [ 🔄 Sincronizar ] |
+------------------------------------+----------------------------------------------------------+
| Formulário Ativo: Form1            | Vínculos Ativos no TBindingManager                       |
| [ Filtrar componentes...         ] |                                                          |
|                                    | # | Ativo | Origem   | Prop/Expressão | Destino | Alvo   |
| 📁 Form1                           |---|-------|----------|----------------|---------|--------|
|   ├── 📄 Caption (String)          | 1 | SIM   | edtNome  | Text           | lblNome | Caption|
|   └── 📄 Enabled (Boolean)         | 2 | SIM   | sePreco  | Value * Qtd    | lblTotal| Caption|
| 📁 edtNome: TEdit                  |                                                          |
|   └── 📄 Text (String)             |                                                          |
| 📁 lblNome: TLabel                 |                                                          |
|   └── 📄 Caption (String)          |                                                          |
|------------------------------------|                                                          |
| [ Definir Origem ] [Definir Destino|                                                          |
| Origem: edtNome.Text               |                                                          |
| Destino: lblNome.Caption           |                                                          |
+------------------------------------+----------------------------------------------------------+
| Status: 2 vínculos configurados.                                                             |
+-----------------------------------------------------------------------------------------------+
```

### Criando um Vínculo Direto pela Janela:
1. Na árvore de componentes (painel esquerdo), expanda o componente de origem e clique na propriedade desejada (ex: `edtNome.Text`).
2. Clique no botão **"Definir Origem"**.
3. Em seguida, selecione na árvore a propriedade de destino (ex: `lblNome.Caption`).
4. Clique no botão **"Definir Destino"**.
5. Clique no botão da barra de ferramentas **"🔗 Vínculo Direto"**.
6. O vínculo é imediatamente criado no `TBindingManager` e o formulário é marcado como modificado (`GlobalDesignHook.Modified`).

### Criando um Vínculo por Expressão:
1. Defina o componente e a propriedade de destino clicando em **"Definir Destino"** (ex: `lblTotal.Caption`).
2. Clique em **"⚡ Vínculo Expressão"**.
3. O diálogo do Construtor de Expressões será aberto para você digitar e validar a fórmula.
4. Ao clicar em **OK**, o vínculo é registrado no `TBindingManager`.

### Sincronização Bidirecional com a Seleção do Designer:
Ao clicar em qualquer componente na tela de desenho do formulário no Lazarus, a árvore do LiveBindings Designer seleciona e foca automaticamente o controle correspondente.

---

## 2. Menu de Contexto no Designer ("Vincular com LiveBinding...")

Qualquer componente colocado sobre um formulário passa a ter uma opção de atalho no menu de clique com o botão direito:

1. Clique com o botão direito sobre um controle (ex: `TEdit`, `TLabel`, `TTrackBar`, etc.).
2. Selecione a opção **"Vincular com LiveBinding..."**.
3. O Lazarus executará as seguintes ações automaticamente:
   - Se o formulário ainda não tiver um `TBindingManager`, ele criará um automaticamente com o nome `BindingManager1`.
   - Abre a janela do **LiveBindings Designer**.
   - Posiciona o foco e pré-seleciona o controle clicado na árvore de componentes.

---

## 3. Construtor Modal de Expressões (`TBindingExpressionDialog`)

Acessível dando duplo clique na propriedade `SourceExpression` de qualquer item da coleção no Object Inspector, ou pelo botão **"✏️ Editar Expressão"** no LiveBindings Designer.

### Recursos do Construtor:
1. **Editor de Expressão (Memo Superior):** Exibe a fórmula com fonte monoespaçada legível.
2. **Propriedades Disponíveis (Esquerda):** Lista todas as propriedades RTTI do componente de origem e também variáveis geradas para controles irmãos no mesmo formulário (sintaxe `Componente_Propriedade`).
   - Campo de busca instantânea no topo para filtrar propriedades.
   - Duplo clique sobre qualquer item insere o nome da propriedade na posição do cursor no editor.
3. **Catálogo de Funções e Operadores (Direita):**
   - Seletor de categoria (`Todas`, `Matemática`, `Texto (Strings)`, `Lógica / Condicional`, `Data e Hora`, `Conversão`, `Operadores`).
   - Exibe a lista de funções com seus parâmetros esperados.
   - Duplo clique insere a função no editor já posicionando o cursor dentro dos parênteses.
   - Painel explicativo com a descrição de cada função.
4. **Validador em Tempo de Design (Botão "⚡ Testar Expressão"):**
   - Executa a expressão em tempo real contra as variáveis do formulário.
   - Se a expressão for válida, exibe em verde: `✓ Válida! [rtFloat] 150.00`.
   - Se contiver erros de sintaxe ou identificador desconhecido, exibe em vermelho a mensagem de diagnóstico precisa da exceção.

---

## 4. Property Editors no Object Inspector

- **Dropdown de Propriedades (`TBindingPropertySelectorEditor`):**
  - Aplicado aos campos `SourceProperty` e `TargetProperty` de cada `TBindingLink`.
  - Ao clicar na seta do dropdown no Object Inspector, exibe apenas propriedades compatíveis (propriedades legíveis para `SourceProperty` e graváveis para `TargetProperty`), eliminando a necessidade de digitar nomes de propriedades manualmente.
- **Diálogo de Expressão (`TBindingExpressionEditor`):**
  - Aplicado ao campo `SourceExpression`.
  - Exibe o botão `[...]` no Object Inspector para abrir o construtor visual.
