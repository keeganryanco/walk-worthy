import { DailyJourneyPackage } from "./types";
import { JourneyPackageRequest } from "./types";
import { deterministicReference, normalizeReference } from "./scripture";

const CHIP_MIN_WORDS = 2;
const CHIP_MAX_WORDS = 7;
const CHIP_MAX_LENGTH = 80;
const CHIP_LIMIT = 4;
const CHIP_FALLBACK_COUNT = 3;

type SupportedLanguageCode = "en" | "es" | "pt" | "de" | "ja" | "ko";

const DANGLING_ENDINGS_EN = new Set([
  "a",
  "an",
  "and",
  "at",
  "because",
  "for",
  "from",
  "in",
  "into",
  "of",
  "on",
  "or",
  "that",
  "the",
  "to",
  "toward",
  "towards",
  "with"
]);

const DANGLING_ENDINGS_ES = new Set([
  "a",
  "al",
  "con",
  "de",
  "del",
  "el",
  "en",
  "la",
  "las",
  "los",
  "o",
  "para",
  "por",
  "que",
  "un",
  "una",
  "y"
]);

const DANGLING_ENDINGS_PT = new Set([
  "a",
  "ao",
  "com",
  "da",
  "das",
  "de",
  "do",
  "dos",
  "e",
  "em",
  "o",
  "os",
  "ou",
  "para",
  "por",
  "que",
  "um",
  "uma"
]);

const DANGLING_ENDINGS_DE = new Set([
  "an",
  "am",
  "auf",
  "aus",
  "bei",
  "das",
  "dem",
  "den",
  "der",
  "die",
  "ein",
  "eine",
  "einem",
  "einen",
  "einer",
  "für",
  "im",
  "in",
  "mit",
  "oder",
  "um",
  "und",
  "von",
  "zu",
  "zum",
  "zur"
]);

const DANGLING_ENDINGS_JA = new Set([
  "を",
  "に",
  "へ",
  "で",
  "と",
  "や",
  "の",
  "が",
  "は",
  "も",
  "から",
  "まで"
]);

const DANGLING_ENDINGS_KO = new Set([
  "을",
  "를",
  "은",
  "는",
  "이",
  "가",
  "의",
  "에",
  "에서",
  "와",
  "과",
  "도",
  "로"
]);

const LEADING_FRAGMENT_WORDS_EN = new Set([
  "and",
  "because",
  "for",
  "if",
  "or",
  "so",
  "then",
  "to",
  "when",
  "while",
  "with"
]);

const LEADING_FRAGMENT_WORDS_ES = new Set([
  "con",
  "cuando",
  "mientras",
  "o",
  "para",
  "porque",
  "que",
  "si",
  "y"
]);

const LEADING_FRAGMENT_WORDS_PT = new Set([
  "com",
  "quando",
  "e",
  "enquanto",
  "ou",
  "para",
  "porque",
  "que",
  "se"
]);

const LEADING_FRAGMENT_WORDS_DE = new Set([
  "aber",
  "denn",
  "oder",
  "und",
  "wenn",
  "weil",
  "während",
  "mit",
  "für"
]);

const LEADING_FRAGMENT_WORDS_JA = new Set([
  "そして",
  "だから",
  "しかし",
  "または",
  "もし",
  "なぜなら",
  "けれども"
]);

const LEADING_FRAGMENT_WORDS_KO = new Set([
  "그리고",
  "그래서",
  "하지만",
  "또는",
  "만약",
  "왜냐하면",
  "그래도"
]);

const themeChipBankEn: Record<string, string[]> = {
  basic: ["Pray over one task", "Take one faithful step", "Complete one delayed task"],
  faith: ["Pray with full trust", "Write one trust statement", "Release one control area"],
  patience: ["Wait before reacting", "Choose one slow step", "Finish one lingering task"],
  peace: ["Take five calm breaths", "Pray through one worry", "Silence one distraction"],
  resilience: ["Do one hard thing", "Reframe one setback", "Ask for strength today"],
  community: ["Send one encouragement text", "Pray for one friend", "Schedule one check-in"],
  discipline: ["Set one focused block", "Remove one distraction", "Start before you feel ready"],
  healing: ["Name one honest feeling", "Take one gentle action", "Reach out for support"],
  joy: ["Write three gratitude lines", "Celebrate one small win", "Share one praise update"],
  wisdom: ["Pause and seek wisdom", "Write one wise next step", "Ask trusted counsel today"]
};

const themeChipBankEs: Record<string, string[]> = {
  basic: ["Ora por una tarea", "Da un paso fiel", "Termina una tarea pendiente"],
  faith: ["Ora con plena confianza", "Escribe una verdad de fe", "Entrega un área de control"],
  patience: ["Espera antes de reaccionar", "Elige un paso tranquilo", "Avanza una tarea atrasada"],
  peace: ["Respira profundo cinco veces", "Ora por una preocupación", "Silencia una distracción"],
  resilience: ["Haz algo difícil hoy", "Reformula un tropiezo", "Pide fuerzas para hoy"],
  community: ["Envía un mensaje de ánimo", "Ora por un amigo", "Agenda un seguimiento"],
  discipline: ["Define un bloque de enfoque", "Quita una distracción", "Empieza ahora mismo"],
  healing: ["Nombra una emoción real", "Da un paso de cuidado", "Pide apoyo hoy"],
  joy: ["Escribe tres gratitudes", "Celebra un pequeño avance", "Comparte una alabanza"],
  wisdom: ["Pausa y pide sabiduría", "Define un paso sabio", "Busca consejo confiable"]
};

const themeChipBankPt: Record<string, string[]> = {
  basic: ["Ore por uma tarefa", "Dê um passo fiel", "Conclua uma tarefa pendente"],
  faith: ["Ore com plena confiança", "Escreva uma verdade de fé", "Entregue uma área de controle"],
  patience: ["Espere antes de reagir", "Escolha um passo calmo", "Avance uma tarefa atrasada"],
  peace: ["Respire fundo cinco vezes", "Ore por uma preocupação", "Silencie uma distração"],
  resilience: ["Faça algo difícil hoje", "Reenquadre um tropeço", "Peça força para hoje"],
  community: ["Envie uma mensagem de incentivo", "Ore por um amigo", "Agende um acompanhamento"],
  discipline: ["Defina um bloco de foco", "Remova uma distração", "Comece agora mesmo"],
  healing: ["Nomeie uma emoção real", "Dê um passo de cuidado", "Peça apoio hoje"],
  joy: ["Escreva três gratidões", "Celebre um pequeno avanço", "Compartilhe um louvor"],
  wisdom: ["Pare e peça sabedoria", "Defina um passo sábio", "Busque conselho confiável"]
};

