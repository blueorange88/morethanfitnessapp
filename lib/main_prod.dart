import 'main.dart' as app;
import 'services/app_environment.dart';

Future<void> main() => app.runMtfApp(environment: AppEnvironment.prod);
