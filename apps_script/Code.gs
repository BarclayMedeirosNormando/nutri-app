/**
 * NutriApp - backend (Google Apps Script Web App)
 * Passo 3: esqueleto com doGet (versão) e doPost (roteador de ações).
 * Login, token e dados entram nos próximos passos.
 */

const VERSION = '0.4.0';

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
      case 'listAlimentos':
        return json_({ status: 'success', data: listAlimentos_(req) });
      case 'listPacientes':
        return json_({ status: 'success', data: listPacientes_(req) });
      case 'savePaciente':
        return json_({ status: 'success', data: savePaciente_(req) });
      case 'archivePaciente':
        return json_({ status: 'success', data: archivePaciente_(req) });
      default:
        return json_({ status: 'error', code: 'unknown_action' });
    }
  } catch (err) {
    if (err && err.appCode) {
      return json_({ status: 'error', code: err.appCode, field: err.field || '' });
    }
    // Nunca devolver err.message ao cliente (pode revelar detalhes internos).
    console.error(err);
    return json_({ status: 'error', code: 'server_error' });
  }
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

/* ===================== Autenticação ===================== */

function fail_(code, field) { throw { appCode: code, field: field }; }
function props_() { return PropertiesService.getScriptProperties(); }

/**
 * Primeiro acesso: define a senha da profissional.
 * Só funciona enquanto não existe senha e com o código de configuração
 * (propriedade SETUP_CODE) que foi combinado fora do app.
 */
function setup_(req) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const p = props_();
    if (p.getProperty('PASSWORD_HASH')) fail_('already_configured');
    const code = p.getProperty('SETUP_CODE');
    if (!code || !safeEqual_(String(req.codigo || ''), code)) fail_('invalid_setup_code');
    const senha = String(req.senha || '');
    if (senha.length < MIN_PASSWORD_LEN) fail_('weak_password');
    const salt = Utilities.getUuid();
    p.setProperty('PASSWORD_SALT', salt);
    p.setProperty('PASSWORD_HASH', hashPassword_(senha, salt));
    p.deleteProperty('SETUP_CODE');
    audit_(USER_LABEL, 'setup', '', '', 'senha definida');
    return { configurado: true };
  } finally {
    lock.releaseLock();
  }
}

function login_(req) {
  const p = props_();
  const hash = p.getProperty('PASSWORD_HASH');
  if (!hash) fail_('not_configured');

  const cache = CacheService.getScriptCache();
  const fails = Number(cache.get('login_fails') || 0);
  if (fails >= MAX_FAILS) fail_('locked');

  const ok = safeEqual_(hashPassword_(String(req.senha || ''), p.getProperty('PASSWORD_SALT')), hash);
  if (!ok) {
    cache.put('login_fails', String(fails + 1), LOCK_SEC);
    audit_(USER_LABEL, 'login_falhou', '', '', 'tentativa ' + (fails + 1));
    fail_('invalid_credentials');
  }
  cache.remove('login_fails');
  const now = Math.floor(Date.now() / 1000);
  const token = signToken_({ sub: USER_LABEL, iat: now, exp: now + TOKEN_TTL_SEC });
  audit_(USER_LABEL, 'login', '', '', 'ok');
  return { token: token, expira_em: now + TOKEN_TTL_SEC, usuario: USER_LABEL };
}

/** Exige token válido; devolve o conteúdo do token. Use no início de toda ação protegida. */
function auth_(req) {
  const payload = verifyToken_(String(req.token || ''));
  if (!payload) fail_('unauthorized');
  return payload;
}

function hashPassword_(senha, salt) {
  let h = senha;
  for (let i = 0; i < HASH_ROUNDS; i++) h = hex_(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, salt + h));
  return h;
}

function hex_(bytes) {
  return bytes.map(function (b) { return ('0' + (b & 0xff).toString(16)).slice(-2); }).join('');
}

