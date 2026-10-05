/**
 * NutriApp - backend (Google Apps Script Web App)
 * Passo 3: esqueleto com doGet (versão) e doPost (roteador de ações).
 * Login, token e dados entram nos próximos passos.
 */

const VERSION = '0.6.0';

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
      case 'listPlanos':
        return json_({ status: 'success', data: listPlanos_(req) });
      case 'getPlano':
        return json_({ status: 'success', data: getPlano_(req) });
      case 'savePlano':
        return json_({ status: 'success', data: savePlano_(req) });
      case 'deletePlano':
        return json_({ status: 'success', data: deletePlano_(req) });
      case 'listMedidasCaseiras':
        return json_({ status: 'success', data: listMedidasCaseiras_(req) });
      case 'saveMedidaCaseira':
        return json_({ status: 'success', data: saveMedidaCaseira_(req) });
      case 'deleteMedidaCaseira':
        return json_({ status: 'success', data: deleteMedidaCaseira_(req) });
      case 'saveAlimento':
        return json_({ status: 'success', data: saveAlimento_(req) });
      case 'getConfig':
        return json_({ status: 'success', data: getConfig_(req) });
      case 'saveConfig':
        return json_({ status: 'success', data: saveConfig_(req) });
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
  ensureRows_(sh, row);
  const rg = sh.getRange(row, 1, 1, h.length);
  rg.setNumberFormats([formats]);
  rg.setValues([values]);
}

/** Garante que a aba tenha linhas até 'ultima' (abas importadas vêm sem linhas sobrando). */
function ensureRows_(sh, ultima) {
  const max = sh.getMaxRows();
  if (ultima > max) sh.insertRowsAfter(max, ultima - max);
}

/** Grava vários objetos em linhas consecutivas a partir de 'inicio', numa única chamada. */
function writeRows_(sh, inicio, objs) {
  if (!objs.length) return;
  const h = headers_(sh);
  const values = objs.map(function (o) {
    return h.map(function (k) { return o[k] === undefined ? '' : o[k]; });
  });
  const formats = values.map(function (r) {
    return r.map(function (v) { return typeof v === 'string' ? '@' : 'General'; });
  });
  ensureRows_(sh, inicio + objs.length - 1);
  const rg = sh.getRange(inicio, 1, objs.length, h.length);
  rg.setNumberFormats(formats);
  rg.setValues(values);
}

/** Apaga linhas pelos números (de baixo para cima, agrupando as consecutivas). */
function deleteRows_(sh, numeros) {
  const n = numeros.slice().sort(function (a, b) { return b - a; });
  let i = 0;
  while (i < n.length) {
    let j = i;
    while (j + 1 < n.length && n[j + 1] === n[j] - 1) j++;
    sh.deleteRows(n[j], j - i + 1);
    i = j + 1;
  }
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

/* ===================== Alimentos próprios e medidas caseiras ===================== */

const SHEET_ALIMENTOS = 'alimentos';
const SHEET_MEDIDAS = 'medidas_caseiras';

/** Número validado: aceita número ou texto com vírgula. Vazio vira null (se não obrigatório). */
function numField_(v, campo, min, max, obrigatorio) {
  const vazio = String(v == null ? '' : v).trim() === '';
  const n = vazio ? null : num_(v);
  if (n === null || !isFinite(n)) {
    if (obrigatorio || !vazio) fail_('invalid_data', campo);
    return null;
  }
  if (n < min || n > max) fail_('invalid_data', campo);
  return n;
}

/** Data AAAA-MM-DD válida (ou vazio). */
function dataIso_(v, campo) {
  const s = str_(v, 10, campo);
  if (!s) return '';
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) fail_('invalid_data', campo);
  const dt = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  if (dt.getFullYear() !== Number(m[1]) || dt.getMonth() !== Number(m[2]) - 1 ||
      dt.getDate() !== Number(m[3])) fail_('invalid_data', campo);
  return s;
}

function porId_(rows, id) {
  return rows.filter(function (r) { return String(r.id) === id; })[0];
}

function publicAlimento_(r) {
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
}

/**
 * Cadastra ou edita um alimento PRÓPRIO (valores por 100 g). Alimentos da TACO
 * não podem ser alterados. Entrada: { alimento: { id?, nome, categoria, energia_kcal, ... } }
 */
