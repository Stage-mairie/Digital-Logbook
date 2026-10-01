// Le Web télécharge avec un Blob ; les autres plateformes restent compilables
// sans importer dart:html (le bouton n'est présent que sur HistoriqueWebPage).
export 'download_file_stub.dart'
    if (dart.library.html) 'download_file_web.dart';