function safeEqual_(a, b) {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

function tokenSecret_() {
  const p = props_();
  let s = p.getProperty('TOKEN_SECRET');
  if (!s) { s = Utilities.getUuid() + Utilities.getUuid(); p.setProperty('TOKEN_SECRET', s); }
  return s;
}

function b64u_(x) { return x.replace(/=+$/, ''); }

function signToken_(payload) {
  const body = b64u_(Utilities.base64EncodeWebSafe(JSON.stringify(payload), Utilities.Charset.UTF_8));
  const sig = b64u_(Utilities.base64EncodeWebSafe(Utilities.computeHmacSha256Signature(body, tokenSecret_())));
  return body + '.' + sig;
}

function verifyToken_(token) {
  const parts = token.split('.');
  if (parts.length !== 2) return null;
  const expected = b64u_(Utilities.base64EncodeWebSafe(Utilities.computeHmacSha256Signature(parts[0], tokenSecret_())));
  if (!safeEqual_(parts[1], expected)) return null;
  try {
    let b = parts[0];
    while (b.length % 4) b += '=';
    const payload = JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(b)).getDataAsString());
    if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch (e) {
    return null;
  }
}

/* ===================== Auditoria ===================== */

/** Colunas da aba auditoria: id, data_hora, usuario, acao, aba, registro_id, detalhes */
function audit_(usuario, acao, aba, registroId, detalhes) {
  try {
    const sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('auditoria');
    sh.appendRow([Utilities.getUuid(), new Date(), usuario, acao, aba, registroId, detalhes]);
  } catch (e) {
    console.error('falha na auditoria', e);
  }
}

/* ===================== Utilidades de planilha ===================== */

function table_(name) {
  const sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(name);
  if (!sh) { console.error('aba ausente: ' + name); fail_('server_error'); }
  return sh;
}

function headers_(sh) {
  return sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0].map(String);
}

function norm_(v) {
  if (v instanceof Date) {
    return Utilities.formatDate(v, Session.getScriptTimeZone(), 'yyyy-MM-dd');
  }
  return v;
}

/** Lê todas as linhas de uma aba como objetos { coluna: valor, _row: nº da linha }. */
function readRows_(name) {
  const sh = table_(name);
  const last = sh.getLastRow();
  if (last < 2) return [];
  const h = headers_(sh);
  const vals = sh.getRange(2, 1, last - 1, h.length).getValues();
  return vals.map(function (r, i) {
    const o = { _row: i + 2 };
    h.forEach(function (k, j) { o[k] = norm_(r[j]); });
    return o;
  });
}

/** Grava um objeto numa linha. Textos vão como texto puro (não viram data nem fórmula). */
function writeRow_(sh, row, obj) {
  const h = headers_(sh);
  const values = h.map(function (k) { return obj[k] === undefined ? '' : obj[k]; });
  const formats = values.map(function (v) { return typeof v === 'string' ? '@' : 'General'; });
  const rg = sh.getRange(row, 1, 1, h.length);
  rg.setNumberFormats([formats]);
  rg.setValues([values]);
}

/** Executa fn com trava, para evitar escritas simultâneas na planilha. */
function withLock_(fn) {
  const lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try { return fn(); } finally { lock.releaseLock(); }
}

/* ===================== Pacientes ===================== */

const SHEET_PACIENTES = 'pacientes';
const SHEET_CONSENT = 'consentimentos';
const CONSENT_TIPO = 'tratamento_dados_saude';
const CONSENT_VERSAO = 'v1';
const CAMPOS_PACIENTE = ['nome', 'data_nascimento', 'sexo', 'telefone', 'email', 'objetivo', 'observacoes'];

/** paciente_id -> data do consentimento vigente (concedido e não revogado). */
function consentMap_() {
  const mapa = {};
  readRows_(SHEET_CONSENT).forEach(function (r) {
    if (r.tipo === CONSENT_TIPO && r.concedido === true && !r.revogado_em) {
      mapa[String(r.paciente_id)] = String(r.data_registro);
    }
  });
  return mapa;
}

