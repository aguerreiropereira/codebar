# Fontes de métricas sem Codenotch

Pesquisa realizada em 25 de outubro de 2026. O objetivo é definir fontes independentes para os coletores e evitar que uma única aplicação local agregadora seja necessária para obter métricas.

## Resumo

Os provedores não expõem todos o mesmo tipo de métrica nem uma interface automatizada suportada. O app precisa parar de tratar toda resposta como uma porcentagem de cota. Algumas fontes entregam cota de plano; outras entregam saldo de API, uso de projeto ou apenas disponibilidade local.

| Provedor / produto | Fonte independente encontrada | Suporte e limites | Direção proposta |
| --- | --- | --- | --- |
| Codex com plano ChatGPT | CLI do Codex (`/status`) e painel de uso do ChatGPT; o coletor atual também consulta o endpoint `chatgpt.com/backend-api/codex/usage` usando a sessão local do Codex | A interface documentada é manual. O endpoint chamado pelo coletor é um endpoint privado, sem contrato público localizado nesta pesquisa. | Manter a leitura direta isolada e tolerante a mudanças, ou indicar indisponibilidade se o endpoint deixar de funcionar. Não voltar a consultar Codenotch. |
| Claude com plano Claude/Claude Code | Histórico local do Claude Desktop (`plan-usage-history.json`), já usado pelo coletor | O formato e o caminho do histórico não aparecem como interface pública documentada. A API oficial de Usage and Cost mede tráfego da API Anthropic da organização, não a cota de assinatura pessoal do Claude. | Manter o adaptador local, validar schema e idade dos dados; não usar a API da Anthropic como substituto da cota de assinatura. |
| Antigravity | Language Server local, método `RetrieveUserQuotaSummary`, já consultado pelo coletor | É uma interface interna do Language Server, não documentada como API pública. A ajuda oficial aponta o app e seu seletor de modelos/configurações como lugar para conferir uso. | Manter como adaptador privado, sem fallback Codenotch; guardar cache com timestamp e identificar claramente dados antigos. |
| Gemini Apps (assinatura pessoal) | Página de limites de uso no app Gemini | A documentação oficial descreve limites computacionais, janelas de 5 horas e limites semanais, e manda consultar as configurações do app. Não foi encontrada uma API pública para ler o saldo restante. | Não automatizar chamadas internas do site sem uma decisão explícita; exibir indisponível até haver uma fonte sustentável. |
| Gemini Developer API (projeto) | AI Studio e quotas/telemetria do projeto Google Cloud | É outra métrica: limites de RPM/TPM/RPD e consumo do projeto, não a cota pessoal do Gemini Apps. Acesso automatizado exige projeto e permissões Google Cloud. | Oferecer integração opcional separada, baseada em projeto e OAuth/ADC; apresentar quota de API como tal, nunca como cota da assinatura Gemini. |
| DeepSeek API | `GET https://api.deepseek.com/user/balance` com uma API key | API oficial documentada retorna saldo monetário disponível (`USD`/`CNY`) e se há saldo suficiente. Não retorna percentual de cota ou janela de reset. | Substituir o coletor por estado de saldo, com API key opcional guardada no Keychain; não inventar um percentual de uso. |
| DeepSeek Chat (assinatura) | Nenhuma API pública de cota pessoal encontrada | A API de saldo acima pertence à plataforma de desenvolvedores e não representa limites do app/web DeepSeek. | Mostrar indisponível para cota de Chat até existir interface documentada; não misturar com saldo da API. |
| Ollama local | `GET http://127.0.0.1:11434/api/ps` e `/api/tags` | API local documentada; mostra modelos carregados, memória/VRAM e modelos instalados. Não é uma cota remota. | Manter independente; classificar como estado local/modelos, não como porcentagem de consumo de cota. |
| Perplexity Pro/Max (app) | Informações de limites e uso no produto Perplexity | A ajuda oficial explica que limites variam por plano e que o uso Pro é limitado/variável. Não foi encontrada API pública para o saldo pessoal de pesquisas. | Não depender de endpoint interno do site; mostrar indisponível para a cota da assinatura até existir uma fonte suportada. |
| Perplexity API Platform | Painel de faturamento e Analytics API | A API Analytics oficial oferece uso organizacional para clientes Enterprise com uma chave de organização habilitada por administrador. Os dados são agregados em janelas de 1h/1d, sincronizados periodicamente e não representam saldo de assinatura Pro/Max nem cota em tempo real. | Oferecer integração opcional Enterprise para uso da API, separada do cartão de Perplexity Pro. Para API pessoal sem Analytics Enterprise, manter sem métrica automática até existir um endpoint documentado de saldo. |

