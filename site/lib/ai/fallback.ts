import { DailyJourneyPackage, JourneyPackageRequest } from "./types";
import { deterministicReference } from "./scripture";

type FollowThroughStatus = "yes" | "partial" | "no" | "unanswered";

function languageCode(input: JourneyPackageRequest): "en" | "es" | "pt" | "de" | "ja" | "ko" {
  const raw = (input.languageCode ?? input.localeIdentifier ?? "").toLowerCase();
  if (raw.startsWith("es")) return "es";
  if (raw.startsWith("pt")) return "pt";
  if (raw.startsWith("de")) return "de";
  if (raw.startsWith("ja")) return "ja";
  if (raw.startsWith("ko")) return "ko";
  return "en";
}

function followThroughStatus(input: JourneyPackageRequest): FollowThroughStatus | undefined {
  const context = (input as JourneyPackageRequest & {
    followThroughContext?: { previousFollowThroughStatus?: FollowThroughStatus };
  }).followThroughContext;

  return context?.previousFollowThroughStatus;
}

function fallbackChips(input: JourneyPackageRequest): string[] {
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

  const theme = input.journey.themeKey ?? "basic";
  const byTheme: Record<string, string[]> = {
    basic: ["Pray over one task", "Take one faithful action", "Write today's next step"],
    faith: ["Pray with full trust", "Release one control area", "Take one faith step"],
    patience: ["Choose one slow step", "Wait before reacting", "Finish one lingering task"],
    peace: ["Take five calm breaths", "Pray through one worry", "Silence one distraction"],
    resilience: ["Do one hard thing", "Reframe one setback", "Ask for strength today"],
    community: ["Send one encouragement text", "Pray for one friend", "Schedule one check-in"],
    discipline: ["Set one focused block", "Remove one distraction", "Start before you feel ready"],
    healing: ["Take one gentle action", "Name one honest feeling", "Reach out for support"],
    joy: ["Write three gratitude lines", "Celebrate one small win", "Share one praise update"],
    wisdom: ["Pause and seek wisdom", "Write one wise step", "Ask trusted counsel today"]
  };
  if (language === "es") {
    const byThemeEs: Record<string, string[]> = {
      basic: ["Ora por una tarea", "Da una acción fiel", "Escribe tu próximo paso"],
      faith: ["Ora con plena confianza", "Entrega un área de control", "Da un paso de fe"],
      patience: ["Elige un paso tranquilo", "Espera antes de reaccionar", "Avanza una tarea atrasada"],
      peace: ["Respira profundo cinco veces", "Ora por una preocupación", "Silencia una distracción"],
      resilience: ["Haz algo difícil hoy", "Reformula un tropiezo", "Pide fuerzas para hoy"],
      community: ["Envía un mensaje de ánimo", "Ora por un amigo", "Agenda un seguimiento"],
      discipline: ["Define un bloque de enfoque", "Quita una distracción", "Empieza ahora mismo"],
      healing: ["Da un paso de cuidado", "Nombra una emoción real", "Pide apoyo hoy"],
      joy: ["Escribe tres gratitudes", "Celebra un pequeño avance", "Comparte una alabanza"],
      wisdom: ["Pausa y pide sabiduría", "Define un paso sabio", "Busca consejo confiable"]
    };
    return byThemeEs[theme] ?? byThemeEs.basic;
  }

  if (language === "pt") {
    const byThemePt: Record<string, string[]> = {
      basic: ["Ore por uma tarefa", "Dê uma ação fiel", "Escreva o próximo passo"],
      faith: ["Ore com plena confiança", "Entregue uma área de controle", "Dê um passo de fé"],
      patience: ["Escolha um passo calmo", "Espere antes de reagir", "Avance uma tarefa atrasada"],
      peace: ["Respire fundo cinco vezes", "Ore por uma preocupação", "Silencie uma distração"],
      resilience: ["Faça algo difícil hoje", "Reenquadre um tropeço", "Peça força para hoje"],
      community: ["Envie uma mensagem de incentivo", "Ore por um amigo", "Agende um acompanhamento"],
      discipline: ["Defina um bloco de foco", "Remova uma distração", "Comece agora mesmo"],
      healing: ["Dê um passo de cuidado", "Nomeie uma emoção real", "Peça apoio hoje"],
      joy: ["Escreva três gratidões", "Celebre um pequeno avanço", "Compartilhe um louvor"],
      wisdom: ["Pare e peça sabedoria", "Defina um passo sábio", "Busque conselho confiável"]
    };
    return byThemePt[theme] ?? byThemePt.basic;
  }

  if (language === "de") {
    const byThemeDe: Record<string, string[]> = {
      basic: ["Bete über eine Aufgabe", "Tu eine treue Handlung", "Schreibe deinen nächsten Schritt auf"],
      faith: ["Bete mit vollem Vertrauen", "Schreibe ein Glaubens-Statement", "Gib einen Kontrollbereich ab"],
      patience: ["Wähle einen ruhigen Schritt", "Warte vor deiner Reaktion", "Erledige eine liegen gebliebene Aufgabe"],
      peace: ["Atme fünfmal ruhig durch", "Bete über eine Sorge", "Schalte eine Ablenkung aus"],
      resilience: ["Tu heute etwas Schwieriges", "Deute einen Rückschlag neu", "Bitte heute um Kraft"],
      community: ["Sende eine ermutigende Nachricht", "Bete für einen Freund", "Plane ein kurzes Nachfassen"],
      discipline: ["Setze einen Fokus-Block", "Entferne eine Ablenkung", "Starte jetzt sofort"],
      healing: ["Tu einen fürsorglichen Schritt", "Benenne ein echtes Gefühl", "Bitte heute um Unterstützung"],
      joy: ["Schreibe drei Dankbarkeiten", "Feiere einen kleinen Fortschritt", "Teile ein Lob"],
      wisdom: ["Halte inne und bitte um Weisheit", "Formuliere einen weisen Schritt", "Suche vertrauenswürdigen Rat"]
    };
    return byThemeDe[theme] ?? byThemeDe.basic;
  }

  if (language === "ja") {
    const byThemeJa: Record<string, string[]> = {
      basic: ["一つの課題のために祈る", "忠実な行動を一つ取る", "今日の次の一歩を書く"],
      faith: ["全き信頼で祈る", "手放す領域を一つ決める", "信仰の一歩を踏み出す"],
      patience: ["穏やかな一歩を選ぶ", "反応する前に待つ", "先延ばしの課題を終える"],
      peace: ["ゆっくり5回深呼吸する", "不安を祈りに委ねる", "妨げを一つ静める"],
      resilience: ["難しいことを一つ行う", "つまずきを捉え直す", "今日の力を祈り求める"],
      community: ["励ましのメッセージを送る", "一人の友のために祈る", "短い連絡の時間を決める"],
      discipline: ["集中ブロックを設定する", "妨げを一つ取り除く", "準備できる前に始める"],
      healing: ["いたわりの一歩を取る", "正直な感情を言葉にする", "支えを求める"],
      joy: ["感謝を3つ書く", "小さな前進を祝う", "賛美の分かち合いをする"],
      wisdom: ["立ち止まり知恵を求める", "知恵ある一歩を書く", "信頼できる助言を求める"]
    };
    return byThemeJa[theme] ?? byThemeJa.basic;
  }

  if (language === "ko") {
    const byThemeKo: Record<string, string[]> = {
      basic: ["한 가지 일로 기도하세요", "신실한 행동 하나를 하세요", "다음 걸음을 적어 보세요"],
      faith: ["온전히 신뢰하며 기도하세요", "통제하려던 한 영역을 내려놓으세요", "믿음의 행동 하나를 하세요"],
      patience: ["차분한 한 걸음을 고르세요", "반응 전에 잠시 기다리세요", "미뤄 둔 일 하나를 끝내세요"],
      peace: ["천천히 다섯 번 숨 쉬세요", "걱정 하나를 두고 기도하세요", "방해 요소 하나를 잠시 끄세요"],
      resilience: ["어려운 일 하나를 해보세요", "실패를 다시 해석해 보세요", "오늘 힘을 구하세요"],
      community: ["격려 메시지 하나를 보내세요", "친구 한 사람을 위해 기도하세요", "짧은 안부 일정을 잡으세요"],
      discipline: ["집중 시간 블록을 정하세요", "방해 요소 하나를 제거하세요", "준비되기 전에 먼저 시작하세요"],
      healing: ["돌봄 행동 하나를 하세요", "솔직한 감정 하나를 적어 보세요", "도움을 요청하세요"],
      joy: ["감사 세 가지를 적어 보세요", "작은 승리를 축하하세요", "찬양 제목 하나를 나누세요"],
      wisdom: ["잠시 멈추고 지혜를 구하세요", "지혜로운 다음 걸음을 적으세요", "신뢰할 조언을 구하세요"]
    };
    return byThemeKo[theme] ?? byThemeKo.basic;
  }

  return byTheme[theme] ?? byTheme.basic;
}