function saveAlimento_(req) {
  auth_(req);
  const e = req.alimento || {};
  const d = {
    nome: str_(e.nome, 120, 'nome', true),
    categoria: str_(e.categoria, 60, 'categoria'),
    energia_kcal: numField_(e.energia_kcal, 'energia_kcal', 0, 1000, true),
    proteina_g: numField_(e.proteina_g, 'proteina_g', 0, 100, false),
    lipidios_g: numField_(e.lipidios_g, 'lipidios_g', 0, 100, false),
    carboidrato_g: numField_(e.carboidrato_g, 'carboidrato_g', 0, 100, false),
    fibra_g: numField_(e.fibra_g, 'fibra_g', 0, 100, false),
    sodio_mg: numField_(e.sodio_mg, 'sodio_mg', 0, 50000, false)
  };
  Object.keys(d).forEach(function (k) { if (d[k] === null) d[k] = ''; });

  return withLock_(function () {
    const sh = table_(SHEET_ALIMENTOS);
    let id = String(e.id || '');
    let acao;
    if (id) {
      const atual = porId_(readRows_(SHEET_ALIMENTOS), id);
      if (!atual) fail_('not_found');
      if (String(atual.origem) !== 'PROPRIO') fail_('forbidden');
      writeRow_(sh, atual._row, Object.assign({}, atual, d));
      acao = 'editar_alimento';
    } else {
      id = 'PROPRIO-' + Utilities.getUuid();
      writeRow_(sh, sh.getLastRow() + 1, Object.assign({ id: id, origem: 'PROPRIO' }, d));
      acao = 'criar_alimento';
    }
    audit_(USER_LABEL, acao, SHEET_ALIMENTOS, id, '');
    return { alimento: publicAlimento_(porId_(readRows_(SHEET_ALIMENTOS), id)) };
  });
}

function publicMedida_(r) {
  return {
    id: String(r.id),
    alimento_id: String(r.alimento_id),
    descricao: String(r.descricao || ''),
    gramas: num_(r.gramas)
  };
}

/** Todas as medidas caseiras (a tabela é pequena; o app guarda em memória). */
function listMedidasCaseiras_(req) {
  auth_(req);
  const lista = readRows_(SHEET_MEDIDAS)
    .filter(function (r) { return r.id; })
    .map(publicMedida_);
  return { medidas: lista };
}

/** Cadastra ou edita uma medida caseira: { medida: { id?, alimento_id, descricao, gramas } } */
function saveMedidaCaseira_(req) {
  auth_(req);
  const e = req.medida || {};
  const alimentoId = str_(e.alimento_id, 64, 'alimento_id', true);
  const descricao = str_(e.descricao, 60, 'descricao', true);
  const gramas = numField_(e.gramas, 'gramas', 0.1, 5000, true);

  return withLock_(function () {
    if (!porId_(readRows_(SHEET_ALIMENTOS), alimentoId)) fail_('not_found', 'alimento_id');
    const sh = table_(SHEET_MEDIDAS);
    const todas = readRows_(SHEET_MEDIDAS);
    let id = String(e.id || '');
    const chave = descricao.toLowerCase();
    const duplicada = todas.some(function (r) {
      return String(r.alimento_id) === alimentoId && String(r.descricao).toLowerCase() === chave &&
        String(r.id) !== id;
    });
    if (duplicada) fail_('duplicate', 'descricao');

    const dados = { alimento_id: alimentoId, descricao: descricao, gramas: gramas };
    let acao;
    if (id) {
      const atual = porId_(todas, id);
      if (!atual) fail_('not_found');
      writeRow_(sh, atual._row, Object.assign({}, atual, dados));
      acao = 'editar_medida_caseira';
    } else {
      id = 'MC-' + Utilities.getUuid();
      writeRow_(sh, sh.getLastRow() + 1, Object.assign({ id: id }, dados));
      acao = 'criar_medida_caseira';
    }
    audit_(USER_LABEL, acao, SHEET_MEDIDAS, id, '');
    return { medida: publicMedida_(porId_(readRows_(SHEET_MEDIDAS), id)) };
  });
}

/** Apaga uma medida caseira, se nenhum item de plano ou substituição a usa. */
function deleteMedidaCaseira_(req) {
  auth_(req);
  const id = str_(req.id, 64, 'id', true);
  return withLock_(function () {
    const atual = porId_(readRows_(SHEET_MEDIDAS), id);
    if (!atual) fail_('not_found');
    const usada = readRows_(SHEET_ITENS).concat(readRows_(SHEET_SUBST)).some(function (r) {
      return String(r.medida_caseira_id) === id;
    });
    if (usada) fail_('in_use');
    deleteRows_(table_(SHEET_MEDIDAS), [atual._row]);
    audit_(USER_LABEL, 'apagar_medida_caseira', SHEET_MEDIDAS, id, '');
    return { apagado: true };
  });
}

/* ===================== Planos alimentares ===================== */

