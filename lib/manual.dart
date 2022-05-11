import 'package:flutter/material.dart';
import './strings.dart';
import './model.dart';
import './api.dart';

class ManualPage extends StatefulWidget {
  @override
  _ManualPageState createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  bool _isLoading = false;
  Manual _manual;

  @override
  void initState() {
    super.initState();

    fetchManual();
  }

  fetchManual() async {
    setIsLoading(true);
    Manual manual;
    try {
      manual = await getManual();
    } finally {
      setIsLoading(false);
    }
    setState(() {
      _manual = manual;
    });
  }

  setIsLoading(bool isLoading) {
    setState(() {
      _isLoading = isLoading;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(strings['manual']!),
        bottom: PreferredSize(
          preferredSize: Size(double.infinity, 1.0),
          child: Opacity(
            opacity: _isLoading ? 1 : 0,
            child: LinearProgressIndicator(
              value: null,
            ),
          ),
        ),
      ),
      body: _manual == null
          ? Container()
          : ListView.builder(
              itemCount: _manual.steps.length + 1,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.all(16),
                child: index < _manual.steps.length
                    ? Text(
                        "${index + 1}. ${_manual.steps[index]}",
                        style: Theme.of(context).textTheme.subtitle1,
                      )
                    : Image.network(_manual.image),
              ),
            ),
    );
  }
}
