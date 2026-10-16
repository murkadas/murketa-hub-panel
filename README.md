# Murketa Hub — painel privado de keys

Painel web com tema de galáxia roxa para geração e gerenciamento de licenças. O site não mostra dados sem login; as operações administrativas usam sessão HttpOnly e o segredo não vai para o navegador.

## Recursos

- geração de keys com validade em horas, dias, semanas ou permanente;
- vinculação automática de uma HWID no primeiro `/activate`;
- bloqueio de uma segunda HWID;
- listagem, busca, status, tempo restante, revogação e reset de HWID;
- armazenamento de keys com hash para validação e cifra AES-GCM para cópia administrativa;
- frontend sem dependências externas, com animações e layout responsivo.

## Rodar localmente

```powershell
Copy-Item .env.example .env
# edite .env e troque KEY_SECRET e ADMIN_SECRET
npm start
```

Abra `http://localhost:3000` e entre com `ADMIN_SECRET`.

## Script Roblox

O endpoint de validação é:

```text
POST https://SEU-DOMINIO/activate
```

O bloco do script deve enviar JSON com `key` e `hwid`. A primeira ativação vincula a HWID; uma diferente recebe `HWID_MISMATCH`.

## Produção

Para compradores externos, publique este projeto em um serviço cloud ou VPS com HTTPS. Não use `localhost` no script do comprador. Configure um volume persistente para `keys.json`; sem isso, um redeploy pode apagar as licenças.
