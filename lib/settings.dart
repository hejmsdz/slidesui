import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

import './strings.dart';
import './state.dart';

const aspectRatios = <String, String>{
  '16:9': '16:9',
  '4:3': '4:3',
};

final behaviors = <String, String>{
  'display': strings['behaviorDisplay']!,
  'save': strings['behaviorSave']!,
  'share': strings['behaviorShare']!,
};

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(
      title: strings['settings']!,
      children: [
        Consumer<SlidesModel>(
          builder: (context, state, child) => Column(children: [
            SettingsGroup(
              title: strings['settingsSectionSlides']!,
              children: <Widget>[
                SwitchSettingsTile(
                  settingKey: 'slides.hints',
                  title: strings['hints']!,
                  enabledLabel: strings['enabled']!,
                  disabledLabel: strings['disabled']!,
                  leading: const Icon(Icons.help),
                  defaultValue: false,
                ),
                SliderSettingsTile(
                  title: strings['fontSize']!,
                  settingKey: 'slides.fontSize',
                  defaultValue: 42,
                  min: 36,
                  max: 72,
                  step: 1,
                  leading: const Icon(Icons.format_size),
                ),
                DropDownSettingsTile<String>(
                  leading: const Icon(Icons.aspect_ratio),
                  title: strings['aspectRatio']!,
                  subtitle: " ",
                  settingKey: 'slides.aspectRatio',
                  values: aspectRatios,
                  selected: "16:9",
                ),
                DropDownSettingsTile<String>(
                  leading: const Icon(Icons.slideshow),
                  title: strings['slidesBehavior']!,
                  subtitle: " ",
                  settingKey: 'app.slidesBehavior',
                  values: behaviors,
                  selected: 'save',
                ),
              ],
            ),
          ]),
        )
      ],
    );
  }
}
