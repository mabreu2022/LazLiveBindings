# LiveBindings Visual com Binding Expressions para Lazarus / Free Pascal

Suíte completa e profissional de componentes e extensões IDE para o **Lazarus IDE** e **Free Pascal Compiler (FPC)**, reproduzindo com fidelidade e robustez a experiência de **LiveBindings** do Delphi (estilo OTA), com suporte a **Binding Expressions** em tempo de execução via `fpexprpars`.

---

## 1. Arquitetura Modular dos Pacotes

A solução foi estruturada em dois pacotes modulares conforme as melhores práticas do ecossistema Lazarus:

| Pacote | Tipo | Descrição |
|---|---|---|
| [`runtime/pkg_livebindings_runtime.lpk`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/runtime/pkg_livebindings_runtime.lpk) | **RunAndDesignTime** | Motor de execução, parsing de expressões com `fpexprpars`, sincronização bidirecional por RTTI estendida e componentes centrais (`TBindingManager`, `TBindingLink`, `TBindingLinks`). |
| [`designtime/pkg_livebindings_designtime.lpk`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/designtime/pkg_livebindings_designtime.lpk) | **DesignTime** | Registros na IDE, Property Editors no Object Inspector (`TPropertyEditor`), Component Editor no designer de formulários, Diálogo Construtor de Expressões e Janela Dockable do Designer Visual. |

---

## 2. Estrutura dos Arquivos e Módulos

```
d:\Projetos AntiGravity\Lazarus LiveBinding\
├── runtime\
│   ├── pkg_livebindings_runtime.lpk       # Pacote Runtime
│   ├── pkg_livebindings_runtime.pas       # Stub de registro do pacote
│   └── uBindingRuntime.pas                # Motor de vinculação e avaliação de expressões
├── designtime\
│   ├── pkg_livebindings_designtime.lpk    # Pacote Designtime
│   ├── pkg_livebindings_designtime.pas    # Stub de registro designtime
│   ├── uLiveBindingsRegister.pas          # Registro de componentes, editores e janela IDE
│   ├── uBindingPropEditors.pas            # Property Editors do Object Inspector
│   ├── uBindingComponentEditor.pas        # Component Editor com atalho no menu de contexto
│   ├── uBindingExpressionDialog.pas       # Diálogo modal construtor/validador de expressões
│   ├── uBindingExpressionDialog.lfm       # Interface do construtor de expressões
│   ├── uBindingDesignerForm.pas           # Janela Dockable de LiveBindings Visual
│   └── uBindingDesignerForm.lfm           # Interface do LiveBindings Designer
├── demo\
│   ├── LiveBindingsDemo.lpi               # Projeto de demonstração executável
│   ├── LiveBindingsDemo.lpr               # Programa principal
│   ├── uMainForm.pas                      # Formulário de teste interativo
│   └── uMainForm.lfm                      # Layout e componentes do formulário de demonstração
└── README.md
```

---

## 3. Especificação Detalhada das Implementações

### 3.1. `uBindingRuntime.pas` (Motor Runtime & Binding Expressions)
- **Diretivas & Units:** `{$mode objfpc}{$H+}` com `Classes`, `SysUtils`, `TypInfo`, `Rtti`, `fpexprpars`.
- **Tipos Base:**
  - `TBindingDirection = (bdSourceToTarget, bdTargetToSource, bdTwoWay);`
  - `TBindingMode = (bmDirectProperty, bmExpression);`
- **Classe `TBindingLink` (`TCollectionItem`):**
  - Propriedades publicadas: `Source`, `SourceProperty`, `SourceExpression`, `Target`, `TargetProperty`, `Direction`, `Mode`, `Active`, `FormatMask`.
  - Tratamento de `FreeNotification` integrado ao `OwnerManager` para anular referências quando componentes forem excluídos.
  - Reentrancy Guard (`FSynchronizing`) prevenindo loops infinitos em sincronizações bidirecionais (`bdTwoWay`).
  - **Sincronização Direta (`bmDirectProperty`):** Extrai o valor do `Source` e converte automaticamente entre tipos primitivos (`String`, `Integer`, `Int64`, `Float`, `Boolean`, `Enumeration`) atribuindo com segurança ao `Target`.
  - **Sincronização por Expressão (`bmExpression`):**
    - Instancia o `TFPExpressionParser` com categorias `[bcStrings, bcDateTime, bcMath, bcBoolean, bcConversion]`.
    - Registra funções customizadas úteis: `UPPER`, `LOWER`, `TRIM`, `IF`, `IFNUM`.
    - Inspeciona via RTTI todas as propriedades publicadas do `Source` em tempo real e as injeta no parser (`AddFloatVariable`, `AddStringVariable`, `AddBooleanVariable`, `AddIntegerVariable`).
    - Inspeciona componentes irmãos no mesmo formulário (sintaxe `Componente_Propriedade`, ex: `Edit1_Text`, `seQtd_Value`).
    - Avalia `Parser.Evaluate` e converte o resultado (`TFPExpressionResult`) para o tipo exato da propriedade de destino.
    - Suporte a máscara de formatação (`FormatMask`, ex: `'R$ #,##0.00'`, `'%d%%'`, `'dd/mm/yyyy'`).
    - Tratamento de exceções robusto evitando loops de erro ou travamento da aplicação.