const themeChipBankDe: Record<string, string[]> = {
  basic: ["Bete über eine Aufgabe", "Tu einen treuen Schritt", "Erledige eine offene Aufgabe"],
  faith: ["Bete mit vollem Vertrauen", "Schreibe ein Glaubens-Statement", "Gib einen Kontrollbereich ab"],
  patience: ["Warte vor deiner Reaktion", "Wähle einen ruhigen Schritt", "Erledige eine liegen gebliebene Aufgabe"],
  peace: ["Atme fünfmal ruhig durch", "Bete über eine Sorge", "Schalte eine Ablenkung aus"],
  resilience: ["Tu heute etwas Schwieriges", "Deute einen Rückschlag neu", "Bitte heute um Kraft"],
  community: ["Sende eine ermutigende Nachricht", "Bete für einen Freund", "Plane ein kurzes Nachfassen"],
  discipline: ["Setze einen Fokus-Block", "Entferne eine Ablenkung", "Starte bevor du bereit bist"],
  healing: ["Benenne ein echtes Gefühl", "Tu einen fürsorglichen Schritt", "Bitte um Unterstützung"],
  joy: ["Schreibe drei Dankbarkeiten", "Feiere einen kleinen Fortschritt", "Teile ein Lob"],
  wisdom: ["Halte inne und bitte um Weisheit", "Schreibe den nächsten weisen Schritt", "Suche vertrauenswürdigen Rat"]
};

const themeChipBankJa: Record<string, string[]> = {
  basic: ["一つの課題のために祈る", "忠実な一歩を取る", "先延ばしの課題を終える"],
  faith: ["全き信頼で祈る", "信仰のことばを書き留める", "手放す領域を一つ決める"],
  patience: ["反応する前に待つ", "穏やかな一歩を選ぶ", "残っている課題を進める"],
  peace: ["ゆっくり5回深呼吸する", "不安を祈りに委ねる", "妨げを一つ静める"],
  resilience: ["難しいことを一つ行う", "つまずきを捉え直す", "今日の力を祈り求める"],
  community: ["励ましのメッセージを送る", "一人の友のために祈る", "短い連絡時間を決める"],
  discipline: ["集中ブロックを設定する", "妨げを一つ取り除く", "準備前でも始める"],
  healing: ["正直な感情を書き出す", "いたわりの一歩を取る", "支えを求める"],
  joy: ["感謝を3つ書く", "小さな前進を祝う", "賛美を分かち合う"],
  wisdom: ["立ち止まり知恵を求める", "知恵ある次の一歩を書く", "信頼できる助言を求める"]
};

const themeChipBankKo: Record<string, string[]> = {
  basic: ["한 가지 일로 기도하세요", "신실한 행동 하나를 하세요", "미뤄 둔 일 하나를 끝내세요"],
  faith: ["온전히 신뢰하며 기도하세요", "믿음의 고백을 적어 보세요", "통제를 내려놓을 영역을 정하세요"],
  patience: ["반응 전에 잠시 멈추세요", "차분한 한 걸음을 고르세요", "미룬 일 하나를 마무리하세요"],
  peace: ["천천히 다섯 번 숨 쉬세요", "걱정 하나를 두고 기도하세요", "방해 요소 하나를 끄세요"],
  resilience: ["어려운 일 하나를 하세요", "실패를 다시 해석해 보세요", "오늘의 힘을 구하세요"],
  community: ["격려 메시지 하나를 보내세요", "친구 한 명을 위해 기도하세요", "짧은 안부 시간을 정하세요"],
  discipline: ["집중 시간 블록을 정하세요", "방해 요소 하나를 제거하세요", "준비되기 전에 먼저 시작하세요"],
  healing: ["솔직한 감정을 적어 보세요", "돌봄 행동 하나를 하세요", "지원을 요청하세요"],
  joy: ["감사 세 가지를 적어 보세요", "작은 승리를 축하하세요", "찬양 제목 하나를 나누세요"],
  wisdom: ["잠시 멈추고 지혜를 구하세요", "지혜로운 다음 걸음을 적으세요", "신뢰할 조언을 구하세요"]
};

const contextualKeywordChipsEn: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(anx|worr|fear|stress|panic|calm|rest|peace)/i, chips: ["Pray through this worry", "Take five calm breaths"] },
  { pattern: /(focus|disciplin|habit|procrastin|delay|consisten)/i, chips: ["Start one focused block", "Finish one delayed task"] },
  { pattern: /(family|marriage|friend|relationship|team|community)/i, chips: ["Send one honest message", "Pray for this relationship"] },
  { pattern: /(money|financial|budget|debt|career|business|work)/i, chips: ["Review one key number", "Take one work action"] },
  { pattern: /(health|heal|grief|pain|recover|tired)/i, chips: ["Take one healing step", "Rest and pray ten minutes"] }
];

const contextualKeywordChipsEs: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(ansied|preocup|miedo|estr[eé]s|calma|descanso|paz)/i, chips: ["Ora por esta preocupación", "Respira y vuelve a orar"] },
  { pattern: /(enfoque|disciplina|h[aá]bito|procrastin|constancia|demora)/i, chips: ["Haz un bloque de enfoque", "Termina una tarea pendiente"] },
  { pattern: /(familia|matrimonio|amig|relaci[oó]n|comunidad)/i, chips: ["Envía un mensaje sincero", "Ora por esta relación"] },
  { pattern: /(dinero|financ|presupuesto|deuda|carrera|trabajo|negocio)/i, chips: ["Revisa un número clave", "Da un paso laboral hoy"] },
  { pattern: /(salud|sanidad|duelo|dolor|recuper)/i, chips: ["Da un paso de sanidad", "Descansa y ora diez minutos"] }
];

const contextualKeywordChipsPt: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(ansied|preocup|medo|estresse|calma|descanso|paz)/i, chips: ["Ore por esta preocupação", "Respire e ore novamente"] },
  { pattern: /(foco|disciplina|h[aá]bito|procrastin|const[aâ]ncia|atraso)/i, chips: ["Faça um bloco de foco", "Conclua uma tarefa pendente"] },
  { pattern: /(fam[ií]lia|casamento|amig|relacionamento|comunidade)/i, chips: ["Envie uma mensagem sincera", "Ore por este relacionamento"] },
  { pattern: /(dinheiro|financ|orçamento|d[ií]vida|carreira|trabalho|neg[oó]cio)/i, chips: ["Revise um número-chave", "Dê um passo no trabalho"] },
  { pattern: /(sa[uú]de|cura|luto|dor|recuper)/i, chips: ["Dê um passo de cuidado", "Descanse e ore dez minutos"] }
];

