import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fit_gym/theme/app_theme.dart';

Future<void> loadAppTestFonts() async {
  final loader = FontLoader(AppTextTheme.font);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
  }
  await loader.load();
  final icons = File(
    'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(ByteData.sublistView(await icons.readAsBytes())),
        ))
        .load();
  }
}