- **Classe `TBindingLinks` (`TCollection`):** Gerencia os itens tipados com override de `GetOwner` retornando `FOwnerManager: TBindingManager` para garantir streaming nativo em arquivos `.lfm`.
- **Classe `TBindingManager` (`TComponent`):**
  - Propriedades publicadas: `Links: TBindingLinks`, `AutoSyncOnLoaded: Boolean`, `Active: Boolean`.
  - Eventos: `OnBeforeSync`, `OnAfterSync`, `OnBindingError`.
  - Override de `Notification`: limpa referências órfãs automaticamente.
  - Override de `Loaded`: dispara `SynchronizeAll` automaticamente se `AutoSyncOnLoaded = True`.

---

### 3.2. `uBindingPropEditors.pas` (Property Editors no Object Inspector)
- **`TBindingPropertySelectorEditor` (`TStringPropertyEditor`):**
  - Retorna atributos `[paValueList, paSortList, paMultiSelect]`.
  - Inspeciona dinamicamente as propriedades publicadas do componente referenciado (`Source` ou `Target`), filtrando propriedades legíveis para origem e graváveis para destino, exibindo lista dropdown no Object Inspector.
- **`TBindingExpressionEditor` (`TStringPropertyEditor`):**
  - Retorna atributo `[paDialog]`.
  - Ao clicar no botão de reticências `[...]` da propriedade `SourceExpression`, abre o diálogo dedicado `TBindingExpressionDialog`.

---

### 3.3. `uBindingExpressionDialog.pas` (Construtor Modal de Expressões)
- **Editor de Expressões:** Memo com fonte monoespaçada e suporte a inserção por cursor.
- **Árvore de Propriedades:** Lista todas as propriedades RTTI do `Source` e de componentes irmãos no mesmo formulário, com filtro de busca em tempo real. Duplo clique insere o identificador na expressão.
- **Catálogo de Funções `fpexprpars`:** Categorias (Matemática, Texto, Lógica, Data/Hora, Conversão, Operadores). Duplo clique insere a chamada com os parênteses e posiciona o cursor.
- **Validação e Teste em Tempo de Design:** Botão "⚡ Testar Expressão" avalia a sintaxe em tempo real com o parser, exibindo resultado tipado em verde (`[rtFloat] 150.00`) ou mensagem de erro em vermelho.

---

### 3.4. `uBindingComponentEditor.pas` (Menu de Contexto no Designer)
- Registrado para `TComponent` no Designer do Lazarus.
- Menu de clique com botão direito: **"Vincular com LiveBinding..."**.
- Ao ser acionado:
  1. Localiza um `TBindingManager` existente no formulário ou cria um novo automaticamente (`BindingManager1`).
  2. Notifica o `GlobalDesignHook.Modified(OwnerForm)`.
  3. Abre a janela dockable do LiveBindings Designer com o controle pré-selecionado na árvore.

---

### 3.5. `uBindingDesignerForm.pas` (Janela Dockable de LiveBindings Visual)
- Integrada com `IDEWindowCreators` sob o identificador `'LiveBindingDesignerForm'` e menu **Exibir -> Janelas Secundárias -> LiveBinding Designer**.
- Interface em dois painéis ajustáveis:
  - **Esquerda:** Hierarquia dos componentes do formulário ativo e suas propriedades RTTI legíveis, com filtro de busca e botões "Definir Origem" e "Definir Destino".
  - **Direita:** Grid completa dos vínculos configurados (`#`, `Ativo`, `Origem`, `Propriedade / Expressão`, `Direção`, `Destino`, `Propriedade Alvo`, `Modo`).
- **Ganchos com o `GlobalDesignHook`:**
  - `GlobalDesignHook.AddHandlerSetSelection(@OnDesignerSelectionChanged)`: quando um controle é clicado no designer do Lazarus, o LiveBindings Designer foca automaticamente o nó correspondente.
  - `GlobalDesignHook.AddHandlerComponentRenamed(@OnComponentRenamed)`: atualiza a lista de componentes.
  - `GlobalDesignHook.AddHandlerPersistentDeleted(@OnPersistentDeleted)`: atualiza referências se um componente for deletado.
  - `GlobalDesignHook.Modified(Root)`: acionado ao adicionar, editar ou remover vínculos, marcando o formulário como alterado para que o Lazarus salve as alterações no `.lfm`.
