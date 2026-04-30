export async function resolve(specifier, context, defaultResolve) {
  try {
    return await defaultResolve(specifier, context, defaultResolve);
  } catch (error) {
    const shouldTryTypeScript =
      (specifier.startsWith("./") || specifier.startsWith("../")) &&
      !specifier.match(/\.[a-z0-9]+$/i);

    if (!shouldTryTypeScript) {
      throw error;
    }

    return defaultResolve(`${specifier}.ts`, context, defaultResolve);
  }
}