const SHEET_PLANOS = 'planos';
const SHEET_REFEICOES = 'refeicoes';
const SHEET_ITENS = 'itens_refeicao';
const SHEET_SUBST = 'substituicoes';
const STATUS_PLANO = ['rascunho', 'ativo', 'encerrado'];
const MAX_REFEICOES = 12;
const MAX_ITENS_REFEICAO = 30;
const MAX_ITENS_PLANO = 200;

/** Valida a estrutura recebida (sem consultar a planilha). */
function validarPlano_(p) {
  const d = {};
  d.nome = str_(p.nome, 120, 'nome', true);
  d.data_inicio = dataIso_(p.data_inicio, 'data_inicio');
  d.data_fim = dataIso_(p.data_fim, 'data_fim');
  if (d.data_inicio && d.data_fim && d.data_fim < d.data_inicio) fail_('invalid_data', 'data_fim');
  d.meta_kcal = numField_(p.meta_kcal, 'meta_kcal', 0, 10000, false);
  d.status = str_(p.status || 'rascunho', 20, 'status');
  if (STATUS_PLANO.indexOf(d.status) < 0) fail_('invalid_data', 'status');
  d.observacoes = str_(p.observacoes, 2000, 'observacoes');

  const refs = Array.isArray(p.refeicoes) ? p.refeicoes : [];
  if (refs.length > MAX_REFEICOES) fail_('invalid_data', 'refeicoes');
  let total = 0;
  d.refeicoes = refs.map(function (r) {
    r = r || {};
    const horario = str_(r.horario, 5, 'horario');
    if (horario && !/^([01]\d|2[0-3]):[0-5]\d$/.test(horario)) fail_('invalid_data', 'horario');
    const itens = Array.isArray(r.itens) ? r.itens : [];
    if (itens.length > MAX_ITENS_REFEICAO) fail_('invalid_data', 'itens');
    total += itens.length;
    if (total > MAX_ITENS_PLANO) fail_('invalid_data', 'itens');
    return {
      id: str_(r.id, 64, 'id'),
      nome: str_(r.nome, 60, 'refeicao_nome', true),
      horario: horario,
      observacoes: str_(r.observacoes, 500, 'observacoes'),
      itens: itens.map(function (it) {
        it = it || {};
        return {
          id: str_(it.id, 64, 'id'),
          alimento_id: str_(it.alimento_id, 64, 'alimento_id', true),
          medida_caseira_id: str_(it.medida_caseira_id, 64, 'medida_caseira_id'),
          quantidade: numField_(it.quantidade, 'quantidade', 0.1, 5000, true),
          observacoes: str_(it.observacoes, 200, 'observacoes')
        };
      })
    };
  });
  return d;
}

function publicPlano_(p, refeicoes) {
  const o = {
    id: String(p.id),
    paciente_id: String(p.paciente_id),
    nome: String(p.nome || ''),
    data_inicio: String(p.data_inicio || ''),
    data_fim: String(p.data_fim || ''),
    meta_kcal: num_(p.meta_kcal),
    status: String(p.status || 'rascunho'),
    observacoes: String(p.observacoes || ''),
    criado_em: String(p.criado_em || ''),
    atualizado_em: String(p.atualizado_em || '')
  };
  if (refeicoes) o.refeicoes = refeicoes;
  return o;
}

/** Monta o plano completo (refeições e itens) a partir das linhas das abas. */
function arvorePlano_(p, todasRef, todosItens) {
  const id = String(p.id);
  const refs = todasRef.filter(function (r) { return String(r.plano_id) === id; })
    .sort(function (a, b) { return Number(a.ordem) - Number(b.ordem); });
  const mapa = {};
  refs.forEach(function (r) { mapa[String(r.id)] = []; });
  todosItens.forEach(function (it) {
    const k = String(it.refeicao_id);
    if (mapa[k]) {
      mapa[k].push({
        id: String(it.id),
        alimento_id: String(it.alimento_id),
        medida_caseira_id: String(it.medida_caseira_id || ''),
        quantidade: num_(it.quantidade),
        gramas: num_(it.gramas),
        observacoes: String(it.observacoes || '')
      });
    }
  });
  return publicPlano_(p, refs.map(function (r) {
    return {
      id: String(r.id),
      nome: String(r.nome || ''),
      horario: String(r.horario || ''),
      ordem: Number(r.ordem) || 0,
      observacoes: String(r.observacoes || ''),
      itens: mapa[String(r.id)]
    };
  }));
}

