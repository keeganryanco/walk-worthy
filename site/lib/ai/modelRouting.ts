export const AI_PACKAGE_QUALITY_VERSION = 6;

function envValue(name: string): string | undefined {
  const value = process.env[name]?.trim();
  return value && value.length > 0 ? value : undefined;
}

export function devotionalModel(): string {
  return envValue("OPENAI_DEVOTIONAL_MODEL") ?? "gpt-5.5";
}

export function actionModel(): string {
  return envValue("OPENAI_ACTION_MODEL")
    ?? envValue("OPENAI_UTILITY_MODEL")
    ?? "gpt-5.1";
}

export function repairModel(): string {
  return envValue("OPENAI_REPAIR_MODEL") ?? envValue("OPENAI_DEVOTIONAL_MODEL") ?? "gpt-5.5";
}

export function utilityModel(): string {
  return envValue("OPENAI_UTILITY_MODEL") ?? actionModel();
}
