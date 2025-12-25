import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final codeConfig = input.config.code;
    final os = codeConfig.targetOS;
    final arch = codeConfig.targetArchitecture;

    Uri resolveInPackage(String relativePath) {
      return input.packageRoot.resolve(relativePath);
    }

    Future<Uri> stageFile({
      required String sourceRelativePath,
      required String stagedRelativePath,
    }) async {
      final src = resolveInPackage(sourceRelativePath);
      final dst = input.outputDirectoryShared.resolve(stagedRelativePath);

      final srcFile = File.fromUri(src);
      if (!await srcFile.exists()) {
        throw StateError(
          'Native asset not found: ${srcFile.path}\n'
          'Expected relative path: $sourceRelativePath',
        );
      }

      final dstFile = File.fromUri(dst);
      await dstFile.parent.create(recursive: true);
      await srcFile.copy(dstFile.path);
      return dst;
    }

    void addBundledCodeAsset({required String name, required Uri file}) {
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: name,
          linkMode: DynamicLoadingBundled(),
          file: file,
        ),
      );
    }

    String prefix() => '${os.name}/${arch.name}';

    // Core FreeTDS libraries
    const sybdbAssetName = 'src/ffi/freetds_bindings.dart';
    const ctAssetName = 'src/native_assets/freetds_ct.dart';

    // Optional runtime deps (bundled where shipped)
    const sslAssetName = 'src/native_assets/freetds_ssl.dart';
    const cryptoAssetName = 'src/native_assets/freetds_crypto.dart';

    if (os == OS.android) {
      final abi = switch (arch) {
        Architecture.arm64 => 'arm64-v8a',
        Architecture.arm => 'armeabi-v7a',
        Architecture.x64 => 'x86_64',
        _ => throw StateError('Unsupported Android architecture: ${arch.name}'),
      };

      final base = 'android/src/main/jniLibs/$abi/';

      final sybdb = await stageFile(
        sourceRelativePath: '${base}libsybdb.so',
        stagedRelativePath: '${prefix()}/libsybdb.so',
      );
      final ct = await stageFile(
        sourceRelativePath: '${base}libct.so',
        stagedRelativePath: '${prefix()}/libct.so',
      );

      addBundledCodeAsset(name: sybdbAssetName, file: sybdb);
      addBundledCodeAsset(name: ctAssetName, file: ct);
      return;
    }

    if (os == OS.windows) {
      if (arch != Architecture.x64) {
        throw StateError(
          'Windows artifacts in this package appear to be x64-only; '
          'unsupported architecture: ${arch.name}',
        );
      }

      final sybdb = await stageFile(
        sourceRelativePath: 'windows/Libraries/bin/sybdb.dll',
        stagedRelativePath: '${prefix()}/sybdb.dll',
      );
      final ct = await stageFile(
        sourceRelativePath: 'windows/Libraries/bin/ct.dll',
        stagedRelativePath: '${prefix()}/ct.dll',
      );

      addBundledCodeAsset(name: sybdbAssetName, file: sybdb);
      addBundledCodeAsset(name: ctAssetName, file: ct);

      // OpenSSL (shipped in this repo) – needed on some setups.
      final ssl = await stageFile(
        sourceRelativePath: 'windows/Libraries/bin/libssl-1_1-x64.dll',
        stagedRelativePath: '${prefix()}/libssl-1_1-x64.dll',
      );
      final crypto = await stageFile(
        sourceRelativePath: 'windows/Libraries/bin/libcrypto-1_1-x64.dll',
        stagedRelativePath: '${prefix()}/libcrypto-1_1-x64.dll',
      );
      addBundledCodeAsset(name: sslAssetName, file: ssl);
      addBundledCodeAsset(name: cryptoAssetName, file: crypto);
      return;
    }

    if (os == OS.linux) {
      // Prefer the most specific SONAMEs if present.
      Future<Uri> stageFirstExisting(
        List<String> candidates,
        String outName,
      ) async {
        for (final candidate in candidates) {
          final src = resolveInPackage(candidate);
          if (await File.fromUri(src).exists()) {
            return stageFile(
              sourceRelativePath: candidate,
              stagedRelativePath: '${prefix()}/$outName',
            );
          }
        }
        throw StateError(
          'None of the candidate native assets were found:\n'
          '${candidates.join('\n')}',
        );
      }

      final sybdb = await stageFirstExisting([
        'linux/Libraries/lib/libsybdb.so.5.1.0',
        'linux/Libraries/lib/libsybdb.so.5',
        'linux/Libraries/lib/libsybdb.so',
      ], 'libsybdb.so');
      final ct = await stageFirstExisting([
        'linux/Libraries/lib/libct.so.4.0.0',
        'linux/Libraries/lib/libct.so.4',
        'linux/Libraries/lib/libct.so',
      ], 'libct.so');

      addBundledCodeAsset(name: sybdbAssetName, file: sybdb);
      addBundledCodeAsset(name: ctAssetName, file: ct);

      // If packaged, bundle OpenSSL 3.
      final ssl = await stageFirstExisting([
        'linux/Libraries/lib/libssl.so.3',
        'linux/Libraries/lib/libssl.so',
      ], 'libssl.so.3');
      final crypto = await stageFirstExisting([
        'linux/Libraries/lib/libcrypto.so.3',
        'linux/Libraries/lib/libcrypto.so',
      ], 'libcrypto.so.3');
      addBundledCodeAsset(name: sslAssetName, file: ssl);
      addBundledCodeAsset(name: cryptoAssetName, file: crypto);
      return;
    }

    if (os == OS.macOS) {
      Future<Uri> stageFirstExisting(
        List<String> candidates,
        String outName,
      ) async {
        for (final candidate in candidates) {
          final src = resolveInPackage(candidate);
          if (await File.fromUri(src).exists()) {
            return stageFile(
              sourceRelativePath: candidate,
              stagedRelativePath: '${prefix()}/$outName',
            );
          }
        }
        throw StateError(
          'None of the candidate native assets were found:\n'
          '${candidates.join('\n')}',
        );
      }

      final sybdb = await stageFirstExisting([
        'macos/Libraries/lib/libsybdb.5.dylib',
        'macos/Libraries/lib/libsybdb.dylib',
      ], 'libsybdb.dylib');
      final ct = await stageFirstExisting([
        'macos/Libraries/lib/libct.4.dylib',
        'macos/Libraries/lib/libct.dylib',
      ], 'libct.dylib');

      addBundledCodeAsset(name: sybdbAssetName, file: sybdb);
      addBundledCodeAsset(name: ctAssetName, file: ct);

      final ssl = await stageFirstExisting([
        'macos/Libraries/lib/libssl.3.dylib',
        'macos/Libraries/lib/libssl.dylib',
      ], 'libssl.3.dylib');
      final crypto = await stageFirstExisting([
        'macos/Libraries/lib/libcrypto.3.dylib',
        'macos/Libraries/lib/libcrypto.dylib',
      ], 'libcrypto.3.dylib');
      addBundledCodeAsset(name: sslAssetName, file: ssl);
      addBundledCodeAsset(name: cryptoAssetName, file: crypto);
      return;
    }

    if (os == OS.iOS) {
      // Current repo ships iOS static libraries inside XCFrameworks.
      // Build hooks support for static linking is not available in the SDK yet.
      throw StateError(
        'iOS is not supported with build hooks using the current artifacts. '
        'This package ships iOS static .a libraries; StaticLinking is not yet '
        'supported by the Dart/Flutter SDK. Provide dynamic iOS artifacts '
        '(e.g., a dynamic XCFramework) to enable iOS bundling.',
      );
    }

    throw StateError('Unsupported target OS: ${os.name}');
  });
}
