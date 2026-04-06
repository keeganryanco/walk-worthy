import { DailyJourneyPackage, JourneyPackageRequest } from "./types";
import { deterministicReference } from "./scripture";

type FollowThroughStatus = "yes" | "partial" | "no" | "unanswered";

function languageCode(input: JourneyPackageRequest): "en" | "es" {
  const raw = (input.languageCode ?? input.localeIdentifier ?? "").toLowerCase();
  return raw.startsWith("es") ? "es" : "en";
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
    return language === "es"
      ? ["Haz un paso de dos minutos", "Elige una acción más fácil", "Ora y empieza pequeño"]
      : ["Take a two minute step", "Choose one easier action", "Pray then start small"];
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
      : "Bring your requests to God with trust, and take one faithful step today.");

  return {
    reflectionThought:
      language === "es"
        ? "Una decisión fiel hoy puede formar un crecimiento duradero."
        : "One faithful choice today can shape long-term growth.",
    scriptureReference: reference,
    scriptureParaphrase,
    prayer:
      language === "es"
        ? "Señor, afirma mi corazón y alinea mi próxima acción con el crecimiento que te estoy pidiendo."
        : "Lord, steady my heart and align my next action with the growth I am asking You for.",
    smallStepQuestion:
      followThroughStatus(input) === "partial" ||
      followThroughStatus(input) === "no"
        ? language === "es"
          ? "¿Cuál es un paso pequeño que sí puedes terminar hoy?"
          : "What is one small step you can realistically finish today?"
        : language === "es"
          ? "¿Qué paso pequeño podrías dar hoy?"
          : "What small step could you take today?",
    suggestedSteps: fallbackChips(input),
    completionSuggestion: {
      shouldPrompt: false,
      reason: "",
      confidence: 0
    }
  };
}