/** Lista os planos de um paciente (sem refeições), com contagem de refeições. */
function listPlanos_(req) {
  auth_(req);
  const pid = str_(req.paciente_id, 64, 'paciente_id', true);
  const refs = readRows_(SHEET_REFEICOES);
  const lista = readRows_(SHEET_PLANOS)
    .filter(function (p) { return p.id && String(p.paciente_id) === pid; })
    .map(function (p) {
      const o = publicPlano_(p);
      o.total_refeicoes = refs.filter(function (r) { return String(r.plano_id) === o.id; }).length;
      return o;
    });
  lista.sort(function (a, b) { return b.criado_em < a.criado_em ? -1 : b.criado_em > a.criado_em ? 1 : 0; });
  return { planos: lista };
}

function getPlano_(req) {
  auth_(req);
  const id = str_(req.id, 64, 'id', true);
  const p = porId_(readRows_(SHEET_PLANOS), id);
  if (!p) fail_('not_found');
  return { plano: arvorePlano_(p, readRows_(SHEET_REFEICOES), readRows_(SHEET_ITENS)) };
}

/**
 * Cria ou edita um plano inteiro (plano + refeições + itens) numa única chamada.
 * Entrada: { plano: { id?, paciente_id, nome, data_inicio, data_fim, meta_kcal, status,
 *   observacoes, refeicoes: [ { id?, nome, horario, observacoes,
 *   itens: [ { id?, alimento_id, medida_caseira_id?, quantidade, observacoes } ] } ] } }
 * As gramas de cada item são calculadas aqui (quantidade x gramas da medida caseira).
 */
function savePlano_(req) {
  auth_(req);
  const e = req.plano || {};
  const d = validarPlano_(e);

  return withLock_(function () {
    const agora = new Date().toISOString();
    const shP = table_(SHEET_PLANOS);
    const shR = table_(SHEET_REFEICOES);
    const shI = table_(SHEET_ITENS);

    const alimentos = {};
    readRows_(SHEET_ALIMENTOS).forEach(function (a) { if (a.id) alimentos[String(a.id)] = true; });
    const medidas = {};
    readRows_(SHEET_MEDIDAS).forEach(function (m) {
      if (m.id) medidas[String(m.id)] = { alimento_id: String(m.alimento_id), gramas: num_(m.gramas) };
    });

    let id = String(e.id || '');
    let atual = null;
    let pacienteId;
    if (id) {
      atual = porId_(readRows_(SHEET_PLANOS), id);
      if (!atual) fail_('not_found');
      pacienteId = String(atual.paciente_id);
    } else {
      pacienteId = str_(e.paciente_id, 64, 'paciente_id', true);
      if (!porId_(readRows_(SHEET_PACIENTES), pacienteId)) fail_('not_found', 'paciente_id');
      id = Utilities.getUuid();
    }

    // linhas atuais do plano (para reaproveitar ids e depois apagar as antigas)
    const refsAntigas = atual
      ? readRows_(SHEET_REFEICOES).filter(function (r) { return String(r.plano_id) === id; }) : [];
    const idsRefAntigas = {};
    refsAntigas.forEach(function (r) { idsRefAntigas[String(r.id)] = true; });
    const itensAntigos = atual
      ? readRows_(SHEET_ITENS).filter(function (it) { return idsRefAntigas[String(it.refeicao_id)]; }) : [];
    const idsItensAntigos = {};
    itensAntigos.forEach(function (it) { idsItensAntigos[String(it.id)] = true; });

    // monta as linhas novas (valida alimentos/medidas e calcula gramas)
    const usadosR = {};
    const usadosI = {};
    const novasRef = [];
    const novosItens = [];
    d.refeicoes.forEach(function (r, i) {
      let rid = r.id;
      if (!rid || !idsRefAntigas[rid] || usadosR[rid]) rid = Utilities.getUuid();
      usadosR[rid] = true;
      novasRef.push({ id: rid, plano_id: id, nome: r.nome, horario: r.horario,
        ordem: i + 1, observacoes: r.observacoes });
      r.itens.forEach(function (it) {
        if (!alimentos[it.alimento_id]) fail_('not_found', 'alimento_id');
        let g = it.quantidade;
        if (it.medida_caseira_id) {
          const m = medidas[it.medida_caseira_id];
          if (!m) fail_('not_found', 'medida_caseira_id');
          if (m.alimento_id !== it.alimento_id) fail_('invalid_data', 'medida_caseira_id');
          g = it.quantidade * m.gramas;
        }
        g = Math.round(g * 10) / 10;
        if (!(g > 0) || g > 5000) fail_('invalid_data', 'quantidade');
        let iid = it.id;
        if (!iid || !idsItensAntigos[iid] || usadosI[iid]) iid = Utilities.getUuid();
        usadosI[iid] = true;
        novosItens.push({ id: iid, refeicao_id: rid, alimento_id: it.alimento_id,
          medida_caseira_id: it.medida_caseira_id, quantidade: it.quantidade, gramas: g,
          observacoes: it.observacoes });
      });
    });

    // grava o plano
    const campos = { paciente_id: pacienteId, nome: d.nome, data_inicio: d.data_inicio,
      data_fim: d.data_fim, meta_kcal: d.meta_kcal === null ? '' : d.meta_kcal,
      status: d.status, observacoes: d.observacoes, atualizado_em: agora };
    if (atual) {
      writeRow_(shP, atual._row, Object.assign({}, atual, campos));
    } else {
      writeRow_(shP, shP.getLastRow() + 1, Object.assign({ id: id, criado_em: agora }, campos));
    }

    // grava as linhas novas primeiro e só depois apaga as antigas
    writeRows_(shR, shR.getLastRow() + 1, novasRef);
    writeRows_(shI, shI.getLastRow() + 1, novosItens);
    deleteRows_(shI, itensAntigos.map(function (r) { return r._row; }));
    deleteRows_(shR, refsAntigas.map(function (r) { return r._row; }));

    // A auditoria registra só ids e contagens, nunca o conteúdo do plano.
    audit_(USER_LABEL, atual ? 'editar_plano' : 'criar_plano', SHEET_PLANOS, id,
      'refeicoes=' + novasRef.length + ',itens=' + novosItens.length);

    const salvo = porId_(readRows_(SHEET_PLANOS), id);
    return { plano: arvorePlano_(salvo, readRows_(SHEET_REFEICOES), readRows_(SHEET_ITENS)) };
  });
}