function publicPaciente_(r, consent) {
  const id = String(r.id);
  return {
    id: id,
    nome: String(r.nome || ''),
    data_nascimento: String(r.data_nascimento || ''),
    sexo: String(r.sexo || ''),
    telefone: String(r.telefone || ''),
    email: String(r.email || ''),
    objetivo: String(r.objetivo || ''),
    observacoes: String(r.observacoes || ''),
    ativo: r.ativo !== false,
    criado_em: String(r.criado_em || ''),
    atualizado_em: String(r.atualizado_em || ''),
    consentimento_em: consent[id] || ''
  };
}

function str_(v, max, campo, obrigatorio) {
  const s = String(v == null ? '' : v).trim();
  if (obrigatorio && !s) fail_('invalid_data', campo);
  if (s.length > max) fail_('invalid_data', campo);
  return s;
}

function validarPaciente_(p) {
  const d = {};
  d.nome = str_(p.nome, 120, 'nome', true);

  d.data_nascimento = str_(p.data_nascimento, 10, 'data_nascimento');
  if (d.data_nascimento) {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(d.data_nascimento);
    if (!m) fail_('invalid_data', 'data_nascimento');
    const dt = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
    if (dt.getFullYear() !== Number(m[1]) || dt.getMonth() !== Number(m[2]) - 1 ||
        dt.getDate() !== Number(m[3]) || dt > new Date()) {
      fail_('invalid_data', 'data_nascimento');
    }
  }

  d.sexo = str_(p.sexo, 1, 'sexo');
  if (['', 'F', 'M', 'O'].indexOf(d.sexo) < 0) fail_('invalid_data', 'sexo');

  d.telefone = str_(p.telefone, 20, 'telefone');
  if (d.telefone && !/^[0-9+()\-\s]+$/.test(d.telefone)) fail_('invalid_data', 'telefone');

  d.email = str_(p.email, 120, 'email');
  if (d.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(d.email)) fail_('invalid_data', 'email');

  d.objetivo = str_(p.objetivo, 300, 'objetivo');
  d.observacoes = str_(p.observacoes, 2000, 'observacoes');
  return d;
}

function listPacientes_(req) {
  auth_(req);
  const incluir = req.incluirArquivados === true;
  const consent = consentMap_();
  const lista = readRows_(SHEET_PACIENTES)
    .filter(function (r) { return r.id && (incluir || r.ativo !== false); })
    .map(function (r) { return publicPaciente_(r, consent); });
  lista.sort(function (a, b) { return a.nome.localeCompare(b.nome, 'pt-BR'); });
  return { pacientes: lista };
}

function savePaciente_(req) {
  auth_(req);
  const entrada = req.paciente || {};
  const d = validarPaciente_(entrada);

  return withLock_(function () {
    const sh = table_(SHEET_PACIENTES);
    const agora = new Date().toISOString();
    let id = String(entrada.id || '');
    let acao;
    let campos;

    if (id) {
      const atual = readRows_(SHEET_PACIENTES).filter(function (r) { return String(r.id) === id; })[0];
      if (!atual) fail_('not_found');
      campos = CAMPOS_PACIENTE.filter(function (k) { return String(atual[k] || '') !== d[k]; });
      const novo = Object.assign({}, atual, d, { atualizado_em: agora });
      writeRow_(sh, atual._row, novo);
      acao = 'editar_paciente';
    } else {
      id = Utilities.getUuid();
      const novo = Object.assign({ id: id }, d, { ativo: true, criado_em: agora, atualizado_em: agora });
      writeRow_(sh, sh.getLastRow() + 1, novo);
      acao = 'criar_paciente';
      campos = ['(novo)'];
    }
    // A auditoria registra QUEM mudou O QUÊ (nomes de campos), nunca os valores.
    audit_(USER_LABEL, acao, SHEET_PACIENTES, id, campos.join(','));

    if (req.consentimento === true && !consentMap_()[id]) {
      const sc = table_(SHEET_CONSENT);
      writeRow_(sc, sc.getLastRow() + 1, {
        id: Utilities.getUuid(), paciente_id: id, tipo: CONSENT_TIPO,
        versao_texto: CONSENT_VERSAO, concedido: true, data_registro: agora, revogado_em: ''
      });
      audit_(USER_LABEL, 'registrar_consentimento', SHEET_CONSENT, id, CONSENT_VERSAO);
    }

    const salvo = readRows_(SHEET_PACIENTES).filter(function (r) { return String(r.id) === id; })[0];
    return { paciente: publicPaciente_(salvo, consentMap_()) };
  });
}

