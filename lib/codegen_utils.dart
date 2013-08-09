part of codegen;

/**
 * Apply [Path.normalize] and [Path.absolute] to a given path.
 */
String absoluteNormalize(String unnormalized) =>
    path.normalize(path.absolute(unnormalized));

/**
 * Given a dart executable path, return the dart-sdk path. Assumes the following
 * layout -
 * /<path to dart sdk>/bin/dart this method will return
 * /<path to dart sdk>
 */
String extractSdkPathFromExecutablePath(String executablePath) =>
    path.dirname(path.dirname(executablePath));