/** Apaga um plano (só se estiver como rascunho), com refeições, itens e substituições. */
function deletePlano_(req) {
  auth_(req);
  const id = str_(req.id, 64, 'id', true);
  return withLock_(function () {
    const p = porId_(readRows_(SHEET_PLANOS), id);
    if (!p) fail_('not_found');
    if (String(p.status) !== 'rascunho') fail_('forbidden');
    const refs = readRows_(SHEET_REFEICOES).filter(function (r) { return String(r.plano_id) === id; });
    const idsRef = {};
    refs.forEach(function (r) { idsRef[String(r.id)] = true; });
    const itens = readRows_(SHEET_ITENS).filter(function (it) { return idsRef[String(it.refeicao_id)]; });
    const idsItem = {};
    itens.forEach(function (it) { idsItem[String(it.id)] = true; });
    const subs = readRows_(SHEET_SUBST).filter(function (s) { return idsItem[String(s.item_refeicao_id)]; });

    deleteRows_(table_(SHEET_SUBST), subs.map(function (r) { return r._row; }));
    deleteRows_(table_(SHEET_ITENS), itens.map(function (r) { return r._row; }));
    deleteRows_(table_(SHEET_REFEICOES), refs.map(function (r) { return r._row; }));
    deleteRows_(table_(SHEET_PLANOS), [p._row]);
    audit_(USER_LABEL, 'apagar_plano', SHEET_PLANOS, id,
      'refeicoes=' + refs.length + ',itens=' + itens.length);
    return { apagado: true };
  });
}

/* ===================== Configurações da profissional ===================== */

const CONFIG_CAMPOS = [
  { campo: 'nome', chave: 'PROF_NOME', max: 120 },
  { campo: 'crn', chave: 'PROF_CRN', max: 40 },
  { campo: 'contato', chave: 'PROF_CONTATO', max: 120 }
];

/** Dados da profissional que saem no cabeçalho do PDF (guardados nas propriedades do script). */
function getConfig_(req) {
  auth_(req);
  const p = props_();
  const cfg = {};
  CONFIG_CAMPOS.forEach(function (c) { cfg[c.campo] = p.getProperty(c.chave) || ''; });
  return { config: cfg };
}

/** Entrada: { config: { nome, crn, contato } } */
function saveConfig_(req) {
  auth_(req);
  const e = req.config || {};
  const novo = {};
  CONFIG_CAMPOS.forEach(function (c) { novo[c.campo] = str_(e[c.campo], c.max, c.campo); });
  return withLock_(function () {
    const p = props_();
    const mudou = [];
    CONFIG_CAMPOS.forEach(function (c) {
      if ((p.getProperty(c.chave) || '') !== novo[c.campo]) mudou.push(c.campo);
      if (novo[c.campo]) p.setProperty(c.chave, novo[c.campo]); else p.deleteProperty(c.chave);
    });
    audit_(USER_LABEL, 'editar_configuracao', '', '', mudou.join(','));
    return { config: novo };
  });
}