/** Arquiva (ativo=false) ou reativa um paciente. Não apaga nada. */
function archivePaciente_(req) {
  auth_(req);
  const id = String(req.id || '');
  if (!id) fail_('invalid_data', 'id');
  const arquivar = req.arquivar === true;

  return withLock_(function () {
    const sh = table_(SHEET_PACIENTES);
    const atual = readRows_(SHEET_PACIENTES).filter(function (r) { return String(r.id) === id; })[0];
    if (!atual) fail_('not_found');
    const novo = Object.assign({}, atual, { ativo: !arquivar, atualizado_em: new Date().toISOString() });
    writeRow_(sh, atual._row, novo);
    audit_(USER_LABEL, arquivar ? 'arquivar_paciente' : 'reativar_paciente', SHEET_PACIENTES, id, '');
    return { paciente: publicPaciente_(novo, consentMap_()) };
  });
}

/* ===================== Manutenção (só pelo editor) ===================== */

/**
 * ATENÇÃO: apaga TODOS os dados de pacientes (linhas 2 em diante) das abas abaixo.
 * Mantém cabeçalhos, a base de alimentos (alimentos, medidas_caseiras) e a senha.
 * Executar manualmente no editor do Apps Script. Não é acessível pelo app.
 * REMOVER ESTA FUNÇÃO antes de colocar o sistema em uso real.
 */
function zerarDadosDeTeste() {
  const abas = ['pacientes', 'consentimentos', 'consultas', 'medidas', 'planos', 'refeicoes',
    'itens_refeicao', 'substituicoes', 'diario_alimentar', 'mensagens', 'auditoria'];
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  abas.forEach(function (nome) {
    const sh = ss.getSheetByName(nome);
    if (sh && sh.getLastRow() > 1) sh.deleteRows(2, sh.getLastRow() - 1);
  });
}

/* ===================== Alimentos ===================== */

/** Converte célula numérica (número, texto com vírgula ou vazio) em número ou null. */
function num_(v) {
  if (typeof v === 'number') return v;
  const s = String(v == null ? '' : v).trim();
  if (!s) return null;
  const n = Number(s.replace(',', '.'));
  return isNaN(n) ? null : n;
}

/**
 * Devolve a tabela de alimentos inteira numa única chamada (o app guarda em
 * memória e no aparelho e faz os cálculos localmente). Valores em branco = null.
 */
function listAlimentos_(req) {
  auth_(req);
  const lista = readRows_('alimentos')
    .filter(function (r) { return r.id; })
    .map(function (r) {
      return {
        id: String(r.id),
        origem: String(r.origem || ''),
        nome: String(r.nome || ''),
        categoria: String(r.categoria || ''),
        energia_kcal: num_(r.energia_kcal),
        proteina_g: num_(r.proteina_g),
        lipidios_g: num_(r.lipidios_g),
        carboidrato_g: num_(r.carboidrato_g),
        fibra_g: num_(r.fibra_g),
        sodio_mg: num_(r.sodio_mg)
      };
    });
  return { alimentos: lista };
}