const referenceFallbackParaphrases: Record<string, string> = {
  "Galatians 6:9": "Do not grow weary in doing good, because in due time you will reap a harvest if you do not give up.",
  "1 Corinthians 15:58": "Stand firm and keep giving yourself fully to the Lord's work, because your labor in Him is not in vain.",
  "Joshua 1:9": "Be strong and courageous, do not be afraid, for the Lord your God is with you wherever you go.",
  "2 Timothy 1:7": "God gives you a spirit of power, love, and self-control, not fear.",
  "Philippians 4:6-7": "Bring every worry and request to God with thanksgiving, and His peace will guard your heart and mind in Christ.",
  "Isaiah 26:3": "God keeps in perfect peace the one whose mind is steadfast and trusting in Him.",
  "Colossians 3:23": "Work wholeheartedly, as for the Lord and not for people.",
  "1 Corinthians 9:27": "Practice disciplined self-control so your life stays aligned with what you proclaim.",
  "Galatians 5:13": "Use your freedom to serve one another humbly in love.",
  "Mark 10:45": "The Son of Man came not to be served but to serve and to give His life for many.",
  "Proverbs 16:3": "Commit your work to the Lord, and He will establish your plans.",
  "Matthew 6:33": "Seek God's kingdom first, and trust Him to provide what you need."
};

