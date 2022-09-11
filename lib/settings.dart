import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

import './strings.dart';
import './state.dart';

const aspectRatios = <String, String>{
  '4:3': '4:3',
  '16:9': '16:9',
};

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(
      title: strings['settings']!,
      children: [
        Consumer<SlidesModel>(
          builder: (context, state, child) => SettingsGroup(
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
                defaultValue: 36,
                min: 18,
                max: 50,
                step: 1,
                leading: const Icon(Icons.format_size),
              ),
              DropDownSettingsTile<String>(
                leading: const Icon(Icons.aspect_ratio),
                title: strings['aspectRatio']!,
                subtitle: " ",
                settingKey: 'slides.aspectRatio',
                values: aspectRatios,
                selected: "4:3",
              ),
            ],
          ),
        )
      ],
    );
  }
}
