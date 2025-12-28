import Flutter
import UIKit

// This is a dummy plugin class required by Flutter's plugin registration system.
// The actual FFI bindings are handled by Dart FFI directly linking to the
// statically linked FreeTDS libraries via DynamicLibrary.process().
public class MssqlConnectionPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // No method channel needed - this is an FFI plugin.
    // FreeTDS symbols are linked statically and accessed via DynamicLibrary.process()
  }
}