function collectUsedScriptureReferences(input: JourneyPackageRequest): string[] {
  const fromHistory = (input.recentEntries ?? [])
    .map((entry) => entry.scriptureReference?.trim() ?? "")
    .filter(Boolean);
  const fromPayload = (input.usedScriptureReferences ?? [])
    .map((value) => value.trim())
    .filter(Boolean);
  return Array.from(new Set([...fromHistory, ...fromPayload]));
}

export function fallbackPackage(input: JourneyPackageRequest): DailyJourneyPackage {
  const language = languageCode(input);
  const seed = `${input.journey.id}-${input.dateISO ?? "today"}`;
  const usedReferences = collectUsedScriptureReferences(input);
  const reference = deterministicReference(seed, usedReferences);
  const scriptureParaphrase =
    referenceFallbackParaphrases[reference] ??
    (language === "es"
      ? "Presenta tus peticiones a Dios con confianza y da hoy un paso fiel."
      : language === "pt"
        ? "Apresente seus pedidos a Deus com confiança e dê hoje um passo fiel."
        : language === "de"
          ? "Bring deine Anliegen im Vertrauen vor Gott und gehe heute einen treuen Schritt."
        : language === "ja"
          ? "神に願いを信頼してゆだね、今日、忠実な一歩を踏み出しましょう。"
        : language === "ko"
          ? "믿음으로 하나님께 간구를 올려 드리고, 오늘 신실한 한 걸음을 내딛으세요."
      : "Bring your requests to God with trust, and take one faithful step today.");

  return {
    reflectionThought:
      language === "es"
        ? "Una decisión fiel hoy puede formar un crecimiento duradero."
        : language === "pt"
          ? "Uma decisão fiel hoje pode formar um crescimento duradouro."
          : language === "de"
            ? "Eine treue Entscheidung heute kann langfristiges Wachstum formen."
          : language === "ja"
            ? "今日の忠実な決断が、長く続く成長を形づくります。"
          : language === "ko"
            ? "오늘의 신실한 결정 하나가 오래 남는 성장을 만듭니다."
        : "One faithful choice today can shape long-term growth.",
    scriptureReference: reference,
    scriptureParaphrase,
    prayer:
      language === "es"
        ? "Señor, afirma mi corazón y alinea mi próxima acción con el crecimiento que te estoy pidiendo."
        : language === "pt"
          ? "Senhor, firma meu coração e alinha minha próxima ação com o crescimento que estou Te pedindo."
          : language === "de"
            ? "Herr, stärke mein Herz und richte meine nächste Handlung auf das Wachstum aus, um das ich Dich bitte."
          : language === "ja"
            ? "主よ、私の心を堅くし、私が願う成長と一致する次の行動へ導いてください。"
          : language === "ko"
            ? "주님, 제 마음을 붙드시고 제가 구하는 성장과 맞는 다음 행동으로 이끌어 주세요."
        : "Lord, steady my heart and align my next action with the growth I am asking You for.",
    smallStepQuestion:
      followThroughStatus(input) === "partial" ||
      followThroughStatus(input) === "no"
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
          : "What small step could you take today?",
    suggestedSteps: fallbackChips(input),
    completionSuggestion: {
      shouldPrompt: false,
      reason: "",
      confidence: 0
    }
  };
}
