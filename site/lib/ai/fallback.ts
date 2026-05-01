import {
  DAILY_JOURNEY_PACKAGE_QUALITY_VERSION,
} from "./types";
import type { ActionLayerOutput, DailyJourneyPackage, DevotionalCore, JourneyArc, JourneyPackageRequest } from "./types";
import {
  approvedScriptureParaphraseForReferenceSet,
  deterministicReference,
  deterministicReferenceForThemes
} from "./scripture";

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
  const signals = `${input.profile.prayerFocus} ${input.profile.growthGoal} ${input.journey.title} ${input.journey.category}`.toLowerCase();
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

  if (language === "en" && /(husband|wife|spouse|marriage)/i.test(signals)) {
    return ["Write a kind note", "Ask one caring question", "Do one helpful chore", "Pray for your wife"];
  }
  if (language === "en" && /(future|impact|ambition|calling|purpose|influenc|great things|world)/i.test(signals)) {
    return ["Name one fear clearly", "Pray over one ambition", "Do one focused work block", "Encourage one person"];
  }

  const theme = input.journey.themeKey ?? "basic";
  const byTheme: Record<string, string[]> = {
    basic: ["Pray over one concern", "Name one honest need", "Choose one wise task"],
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

export function fallbackActionLayer(input: JourneyPackageRequest, core?: DevotionalCore): ActionLayerOutput {
  const language = languageCode(input);
  const status = followThroughStatus(input);
  const todayAim = core?.todayAim?.trim() ?? "";
  const signals = `${input.profile.prayerFocus} ${input.profile.growthGoal} ${input.journey.title} ${input.journey.category} ${todayAim}`.toLowerCase();

  let smallStepQuestion =
    status === "partial" || status === "no"
      ? "What small step can you finish today?"
      : "What can you do today?";

  if (language === "en" && /(husband|wife|spouse|marriage)/i.test(signals)) {
    smallStepQuestion = "What is one simple way to show love today?";
  } else if (language === "en" && /(test|exam|school|act|sat)/i.test(signals)) {
    smallStepQuestion = "How will you prepare with calm today?";
  } else if (language === "en" && /(future|impact|ambition|calling|purpose|business|work|career)/i.test(signals)) {
    smallStepQuestion = "What is one wise way to face your future today?";
  }

  return {
    smallStepQuestion,
    suggestedSteps: fallbackChips(input),
    completionSuggestion: {
      shouldPrompt: false,
      reason: "",
      confidence: 0
    }
  };
}

const referenceFallbackParaphrases: Record<string, Record<"en" | "es" | "pt" | "de" | "ja" | "ko", string>> = {
  "Galatians 6:9": {
    en: "Do not grow weary in doing good, because in due time you will reap a harvest if you do not give up.",
    es: "No te canses de hacer el bien, porque a su tiempo cosecharás si no te rindes.",
    pt: "Não se canse de fazer o bem, pois no tempo certo você colherá se não desistir.",
    de: "Werde nicht müde, Gutes zu tun; zur rechten Zeit wirst du ernten, wenn du nicht aufgibst.",
    ja: "善を行うことに疲れ果てないでください。あきらめなければ、時が来て必ず実を結びます。",
    ko: "선을 행하다가 낙심하지 마세요. 포기하지 않으면 때가 되어 반드시 열매를 거둡니다."
  },
  "1 Corinthians 15:58": {
    en: "Stand firm and keep giving yourself fully to the Lord's work, because your labor in Him is not in vain.",
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
  "Philippians 4:6-7": {
    en: "Bring every worry and request to God with thanksgiving, and His peace will guard your heart and mind in Christ.",
    es: "Presenta a Dios cada preocupación y petición con gratitud, y su paz guardará tu corazón y tu mente en Cristo.",
    pt: "Apresente a Deus cada preocupação e pedido com gratidão, e a paz dEle guardará seu coração e sua mente em Cristo.",
    de: "Bring jede Sorge und Bitte mit Dank zu Gott, und sein Frieden wird dein Herz und deinen Sinn in Christus bewahren.",
    ja: "あらゆる不安と願いを感謝とともに神にささげるなら、神の平安がキリストにあってあなたの心と思いを守ってくださいます。",
    ko: "모든 염려와 간구를 감사함으로 하나님께 아뢰면, 그분의 평강이 그리스도 안에서 마음과 생각을 지켜 주십니다."
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
    ko: "자신을 훈련하고 절제하여, 고백하는 믿음과 삶이 함께 가도록 하세요."
  },
  "Galatians 5:13": {
    en: "Use your freedom to serve one another humbly in love.",
    es: "Usa tu libertad para servir a otros con humildad y amor.",
    pt: "Use sua liberdade para servir uns aos outros com humildade e amor.",
    de: "Nutze deine Freiheit, um einander in Liebe demütig zu dienen.",
    ja: "与えられた自由を、自分のためだけでなく、愛をもって互いに仕えるために用いなさい。",
    ko: "주어진 자유를 사랑으로 서로 섬기는 데 사용하세요."
  },
  "Mark 10:45": {
    en: "The Son of Man came not to be served but to serve and to give His life for many.",
    es: "El Hijo del Hombre no vino para ser servido, sino para servir y dar su vida por muchos.",
    pt: "O Filho do Homem não veio para ser servido, mas para servir e dar a sua vida por muitos.",
    de: "Der Menschensohn kam nicht, um bedient zu werden, sondern um zu dienen und sein Leben für viele zu geben.",
    ja: "人の子は仕えられるためではなく、仕えるため、また多くの人のために命を与えるために来られました。",
    ko: "인자는 섬김을 받으러 온 것이 아니라 섬기고 많은 사람을 위해 생명을 주러 오셨습니다."
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
    en: "Seek God's kingdom first, and trust Him to provide what you need.",
    es: "Busca primero el reino de Dios y confía en que Él proveerá lo que necesitas.",
    pt: "Busque primeiro o reino de Deus e confie que Ele proverá o que você precisa.",
    de: "Suche zuerst Gottes Reich und vertraue darauf, dass er gibt, was du brauchst.",
    ja: "まず神の国を求め、必要なものは主が満たしてくださると信頼しなさい。",
    ko: "먼저 하나님의 나라를 구하고, 필요한 것을 주님이 채우실 것을 신뢰하세요."
  }
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

function fallbackDailyTitle(input: JourneyPackageRequest): string {
  const language = languageCode(input);
  const signals = `${input.profile.prayerFocus} ${input.profile.growthGoal} ${input.journey.title} ${input.journey.category}`.toLowerCase();
  if (language === "en" && /(husband|wife|spouse|marriage)/i.test(signals)) return "Learning Sacrificial Love";
  if (language === "en" && /(future|impact|ambition|calling|purpose|influenc|great things|world)/i.test(signals)) return "Holding Ambition Loosely";
  if (language === "en" && /(peace|anx|worr|fear|stress|calm)/i.test(signals)) return "Choosing Peace Today";
  if (language === "en" && /(prayer|consisten|disciplin|habit)/i.test(signals)) return "Practicing Steady Prayer";
  if (language === "es") return "El paso de hoy";
  if (language === "pt") return "O passo de hoje";
  if (language === "de") return "Der heutige Schritt";
  if (language === "ja") return "今日の一歩";
  if (language === "ko") return "오늘의 걸음";
  return "Receiving Today With God";
}

function fallbackTodayAim(input: JourneyPackageRequest): string {
  const signals = `${input.profile.prayerFocus} ${input.profile.growthGoal} ${input.journey.title} ${input.journey.category}`.toLowerCase();
  if (/(husband|wife|spouse|marriage)/i.test(signals)) return "practice concrete love toward your spouse";
  if (/(future|impact|ambition|calling|purpose|influenc|great things|world)/i.test(signals)) return "hold ambition with humility and wisdom";
  if (/(peace|anx|worr|fear|stress|calm)/i.test(signals)) return "receive God's peace with honesty about worry";
  if (/(prayer|consisten|disciplin|habit)/i.test(signals)) return "turn prayer into one steady practice";
  return input.profile.growthGoal || input.profile.prayerFocus || "listen for today's wise direction";
}

function fallbackJourneyArc(input: JourneyPackageRequest, todayAim: string): JourneyArc {
  const purpose = input.journeyArc?.journeyPurpose || input.journeyArc?.purpose || input.profile.prayerFocus || todayAim;
  return {
    purpose,
    journeyPurpose: purpose,
    currentStage: input.journeyArc?.currentStage || "beginning with honest attention",
    todayAim,
    nextMovement: input.journeyArc?.nextMovement || "Continue the same theme with more clarity, humility, and trust.",
    tone: input.journeyArc?.tone || "grounded, specific, biblically anchored, practical",
    practicalActionDirection:
      input.journeyArc?.practicalActionDirection ||
      "Prefer specific real-life actions when the user's context supports them.",
    recentDayTitles: input.journeyArc?.recentDayTitles ?? [],
    specificContextSignals: input.journeyArc?.specificContextSignals ?? [],
    lastFollowThroughInterpretation: input.journeyArc?.lastFollowThroughInterpretation ?? ""
  };
}

export function fallbackPackage(input: JourneyPackageRequest): DailyJourneyPackage {
  const language = languageCode(input);
  const seed = `${input.journey.id}-${input.dateISO ?? "today"}`;
  const usedReferences = collectUsedScriptureReferences(input);
  const signals = `${input.profile.prayerFocus} ${input.profile.growthGoal} ${input.journey.title} ${input.journey.category}`.toLowerCase();
  const reference =
    language === "en" && /(future|impact|ambition|calling|purpose|influenc|great things|world)/i.test(signals)
      ? deterministicReferenceForThemes(seed, ["calling", "ambition", "wisdom", "work"], usedReferences)
      : language === "en" && /(husband|wife|spouse|marriage)/i.test(signals)
        ? deterministicReferenceForThemes(seed, ["marriage", "love", "service"], usedReferences)
        : language === "en" && /(peace|anx|worr|fear|stress|calm)/i.test(signals)
          ? deterministicReferenceForThemes(seed, ["anxiety", "peace"], usedReferences)
          : deterministicReference(seed, usedReferences);
  const scriptureParaphrase =
    approvedScriptureParaphraseForReferenceSet(reference) ??
    referenceFallbackParaphrases[reference]?.[language] ??
    approvedScriptureParaphraseForReferenceSet("Philippians 4:6-7") ??
    "Bring every worry and request to God with thanksgiving, and His peace will guard your heart and mind in Christ.";
  const dailyTitle = fallbackDailyTitle(input);
  const todayAim = fallbackTodayAim(input);
  const isEnglishMarriageJourney = language === "en" && /(husband|wife|spouse|marriage)/i.test(signals);
  const isEnglishFutureImpactJourney =
    language === "en" && /(future|impact|ambition|calling|purpose|influenc|great things|world)/i.test(signals);

  return {
    dailyTitle,
    reflectionThought: isEnglishMarriageJourney
      ? "Jesus shows that love for God is tied to love for the person close beside you. In marriage, love becomes real when it is patient, humble, and willing to serve. A husband is growing in the right direction when his daily choices look less selfish and more like the way Christ loves. Sacrificial love is learned in ordinary moments of care, listening, and humility."
      : isEnglishFutureImpactJourney
        ? "Scripture treats influence as a gift that should point beyond the self. A desire to do meaningful things becomes healthier when it is shaped by service instead of pressure to prove worth. Anxiety about the future can make calling feel heavy before the path is clear. God can form ambition into wisdom, humility, and love for the people who may be helped."
      : language === "es"
        ? "La fe puede formar un camino paciente en esta área de oración. Dios suele obrar en el corazón antes de que todo se vea resuelto. Un paso pequeño puede revelar qué parte de la vida necesita atención y cuidado. El crecimiento verdadero se forma con fidelidad, no con presión."
        : language === "pt"
          ? "A fé pode formar um caminho paciente nesta área de oração. Deus muitas vezes trabalha no coração antes que tudo pareça resolvido. Um pequeno passo pode revelar que parte da vida precisa de atenção e cuidado. O crescimento verdadeiro se forma com fidelidade, não com pressão."
          : language === "de"
            ? "Glaube kann in diesem Gebetsbereich einen geduldigen Weg formen. Gott wirkt oft im Herzen, bevor äußerlich alles gelöst ist. Ein kleiner Schritt kann zeigen, welcher Teil des Lebens Aufmerksamkeit und Fürsorge braucht. Echtes Wachstum entsteht durch Treue, nicht durch Druck."
          : language === "ja"
            ? "この祈りの領域において、信仰は忍耐深い歩みを形づくります。神は目に見える解決の前に、心の中で働かれることがあります。小さな一歩は、生活のどこに注意と配慮が必要かを示してくれます。真の成長は、圧力ではなく忠実さによって育ちます。"
          : language === "ko"
            ? "이 기도의 자리에서 믿음은 인내로운 길을 만들어 갑니다. 하나님은 모든 것이 해결되기 전에 먼저 마음 안에서 일하실 때가 많습니다. 작은 한 걸음은 삶의 어느 부분에 관심과 돌봄이 필요한지 보여 줄 수 있습니다. 참된 성장은 압박이 아니라 신실함으로 자랍니다."
        : "Scripture gives this concern a steadier center than pressure can provide. God cares about the heart beneath the request, not only the outcome being hoped for. This journey can become a place to receive wisdom, patience, and trust. Growth begins to feel less vague when the concern is brought honestly before God.",
    scriptureReference: reference,
    scriptureParaphrase,
    prayer: isEnglishMarriageJourney
      ? "Jesus, I bring my marriage and my role as a husband to You today. Teach me to love my wife with patience, humility, and attention. Show me where selfishness or passivity has shaped my habits. Make my love more like Yours."
      : isEnglishFutureImpactJourney
        ? "Lord, I bring You my fear about the future and my desire to matter. Teach me to want impact that serves people and honors You. Keep ambition from becoming pressure to prove myself. Give me wisdom, humility, and peace as I grow."
      : language === "es"
        ? "Señor, pongo esta jornada en Tus manos hoy. Ayúdame a ver un paso concreto que pueda dar con fidelidad. Dame humildad para empezar pequeño en vez de quedarme solo en intención. Guía mi acción hacia el crecimiento que te estoy pidiendo."
        : language === "pt"
          ? "Senhor, coloco esta jornada em Tuas mãos hoje. Ajuda-me a enxergar um passo concreto que posso dar com fidelidade. Dá-me humildade para começar pequeno em vez de ficar apenas na intenção. Guia minha ação em direção ao crescimento que estou Te pedindo."
          : language === "de"
            ? "Herr, ich lege diese Journey heute in Deine Hände. Hilf mir, einen konkreten Schritt zu sehen, den ich treu gehen kann. Gib mir Demut, klein anzufangen, statt nur bei der Absicht zu bleiben. Richte meine Handlung auf das Wachstum aus, um das ich Dich bitte."
          : language === "ja"
            ? "主よ、今日この歩みをあなたの御手にゆだねます。私が忠実に踏み出せる具体的な一歩を見せてください。思いだけで終わらず、小さく始める謙遜を与えてください。私が願っている成長へ向かう行動へ導いてください。"
          : language === "ko"
            ? "주님, 오늘 이 여정을 주님의 손에 올려드립니다. 제가 신실하게 할 수 있는 구체적인 한 걸음을 보게 해 주세요. 마음만 품고 멈추지 않고 작게 시작할 겸손을 주세요. 제가 구하는 성장으로 이어지는 행동을 인도해 주세요."
        : "Lord, I bring this concern to You honestly today. Give me wisdom for what is unclear and peace where I feel pressure. Shape my desires with humility and trust. Keep my heart open to what is true and good.",
    todayAim,
    smallStepQuestion: isEnglishMarriageJourney
      ? "What is one simple way to show love to your wife today?"
      : isEnglishFutureImpactJourney
        ? "What is one wise way to face your future today?"
      : followThroughStatus(input) === "partial" ||
      followThroughStatus(input) === "no"
        ? language === "es"
            ? "¿Qué paso pequeño sí puedes completar hoy?"
          : language === "pt"
            ? "Que pequeno passo você consegue concluir hoje?"
            : language === "de"
              ? "Welchen kleinen Schritt kannst du heute schaffen?"
            : language === "ja"
              ? "今日、現実的に終えられる小さな一歩は何ですか？"
            : language === "ko"
              ? "오늘 현실적으로 마칠 수 있는 작은 걸음 하나는 무엇인가요?"
          : "What is one small step you can realistically finish today?"
        : language === "es"
          ? "¿Qué puedes hacer hoy?"
          : language === "pt"
            ? "O que você pode fazer hoje?"
            : language === "de"
              ? "Was kannst du heute tun?"
            : language === "ja"
              ? "今日、どんな小さな一歩を踏み出せますか？"
            : language === "ko"
              ? "오늘 어떤 작은 걸음을 내딛을 수 있을까요?"
          : "What can you do today?",
    suggestedSteps: fallbackChips(input),
    completionSuggestion: {
      shouldPrompt: false,
      reason: "",
      confidence: 0
    },
    updatedJourneyArc: fallbackJourneyArc(input, todayAim),
    qualityVersion: DAILY_JOURNEY_PACKAGE_QUALITY_VERSION
  };
}
