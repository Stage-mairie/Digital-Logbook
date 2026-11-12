// Les deux plateformes téléchargent le même PDF, sans nouvelle dépendance Flutter.
export 'receipt_file_saver_stub.dart'
    if (dart.library.html) 'receipt_file_saver_web.dart'
    if (dart.library.io) 'receipt_file_saver_io.dart';