## Evidências por provedor

### OpenAI Codex

A documentação de ajuda orienta a conferir limites e reset no painel de uso e, durante uma sessão do Codex CLI, usar `/status`. A documentação também menciona a Compliance API para logs de uso de Codex em workspaces, que não equivale a uma API pessoal de saldo de cota. O coletor atual tem uma alternativa direta para a sessão em `~/.codex/auth.json`, mas usa uma rota `backend-api` do ChatGPT; classificamos essa rota como privada porque não encontramos contrato público para ela.

Fontes: [Using Codex with your ChatGPT plan](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan), [ChatGPT Work and Codex](https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex).

### Anthropic Claude

O coletor já lê o histórico local do Claude Desktop e depois consulta Codenotch. A API oficial Usage and Cost oferece relatórios de tokens/custos da organização para tráfego da Claude Platform e requer credencial administrativa; a própria documentação separa esses dados do plano pessoal Claude/Claude Code. Não devemos transformar esses relatórios em percentual de cota de assinatura.

Fontes: [Usage and Cost API](https://platform.claude.com/docs/en/manage-claude/usage-cost-api), [Get Messages Usage Report](https://platform.claude.com/docs/en/api/beta/organization/usage_report/retrieve_messages), [Set up Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started).

### Google Antigravity e Gemini

O coletor Antigravity já conversa com o servidor de linguagem local para obter grupos e janelas de cota. Isso remove a necessidade funcional do agregador, porém a rota protobuf usada não é publicada como API suportada. A documentação pública de Antigravity direciona o usuário ao app, onde a seleção de modelos exibe consumo. Manteremos esse caminho sujeito a mudanças e trataremos cache como cache, incluindo sua idade.

Para Gemini Apps, a documentação oficial informa que os limites são computacionais, variam por plano/uso e renovam por janelas de cinco horas até o limite semanal; a página de uso fica dentro do app. Para Gemini API, AI Studio exibe as quotas ativas e Google Cloud fornece visualização e telemetria de quotas por projeto. Essas métricas não representam a cota do produto Gemini Apps.

Fontes: [Google Antigravity in Gemini Apps](https://support.google.com/googleone/answer/14534406), [Gemini Apps limits](https://support.google.com/gemini/answer/16275805), [Gemini API rate limits](https://ai.google.dev/gemini-api/docs/rate-limits), [Google Cloud quota monitoring](https://docs.cloud.google.com/docs/quotas/view-manage), [Gemini API Cloud Monitoring metrics](https://docs.cloud.google.com/monitoring/api/metrics_gcp_d_h).

### DeepSeek

O endpoint oficial `GET /user/balance` retorna se o saldo da conta API é suficiente e os saldos promocional/recarregado por moeda. Não informa uso percentual, limite de assinatura DeepSeek Chat nem data de reset. Usá-lo exige uma API key, portanto a chave deve ser opcional e guardada no Keychain, não em `settings.json` ou no repositório.

Fontes: [Get User Balance](https://api-docs.deepseek.com/api/get-user-balance/), [DeepSeek API error codes](https://api-docs.deepseek.com/quick_start/error_codes/).

### Ollama

Ollama possui endpoints locais documentados para modelos em execução e instalados. `/api/ps` retorna nome, tamanho em memória/VRAM e outras informações dos modelos carregados. Isso já satisfaz o objetivo sem credenciais ou serviço externo.

Fonte: [Ollama List running models](https://docs.ollama.com/api/ps).

### Perplexity

A documentação de planos distingue o produto de assinatura Perplexity (web/app) da API Platform para desenvolvedores, que é cobrada separadamente. Os limites de Pro Search variam e são descritos como uso limitado/por semana; a página pública não define uma API para consultar o saldo pessoal. A documentação da Analytics API permite que organizações Enterprise consultem dados de créditos, volume de consultas e outros indicadores com uma chave de analytics própria. Os dados têm buckets completos de UTC e sincronização periódica, portanto não devem ser apresentados como cota pessoal do app nem como leitura em tempo real.

Fontes: [Perplexity plans](https://www.perplexity.ai/help-center/en/articles/11187416-which-perplexity-subscription-plan-is-right-for-you), [What is Perplexity Pro?](https://www.perplexity.ai/help-center/en/articles/10352901-what-is-perplexity-pro), [Projects & Billing](https://docs.perplexity.ai/docs/getting-started/projects), [Analytics API](https://docs.perplexity.ai/docs/admin/computer-analytics-api), [Rate Limits & Usage Tiers](https://docs.perplexity.ai/docs/admin/rate-limits-usage-tiers).

## Plano de implementação

1. **Definir um contrato comum de resultado.** Representar `quota`, `saldo`, `atividade local` e `indisponível` como tipos distintos; incluir origem, instante da amostra, validade/cache e janela de reset quando existente. A UI não deve deduzir `0%` de ausência de dados.
2. **Remover Codenotch dos coletores.** Retirar as consultas `127.0.0.1:4577` de todos os `*_status.py`, remover nomes de fonte do app nativo e atualizar README. O servidor do painel legado deve apenas chamar coletores locais.
3. **Consolidar fontes locais independentes.** Codex (sessão local + rota privada atual), Claude Desktop (histórico local), Antigravity (Language Server + cache datado) e Ollama (API local). Isolar cada protocolo em um adaptador pequeno, com parsing separado e erros explícitos.
4. **Adicionar integrações oficiais que precisam de credenciais.** DeepSeek API Balance com API key opcional no Keychain; Gemini API por projeto Google Cloud e credencial OAuth/ADC, em aba/configuração separada da assinatura Gemini Apps. Claude Usage Admin API pode ser opção para contas de API/org, sem misturar com Claude Pro/Max.
5. **Manter estados indisponíveis para cotas de consumidor sem API pública.** Gemini Apps, Perplexity Pro/Max e DeepSeek Chat não recebem uma porcentagem inventada nem chamadas não documentadas por padrão. A UI pode oferecer um link para a tela oficial de uso.
6. **Endurecer e validar a cobertura.** Testes com fixtures por adaptador para cada forma de resposta, casos offline/sem credencial, dados expirados e parsing inválido; confirmar com o app sem Codenotch ativo e verificar que nenhuma rota `4577` permanece no código.

## Decisões de produto pendentes para a próxima etapa

- Se o requisito é monitorar **assinaturas de consumidor** ou também **contas/API keys de desenvolvedor**. As fontes e unidades diferem para Codex, Claude, Gemini, DeepSeek e Perplexity.
- Se vale manter adaptadores privados de Codex e Antigravity sabendo que podem quebrar após atualização, ou exibir apenas a fonte manual/oficial nesses dois casos.
- Se o cartão de cada provedor deve mudar de porcentagem para estado contextual (por exemplo, saldo `US$ 12,40`, `2 modelos ativos` ou `Cota indisponível`).

## Critério de conclusão

O app continua mostrando estados úteis com Codenotch fechado ou desinstalado; não contém referências a `127.0.0.1:4577`; nunca mostra uma porcentagem como se fosse uma cota quando a fonte não fornece essa medida; e separa claramente métricas de assinatura, API paga e runtime local.

## Estado aplicado

- Removidas as chamadas a `127.0.0.1:4577` dos coletores e o link do painel legado.
- Coletores agora aceitam `--json` e devolvem `provider`, `kind`, `state`, `source`, `observed_at` e `badge`; o app nativo usa esse formato.
- Codex usa a sessão local com endpoint privado; Claude usa apenas o histórico local; Antigravity usa o Language Server local e identifica cache como antigo.
- Gemini Apps e Perplexity Pro/Max mostram indisponibilidade explícita. Ollama mostra atividade local, sem percentual fictício.
- DeepSeek consulta o saldo oficial da API quando uma chave opcional é salva no Keychain; o valor não é tratado como cota percentual.
- Permanecem como expansões opcionais, se houver credenciais/contas correspondentes: Gemini Developer API por projeto Cloud, Perplexity Analytics para Enterprise e Anthropic Usage API para organizações de API. Elas medem produtos diferentes das cotas pessoais.

## Nota sobre evidência

“Não foi encontrada API pública” significa que a documentação oficial consultada não descreve uma interface automatizada adequada ao tipo de cota em questão. É uma conclusão limitada à documentação pesquisada, não uma afirmação de que o fornecedor não possua nenhuma interface interna.