- **Ações Rápidas na Barra de Ferramentas:**
  - `🔗 Vínculo Direto`: cria vínculo direto entre origem e destino selecionados.
  - `⚡ Vínculo Expressão`: abre o construtor de expressão e adiciona o vínculo ao `TBindingManager`.
  - `✏️ Editar Expressão`: edita o vínculo selecionado.
  - `🗑️ Excluir`: remove o vínculo com confirmação.
  - `✔️ Ativar/Desat.`: liga ou desliga o vínculo em tempo de design/execução.
  - `🔄 Sincronizar`: força a sincronização imediata do vínculo selecionado.

---

### 3.6. `uLiveBindingsRegister.pas` (Registro na IDE)
Centraliza o registro oficial na IDE do Lazarus:
1. `RegisterComponents('LiveBindings', [TBindingManager]);`
2. `RegisterPropertyEditor(...)` para `SourceProperty`, `TargetProperty` e `SourceExpression`.
3. `RegisterComponentEditor(TComponent, TBindingComponentEditor);`
4. `RegisterIDEMenuCommand(itmViewSecondaryWindows, 'itmLiveBindingDesigner', ...);`
5. `IDEWindowCreators.Add('LiveBindingDesignerForm', @CreateLiveBindingDesigner, nil, ...);`

---

## 4. Como Instalar no Lazarus IDE

### Passo 1: Compilar o Pacote Runtime
1. No menu do Lazarus, vá em **Pacote (Package) -> Abrir arquivo de pacote (.lpk)...**
2. Selecione [`runtime/pkg_livebindings_runtime.lpk`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/runtime/pkg_livebindings_runtime.lpk).
3. Na janela do gerenciador de pacotes, clique em **Compilar (Compile)**.

### Passo 2: Compilar e Instalar o Pacote Designtime
1. No menu do Lazarus, vá em **Pacote (Package) -> Abrir arquivo de pacote (.lpk)...**
2. Selecione [`designtime/pkg_livebindings_designtime.lpk`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/designtime/pkg_livebindings_designtime.lpk).
3. Na janela do pacote, clique em **Compilar (Compile)** e em seguida em **Usar (Use) -> Instalar (Install)**.
4. O Lazarus solicitará confirmação para reconstruir a IDE. Confirme com **Sim**.
5. Após reiniciar:
   - O componente `TBindingManager` estará disponível na aba **LiveBindings** da paleta de componentes.
   - O comando **LiveBinding Designer** estará disponível em **Exibir -> Janelas Secundárias**.
   - Clicar com o botão direito em qualquer componente no designer exibirá a opção **"Vincular com LiveBinding..."**.

---

## 5. Como Testar com a Aplicação de Demonstração

O projeto de demonstração já está compilado e pronto para execução:
- Executável: [`demo/lib/x86_64-win64/LiveBindingsDemo.exe`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/demo/lib/x86_64-win64/LiveBindingsDemo.exe)
- Projeto Lazarus: [`demo/LiveBindingsDemo.lpi`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/demo/LiveBindingsDemo.lpi)

### Recursos demonstrados no aplicativo:
1. **Aba "Vínculos Diretos":**
   - Digitar no `TEdit` atualiza instantaneamente o `TLabel`.
   - Mover o `TTrackBar` sincroniza simultaneamente a `TProgressBar` e um `TLabel` percentual formatado.
   - Marcar/desmarcar o `TCheckBox` habilita/desabilita um `TButton`.
2. **Aba "Expressões Dinâmicas":**
   - Alterar preço e quantidade calcula automaticamente o Subtotal (`Value * seQtd_Value`) e o Total com 15% de imposto (`Value * seQtd_Value * 1.15`), formatados como moeda (`R$ #,##0.00`).
   - Digitar texto formata automaticamente com `Upper(Text)` e `Trim(Text)`.
   - Alternar o checkbox de cliente VIP avalia uma expressão condicional `If(Checked, 'VIP...', 'REGULAR...')`.
3. **Aba "Monitor & Gerenciador":**
   - Tabela em tempo real de todos os `TBindingLinks`.
   - Botão para adicionar um novo vínculo de expressão em tempo de execução (`If(Position > 70, "ALERTA...", "Volume Seguro")`).
   - Log completo de eventos de ciclo de vida (`OnBeforeSync`, `OnAfterSync`, `OnBindingError`).

---

## 6. Verificação de Compilação

Todos os pacotes e projetos foram verificados via linha de comando com `lazbuild` do Lazarus 4.8 / FPC 3.2.2:
```bash
# Pacote Runtime:
lazbuild runtime/pkg_livebindings_runtime.lpk    # [Exit code 0 - SUCESSO]

# Pacote Designtime:
lazbuild designtime/pkg_livebindings_designtime.lpk  # [Exit code 0 - SUCESSO]

# Demonstração:
lazbuild demo/LiveBindingsDemo.lpi             # [Exit code 0 - SUCESSO]
```
