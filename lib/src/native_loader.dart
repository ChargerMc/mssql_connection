import 'dart:ffi';
import 'dart:io' show Platform, File, Directory;

import 'package:ffi/ffi.dart';

import 'native_logger.dart';

class NativeLoader {
  static DynamicLibrary loadDBLib() {
    NativeLogger.i('loadDBLib: platform=${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      // On Android, .so files from jniLibs are automatically loaded from the app's native lib dir
      NativeLogger.i('Android: opening libsybdb.so');
      return DynamicLibrary.open('libsybdb.so');
    } else if (Platform.isIOS) {
      // iOS links the XCFramework statically via CocoaPods; use process.
      NativeLogger.i('iOS: using DynamicLibrary.process()');
      return DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      // On macOS, dylibs are bundled in the app's Frameworks directory or plugin bundle
      NativeLogger.i('macOS: searching for sybdb dylib');
      final candidatePaths = <String>[];

      // Try to find the executable path and derive the Frameworks directory
      try {
        final execPath = Platform.resolvedExecutable;
        final appDir = File(execPath).parent.parent.path;
        candidatePaths.add('$appDir/Frameworks/libsybdb.dylib');
        candidatePaths.add('$appDir/Frameworks/libsybdb.5.dylib');
        // Also check Resources for embedded dylibs
        candidatePaths.add('$appDir/Resources/libsybdb.dylib');
        candidatePaths.add('$appDir/Resources/libsybdb.5.dylib');
      } catch (e) {
        NativeLogger.w('macOS: could not determine app bundle path: $e');
      }

      // Fallback paths for development/testing
      try {
        final scriptDir = File.fromUri(Platform.script).parent;
        final root = scriptDir.parent;
        candidatePaths.add('${root.path}/macos/Libraries/lib/libsybdb.dylib');
        candidatePaths.add('${root.path}/macos/Libraries/lib/libsybdb.5.dylib');
      } catch (_) {}
      try {
        final cwd = Directory.current.path;
        candidatePaths.add('$cwd/macos/Libraries/lib/libsybdb.dylib');
        candidatePaths.add('$cwd/macos/Libraries/lib/libsybdb.5.dylib');
      } catch (_) {}

      // System fallback names
      candidatePaths.addAll(['libsybdb.dylib', 'libsybdb.5.dylib']);

      for (final path in candidatePaths) {
        try {
          NativeLogger.i('macOS: trying $path');
          final lib = DynamicLibrary.open(path);
          NativeLogger.i('macOS: opened $path');
          return lib;
        } catch (e) {
          NativeLogger.w('macOS: failed $path -> $e');
        }
      }
    } else if (Platform.isLinux) {
      // On Linux, .so files are bundled in the app's lib directory
      NativeLogger.i('Linux[DB]: searching for sybdb library');
      final candidatePaths = <String>[];

      // Try to find bundled library relative to executable
      try {
        final execPath = Platform.resolvedExecutable;
        final execDir = File(execPath).parent.path;
        candidatePaths.add('$execDir/lib/libsybdb.so');
        candidatePaths.add('$execDir/lib/libsybdb.so.5');
        candidatePaths.add('$execDir/lib/libsybdb.so.5.1.0');
      } catch (e) {
        NativeLogger.w('Linux[DB]: could not determine executable path: $e');
      }

      // Fallback paths for development/testing
      try {
        final scriptDir = File.fromUri(Platform.script).parent;
        final root = scriptDir.parent;
        final rootPath = root.path;
        candidatePaths.add('$rootPath/linux/Libraries/lib/libsybdb.so');
        candidatePaths.add('$rootPath/linux/Libraries/lib/libsybdb.so.5');
      } catch (_) {}
      try {
        final cwd = Directory.current.path;
        candidatePaths.add('$cwd/linux/Libraries/lib/libsybdb.so');
        candidatePaths.add('$cwd/linux/Libraries/lib/libsybdb.so.5');
      } catch (_) {}

      // System fallback names
      candidatePaths.addAll([
        'libsybdb.so',
        'libsybdb.so.5',
        'libsybdb.so.5.1.0',
      ]);

      for (final path in candidatePaths) {
        try {
          NativeLogger.i('Linux[DB]: trying $path');
          final lib = DynamicLibrary.open(path);
          NativeLogger.i('Linux[DB]: opened $path');
          return lib;
        } catch (e) {
          NativeLogger.w('Linux[DB]: failed $path -> $e');
        }
      }
    } else if (Platform.isWindows) {
      // On Windows, DLLs are bundled next to the executable
      final tried = <String>[];
      Object? lastErr;

      // Configure modern DLL search behavior
      _setDefaultDllDirectories();

      // First, try the bundled location next to the executable (Flutter app bundle)
      try {
        final execPath = Platform.resolvedExecutable;
        final execDir = File(execPath).parent.path;
        NativeLogger.i('Windows[DB]: executable dir = $execDir');

        // Preload dependencies from the same directory
        _preloadDependencies(execDir);

        final dbPath = '$execDir\\sybdb.dll';
        if (File(dbPath).existsSync()) {
          _setDllDirectory(execDir);
          NativeLogger.i('Windows[DB]: trying bundled $dbPath');
          tried.add(dbPath);
          return DynamicLibrary.open(dbPath);
        }
      } catch (e) {
        lastErr = e;
        NativeLogger.w('Windows[DB]: bundled location failed -> $e');
      }

      // Try by name (if PATH already set correctly)
      try {
        NativeLogger.i('Windows[DB]: trying sybdb.dll by name');
        tried.add('sybdb.dll');
        return DynamicLibrary.open('sybdb.dll');
      } catch (e) {
        lastErr = e;
        NativeLogger.w('Windows[DB]: sybdb.dll by name failed -> $e');
      }

      // Build candidate directories (prefer bundled locations first)
      final candidateDirs = <String>[];
      try {
        final scriptDir = File.fromUri(Platform.script).parent;
        final root = scriptDir.parent; // repo root when running from tool/
        final rootPath = root.path;
        candidateDirs.addAll(['$rootPath\\windows\\Libraries\\bin']);
      } catch (_) {}
      // Also add fallbacks relative to the current working directory
      try {
        final cwd = Directory.current.path;
        candidateDirs.addAll(['$cwd\\windows\\Libraries\\bin', cwd]);
      } catch (_) {}
      NativeLogger.i('Windows[DB]: candidateDirs=${candidateDirs.join('; ')}');

      // Try to load from each candidate dir
      for (final dir in candidateDirs) {
        try {
          NativeLogger.i('Windows[DB]: trying dir=$dir');
          _setDllDirectory(dir);
          NativeLogger.i('Windows[DB]: SetDllDirectory($dir)');

          _preloadDependencies(dir);

          final db = '$dir\\sybdb.dll';
          tried.add(db + (File(db).existsSync() ? ' (exists)' : ' (missing)'));
          NativeLogger.i('Windows[DB]: opening $db');
          return DynamicLibrary.open(db);
        } catch (e) {
          NativeLogger.w('Windows[DB]: failed -> $e');
          lastErr = e;
        }
      }
      throw UnsupportedError(
        'Could not load FreeTDS DB-Lib for this platform. Tried: ${tried.join('; ')}${lastErr != null ? ' | Last error: $lastErr' : ''}',
      );
    }
    throw UnsupportedError('Could not load FreeTDS DB-Lib for this platform.');
  }