const contextualKeywordChipsDe: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(angst|sorge|furcht|stress|ruhe|frieden)/i, chips: ["Bete über diese Sorge", "Atme ruhig und bete neu"] },
  { pattern: /(fokus|disziplin|gewohnheit|aufschieb|konstanz)/i, chips: ["Starte einen Fokus-Block", "Erledige eine offene Aufgabe"] },
  { pattern: /(familie|ehe|freund|beziehung|gemeinschaft)/i, chips: ["Sende eine ehrliche Nachricht", "Bete für diese Beziehung"] },
  { pattern: /(geld|finanz|budget|schuld|karriere|arbeit|geschäft)/i, chips: ["Prüfe eine wichtige Zahl", "Tu heute einen Arbeitsschritt"] },
  { pattern: /(gesundheit|heil|trauer|schmerz|erholung)/i, chips: ["Tu einen fürsorglichen Schritt", "Ruh dich aus und bete zehn Minuten"] }
];

const contextualKeywordChipsJa: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(不安|心配|恐れ|ストレス|平安|休息)/i, chips: ["この不安を祈りに委ねる", "呼吸を整えて祈り直す"] },
  { pattern: /(集中|鍛錬|習慣|先延ばし|継続)/i, chips: ["集中ブロックを一つ作る", "先延ばしの課題を終える"] },
  { pattern: /(家族|結婚|友人|関係|共同体)/i, chips: ["誠実なメッセージを送る", "この関係のために祈る"] },
  { pattern: /(お金|財政|予算|借金|キャリア|仕事|事業)/i, chips: ["重要な数値を一つ見直す", "仕事の一歩を今日実行する"] },
  { pattern: /(健康|癒し|悲しみ|痛み|回復)/i, chips: ["いたわりの一歩を取る", "10分休んで祈る"] }
];

const contextualKeywordChipsKo: Array<{ pattern: RegExp; chips: string[] }> = [
  { pattern: /(불안|걱정|두려움|스트레스|평안|쉼)/i, chips: ["이 걱정을 두고 기도하세요", "천천히 숨을 고르세요"] },
  { pattern: /(집중|훈련|습관|미루|꾸준)/i, chips: ["집중 시간 블록을 시작하세요", "미뤄 둔 일 하나를 끝내세요"] },
  { pattern: /(가족|결혼|친구|관계|공동체)/i, chips: ["진심 담긴 메시지를 보내세요", "이 관계를 위해 기도하세요"] },
  { pattern: /(돈|재정|예산|빚|커리어|일|사업)/i, chips: ["핵심 수치 하나를 점검하세요", "일 관련 행동 하나를 하세요"] },
  { pattern: /(건강|치유|슬픔|통증|회복)/i, chips: ["돌봄 행동 하나를 하세요", "10분 쉬며 기도하세요"] }
];

const genericFallbackChipsEn = ["Pray and choose one step", "Take one faithful action", "Write today's next step"];
const genericFallbackChipsEs = ["Ora y elige un paso", "Da una acción fiel", "Escribe tu próximo paso"];
const genericFallbackChipsPt = ["Ore e escolha um passo", "Dê uma ação fiel", "Escreva seu próximo passo"];
const genericFallbackChipsDe = ["Bete und wähle einen Schritt", "Tu eine treue Handlung", "Schreibe deinen nächsten Schritt"];
const genericFallbackChipsJa = ["祈って一歩を選ぶ", "忠実な行動を一つ取る", "今日の次の一歩を書く"];
const genericFallbackChipsKo = ["기도하고 한 걸음을 고르세요", "신실한 행동 하나를 하세요", "오늘의 다음 걸음을 적으세요"];
const FIRST_PERSON_PRAYER_REGEX_EN = /\b(i|i'm|i’ve|i've|i’d|i'll|i’ll|me|my|mine|myself|we|we're|we’ve|we've|we’d|we'll|we’ll|us|our|ours|ourselves)\b/i;
const FIRST_PERSON_PRAYER_REGEX_ES = /\b(yo|mi|m[ií]o|m[ií]a|m[ií]os|m[ií]as|m[ií]|me|conmigo|nosotros|nosotras|nuestro|nuestra|nuestros|nuestras|nos)\b/i;
const FIRST_PERSON_PRAYER_REGEX_PT = /\b(eu|meu|minha|meus|minhas|mim|me|comigo|n[oó]s|nosso|nossa|nossos|nossas|nos)\b/i;
const FIRST_PERSON_PRAYER_REGEX_DE = /\b(ich|mich|mir|mein|meine|meinen|meinem|meiner|meines|wir|uns|unser|unsere|unseren|unserem|unserer)\b/i;
const FIRST_PERSON_PRAYER_REGEX_JA = /(私|わたし|僕|ぼく|俺|おれ|私たち|わたしたち|僕たち|ぼくたち|わたくし)/i;
const FIRST_PERSON_PRAYER_REGEX_KO = /(저|제|저는|제가|저를|저의|나|내|나는|내가|우리는|우리가|우리의)/i;
const FIRST_PERSON_REFLECTION_REGEX = /\b(i|i'm|i’ve|i've|i’d|i'll|i’ll|me|my|mine|myself|we|we're|we’ve|we've|we’d|we'll|we’ll|us|our|ours|ourselves)\b/i;
const FIRST_PERSON_REFLECTION_REGEX_DE = /\b(ich|mich|mir|mein|meine|meinen|meinem|meiner|meines|wir|uns|unser|unsere|unseren|unserem|unserer)\b/i;
const PROSE_END_REGEX = /[.!?]["')\]]?$/;
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_EN = [
  "the user",
  "this user",
  "for the user",
  "their journey",
  "his journey",
  "her journey"
];
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_ES = [
  "el usuario",
  "la usuaria",
  "este usuario",
  "esta usuaria",
  "su camino",
  "su jornada"
];
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_PT = [
  "o usuário",
  "a usuária",
  "este usuário",
  "esta usuária",
  "sua jornada",
  "o caminho do usuário"
];
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_DE = [
  "der nutzer",
  "die nutzerin",
  "dieser nutzer",
  "diese nutzerin",
  "seine journey",
  "ihre journey"
];
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_JA = ["ユーザー", "利用者", "このユーザー", "その人の旅", "彼らの旅路"];
const DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_KO = ["사용자", "유저", "그 사람의 여정", "그녀의 여정", "그들의 여정"];
const QUESTION_START_REGEX_EN = /^(how|what|why|when|where|who|can|could|should|would|do|does|did|is|are|am|will|have|has|had)\b/i;
const QUESTION_START_REGEX_ES = /^(c[oó]mo|qu[eé]|por qu[eé]|cu[aá]ndo|d[oó]nde|qui[eé]n|puedo|puedes|debo|deber[ií]a|es|son|est[aá]|est[aá]n|hay)\b/i;
const QUESTION_START_REGEX_PT = /^(como|o que|por que|quando|onde|quem|posso|pode|devo|deveria|[ée]|s[aã]o|est[aá]|est[aã]o|h[aá])\b/i;
const QUESTION_START_REGEX_DE = /^(wie|was|warum|wann|wo|wer|kann|könnte|sollte|würde|ist|sind|bin|habe|hast|hat)\b/i;
const QUESTION_START_REGEX_JA = /^(どう|何|なぜ|いつ|どこ|誰|どのように|できますか|すべき|でしょうか|ですか)/i;
const QUESTION_START_REGEX_KO = /^(어떻게|무엇|왜|언제|어디|누가|어떤|할 수|해야)\b/i;
type FollowThroughStatus = "yes" | "partial" | "no" | "unanswered";

function languageCode(input?: JourneyPackageRequest): SupportedLanguageCode {
  const raw = (input?.languageCode ?? input?.localeIdentifier ?? "").toLowerCase();
  if (raw.startsWith("es")) return "es";
  if (raw.startsWith("pt")) return "pt";
  if (raw.startsWith("de")) return "de";
  if (raw.startsWith("ja")) return "ja";
  if (raw.startsWith("ko")) return "ko";
  return "en";
}

function followThroughStatus(input?: JourneyPackageRequest): FollowThroughStatus | undefined {
  const context = (input as (JourneyPackageRequest & {
    followThroughContext?: { previousFollowThroughStatus?: FollowThroughStatus };
  }) | undefined)?.followThroughContext;

  return context?.previousFollowThroughStatus;
}

function cleanText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") {
    return "";
  }
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (trimmed.length <= maxLength) {
    return trimmed;
  }

  const hard = trimmed.slice(0, maxLength);
  const sentenceBoundary = Math.max(
    hard.lastIndexOf("."),
    hard.lastIndexOf("!"),
    hard.lastIndexOf("?")
  );
  if (sentenceBoundary >= Math.floor(maxLength * 0.55)) {
    return hard.slice(0, sentenceBoundary + 1).trim();
  }

  const wordBoundary = hard.lastIndexOf(" ");
  if (wordBoundary >= Math.floor(maxLength * 0.55)) {
    return hard.slice(0, wordBoundary).trim();
  }

  // Preserve full model output if we cannot trim at a natural boundary.
  // This prevents mid-sentence clipping in the app UI.
  return trimmed;
}

