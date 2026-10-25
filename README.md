# CodeTouchBar Studio

Aplicativo local para macOS que mostra métricas de uso de Codex, Claude e Antigravity na Touch Bar. A versão nativa é empacotada como `CodeTouchBar.app` e não depende do MTMR.

## Requisitos

- macOS e um MacBook Pro com Touch Bar
- Python 3
- Command Line Tools do Xcode (compilador `clang` e `codesign`)
- MTMR somente para o painel web legado descrito abaixo
- Sessão local ativa para cada provedor que você quer monitorar

O projeto usa apenas a biblioteca padrão do Python; não há dependências Python para instalar.

## Gerar o app nativo

Na pasta do projeto, execute:

```sh
./macos/build_app.sh
open dist/CodeTouchBar.app
```

O script compila o app, empacota os ícones e coletores em seu bundle interno, assina localmente e substitui compilações anteriores automaticamente.

As versões empacotadas para instalação ficam na página de [Releases do GitHub](https://github.com/aguerreiropereira/codebar/releases). Baixe o ZIP do app, extraia `CodeTouchBar.app` e mova-o para `Applications`.

Ao abrir, o app exibe uma janela de controle com estados obtidos de fontes locais ou integrações configuradas e fica acessível pelo ícone de brilho (**✨**) na barra de menus. O atalho compacto **AI** aparece fixado no Control Strip da Touch Bar.

### Experiência na Touch Bar
- **Tecla ESC Virtual Fixa:** A tecla `esc` fica permanentemente acessível na extrema esquerda da Touch Bar em todos os modos, garantindo o funcionamento do Escape em qualquer app e no terminal sem conflitos.
- **Indicadores Contextuais:** Os cards mostram percentuais quando há uma cota mensurável, saldo monetário para integrações de API, estado de modelos locais ou indisponibilidade explícita quando o provedor não oferece uma fonte automatizada adequada.
- **Mais Modelos de LLM Suportados:**
  - **OpenAI Codex / ChatGPT:** Monitoramento de sessão de 5h e cota semanal.
  - **Anthropic Claude:** Cota lida do histórico local do Claude Desktop quando disponível.
  - **Google Antigravity:** Comunicação direta com o Language Server local e cota em tempo real.
  - **Google Gemini:** A cota da assinatura Gemini não tem API pública documentada; o card informa indisponibilidade.
  - **DeepSeek AI:** Saldo da API DeepSeek opcional, autenticado por chave guardada no Keychain. Esse saldo não é a cota do DeepSeek Chat.
  - **Ollama (Local):** Detecção automática de modelos carregados na memória/VRAM e daemon local (`127.0.0.1:11434`), sem percentual de cota.
  - **Perplexity AI:** A cota pessoal Pro/Max não tem API pública documentada; organizações Enterprise podem consultar Analytics API separadamente.
- **Painel de Controles do Sistema Expandido (Ícone de Sliders):**
  - Toque no botão de controles (ícone de sliders nativo) para expandir instantaneamente os controles essenciais de hardware do Mac:
    - **Brilho:** Diminuir e Aumentar com leitura e ajuste do monitor principal.
    - **Controle de Mídia:** Faixa Anterior, Reproduzir/Pausar e Próxima Faixa com HUD informativo na tela.
    - **Volume:** botões Mudo, Diminuir e Aumentar.
  - Toque no botão de retorno (chevron esquerdo) para voltar imediatamente à visualização dos modelos.
- **Feedback Visual na Tela (On-Screen Display / HUD):**
  - As métricas dos modelos são atualizadas pelo intervalo configurado, no botão de atualização e ao abrir a Touch Bar quando os dados estiverem vencidos. O brilho é alterado diretamente no monitor, e os controles de mídia mantêm um card informativo próprio.
- **Design Minimalista Sem Emojis:**
  - Toda a navegação e controles utilizam estritamente ícones nativos (SF Symbols e Touch Bar Templates da Apple), como `chevron.left`, `slider.horizontal.3`, `xmark` e `sparkles`, eliminando textos redundantes e emojis.
- **Visualização Detalhada ao Toque:** Ao tocar em qualquer botão de modelo na Touch Bar, abre-se a tela de opções expandidas:
  - Botão de retorno (chevron esquerdo) para voltar à faixa principal.
  - Indicador com ícone oficial, nome do provedor e métrica disponível para aquela fonte.
  - Botão de ação rápida `Abrir <App>` em destaque azul para abrir a ferramenta correspondente.
  - Botão de alternância para o painel de controles de sistema.
  - Botão de atualização rápida e botão de fechar (`xmark`).
- **Botão no Control Strip:** Atalho com ícone `sparkles` fixado na lateral direita da Touch Bar física sobre qualquer aplicativo em primeiro plano.

### Barra de Menus e Janela de Controle
- O menu exibe os status atuais de cada assistente, o horário exato da última sincronização, atalhos para abrir as aplicações e opções de atualização manual.
- **Permanência em Segundo Plano:** Ao fechar a janela principal (pelo botão vermelho ou <kbd>⌘</kbd><kbd>W</kbd>), o app não é finalizado; ele continua ativo em segundo plano na barra de menus e na Touch Bar. Para encerrar de fato, utilize **Sair do CodeTouchBar** (<kbd>⌘</kbd><kbd>Q</kbd>) no menu da barra.

### Controle Avançado de Limites e Preferências
A janela de **Preferências…** agora é dividida em abas:
- **Aba Geral:**
  - Seleção de indicadores ativos na Touch Bar (Codex, Claude, Antigravity, Gemini, DeepSeek, Ollama, Perplexity).
  - Intervalo de atualização (15s, 30s, 1m, 2m ou 5m).
  - Abertura automática ao iniciar a sessão no macOS.
  - Opção para manter ativo na barra de menus ao fechar a janela.
- **Aba Controle de Limites:**
  - **Janela de Cota Preferencial:** escolha entre *Automático (Maior uso)*, *Sessão Atual (5h)* ou *Cota Semanal (7 dias)* para assistentes com múltiplos limites.
  - **Exibição do Antigravity:** alterne entre seleção automática e cota percentual.
  - **Limiares de Alerta Customizáveis:** configure o percentual para aviso (⚠️ de 50% a 80%) e alerta crítico (🚨 de 80% a 98%).
  - **Contagem Regressiva de Reset:** ative ou desative o temporizador (`· 4h50m`) na Touch Bar.
  - **Notificações Nativas:** receba notificações no macOS quando o uso atingir limites críticos para prevenir bloqueios.

As preferências do app nativo são salvas em `~/Library/Application Support/CodeTouchBar/settings.json`. O arquivo `config/native-settings.example.json` mostra o formato inicial; não é necessário criá-lo manualmente.

O app tenta executar os coletores com Python 3 encontrado em `/opt/homebrew/bin/python3`, `/usr/local/bin/python3` ou `/usr/bin/python3`. A chave opcional da DeepSeek API fica no Keychain do macOS; ela não é gravada em `settings.json`.

## Limite e compatibilidade

Para manter o atalho disponível enquanto outro aplicativo está em primeiro plano, o app usa funções privadas do macOS (`DFRFoundation`). A Apple não oferece uma API pública para esse comportamento global: a API pública `NSTouchBar` serve a Touch Bar do app em primeiro plano. Por isso, esta implementação pode deixar de funcionar após uma atualização do macOS e não é adequada para distribuição pela Mac App Store, que exige APIs públicas. Veja a [documentação oficial de NSTouchBar](https://developer.apple.com/documentation/appkit/nstouchbar) e as [regras de revisão da App Store](https://developer.apple.com/app-store/review/guidelines/).

O script assina o app localmente com assinatura ad hoc. Para distribuir um app fora da App Store com a experiência padrão do Gatekeeper, será necessário assinar com Developer ID e notarizar a versão distribuída, conforme a [documentação de notarização da Apple](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Painel web legado

O painel web existente ainda gera configuração para MTMR. Para usá-lo, instale o MTMR, execute `./open_settings.sh` e abra [http://127.0.0.1:4588](http://127.0.0.1:4588). Para reaplicar a configuração pelo Terminal, execute `./reload.sh`. Essa integração será substituída gradualmente pelo app nativo.

## Fontes e tipos de métricas

Os coletores produzem resultados estruturados com tipo, estado, fonte, horário da leitura e texto de exibição. Tipos diferentes não são convertidos em percentuais. O app não depende do Codenotch.

- **Codex:** usa a sessão local em `~/.codex/auth.json` e a rota privada de uso do ChatGPT. Essa rota pode mudar sem aviso; a documentação oficial indica o painel de uso e o comando `/status` como superfícies suportadas.
- **Claude:** lê `~/Library/Application Support/Claude/plan-usage-history.json` quando presente. O caminho e formato são internos ao Claude Desktop; sem esse arquivo, o card informa indisponibilidade.
- **Antigravity:** consulta o Language Server local (`RetrieveUserQuotaSummary`). Essa interface não é pública/documentada; valores em cache mostram idade e não disparam alertas como se fossem atuais.
- **Gemini Apps:** a cota pessoal não tem API pública de leitura documentada e aparece como indisponível. Quotas da Gemini Developer API por projeto Google Cloud são uma integração diferente e não estão misturadas à assinatura Gemini.
- **DeepSeek:** sem chave, mostra que a integração de API não está configurada. Com chave no Keychain, consulta `GET https://api.deepseek.com/user/balance` e exibe saldo monetário, não uma porcentagem de cota.
- **Ollama:** consulta a API local documentada (`127.0.0.1:11434/api/ps` e `/api/tags`) e informa modelos carregados/instalados.
- **Perplexity:** a cota pessoal Pro/Max aparece como indisponível. A Analytics API da Perplexity é uma integração Enterprise para uso organizacional/API, com dados agregados e atualização periódica.

## Arquitetura de Controles de Hardware

Os botões de controle na Touch Bar utilizam integrações diretas do macOS para garantir resposta instantânea sem exigir privilégios de Acessibilidade no sistema:
- **Brilho:** `DisplayServices.framework` lê e ajusta o monitor principal em passos de 1/16; se o serviço não estiver disponível, o app tenta a tecla do sistema.
- **Volume:** botões Mudo, Diminuir e Aumentar leem e ajustam a saída padrão via Core Audio HAL. O botão Mudo tenta a tecla do sistema quando a saída não expõe uma propriedade de mute.
- **Mídia:** `MediaRemote.framework` (`MRMediaRemoteSendCommand`) com dual trigger em AppleScript para Spotify e Apple Music.
- **ESC:** Tecla virtual 53 despachada simultaneamente para o `kCGHIDEventTap` e `kCGSessionEventTap`.

## Estrutura

- `macos/Sources/CodeTouchBarApp.m`: app nativo e integração global com a Touch Bar.
- `macos/build_app.sh`: gera e assina localmente `dist/CodeTouchBar.app`.
- `server.py`: servidor local e API do painel web legado.
- `builder.py`: transforma as preferências do painel web em `items.json` do MTMR.
- `web/`: interface de configuração e prévia da Touch Bar.
- `scripts/`: coletores de métricas dos provedores.
- `assets/`: imagens usadas na interface e na Touch Bar.
- `config/settings.example.json`: exemplo das preferências iniciais.
- `config/native-settings.example.json`: exemplo das preferências do app nativo.
- `scripts/metric.py`: formato estruturado comum dos resultados dos coletores.

`config/settings.json` guarda as preferências locais do painel legado e `config/items.json` é gerado por ele. Ambos são ignorados pelo Git para evitar publicar configurações específicas da máquina e caminhos locais. O app nativo compilado em `dist/` também é ignorado.

## Privacidade

O painel web legado escuta somente em `127.0.0.1`. Os coletores podem ler arquivos locais de autenticação ou consultar serviços dos provedores para obter métricas. Não compartilhe arquivos de autenticação nem publique tokens. As credenciais não fazem parte deste repositório.