  /// Preload common dependencies (OpenSSL, ct.dll) from a directory
  static void _preloadDependencies(String dir) {
    // Preload OpenSSL if present
    final crypto = '$dir\\libcrypto-1_1-x64.dll';
    final ssl = '$dir\\libssl-1_1-x64.dll';
    if (File(crypto).existsSync()) {
      _preloadWithAlteredSearchPath(crypto);
      NativeLogger.i('Windows: preloaded $crypto');
    }
    if (File(ssl).existsSync()) {
      _preloadWithAlteredSearchPath(ssl);
      NativeLogger.i('Windows: preloaded $ssl');
    }

    // Preload ct.dll before sybdb.dll
    final ct = '$dir\\ct.dll';
    if (File(ct).existsSync()) {
      _preloadWithAlteredSearchPath(ct);
      try {
        DynamicLibrary.open(ct);
        NativeLogger.i('Windows: preloaded $ct');
      } catch (e) {
        NativeLogger.w('Windows: preload ct.dll failed -> $e');
      }
    }
  }

  static DynamicLibrary loadCTLib() {
    NativeLogger.i('loadCTLib: platform=${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      NativeLogger.i('Android: opening libct.so');
      return DynamicLibrary.open('libct.so');
    } else if (Platform.isIOS) {
      // iOS links the XCFramework statically via CocoaPods; use process.
      NativeLogger.i('iOS: using DynamicLibrary.process()');
      return DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      NativeLogger.i('macOS: searching for ct dylib');
      final candidatePaths = <String>[];

      // Try app bundle locations
      try {
        final execPath = Platform.resolvedExecutable;
        final appDir = File(execPath).parent.parent.path;
        candidatePaths.add('$appDir/Frameworks/libct.dylib');
        candidatePaths.add('$appDir/Frameworks/libct.4.dylib');
        candidatePaths.add('$appDir/Resources/libct.dylib');
        candidatePaths.add('$appDir/Resources/libct.4.dylib');
      } catch (_) {}

      // Development fallbacks
      try {
        final scriptDir = File.fromUri(Platform.script).parent;
        final root = scriptDir.parent;
        candidatePaths.add('${root.path}/macos/Libraries/lib/libct.dylib');
        candidatePaths.add('${root.path}/macos/Libraries/lib/libct.4.dylib');
      } catch (_) {}
      try {
        final cwd = Directory.current.path;
        candidatePaths.add('$cwd/macos/Libraries/lib/libct.dylib');
        candidatePaths.add('$cwd/macos/Libraries/lib/libct.4.dylib');
      } catch (_) {}

      candidatePaths.addAll(['libct.dylib', 'libct.4.dylib']);

      for (final path in candidatePaths) {
        try {
          NativeLogger.i('macOS: trying $path');
          final lib = DynamicLibrary.open(path);
          NativeLogger.i('macOS: opened $path');
          return lib;
        } catch (e) {
          NativeLogger.w('macOS: failed $path -> $e');
        }
      }
    } else if (Platform.isLinux) {
      NativeLogger.i('Linux[CT]: searching for ct library');
      final candidatePaths = <String>[];

      // Bundled location
      try {
        final execPath = Platform.resolvedExecutable;
        final execDir = File(execPath).parent.path;
        candidatePaths.add('$execDir/lib/libct.so');
        candidatePaths.add('$execDir/lib/libct.so.4');
        candidatePaths.add('$execDir/lib/libct.so.4.0.0');
      } catch (_) {}

      // Development fallbacks
      try {
        final scriptDir = File.fromUri(Platform.script).parent;
        final root = scriptDir.parent;
        final rootPath = root.path;
        candidatePaths.add('$rootPath/linux/Libraries/lib/libct.so');
        candidatePaths.add('$rootPath/linux/Libraries/lib/libct.so.4');
      } catch (_) {}
      try {
        final cwd = Directory.current.path;
        candidatePaths.add('$cwd/linux/Libraries/lib/libct.so');
        candidatePaths.add('$cwd/linux/Libraries/lib/libct.so.4');
      } catch (_) {}

      candidatePaths.addAll(['libct.so', 'libct.so.4', 'libct.so.4.0.0']);

      for (final path in candidatePaths) {
        try {
          NativeLogger.i('Linux[CT]: trying $path');
          final lib = DynamicLibrary.open(path);
          NativeLogger.i('Linux[CT]: opened $path');
          return lib;
        } catch (e) {
          NativeLogger.w('Linux[CT]: failed $path -> $e');
        }
      }
    } else if (Platform.isWindows) {
      final tried = <String>[];
      Object? lastErr;

      // Try bundled location first
      try {
        final execPath = Platform.resolvedExecutable;
        final execDir = File(execPath).parent.path;
        final ctPath = '$execDir\\ct.dll';
        if (File(ctPath).existsSync()) {
          _setDllDirectory(execDir);
          _preloadWithAlteredSearchPath(ctPath);
          NativeLogger.i('Windows[CT]: trying bundled $ctPath');
          tried.add(ctPath);
          return DynamicLibrary.open(ctPath);
        }
      } catch (e) {
        lastErr = e;
        NativeLogger.w('Windows[CT]: bundled location failed -> $e');
      }

      // Try by name
      try {
        NativeLogger.i('Windows[CT]: trying ct.dll by name');
        tried.add('ct.dll');
        return DynamicLibrary.open('ct.dll');
      } catch (e) {
        lastErr = e;
        NativeLogger.w('Windows[CT]: ct.dll by name failed -> $e');
      }

      // Development fallbacks
      try {
        final scriptDir = File.fromUri(Platform.script).parent;
        final root = scriptDir.parent;
        final rootPath = root.path;
        final candidateRootDirs = ['$rootPath\\windows\\Libraries\\bin'];
        NativeLogger.i(
          'Windows[CT]: candidateDirs(root)=${candidateRootDirs.join('; ')}',
        );
        for (final dir in candidateRootDirs) {
          final p = '$dir\\ct.dll';
          if (File(p).existsSync()) {
            _setDllDirectory(dir);
            NativeLogger.i('Windows[CT]: SetDllDirectory($dir)');
            _preloadWithAlteredSearchPath(p);
            NativeLogger.i('Windows[CT]: preload $p');
            tried.add(p);
            return DynamicLibrary.open(p);
          }
        }
      } catch (_) {}

      try {
        final cwd = Directory.current.path;
        final candidateCwdDirs = ['$cwd\\windows\\Libraries\\bin', cwd];
        NativeLogger.i(
          'Windows[CT]: candidateDirs(cwd)=${candidateCwdDirs.join('; ')}',
        );
        for (final dir in candidateCwdDirs) {
          final p = '$dir\\ct.dll';
          if (File(p).existsSync()) {
            _setDllDirectory(dir);
            NativeLogger.i('Windows[CT]: SetDllDirectory($dir)');
            _preloadWithAlteredSearchPath(p);
            NativeLogger.i('Windows[CT]: preload $p');
            tried.add(p);
            return DynamicLibrary.open(p);
          }
        }
      } catch (_) {}

      throw UnsupportedError(
        'Could not load FreeTDS CT-Lib for this platform. Tried: ${tried.join('; ')}${' | Last error: $lastErr'}',
      );
    }
    throw UnsupportedError('Could not load FreeTDS CT-Lib for this platform.');
  }

