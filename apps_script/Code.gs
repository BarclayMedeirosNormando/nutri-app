/**
 * NutriApp - backend (Google Apps Script Web App)
 * Passo 3: esqueleto com doGet (versão) e doPost (roteador de ações).
 * Login, token e dados entram nos próximos passos.
 */

const VERSION = '0.2.0';

const TOKEN_TTL_SEC = 8 * 3600;   // validade do token: 8 horas
const MAX_FAILS = 5;              // tentativas erradas antes de bloquear
const LOCK_SEC = 15 * 60;         // duração do bloqueio: 15 minutos
const HASH_ROUNDS = 2000;         // repetições do hash da senha
const MIN_PASSWORD_LEN = 10;
const USER_LABEL = 'profissional';

/** Teste de publicação: abrir o endereço /exec no navegador. */
function doGet() {
  return json_({ status: 'success', backend: VERSION });
}

/** Todas as chamadas do app: POST com JSON { action, token, ...dados } em text/plain. */
function doPost(e) {
  try {
    const req = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    switch (req.action) {
      case 'ping':
        return json_({ status: 'success', data: { pong: true, version: VERSION } });
      case 'setup':
        return json_({ status: 'success', data: setup_(req) });
      case 'login':
        return json_({ status: 'success', data: login_(req) });
      case 'me':
        return json_({ status: 'success', data: { usuario: auth_(req).sub } });
      default:
        return json_({ status: 'error', code: 'unknown_action' });
    }
  } catch (err) {
    if (err && err.appCode) return json_({ status: 'error', code: err.appCode });
    // Nunca devolver err.message ao cliente (pode revelar detalhes internos).
    console.error(err);
    return json_({ status: 'error', code: 'server_error' });
  }
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
