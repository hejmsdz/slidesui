import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

import './strings.dart';
import './state.dart';

const aspectRatios = <String, String>{
  '16:9': '16:9',
  '4:3': '4:3',
};

final verticalAlignments = <String, String>{
  'top': strings['verticalAlignTop']!,
  'center': strings['verticalAlignCenter']!,
  'bottom': strings['verticalAlignBottom']!,
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
                const VerticalAlignmentSettingsTile(),
                DropDownSettingsTile<String>(
                  leading: const Icon(Icons.aspect_ratio),
                  title: strings['aspectRatio']!,
                  subtitle: " ",
                  settingKey: 'slides.aspectRatio',
                  values: aspectRatios,
                  selected: "16:9",
                ),
                kIsWeb
                    ? Container()
                    : DropDownSettingsTile<String>(
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

class VerticalAlignmentSettingsTile extends StatefulWidget {
  const VerticalAlignmentSettingsTile({super.key});

  @override
  State<VerticalAlignmentSettingsTile> createState() =>
      _VerticalAlignmentSettingsTileState();
}

class _VerticalAlignmentSettingsTileState
    extends State<VerticalAlignmentSettingsTile> {
  String? _verticalAlign;

  @override
  void initState() {
    super.initState();

    _verticalAlign = Settings.getValue('slides.verticalAlign');
  }

  Widget buildIcon() {
    if (_verticalAlign == 'top') {
      return const Icon(Icons.align_vertical_top);
    } else if (_verticalAlign == 'bottom') {
      return const Icon(Icons.align_vertical_bottom);
    } else {
      return const Icon(Icons.align_vertical_center);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropDownSettingsTile<String>(
      leading: buildIcon(),
      title: strings['verticalAlign']!,
      settingKey: 'slides.verticalAlign',
      values: verticalAlignments,
      selected: 'center',
      onChange: (value) {
        setState(() {
          _verticalAlign = value;
        });
      },
    );
  }
}