  static void _setDllDirectory(String dir) {
    try {
      final k32 = DynamicLibrary.open('kernel32.dll');
      final setDllDir = k32
          .lookupFunction<
            Int32 Function(Pointer<Utf16>),
            int Function(Pointer<Utf16>)
          >('SetDllDirectoryW');
      final p = dir.toNativeUtf16();
      setDllDir(p);
      malloc.free(p);
    } catch (_) {}
  }

  // Configure default DLL directory search behavior for Windows.
  // Uses SetDefaultDllDirectories to restrict search to SAFE directories and
  // adds the current working directory using AddDllDirectory.
  static void _setDefaultDllDirectories() {
    try {
      final k32 = DynamicLibrary.open('kernel32.dll');
      final setDefault = k32
          .lookupFunction<Int32 Function(Uint32), int Function(int)>(
            'SetDefaultDllDirectories',
          );
      // LOAD_LIBRARY_SEARCH_DEFAULT_DIRS = 0x00001000
      setDefault(0x00001000);
      final addDir = k32
          .lookupFunction<
            Pointer<Void> Function(Pointer<Utf16>),
            Pointer<Void> Function(Pointer<Utf16>)
          >('AddDllDirectory');
      final cwd = Directory.current.path.toNativeUtf16();
      addDir(cwd);
      malloc.free(cwd);
    } catch (_) {
      // Ignore if not supported (older OS); best-effort only.
    }
  }

  // Best-effort: Preload a DLL with altered search path so its dependencies are
  // resolved relative to the DLL's own directory. Only used on Windows.
  static void _preloadWithAlteredSearchPath(String dllPath) {
    try {
      final k32 = DynamicLibrary.open('kernel32.dll');
      final loadLibraryEx = k32
          .lookupFunction<
            Pointer<Void> Function(Pointer<Utf16>, Pointer<Void>, Uint32),
            Pointer<Void> Function(Pointer<Utf16>, Pointer<Void>, int)
          >('LoadLibraryExW');
      final p = dllPath.toNativeUtf16();
      // 0x00000008 = LOAD_WITH_ALTERED_SEARCH_PATH
      loadLibraryEx(p, nullptr, 0x00000008);
      malloc.free(p);
      // If h is null, ignore; DynamicLibrary.open will throw a useful error later.
    } catch (_) {
      // Ignore: not fatal; used as a hint only.
    }
  }
}