function normalizeProseEnding(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return "";
  if (PROSE_END_REGEX.test(trimmed)) return trimmed;

  const sentenceBoundary = Math.max(
    trimmed.lastIndexOf("."),
    trimmed.lastIndexOf("!"),
    trimmed.lastIndexOf("?")
  );
  if (sentenceBoundary >= Math.floor(trimmed.length * 0.45)) {
    return trimmed.slice(0, sentenceBoundary + 1).trim();
  }

  const wordBoundary = trimmed.lastIndexOf(" ");
  if (wordBoundary >= Math.floor(trimmed.length * 0.7)) {
    const candidate = trimmed.slice(0, wordBoundary).trim();
    if (candidate) {
      return `${candidate}.`;
    }
  }

  return trimmed;
}

function normalizeChip(value: unknown, language: SupportedLanguageCode): string {
  const cleaned = cleanText(value, CHIP_MAX_LENGTH).replace(/[^\p{L}\p{N}\s'-]/gu, " ");
  if (!cleaned) return "";

  const compact = cleaned.replace(/\s+/g, " ").trim();
  if (!compact) return "";

  const words = compact.split(" ");
  if (words.length < CHIP_MIN_WORDS || words.length > CHIP_MAX_WORDS) {
    return "";
  }

  const leadingWords =
    language === "es"
      ? LEADING_FRAGMENT_WORDS_ES
      : language === "pt"
        ? LEADING_FRAGMENT_WORDS_PT
        : language === "de"
          ? LEADING_FRAGMENT_WORDS_DE
        : language === "ja"
          ? LEADING_FRAGMENT_WORDS_JA
        : language === "ko"
          ? LEADING_FRAGMENT_WORDS_KO
          : LEADING_FRAGMENT_WORDS_EN;
  const danglingEndings =
    language === "es"
      ? DANGLING_ENDINGS_ES
      : language === "pt"
        ? DANGLING_ENDINGS_PT
        : language === "de"
          ? DANGLING_ENDINGS_DE
        : language === "ja"
          ? DANGLING_ENDINGS_JA
        : language === "ko"
          ? DANGLING_ENDINGS_KO
          : DANGLING_ENDINGS_EN;
  const firstWord = words[0]?.toLowerCase() ?? "";
  const lastWord = words[words.length - 1]?.toLowerCase() ?? "";
  if (leadingWords.has(firstWord) || danglingEndings.has(lastWord)) {
    return "";
  }

  if (/[,:;]$/.test(compact) || compact.endsWith("...")) {
    return "";
  }

  return words.join(" ");
}

function dedupeChips(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const chip of values) {
    const key = chip.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(chip);
  }
  return result;
}

function contextSignals(input?: JourneyPackageRequest): string {
  if (!input) return "";
  const profile = `${input.profile.prayerFocus} ${input.profile.growthGoal}`;
  const journey = `${input.journey.title} ${input.journey.category}`;
  const recent = (input.recentJourneySignals ?? []).join(" ");
  return `${profile} ${journey} ${recent}`.toLowerCase();
}

function contextualFallbackChips(input?: JourneyPackageRequest): string[] {
  const language = languageCode(input);
  const status = followThroughStatus(input);
  if (status === "partial" || status === "no") {
    if (language === "es") {
      return ["Haz un paso de dos minutos", "Elige una acción más fácil", "Ora y empieza pequeño"];
    }
    if (language === "pt") {
      return ["Faça um passo de dois minutos", "Escolha uma ação mais fácil", "Ore e comece pequeno"];
    }
    if (language === "de") {
      return ["Mach einen Zwei-Minuten-Schritt", "Wähle eine leichtere Aktion", "Bete und starte klein"];
    }
    if (language === "ja") {
      return ["2分でできる一歩を選びましょう", "もっと簡単な行動を一つ選びましょう", "祈ってから小さく始めましょう"];
    }
    if (language === "ko") {
      return ["2분짜리 작은 행동을 하세요", "더 쉬운 행동 하나를 고르세요", "기도하고 작게 시작하세요"];
    }
    return ["Take a two minute step", "Choose one easier action", "Pray then start small"];
  }

  const themeKey = input?.journey.themeKey ?? "basic";
  const baseBank =
    language === "es"
      ? themeChipBankEs
      : language === "pt"
        ? themeChipBankPt
        : language === "de"
          ? themeChipBankDe
        : language === "ja"
          ? themeChipBankJa
        : language === "ko"
          ? themeChipBankKo
          : themeChipBankEn;
  const keywordSets =
    language === "es"
      ? contextualKeywordChipsEs
      : language === "pt"
        ? contextualKeywordChipsPt
        : language === "de"
          ? contextualKeywordChipsDe
        : language === "ja"
          ? contextualKeywordChipsJa
        : language === "ko"
          ? contextualKeywordChipsKo
          : contextualKeywordChipsEn;
  const genericFallback =
    language === "es"
      ? genericFallbackChipsEs
      : language === "pt"
        ? genericFallbackChipsPt
        : language === "de"
          ? genericFallbackChipsDe
        : language === "ja"
          ? genericFallbackChipsJa
        : language === "ko"
          ? genericFallbackChipsKo
          : genericFallbackChipsEn;
  const chips: string[] = [...(baseBank[themeKey] ?? baseBank.basic)];

  const signals = contextSignals(input);
  for (const keywordSet of keywordSets) {
    if (keywordSet.pattern.test(signals)) {
      chips.push(...keywordSet.chips);
    }
  }

  chips.push(...genericFallback);
  const normalized = dedupeChips(chips.map((chip) => normalizeChip(chip, language)).filter(Boolean));
  return normalized.slice(0, CHIP_FALLBACK_COUNT);
}

function normalizedChips(rawValues: unknown[], input?: JourneyPackageRequest): string[] {
  const language = languageCode(input);
  const genericFallback =
    language === "es"
      ? genericFallbackChipsEs
      : language === "pt"
        ? genericFallbackChipsPt
        : language === "de"
          ? genericFallbackChipsDe
        : language === "ja"
          ? genericFallbackChipsJa
        : language === "ko"
          ? genericFallbackChipsKo
          : genericFallbackChipsEn;
  const generated = dedupeChips(rawValues.map((item) => normalizeChip(item, language)).filter(Boolean)).slice(0, CHIP_LIMIT);
  const contextual = contextualFallbackChips(input);

  const merged = dedupeChips([...generated, ...contextual]).slice(0, CHIP_LIMIT);
  if (merged.length >= CHIP_FALLBACK_COUNT) {
    return merged;
  }

  const toppedUp = dedupeChips([...merged, ...genericFallback.map((chip) => normalizeChip(chip, language)).filter(Boolean)]).slice(
    0,
    CHIP_LIMIT
  );
  if (toppedUp.length >= CHIP_FALLBACK_COUNT) {
    return toppedUp;
  }

  return (
    language === "es"
      ? ["Ora y elige un paso", "Da una acción fiel", "Escribe tu próximo paso"]
      : language === "pt"
        ? ["Ore e escolha um passo", "Dê uma ação fiel", "Escreva seu próximo passo"]
        : language === "de"
          ? ["Bete und wähle einen Schritt", "Tu eine treue Handlung", "Schreibe deinen nächsten Schritt"]
        : language === "ja"
          ? ["祈って一歩を選ぶ", "忠実な行動を一つ取る", "今日の次の一歩を書く"]
        : language === "ko"
          ? ["기도하고 한 걸음을 고르세요", "신실한 행동 하나를 하세요", "오늘의 다음 걸음을 적으세요"]
        : ["Pray and choose one step", "Take one faithful action", "Write today's next step"]
  ).slice(0, CHIP_LIMIT);
}

function normalizeFirstPersonPrayer(value: unknown, input?: JourneyPackageRequest): string {
  const trimmed = normalizeProseEnding(cleanText(value, 900));
  if (!trimmed) return "";

  const normalized = trimmed.toLowerCase().replace(/[’`]/g, "'");
  const language = languageCode(input);
  const disallowedPhrases =
    language === "es"
      ? DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_ES
      : language === "pt"
        ? DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_PT
        : language === "de"
          ? DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_DE
        : language === "ja"
          ? DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_JA
        : language === "ko"
          ? DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_KO
          : DISALLOWED_THIRD_PERSON_PRAYER_PHRASES_EN;
  if (disallowedPhrases.some((phrase) => normalized.includes(phrase))) {
    return "";
  }

  const firstPersonRegex =
    language === "es"
      ? FIRST_PERSON_PRAYER_REGEX_ES
      : language === "pt"
        ? FIRST_PERSON_PRAYER_REGEX_PT
        : language === "de"
          ? FIRST_PERSON_PRAYER_REGEX_DE
        : language === "ja"
          ? FIRST_PERSON_PRAYER_REGEX_JA
        : language === "ko"
          ? FIRST_PERSON_PRAYER_REGEX_KO
          : FIRST_PERSON_PRAYER_REGEX_EN;
  return firstPersonRegex.test(normalized) ? trimmed : "";
}

function fallbackReflectionThought(input?: JourneyPackageRequest): string {
  const language = languageCode(input);
  const focus = cleanText(input?.profile.growthGoal, 140) || cleanText(input?.profile.prayerFocus, 140);
  if (focus) {
    return language === "es"
      ? `La fe puede guiar tu camino en ${focus.replace(/[.!?]+$/g, "")}.`
      : language === "pt"
        ? `A fé pode guiar seu caminho em ${focus.replace(/[.!?]+$/g, "")}.`
        : language === "de"
          ? `Der Glaube kann deinen Weg in ${focus.replace(/[.!?]+$/g, "")} leiten.`
        : language === "ja"
          ? `${focus.replace(/[.!?]+$/g, "")}の中でも、信仰はあなたの歩みを導けます。`
        : language === "ko"
          ? `${focus.replace(/[.!?]+$/g, "")}의 자리에서도 믿음이 당신의 길을 이끌 수 있습니다.`
      : `Faith can guide your path in ${focus.replace(/[.!?]+$/g, "")}.`;
  }
  return language === "es"
    ? "Una acción fiel hoy puede formar un crecimiento duradero."
    : language === "pt"
      ? "Uma ação fiel hoje pode formar um crescimento duradouro."
      : language === "de"
        ? "Ein treuer Schritt heute kann langfristiges Wachstum formen."
      : language === "ja"
        ? "今日の忠実な行動が、長く続く成長を形づくります。"
      : language === "ko"
        ? "오늘의 신실한 행동 하나가 오래 남는 성장을 만듭니다."
    : "Faithful action today can shape long-term growth.";
}

function normalizeReflectionThought(value: unknown, input?: JourneyPackageRequest): string {
  const raw = cleanText(value, 520);
  const fallback = fallbackReflectionThought(input);
  const language = languageCode(input);
  if (!raw) return fallback;

  const alreadyDirective = /^take a moment to reflect on\b/i.test(raw) || /^reflect on\b/i.test(raw);
  const questionStartRegex =
    language === "es"
      ? QUESTION_START_REGEX_ES
      : language === "pt"
        ? QUESTION_START_REGEX_PT
        : language === "de"
          ? QUESTION_START_REGEX_DE
        : language === "ja"
          ? QUESTION_START_REGEX_JA
        : language === "ko"
          ? QUESTION_START_REGEX_KO
          : QUESTION_START_REGEX_EN;
  const originalLooksQuestion = questionStartRegex.test(raw) || raw.includes("?");
  const originalUsesFirstPerson =
    language === "de" ? FIRST_PERSON_REFLECTION_REGEX_DE.test(raw) : FIRST_PERSON_REFLECTION_REGEX.test(raw);

  let normalized = raw
    .replace(/\?/g, " ")
    .replace(/\bmy\b/gi, "your")
    .replace(/\bmine\b/gi, "yours")
    .replace(/\bme\b/gi, "you")
    .replace(/\bi\b/gi, "you")
    .replace(/\bour\b/gi, "your")
    .replace(/\bours\b/gi, "yours")
    .replace(/\bus\b/gi, "you")
    .replace(/\bwe\b/gi, "you")
    .replace(/\bwe're\b/gi, "you're")
    .replace(/\s+/g, " ")
    .trim();

  if (!originalLooksQuestion && !originalUsesFirstPerson && !alreadyDirective) {
    return `${normalized.replace(/[.!?]+$/g, "").trim()}.`;
  }

  if (language === "es") {
    normalized = normalized
      .replace(/^t[oó]mate un momento para reflexionar sobre\s+/i, "")
      .replace(/^reflexiona sobre\s+/i, "")
      .replace(/[.!?]+$/g, "")
      .trim();
  } else if (language === "pt") {
    normalized = normalized
      .replace(/^reserve um momento para refletir sobre\s+/i, "")
      .replace(/^reflita sobre\s+/i, "")
      .replace(/[.!?]+$/g, "")
      .trim();
  } else if (language === "de") {
    normalized = normalized
      .replace(/^nimm dir einen moment und reflektiere über\s+/i, "")
      .replace(/^reflektiere über\s+/i, "")
      .replace(/^denke über\s+/i, "")
      .replace(/\bmein\b/gi, "dein")
      .replace(/\bmeine\b/gi, "deine")
      .replace(/\bmeinen\b/gi, "deinen")
      .replace(/\bmeinem\b/gi, "deinem")
      .replace(/\bmeiner\b/gi, "deiner")
      .replace(/\bich\b/gi, "du")
      .replace(/\bwir\b/gi, "ihr")
      .replace(/\bunser\b/gi, "euer")
      .replace(/\bunsere\b/gi, "eure")
      .replace(/[.!?]+$/g, "")
      .trim();
  } else if (language === "ja") {
    normalized = normalized
      .replace(/^少し立ち止まって.*を振り返りましょう[:：]?\s*/i, "")
      .replace(/^.*を振り返りましょう[:：]?\s*/i, "")
      .replace(/[.!?。！？]+$/g, "")
      .trim();
  } else if (language === "ko") {
    normalized = normalized
      .replace(/^잠시\s+.*묵상(해|해 보)?세요[:\s]*/i, "")
      .replace(/^묵상(해|해 보)?세요[:\s]*/i, "")
      .replace(/[.!?]+$/g, "")
      .trim();
  } else {
    normalized = normalized
      .replace(/^take a moment to reflect on\s+/i, "")
      .replace(/^reflect on\s+/i, "")
      .replace(/^(how|what|why|when|where|who)\s+(do|does|did|can|could|should|would|is|are|am|will|have|has|had)\s+/i, "")
      .replace(/^(do|does|did|can|could|should|would|is|are|am|will|have|has|had)\s+/i, "")
      .replace(/[.!?]+$/g, "")
      .trim();
  }

  if (!normalized) return fallback;
  return `${normalized.replace(/[.!?]+$/g, "").trim()}.`;
}

const referenceParaphraseFallbacks: Record<
  string,
  { en: string; es: string; pt: string; de: string; ja: string; ko: string }
> = {
  "Philippians 4:6-7": {
    en: "Bring every worry and request to God with thanksgiving, and His peace will guard your heart and mind in Christ.",
    es: "Presenta a Dios cada preocupación y petición con gratitud, y su paz guardará tu corazón y tu mente en Cristo.",
    pt: "Apresente a Deus cada preocupação e pedido com gratidão, e a paz dEle guardará seu coração e sua mente em Cristo.",
    de: "Bring jede Sorge und Bitte mit Dank zu Gott, und sein Frieden wird dein Herz und deinen Sinn in Christus bewahren.",
    ja: "あらゆる不安と願いを感謝とともに神にささげるなら、神の平安がキリストにあってあなたの心と思いを守ってくださいます。",
    ko: "모든 염려와 간구를 감사함으로 하나님께 아뢰면, 그분의 평강이 그리스도 안에서 마음과 생각을 지켜 주십니다."
  },
  "Proverbs 16:3": {
    en: "Commit your work to the Lord, and He will establish your plans.",
    es: "Encomienda tu trabajo al Señor, y Él afirmará tus planes.",
    pt: "Entregue seu trabalho ao Senhor, e Ele firmará seus planos.",
    de: "Befiehl dem Herrn dein Werk an, und er wird deine Pläne festigen.",
    ja: "あなたの働きを主にゆだねれば、主があなたの計画を確かなものにしてくださいます。",
    ko: "당신의 일을 주님께 맡기면, 주님께서 당신의 계획을 굳게 세워 주십니다."
  },
  "Matthew 6:33": {
    en: "Seek God’s kingdom first, and trust Him to provide what you need.",
    es: "Busca primero el reino de Dios y confía en que Él proveerá lo que necesitas.",
    pt: "Busque primeiro o reino de Deus e confie que Ele proverá o que você precisa.",
    de: "Suche zuerst Gottes Reich und vertraue darauf, dass er gibt, was du brauchst.",
    ja: "まず神の国を求め、必要なものは主が満たしてくださると信頼しなさい。",
    ko: "먼저 하나님의 나라를 구하고, 필요한 것을 주님이 채우실 것을 신뢰하세요."
  },
  "Galatians 6:9": {
    en: "Do not grow weary in doing good, because in due time you will reap a harvest if you do not give up.",
    es: "No te canses de hacer el bien, porque a su tiempo cosecharás si no te rindes.",
    pt: "Não se canse de fazer o bem, pois no tempo certo você colherá se não desistir.",
    de: "Werde nicht müde, Gutes zu tun; zur rechten Zeit wirst du ernten, wenn du nicht aufgibst.",
    ja: "善を行うことに疲れ果てないでください。あきらめなければ、時が来て必ず実を結びます。",
    ko: "선을 행하다가 낙심하지 마세요. 포기하지 않으면 때가 되어 반드시 열매를 거둡니다."
  },
  "1 Corinthians 15:58": {
    en: "Stand firm and keep giving yourself fully to the Lord’s work, because your labor in Him is not in vain.",
    es: "Mantente firme y sigue entregándote por completo a la obra del Señor, porque tu esfuerzo en Él no es en vano.",
    pt: "Permaneça firme e continue se dedicando por completo à obra do Senhor, pois seu trabalho nEle não é em vão.",
    de: "Steh fest und diene dem Herrn mit ganzem Herzen, denn deine Mühe in ihm ist nicht vergeblich.",
    ja: "固く立って揺らがず、主の働きに心を尽くし続けてください。主にあるあなたの労苦は決して無駄ではありません。",
    ko: "굳게 서서 주님의 일에 더욱 힘쓰세요. 주님 안에서의 수고는 헛되지 않습니다."
  },
  "Joshua 1:9": {
    en: "Be strong and courageous, do not be afraid, for the Lord your God is with you wherever you go.",
    es: "Sé fuerte y valiente, no tengas miedo, porque el Señor tu Dios está contigo dondequiera que vayas.",
    pt: "Seja forte e corajoso, não tenha medo, pois o Senhor seu Deus está com você por onde você for.",
    de: "Sei stark und mutig, hab keine Angst, denn der Herr, dein Gott, ist mit dir, wohin du auch gehst.",
    ja: "強くあれ、雄々しくあれ。恐れないでください。あなたがどこへ行っても、あなたの神である主が共におられます。",
    ko: "강하고 담대하세요. 두려워하지 마세요. 어디로 가든지 주 하나님이 함께하십니다."
  },
  "2 Timothy 1:7": {
    en: "God gives you a spirit of power, love, and self-control, not fear.",
    es: "Dios te da un espíritu de poder, amor y dominio propio, no de miedo.",
    pt: "Deus lhe dá um espírito de poder, amor e domínio próprio, e não de medo.",
    de: "Gott gibt dir keinen Geist der Furcht, sondern der Kraft, der Liebe und der Besonnenheit.",
    ja: "神は恐れではなく、力と愛と自制の霊をあなたに与えてくださいます。",
    ko: "하나님은 두려움이 아니라 능력과 사랑과 절제의 영을 주십니다."
  },
  "Isaiah 26:3": {
    en: "God keeps in perfect peace the one whose mind is steadfast and trusting in Him.",
    es: "Dios guarda en perfecta paz a quien mantiene su mente firme y confía en Él.",
    pt: "Deus mantém em perfeita paz quem permanece firme e confia nEle.",
    de: "Gott bewahrt den in vollkommenem Frieden, dessen Sinn fest auf ihn gerichtet ist und ihm vertraut.",
    ja: "心を主に堅く据えて主に信頼する者を、神は完全な平安のうちに守ってくださいます。",
    ko: "마음을 주님께 굳게 두고 의지하는 사람을 하나님이 온전한 평강으로 지켜 주십니다."
  },
  "Colossians 3:23": {
    en: "Work wholeheartedly, as for the Lord and not for people.",
    es: "Trabaja de todo corazón, como para el Señor y no para las personas.",
    pt: "Trabalhe de todo o coração, como para o Senhor e não para as pessoas.",
    de: "Arbeite von Herzen, als für den Herrn und nicht nur für Menschen.",
    ja: "何をするにも、人のためではなく主のためにするように、心を尽くして行ってください。",
    ko: "무슨 일을 하든 사람에게 하듯이 하지 말고 주님께 하듯 마음을 다해 하세요."
  },
  "1 Corinthians 9:27": {
    en: "Practice disciplined self-control so your life stays aligned with what you proclaim.",
    es: "Practica un dominio propio disciplinado para que tu vida permanezca alineada con lo que proclamas.",
    pt: "Pratique domínio próprio com disciplina para que sua vida permaneça alinhada ao que você proclama.",
    de: "Übe disziplinierte Selbstkontrolle, damit dein Leben mit dem übereinstimmt, was du bekennst.",
    ja: "自分を訓練し節制を保ち、あなたが告白する信仰と生き方が一致するようにしなさい。",
    ko: "절제와 훈련으로 자신을 다스려, 말로 고백한 믿음과 삶이 일치하도록 하세요."
  },
  "Galatians 5:13": {
    en: "Use your freedom to serve one another humbly in love.",
    es: "Usa tu libertad para servir a los demás con humildad y amor.",
    pt: "Use sua liberdade para servir uns aos outros com humildade e amor.",
    de: "Nutze deine Freiheit, um einander in Liebe demütig zu dienen.",
    ja: "与えられた自由を、愛をもって互いにへりくだって仕えるために用いなさい。",
    ko: "주어진 자유를 사랑 안에서 서로를 겸손히 섬기는 데 사용하세요."
  },
  "Mark 10:45": {
    en: "The Son of Man came not to be served but to serve and to give His life for many.",
    es: "El Hijo del Hombre no vino para ser servido, sino para servir y dar su vida por muchos.",
    pt: "O Filho do Homem não veio para ser servido, mas para servir e dar a sua vida por muitos.",
    de: "Der Menschensohn kam nicht, um sich bedienen zu lassen, sondern um zu dienen und sein Leben für viele hinzugeben.",
    ja: "人の子は仕えられるためではなく仕えるために来られ、多くの人のためにご自身のいのちを与えるために来られました。",
    ko: "인자는 섬김을 받으려 온 것이 아니라 섬기고 많은 사람을 위해 자기 생명을 내어주려 오셨습니다."
  }
};

const referenceAnchorRules: Record<string, string[]> = {
  "Philippians 4:6-7": ["pray", "request", "peace", "anxious", "thank"],
  "Proverbs 16:3": ["commit", "work", "lord", "plans", "establish"],
  "Matthew 6:33": ["seek", "kingdom", "righteous", "first", "provide"],
  "Galatians 6:9": ["weary", "good", "reap", "harvest", "give up"],
  "1 Corinthians 15:58": ["stand firm", "steadfast", "lord", "work", "not in vain"],
  "Joshua 1:9": ["strong", "courageous", "afraid", "with you", "wherever"],
  "2 Timothy 1:7": ["spirit", "power", "love", "self-control", "fear"],
  "Isaiah 26:3": ["perfect peace", "mind", "steadfast", "trust", "trusts"],
  "Colossians 3:23": ["work", "heartily", "lord", "not for", "people"],
  "1 Corinthians 9:27": ["discipline", "self-control", "body", "proclaim", "disqualified"],
  "Galatians 5:13": ["freedom", "serve", "one another", "love", "humble"],
  "Mark 10:45": ["serve", "served", "son of man", "ransom", "many"]
};

const referenceOffTargetSignals: Record<string, string[]> = {
  "Philippians 4:6-7": ["plans", "establish", "business", "provision", "career", "success"]
};

function fallbackParaphrase(reference: string, language: SupportedLanguageCode): string | undefined {
  const fallback = referenceParaphraseFallbacks[reference];
  if (!fallback) return undefined;
  return fallback[language] ?? fallback.en;
}

function enforceParaphraseFidelity(reference: string, paraphrase: string, language: SupportedLanguageCode): string {
  const fallback = fallbackParaphrase(reference, language);
  const anchors = referenceAnchorRules[reference];
  if (!fallback) {
    return paraphrase;
  }

  // English anchors are intentionally strict only for English output.
  // For non-English locales, keep model paraphrase unless empty.
  if (language !== "en") {
    return paraphrase.trim().length === 0 ? fallback : paraphrase;
  }

  if (!anchors) {
    return paraphrase;
  }

  const lower = paraphrase.toLowerCase();
  const anchorMatches = anchors.reduce((count, anchor) => (lower.includes(anchor) ? count + 1 : count), 0);
  const offTargetMatches = (referenceOffTargetSignals[reference] ?? []).reduce(
    (count, signal) => (lower.includes(signal) ? count + 1 : count),
    0
  );

  if (anchorMatches < 2 || (anchorMatches === 0 && offTargetMatches >= 2)) {
    return fallback;
  }

  return paraphrase;
}

function collectUsedScriptureReferences(input?: JourneyPackageRequest): string[] {
  if (!input) {
    return [];
  }

  const fromHistory = (input.recentEntries ?? [])
    .map((entry) => normalizeReference(cleanText(entry.scriptureReference, 120)))
    .filter(Boolean);
  const fromPayload = (input.usedScriptureReferences ?? [])
    .map((value) => normalizeReference(cleanText(value, 120)))
    .filter(Boolean);

  return Array.from(new Set([...fromHistory, ...fromPayload]));
}

function nonRepeatingReference(candidate: string, input?: JourneyPackageRequest): string {
  const used = collectUsedScriptureReferences(input);
  if (used.length === 0 || !used.includes(candidate)) {
    return candidate;
  }

  const seed = `${input?.journey?.id ?? "journey"}-${input?.dateISO ?? "today"}`;
  return deterministicReference(seed, used);
}

function extractJSON(raw: string): unknown {
  const trimmed = raw.trim();

  try {
    return JSON.parse(trimmed);
  } catch {
    // Try to parse fenced JSON.
  }

  const fenceMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fenceMatch?.[1]) {
    try {
      return JSON.parse(fenceMatch[1]);
    } catch {
      return null;
    }
  }

  return null;
}

export function parseAndNormalizePackage(rawText: string, input?: JourneyPackageRequest): DailyJourneyPackage | null {
  const parsed = extractJSON(rawText);
  if (!parsed || typeof parsed !== "object") {
    return null;
  }

  return normalizePackageFromObject(parsed as Record<string, unknown>, input);
}

export function normalizePackageFromObject(
  source: Record<string, unknown>,
  input?: JourneyPackageRequest
): DailyJourneyPackage | null {
  const suggestedRaw = Array.isArray(source.suggestedSteps) ? source.suggestedSteps : [];
  const suggested = normalizedChips(suggestedRaw, input);

  const completionRaw =
    source.completionSuggestion && typeof source.completionSuggestion === "object"
      ? (source.completionSuggestion as Record<string, unknown>)
      : {};
  const confidenceRaw = typeof completionRaw.confidence === "number" ? completionRaw.confidence : 0;
  const confidence = Math.min(1, Math.max(0, confidenceRaw));

  const status = followThroughStatus(input);
  const language = languageCode(input);
  const defaultQuestion =
    status === "partial" || status === "no"
      ? language === "es"
        ? "¿Cuál es un paso pequeño que sí puedes terminar hoy?"
        : language === "pt"
          ? "Qual é um pequeno passo que você consegue concluir hoje?"
          : language === "de"
            ? "Welchen kleinen Schritt kannst du heute realistisch abschließen?"
          : language === "ja"
            ? "今日、現実的に終えられる小さな一歩は何ですか？"
          : language === "ko"
            ? "오늘 현실적으로 마칠 수 있는 작은 걸음 하나는 무엇인가요?"
        : "What is one small step you can realistically finish today?"
      : language === "es"
        ? "¿Qué paso pequeño podrías dar hoy?"
        : language === "pt"
          ? "Qual pequeno passo você pode dar hoje?"
          : language === "de"
            ? "Welchen kleinen Schritt kannst du heute gehen?"
          : language === "ja"
            ? "今日、どんな小さな一歩を踏み出せますか？"
          : language === "ko"
            ? "오늘 어떤 작은 걸음을 내딛을 수 있을까요?"
        : "What small step could you take today?";

  const referenceCandidate = normalizeReference(cleanText(source.scriptureReference, 120));
  const uniqueReference = nonRepeatingReference(referenceCandidate, input);

  const normalized: DailyJourneyPackage = {
    reflectionThought: normalizeReflectionThought(source.reflectionThought, input),
    scriptureReference: uniqueReference,
    scriptureParaphrase: normalizeProseEnding(
      enforceParaphraseFidelity(
        uniqueReference,
        cleanText(source.scriptureParaphrase, 900),
        language
      )
    ),
    prayer: normalizeFirstPersonPrayer(source.prayer, input),
    smallStepQuestion: cleanText(source.smallStepQuestion, 320) || defaultQuestion,
    suggestedSteps: suggested,
    completionSuggestion: {
      shouldPrompt: completionRaw.shouldPrompt === true,
      reason: cleanText(completionRaw.reason, 260),
      confidence
    }
  };

  if (!normalized.reflectionThought || !normalized.scriptureParaphrase || !normalized.prayer) {
    return null;
  }

  return normalized;
}
