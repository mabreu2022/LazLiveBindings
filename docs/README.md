# Documentação do LiveBindings para Lazarus / Free Pascal

Bem-vindo à documentação oficial da suíte **LiveBindings Visual com Binding Expressions para Lazarus e Free Pascal**.

Esta documentação foi elaborada para desenvolvedores que buscam produtividade, desacoplamento e poder declarativo ao conectar dados e interfaces visuais no Lazarus LCL, reproduzindo com fidelidade a tecnologia de **LiveBindings** do Delphi com o poder do motor nativo de expressões `fpexprpars`.

---

## 📚 Índice de Documentos

1. **[Guia de Início Rápido e Uso Geral](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/docs/GUIA_DE_USO.md)**
   - O que é o LiveBindings para Lazarus.
   - Componentes centrais: `TBindingManager`, `TBindingLink`, `TBindingLinks`.
   - Modos de operação: Vínculo Direto (`bmDirectProperty`) e Expressões (`bmExpression`).
   - Ciclo de vida e sincronização automática.

2. **[Manual do Designer Visual e IDE](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/docs/DESIGNER_VISUAL.md)**
   - Janela Dockable **LiveBinding Designer**.
   - Integração com o menu de contexto: *"Vincular com LiveBinding..."*.
   - Property Editors personalizados no Object Inspector.
   - Construtor e validador de expressões em tempo de design.

3. **[Referência do Motor de Expressões (`fpexprpars`)](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/docs/MOTOR_DE_EXPRESSOES.md)**
   - Sintaxe das expressões dinâmicas.
   - Variáveis automáticas extraídas por RTTI do componente de origem e de formulários.
   - Catálogo completo de funções embutidas (Matemática, Strings, Lógica, Data/Hora, Conversão).
   - Máscaras de formatação com `FormatMask`.

4. **[Programação em Tempo de Execução e Exemplos](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/docs/EXEMPLOS_E_RUNTIME.md)**
   - Criação de vínculos dinâmicos 100% via código Pascal.
   - Sincronização programática (`SynchronizeAll`, `SynchronizeSource`, `SynchronizeTarget`).
   - Monitoramento e tratamento de erros com os eventos `OnBeforeSync`, `OnAfterSync` e `OnBindingError`.
   - Demonstração prática comentada ([`LiveBindingsDemo`](file:///d:/Projetos%20AntiGravity/Lazarus%20LiveBinding/demo/LiveBindingsDemo.lpi)).

---

## 🚀 Status da Instalação no Sistema

Os pacotes foram registrados e compilados diretamente na instalação do Lazarus em `C:\lazarus`:
- **Binário da IDE Atualizado:** `C:\lazarus\lazarus.exe`
- **Pacote Runtime:** `d:\Projetos AntiGravity\Lazarus LiveBinding\runtime\pkg_livebindings_runtime.lpk`
- **Pacote Designtime:** `d:\Projetos AntiGravity\Lazarus LiveBinding\designtime\pkg_livebindings_designtime.lpk`
- **Aba na Paleta de Componentes:** `LiveBindings`
- **Comando de Menu:** `Exibir -> Janelas Secundárias -> LiveBinding Designer`
